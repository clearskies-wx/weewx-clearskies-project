# Marine Model Restoration & Verification Plan

**Created:** 2026-07-27
**Revised:** 2026-07-27 after adversarial review (findings incorporated; see "Review corrections")
**Status:** Phases A–C landed. **Phases E and F added 2026-07-27** after the grid-strategy review.
**Repos:** marine = `repos/weewx-clearskies-marine`, meta = repo root

**Sequence:**
Phase A ✅ → Phase B ✅ → **Deploy 1** ✅ → Gate B (rows 3/5/8/11/13 outstanding) →
Phase C ✅ (C1/C2/C3 landed; **C4 pending**) → **E0 restore service** →
Phase E → Gate E → Phase F → Gate F → Phase D → Gate D

> ### ⛔ Read this before touching Phase C or the L3 grid
>
> **C3 landed and is not being reverted as a defect** — it correctly restored L3's offshore edge to
> the measured 15 m contour per this plan as written. But the resulting **41 895-cell** grid ran
> **past 75 minutes without completing**, against a ~7-minute baseline, and no forecast published.
>
> The 2026-07-27 review concluded the 15 m offshore edge was a carryover from when L3 was the
> fine-detail model, and that **10 m resolution was an assumption, not a derivation**. **Phase E
> replaces the L3 strip with a small rotated grid on the structure** and rescopes L3 to a nesting
> step. C3's `offshore_distance_m` threading is **kept and reused** by E4.
>
> **E0 comes first**: roll back to the publishing grid and restore service before any Phase E work.
>
> Governing rulings: [briefs/SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md](briefs/SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md)
> §0A (grid strategy) and §0B (wind). **Findings §1–§8 are the research record and contain
> superseded text — §0A/§0B win on every conflict.**

Two deploys, not one. Both need the operator's word. The reason is in "Why observability deploys
first" below — without it the plan cannot be executed as written.

---

## Context

Between 2026-07-19 and 2026-07-27 the surf model lost capabilities that had been built and, in
some cases, verified working in production. Four mechanisms:

1. **Silent supersession.** `6209c7a` (07-21) introduced `smart_size_l3_grid()` with no
   offshore-distance argument. L3's offshore edge went from the measured 15 m contour (2160 m,
   production-verified 07-19) to 910 m; it is 870 m today. Accepted under a minute after the report.
2. **Half-completed rulings.** The operator ruled on 07-25 that each 1D strip must start from its
   own nearest grid cell — "PULL FROM THE GRID". T4B.1/.3/.4 shipped. **T4B.6 never did.**
3. **Closure on evidence that cannot detect failure.** Shadow classification was reported DONE
   twice on synthetic self-tests while production logged `0 shadowed, 32 open` daily from 07-22.
4. **A rule that lived only in conversation.** Distances are measured from the coastline anchor,
   never the operator's pin. Five sites violated it; it was written down nowhere.

**Through-line: every one of these passed review.** Agents were given goals, not designs, and
filled the gap by designing on the fly. Supervision accepted reports instead of re-running claims.

**The fifth mechanism, found in review and not in the original plan: signals existed and nobody
read them.** `Structure pier(567m): no usable coordinates` and `0 shadowed, 32 open` were logged
every cycle for six days. Detection was never the problem. **Delivery** was. Any plan that adds
more ERROR lines to the same journal builds a smoke detector and installs it in a sealed room —
hence **B3**, which did not exist before review.

---

## Why observability deploys first

The marine service runs only on **librewxr**. There is no dev instance. `scripts/deploy-marine.sh`
pulls from GitHub, so nothing reaches the running system without a push.

The original plan demanded a live value for every gate row while deferring all deployment to the
end. That is circular: Phase B and C gates required evidence from a system that could not exist
until after them. Under pressure the coordinator would have redefined "live" as "local," which is
the same slippage that produced the failures this plan exists to end.

**Deploy 1 therefore carries the twelve existing fixes plus Phase B, before any Phase C work.**
Consequences, all of them good:

- The invariants run against genuine production, where defects 4, 5 and 6 are still live.
- The twelve unpushed commits stop riding to production unverified — Gate B verifies them.
- Gate C's live values come from a system that is one deploy behind the working tree, not twelve.
- Gate B's "must fire" list becomes truthful: it names only the defects still present after the
  twelve commits land.

---

## Conventions used by every task below

- **Owner** — the agent type dispatched. `coordinator` means the coordinator does it directly.
- **Files** — the complete allowlist. Anything not listed is off limits, full stop.
- **Must not touch** — named traps, called out because they are adjacent and tempting.
- **Design** — what to write, to file and line. If it is not specified here, the agent stops
  and reports; it does not choose.
- **Live check** — a command run against the deployed system, with the number expected. Not a test.
- **Guard** — a unit test, written by `clearskies-test-author`, which must fail against the
  pre-change code. It is a regression guard, not evidence the system works.
- **Adversarial** — `clearskies-auditor`, given the design and the expected numbers, never the
  implementing agent's tests or report, briefed to disprove.

**Universal prohibitions, every task:** no renaming; no signature changes not named in the task; no
refactoring or helper extraction; no replacing an implementation with an equivalent; no spawning
subagents; no deploy or service restart; no `chown`/`chmod`; no editing anything under
`docs/archive/`; git limited to `status`/`log`/`diff`/`add <explicit paths>`/`commit`.

**No new parameter, config key, field, or file EXCEPT where the task's Design names it explicitly
and gives its name and location.** (Review finding: the original blanket ban made B1 and C4
undeliverable — a trace needs a config key and an output path, and per-transect profiles need
somewhere to live. A task that requires a new artefact must name it; a task that does not name one
may not invent one.)

**Known-answer tests are mandatory for numerical kernels.** Any function computing a physical
quantity from a closed-form relation gets a test against an *independently implemented* reference —
not a rearrangement of the same code. `tests/test_surf_1d_dispersion.py` is the model: it solves
ω² = gk·tanh(kd) with Brent, sharing no code path with the implementation. **This is the only
defense against the dispersion class of defect, which produces plausible outputs and passes every
gate in this plan.** Applies to shoaling, refraction, breaking, and wave setup as they are touched.

---

## QC gates — how they work

A gate is **blocking**. Nothing downstream starts until it passes. A gate is not a test run and not
an agent's report.

Every gate is walked by the coordinator, element by element, against the task's numbered design.
For each element:

| # | Design element | Where it is in the code | Live value proving it ran |
|---|---|---|---|

- **Where it is in the code** — `file:line`, read after the change. Not the agent's claim.
- **Live value proving it ran** — a number from the deployed system or its artefacts, with the
  command that produced it. *"The test passes"* is not a live value.

**A design element with no live value is a FAIL, not a gap.**

Then:

- **Allowlist diff.** `git show <commit> --stat` against the task's **Files** list. Anything
  outside it is reverted and the task returns to the agent.
- **Adversarial pass.** `clearskies-auditor`, given the design and expected numbers, and **never**
  the implementing agent's tests, commit message, or report. Brief: *"This is claimed to work.
  Prove it does not. Look for values right by accident, right for one timestep only, right in cache
  but never recomputed, or right because a fallback fired silently."* Passes only when the auditor
  reports it could not disprove the claim and names what it ruled out.

**Every gate gets an adversarial pass, including Gate A.** (Review finding: Gate A originally
waived it on the grounds that there was no running system — but Gate A's rows are all file checks
an auditor can verify today, and the coordinator is the component whose one-minute acceptance
caused defect 6. It does not get to be its own sole verifier.)

**Gate failure is normal and is not a reason to widen scope.** A failed gate returns the task to
its agent with the failing row named.

---

# PHASE A — Governance (coordinator alone; no agents dispatched)

### A1 — One canonical architectural block
**Owner:** coordinator · **Files:** `CLAUDE.md`, `~/.claude/CLAUDE.md`
**Design:** The block exists twice, near-verbatim. Project `CLAUDE.md` keeps the canonical full
text. Global keeps only the one-sentence rule, the seven triggers as a bare list, and a pointer.
**Must not touch:** the trigger wording. Deduplicate, do not re-draft.

### A2 — Collapse agent rules into `rules/agents.md`
**Owner:** coordinator · **Files:** new `rules/agents.md`; `rules/clearskies-process.md`, `CLAUDE.md`
**Design:** Six locations hold agent rules — `CLAUDE.md` §"Git safety — agents and coordinator",
and `clearskies-process.md` §"Agent orchestration" (121), §"Architectural change block" (207),
§"Scope binding before agent dispatch" (232), §"Agent prompt requirements" (245), §"False-claim
protocol" (263). Move all six into one file, once; leave a one-line pointer at each origin.
**Must not touch:** the substance of any rule. Relocation and deduplication only.

