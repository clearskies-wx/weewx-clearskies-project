# Marine Model Restoration & Verification Plan

**Created:** 2026-07-27
**Revised:** 2026-07-27 after adversarial review (findings incorporated; see "Review corrections")
**Revised again:** 2026-07-28 — Phase E (E0–E13, plus the untracked E2b and the F1 projection fix) is
now **DONE at code/test level, all commits pushed**. Docs-only consolidation pass on this date; no
code changed. See "Phase E session log, 2026-07-28" in the decision log below.
**Status:** Phases A–C landed. **Phase E (all tasks E0–E13, plus E2b and the projection fix) landed
code/test level 2026-07-27/28.** Gate E's live rows (deploy + config re-push required — see Gate E
preamble) are the only work still owed before Phase F.
**Repos:** marine = `repos/weewx-clearskies-marine`, meta = repo root

**Sequence:**
Phase A ✅ → Phase B ✅ → **Deploy 1** ✅ → Gate B (rows 3/5/8/11/13 outstanding) →
Phase C (C1/C2/C3 ✅ landed; **C4 superseded by E10**) →
**Phase E (E0–E13 ✅ all code/test level, plus E2b ✅ and the F1 projection fix ✅)** → Gate E ⬜ (live
rows owed — deploy + config re-push, see Gate E preamble) → Phase F (F1–F5) → Gate F → Phase D (D1) → Gate D

---

# ▶ START HERE

