# Marine Model Restoration & Verification Plan

**Created:** 2026-07-27
**Revised:** 2026-07-27 after adversarial review (findings incorporated; see "Review corrections")
**Status:** APPROVED — not started
**Repos:** marine = `repos/weewx-clearskies-marine`, meta = repo root

**Sequence:**
Phase A (coordinator alone) → **VSCode restart** → Phase B → **Deploy 1** → Gate B →
Phase C → **Deploy 2** → Gate C → Phase D → Gate D

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

**Requires the word "push" from the operator in chat.** `scripts/deploy-marine.sh`, then force a
cycle.

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

**Requires the word "push".** Deploy, **re-push config** (C3's grid sizing is config-time), force a
cycle.

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