### A3 — Collapse verification rules into `rules/verification.md`
**Owner:** coordinator · **Files:** new `rules/verification.md`; `clearskies-process.md`, `CLAUDE.md`
**Design:** Move `clearskies-process.md` §"Audit rules" (276), §"Round-close verification gate"
(296) and its steps (300-337), §"Validate against reality, never against the model's own output"
(654); plus `CLAUDE.md` §"Self-audit before delivering" and §"Prompt faithfulness". Add: the
three-layer model (**guard** = agent-written unit test, a regression guard, never evidence the
system works / **invariant** = runtime assertion on real data / **adversarial** = auditor who never
sees the implementing agent's work); and the **known-answer test mandate** for numerical kernels,
with `tests/test_surf_1d_dispersion.py` cited as the pattern.

### A4 — Rewrite the six agent profiles
**Owner:** coordinator
**Files:** `.claude/agents/clearskies-{api-dev,auditor,dashboard-dev,docs-author,realtime-dev,test-author}.md`
**Design:** Common four-part spine; only the domain section differs.
1. **Scope** — what this agent is for, two sentences.
2. **You code a design; you do not design.** If the task does not specify the design, stop and
   report. Carries the universal prohibitions verbatim.
3. **Hard restrictions** — git allowlist; no subagents (A5); no deploy/restart; no `chown`/`chmod`;
   never edit `docs/archive/`.
4. **Reporting** — changes with file:line; what could not be verified, stated plainly; every
   trigger hit and stopped on. A claim without a command and its output is not evidence.
**Must not touch:** existing domain knowledge. Replace only the boilerplate.

### A5 — Agents may not spawn agents
**Owner:** coordinator · **Files:** the six profiles
**Design:** **The profiles currently have no `tools:` frontmatter at all** — they inherit
everything, including `Agent`. So this task *adds* a restrictive `tools:` line to each, omitting
`Agent` and `Task`, and states the prohibition in prose. (Review finding: the original design said
"remove `Agent`/`Task` from every profile's tool list," targeting something that does not exist,
and its gate row would have passed before any change was made.)

### A6 — Create `rules/coordinator.md`
**Owner:** coordinator · **Files:** new `rules/coordinator.md`; `CLAUDE.md` routing entry
**Design:**
- **Dispatch gate.** No agent is dispatched without a file allowlist, the design to file-and-line,
  an explicit prohibition list, and a live check with expected numbers. If the coordinator cannot
  write those four, the task is not ready.
- **Acceptance gate.** An agent's report is a claim. Before marking anything done: independently
  re-run the live check and paste raw output; diff actual changes against the allowlist; revert
  anything outside it.
- **The coordinator does not write production code.** Reads, verifies, dispatches, reports.
- **Never push without the word "push" from the operator in chat.**
- **Stop-and-surface:** unexpected repo state, an architectural trigger, an agent reporting a blocker.
- **Operator spot-check protocol.** This file is written by the entity it governs and cannot
  self-enforce. State plainly which gate rows the operator should spot-check by hand, and that a
  coordinator claim of "gate passed" without pasted raw output is to be rejected.

### A7 — Deduplicate the remainder
**Owner:** coordinator · **Files:** `rules/coding.md`
**Design:** Two sections are both numbered 6 (§6 Internationalization at 474; §6.1 Rules at 565,
under §7 Charts). Fix the numbering. **Do not look for a `CLAUDE.md` counterpart to §1 "A model
runs on all its inputs" — review confirmed none exists in either CLAUDE.md.**

### A8 — Write down the anchor rule *(new; review finding)*
**Owner:** coordinator · **Files:** `docs/ARCHITECTURE.md` or the relevant manual; `rules/coding.md`
**Design:** Mechanism 4 is not closed. The rule — profile distances are measured from the coastline
anchor, never the operator's pin, because that is how `find_depth_contour_distance()` generates
them — currently lives in a docstring (`swan_domain.py:758-783`), in tests, and in this plan. Plan
files get archived; that is precisely how the rule died the first time. State it as a fact about
the data, cite the generating code, and put it somewhere a future implementer reads before writing
grid or profile code.

---

## ⛔ QC GATE A — governance

| # | Element | Evidence required |
|---|---|---|
| 1 | Architectural block appears once in full | `grep -c` of a distinctive trigger phrase across both CLAUDE.md files returns 1 for the full text |
| 2 | Global keeps only rule + triggers + pointer | section line count, before and after |
| 3 | Six agent-rule sections moved, not copied | each origin heading gone from `clearskies-process.md`; pointer in its place |
| 4 | `clearskies-process.md` shrank | `wc -l` before (704) and after |
| 5 | Verification rules in one file, incl. known-answer mandate | move-not-copy check per origin; the mandate is present |
| 6 | Six profiles carry the identical spine | `grep -L` for a spine phrase returns no file |
| 7 | **A restrictive `tools:` line now exists in all six** | `grep -c '^tools:'` returns 6 **and** `Agent` appears in none of them. Row 7 must be shown to have FAILED before the change — the profiles had no frontmatter at all |
| 8 | Coordinator profile exists, routed, includes the spot-check protocol | routing entry resolves; all five sections present |
| 9 | `coding.md` numbering fixed | no duplicate section number |
| 10 | Anchor rule is in a live governing document | file:line, and it is not a plan or archive file |
| 11 | No rule appears in two files | coordinator reads every rules file end to end and states what it checked |
| 12 | Routing table resolves | every path in the table exists on disk |

**Adversarial:** `clearskies-auditor` verifies rows 1, 3, 5, 7, 10, 11 independently against the
files, without the coordinator's report. It is specifically briefed that row 7 is the row most
likely to be satisfied vacuously.

**Fail conditions:** any rule in two places; any profile still able to spawn agents; any
routing-table path that does not resolve; row 7 passing without evidence it previously failed.

---

# ⛔ GATE — RESTART VSCODE

Agent profiles, `CLAUDE.md`, and `rules/` load at session start. Dispatching Phase B from the
session that wrote Phase A runs agents under the profiles this plan replaces.

1. Coordinator completes and commits Phase A. **Dispatches nothing.**
2. Coordinator writes a resume prompt to `docs/planning/briefs/` naming: this plan, the Phase A
   commit, the twelve unpushed marine commits, and the current live numbers — surf height, L3 grid
   dimensions, shadowed count, transect spread.
3. **Operator restarts VSCode.**
4. New session confirms the new profiles are loaded, then begins Phase B.

---

# PHASE B — Observability

### B1 — DEBUG trace
**Owner:** `clearskies-api-dev`
**Files:** new `weewx_clearskies_marine/services/trace.py`; the call-site files in the table below
**Must not touch:** any physics, any published field, any existing log line

**Named artefacts this task is authorised to create** (review finding — the original task forbade
exactly what it required):
- config key `[marine] debug_trace` (boolean, default `false`) in `marine.conf`
- output path `/var/log/weewx-clearskies/marine-trace-{YYYYMMDD}.jsonl`

**Design:** one JSON object per line, written only when `debug_trace` is true. Correlation key on
every record: `spot_id`, `valid_time`, `transect_index` where applicable.

| Stage | Call site | Records |
|---|---|---|
| Grid sizing | `services/grid_sizing_chain.py` (config-push path, **not per cycle** — see note) | level, cells, extent m, edge positions, origin anchor, contour distances consumed |
| Obstacle | `providers/nearshore/swan.py:892` | structure id, source (explicit / computed), endpoints, transmission |
| SWAN sample | `services/swan_runner.py` band parse | station index, depth, Hs, Tp, Dir, Qb |
| Handoff selection | `services/swan_runner.py` `_select_l3_handoff_position_and_spectrum` (**not** `surf_pipeline_timestep.py:209`, which only reads a pre-made choice) | target depth, chosen station and its depth, clamped y/n, Qb refinement y/n, reason |
| Handoff resolution | `services/surf_pipeline_timestep.py:209` | which source the per-transect map came from, and its distinct-value count |
| Profile to 1D | `services/surf_1d_pipeline.py:1128` | seaward depth, shoreward depth, point count, truncated at |
| SwellTrack | `services/surf_1d_pipeline.py:1156` | boundary Hs, break depth, Hs at break, face height, Ks |
| Shadow | `services/transect_handoff.py:512` | structures received (count + ids), transects tested, shadowed count |
| Published | `endpoints/surf.py:1058` | every field for that timestep, **and which stage and which source channel produced it** |

**Note on grid sizing:** `run_grid_sizing_chain()` runs at config push, not per cycle
(`endpoints/config.py:77`; geometry is "computed ONCE... never recomputed here",
`providers/nearshore/swan.py:762-764`). Its trace record therefore appears only on a config
re-push, and Gate B does not require it from a forced cycle.

**Live check:** enable, force one cycle, follow one published `breakingFaceHeight` back to its SWAN
station using only the trace file.
**Guard:** disabled produces zero output.

### B2 — Runtime invariants
**Owner:** `clearskies-api-dev`
**Files:** new `weewx_clearskies_marine/services/invariants.py`; call sites at the stages above
**Must not touch:** thresholds inside physics formulae

**Invariants observe and log. They never alter published output.** (Review finding: the original
task simultaneously said "observe, do not correct," "refuse rather than degrade," and "no published
field changed — byte-identical." Only the first and third can both hold. Refusal behaviour belongs
to the Phase C code paths, not to the invariants.)

| # | Invariant | Threshold / criterion | Would have caught |
|---|---|---|---|
| 1 | break depth ≤ handoff depth | exact | re-shoaling from 10.6 m when handed off at 1.46 m |
| 2 | SwellTrack Hs vs SWAN Hs over the overlapping depth range | **25%** — looser than the 20% test tolerance, which is itself justified by 2D refraction a 1D strip cannot represent | the 1.45× disagreement |
| 3 | `spot_config.structures` non-empty ⟹ shadowed count > 0 | exact | `0 shadowed` daily since 07-22 |
| 4 | distinct handoff depths across transects > 1 | **skip when `handoff_source_level == "L2"`** — the T4B.4 writer legitimately populates a constant `L2_REFERENCE_DEPTH_M` for every transect | the broadcast |
| 5 | transect bathymetry objects are not all the same object | identity | the shared profile |
| 6 | L3 offshore edge ≥ the spot's measured 15 m contour | evaluated at config push, cached, checked per cycle | the grid collapse |
| 7 | **the swell card's source channel is the deep-water reference** | provenance, from B1's Published record | surf-zone partitions published as swell |
| 8 | best peak > spot average **when invariant 4's distinct count > 1** | exact | 32 identical transects |
| 9 | a published hour has a non-empty wave field | Hs > 0.05 m or Tp > 2 s | SWAN's cold-start row published as forecast |

**Invariant 7 was rewritten in review.** As originally specified — "swell-card sample depth ≥ 10 m"
— it was uncomputable: deep-water entries carry `time/freqs_hz/dirs_deg/energy/components` and no
depth (`swan_runner.py:2961-2967`), and the published `multiSwell` carries none either
(`surf.py:1041-1051`). Adding a depth field is a data-contract change no task authorises.
Provenance is the catchable signal and B1 already records it.

**Invariant 6 note:** grid sizing is config-time. The invariant reads the cached sizing metadata
each cycle rather than recomputing.

### B3 — Marine health reports a real state *(new; the review's highest-value finding)*
**Owner:** `clearskies-api-dev`
**Files:** `weewx_clearskies_marine/endpoints/health.py`, `weewx_clearskies_marine/state.py`,
`weewx_clearskies_marine/services/invariants.py`
**Must not touch:** the existing response keys `version`, `last_run`, `spots`, `run_in_progress` —
the API polls this endpoint every 60 s (OPERATIONS-MANUAL) and must keep working unchanged

**The endpoint currently cannot report a problem.** `endpoints/health.py` returns a hardcoded
`"status": "ok"` on every call, whatever the model is doing. During the six days production logged
`0 shadowed, 32 open`, health said `ok`. It would have said `ok` with SWAN failing every cycle.

**Named artefacts this task is authorised to add** — additive keys only, no key removed or retyped:
- `status` becomes one of `ok` / `degraded` / `failed` (today: always `ok`)
- `reasons`: list of short machine-readable strings explaining a non-`ok` status
- `inputs`: per-input freshness — `ww3_boundary`, `wind`, `bathymetry`, `tide`, each with
  `available` and `age_s`
- `invariants`: `{fired_total, last_fired_at, last_fired_names}`

**State model, driven by what the model could actually get:**

| status | meaning |
|---|---|
| `ok` | last cycle completed, every input present and fresh, no invariant fired |
| `degraded` | cycle completed, but an input was stale or a fallback fired, or an invariant fired — output exists and is suspect |
| `failed` | last cycle did not complete, or a required input was unavailable so nothing was published |

The operator's standing rule — never publish anything not computed with the full model — means an
unavailable *required* input is `failed`, not `degraded`. A stale-but-usable input is `degraded`.
**The task must state which inputs it classes as required and which as degrading, and the
coordinator rules on that list before dispatch.**

**Why this exists:** detection was never the failure. `Structure pier(567m): no usable coordinates`
was logged every cycle for six days. **A plan that adds ERROR lines to the same journal and calls
it QC repeats the failure at higher volume.**

**Live check:** force an invariant to fire — `status` becomes `degraded` and `reasons` names it.
Stop a required input — `status` becomes `failed`. Neither requires reading the journal.

### B4 — Admin status page *(new; operator direction, 2026-07-27)*
**Owner:** `clearskies-api-dev` (FastAPI + Jinja, not React — this is the config UI, not the dashboard)
**Repo:** `repos/weewx-clearskies-stack`
**Files:** `weewx_clearskies_config/admin/routes.py`,
`weewx_clearskies_config/templates/admin/status.html` (new),
plus the i18n keys `help.admin.status.*`
**Must not touch:** any existing admin section; the wizard; `_VALID_SECTIONS`

**Design:** a new admin section `status`, added to `_CUSTOM_SECTIONS` (`admin/routes.py:839`)
alongside the existing entries, following the pattern of the `marine-service` section already
there. It polls and renders:

- **API health** — status, version, last update
- **Marine service health** — the full B3 payload: status, reasons, per-input freshness, invariant
  counts and the names of anything that fired

Render `degraded` and `failed` so they are unmissable, and show `reasons` verbatim rather than
collapsing them to a single line. The page is read-only — it displays, it does not act.

**Why the admin page and not an external monitor:** it is where the operator already looks, it
ships with the product, and it needs no infrastructure this project does not already run.

**Live check:** with the marine service degraded, the admin status page shows `degraded` and the
reason, without the operator opening a terminal.
**Guard:** the page renders when the marine service is unreachable — an unreachable service is
itself a status, not a stack trace.

---

# ⛔ DEPLOY 1 — twelve fixes + observability



Carries `eb3c4b7` `1664701` `7fb75f9` `83f0205` `bed7ec7` `aa4553d` `bd8c928` `35af390` `ac6bd8a`
`c28588b` `595ff6a` `4276806` plus B1–B3. The live system is currently running **none** of these.

**Rollback:** the deployed commit is `007028d`. If the cycle fails to complete, redeploy that hash
before diagnosing.

---

## ⛔ QC GATE B — observability, and the twelve commits

Walked against **deployed production**.

**Part 1 — the trace**

| # | Element | Evidence |
|---|---|---|
| 1 | Off by default | fresh start with `debug_trace=false` writes no file |
| 2 | Every per-cycle stage emits | one cycle produces ≥1 record per stage except Grid sizing (config-time) |
| 3 | A published number is fully traceable | follow one `breakingFaceHeight` to its SWAN station using only the trace. Paste the chain |
| 4 | Correlation keys present | every record carries `spot_id`, `valid_time`, `transect_index` where applicable |
| 5 | No published field changed | forecast bundle before and after — byte-identical |

**Part 2 — invariants must fire on production's remaining defects**

After Deploy 1, defects 1, 2, 3 and 7 are fixed by the twelve commits. Defects 4, 5 and 6 are not.
**The must-fire list is therefore 3, 4, 5, 6 and 8** — and only those. (Review finding: the original
list demanded invariant 1 fire, but `7fb75f9` fixes its defect in the only tree that can host it,
so a correct invariant would have been condemned.)

| # | Element | Evidence |
|---|---|---|
| 6 | Invariants 3, 4, 5, 6, 8 fire | raw ERROR lines, pasted |
| 7 | Invariants 1, 2, 7, 9 pass | and their guards demonstrate they fail against pre-fix behaviour |
| 8 | No invariant fires off stale cache | for each firing, show it came from the live computation, not a cached artefact |

**Part 3 — the twelve commits did what they claimed**

| # | Commit | Evidence |
|---|---|---|
| 9 | `7fb75f9` | surf height at Huntington ≈ 3.3 ft, not 6.0 ft |
| 10 | `83f0205` + `bd8c928` | `multiSwell` sourced from the deep-water reference; the 6–8 s westerly appears |
| 11 | `bed7ec7` | `TABLE_DWR_1.txt` holds 67 rows, not 1; handoff moves off breaking cells |
| 12 | `aa4553d` | hotstart loads; the run is warm, not cold |
| 13 | `1664701` | tide is non-zero across the forecast |
| 14 | `35af390`, `595ff6a`, `ac6bd8a`, `c28588b` | beach-profile partitions align; grid edges anchor-relative |

**Part 4 — delivery**

| # | Element | Evidence |
|---|---|---|
| 15 | Health can report something other than `ok` | the endpoint returns `degraded` with `reasons` naming the invariants that fired on this very cycle — production has defects 4, 5 and 6 live, so a health response of `ok` after Deploy 1 is a **FAIL** |
| 16 | Per-input freshness is real | `inputs` shows actual ages; stop one input and it reflects that |
| 17 | The admin status page shows it | screenshot or rendered output showing `degraded` and the reasons, without opening a terminal |
| 18 | Unreachable service renders as a status | stop the marine service; the admin page reports it rather than erroring |

**Fail conditions:** any of 3, 4, 5, 6, 8 passing (it cannot detect its own defect); any published
number the trace cannot explain; any published field changed; any invariant firing off stale cache.

**Adversarial:** construct a state where a broken system passes an invariant, and a published value
the trace cannot account for.

---

# PHASE C — Model fixes

### C1 — Per-transect handoff reaches the pipeline
**Owner:** `clearskies-api-dev`
**Files:** `weewx_clearskies_marine/services/surf_pipeline_timestep.py` only
**Must not touch:** `swan_runner.py`; the return type; the five call sites; `surf_1d_pipeline.py`

SWAN writes 32 per-transect band tables every cycle (`TABLE_PT_1_0.txt` … `TABLE_PT_1_31.txt`,
10 stations each, genuinely distinct — depths 8.35 / 9.19 / 9.40 m on transects 0 / 16 / 31 at the
same timestamp). They are parsed; the handoff is selected from each band's own depths and Qb; the
result is attached at `swan_runner.py:4498`. **Two writers (`:3083`, `:4498`), zero readers.**

`resolve_handoff_by_transect()` (`surf_pipeline_timestep.py:209-246`) reads the *scalar*
`handoff_depth_m` at line 226 off that same object and replicates it 32× at lines 240-243.

**Design:** at line 226, prefer `ts_handoff_specout["handoff_by_transect"]` when present; build the
returned dict from its per-transect entries, keyed by transect index. The per-transect entries carry
the same `handoff_depth_m`/`handoff_source_level` keys the scalar path reads
(`swan_runner.py:854-856`, `:3065-3066`). Fall back to the scalar path when absent, logging at
WARNING. Signature and return type unchanged.

**Known false positive to expect:** the T4B.4 writer at `swan_runner.py:3083` populates
`handoff_by_transect` with a constant `L2_REFERENCE_DEPTH_M` for every transect — legitimate per
Amendment 2 §4. On any L2-fallback cycle the 32 values are identically equal by design. Invariant 4
skips that case; Gate C1 row 1 must be evaluated on an L3 cycle.

**Live check:** distinct `handoffDepthM` count > 1; `bestPeakFaceHeight` > `spotAverageFaceHeight`;
`peelDirection` not `a_frame` on every timestep.

### C2 — Populate structure coordinates at config parse
**Owner:** `clearskies-api-dev`
**Files:** `weewx_clearskies_marine/config/marine_config.py` only
**Must not touch:** `build_obstacle_structures()`; `compute_transect_shadows()`; `TRANSM 0.95`
(`swan_formats.py:1489`) — a physics constant, trigger 1

**This task was redesigned in review.** The original put the adapter in `swan_formats.py` and then
required changes in three caller files outside its own allowlist, plus a `length_m` lookup
impossible inside `compute_spot_transects()` (no spot-config parameter, and signature changes are
banned). The fix belongs one layer earlier.

**Both halves run in the same process, one second apart:**
```
05:44:30  SWAN structure emitted: type=pier, bearing=221.0°, length=567m, distance=124m
07:58:26  Structure pier(567m): no usable coordinates — excluded from shadow computation.
```
`build_obstacle_structures()` (`providers/nearshore/swan.py:856-877`) projects bearing/length/
distance into a two-point `[lon, lat]` line. `compute_transect_shadows()` reads
`structure.coordinates` by attribute (`transect_handoff.py:288, 335`). The live config has no
`coordinates` key, so `marine_config.py:340-342` leaves it `[]` and the classifier bails at `:289`.

**Design:** in `StructureConfig.__init__` (`marine_config.py:333-342`), when `coordinates` is absent
or shorter than two points and `bearing_degrees`/`length_m`/`distance_m` are all present, populate
`self.coordinates` using the same projection as `swan.py:862-872`. The field's own docstring
(`marine_config.py:329-331`) already says it is the OBSTACLE line geometry; leaving it empty when it
is derivable from data in hand is the defect. One change, one place, and every consumer — SWAN
emission, shadow classification, and grid sizing — sees the same geometry.

**Expected side effect, report it:** `build_obstacle_structures()` will now take case (a)
("explicit") rather than case (b) ("computed from pin"), changing its log wording. The emitted
`OBSTACLE` line must be byte-identical — verify and paste both.

**SWAN already computes the shadow.** Per-transect bands at the peak hour: PT0–PT7 at 0.812–0.830 m
against a far-field 0.872–0.890 m — an 8% deficit at 8–9 m depth with Qb = 0 everywhere. The
classifier's geometry predicts transects 0–12 shadowed.

**Live check:** `openTransectCount` < `transectCount`; shadowed set overlaps 0–12; `"no usable
coordinates"` gone from the journal.
**Guard:** a `StructureConfig` built from bearing/length/distance **with no `coordinates` key** —
production's shape — yields two coordinate points and shadows transects. The deleted test only ever
built the explicit-coordinates shape, which is why it passed while production failed.

### C3 — L3 offshore edge returns to the measured 15 m contour
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_domain.py` only
**Must not touch:** L3 resolution; L3's shoreward edge and `shoreward_distance_m`; the lateral terms;
L1 and L2; `_compute_level3_grid()`'s non-delegating branch (1353-1460)

`offshore_distance_m` is measured (`grid_sizing_chain.py:452` → **2574.19 m**), threaded five hops
(`:478` → `swan_domain.py:729-732` → `:747` → `:397`), and **dropped at `swan_domain.py:1328` —
`if structures:` → `:1351` `return smart`**. Its consumer at `:1358-1359` is unreachable for any
cluster with structures, and L3 exists only for clusters with structures. `smart_size_l3_grid()`
builds the offshore edge from the most-offshore *structure* point plus a 100 m pad (`:1173`,
`:1185-1186`): pin + 761.1 m = **anchor + 970.7 m** against a contour at **2574.19 m**. Its own
docstring at `:1045` claims "Offshore stays the 15 m contour."

**Design:**
1. Add `offshore_distance_m: float | None = None` to `smart_size_l3_grid()`'s keyword-only signature
   (`:1023-1032`), beside `shoreward_distance_m`.
2. Forward it at the delegation site `:1329-1337`.
3. When present and > 0, the offshore edge sits at **anchor + (offshore_distance_m / 1000.0 + 0.1)
   km along `bearing_rad`** — same arithmetic as `:1359`, same anchor branch shape as the shoreward
   edge at `:1199-1206`, assembled into the corners at `:1217-1228`. When absent, keep today's
   structure-derived edge and log at WARNING.
4. **Anchor-relative, mandatory.** Project from `coastline_origin`, never the pin.
   **When `coastline_origin` is None but `offshore_distance_m` is present: keep today's
   structure-derived edge.** (Review flagged this as ambiguous — it is now ruled. Do not mirror the
   shoreward degraded branch; without an anchor the distance cannot be placed honestly.)
5. Lateral terms and shoreward edge untouched.

**Report, do not fix:** `offshore_depth_m` (`:1293`) is passed in and read nowhere;
`spot_deep_points` (`:1297`) has no caller anywhere, so `_assert_grid_contains_points()` — written
because a live run was caught clipping a transect from 2440 m to 950 m — has never executed.

**Compute cost — already paid, not a new decision.**

| | today | restored | 07-19 (working) |
|---|---|---|---|
| cells | 87 × 73 = **6 351** | 244 × 171 = **41 724** | 216 × 216 = **46 656** |
| offshore reach from anchor | 970.7 m | 2 674.2 m | ~2 450 m |

Smaller than what was already running on 07-19, when the SWAN timeout was raised to 3600 s for
exactly this reason. The 870 m grid is the defect, not a cheaper option.

**Live check requires a config re-push, not a forced cycle** — grid sizing runs at config push
(`endpoints/config.py:77`) and geometry is cached. A coordinator who forces a cycle, sees the old
87×73, and concludes the fix failed has made a sequencing error.

**Guard:** `tests/test_grid_edge_origin.py` exercises `_compute_level3_grid()` with **no
`structures` argument** at lines 100, 118, 147 — only the branch production never reaches. The one
structures test at `:286-296` asserts only the shoreward edge. Add a case passing structures *and*
`offshore_distance_m`, asserting the offshore edge lands on the contour.

### C4 — Per-transect bathymetry profiles
**Owner:** `clearskies-api-dev`
**Files:** `services/grid_sizing_chain.py`, `enrichment/bathymetry.py`,
`providers/nearshore/swan.py`, `endpoints/beach_profile.py`
**Must not touch:** `extract_native_profile_from_grid()`'s body; `_band_ray_origin()`
(`swan_runner.py:124-163`)

**Allowlist expanded and storage designed in review.** The original listed only the two producer
files, while the consumers that assign `bathymetric_profile` — `swan.py:1599-1602` and
`beach_profile.py:264-265`, both assigning the same list object — sat outside it, and the cache
format was must-not-touch. As written it recreated "two writers, zero readers," the pattern C1's
preamble ridicules.

**Build, not restore.** `extract_native_profile_from_grid()` (`bathymetry.py:1477-1533`) has exactly
one call site in all history — `grid_sizing_chain.py:556`, per spot. Of its four arguments three are
available per transect; the missing one is a per-transect shoreline anchor, which
`_band_ray_origin()` already computes for the POINTS bands.

**Named artefact:** the profile cache gains a `profiles_by_transect` key — a mapping of transect
index to profile array — alongside the existing per-spot `profile`, which stays for every current
consumer. Additive; nothing existing changes shape.

**Consumers:** `swan.py:1599-1602` and `beach_profile.py:264-265` assign from
`profiles_by_transect[t.index]` when present, falling back to the shared profile with a WARNING when
absent.

**Sequencing:** C1 alone already yields 32 *differently truncated* profiles — same seabed, different
start points — because truncation copies rather than mutates (`_bathy_array()` builds a new array at
`surf_1d_pipeline.py:269-272`). **Run C1 first and measure the spread**, so C4's contribution is
separable.

**Depends on C3.** The profile is extracted over the L3 grid's bbox (`grid_sizing_chain.py:539,
556`) and stops at 11.094 m today. Per-transect profiles are worth little until the grid reaches
15 m.

---

## ⛔ QC GATE C — one gate per task

Every row needs a `file:line` and a live number from the deployed system.

**C1** — distinct `handoffDepthM` count > 1 **on an L3 cycle**; the WARNING fallback line, triggered
deliberately; `git diff` showing signature and return type unchanged; `bestPeakFaceHeight` >
`spotAverageFaceHeight`, both pasted; `peelDirection` counted by value.

**C2** — `openTransectCount` < `transectCount`, both pasted; the shadow log naming `pier(567m)` with
a non-zero count; `"no usable coordinates"` absent from a full cycle's journal; shadowed indices
overlapping PT0–PT12; **the emitted `OBSTACLE` line byte-identical before and after**.

**C3** — `git diff` of signature and delegation site; `CGRID` extent ≥ 2674 m from the anchor on
bearing 238°, line pasted; edge differing from the pin projection by 209.6 m; `coastline_origin=None`
still producing today's placement; regenerated profile's deepest sample ≥ 15 m (today 11.094 m);
both bboxes pasted showing L2 contains L3; **actual L3 wall time against the 827 s baseline, stated
warm or cold**.

**C4** — 32 distinct anchors with spread; depth at a fixed offshore distance across all 32, min/max/
spread; identity check proving the profiles are not one object; the C1-only spread restated for
separability; the fallback WARNING when `profiles_by_transect` is absent.

---

# ⛔ DEPLOY 2 — model fixes



**Rollback:** Deploy 1's commit. Recorded before Deploy 2 begins.

**Known risk, named because the plan previously had no failure path:** the first cycle after C3 runs
a ~41,700-cell L3. If `aa4553d` is working the run is warm; if not it is cold, against a 3600 s
timeout on a 6-thread budget, with the 07-19 precedent at "more than 30 minutes" for 46,656 cells
cold. **If cadence blows, the response is to roll back and bring O1 (rotation) to the operator —
not to shrink the grid, which is the defect.**

---

# PHASE D — Verify the whole chain

### D1 — Cold-start first hour
Previously C5; **moved because its gate opened only post-deploy, making Phase C circular.**
The first output row of every run is the empty initial field (`Hsig 0.014 m`, partitions zero,
`Tm01 1.6 s`) and is published as a forecast hour. That is expected for a cold-started spectral
model and is not itself a defect. `aa4553d` fixes the hotstart. **Check first whether a working
hotstart populates the first hour. Only if it is still empty does suppression get designed** — and
it gets designed then, not now.

## ⛔ QC GATE D — the whole chain

| # | Element | Evidence |
|---|---|---|
| 1 | Every invariant passes | raw log, all nine, no ERROR |
| 2 | One number traced end to end | full chain from the trace, pasted |
| 3 | Surf height vs reference | published vs Surfline and Surf-forecast, deltas stated |
| 4 | Swell partitions vs reference | height, period, direction per partition vs both |
| 5 | The westerly is published | the 6–8 s W component appears in `multiSwell` |
| 6 | Alongshore variation is real | spread of face height across the 32 transects |
| 7 | Cycle completes in cadence | wall time vs schedule interval, warm or cold stated |
| 8 | Health reports `ok` — and has earned it | `status: ok` with every input fresh and zero invariants fired. After Phase C this is the first time in the plan an `ok` is a pass rather than a fail |
| 9 | The admin status page agrees | rendered output showing `ok` for both API and marine |
| 10 | First forecast hour is not the initial field | Hs and Tp of hour 1 |

**Adversarial:** `clearskies-auditor`, with no access to any implementing agent's tests, commit
messages, or reports, attempts to disprove C1–C4 and D1 on the deployed system.

Then `clearskies-docs-author` syncs governing documents to what actually landed — after Gate D, so
the documents describe the verified system rather than the intended one.

---

# Review corrections incorporated

Adversarial review, 2026-07-27. Findings and disposition:

| Finding | Disposition |
|---|---|
| Phases B/C demanded live values from a system that could not exist until Phase D | **Deploy 1 added** before Phase C |
| Gate B's must-fire list included invariant 1, whose defect `7fb75f9` already fixes | must-fire list corrected to 3, 4, 5, 6, 8 |
| C2 ordered work in three files outside its allowlist; `length_m` lookup impossible | **C2 redesigned** at `marine_config.py`, one file |
| C4 computed 32 profiles with nowhere to store or read them | allowlist expanded; `profiles_by_transect` named; consumers designed |
| B1 forbidden from creating the config key and output path it required | universal prohibition amended; artefacts named |
| B2 self-contradicted on observe / refuse / byte-identical | invariants observe only |
| Invariant 7 uncomputable — no depth field exists | rewritten as a provenance check |
| Invariant 4 false-positives on the legitimate L2 constant | skip condition added |
| Invariant 2's tolerance unspecified | 25% |
| Gate A row 7 passed before any change — profiles have no `tools:` frontmatter | A5 corrected to *add* a restriction; row 7 must be shown to have failed first |
| Gate A waived its adversarial pass on a false excuse | adversarial pass added |
| A7 reconciled a phantom | removed |
| Grid sizing is config-time, not per-cycle | noted in B1, invariant 6, C3's live check, and Deploy 2 |
| Dispersion class of defect has no gate coverage | known-answer test mandate added to conventions and A3 |
| The anchor rule still landed in no `rules/` file | **A8 added** |
| Twelve commits would ride to production unverified | Gate B Part 3 |
| No rollback path | added to both deploys |
| **Invariants log to the journal nobody read for six days** | **B3 + B4 added** — the review's highest-value finding |

Operator direction after review (2026-07-27): deliver through the **admin UI**, not an external
monitor. B3 makes the marine health endpoint report a real state — it currently returns a hardcoded
`"status": "ok"` (`endpoints/health.py`) and has done so throughout every defect in this plan, while
the API polled it every 60 seconds. B4 adds an admin status section showing API and marine health
together. Health must distinguish **degraded** (output exists and is suspect) from **failed** (a
required input was unavailable, so nothing was published) — per the standing rule that we never
publish anything not computed with the full model.

Not disputed. One judgment retained against the review's framing: C3's compute cost is presented as
a regression to repair rather than a decision to rule on, because the 07-19 grid was larger and was
accepted with the timeout raised for that purpose.

---

# Open design questions — recorded, NOT tasks

## O1 — Rotate the L3 grid to the beach bearing

L3 is an axis-aligned lat/lon rectangle while the beach runs at 238°. C3's restored edge extends
along that diagonal, inflating both spans: a **2 438 × 1 713 m** box to hold a strip 2 645 m long
and ~370 m wide.

- Rotation is per grid — L3 can rotate while L1 and L2 stay square. Standard SWAN.
- Four hardcoded zeros: `CGRID REG … 0.` (`swan_formats.py:1337`), `NGRID 'inner' … 0.0` (`:1538`),
  `INPGRID BOTTOM/WIND … 0.` (`:1354`, `:1382`).
- **Only the first two change, and they must agree exactly** — the nest's geometry is declared by
  the child in `CGRID` and by the parent in `NGRID`. A mismatch produces a nest reading boundary
  conditions along the wrong line, silently.
- **`INPGRID` does not rotate.** SWAN interpolates at any relative orientation, so bathymetry, DEM
  sampling and wind are untouched. Output points are absolute UTM and unaffected.
- What changes: `mxc`/`myc` derived from a lat/lon bbox at `:258-259` would compute along rotated
  axes; L2 must still contain the rotated rectangle.

Effect: ~265 × 37 ≈ 10 000 cells against 41 724 — **cheaper than today's 6 351 is at a third of the
coverage.** This is the response if Deploy 2 blows the cadence.

## O2 — Merge-versus-rotate cost rule for L3 clusters

**Only arises when two or more spots that each independently trigger L3 fall within clustering
distance.** L3 is triggered per cluster by structure presence or operator classification
(`swan_domain.py:206-213`); a spot with neither runs L1 → L2 → SwellTrack. One pier and one open
beach 400 m apart is not a merge question.

When both trigger, a merged cluster must pick one bearing — the mean. Each member is misaligned by
Δ/2, and a strip of length L needs extra width ≈ **L · sin(Δ/2)**.

For the restored grid (L ≈ 2 645 m, W ≈ 370 m, 400 m separation): merging wins to ~30° of spread,
crossover ~34°, separate wins beyond. **The penalty scales with L**, so C3 makes merging ~2.8× less
tolerant; on today's short grid the crossover sits near 70°, which is why this has never bitten.

`_cluster_spots()` sees only distance. A real rule compares cell counts. Two non-geometric factors:
fixed per-grid cost (two SWAN runs, two hotstarts, two nests — ~4% of solver time), and
**overlapping nests as a correctness question** — two grids computing the same water from the same
L2 boundary without agreeing exactly, with nothing deciding which owns a transect in the overlap.

Not live today: one spot, one cluster. The rule would fire for the first time when a second
L3-triggering spot is added, on live data, with nobody watching.

**Disposition after the 2026-07-27 grid-strategy review:**

- **O1 is promoted to a task.** Its rotation mechanics are correct and are now used by **E3** — but
  applied to the **structure grid (L4)**, not to L3. The coordinator's earlier ruling that rotation
  is pointless because swell does not arrive along the tilt was **wrong for a nested grid**: a nested
  grid receives parent boundary spectra around its *entire* perimeter, so orientation never gates
  energy entry. Rotation here is an area optimization around a fixed physical object, not an attempt
  to align with a variable swell. See findings §3.1.
- **O2 is narrowed and stays open.** Under §0A D2, L3 is a nesting step sized from L4 plus clearance,
  not a long strip along the beach. The `L · sin(Δ/2)` penalty scales with strip length, so a short
  L3 is far more merge-tolerant than the restored strip was. The correctness half of O2 — two grids
  computing the same water with nothing deciding which owns a transect in the overlap — is
  **unchanged and still unresolved**. Not live today (one spot, one cluster).

---

# PHASE E — Grid strategy: the structure grid replaces the L3 strip

**Authority:** operator rulings D1–D8 in
[briefs/SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md](briefs/SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md)
§0A, given in chat on 2026-07-27. Every task below trips at least one architectural trigger; **the
approval is D6's table and nothing else.** An agent that finds itself wanting a change not on that
table stops and reports.

**What this phase supersedes.** **C3 restored L3's offshore edge to the measured 15 m contour
(41 895 cells).** That was correct against the plan as written and is *not* being reverted as a
defect — but the resulting cycle **ran past 75 minutes without completing** against a ~7-minute
baseline, and the review concluded the 15 m offshore edge was a carryover from when L3 was the
fine-detail model. Phase E retires that edge for structure spots and replaces the strip with a small
rotated grid on the structure. **C3's threading work (`offshore_distance_m` through five hops) is
kept** — E4 reuses it.

### Reading order, mandatory before any Phase E task
1. Findings §0A (the rulings) — **not** §1–§8, which are the research record and contain superseded text.
2. Findings §5.1.4 "Misreadings to guard against."
3. This phase's task.
Anything in findings §1–§8 that appears to contradict §0A: **§0A wins.** §5.1.3 in particular is
marked superseded and must not be implemented.

### E0 — Restore service before anything else
**Owner:** `coordinator` (operational; no agent) · **Files:** none — deploy and config only

The 41 895-cell grid is deployed and **no forecast has published since it landed**. Debug tracing
from B1 is still enabled on librewxr, writing daily files.

1. Roll the marine service back to `49839ac` and re-push config so grid sizing recomputes at the
   pre-C3 geometry. **Grid sizing runs at config push (`endpoints/config.py:77`), not per cycle** —
   a forced cycle alone will not resize. This is the same sequencing trap C3's live check names.
2. Disable the B1 trace key in `/etc/weewx-clearskies/marine/network.env`; restart.
3. Confirm a cycle completes and `/health` reports `last_run` advancing.

**This is a service restoration, not a decision on Phase E.** The rollback target is the grid that
was publishing, not an endorsement of the 870 m defect C3 fixed — Phase E replaces both.

### E1 — Structure-grid resolution derived from the tip wavelength
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_domain.py` only
**Must not touch:** L1 and L2 sizing; `_compute_level3_grid()`'s non-delegating branch (1353-1460);
anything in `swan_formats.py` (that is E3/E6/E7)

Today L3's resolution is the constant 10 m. Findings §1.1: SWAN's manual requires mesh size
**1/5 to 1/10 of the dominant wavelength near the tip of the diffracting obstacle** — evaluated at
the **tip**, not everywhere. 10 m was an assumption, never a derivation.

**Design:**
1. Add a module-level helper computing the structure grid's resolution:
   `dx = min(L_tip / 8.0, 15.0)`, **floored at 10.0 m**, where `L_tip` is the local wavelength from
   the dispersion relation ω² = gk·tanh(kd) at the spot's **design Tp** and the tip depth `d_tip`.
2. `d_tip` is read from the **cached FINE profile** at the cluster's most-seaward structure point.
   **Do not interpolate between contour distances** — findings §7 item 2 flags the coordinator's
   6.3 m tip-depth figure as exactly that kind of assumption. If the cached profile cannot supply a
   depth at that point: log WARNING, use the 10.0 m floor, and record the reason.
3. The floor exists for short-period wind-swell coasts where `L_tip/8` would go below the useful
   range. The 15 m ceiling exists because that is the manual's L/5 limit at our periods.
4. Emit `dx` into the sizing cache alongside the grid geometry so E7 can derive `smnum` from it and
   the auditor can read it without recomputing.

**Expected at HB:** Tp 15.27 s, `d_tip` from the profile → `L_tip ≈ 118 m` → `dx = 12.5 m` (≈ L/9.4).
**Do not hardcode 12.5** — findings §5.1.4 misreading 2. It is a result, not a constant.

**Safe against the source data (D7):** HB bathymetry is 10 m, so a 12.5 m grid is *coarser than its
data* and does not interpolate. An agent computing `dx` below the source resolution has produced a
grid that computes interpolation rather than physics — the 2026-07-19 defect. **If `dx` < the source
bathymetry resolution, stop and report.**

**Guard:** known-answer test on the wavelength — solve ω² = gk·tanh(kd) with an independent solver
(Brent), as `tests/test_surf_1d_dispersion.py` already does, sharing no code path with the
implementation. Assert `dx` for a table of (Tp, d_tip) pairs including both clamp boundaries.

### E2 — Structure-grid extent: rotated rectangle on the structure
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_domain.py` only
**Must not touch:** L1/L2; the breaking-depth criterion itself (ADR-093 Amendment 2 §2 — reused
unchanged); `_cluster_spots()`'s distance logic

**The single biggest change in this phase: the 15 m-contour offshore edge is retired.** It made
sense when L3 was the general fine-detail model. The structure grid's job is the structure.

**Design — every quantity is available at config-push time:**
1. **Orientation:** rotated to the structure cluster's **principal axis** (its long axis). At HB the
   pier bears 221°.
2. **Along-structure axis:** from the **breaking-depth contour** (existing criterion, unchanged) to
   the structure's seaward **tip + 1 · L_tip**. The offshore margin exists so the grid boundary sits
   clear of the obstacle's near field. **NOT the 15 m contour.**
3. **Across-structure axis:** the union, over the spot's **swell-climate direction window**, of the
   geometric shadow cast on the shoreward edge, **+ 2 · L_tip beyond the shadow boundary on each
   side**. Include both sides when the climate window crosses the structure axis (at HB: S swells
   shadow the NW side, W/NW windswell the SE side).
   *Basis (findings §3.2):* for directional random seas the diffraction coefficient is ≈ 0.7 on the
   geometric shadow boundary and recovers to within a few percent of 1 within ~2 wavelengths outside
   it; the strongly-modified zone sits within ~2–4 wavelengths of the tip. Directional spreading is
   why the zone is small — real seas fill shadows.
4. **Anchor-relative, mandatory.** Project from `coastline_origin`, never the operator's pin — A8's
   rule. Where `coastline_origin` is None, **stop and report**; do not fall back to the pin.
5. **Sized once, at config push. Frozen thereafter.** No runtime resize, no per-run reshaping by
   swell direction — the standing 2026-07-23 rule (a runtime resize left the grid outside the
   NESTOUT and silently zeroed the swell). Findings §3.3. The per-run saving would be ~1–2 min/day
   against a repealed safety rule and invalidated hotstarts, which are grid-shaped.
6. Run the existing viability test (grid must reach its feature). A structure grid that cannot is
   **disabled at setup**, exactly as today's L3 is — never resized at runtime.

**Expected at HB:** along-pier ≈ 1 000 m, across-pier ≈ 800 m → at 12.5 m, **80 × 64 = 5 120 cells**
(against 41 895 today). Axis-aligned at 10 m the same box is ~16 100 — rotation and tip-scaled
resolution together are the 3–8× win.

**Report, do not fix:** findings §7 item 1 — the pier-base position was read as "124 m offshore of
the spot pin", giving pier ≈ anchor+334 m to anchor+901 m. **Verify against the Overpass way geometry
before sizing.** If it disagrees, report the discrepancy and stop; do not size from an unverified
base.

**Guard:** cell count and both spans for a synthetic cluster at a known bearing with a known
`L_tip`; assert the offshore edge is at tip + L_tip and **not** at any 15 m contour value.

### E3 — Rotated CGRID/NGRID emission
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_formats.py` only
**Must not touch:** `INPGRID BOTTOM` / `INPGRID WIND` rotation (`:1354`, `:1382`) — **these stay
`0.`**

O1's mechanics, now approved (D6 item 3) and applied to the structure grid.

**Design:**
1. `CGRID REG … [alpc]` (`swan_formats.py:1337`) and `NGRID 'inner' … [alpn]` (`:1538`) take the
   structure grid's rotation angle instead of the hardcoded `0.` / `0.0`.
2. **They must agree exactly.** The nest's geometry is declared by the child in `CGRID` and by the
   parent in `NGRID`; a mismatch produces a nest reading boundary conditions along the wrong line,
   **silently**. Emit both from one value, never two computations.
3. **`INPGRID` does not rotate.** SWAN interpolates input fields at any relative orientation, so
   bathymetry, DEM sampling and wind are untouched. Output points are absolute UTM and unaffected.
4. `mxc`/`myc` derivation from a lat/lon bbox (`:258-259`) must compute along the **rotated** axes.
5. L2 must still contain the rotated rectangle — assert it, and fail loudly if not.

**Severable.** If rotation is deferred, E2's design still works axis-aligned at ~16 100 cells
(~15 min cycles instead of ~7). The architecture survives; only the factor-of-2 is lost. **Do not
silently fall back to axis-aligned** — that decision is the operator's.

**Guard:** assert the emitted `CGRID` and `NGRID` rotation values are equal and non-zero for a
rotated structure grid, and that both `INPGRID` lines still emit `0.`

### E4 — L3 rescoped: need-driven, sized from L4
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_domain.py`,
`weewx_clearskies_marine/services/grid_sizing_chain.py`
**Must not touch:** C3's `offshore_distance_m` threading — **it is reused, not reverted**

**Ruling D2.** L3 is built for exactly two reasons and never otherwise:

**Design:**
1. **As the nesting step under a structure grid.** 100 m → 12.5 m is 8:1; L3 at 30–40 m makes it
   2.5:1 then 3.2:1. Extent = the structure grid's footprint **plus clearance of at least 2 parent
   cells on every side**, plus the spot's alongshore span. **Not the 30 m contour** — that rationale
   died with the conditional band.
2. **As the working refraction grid** at an operator-classified point break, headland, or bay.
   Extent per the existing feature-sizing logic; cross-shore span 15 m contour → breaking-depth
   contour. **Diffraction OFF here** (E7).
3. **Neither condition → no L3 at all.** `L1 → L2 → 1D at 15 m`, the current production path,
   byte-identical. **This redesign must not change a single value for a spot with no structure and
   no classified feature** — that is E4's strongest acceptance criterion.
4. If both conditions hold, build **one** L3 covering both roles. **Never two grids stacked
   edge-to-edge** — edge-on-edge nesting is degenerate (findings §5.1.4 misreading 5).
5. **The L2-collar fallback from findings §2.3 is struck.** It existed to hedge the 8:1 jump, which
   L3 now removes.

**Expected at HB:** ~1 500 × 1 300 m at 40 m ≈ **1 400 cells**.

**Guard:** a spot with no structures and no classification produces **exactly** today's grid set —
assert L3 is absent and L1/L2 are unchanged.

### E5 — Handoff selection, and the deep-water reference written down
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/transect_handoff.py`,
`weewx_clearskies_marine/services/surf_1d_pipeline.py`
**Must not touch:** the breaking-depth criterion `1.3 · Hs / 0.73`; `L2_REFERENCE_DEPTH_M = 15.0`
(`transect_handoff.py:79`) — **the constant is unchanged; only which transects use it changes**

**Ruling D3 — the rule findings §5.1.3 got wrong.** Hand off as deep as possible; go shallower only
where 2D physics still matters, and only as far as the grid modelling it reaches.

**Design — first match wins, per transect, per forecast hour:**
```
1. The transect's cross-shore line enters the structure grid's footprint
       → read per-transect POINTS from L4 at the per-hour 1.3·Hs/0.73 depth.
2. The transect lies in a classified refraction feature covered by L3
       → read per-transect POINTS from L3 at the per-hour 1.3·Hs/0.73 depth.
3. Otherwise
       → hand off from L2 at fixed 15.0 m. Unchanged production path.
```
1. **"Touches" = the transect's cross-shore line enters the structure grid's footprint.**
   Operator-accepted definition. Not "the handoff point is inside", not "the spot has a structure".
2. Neighbouring transects MAY resolve to different rules. That is the non-uniform handoff the
   operator explicitly accepted — **not a defect, and not to be smoothed**.
3. **The deep-water reference stays on L2 at the spot's own 15 m contour, in every case.** The
   structure grid never reaches it and can never supply it.
4. **Doc-code sync, mandatory in this task, not deferred:** write into `docs/ARCHITECTURE.md` and
   `docs/manuals/API-MANUAL.md` that the deep-water reference is **L2-sourced and is not the 1D
   model's starting point**, so a future reader does not "fix" a by-design difference. D4.

**Live check:** at HB the structure grid covers all 32 transects, so **every transect must resolve
to rule 1**. If any resolves to rule 3, either the envelope is undersized or "touches" is
mis-implemented — report, do not adjust the envelope to make the check pass.

**Known gap, record it — do not attempt to close it:** rule 2's path and the mixed rule-1/rule-3 case
**cannot be exercised at HB**. They will be written and untested until a spot exists whose structure
grid covers only part of the beach. Nobody may claim these paths are verified.

### E6 — Pier transmission 0.95 → 0.82
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_formats.py` only
(`_OBSTACLE_PARAMS`) **Must not touch:** the jetty / groin / breakwater / seawall rows — all unchanged

**Architectural trigger 1. Approved: D6 item 4.**

SWAN's `TRANSM` is a **wave-height** ratio, not energy (manual). `0.95` passes 95% of height = 90% of
energy and traces to nothing. The measured PT0–PT7 deficit (0.83 vs 0.87 ≈ 0.95) was the model
echoing its own input constant back — **not evidence about the pier**.

**Evidence for 0.82:** Elgar, Guza, O'Reilly, Raubenheimer & Herbers (2001), *Wave energy and
direction observed near a pier*, JWPCOE 127(1):2–6 — the Duck, NC research pier, 561 m,
pile-supported, directly comparable to HB's 567 m. Matching observations required **30–50% energy
blocking** by the pilings ⇒ **Kt_height ≈ 0.71–0.84**. Blocking is strongest for
obliquely-crossing components; at HB swell from 201.9° crosses the 221° pier at ~19° — the
high-attenuation geometry.

**Design:** set the pier class to `TRANSM 0.82`. One value. **Do not implement `TRANS2D`** —
direction-dependent transmission is the physically better shape and is explicitly deferred: one
constant first, calibrate, then decide.

**Do not launder bathymetry through Kt.** Much of Duck's far-field pattern was **refraction over the
scour trench** under the pier, not the pilings. If HB's 10 m DEM contains the trench, that is a
separate resolvable mechanism. **Inflating Kt to cover a missing bathymetric feature would bake a
site-specific data error into a physics constant.** Findings §4.3.

**Calibrate against reality, not the model** (`rules/verification.md`): the observable is the
alongshore Hs gradient across PT0–PT31 versus an independent reference (nearest CDIP/NDBC nearshore
buoy, Surfline per-peak, or operator observation) on an oblique-swell day. **Not a Phase E gate row**
— it needs the right weather. Record it as owed.

### E7 — Diffraction only in the structure grid; smoothing scaled to resolution
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_formats.py` only
**Must not touch:** the `0.2` under-relaxation parameter; wind forcing on any grid (**always on** —
standing rule)

**Design:**
1. **`DIFFRACTION` is emitted for the structure grid and no other grid.** At 30–100 m it is
   sub-resolution — emitting it there is both useless and destabilising, and it "disappears" as cells
   coarsen past L/10. L3, L2 and L1 get none. Findings §5.1.4 misreading 3.
2. `smnum` derives from the grid's own `dx` via the existing project relation
   **εx = ½ · √(3n) · Δx**, target **εx ≈ 45 m**.
3. **Arithmetic check, and it validates the relation:** at Δx = 10 m the relation gives
   √(3n) = 45/5 = 9 → n = **27**, which is exactly today's emitted `DIFFRACTION 1 0.2 27`. At
   Δx = 12.5 m it gives √(3n) = 45/6.25 = 7.2 → n = **17**. An agent whose formula does not reproduce
   27 at 10 m has the relation wrong — **stop and report**.
4. **Never emit bare unsmoothed `DIFFRACTION`** — hard project rule since 2026-07-19.

**Guard:** assert `smnum == 27` at Δx = 10 m and `smnum == 17` at Δx = 12.5 m; assert no
`DIFFRACTION` line is emitted for L1, L2 or L3.

### E8 — Hourly quick update covers every grid that supplies a handoff
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_runner.py`
**Must not touch:** the stationary/non-stationary mode selection — quick updates stay **stationary**
(operator-confirmed, already correct); the 6-hourly full-cycle cadence

**Ruling D5.** Today quick updates run "the finest grid only", which was safe when the finest grid
spanned the whole spot. Under D2/D3 it may cover only part of one, silently leaving transects with no
hourly refresh.

**Design:** the hourly quick update runs **every grid that supplies a handoff under E5's rule** for
this spot — L4 and/or L3 as applicable. A spot whose transects all hand off from L2 gets its existing
behaviour.

**Cost at HB:** L3 + L4 ≈ **6 520 cells**.

**Record, do not act on:** L3 sits in 15–30 m of water where a metre of tide is a few percent depth
change and there is negligible fetch — its hourly refresh carries almost no new information. The
structure grid spans ~2–6 m, where the same metre is a 15–50% change. **That** is where hourly
matters. Stated so nobody later assumes the L3 hourly run is load-bearing.

## ⛔ QC GATE E — grid strategy

Every row needs a `file:line` read after the change and a live number from the deployed system.

| # | Element | Live value proving it ran |
|---|---|---|
| 1 | Structure-grid resolution is derived, not constant | `dx` from the sizing cache = 12.5 m at HB, with the `L_tip` and `d_tip` it came from |
| 2 | `dx` is not finer than the source bathymetry | `dx` vs the DEM resolution actually used (10 m at HB) |
| 3 | Offshore edge is tip + L_tip, **not** the 15 m contour | offshore reach from anchor; must **not** be ~2 574 m |
| 4 | Structure grid is rotated, and `CGRID`/`NGRID` agree | both angles from the emitted INPUT file, equal and non-zero |
| 5 | `INPGRID` still emits `0.` | both lines from the same file |
| 6 | Cell counts | L1 / L2 / L3 / L4 and total; total ≈ 12 600 at HB |
| 7 | Cycle completes in cadence | wall time vs schedule interval, warm or cold stated |
| 8 | A no-structure spot is unchanged | its grid set before and after, identical |
| 9 | All 32 HB transects resolve to handoff rule 1 | per-transect rule, from the trace |
| 10 | Deep-water reference still sourced from L2 | the SPECOUT grid, from the emitted INPUT file |
| 11 | `TRANSM 0.82` emitted for the pier | the `OBSTACLE` line |
| 12 | `DIFFRACTION` on L4 only, `smnum` = 17 | every `DIFFRACTION` line in every emitted INPUT file |
| 13 | Hourly update runs L3 + L4 | grid names in one quick-update run's log |
| 14 | Docs synced | the ARCHITECTURE.md / API-MANUAL.md diff for E5 item 4 |

**Adversarial:** `clearskies-auditor`, given D1–D8 and the expected numbers above but **not** any
implementing agent's tests, commits or reports, attempts to disprove E1–E8 on the deployed system.
Specifically briefed to hunt: a hardcoded 12.5; a 15 m offshore edge surviving anywhere; `CGRID`/
`NGRID` rotation disagreement; `DIFFRACTION` emitted on a coarse grid; and any changed value at a
no-structure spot.

---

# PHASE F — Wind source term in the 1D model

**Authority:** operator ruling, 2026-07-27, recorded in findings §0B.4. **This trips architectural
trigger 1.** The coordinator recommended against it on height impact (2–3%); the operator overruled,
and the coordinator's yardstick was wrong — the value is in the surf scorer's **swell dominance** and
**cross-swell** sub-factors, which currently cannot see a locally generated short-period component.

**Read findings §0B in full before any Phase F task.** §0B.5 (the double-count trace) and §0B.6 (why
option C beat A and B) are the design; this phase implements them.

### F1 — Carry `is_wind_sea` through the partition conversion
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_spectral.py` only
**Must not touch:** `parse_table_pt_partitions()`'s parsing (it already sets the flag correctly at
`:1136`); the descending-Hs sort at `:1207`; `decompose_spectrum()`