> ## ⛔ 2026-07-31: ALL WORK REDIRECTED TO PHASE R (end of this document)
>
> On 2026-07-31 the marine model **stopped publishing entirely** after the 11:13 deploy of
> `4828d99` (geometry plan G2 + the G1 facing going live). The full evidence-backed diagnosis,
> the recovery tasks, the test purge, the brief/manual reconciliation, and the QC hardening are
> in **[PHASE R](#phase-r--2026-07-31-regression-recovery--anti-regression-hardening)** at the
> end of this file. **Phase R runs before Phase F and Phase D and before ANY further work on
> `MARINE-GEOMETRY-MODEL-PLAN.md`.** The geometry plan is suspended until Gate R passes.

**Every task and gate in this document carries a status marker.** `✅ DONE` · `⬜ NOT STARTED` ·
`⛔ SUPERSEDED` / `NEVER WALKED` · `⚠️ PARTIAL`. If a heading has no marker it is not a task.

| | State |
|---|---|
| **Phase A** (A1–A8) + Gate A | ✅ Done, gate passed |
| **Phase B** (B1–B4) + Deploy 1 | ✅ Done |
| **Gate B** | ⚠️ **Partial** — rows 3, 5, 8, 11, 13 never passed → relocated to **Gate E 21–24**, **Gate F 11** |
| **Phase C** — C1, C2, C3 | ✅ Done (`2ab0a2a`, `de71775`, `9b4fc45`) |
| **Phase C** — C4 | ⛔ Shipped as `060a56b`, **not deployed**, premise removed by Phase E → reworked as **E10** |
| **Gate C** | ⛔ **Never walked** → rows relocated to **Gate E 18–20** |
| **Phase E** — E0 | ✅ Done — service **stopped and disabled** on librewxr, deliberately |
| **Phase E** — E1, E6, E11, E12 | ✅ **Done code/test level** (2026-07-27, commits `19b0d4b`…`af02d19`, pushed) — adversarially audited; Gate E live rows still owed. E11 item 2 open for Gate E. See [briefs/PHASE-E-SESSION-LOG-2026-07-27.md](briefs/PHASE-E-SESSION-LOG-2026-07-27.md) |
| **Phase E** — E13 | ✅ **DONE code/test level** (2026-07-27, new session): marine `8d87ad2`+`1307386`, api `5ca6a93`+`3444fa1`, stack `19d9332`, guards `634c430`. Persisted real OSM geometry through wizard→api→marine; deleted the pin projection. **Coordinator caught + fixed a latent contract bug**: configobj cannot round-trip a nested coord list — JSON-string encoding chosen, decode on both read sides. Gate E rows 25–27 owed live (need deploy + wizard re-run). See session log "2026-07-27 (continued)" |
| **OPERATOR RULING 2026-07-27** | **Structure grid dx = constant 10 m** ("just use a 10m grid for when L4 is needed, period"). Retires E1's `min(L_tip/8,15)` derivation and **kills the `design_tp_s` config key** — E2's design-Tp blocker is CLOSED. E2 uses a fixed ~15 s representative period only for the grid-EXTENT margin (a sizing constant, not a published value). See session log |
| **Phase E** — E2, E2b, E3, E4, E5, E7, E8, E9, E10 | ✅ **DONE code/test level** (2026-07-27/28) — `7ea961b`+`97e08d1` (E2), `9ceab5d`+`53abe07`+`c3f22f7`+`e14baa2` (E2b, untracked task, added mid-session), `49df65c`+`53abe07`+`af7bcda` (E3), `6b48abd` (E4), `2bad206`+`d68465a` (E5), `d517084`+`af7bcda` (E7), `618378c`+`bbcec8f`+`c3fa5b6`+`1b7699b`+`0979b99` (E8, redesigned), `416e1fc`+`255d192`+`0b1cb34` (E9), `054df69` (E10). All pushed. Gate E's live rows are the only work not yet done — they require a deploy plus a marine-config re-push (see Gate E preamble and the new "Deploy requirement" note below Gate E) |
| **NEW, not an original E-task** — **F1 projection fix** (UTM-zone-straddle, operator Option A) | ✅ **DONE**, adversarially audited clean — `f6033ed`+`dba0fd4`+`55c3964`+`1584136` (lock) + `71939fd`+`b136f15` (antimeridian-aware F2). See "Projection fix" subsection under Phase E |
| **Phase F** (F1–F5), **Phase D** (D1) | ⬜ Not started |

### Start at E1

**E0 is done.** The marine service is **deliberately stopped and disabled** on librewxr (operator
ruling, 2026-07-27) — it was looping on the 41 895-cell grid, burning ~75 min per cycle to publish
nothing. Finding it `inactive` is expected, not a new failure. **Read E0's restart order before any
deploy** — a deploy alone re-enables the service but does *not* resize the cached grid, which would
restart the loop.

**➡ First implementation task: [E1](#e1--structure-grid-resolution-derived-from-the-tip-wavelength).**
Self-contained, one file, gated on a known-answer dispersion test — and **every other Phase E
geometry task depends on the `dx` it derives**, so nothing else in Phase E should start before it
lands.

Nothing is deployed or tested until Phase E's geometry is in place. There is no live system to check
against in the meantime, so **every Phase E task's evidence is code-level and test-level until the
service comes back**; Gate E's live rows are collected in one pass after the restart.

### Before dispatching any Phase E or F agent

Read, in this order: findings **§0A** (grid rulings) and **§0B** (wind); the Phase E preamble's
reading-order note; then the task. **Findings §1–§8 are the research record and contain superseded
text — §0A/§0B win on every conflict.** §5.1.3 in particular is marked superseded and must not be
implemented.

**Phase D has been physically moved to sit below Gate F**, so document order *is* execution order.
It previously sat immediately after Phase C — which is done — so anyone reading top-down would have
started it now. Hotstarts are grid-shaped and Phase E invalidates every one; Phase F changes the
published partitions Gate D checks.

**The "Reality reads" section sits before Phase E**, because its first read happens at Gate E. Left
inside Phase D it would have been read too late to execute.

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

### A1 — One canonical architectural block  ✅ **DONE**
**Owner:** coordinator · **Files:** `CLAUDE.md`, `~/.claude/CLAUDE.md`
**Design:** The block exists twice, near-verbatim. Project `CLAUDE.md` keeps the canonical full
text. Global keeps only the one-sentence rule, the seven triggers as a bare list, and a pointer.
**Must not touch:** the trigger wording. Deduplicate, do not re-draft.

### A2 — Collapse agent rules into `rules/agents.md`  ✅ **DONE**
**Owner:** coordinator · **Files:** new `rules/agents.md`; `rules/clearskies-process.md`, `CLAUDE.md`
**Design:** Six locations hold agent rules — `CLAUDE.md` §"Git safety — agents and coordinator",
and `clearskies-process.md` §"Agent orchestration" (121), §"Architectural change block" (207),
§"Scope binding before agent dispatch" (232), §"Agent prompt requirements" (245), §"False-claim
protocol" (263). Move all six into one file, once; leave a one-line pointer at each origin.
**Must not touch:** the substance of any rule. Relocation and deduplication only.

### A3 — Collapse verification rules into `rules/verification.md`  ✅ **DONE**
**Owner:** coordinator · **Files:** new `rules/verification.md`; `clearskies-process.md`, `CLAUDE.md`
**Design:** Move `clearskies-process.md` §"Audit rules" (276), §"Round-close verification gate"
(296) and its steps (300-337), §"Validate against reality, never against the model's own output"
(654); plus `CLAUDE.md` §"Self-audit before delivering" and §"Prompt faithfulness". Add: the
three-layer model (**guard** = agent-written unit test, a regression guard, never evidence the
system works / **invariant** = runtime assertion on real data / **adversarial** = auditor who never
sees the implementing agent's work); and the **known-answer test mandate** for numerical kernels,
with `tests/test_surf_1d_dispersion.py` cited as the pattern.

### A4 — Rewrite the six agent profiles  ✅ **DONE**
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

### A5 — Agents may not spawn agents  ✅ **DONE**
**Owner:** coordinator · **Files:** the six profiles
**Design:** **The profiles currently have no `tools:` frontmatter at all** — they inherit
everything, including `Agent`. So this task *adds* a restrictive `tools:` line to each, omitting
`Agent` and `Task`, and states the prohibition in prose. (Review finding: the original design said
"remove `Agent`/`Task` from every profile's tool list," targeting something that does not exist,
and its gate row would have passed before any change was made.)

### A6 — Create `rules/coordinator.md`  ✅ **DONE**
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

### A7 — Deduplicate the remainder  ✅ **DONE**
**Owner:** coordinator · **Files:** `rules/coding.md`
**Design:** Two sections are both numbered 6 (§6 Internationalization at 474; §6.1 Rules at 565,
under §7 Charts). Fix the numbering. **Do not look for a `CLAUDE.md` counterpart to §1 "A model
runs on all its inputs" — review confirmed none exists in either CLAUDE.md.**

### A8 — Write down the anchor rule *(new; review finding)*  ✅ **DONE**
**Owner:** coordinator · **Files:** `docs/ARCHITECTURE.md` or the relevant manual; `rules/coding.md`
**Design:** Mechanism 4 is not closed. The rule — profile distances are measured from the coastline
anchor, never the operator's pin, because that is how `find_depth_contour_distance()` generates
them — currently lives in a docstring (`swan_domain.py:758-783`), in tests, and in this plan. Plan
files get archived; that is precisely how the rule died the first time. State it as a fact about
the data, cite the generating code, and put it somewhere a future implementer reads before writing
grid or profile code.

---

## ⛔ QC GATE A — governance  ✅ **PASSED**

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

### B1 — DEBUG trace  ✅ **DONE**
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

### B2 — Runtime invariants  ✅ **DONE**
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

### B3 — Marine health reports a real state *(new; the review's highest-value finding)*  ✅ **DONE**
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

### B4 — Admin status page *(new; operator direction, 2026-07-27)*  ✅ **DONE**
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

## ⛔ QC GATE B — observability, and the twelve commits  ⚠️ **PARTIAL** — rows 3, 5, 8, 11, 13 never passed; relocated to Gate E 21–24 and Gate F 11

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

### C1 — Per-transect handoff reaches the pipeline  ✅ **DONE**
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

### C2 — Populate structure coordinates at config parse  ✅ **DONE**
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

### C3 — L3 offshore edge returns to the measured 15 m contour  ✅ **DONE**
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

### C4 — Per-transect bathymetry profiles — ⛔ SUPERSEDED BY E10, DO NOT IMPLEMENT AS WRITTEN

> **C4 shipped as `060a56b` and is committed but NOT deployed** (librewxr runs `de71775`). Phase E
> then removed its premise: it extracts the profile over **the L3 grid's bbox** and depends on C3
> having pushed that grid out to the 15 m contour. Under Phase E an open-beach spot has **no L3 at
> all**, and a structure spot's L3 is a small grid hugging the structure — neither spans to 15 m.
> **E10 re-bases extraction on the transect itself and drops the L3 dependency.** It is a **rework of
> `060a56b`**, not a fresh build: the allowlist, the `profiles_by_transect` artefact, the consumers,
> and the C1-first measurement all carry over. Retained below for that detail.

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

## ⛔ QC GATE C — one gate per task  ⛔ **NEVER WALKED** — rows relocated to Gate E 18–20

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

# ⛔ PHASE D IS NOT HERE. IT RUNS LAST, AFTER GATE F.

**Phase D used to sit at exactly this point — immediately after Phase C. Phase C is done, so anyone
reading this document top-down would have started Phase D now.** This plan exists because agents did
what was in front of them; leaving execution order and document order disagreeing would have been the
same mistake in a new costume.

**Phase D has been physically moved below Phase F.** Document order is now execution order.

Why it runs last:
- **Hotstarts are grid-shaped.** Phase E changes every grid's geometry, invalidating every hotstart.
  D1 is *about* whether a working hotstart populates the first forecast hour — run before E, its
  result is thrown away and re-run anyway.
- Phase F changes the published partitions Gate D row 4 checks. Running D before F validates a chain
  that is about to change.

**What Phase D is for:** it is the **only place in this plan where output is checked against the real
world**. Every other gate — guards, invariants, live checks — compares the system against its own
design, which cannot catch a design that is wrong. Gate D's reference comparisons are the sole
external check. That is worth having, and it is worth having *once, at the end, on the finished
system*.

**➡ Next work is E0, not D1.**

---

# Reality reads — the only external check in this plan

**Placed here, before Phase E, because the first read happens at Gate E — long before Phase D.**
Left inside Phase D it would have been read too late to execute.

Guards, invariants and live checks all compare the system to its own design. Three independent
physics changes are about to land — grid geometry (E1–E4), **`TRANSM 0.95 → 0.82`** (E6), and the
**wind source term** (Phase F). Checked only once at the end, a wrong result cannot be attributed to
any of them.

**Protocol — the same read, at each gate. Costs one reference page view each.**

| When | What it establishes |
|---|---|
| **Gate E** | Grid geometry **and** `TRANSM 0.82` together |
| **Gate F** | The wind source term alone |
| **Gate D** | The finished system |

Each read records: published surf height, per-partition height/period/direction, the reference values
(Surfline and Surf-forecast), and the deltas. **Same spot, same forecast hour, conditions stated.**

**⚠ There is no pre-refactor baseline, and one cannot be manufactured.** The deployed configuration
cannot complete a cycle, so it publishes nothing to read. The configuration before it had the
collapsed 870 m grid — a *known-defective* baseline whose numbers would mean nothing. **Every
configuration in this window is defective in a known way.** Recovering a baseline would mean
deploying a grid we already know is wrong, purely to measure it. Not worth it — the operator's
ruling is that the model is being refactored, not propped up.

**Consequence, stated so it is not discovered later:** Gate E's read is the **first** data point, so
"is this better than before?" is unanswerable by this method. What the protocol still delivers is
Gate F attributable against Gate E, and absolute agreement with reference at Gate D. Grid and
`TRANSM` also remain inseparable from each other — E6's own calibration on an oblique-swell day is
the instrument for `TRANSM` specifically, and is already recorded as owed.

---


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

## Carried forward from Phases A–C — relocated here, because a closed phase never gets revisited

**Operator ruling, 2026-07-27:** *"If anything changes in A–C, those changes need to be moved to
D–F, or else they will never get fixed."*

Phases A–C are closed. Anything still owed from them has **no owner and no gate** where it currently
sits. Every item below is therefore **relocated into Phase E or F and owned there**. This table is
the authoritative list; an item not on it and not in a live phase is not being worked on by anybody.

| Owed from | What | Relocated to |
|---|---|---|
| **C4** | Implemented as `060a56b`, **committed, never deployed**; its L3-bbox extraction basis is broken by Phase E | **E10** — rework, not rebuild |
| **Gate C** | **Never walked.** C1/C2/C3 were accepted individually; the gate itself never ran | **Gate E rows 18–20** below |
| Gate C row for C3 | *"L3 grid ≥ 2 674 m"* — **now wrong by design.** Phase E retires that edge | **struck**; replaced by Gate E rows 3 and 15 |
| **Shadow classification** | Two call sites still pass no structures; C2 fixed only one path | **E11** |
| **Gate B rows 3, 5, 8** | Never passed | **Gate E rows 21–23** below |
| **Gate B row 11** | Deep-water reference returned **1 row, not 67** | **Gate E row 24** — and it is a prerequisite for the **Reality reads**, which read that reference |
| **Gate B row 13** | **No tide field in the published payload** | **Gate F row 11** — Phase F touches the same publish path, and tide is already computed correctly (findings §0B.1); this is a plumbing gap, not a physics one |

**Nothing on this list may be closed by asserting it was already done in A–C.** Each needs a live
value from the deployed system, at the gate it has been moved to.

### E0 — Stop the thrash loop  ✅ **DONE — option C, operator ruling 2026-07-27**
**Owner:** `coordinator` (operational; no agent) · **Files:** none — deploy and config only

> ### ✅ Executed: the marine service is deliberately STOPPED and DISABLED
>
> **Operator ruling:** *"just stop the service until you are ready to deploy and test."*
>
> ```
> systemctl is-active   weewx-clearskies-marine  →  inactive
> systemctl is-enabled  weewx-clearskies-marine  →  disabled
> swan processes: 0   ·   listeners on :8780: 0
> ```
> `disabled` means it does **not** come back after a reboot. There is no timer unit — cycles are
> driven by the service's own internal loop, so this stops them completely.
>
> **`weewx-clearskies-marine` being `inactive` on librewxr is EXPECTED, not a new failure.** Anyone
> checking service health during Phase E will find it down. That is this ruling, not a defect.
>
> **⚠ The trap on the way back up.** `scripts/deploy-marine.sh` runs `systemctl enable` and
> `restart`, so **the next deploy brings the service back automatically** — no manual re-enable. But
> the grid geometry is still cached in `/etc/weewx-clearskies/swan_grid_sizing.json` at **41 895
> cells**, and a deploy does not resize it. **A deploy alone therefore restarts the thrash loop.**
>
> **Order on restart is mandatory:**
> 1. Phase E geometry code deployed, **then**
> 2. **config re-pushed** so sizing recomputes (`endpoints/config.py:77` — sizing is config-time, not
>    per-cycle; a forced cycle will not resize), **then**
> 3. confirm `/health` shows `last_run` **advancing across two consecutive cycles**.
>
> Options A, B and D below were not taken and are retained only to show what was weighed.

**Measured state, 2026-07-27, immediately after the hung cycle was killed:**
```
status: ok | run_in_progress: True | last_run: 2026-07-27T19:57:32Z   (1 swan process)
```
**The system is in a loop.** Restarting the service killed the hung cycle, and the scheduler
immediately started another on the **identical 41 895-cell grid**. Grid geometry is cached in
`/etc/weewx-clearskies/swan_grid_sizing.json` — **a persisted file a restart does not touch** — so
every new cycle rebuilds the same oversized domain, overruns, and publishes nothing. `last_run` has
not advanced since 19:57:32Z.

**Restarting the service is NOT a fix and must not be recorded as one.** It buys exactly one cycle.

**Four options. This is the operator's call, not the coordinator's**, because two of them change the
operator's own spot config or revert shipped work.

| | Action | Consequence |
|---|---|---|
| **A** *(recommended)* | **Temporarily remove the pier structure from the spot config** | Config value only, no code change. L3 is triggered by structure presence (`swan_domain.py:206-213`), so with no structure the spot runs `L1 → L2 → 1D at 15 m` — **exactly the open-beach path Phase E gives it anyway** — at ~6 100 cells. Forecasts publish. Reversed by re-adding the structure at Phase E. Loses pier modelling meanwhile, **which currently produces `shadowed_count: 0` regardless** — that is E11 |
| B | Revert C3 (`9b4fc45`) | Restores the pre-C3 grid, but that is the **collapsed 870 m defect**. Tangles with E4 and E10, which reuse C3's `offshore_distance_m` threading, and with C4 (`060a56b`), which builds on it |
| C | Stop the marine timer | No cycles, no thrash, no publishing. Cleanest pause; the site goes fully stale |
| D | Leave it | Every cycle burns ~75 min of CPU to publish nothing, indefinitely |

**Not blocking on the trace.** B1's debug tracing is still on and totals **242 KB** — not a disk
concern, and **Gate E rows 21–22 need it**. Leave it enabled.

**Whatever is chosen, the acceptance criterion is the same:** `/health` shows `last_run` **advancing
across two consecutive cycles**. Not "the service restarted." Not "a cycle started."

### E1 — Structure-grid resolution derived from the tip wavelength  ⛔ **SUPERSEDED by the 2026-07-27 "constant 10 m" operator ruling**
> The wavelength derivation (`min(L_tip/8,15)`, floor 10) is retired: **structure grid dx = 10.0 m, fixed**. E1's landed code (`19b0d4b` `compute_structure_grid_resolution` / `tip_depth_from_fine_profile`, guard `f03d688`+`9331841`) is now dead — it has no caller. E2 uses the constant directly; E1's helper may be deleted in E2's commit. **`design_tp_s` is off the table.** Original E1 spec retained below for history only.
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

### E2 — Structure-grid extent: rotated rectangle on the structure  ✅ **DONE code/test level** — landed as `7ea961b` (feat) + `97e08d1` (guard)
> **Changes from the 2026-07-27 rulings:** resolution is now **fixed 10 m** (not derived — E1 superseded). The design-Tp blocker is gone. E2 still sizes the grid-EXTENT margins from a wavelength; per the ruling, compute that wavelength from a **single fixed representative period (~15 s) as a module-level sizing constant applied to every spot** — it affects grid extent/cell count only, never a published value. Grid geometry is sized from the **real OSM coordinates** E13 persists, so E13 must be deployed and the HB wizard re-run (coordinates in `marine.conf`) before E2's config-push sizing is exercised live.
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

### E2b — Run L4 as a nested inner grid under L3-as-middle  ✅ **DONE code/test level** — landed as `9ceab5d` (part 1: bathymetry/datum/cache plumbing + rotated-grid params) + `53abe07` (E3-amendment: decouple child NGRID rotation from parent CGRID, required to complete rotated nesting) + `c3f22f7` (part 2: run L4 as the nested inner grid under L3-as-middle) + guard `e14baa2`
> **Not in the plan as originally written — tracked and dispatched mid-session** (coordinator finding, 2026-07-27, full detail in
> [briefs/PHASE-E-SESSION-LOG-2026-07-27.md](briefs/PHASE-E-SESSION-LOG-2026-07-27.md) "TRACKED GAP — NEW TASK E2b"). **Owner:**
> `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_runner.py`, `weewx_clearskies_marine/providers/nearshore/swan.py`
> (part 1); `weewx_clearskies_marine/services/swan_formats.py` (E3-amendment only, decoupling child/parent rotation)
>
> E2 sizes and E4 caches the L4 structure grid, but a read-only survey found **zero L4 references anywhere in the run
> pipeline** — L4 was sized and cached, never executed. E2b wires L4 in as SWAN's nested inner grid under L3-as-middle
> (L1→L2→L3→L4), so L4 actually emits CURVE/POINTS output the handoff selection (E5) can read. Adversarially audited
> clean on both parts (0 blocker/major findings), including the real asymmetric-rotation case.

### E3 — Rotated CGRID/NGRID emission  ✅ **DONE** — landed as `49df65c` (feat) + `53abe07` (E3-amendment, decouples child NGRID rotation/geometry from parent CGRID — required for E2b's rotated nesting) + guard `af7bcda`
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

### E4 — L3 rescoped: need-driven, sized from L4  ✅ **DONE** — landed as `6b48abd`
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

### E5 — Handoff selection, and the deep-water reference written down  ✅ **DONE** — landed as `2bad206` (feat, three-way first-match handoff + doc-sync D4) + guard `d68465a`
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

### E6 — Pier transmission 0.95 → 0.82  ✅ **DONE code level** (2026-07-27: `dba85ea`, Elgar 2001 cited; adversarial pass clean — no second 0.95 path. Gate E row 11 live check and oblique-swell calibration still owed)
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

### E7 — Diffraction only in the structure grid; smoothing scaled to resolution  ✅ **DONE** — landed as `d517084` (feat) + guard `af7bcda`
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

### E8 — Rebuild the hourly stationary "fill" update for the D1 architecture  ✅ **DONE code/test level** — landed as `618378c` (full-nest stationary runner, reuse WW3, no hotstart save) + `bbcec8f` (stationary fill runs the 1D chain + merges swelltrack) + `c3fa5b6` (wire hourly-fill/6h-full into runner loop) + audit fix `1b7699b` (F2 — fill reports updated-vs-skipped honestly) + guard `0979b99`. Plus the coupled F1 work: `c3ceaa8` (cold-start clear on geometry-changing config push, audit F1 option A) + `12907ca` (geometry-changing config push signals an immediate full run, operator ruling 2026-07-28)
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_runner.py`,
`weewx_clearskies_marine/providers/nearshore/swan.py`, `weewx_clearskies_marine/service.py`
**Must not touch:** the T4.2 hotstart-isolation rule (a stationary run never saves/overwrites the
nonstationary chain's hotstart); the full non-stationary run's own path (`_run_all_spots_locked` /
`run_3level`); the C-76 "never fabricate a WW3 boundary" rule.

> **SUPERSEDES the original E8 below (operator ruling 2026-07-27).** The original E8 ("add L4 to the
> finest-grid-only quick update") was scoped on a premise that does not hold. Investigation while
> preparing to dispatch it found:
>
> 1. **The quick-update path is a SWAN-only-era remnant.** `run_stationary_level3` /
>    `_run_quick_update_locked` are a straight port of the old `run_stationary_inner` path. They emit
>    **SWAN grid points only** — they never invoke the D1 handoff→SwellTrack 1D chain
>    (`_precompute_swelltrack_for_spot`) that produces the actual surf forecast under the current
>    architecture. Even wired, they would refresh SWAN numbers and leave the surf card stale.
> 2. **It was never wired in.** The marine runner loop (`service.py`) fires **only full runs**, on
>    every HRRR cycle change; `run_quick_update` is called from nothing (its own docstring says so).
> 3. **A nested grid from a cached parent boundary is a stale-boundary shortcut.** L3-only-from-cached-
>    L2-NESTOUT refreshes a child grid's interior wind but freezes its offshore boundary at the last
>    full run, and refreshes **no** open-beach (L2-only) spot at all.
>
> **Corrected design (operator-approved, cadence + shape ruled 2026-07-27):**
>
> - **Cadence.** Full **non-stationary** run every **6 h**, on the extended HRRR cycles (00/06/12/18Z,
>   which run the extended 48–72 h forecast). **Hourly stationary "fill"** on the intervening HRRR
>   cycles. The loop currently fires a full run on *every* cycle — this throttles full to 6-hourly and
>   adds the fill between (cadence change, trigger 6, operator-approved).
> - **The fill runs the full nest stationary**, not L3-only: L1→L2→L3→L4, single snapshot, latest HRRR
>   wind. L1 **reuses the last full run's WW3 boundary files** already on disk in the persistent
>   `swan_work/level1/` (same pattern the current code uses to reuse `level2/nest_out.dat`; deep-water
>   swell changes slowly, so reusing the last-fetched WW3 is correct — operator ruling). Because L1
>   runs, the WW3 boundary object is naturally in scope and the C-76 fabrication rule is never touched.
>   Warm-start from the last full run's hotstart, **do not save** one (T4.2).
> - **Then run the 1D chain** — `_precompute_swelltrack_for_spot`, exactly as `_run_all_spots_locked`
>   does — so the surf card (the 1D product) refreshes, not just SWAN grid points. Merge into cache the
>   same way, including the `swelltrack` payload key.
> - **Wire into the runner loop** at the new cadence.
>
> **Feasibility verified 2026-07-27:** `swan_work` (`/var/run/weewx-clearskies/swan`) is persistent
> (no tmpdir cleanup on the 3-level path); the full run writes WW3 boundary files to `level1/` there;
> `_precompute_swelltrack_for_spot` is a reusable function the full path already calls after
> `run_3level`. The three pieces are coupled through the workdir/orchestration contract → dispatched as
> **one** task, guards + a follow-on adversarial audit (production-loop change = highest verification
> tier).

---

**Original E8 (SUPERSEDED — retained for the record):**

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

### E9 — Rescope the two invariants Phase E breaks  ✅ **DONE** — landed as `416e1fc` (rescope invariant 6 per-grid-kind, mark invariant 2 not-applicable) + guard `255d192` + `0b1cb34` (finalize invariant-6 structure-grid skip rationale, Option C)
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/invariants.py` only
**Must not touch:** invariants 1, 3, 5, 7, 8, 9 — unchanged

**Found while checking Phase D against this redesign. Without E9, Gate D row 1 ("every invariant
passes, no ERROR") fails by design and can never pass again.**

**Invariant 6 — "L3 offshore edge ≥ the spot's measured 15 m contour".** Phase E **deliberately
retires that edge** (E2): the structure grid's offshore edge is tip + 1·L_tip, nowhere near the 15 m
contour. Left as-is, invariant 6 fires on every cycle forever, and the one signal that was supposed
to catch a grid collapse becomes noise that gets ignored — which is mechanism 3 from this plan's own
Context section, rebuilt.

**Design:** invariant 6 is rescoped to assert **each grid reaches the feature it was sized for**:
- structure grid → its offshore edge ≥ the structure tip + 1·L_tip;
- L3 as nesting step → contains the structure grid with ≥ 2 parent cells of clearance on every side;
- L3 as refraction grid → offshore edge ≥ the spot's measured 15 m contour (**today's assertion,
  retained for exactly this case**);
- no L3 and no structure grid → invariant does not apply; skip, do not pass vacuously.

Still evaluated at config push against cached sizing metadata, checked per cycle — unchanged
mechanism, changed assertion.

**Invariant 2 — "SwellTrack Hs vs SWAN Hs over the overlapping depth range, 25%".** It already had
**no measurable overlap** after `7fb75f9`. Under D3 the overlap is definitively **zero** on the
open-beach path: SWAN stops at 15 m, the 1D model starts at 15 m. There is no depth range where both
have a value.

**Design:** do **not** invent an overlap to keep it alive. Mark invariant 2 **not applicable** where
the handoff is a clean boundary rather than an overlap, and record it — **explicitly, in the
invariant's own text** — as a check the current architecture cannot support. **Report; do not
redesign the handoff to create an overlap.** A plan whose acceptance criterion is unreachable is a
STOP-and-surface, never a licence to move a boundary (trigger 3).

**Guard:** invariant 6 must fire against a structure grid whose offshore edge is short of tip + L_tip,
and must **not** fire against a correctly-sized one — the second half is the part that matters here.

### E10 — Per-transect profiles span the handoff to shore, not a grid bbox *(supersedes and resequences C4)*  ✅ **DONE** — landed as `054df69`
**Owner:** `clearskies-api-dev` · **Files:** C4's allowlist —
`services/grid_sizing_chain.py`, `enrichment/bathymetry.py`, `providers/nearshore/swan.py`,
`endpoints/beach_profile.py` **Must not touch:** `extract_native_profile_from_grid()`'s body;
`_band_ray_origin()` (`swan_runner.py:124-163`)

**C4 IS IMPLEMENTED. This is a rework of shipped code, not a fresh build.**
`060a56b feat(C4): add per-transect bathymetry profiles from each transect's own anchor` is
**committed on `main` and NOT deployed** — librewxr runs `de71775`. Read that commit before writing
anything. An agent that treats E10 as greenfield will duplicate `profiles_by_transect` instead of
re-basing it.

**Found checking Phase D against Phase E.** C4 extracts the profile **over the L3 grid's bbox**
(`grid_sizing_chain.py:539, 556`) and its sequencing note reads *"Depends on C3… per-transect
profiles are worth little until the grid reaches 15 m."* Phase E removes that premise entirely:

- **Open-beach spot** → under D2 there is **no L3 at all**. No bbox exists to extract over.
- **Structure spot** → L3 is a small nesting grid hugging the structure. Its bbox does **not** span
  to the 15 m contour.
- Meanwhile D3 makes the 1D run **longer**, not shorter: open transects now run the full
  ~2 450 m from 15 m to shore on their own profile. **Per-transect profiles matter more under this
  design than they did under C4's, not less.**

**Design — the extraction basis changes from a grid bbox to the transect itself:**
1. Each transect's profile spans **from that transect's own handoff point to shore**, where the
   handoff point comes from E5's rule — L4 or L3 at the per-hour breaking depth, or L2 at 15.0 m.
2. Sample along the transect's own line from `_band_ray_origin()`'s per-transect shoreline anchor,
   at the **source bathymetry's native resolution** (10 m at HB), interpolated to the 3–5 m profile
   spacing the 1D model expects. **Do not sample finer than the source** — D7.
3. The named artefact is unchanged from C4: the profile cache gains a **`profiles_by_transect`** key
   mapping transect index to profile array, alongside the existing per-spot `profile`, which stays
   for every current consumer. Additive; nothing existing changes shape.
4. Consumers unchanged from C4: `swan.py:1599-1602` and `beach_profile.py:264-265` assign from
   `profiles_by_transect[t.index]` when present, falling back to the shared profile **with a
   WARNING** when absent.
5. **No dependency on C3 or on any L3 geometry.** That coupling was the defect.

**Sequencing:** C4's own note says C1 alone already yields 32 *differently truncated* profiles — same
seabed, different start points — because truncation copies rather than mutates
(`surf_1d_pipeline.py:269-272`). **That measurement is still owed and still separable**: take it
before E10 so E10's contribution is distinguishable from C1's.

**Guard:** a spot with **no L3 and no structure grid** produces 32 profiles each spanning its own
handoff point to shore. This case is unreachable under C4's design and is the whole point of E10.

### E11 — Shadow classification: the two call sites C2 did not reach  ✅ **DONE code/test level** (2026-07-27: `3e40238`, guard `af02d19`; adversarial pass demonstrated invariant 3 was structurally unfireable before and fires correctly now. **Item 2 remains OPEN — resolve at Gate E row 19 with live config**; probe numbers are non-authoritative pending E13's real geometry. Item 3 confirmed: invariant 3 was trivially passing on empty lists)
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/swan_runner.py` only
**Must not touch:** `marine_config.py` (C2's fix — already landed as `de71775` and deployed); the
shadow-classification function's own logic until item 2 below has been answered

**Recorded during Phase C as a separate defect and left unfixed. It has no owner until now.**
Under Phase E this stops being cosmetic: `TRANSM 0.82` (E6) makes the lee deficit ~20% of height
rather than ~5%, and the structure grid (E2) is sized specifically to resolve the shadow's edge. A
structure grid computing a shadow that the classifier then fails to attribute to any transect is
~5 000 cells of wasted compute per cycle.

**Two live trace records, same cycle, proving two distinct problems:**
```
{"stage":"shadow","spot_id":null,                      "structures_received":{"count":0,"ids":[]},             "shadowed_count":0}
{"stage":"shadow","spot_id":"huntington-city-beach-pier","structures_received":{"count":1,"ids":["pier(567m)"]},"shadowed_count":0}
```

**Design — two separate items. Do not conflate them.**

1. **`swan_runner.py:2880` and `:3836` pass no `structures` argument at all** — hence
   `count: 0` and `spot_id: null`. C2 fixed the `providers/nearshore/swan.py` path only. Thread the
   spot's structures to both call sites, from the same source C2 populated. **Verify the line numbers
   against the current tree before editing** — C1/C2/C3 have all landed since they were recorded.

2. **The second record shows `count: 1` but still `shadowed_count: 0`.** Structures *were* received
   and nothing was shadowed anyway. **Determine whether that is correct or a second defect — do not
   assume either.** It may be legitimate: swell at 201.9° crossing a pier bearing 221° is a ~19°
   grazing geometry, and with the *current* axis-aligned grid the geometric shadow may genuinely miss
   every transect. It may equally be a real defect. **Report the finding with the geometry that
   produced it; do not "fix" it until it is established which.** Changing shadow-attribution criteria
   on an assumption is a trigger-1 change.

**Invariant 3** (*"`spot_config.structures` non-empty ⟹ shadowed count > 0"*) should be firing on
this today. Confirm it is. An invariant that ought to fire and does not is a worse finding than the
defect it was meant to catch.

**Guard:** both call sites receive a non-empty structures list for a spot that has one — asserted at
the call site, not by mocking the classifier.

### E12 — A cycle that overruns must not report `ok`  ✅ **DONE code/test level** (2026-07-27: `eba9622`, guards `85ce1a2`+`f2f4c31`, 16/16; adversarial pass clean incl. failed-never-downgraded. **Finding 2 answered and owed to operator:** timeout is per-SWAN-invocation (`_spawn_swan` :4065), nothing bounds the cycle; deployed config has NO `swan_timeout_s` key so production runs the 900 s code default, not the documented 3600 s — and E0's hung process outlived both, so the timeout appears ineffective. Cycle-bound + value decisions pending)
**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/endpoints/health.py`,
`weewx_clearskies_marine/state.py`, `weewx_clearskies_marine/services/swan_runner.py`
**Must not touch:** B3's input-freshness registry; the invariant-scoping fix (`49839ac`); the four
original `/health` response keys

**Two findings, measured live 2026-07-27 while checking E0's starting state.** Both are the same
class of defect B3 exists to remove, one layer further out.

**Finding 1 — `/health` reports `ok` through a 90-minute overrun.**
```
status: ok | run_in_progress: True | last_run: 2026-07-27T19:57:32Z
```
Read at ~21:30Z. The cycle began ~20:41Z; nothing had completed since 19:57Z. Health has **no concept
of a cycle taking too long** — `run_in_progress: True` is reported as healthy indefinitely. A
forecast site that has published nothing for an hour and a half reports `ok` to the admin page B4
built — the one surface the operator was meant to be able to trust.

**Design:** `_compute_status()` gains a **cycle-duration** check against
`_last_cycle_started_at` (already recorded by `49839ac`). Beyond a threshold, status becomes
**`degraded`** with a reason naming the elapsed time. **Not `failed`** — output from the previous
cycle is still being served and is merely stale, which is exactly the degraded/failed distinction
the plan already draws. Threshold is a **named constant**, set from the measured cadence, not
inlined.

**Finding 2 — the SWAN timeout did not visibly fire.** One `swan` process was still resident ~50
minutes past the documented 3600 s timeout, with the cycle still marked in progress. **Establish
whether the timeout is per-grid-invocation rather than per-cycle, or whether it failed to fire at
all — do not assume either.** If it is per-invocation, a three-grid cycle can legitimately run to
3×3600 s and **the real defect is that nothing bounds the cycle**; say so and bound it. Report the
finding before changing any timeout value — a timeout is a config key (trigger 7).

**Guard:** `/health` returns `degraded` naming elapsed time when `_last_cycle_started_at` is older
than the threshold and `run_in_progress` is True; returns `ok` when it is within it. Reuses
`tests/test_marine_health_state.py`'s existing fixtures.

### E13 — Structure geometry: persist the discovery outline, delete the pin projection  ✅ **DONE code/test level (2026-07-27)**
> **Landed:** marine `8d87ad2` (deleted `_populate_structure_coordinates` + `build_obstacle_structures` case (b)) + `1307386` (JSON-decode coordinates on read) + guards `634c430`; api `5ca6a93` (optional `coordinates` field, `json.dumps` write / `json.loads` read) + `3444fa1` (API-MANUAL §19.5); stack `19d9332` (wizard/admin carry-through, single [lat,lon]→[lon,lat] conversion). All independently acceptance-gated by the coordinator. **Contract bug caught in QC:** configobj returns a nested coord list as strings, so the marine reader's `float(c[0])` hit `'['`; resolved by JSON-string encoding end-to-end with `json.loads` on both read sides (marine reader + api serialize). The mandatory guard round-trips through a real configobj file. **Owed live at Gate E (rows 25–27):** deploy stack+api, re-run HB wizard discovery + Apply so `marine.conf` carries the real outline.
**Owner:** `clearskies-api-dev` (three scoped dispatches, one per repo) + `clearskies-test-author`
**Authority:** ADR-095 Decision 3 (Accepted): *"Structure coordinates from the wizard's Overpass API
discovery."* Operator ruling 2026-07-27 in chat: the spot pin is a point-of-interest marker with no
geometric meaning for structures; the code that fabricates structure position from it is the defect.
A8's anchor rule already bans pin-derived geometry. **This task supersedes and reverses C2's
projection helper (`de71775`) — stated explicitly, not silently.**

**History (git-established 2026-07-27, full citations in
[briefs/PHASE-E-SESSION-LOG-2026-07-27.md](briefs/PHASE-E-SESSION-LOG-2026-07-27.md)):** the wizard's
discovery endpoint downloads the full OSM way geometry (`out body geom`, api `setup.py:3460-3495`)
and always has; the T5.2/T5.3 wizard UI displayed it and **discarded it at form submit**, so no
config has ever contained structure coordinates (verified: live api.conf + both backups + the
SWAN-L3-STABILITY-PLAN's own line 259). `ac73ab2` (07-19) fabricated a line from
bearing/length/distance measured off the pin instead of surfacing the missing save step; C2
entrenched the same fabrication at config parse. The fabricated pier is displaced ~500 m along its
own axis (real base pin+406 m @ 21°, real tip pin+231 m @ 258°; fabricated: pin+124.5→691 m @ 221°).

**Design — one conversion point, no fallback:**
1. **stack** — wizard discovery-card JS (`wizard/routes.py:3436-3449`) adds a hidden
   `..._coordinates` input carrying the way geometry from `data-geometry`, converted once
   lat/lon → lon/lat (the marine `StructureConfig.coordinates` contract). Map-draw tool
   (`step_marine.html:1294-1337`) persists the drawn polyline the same way instead of discarding
   it. Form parse (`routes.py:2952-2972`) includes it. Admin round-trips it (hidden field);
   stale comment `admin/marine.html:589-595` updated.
2. **api** — `MarineStructureApplyConfig` (`setup.py:523-546`, extra="forbid") gains optional
   `coordinates`; `_build_marine_conf_section()` (`:1296-1306`) writes it to api.conf
   (JSON-string encoded for configobj); `_serialize_marine_locations_section()` (`:1499-1521`)
   decodes it — reviving the already-written, currently-dead carry-over branch. API-MANUAL
   structures schema updated in the same commit (doc-code sync).
3. **marine** — DELETE `_populate_structure_coordinates()` + call site
   (`marine_config.py:371-405`, `:994-996`) and `build_obstacle_structures()` case (b)
   (`swan.py:877-895`). Restore the original contract: explicit coordinates used directly; no
   coordinates → excluded with WARNING, **never fabricated**. `StructureConfig.coordinates`
   docstring updated; scalars become display metadata only.
4. **Guards** (`clearskies-test-author`): rewrite `tests/test_structure_config_coordinates.py`
   (currently pins the fabrication) — no-coordinates structure stays empty and is excluded with
   WARNING; explicit coordinates pass through untouched; end-to-end shadow test drives real
   OSM-shaped coordinates. `tests/test_swan_runner_structures_threading.py` fixture supplies
   explicit coordinates instead of calling the deleted helper.
5. **Operational, after deploy:** re-run wizard marine-step discovery for HB and Apply, so the
   pushed config carries the pier's real outline. Expected (OSM way 45074900, measured
   2026-07-27): base (33.6568071, -118.0023173), tip (33.6529618, -118.0063370),
   axis 566.8 m @ 221.0°.

**Must not touch:** `compute_transect_shadows()` logic; `_OBSTACLE_PARAMS`; `bearing_to_spot_degrees`
(zero computational consumers — recorded finding, out of scope); the five scalar fields themselves
(UI still collects/displays them).

### NEW — Projection fix: one locked UTM zone per deployment  ✅ **DONE**, adversarially audited clean (2026-07-28)
> **Not an original E-task.** Found during the audit of E8/F1 work: each SWAN grid independently
> recomputed its own UTM zone from its own centroid, which could put the global L1 grid and a
> per-cluster L3/L4 grid in **different Cartesian frames near a 6° UTM zone seam**, silently zeroing
> the nested wave energy at the boundary. **Operator ruling 2026-07-28, Option A:** lock one UTM zone
> per deployment, computed once from the deployment's surf-spot centroid, rather than let each grid
> pick its own.

**Owner:** `clearskies-api-dev` · **Files:** `weewx_clearskies_marine/services/grid_sizing_chain.py`
and its runtime call sites (deployment-centroid zone lock, width guards, antimeridian handling)

**Design, as landed:**
1. `f6033ed` — `DomainSizing.locked_utm_zone`, persisted in `swan_grid_sizing.json`
   (`domain_sizing_to_dict`/`from_dict`). `run_grid_sizing_chain()` computes it once from the
   deployment's surf-spot centroid (`_locked_utm_zone_for_deployment()`). Setup-time width guard:
   **WARN if surf spots span > 1° longitude, refuse (raise, no sizing produced) if > 2°** — a
   misconfiguration catcher, not an accuracy limit.
2. `dba0fd4` — threads the locked zone through runtime call sites; deletes the per-grid zone
   recomputes it replaces.
3. `55c3964` — updates existing test fixtures for the new zone parameters.
4. `1584136` — adds guards for the UTM-zone lock.
5. `71939fd` + `b136f15` (audit finding F2) — the deployment centroid and width-span calculation are
   made **antimeridian-aware** (global, not US-only): naive longitude averaging breaks for a
   deployment straddling ±180°.

**Consequence for deploy (see the new deploy-requirement note under Gate E, below):** the locked zone
and the new geometry-change signature are written into `swan_grid_sizing.json` by
`run_grid_sizing_chain()`, which runs at config push, not per cycle. **A deploy that does not re-push
marine config leaves the old cache in place**, and `run_3level()` raises `RuntimeError` rather than
run against it (fail-clean behaviour, confirmed by this fix's own adversarial audit).

**Adversarial:** audited clean — no path found where two grids in the same deployment resolve to
different UTM zones, and the antimeridian case was specifically exercised.

## ⛔ QC GATE E — grid strategy  ⬜ **NOT REACHED**

> ### ⚠ Deploy requirement — mandatory config re-push, not just a code deploy
>
> **The Phase E deploy MUST re-push marine config** so `run_grid_sizing_chain()` regenerates
> `swan_grid_sizing.json` with the new `locked_utm_zone` and the geometry-change signature (see the
> "Projection fix" subsection above). Grid sizing runs **at config push, not per cycle**
> (`endpoints/config.py:77`) — a code-only deploy leaves the old cache in place.
>
> **Without the re-push, `run_3level()` raises `RuntimeError` on the stale cache and forecasting
> stays dark.** This is fail-clean by design (confirmed by the projection-fix adversarial audit F1) —
> it does not silently run on a wrong-zone or wrong-geometry cache — but it also does not self-heal.
> The re-push is a **one-time migration for this deploy**, on top of E0's already-documented restart
> order (Phase E code → config re-push → confirm `last_run` advancing across two consecutive cycles).
> Restated here because it now also carries the projection fix's new cache fields, not just the E2–E10
> grid geometry.

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
| 15 | Invariant 6 fires on a short grid and **not** on a correct one | both runs; the second is the row that matters |
| 16 | Invariant 2's not-applicable status is recorded in its own text | the invariant's text, and the applicable set stated |
| 17 | 32 per-transect profiles, each spanning its own handoff to shore | first and last depth of three transects using **different** handoff rules — or a statement that HB exercises only rule 1 |
| | **↓ Relocated from Gate C, which was never walked ↓** | |
| 18 | C1 — distinct handoff depths across transects | the 32 values; count of distinct ones > 1 |
| 19 | C2 + E11 — structures reach every shadow call site | both trace records showing `count: 1`, and the E11 item-2 finding stated either way |
| 20 | Cell count and cadence together | per-grid and total cells beside wall time; **replaces Gate C's struck `L3 ≥ 2 674 m` row**, which Phase E makes wrong by design |
| | **↓ Relocated from Gate B, never passed ↓** | |
| 21 | A published number is fully traceable | follow one `breakingFaceHeight` to its SWAN station using only the trace. Paste the chain |
| 22 | No published field changed by the trace | forecast bundle with trace on and off — byte-identical |
| 23 | No invariant fires off stale cache | for each firing, show it came from the live computation, not a cached artefact. **Sharper after Phase E**: geometry is cached at config push, so a stale-cache firing is the likeliest false positive |
| 24 | Deep-water reference returns **67 rows, not 1** | the row count. **Blocking for the Reality reads** — they read this reference, and a 1-row reference cannot support them |
| | **↓ E13 — structure geometry ↓** | |
| 25 | Pushed config carries the pier's real outline | `coordinates` in `/etc/weewx-clearskies/marine/marine.conf` with endpoints within ~10 m of OSM base (33.6568071, -118.0023173) and tip (33.6529618, -118.0063370) |
| 26 | No pin-projection code remains | `grep -rn "111320" ` across marine + api repos returns nothing in structure paths; both deleted sites shown gone by diff |
| 27 | OBSTACLE line derives from the real outline | the emitted `OBSTACLE` UTM points back-convert to the OSM endpoints, not to pin+124.5 m |

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

### F1 — Carry `is_wind_sea` through the partition conversion  ⬜ **NOT STARTED**
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

### F2 — Sample per-spot wind from the field that forces SWAN  ⬜ **NOT STARTED**
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

### F3 — Depth-limited growth kernel — gated on a known-answer test  ⬜ **NOT STARTED**
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

### F4 — Grow the wind-sea partition along the 1D run  ⬜ **NOT STARTED**
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

### F5 — Fallback: synthesize a wind-sea partition when SWAN handed none over  ⬜ **NOT STARTED**
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

## ⛔ QC GATE F — wind source term  ⬜ **NOT REACHED**

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
| 11 | **Tide appears in the published payload** *(relocated from Gate B row 13)* | the tide field in one published bundle. Tide is already computed correctly (findings §0B.1) — **this is a publish-path plumbing gap, not a physics one**, and it lands here because Phase F touches the same publish path |

**Adversarial:** `clearskies-auditor`, given §0B and the expectations above but **not** any
implementing agent's tests, commits or reports. Specifically briefed to hunt: a coefficient with no
citation; wind sea grown from alongshore or offshore wind; the flag read by index rather than by
field; any change to a swell partition; and a second wind source.

---

# PHASE D — Verify the whole chain

### D1 — Cold-start first hour  ⬜ **NOT STARTED**
Previously C5; **moved because its gate opened only post-deploy, making Phase C circular.**
The first output row of every run is the empty initial field (`Hsig 0.014 m`, partitions zero,
`Tm01 1.6 s`) and is published as a forecast hour. That is expected for a cold-started spectral
model and is not itself a defect. `aa4553d` fixes the hotstart. **Check first whether a working
hotstart populates the first hour. Only if it is still empty does suppression get designed** — and
it gets designed then, not now.

> **⚠ Phase E invalidates every hotstart. Read this before concluding `aa4553d` failed.**
> Hotstart files are written for a specific grid geometry. After Phase E deploys, **the first cycle
> is necessarily a cold start** and its first forecast hour will be the empty initial field — once.
> That is Phase E's expected cost, **not evidence the hotstart fix is broken**.
> **Evaluate D1 on the second cycle after Phase E**, when a hotstart written by the new geometry
> exists. A coordinator who reads an empty first hour on the first post-E cycle and reopens
> `aa4553d` has made a sequencing error of exactly the kind C3's live-check note warns about.

## ⛔ QC GATE D — the whole chain  ⬜ **NOT REACHED**

| # | Element | Evidence |
|---|---|---|
| 1 | Every **applicable** invariant passes | raw log, no ERROR. **Requires E9.** The count is no longer nine: invariant 6 is rescoped per grid kind and invariant 2 is marked not-applicable where the handoff is a boundary rather than an overlap. **State the applicable set and why each excluded one is excluded** — a shrinking invariant count is exactly how coverage quietly disappears |
| 2 | One number traced end to end | full chain from the trace, pasted |
| 3 | Surf height vs reference | published vs Surfline and Surf-forecast, deltas stated — **per the "Reality reads" protocol, presented alongside the Gate E and Gate F reads**. Note there is no pre-refactor baseline and none can be manufactured; see that section |
| 4 | Swell partitions vs reference | height, period, direction per partition vs both |
| 5 | The westerly is published | the 6–8 s W component appears in `multiSwell` |
| 6 | Alongshore variation is real | spread of face height across the 32 transects. **Expected magnitude changed by E6**: at `TRANSM 0.82` the lee deficit is ~20% of height, not the ~5% that `0.95` produced. A spread still near 5% means E6 did not take effect |
| 7 | Cycle completes in cadence | wall time vs schedule interval, warm or cold stated. **Expected ~7 min at ~12 600 cells** (Phase E), against >75 min DNF at 47 992 |
| 8 | Health reports `ok` — and has earned it | `status: ok` with every input fresh and zero invariants fired. After Phase C this is the first time in the plan an `ok` is a pass rather than a fail |
| 9 | The admin status page agrees | rendered output showing `ok` for both API and marine |
| 10 | First forecast hour is not the initial field | Hs and Tp of hour 1 — **on the second post-E cycle**, per D1's warning |
| 11 | **Locally generated wind sea reaches the published output** *(new; Phase F)* | on an onshore-wind hour, a short-period partition appears in `multiSwell` that is **not** present in the L2 handoff spectrum — the end-to-end proof F1–F5 did anything |
| 12 | **A no-structure spot is byte-identical to pre-Phase-E** *(new)* | its published bundle before and after. E4's strongest criterion, verified end to end rather than at the sizing layer |

**Adversarial:** `clearskies-auditor`, with no access to any implementing agent's tests, commit
messages, or reports, attempts to disprove C1–C4, D1, and Phases E and F on the deployed system.

Then `clearskies-docs-author` syncs governing documents to what actually landed — after Gate D, so
the documents describe the verified system rather than the intended one. **Scope now includes Phases
E and F**: `docs/ARCHITECTURE.md`'s SWAN section (grid tiers, what nests in what, which physics runs
where), `API-MANUAL.md` (the handoff rule, the deep-water reference's L2 provenance, the wind-sea
partition), and `rules/clearskies-process.md` (the 2026-07-27 rulings alongside the 07-19 and 07-23
incident rules).

**E5's documentation obligation is *not* deferred to here.** It lands inside E5, in the same commit
as the code, per the doc-code sync rule. This closing pass reconciles everything else.

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

---

# Decision log

## 2026-07-28 — Consolidated Phase E doc sync (docs-only pass)

Phase E's code and tests all landed and pushed across 2026-07-27/07-28, but the plan's own status
markers had not been flipped task-by-task as work completed — each task had doc-synced its own piece
in isolation, leaving the headings for E2/E2b/E3/E4/E5/E7/E8/E9/E10 still reading `⬜ NOT STARTED`
alongside evidence in the session log that they were done. This entry records what a docs-only pass
(`clearskies-docs-author`) verified and changed, and stops it happening again silently.

**Verification method:** every commit hash cited in this entry and in the flipped task headings was
checked with `git -C repos/weewx-clearskies-marine log --oneline` (existence) and, for one commit per
task, `git show <hash> --stat` (content matches the task's own claim). No hash was trusted on the
strength of a heading alone.

**What changed in the document, this pass:**
- Flipped `⬜ NOT STARTED` → `✅ DONE` with a landed-hash citation on: E2 (`7ea961b`+`97e08d1`), E3
  (`49df65c`+`53abe07`+`af7bcda`), E4 (`6b48abd`), E5 (`2bad206`+`d68465a`), E7 (`d517084`+`af7bcda`),
  E8 (`618378c`+`bbcec8f`+`c3fa5b6`+`1b7699b`+`0979b99`, plus the coupled F1 commits below), E9
  (`416e1fc`+`255d192`+`0b1cb34`), E10 (`054df69`).
- Added an **E2b** task heading — this piece of work has no heading anywhere in the plan as written;
  it exists only in the session log ("TRACKED GAP — NEW TASK E2b"). Documented as done
  (`9ceab5d`+`53abe07`+`c3f22f7`+guard `e14baa2`) and flagged as not-originally-planned, per this
  project's rule that undocumented mid-session work gets a home rather than staying log-only.
- Added a **"Projection fix"** subsection under Phase E (also not an original E-task): one locked UTM
  zone per deployment, operator ruling 2026-07-28 Option A (`f6033ed`+`dba0fd4`+`55c3964`+`1584136`,
  antimeridian-aware `71939fd`+`b136f15`). Adversarially audited clean.
- Added a **deploy-requirement note** at the top of Gate E: the Phase E deploy must re-push marine
  config so `run_grid_sizing_chain()` regenerates `swan_grid_sizing.json` with `locked_utm_zone` and
  the geometry-change signature — otherwise `run_3level()` raises `RuntimeError` on the stale cache
  (fail-clean, confirmed by the projection fix's own adversarial audit) and forecasting stays dark.
  One-time migration for this deploy, on top of E0's existing restart order.
- Updated the top-of-file status line, Sequence line, and START HERE table to reflect all of the
  above.

**E8 redesign, summarized (full detail: this file's E8 section and the session log).** The original
E8 ("add L4 to the finest-grid-only quick update") was found to be scoped on a dead premise — the
quick-update path was a SWAN-only-era remnant that never invoked the 1D handoff→SwellTrack chain and
was never wired into the runner loop at all. Operator-approved redesign: full non-stationary run every
6 h on the extended HRRR cycles; **hourly stationary "fill"** runs the **full nest** (L1→L2→L3→L4,
reusing the last full run's WW3 boundary and hotstart, never saving a new hotstart) **and then runs
the 1D chain**, so the surf card refreshes hourly, not just SWAN grid points. Landed `618378c`
(runner) + `bbcec8f` (1D chain + swelltrack merge) + `c3fa5b6` (wired into the loop), with two audit
findings fixed: F1 — a geometry-changing config push now clears SWAN run state and cold-starts
(`c3ceaa8`), and signals an **immediate full run** rather than waiting for the next scheduled cycle
(`12907ca`, operator ruling 2026-07-28); F2 — the fill now reports updated-vs-skipped honestly and the
loop only advances `last_run` on a real update (`1b7699b`), with guards at `0979b99`.

**Projection fix, summarized.** Found during the E8/F1 audit: each SWAN grid independently recomputed
its own UTM zone from its own centroid, risking the global L1 grid and a per-cluster L3/L4 grid
landing in different Cartesian frames near a 6° zone seam — silently zeroing nested wave energy at the
boundary. Operator ruled Option A: lock one UTM zone per deployment, computed once from the surf-spot
centroid, with a setup-time width guard (WARN > 1° longitude span, refuse > 2°). Made
antimeridian-aware in a follow-up fix after the auditor found the naive centroid/span math breaks at
±180°. Adversarially audited clean.

**Doc-code contradictions found this pass:** see Task 4 findings, reported in this pass's closeout to
the coordinator — not resolved here, per this agent's scope (docs-only; a contradiction is a finding,
not something to silently reconcile).

## 2026-08-01 — R3 L4 rewrite: four operator rulings (Phase R doc-sync pass)

Recorded during the doc-sync pass that followed the L4 structure-grid siting rewrite (marine `4e79d21`,
R3 residual "L4-transect co-registration," ADR-093 Amendment 6). All four rulings were given in chat
2026-08-01 and are cross-referenced from ADR-093 Amendment 6, `MARINE-GEOMETRY-MODEL-PLAN.md` (AD-4/G4.2
superseded markers), and PROVIDER-MANUAL.md §14.15.

1. **No primary structure.** L4 is sized against every operator-identified eligible structure in a
   cluster, not a single "primary" one — a beach may have no dominant structure (two equal breakwaters;
   a jetty with adjoining breakwaters). `_cluster_structures_by_proximity()`/`_select_primary_group()`
   deleted; AD-4's proximity-clustering/primary-structure design (G4.2) is superseded, not merely
   unimplemented.
2. **Shadow selection decides grid inclusion only, never physics.** Over-inclusion in the shadow test is
   benign — "when in doubt, include — SWAN inside the box is the authority on the physics." The shadow
   test exists to size the grid, not to pre-judge which transects the physics will actually affect.
3. **The spot PIN has zero bearing on any measurement.** It is a site designator only; the operator may
   relocate it along the beach without affecting L4 sizing, transect bearings, or any other geometry
   computation. The new sizer is pin-independent by construction (beach-frame, anchored on the coastline,
   never the pin).
4. **Transect spacing stays 10 m**, pending performance data from the first full test run against the new
   grid (a full SWAN run was in progress at the time of this doc-sync pass — see R3's PENDING test-run
   note).

---

# PHASE R — 2026-07-31 regression recovery + anti-regression hardening

**Created 2026-07-31 (Fable diagnosis session, operator-directed). Runs before Phase F, Phase D,
and any further `MARINE-GEOMETRY-MODEL-PLAN.md` work.** Every claim below was measured from
primary artifacts this date (preserved workdirs, B1 trace, journal, deploy reflog) — none of it
is inherited from prior session reports, several of which were factually wrong (see TC-21/TC-23
corrections in `MARINE-GEOMETRY-MODEL-CONCERNS.md`).

## R-DIAGNOSIS — what actually happened on 2026-07-31 (evidence-stamped, read first)

| Time (UTC) | Event | Evidence |
|---|---|---|
| ≤ 07:25 | Model WORKING: valid_fraction 95.0–95.4%, published 4–5 ft SW faces @ 8–9 s matching Surfline | trace `published` 07:00; journal |
| **11:13** | **Deploy `4828d99`** — geometry-plan G2 (L1 aim + WW3 sides from open-water fan, GL sizing, island enclosure) **plus the G1 ray-fit facing going live** (238.0° → 201.9° at the 11:16 push) | reflog; journal `beach_facing=` |
| 11:16 | **L3-strip viability test FAILED** — "structure unreachable by ~180 m … L3 disabled; handoff falls back to L2 at ~15 m." The guard fired correctly; nothing surfaced it to the operator. L4 along 483→399 m, reach 30→21 m, L3 bbox moved ~1 km | journal swan_domain |
| 11:51 | Run PASSES gate (80.3%) but "zero usable L3 handoff timesteps"; per-hour ERRORs "no clean QB station"; nearshore Hs already 0.65–0.69 m vs a real high-surf morning; **publishes NOTHING, silently — 07:00 remains the last publish ever**; /health stayed `ok` | journal 11:52; trace (0 `published` records after 07h) |
| 12:49–13:49 | Gate failures 27.3% / 35.5% / 27.3% — same geometry, data-sensitive metric | journal |
| 18:10 | AD-1R facing (217.0°, correct) re-push; frame moves again | journal |
| 18:46 | Failed gate run (7.1%): L4 grid **100% wet** (4752/4752 nodes), all 96 handoff stations **wet but OUTSIDE the grid** (4–56 m shoreward of its frozen edge, at 0.72–1.49 m depth); **south swell (verified in boundary file: 13.6 s @ 185°, Hs_swell 0.85 m, matching Surfline) entirely ABSENT at the 15 m reference** (0.30 m of 5.6 s W wind chop only) | measured from `/tmp/g1r-gate-level4_0-failed` + level1/level2 workdirs |

**Root regressions (fix targets):**
1. **Swell starvation** — boundary files carry the real swell; the model's interior does not.
   Mechanism sits in the `4828d99` window (G2's `_compute_level1` aim / `select_boundary_stations`
   side derivation / L1 box relocation) — pinned to one deploy, NOT yet to one line (task R2).
2. **Frame break** — the facing flip moved the anchor/contour frame; L3-strip viability failed
   (loud but unsurfaced); L4's frozen shoreward edge moved seaward of the station band.
3. **Silent no-publish** — a gate-PASSING run published nothing with `/health` = `ok` (task R4).
4. **Wrong gate contract** — the L4 `low_valid_fraction` check asserts "transect fan inside L4",
   contradicting the operator architecture ruling (2026-07-31, recorded in TC-23): L4 models
   refraction/diffraction around the obstacle; it is NEVER the sole handoff; a transect that
   does not intersect L4 continues to L2. No L4-intersection routing exists anywhere in code.
5. **Missing design floor** — `_MIN_DESIGN_HS_M = 1.0` (→ the 1.78 m contour, STUDY-AREA brief
   §3.1 "smallest handoff ever") is applied to grid sizing ONLY; station placement has no floor.
6. **Latent defects** — BOUNDSPEC `[len]` emitted in degrees (`len_deg`, swan_formats.py:2531)
   into a Cartesian-meters grid (non-fatal so far, wrong since the Jul-28 projection switch);
   NOMADS station-spectra fetches intermittently 403/404 with hot retry loops.

**Exonerated by evidence:** G4.1/G4.2 (L4 axis rotation 221.0° unchanged across every failing
run sized by pre-G4 code); G3 exposure (byte-identical L4 at the pre/post-G3 pushes); the
`len_deg` defect as the trigger (model published real swell through it Jul 29–31 07h);
prior sessions' "L4 grid is 35% dry land" (grid is 100% wet).

## R-tasks

**Sequencing: R11 (rules) FIRST, before any agent is dispatched; then R1 → R2/R3 (diagnosis +
fix, one change per deploy, reality-gated) → R4 → R5/R6 → R7 (sign-off designs) — with R8/R9/R10
as a parallel docs/tests lane.**

### R1 — Bisect-confirm the cliff at `4828d99`  ✅ **RAN 2026-08-01 (operator go) — PREMISE REFUTED**
**Owner:** coordinator. **Design:** on librewxr, check out `f337648` (last-known-publishing
commit) detached, restart service, force one full run. Record: does it publish; DWR partitions
vs NDBC 46222 + Surfline (the reality comparison); valid_fraction; station band depths. Then
redeploy current HEAD. **Accept:** cliff confirmed (f337648 publishes real swell) or refuted —
either result redirects R2. **Rollback ref:** current HEAD hash recorded before checkout.

> **R1 RESULT — 2026-08-01 (measured on librewxr; f337648 detached run, evidence preserved at
> `/tmp/r1-f337648-run/`). Coordinator findings; the two contradictions below are surfaced to the
> operator, NOT self-ruled.** HEAD `73df829` restored, service stopped afterward.
>
> 1. **Bisect REFUTED — swell starvation is present at f337648, older than the cliff.**
>    `python3 /tmp/spec_probe.py` on the L2 workdir: L1 south boundary INPUT (`BOUND_S_46223`)
>    carries **Hs_swell(T>10s)=0.82 m @ 11.9 s @ 185°**; the 15 m reference OUTPUT (`SPEC_DWR_1`)
>    has **Hs_swell=0.04 m**, 0.72 m of 4.2 s @ 268° wind chop. Same starvation signature as broken
>    HEAD's 18:46 run. f337648 predates `4828d99`, so **root-regression #1's attribution (mechanism
>    in the 4828d99 window) is contradicted** — the starvation is chronic.
> 2. **The L4 collapse is facing/frame-driven and separable.** f337648 recomputes facing to
>    **238.0°** (working-era) and L4 converges **valid_fraction=94.7%** (journal
>    `SWAN convergence OK level=level4_0`) vs **7.1%** at HEAD's 217°. Restoring facing recovers L4
>    grid validity; it does NOT fix the starvation.
> 3. **f337648 also fails to publish today** — a separate latent crash: `wind_sea_growth.py:158`
>    `ValueError: fetch_m … must be > 0 (got fetch_m=-1.91)` in the 1D per-transect pipeline
>    (offshore-wind/negative-fetch, unguarded) → every timestep `modelStatus unavailable` → 0 published.
> 4. **`len_deg` is NOT exonerated.** L1 `BOUNDSPEC SIDE S … 0.4086 …` emits DEGREES
>    (`swan_formats.py:2531` writes `station.len_deg`) into a Cartesian METERS grid; local manual
>    `swan-user-manual.txt:2510` says `[len]` is meters for non-spherical. Confirmed real defect
>    (category error, angle vs distance). **Candidate for the starvation, NOT proven cause** — the
>    south side has a single spectrum, which SWAN applies across the whole side regardless of `[len]`,
>    so the south-swell loss is not explained by this alone. Mechanism-pin is R2.
>
> **R2 redirect (awaiting operator ruling):** hunt the starvation in the
> L1-boundary → L1-interior → L2-nest → 15 m reference chain, NOT the 4828d99 window. Next step
> proposed: read-only per-stage swell measurement on the preserved workdir to localize where the
> swell dies, before any fix (fix is trigger-3, needs sign-off).
>
> **R5 deploy result (2026-08-01, measured on librewxr, commit `5581b0a` deployed):** the `[len]`
> fix is CONFIRMED live (L1 BOUNDSPEC S=37975 m, W=646/9517/13952 m — real meters, west 3-station
> mangling fixed) but did NOT restore the swell. From the B1 trace time-series (valid-time-aligned,
> `spec_l1_boundary` vs `spec_l2_dwr`): south swell ~0.5–0.74 m @ 185° enters the L1 boundary
> correctly (matches Surfline ~0.85 m) and arrives at the 15 m reference as ~0.03–0.04 m — **~94–95%
> lost, every hour**, dominated there by 222° wind chop. WW3→L1-boundary handoff is HEALTHY; the
> loss is L1-interior/L1→L2-nest/L2. As predicted (single-spectrum south side), `[len]` was not the
> cause. R5 stands as a correct defect fix; it is not the swell fix.
>
> **Trace-logging defect (2026-08-01, dispatched to `clearskies-api-dev`):** the grid-handoff trace
> stages EXIST (`_trace_nest_handoff` → `spec_l1_nestout`/`spec_l2_nestout`/`spec_l3_handoff`) but
> emit ZERO records — `_trace_nest_handoff` parses the NESTOUT file with the SPECOUT parser
> (`parse_specout_file_multi`), which throws (`timestep block before AFREQ/NDIR`); the bare
> `except: return` swallows it silently. So the L1→L2/L2→L3/L3→L4 handoffs have never been logged.
> Fix in flight: NESTOUT-aware parse + silent-swallow→WARNING + per-band Hs accuracy (`summarize_spectrum`
> band `energy` omits `dtheta`, under-reporting swell ~3.16×) + KAT. Once landed + deployed, one run
> traces the swell through every handoff and pins the death point (the real R2 mechanism hunt).

### R2 — Pin and fix the swell-starvation mechanism  ✅ **SWELL FIX DONE + VERIFIED, PUSHED + DEPLOYED 2026-08-01 (publish still blocked downstream by L4/R3 — see DEPLOY+VERIFY block)**
**Owner:** coordinator diagnosis; fix by `clearskies-api-dev` after operator sign-off (the fix
will touch trigger-3 territory: L1 extent/aim/boundary).
**Leads, in order:** (a) the open-water fan's derived aim for HB — the DWR's sole surviving
partition is 262° W, suspicious against HB's true S–SW window; (b) diff the 18:46 L1 INPUT
(preserved) against an f337648-generated L1 INPUT on the same data: CGRID box position, which
sides carry BOUNDSPEC, station set, `[len]` values; (c) `select_boundary_stations()` side
derivation under the new `mean_offshore_bearing` source. **Accept:** a named file:line cause +
minimal fix, then a full run whose DWR shows the boundary's swell partition (13–14 s, ~185°)
within 20% of the boundary file's swell Hs. **Must not touch:** anything beyond the named cause.

> **R2 PROGRESS — 2026-08-01 (coordinator + operator, SWAN-manual read + live-artifact input audit).**
> Read the load-bearing sections of the local SWAN User Manual (`docs/reference/swan-user-manual.txt`)
> against the ACTUAL generated L1/L2 INPUT (pulled from librewxr) and the LIVE run artifacts. Findings
> are measured, not inferred.
>
> ### ✅ ROOT CAUSE PINNED & VERIFIED — 2026-08-01 (Fable review + coordinator independent verification)
> **The swell is not dissipated in transit — it never ENTERS the domain. Stale bathymetry caches leave
> the entire south boundary dry, so `BOUNDSPEC SIDE S` is imposed on `-9999` exception points and SWAN
> silently discards it.** Chain (all measured on librewxr):
> - L1 `BOTTOM.txt` (IDLA=3, file row 0 = SOUTH): **rows 0–3 = 0 wet cells**; east **cols 24–37 = 0 wet**.
>   (= exactly the 488 nodata cells: 4 south rows + 14 east cols − overlap.) L2 `BOTTOM.txt` south rows
>   0–3 also **0 wet** — same defect.
> - `/etc/weewx-clearskies/swan_bathymetry_L1.json` (**mtime Jul 27 03:24**): footprint **lat 33.5067–33.7122,
>   lon −118.2472 to −117.9298**, ni=30 nj=24 — the PRE-facing-flip domain. Current CGRID extends ~4 km
>   further south and ~14 km further east than the cache covers; resample fills the gap with NaN→−9999→dry.
>   L2 cache same mtime, same defect (footprint short on its south edge).
> - The fixed-name L1/L2 caches are NOT bbox-keyed (unlike L3/L4) and the cache-load early-return in
>   `providers/nearshore/swan.py` (~548) **never re-runs the `_covers()` gate**, violating that function's
>   own docstring contract ("guaranteed to span the whole domain"). The facing flip / L1 re-aim
>   (`38f93ac`/`73df829`/`f6033ed`) moved the box after Jul-27; F1's "clear SWAN run state on geometry
>   push" (`c3ceaa8`) evidently does NOT clear these caches — **verify c3ceaa8 scope.**
> - **Reconciles:** magnitude (Fable's order-of-magnitude check: friction over 22 km ≈ 2–10% Hs, not 97%
>   energy loss — physics could NOT do this), the absent south-boundary warnings (a fully-dry side is
>   silent at any maxerr), "worked a week ago" (pre-flip box matched the cache lineage), and R1's f337648
>   bisect (TWO live starvation bugs — the len-degrees BOUNDSPEC bug [R5, now fixed] AND this stale cache;
>   the bisect found the symptom, not the introduction point).
>
> **Corrected reasoning errors (mine, this session):** "swell enters correctly" was a NON SEQUITUR (no
> warning ⇏ enters; a dry side produces no warning); "bathymetry realistic → not the bug" looked at
> depth VALUES but missed the DRY MASK; the shallow skew (65% <150 m, median 41.6 m for a box reaching
> 30 km offshore) was itself the red flag that the deep/offshore half was amputated.
>
> **Superseded localization (kept for the record, now WRONG):** earlier this session I concluded the loss
> was "L1-interior dissipation over the fetch" and that the swell "enters the south boundary correctly."
> Both refuted by the BOTTOM.txt dry-mask evidence above. The L1 PRINT IS healthy (converges 99.6%) — but
> convergence measures the solver on the WET subset and says nothing about the domain being amputated.
>
> **REFUTED this session (stop chasing):** (a) **bathymetry** — live L1 `BOTTOM.txt`: median 41.6 m, max
> 510 m, deep-offshore-shoaling-to-shore, sign NOT flipped → realistic, not the bug (but 65% of wet cells
> <150 m, so the swell path IS friction-active — friction coefficient is high-leverage). (b) **handoffs /
> convergence** — healthy per PRINT. (c) **whitecapping** — weak suspect: `GEN3 WESTHUYSEN` is the
> swell-friendly saturation scheme (fixed Komen's swell over-dissipation, confirmed by manual + literature).
> (d) **directional resolution** — operator: prior working models used the same/finer, so not it.
> (e) **MODE NONSTATIONARY+COMPUTE STAT**, **flow=0.03**, **df/f≈0.11**, **alfa=0.01**, **SORDUP default** —
> all manual-correct.
>
> **NEW REGRESSION FRAME (operator, 2026-08-01):** runs from ~a week ago (≈2026-07-24) did NOT show this
> loss → treat as a REGRESSION, not chronic. (Tension with R1's f337648 starvation — reconcile via the diff.)
>
> **Fable review dispatched 2026-08-01** (independent skeptical critique of the whole diagnosis +
> regression checklist + magnitude sanity-check). Integrate its findings here when it returns.
>
> **IDENTIFIED FIXES — tracked (do NOT leave as prose):**
> - [x] **★ THE SWELL FIX — regenerated the stale L1/L2 bathymetry caches** — DONE + VERIFIED 2026-08-01
>   (operator go). Backed up the two Jul-27 caches aside (`.stale-jul27-*.bak`), re-ran the production apply
>   chain (`load_config()`+`run_grid_sizing_chain()` via marine venv). Chain re-downloaded L1/L2 for the
>   CURRENT box: new L1 cache spans **lat 33.4560–33.7148** (was 33.5067; grid south edge ~33.47 now
>   covered), logged **"covers the full domain"** for L1 AND L2; ocean cells 576→856. **MEASURED on the
>   live cycle's fresh L1 BOTTOM.txt (deployed code 5581b0a, friction still 0.067 — clean isolation):
>   south edge 0/38→38/38 wet, whole grid 576→1064/1064 wet.** The swell's entry edge is real ocean again.
>   **END-TO-END REALITY GATE (measured, live cycle L1 `nest_out.dat`, 298 nest locations): L1→L2 handoff
>   swell(T>10s) = 0.62 m @ 10.7 s @ 192° (max), median 0.54 m, 219/298 locations > 0.3 m — vs 0.12 m
>   before. Swell RESTORED.** Confirms Fable's magnitude argument (swell was never dissipated in transit;
>   the 85% loss was the dead boundary). ⏳ Pending: confirm the full cycle PUBLISHES (the original
>   regression symptom) + durable code fix so this cannot silently recur.
> - [x] **★ DURABLE fix — re-run coverage gate on cache load** — CODE DONE (working tree, syntax-verified;
>   NOT committed/deployed). `providers/nearshore/swan.py`: added module-level `_grid_covers_domain_gap()`
>   (mirrors the download path's own `_covers()` criterion) and gated the cache-HIT early return — a
>   fresh-by-TTL but domain-SHORT cache is now treated like a missing/corrupt one: re-download at apply
>   (`allow_download=True`), hard-ERROR+abort at runtime (`allow_download=False`) rather than silently
>   returning a domain-short grid. Restores the docstring's "guaranteed to span the whole domain" contract.
>   Still TODO: (a) **verify `c3ceaa8` cache-clearing scope** (geometry-push must invalidate these
>   fixed-name caches); (b) optional bbox-key L1/L2 like L3/L4 (trigger-7 persisted-file naming — operator call).
> - [ ] **★ MISSING GUARD (would have caught this in seconds)** — invariant: every side named in a
>   BOUNDSPEC, and the BOUNDNEST1 ring, MUST have ≥1 wet boundary cell, else FAIL the run loudly. Extend
>   the trace to record computed Hs at the first WET row inside each forced boundary (so "swell enters" is
>   never again asserted from the input file alone). This — not maxerr — is the real guard.
> - [x] **FRICTION JON 0.067 → 0.038** — manual §FRICTION + Zijlema (2012): 0.038 for BOTH swell and wind
>   sea; 0.067 "discouraged even for wind sea." `swan_formats.py:~1783` (all 4 levels). Doc synced
>   (`swan-commands-extract.md:503`). **Code done, working tree — NOT committed/deployed. Valid correctness
>   fix but NOT the swell fix (recovers only a few cm). Do NOT run in the same validation as the cache fix
>   — confounds attribution (Fable).**
> - [x] **SET maxerr 3 → 2** — was running through SEVERE errors ("run no matter what"); now fails on
>   level-3, still allows warnings/repairable. Old code comment misread the boundary mismatch as level-2
>   (PRINT shows it is a `** WARNING`, level 1). `swan_formats.py:~1597`. **Code done, working tree —
>   NOT committed/deployed. NOTE: would NOT have caught this bug — SWAN emits nothing for a fully-dry
>   BOUNDSPEC side; do not credit maxerr as the guard (the wet-boundary invariant above is the guard).**
> - [ ] **South `[len]`=37975.34 > side length 37475.17** — buoy 46223 foot point projects ~500 m past the
>   SE corner; `ww3_boundary_files_and_command()` (`swan_formats.py:~2606`) never clamps. Dormant while the
>   side is dry; live the moment the cache is fixed. Clamp `[len]` into [0, side_len] or reject.
> - [ ] **Single VARIABLE point on a side** — `CONSTANT FILE` is the SWAN idiom for one station; VARIABLE's
>   extrapolation outside the given `[len]` range is undocumented. Revisit south/other single-station sides.
> - [ ] **OBSTACLE double-counting** — the identical `OBSTACLE TRANSM 0.74 LINE …` pier appears in BOTH
>   L1 and L2 INPUT (code threads one domain-wide `structures` list into every level's `build_swan_input`,
>   no L4-only gate) → a wave in the pier's lee is attenuated 26% at each grid level. **Fix (pending
>   operator nod on the split):** structure-grid-eligible (pier/jetty/groin/breakwater, which get an L4
>   grid) → obstacle on **L4 only**; **seawall** (no L4, per `swan_domain.py:1876-1881`) → obstacle on the
>   coarse grid that covers it. NOT a blanket "L4-only" (that would drop seawalls).
> - [ ] **surfbeat_runner.py:359 `SET … 200 3`** — separate surfbeat model carries its own maxerr=3;
>   align to 2 for consistency (pending operator ok — different subsystem).
> - [ ] **REGRESSION diff (highest priority given "worked a week ago"):** diff the SWAN-input generation
>   between ~2026-07-24 (last known good) and HEAD — projection/UTM switch (Cartesian), grid sizing/
>   orientation/facing, boundary `[len]` units, physics command, spectral resolution, obstacle routing.
>   Find the commit that introduced the loss.
> - [ ] **Isolation re-run (decisive experiment):** with friction=0.038 as the new baseline, re-run L1 and
>   measure swell at the nest; then toggle whitecapping OFF (`OFF WCAP`) and breaking OFF one at a time to
>   name the exact L1-interior sink. Manual §2.7 endorses this method.
>
> **DEFERRED (architectural — sign-off required, not now):** `GEN3 WESTHUYSEN → ST6` (+ `SSWELL ZIEGER` +
> `NEGATINP`) A/B for swell-in-mixed-seas. Only after friction + the regression diff are settled; ST6's
> nearshore benefit is "moderated by friction/breaking" per the literature, so it is not the likely bug.
>
> **Standing approvals (operator, 2026-08-01, in chat):** friction fix and maxerr fix authorized.
> Obstacle split + surfbeat straggler + isolation re-run + push/deploy: awaiting explicit go.
>
> ### ✅ DEPLOY + VERIFY — 2026-08-01 (coordinator, operator "push" go). Swell fix proven end-to-end; publish blocked by L4.
> **Pushed:** marine `5581b0a..51543b1` (open-water boundary sides + cache-coverage gate + friction 0.067→0.038 + maxerr 3→2; incl. `67911d2` NESTOUT trace fix) + meta `f27a25f..4e534f1`. **Deployed** via `scripts/deploy-marine.sh`: running commit `51543b1`, ExecMainStartTimestamp 2026-08-01 08:23:25 UTC. **Cleared ALL stale caches** (bathymetry L*/PROFILE, swan_grid_sizing.json, forecast_cache.json, hotstarts, level* workdirs, .stale-jul27 .bak) then **regenerated fresh** via the production apply chain (`run_grid_sizing_chain()`): L1 AND L2 both logged "covers the full domain" (L1 1064 cells, L2 5694 cells), `open_water_bearing_deg=215.0` persisted to `swan_grid_sizing.json`, beach_facing=217.0°. **One full nest run** via `run_all_spots()` (OMP_NUM_THREADS=6), service stopped for isolation.
>
> **MEASURED (artifacts in `/run/weewx-clearskies/swan/level1/`, code `51543b1`):**
> - **L1 `BOTTOM.txt` south rows 0–3 = 38/38 wet each; whole grid 1064/1064 wet** (was 0/38 dry with the stale cache). Cmd: parse `level1/BOTTOM.txt`, ncol=38.
> - **Boundary selection = 215.0° open-water, sides S/W** (was 238° beach facing) — journal `select_boundary_stations: ocean -- bearing 215.0 deg -> sides S/W -- S:[46223], W:[46256,46222,46253]`. South side is a REAL boundary (`BOUND_S_46223.txt`, 9 MB, written).
> - **L1→L2 nest swell (T>10 s) = 0.64 m @ 10.7 s @ 192° (max), median 0.54 m, 219/298 nest locations > 0.3 m** (was 0.12 m with the stale cache; target 0.5–0.6). Cmd: `/tmp/nestout_probe.py level1/nest_out.dat`. Matches the pre-fix session's independent 0.62 m. **Swell RESTORED — confirms the dead-boundary root cause.**
> - **PUBLISH: NO — `forecast_cache.json` ABSENT.** L1/L2/L3 all converged clean (L2 acc 99.6%, L3 acc 100%); **L4 alone failed: valid_fraction=5.2%** → the convergence gate is all-or-nothing and raised `RuntimeError: SWAN: convergence gate failed at level4_0; nothing published this cycle` (`swan.py:3210`). The runner had already computed a valid L2 DWR fallback for the spot (67 timesteps ~15 m, journal "falling back to the L2 DWR reference") but the outer gate discards it.
>
> **BOTTOM LINE:** the swell-starvation root cause (dead south boundary from the stale pre-facing-flip cache) is FIXED and VERIFIED. The model still does not publish — blocked by the **L4 convergence collapse under the AD-1R 217° facing**, which R1 already pinned (238° → L4 94.7%; 217° → L4 5–7%, measured 5.2% here). **That is R3, not R2.** No R2 code remains. Reality gate (published DWR vs NDBC 46222) is MOOT until publish is unblocked — no published value exists to compare. Service left running (`51543b1`); `/health`=`failed` on fresh-start reasons (has not run its own cycle yet). Full session record: coordinator scratchpad `phase-r-session.md`.
>
> **Remaining R2 sub-items NOT done this session (still tracked above, do not lose):** durable cache-coverage GUARD/invariant (wet-boundary check, item ★ MISSING GUARD — code for the coverage gate landed but the loud wet-boundary invariant did not); south `[len]` clamp; single-VARIABLE-point revisit; OBSTACLE double-counting split (pending operator nod); surfbeat maxerr; regression-diff commit hunt; whitecapping/breaking isolation re-run. These are correctness/hardening items, not publish blockers.

### R3 — L3-strip viability + frame integrity under AD-1R facing  ⏳ **REWRITE LANDED + DEPLOYED 2026-08-01 (marine `4e79d21`); full SWAN test run PENDING**

> **R3 UPDATE 2026-08-01 (rewrite landed, this doc-sync pass):** the L4-grid↔transect co-registration fix named
> in the "R3 UPDATE" note below (superseded) is BUILT: `compute_structure_grid_domain()` was rewritten
> (`services/swan_domain.py`, marine `4e79d21`) to size L4 from the beach-frame transect-shadow envelope instead
> of the OMBB structure axis — operator-approved in chat 2026-08-01, recorded as ADR-093 Amendment 6. Same-day
> amendment also dropped primary-structure/proximity-group narrowing (every eligible structure participates).
> See PROVIDER-MANUAL.md §14.15 and ADR-093 Amendment 6 for the full design. **Deployed; measured HB regen
> 2026-08-01 ~19:00 UTC:** facing resolved 216.4° from the shoreline strip; L4 = 46×137 = 6,302 cells, u_span
> 450 m, v_span 1358 m, rot 216.4°, dx 10 m, **143/143 transects shadowed**, 37 open rays, n_footprint_clipped=16,
> L_tip 128.3 m; L3 coarse nest 45×40 @ 40 m around L4 (≥200 m clearance) — contrast the pre-rewrite OMBB grid
> below (458×1247 m, rot 47.3°, 46×125 cells, 333/352 handoff points outside, valid_fraction 5.2%). **A full SWAN
> test run against the new grid was IN PROGRESS at the time of this doc-sync pass — no run/convergence/reality-gate
> result is claimed here; test run PENDING.** Operator rulings from the same session are recorded in the Decision
> log below.
>
> **R3 UPDATE 2026-08-01 (superseded by the rewrite above, kept for the record):** the publish-blocking symptom (L4 gate abort) is FIXED by R7 (see R7 result — model publishes + reality-gate PASS). The remaining R3 substance is the FRAME root cause: the pier-OMBB L4 grid (alpc 47.32°) does not co-register with the cross-shore transects — 0/32 transects get ≥3 band points inside it (they clip its deep corner). L4 therefore supplies no handoff and HB models as open-beach L2. Fixing this is a grid-orientation/placement change (`swan_domain.compute_structure_grid_domain` OMBB axis vs transect bearings) — trigger-3, operator decision, not required for correct publishing. R3 diagnosis block below retained.

> **R3 DIAGNOSIS — 2026-08-01 (coordinator, hard measurement on the preserved failing L4 workdir `/tmp/r3-evidence` on librewxr; code `51543b1`, 217° facing).** This is why the model does not publish (R2 DEPLOY+VERIFY block).
> - **`valid_fraction` (L4, nonstationary) = fraction of forecast TIMESTEPS where ≥50% of the per-transect handoff POINTS have a valid Hs** (`swan_runner.py:5776-5784`). Measured L4 = **5.2%**.
> - **L4 CGRID:** `REG` origin (407323.57, 3723898.01) UTM, **alpc=47.32°**, xlen=458.05 m, ylen=1247.52 m, 46×125 cells. BOTTOM INPGRID 372×367 @ 10 m.
> - **★ Root mechanism (measured): 333 of 352 handoff POINTS fall OUTSIDE the rotated L4 computational grid; only 19 inside (5.4% ≈ valid_fraction 5.2%).** The outside points sit at grid-local cross-shore x = **−117.1 .. −0.6 m** (grid spans x: 0..458), local-y 129.5..421.7 (fully within 0..1248). **The misalignment is purely CROSS-SHORE**: the grid's shoreward edge is placed up to ~117 m offshore of the transect handoff points it exists to sample. Along-axis placement is correct.
> - **The grid straddles the waterline:** L4 BOTTOM median depth **−0.17 m**, **54% of cells shallower than the 1.78 m breaking depth** (0 EXCEPTION cells, but ~half the grid is subaerial/surf-zone → dry in the computation). Compounding WARNINGs this run: per-transect profiles "never reach 0.51/1.00/2.24 m — depths span 2.822–15.955 m" (points snap to the shallowest available sample at ~2.8 m), and L4 sizing "tip depth unavailable from the cached FINE profile at −339 m from the anchor — using the 150 m margin-wavelength fallback." So both the grid extent AND the point depths fell back under this facing.
> - **Reconciles R1:** 238° facing → L4 94.7%; 217° → 5.2%. The AD-1R facing rotates the OMBB-derived grid (alpc) so the separately-derived handoff points fall off its shoreward edge. The open question R3 named — "is the anchor/bbox derivation in a consistent frame, or does the rotation expose an origin offset" — resolves to: **grid-origin derivation (`swan_domain.compute_structure_grid_domain`) and per-transect POINTS derivation are not co-registered on the cross-shore axis under the new facing** (cf. HB's documented anchor-vs-pin ≈209.6 m and segment ≈213.5 m offsets).
> - **FIX CLASS = OPERATOR DECISION (both candidates are gated):** **(A)** the AD-1R 217° facing itself — R1 showed 238° recovers L4; changing the facing criterion is **architectural (trigger 1)**. **(B)** re-register the L4 grid's cross-shore extent (and/or the transect point depths) to the breaking-depth contour under the current facing so the grid actually reaches its points — this **moves a grid extent/edge (trigger 3)** and is the exact class of the 2026-07-25 grid-resize incident, so it needs sign-off even though it reads as a co-registration bug fix. **Coordinator did NOT implement either.** Recommendation for the operator is in the session report + scratchpad.

**Owner:** `clearskies-api-dev` after R2. **Design:** with the facing chain at 217°, re-verify
the L3-strip viability test passes (structure reachable); if it still fails, the anchor/bbox
derivation inherits the same frame bug — diagnose against the 238°-era bbox
`[33.64135,-118.02855 – 33.65696,-118.00203]` (worked) vs the failing
`[33.633251,-118.033738 – 33.655251,-118.002549]`. **Accept:** viability PASS logged at config
push, L3 re-enabled, and the L4 sizing log's shoreward reach/along-span within 15% of the
238°-era values (30 m / 483 m) OR a justified explanation of the delta.

### R4 — No-publish paths must be loud and truthful  ⬜
**Owner:** `clearskies-api-dev`. **Design:** trace the 11:51 abort (gate PASSED, zero published
entries, no ERROR naming the abort): follow "zero usable L3 handoff timesteps" through the
publish/cache step; every path that ends a cycle with nothing published must (1) log ONE ERROR
naming the reason, (2) set B3 `/health` `status != ok` with a `reasons` entry, (3) appear on the
admin status page. A viability-test failure at config push must likewise surface via B3, not
only the journal. **Guard:** a forced degraded cycle yields `degraded`/`failed` health, never
silent `ok` + no-publish. **Must not touch:** the serve-nothing-on-failure rule (G1R.0 stands).

### R5 — BOUNDSPEC `[len]` units fix (defect, latent)  ⏳ **IN PROGRESS 2026-08-01 (operator-directed; promoted ahead of R2/R3 because R1 measured it live-wrong)** — `clearskies-api-dev` implementing degrees→meters at the emitter + a known-answer guard; coordinator runs the reality-gate model check (does swell reach the 15 m reference) at acceptance. NOTE: fixes a confirmed defect + the west-side 3-station mangling for sure; whether it fully restores the south swell is settled by the acceptance model run (R1 caveat: single-spectrum south side may need more).
**Owner:** `clearskies-api-dev`. **Design:** in Cartesian mode emit meters along the side
(convert `len_deg` at the emitter or compute `len_m` in `select_boundary_stations()`); verify
VARIABLE FILE semantics against the LOCAL manual (`docs/reference/swan-user-manual.txt`) §2.6.3
— never web-fetch SWAN docs. **Guard:** KAT asserting emitted `[len]` equals the UTM distance
of each station's projection along the side (known-answer from hand-computed geometry).

### R6 — WW3 fetch hygiene  ⬜
**Owner:** `clearskies-api-dev`. **Design:** exponential backoff + per-cycle retry cap on the
NOMADS station-spectra fetches (403/404 observed with hot retry loops, journal Jul 30–31); a
cycle that runs on cached boundary data logs it and reflects it in B3 `inputs.ww3_boundary`
(age + `available`). **Accept:** a blocked NOMADS never produces a hot loop; staleness visible
in `/health` without reading the journal.

### R7 — Handoff containment trio (ARCHITECTURAL — designs for operator sign-off, then build)  ✅ **BUILT + DEPLOYED + PUBLISH RESTORED + REALITY-GATE VERIFIED 2026-08-01 (operator chat go)**

> **R7 RESULT — 2026-08-01 (coordinator; operator approved build in chat "fix the handoffs").** Commit `2087fc1` (marine, pushed + deployed to librewxr, running 11:42:52 UTC). clearskies-api-dev implemented per coordinator design (scratchpad R3-R7-design.md); coordinator QC'd (diff = swan_runner.py + tests/test_swan_l4_intersection.py only; independent pytest 93 passed; spot-checked prune + gate filter).
> - **R7.1** — `_transect_band_depths` shallow floor 0.1 m → `l3_shoreward_edge_depth_m()` (≈1.78 m). No station placed in the surf zone.
> - **R7.3** — per-transect L4-intersection test (`_point_in_rotated_rect` + `_l4_cgrid_geometry_utm` + `_l4_point_is_wet`): each transect's band pruned to inside-rotated-CGRID + wet points; ≥3 survivors → L4, else → L2 (via the pre-existing, unmodified `resolve_handoff_by_transect` fallback).
> - **R7.2** — `_check_convergence` Check 3 scoped to `TABLE_PT_*` for `level4_*` (excludes the diagnostic CURVE table, which was being counted); 0 TABLE_PT → no-op PASS, not FAIL.
> - **★ THE PUBLISH FIX (measured, live nest, commit 2087fc1, HRRR 06Z):** `SWAN convergence OK level=level4_0: accuracy=99.5%, valid_fraction=0.0%` (no-op pass) → **`forecast cache persisted to disk (1 spots, 3.2 MB)` — MODEL PUBLISHES** (was `RuntimeError: nothing published this cycle`). Served surf endpoint returns HTTP 200 with real swell.
> - **★ REALITY GATE — PASS (vs NDBC 46222 San Pedro, obs 2026-08-01 11:56 UTC):** buoy total WVHT **0.8 m**, swell **0.3 m @ 13.3 s @ S**. Model 12:00Z DWR: total **0.79 m**; multiSwell = 0.55 m @ 10.4 s @ 192° + **0.47 m @ 13.5 s @ 198° (groundswell)** + 0.31 m @ 4.1 s @ 265°. Total Hs match within 1%; the long-period groundswell matches the buoy in period (13.5 vs 13.3 s) and direction (198° vs S) — inside the pre-declared ±30%/±2 s/±30° tolerances. Swell restoration validated against an independent buoy.
> - **RESIDUAL (NOT a routing/gate defect — the R3 geometry root cause):** L4 provides a handoff for **0 of 32 transects** — 15 transects graze the L4 CGRID with only 1–2 points each (max 2; ≥3 needed for an interior station), because the pier-OMBB-rotated L4 grid (alpc 47.32°) and the cross-shore transect bearings are geometrically mismatched: transects clip the grid's deep (~11 m) corner rather than running through it. So HB currently models as open-beach L2 — the pier's refraction/sheltering is not captured. This is R3 frame/geometry (L4 grid ORIENTATION/PLACEMENT vs transect bearings — trigger-3), separate from R7's routing+gate, and NOT required for correct publishing (HB matches the buoy today). Fixing it = align the L4 OMBB axis / grid placement with the transects, or densify the band — a geometry change for operator decision. Tracked as R3-residual.
> - health=`failed` after the restart is R4 restart-lag (serves real cached data but the service hasn't run its OWN cycle; self-resolves next cycle) — separate task R4.

Per the operator architecture ruling recorded in TC-23 (2026-07-31). Three coordinated designs,
each a separate sign-off item, none pre-approved by this plan:
1. **Hs floor in station placement:** apply `_MIN_DESIGN_HS_M` to `_transect_band_depths()` so
   no station is ever placed shoreward of the 1.78 m design contour (trigger 1 — criterion).
2. **Rescope the L4 `low_valid_fraction` gate** to judge L4 only on cells/outputs L4 is
   responsible for — "fan outside L4" is a routing condition, not an L4 failure (trigger 1).
3. **Per-transect L4-intersection routing:** each transect reads L4 where it intersects wet L4
   coverage; otherwise it continues to L2 (fixed 15 m reference) — the FINDINGS-D3 ladder at
   transect granularity, per the operator's stated architecture (triggers 2/4).

### R8 — Test audit: delete/replace tests that pin superseded behavior  ✅ **DONE 2026-08-01 (pushed; operator waived pytest re-verify)**
> **Status 2026-08-01 (coordinator):** Inventory + one scoped deletion, **pushed to origin/main**
> (operator gave "push" 2026-08-01): `5874578` (TEST-INVENTORY.md, all 58 tests classified) →
> `99f2378` (per-function correction) → `cb0fe57` (removed the dead E1
> `compute_structure_grid_resolution` KAT, renamed the file to `test_tip_depth_from_fine_profile.py`,
> kept the 9 live guards) → `14b769f` (stale cross-ref fix). Audit result: the suite is essentially
> clean — **zero** tests pin superseded behaviour in their own assertions; the single file-level
> DELETE-candidate was a misclassification (it also guarded the LIVE `tip_depth_from_fine_profile`,
> called `swan_domain.py:2253`), caught at coordinator review, so only the dead-function part was
> removed. Operator **waived** the pytest re-verification (2026-08-01: "no you do not need to test the
> test … we have nothing to test"). Gate R row 6: inventory delivered + stale test removed = met.
**Owner:** `clearskies-test-author` under coordinator review. **Why:** a stale test that pins
superseded behavior invites the next agent to "fix" code back to it — a reversion engine.
**Design:** inventory EVERY marine-repo test touching facing/geometry/handoff/boundary/gate;
classify each as (a) known-answer (independent reference — keep), (b) behavior-pinning current
design (keep, cite the ADR/brief it pins), (c) **pinning superseded behavior — DELETE in the
same commit that documents why** (candidates: segment-perpendicular/238° relics, isobath
ray-fit leftovers, 2-point-pier OMBB-equivalence fixtures, anything asserting fan-inside-L4
gate semantics or L3-strip-era handoff). **Deliverable:** `docs/planning/briefs/TEST-INVENTORY.md`
— one line per test file: what it asserts, class, verdict — the operator-readable answer to
"what tests exist." **Accept:** zero tests remain that assert superseded design; inventory
committed.

### R9 — Brief→plan reconciliation audit  ⏳ **DIVERGENCES LOGGED 2026-08-01 (TC-24); doc CORRECTIONS deferred to R7/R10 pending the R3 ruling**

> **R9 status 2026-08-01 (coordinator + read-only sweep agent):** all 9 brief↔plan divergences logged to `MARINE-GEOMETRY-MODEL-CONCERNS.md` **TC-24**. Key findings: (1) the briefs + geometry-plan OFF-LIMITS still assert the L4/per-transect-handoff machinery "already works / is off-limits," contradicted by the measured R3 reality (333/352 points outside L4) and the TC-23 operator ruling — but correcting them depends on the R3 A-vs-B decision, so DEFERRED; (2) facing method-of-record is stale in SURF-ZONE §2.6 + STUDY-AREA §1/§5 (still isobath-gradient; AD-1R replaced it) — safe R10 fix; (3) `ARCHITECTURE.md:117` "+15 km" L1 margin vs code/brief "+10 km" — safe R10 fix; (4) handoff-ladder + 1.78 m floor own no plan task — R7/R9 follow-up after R3. The "correct the plans" half of R9 is intentionally held until R3 is ruled (the geometry plan is suspended pending Gate R; editing it now pre-judges the facing decision).

**Owner:** coordinator (docs). **Design:** walk `STUDY-AREA-GEOMETRY-BRIEF.md` §3.1 (FIXED
table), §0/§3.3.6 (L4-need-not-cover-fan + clamp), `SURF-ZONE-MODEL-BRIEF.md` §2.3.4 (with its
supersession boxes), and the geometry plan's AD-1R/AD-3/AD-4 against BOTH plans; log every
divergence found to `MARINE-GEOMETRY-MODEL-CONCERNS.md`; correct the plans. Known divergences
to seed it: the handoff ladder (first-match L4→L3→L2 @ 15 m) and the 1.78 m shoreward-reach
rationale appear in NO plan task; the geometry plan's G-phases never referenced the FIXED table.

### R10 — Manual doc-sync (what the Sonnet agents actually read)  ⬜
**Owner:** `clearskies-docs-author` after R7 designs are ruled. **Design:** update
`docs/ARCHITECTURE.md` (marine section, :99–127) and `PROVIDER-MANUAL.md` §14.15 (+ OPERATIONS
where touched) to state: AD-1R facing (setup-time, operator-overridable); the L4-coverage ruling
(L4 = obstacle refinement, never sole handoff; open beach has no L3/L4); the handoff ladder
incl. per-transect routing once R7.3 lands; the 1.78 m floor semantics; the serve-nothing +
loud-refusal behavior (R4). **Accept:** an agent reading only the manuals reproduces the
operator's architecture — no manual statement contradicts a ruling.

### R11 — QC hardening: rule edits (land BEFORE dispatching any Phase-R agent)  ✅ **DONE 2026-07-31**

> Landed with operator approval (chat, 2026-07-31): `rules/verification.md` gained "Marine deploy
> verification — reality gate and publish-liveness" + "Evidence hygiene"; `rules/coordinator.md`
> gained §7 "Deploy discipline"; `rules/agents.md` gained the "Stale-test block — mandatory agent
> prompt section"; all six `.claude/agents/clearskies-*.md` profiles gained "Stale tests and fired
> guards". The continuous reality invariant + `last_publish_age_s` health field + reality-check
> script fold into R4/R6 dispatch. The draft wording below is retained as the design record.
**Owner:** coordinator; operator approves final wording. Draft content:
1. **`rules/verification.md` — Reality gate on every marine deploy:** within one forecast cycle
   of ANY marine deploy/config push, paste published (or DWR) Hs/Tp/dir beside NDBC 46222 (or
   Surfline) values; disagreement beyond stated tolerance = deploy FAILED, roll back. *A deploy
   with no reality comparison is not complete.* (The operator's manual Surfline checks caught
   every regression the gates missed — make that check mandatory and mechanical.)
2. **`rules/verification.md` — Publish-liveness check:** after any marine deploy, confirm a
   publish (or an explicit, health-visible refusal) within one cycle. Silent `ok` + no-publish
   = FAILED deploy.
3. **`rules/verification.md` — Stale tests:** a task that changes behavior updates/deletes the
   tests pinning the old behavior IN THE SAME COMMIT. An agent finding a failing test that pins
   superseded behavior STOPS and surfaces — **never** alters code to satisfy it.
4. **`rules/agents.md` — mandatory prompt line for implementation agents:** "If an existing
   test contradicts your tasked change, STOP and report it. Do not modify code to make a stale
   test pass; do not delete a test without listing it in your report."
5. **`rules/coordinator.md` — One functional change per deploy** during restoration/recovery
   phases; **baseline capture before replacing any working input** (record facing, DWR Hs,
   valid_fraction, station-band depths pre-change and diff post-change in the gate).
6. **`rules/coordinator.md` — A fired guard is a gate event:** any viability/invariant/guard
   failure at config push or runtime during a gated task is pasted into the gate record and
   surfaced to the operator — "the guard fired and we continued" (11:16, L3 disabled) is the
   exact shape this plan exists to end.

## ⛔ QC GATE R

| # | Element | Evidence |
|---|---|---|
| 1 | Model publishes on current HEAD | `published` trace records this cycle; site serves forecast |
| 2 | Reality gate passes | pasted model-vs-NDBC/Surfline comparison within tolerance |
| 3 | Swell present at 15 m reference | DWR partition table shows the boundary's swell partition (period + direction), not wind chop alone |
| 4 | valid_fraction ≥ 80% on a full nest | journal line pasted |
| 5 | No silent no-publish path | forced degraded cycle → health != ok + admin page shows reason |
| 6 | Test inventory delivered, stale tests gone | `TEST-INVENTORY.md` committed; deletion commit hashes |
| 7 | Rules landed | R11 edits committed with operator-approved wording |
| 8 | Manuals match rulings | R10 spot-checked by adversarial auditor against TC-23 ruling |

**Adversarial:** auditor gets the R-DIAGNOSIS table and this gate — briefed to disprove rows 1–4
with live artifacts, and specifically to attempt one "plausible but stale" test resurrection to
prove row 6's process holds.