`watershed_partitions_to_component_format()` (`:1194-1208`) **discards `is_wind_sea`**, and its own
docstring says so: *"Consuming that distinction is a separate, not-yet-approved change."* **It is now
approved.** This is the whole reason Phase F cannot double-count.

**Design:**
1. Carry `is_wind_sea` into the converted dict, defaulting **False** when absent.
2. **The descending-Hs sort stays.** Consumers rely on it. The flag must therefore be read **from the
   field, never from the index** — after sorting, partition 1 is no longer at index 0.
3. Update the docstring: the distinction is now consumed, by whom, and under what approval.
4. **`classification` is not a substitute and must not be used as one.** It is a period-based proxy
   (`_classify_period`, `:26-29`): a decayed 9 s swell is labelled `wind_swell` and is not a wind
   sea; a wind sea under strong forcing can exceed 10 s.

**Guard:** a converted partition set where the wind sea is **not** the tallest — assert the flag
follows the right partition through the sort.

### F2 — Sample per-spot wind from the field that forces SWAN
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/providers/nearshore/swan.py`,
`weewx_clearskies_marine/services/surf_pipeline_timestep.py`
**Must not touch:** `_stitch_wind()`'s blending; the HRRR/GFS fetch

**Ruling §0B.9 — one wind, not two.** Wind exists as a spatial field (`blended_wind`,
`swan.py:1299`). The 1D model's wind must be sampled from **that same field**, at the spot, for the
same forecast hour.

**Design:**
1. Sample `blended_wind` at the spot's anchor for each forecast hour; carry speed and direction to
   the 1D pipeline alongside `tide_level`.
2. **Never introduce a second wind source** — a station observation or a different forecast product
   would drive SWAN and its own 1D continuation with different winds across the handoff, producing
   plausible, wrong, hard-to-diagnose output.
3. **Follow the tide precedent exactly: refuse rather than substitute.** When wind is unavailable,
   the growth term is **skipped and logged**, never applied with a zero or a guess. See the three
   existing tide guards (`surf_pipeline_timestep.py:110`, `surf.py:954`, `beach_profile.py:1001`).
4. Do **not** thread this across the compute-service HTTP boundary
   (`services/compute_client.py` / `compute_service.py`) — that is a data-contract change
   (trigger 4) and is **not approved**.

### F3 — Depth-limited growth kernel — gated on a known-answer test
**Owner:** `clearskies-api-dev` · **Files:** one new module under
`weewx_clearskies_marine/services/` **Must not touch:** `run_1d_analytical()` — F3 is a standalone
kernel with no caller yet

**Design:**
1. Implement **finite-depth fetch-limited growth**: Young, I.R. & Verhagen, L.A. (1996), *The growth
   of fetch limited waves in water of finite depth. Part 1: Total energy and peak frequency*,
   Coastal Engineering **29**, 47–78. Input: wind speed, fetch, depth. Output: wind-sea Hs and Tp.
2. **Deep-water JONSWAP is the wrong relation and must not be used.** The run goes 15 m → 0 m;
   growth in shallow water is capped by depth well before fetch.

**⛔ HARD GATE — coefficients.** **Two web searches did not surface Young & Verhagen's explicit
coefficients, so none are written in this plan or in the findings document, deliberately.** The
implementing agent must:
- obtain the **primary source** (or Breugem & Holthuijsen 2007, the later revision) and transcribe
  every coefficient from it;
- **cite the equation number and page** for each, in a comment at the constant;
- **stop and report if the source cannot be obtained.** Do not infer, do not reconstruct from a
  secondary summary, do not use a plausible value.

*Why this gate exists:* `TRANSM 0.95` entered this system as a plausible-looking constant that traced
to nothing, and E6 is the cost of removing it. A second one is not acceptable.

**Guard — known-answer test, mandatory (`rules/verification.md`).** Young & Verhagen publish growth
curves: measured height and period against known fetch, wind speed and depth. Assert the
implementation reproduces published points **including at least one in the depth-limited regime**,
where growth has ceased. This must be a genuine independent reference, **not a rearrangement of the
implementation**.

**Design decision, already made — do not re-open.** Apply the relation at each march step using
**local depth** and **cumulative fetch from the handoff point**. The theoretically cleaner
alternative (differentiate the growth curve to get dE/dx and integrate) is **deferred**: the total
contribution is ~0.2 m, and `_combine_partition_hs()` already enforces depth-limited saturation on
the RSS total (`surf_1d_pipeline.py:407`), so a crude estimate is capped correctly by existing
machinery. **Document the approximation at the call site.**

### F4 — Grow the wind-sea partition along the 1D run
**Owner:** `clearskies-api-dev` · **Files:**
`weewx_clearskies_marine/services/surf_1d_pipeline.py` only
**Must not touch:** `run_1d_analytical()` (`surf_1d_analytical.py`) — **the physics module does not
change**; `_combine_partition_hs()`'s RSS and saturation logic; any swell partition's path

**Option C from §0B.6.** SWAN grows the wind sea to the handoff; the 1D model continues it over the
remaining fetch. No double-count by construction.

**Design:**
1. In the per-partition loop, the partition carrying `is_wind_sea == True` — **and only that one** —
   gets F3's growth applied as it marches. Swell partitions are untouched.
2. **Fetch geometry (§0B.7), and this is what stops the double-count returning by the side door:**
   - Use the **onshore component** of wind only, with fetch measured from the handoff point shoreward.
   - **Alongshore wind: do not regenerate.** Its fetch lies inside SWAN's 2D domain, so it is already
     in the handoff spectrum.
   - **Offshore wind: contributes nothing.** Those waves travel seaward, away from the break. Its
     real effect on the wave face is already the surf scorer's job at 15% of the score.
3. At most **one** partition may be flagged. If more than one arrives flagged, log ERROR and grow
   none — that is a parsing defect upstream, not a condition to paper over.
4. Growth is applied **before** breaking, so the grown wind sea breaks through the existing
   Battjes-Janssen path like any other partition.

**Guard:** a two-partition set (one swell, one wind sea) — assert the swell partition's output is
**byte-identical** to the pre-change result and only the wind-sea partition changed.

### F5 — Fallback: synthesize a wind-sea partition when SWAN handed none over
**Owner:** `clearskies-api-dev` · **Files:**
`weewx_clearskies_marine/services/surf_1d_pipeline.py` only

**Option B from §0B.6, surviving only as a fallback** — it cannot double-count because there is
nothing to double.

**Design:**
1. Fires **only** when *both*: no arriving partition is flagged `is_wind_sea`, **and** there is a
   non-zero onshore wind component.
2. Synthesize one partition from F3 at zero initial energy, direction = the onshore wind direction,
   and append it to the partition list. It then flows through F4 and `_combine_partition_hs()`
   normally.
3. **Log at INFO every time it fires, with the reason** — this path also covers the bulk-parameter
   degradation route, and silent synthesis would hide a partition-parsing failure.

## ⛔ QC GATE F — wind source term

| # | Element | Live value proving it ran |
|---|---|---|
| 1 | `is_wind_sea` survives the conversion and the sort | a live partition set with the flag on a non-tallest partition |
| 2 | Coefficients are cited to equation and page | the source comments at each constant |
| 3 | Known-answer test passes in the depth-limited regime | the published point, expected vs computed |
| 4 | Wind comes from `blended_wind`, not a second source | the sampling call site |
| 5 | Missing wind skips growth, never zero-substitutes | log line from a forced missing-wind run |
| 6 | Only the wind-sea partition changed | swell partition output, before vs after, identical |
| 7 | Alongshore/offshore wind generate nothing | three forced runs: onshore, alongshore, offshore |
| 8 | Depth saturation still caps the RSS total | combined Hs vs γd at the shallowest profile point |
| 9 | F5 logs when it fires | INFO line with the reason, from a forced no-wind-sea run |
| 10 | Magnitude is in the expected range | wind-sea Hs at the break for ~15 kt onshore; ~0.2 m expected — **an order-of-magnitude miss means the relation is wrong, not the expectation** |

**Adversarial:** `clearskies-auditor`, given §0B and the expectations above but **not** any
implementing agent's tests, commits or reports. Specifically briefed to hunt: a coefficient with no
citation; wind sea grown from alongshore or offshore wind; the flag read by index rather than by
field; any change to a swell partition; and a second wind source.

---

# Phase E/F provenance

Both phases originate in the 2026-07-27 grid-strategy review, whose research record is
[briefs/SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md](briefs/SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md)
and whose question framing is
[briefs/SWAN-GRID-STRATEGY-RESEARCH-BRIEF.md](briefs/SWAN-GRID-STRATEGY-RESEARCH-BRIEF.md).

**Owed measurements — not gate rows, but not to be lost** (findings §7, as narrowed by §0A):

| # | Measurement | Why it is still owed |
|---|---|---|
| 1 | Pier-base position vs Overpass way geometry | E2 sizes from it; currently an assumption |
| 2 | Tip depth from the cached FINE profile | E1 uses it; the 6.3 m figure was interpolated |
| 3 | Does HB's 10 m DEM contain the pier scour trench? | Decides whether trench refraction — **dominant at Duck** — is in or out of our model. Highest-value single check in the review. |
| 4 | L2 vs L3 handoff spectra at the same points | Demoted from a gate to a measurement of record: D2 chose L2-direct for open beaches. Read both in one run and compare; **no separate A/B configuration needed** |
| 5 | Nest boundary quality at 100 m → 40 m → 12.5 m | The 8:1 jump is gone, so this is now routine rather than a flagged risk |
| 6 | `TRANSM` calibration on an oblique-swell day | E6; needs the right weather |
| 7 | Wall-clock vs cell count | The first structure-grid cycle timestamps it for free. Measured scaling is already **worse than linear** (3.8× cells → >10× time), so small-grid estimates are the trustworthy end |
