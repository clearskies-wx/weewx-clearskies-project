# Marine Model Evolution Plan — WW3 deep-water leg, evidence-driven strengthening, hybrid LUT (2026-08-15)

## INDEX — ALPHABETICAL (keep current; sections below sit in execution order — FIND THINGS HERE. Every new `##` section gets an entry the same commit.)

Ctrl-F the exact heading text:

- `## 📍 CURRENT STATE` — live state, rulings, waiting-on-operator
- `## CARRY-OVER REGISTER` — open items inherited from the closed Fixit plan
- `## NAMED CONSTANTS` — plan-fixed values agents may not re-derive
- `## OPEN OPERATOR QUESTIONS`
- `## PHASE F` — WW3 feasibility build + benchmark (scratch-only, first)
- `## PHASE DOC-W` — ADR-109 + governing docs BEFORE implementation code
- `## PHASE W` — WW3 deep-water leg implementation
- `## PHASE V` — validation against reality + cutover ruling
- `## PHASE R` — strengthening fixes from the research brief
- `## PHASE L` — hybrid lookup-table (LUT) system (LAST, gated)
- `## PRE-APPROVAL REGISTER` — which architectural changes this plan authorizes
- `## PRIME DIRECTIVE`
- `## Round-close & bookkeeping`
- `## SYNTAX PRESCRIPTIONS` — SWAN (local manual) + WW3 (its own manual), binding

## 📍 CURRENT STATE — updated every working session (last: 2026-08-15, plan drafted)

**Status:** DRAFT — execution begins on operator GO. Adversarial Fable review was ordered and
dispatched 2026-08-15; the reviewer was STOPPED by the operator mid-run. Its five previewed
findings (sent before the stop) were independently verified by the lead and applied — see
Round-close record. A full replacement review runs only if the operator asks. Predecessor [MARINE-PAGE-FIXIT-PLAN-2026-08-10.md](../archive/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md)
CLOSED 2026-08-15 and archived; its open items live in this plan's CARRY-OVER REGISTER.

**Evidence record / authority:**
[SWAN-ENERGY-LOSS-RESEARCH-2026-08-15.md](../reference/SWAN-ENERGY-LOSS-RESEARCH-2026-08-15.md)
— the formal research brief this plan operationalizes. Every physics/architecture claim in
this plan cites that brief (coordinator-verified manual/code cites inside it) or a named
experiment record. This plan does not restate the evidence; it turns it into tasks.
Companion records: `RESEARCH-WW3-FEASIBILITY.md`, `RESEARCH-R1R2R4-DEPTHSTEP.md`,
`RESEARCH-R3-GRID-ARCHITECTURE.md`, `RESEARCH-R5-DIFFRACTION.md`,
`P2-CONFIRMATION-PROTOCOL.md` (all in `scratch/` at the project root — the standing scratch
location per CLAUDE.md, operator order 2026-08-15), `/tmp/e1e2/` on librewxr (experiment
decks/outputs).

**What the operator ordered (2026-08-15, in chat), verbatim intent:**
1. Close and archive the Fixit plan (done).
2. New plan, same skeleton and component requirements, operationalizing the research brief.
3. Implement and test our own WW3 system for deep water — with care on WHEN it applies:
   "in many situations our original system of NOAA WW3 handing off to SWAN would probably
   work fine… it is when we have things like complicated bathymetry/island/etc that trigger
   a much larger grid size that we know SWAN struggles with, that we kick in our own WW3 as
   an intermediate step to take over the L1 functionality… or do we think that our own WW3
   should take over ALL L1 functionality regardless?" → OPEN OPERATOR QUESTION Q1 (lead
   recommends CONDITIONAL; plan is structured for conditional; an "always" ruling collapses
   W4's trigger to always-on with no other structural change).
4. Implement the other major strengthening areas from the brief.
5. LUT system LAST — "only after plenty of testing and tweaking to make sure we are getting
   what we feel are accurate and defensible results from the modeling system."
6. Adversarial Fable review of this plan before it lands (dispatched; stopped by the operator
   mid-run; previewed findings verified + applied — see Round-close record).

**Live baseline at drafting (from the closed plan's final state):** marine service healthy;
big-L1 non-stationary architecture (ADR-108) deployed and validated (A1.5 reality gate PASS:
served 0.53 m southerly vs buoy 0.5–0.6 m); full run ~5280 s, hourly cycles store-driven;
L1 nest-age refuse gate `L1_NEST_MAX_AGE_H = 9` active. Unpushed local commits inventoried
in CARRY-OVER.

**THIS PLAN IS THE ARCHITECTURAL PERMISSION** (same convention as the Fixit and
L1-Boundary-Rebuild plans; operator 2026-08-08: "The plan serves as permission for
architectural changes, so if it is in the plan, it is allowed"). The PRE-APPROVAL REGISTER
enumerates every authorized architectural change **contingent on operator GO of this plan
and acceptance of ADR-109 (Phase DOC-W)**. A change NOT in the register stays under the
CLAUDE.md HARD BLOCK.

**Relationship to other live plans:**
- [L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md](L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md) stays
  ACTIVE with its deferred queue (Gate S wlevel → S1+S4a currents → Phase A → Gate C → V).
  NOT absorbed. Where Phase W lands the WW3 leg for triggered sites, that plan's L1-specific
  rows apply to the untriggered (SWAN-L1) path only; cross-references land during DOC-W.
- [MARINE-FORWARD-PLAN.md](MARINE-FORWARD-PLAN.md) open rows untouched; its frozen-core
  list binds here except where a task's Files list names the file.

---

## PRIME DIRECTIVE — carried over from the Fixit plan, binding on every task

1. **Frozen core is OFF LIMITS unless a task's Files list names the exact file.** The
   frozen-core lists of MARINE-FORWARD-PLAN / L1 plan remain closed — explicitly: SWAN wave
   physics marches, jacking, hotstart mechanics, convergence gate, serve-nothing guard,
   `CIRCLE 72 0.03 1.0 34`, `omp_num_threads = 6`, L2/L3/L4 sizing. Phase tasks below name
   their files at dispatch; a file not named is not open.
2. **Baseline before, diff after** every deploy (facing, DWR Hs, valid_fraction, publish
   size, cycle wall-clock, boundary file count/bytes; Phase W adds WW3-leg wall-clock and
   nest-file size). rules/coordinator.md §7.
3. **One functional change per deploy.**
4. **Reality gate on every deploy** (rules/verification.md): matched-time comparison vs NDBC
   46222/46253 + Surfline buoy cards + cam within one cycle, quantities chosen before
   looking; publish-liveness.
5. **Stale tests → STOP and surface** (rules/agents.md block, verbatim in every brief).
6. **Agent discipline:** every implementation task runs on a Sonnet agent with a written
   brief containing the rules/agents.md mandatory blocks (git, stale-test, architectural) +
   scope-ack before code + adversarial `clearskies-auditor` pass BEFORE the lead gate +
   doc-sync in the same round. Adversarial gates use results-free gate-definition files
   (contamination lesson, 2026-08-14).
7. **Line numbers are hints, not gospel.** First agent action: verify quoted state.
8. **No silent fallbacks.** Missing data → refuse loudly. Never a fabricated default.
   Binding on the WW3 leg from day one (nest-age gates, boundary viability, build/run
   failure = refuse, not degrade).
9. **Plain-English displays and docs.** Operator-facing text defines terms; the research
   brief's plain-language standard (operator correction 2026-08-15) binds all plan-produced
   documents.
10. **Model-behavior source rule (NEW, from this round's incident):** SWAN behavior comes
    ONLY from the local SWAN manual; WW3 behavior comes ONLY from the committed WW3 manual
    (DOC-W.4) / WW3 source / NOAA's own docs. NEVER infer one model's behavior from the
    other's manual. Binding on every brief and every design block.

**Execution order (strict):** Phase F → Phase DOC-W → Phase W → Phase V (cutover ruling) →
Phase L last. Phase R: R2/R3 may interleave any time after DOC-W (independent of WW3);
R1 requires Phase W's handoff machinery. Docs precede code in every phase (operator
standing instruction).

---

## PRE-APPROVAL REGISTER — the architectural changes this plan authorizes (and no others)

All rows contingent on: operator GO of this plan + ADR-109 Accepted (DOC-W.1). Phase F is
scratch-only and needs no register row (no production change of any kind).

| # | Change | Trigger(s) | Ruling basis |
|---|--------|-----------|--------------|
| PW1 | **WW3 deep-water leg added to the modeling system**: the WW3 model binary (built from NOAA-EMC/WW3 source, LGPL v3) runs as OUR process for the deep-water domain at sites where the trigger (PW2) fires; SWAN's chain then begins at L2. New dependency (WW3 build), new persisted files (WW3 grids, obstruction masks, nest/boundary files), new schedule entries (WW3 cycle runs), computation moves host-internal from SWAN-L1 to WW3. Deck/grid specifics fixed in ADR-109 from Phase F measurements. | 2, 3, 5, 6, 7 | Operator 2026-08-15 in chat ("we should go ahead and implement and test our own WW3 system for deep water"); research brief §4 Option E + §7 (NWPS precedent) |
| PW2 | **Conditional trigger in grid-sizing**: a mechanical, config-time decision computed in `compute_domains()`-adjacent sizing code — inputs: outer-domain extent vs threshold, islands-inside-domain, depth-step detection (Δh/h-style rule per brief §5) — selecting SWAN-L1 path (unchanged, default) vs WW3-leg path. Logged and testable; NEVER a per-site hand list. Threshold values fixed in ADR-109. **PENDING Q1**: if the operator rules "always," this row becomes an always-on assignment with the same machinery. | 3, 6 | Operator 2026-08-15 (the "kick in our own WW3" framing); Q1 ruling completes it |
| PW3 | **WW3→SWAN L2 handoff contract**: L2's boundary source for triggered sites becomes WW3 output (mechanism — BOUNDNEST3 nest file vs Appendix-D spectra files — fixed in ADR-109 per F evidence; SYNTAX PRESCRIPTIONS bind grammar). The existing per-wet-cell BOUNDSPEC mechanism stays for the untriggered path. | 3, 4 | Research brief §7 (BOUNDNEST3 manual-native); ADR-109 |
| PW4 | **Boundary reconstruction gains a WW3-input emitter**: the existing parametric-spectra reconstruction (constants UNCHANGED) gains an output path writing WW3 boundary input (via ww3_bounc workflow) for the WW3 leg's offshore boundary. | 4, 7 | Research brief §7 (nesting mechanism); reuse of the solved reconstruction problem |
| PW5 | **WW3-leg operational surface**: health keys (WW3 nest age analog of `l1NestAge`), refuse gates, config keys for the trigger/paths, wizard+admin surface for install/enable state. Key names/values fixed in ADR-109. | 6, 7 | Refuse-loudly posture carry-over; OPERATIONS-MANUAL sync |
| PW6 | **Handoff placement rule (R1)**: grid-sizing gains the depth-step DETECTION rule (brief §5: per-cell depth-change ratio), computed and logged for BOTH paths. Placement preference is APPLIED only to the triggered path's new WW3→L2 handoff at Phase W. Relocating the LIVE untriggered path's L1→L2 seam is authorized by this row but ONLY as its own separate deploy round (never bundled), with the cliff-KAT number measured before/after and the change operator-visible — because the research verdict is that seam relocation is UNPROVEN as a fix; the measurement delivers the verdict. | 3 | Research brief §2 + §5; operator sees the before/after |
| PW7 | **Fed E-side boundary (R2)** — IF the re-derived census (R2.1, read-only) shows material unfed energy: the E offshore side gains boundary feeding via the existing per-wet-cell mechanism. NOT pre-approved beyond that mechanism; a different mechanism returns to the operator. | 3, 4 | Fixit-plan unfed-E finding (8–11 pt upper bound, index-corrected derivation pending) |
| PW8 | **Problem-2 fix (R3)**: WITHHELD. R3 runs the confirmation protocol (T1–T3) and brings the verdict + fix proposal to the operator. Any multiSwell selection/assembly change is architectural and NOT pre-approved. | 4 | P2-CONFIRMATION-PROTOCOL.md pre-declared verdict criteria |
| PW9 | **LUT system (Phase L)**: WITHHELD ENTIRELY. Phase L opens with its own design round and ADR-110; nothing in Phase L is authorized by this register. Listed so the boundary is explicit. | all | Operator: LUT is last, gated on defensible model results |

Withheld in general: model-physics changes of any kind (SWAN or WW3 source terms, breaking,
friction — any formula/constant); cutover/decommission decisions (V4/V5 are operator ruling
rows); anything touching the untriggered path's frozen core.

---

## CARRY-OVER REGISTER — inherited open items (from the closed Fixit plan + session)

| # | Item | State at close | Where it lands |
|---|------|----------------|----------------|
| C1 | B2-Accept (served multiSwell shows real trains) | **UNBLOCKED since 2026-08-14**: the operator's freeze condition ("not eyeballing anything else until you get the model right" = A1 passing its reality validation, A1.5) is SATISFIED — A1.5 PASSED 2026-08-14 | Operator may eyeball ANY TIME; V3 offers a consolidated round at the latest |
| C2 | S-Accept card eyeball | pending operator; unblocked (same A1.5 condition) | Any time; V3 at the latest |
| C3 | K-Accept rows 1 (cam eyeball) + 3 (knob drill go) | pending operator; unblocked (same) | Any time; V3 at the latest |
| C4 | H re-accept (dry-beach + ortho remediations deployed) | pending operator; unblocked (same) | Any time; V3 at the latest |
| C5 | Unfed-E census re-derivation at corrected time index (06Z = index 2 in 3-hourly files) | derivation error found, not redone | Task R2.1 (read-only, first R2 step) |
| C6 | Problem-2 confirmation protocol (T2 free; T1/T3 need capture-mechanism sign-off) | drafted, not approved | Task R3.1 (T2 starts free); T1/T3 mechanism = OPEN OPERATOR QUESTION Q2 |
| C7 | Fresh buoy apples-to-apples (18s SSW event; old probe hung, killed) | owed | Folded into V3's matched-time comparison rows (and available on request any time) |
| C8 | Two rule-lessons pending operator go/no-go: (a) results-free gate briefs → rules/agents.md; (b) post-remediation rerun scope → rules/verification.md | proposed | OPEN OPERATOR QUESTION Q3 |
| C9 | Unpushed local commits: meta repo ahead (A1 as-built docs, gate records, research brief chain, this plan's closeout/creation commits); marine ahead 1 (`e40d2c9` F2 citation comments) | local-only | Pushed only on the operator's word "push" (standing rule); inventory kept current here |
| C10 | Marine failure monitor `b4omhq1fs` | armed | Stays armed through this plan |
| C11 | L1-BOUNDARY-REBUILD-PLAN deferred queue (Gate S wlevel → S1+S4a currents → Phase A → Gate C → V) | that plan's own queue | NOT absorbed; noted for scheduling awareness only |
| C12 | Research-round scratch artifacts worth keeping (WW3 manual text extraction, energy-ledger scripts) | `scratch/` at project root + /tmp on librewxr (the WW3 source clone was DELETED 2026-08-15 per the SSD cleanup — re-fetchable; its manual extraction is preserved in `scratch/`) | DOC-W.4 commits the WW3 manual text to docs/reference AND the ledger scripts to `scripts/analysis/` (repo changes belong to DOC-W, keeping Phase F pure scratch) |
| C13 | Phase T (tide coherence) close acknowledgment — the archived plan's WAITING-ON-OPERATOR item 4, deployed but never nodded closed | owed since 2026-08-11 | One-line operator acknowledgment (or reopen) at any convenience; listed so it isn't lost |

---

## NAMED CONSTANTS fixed by this plan (not re-derivable by agents)

- **Energy-ledger band edges: < 0.09 Hz / 0.09–0.2 Hz / > 0.2 Hz** (>11 s / 5–11 s / <5 s)
  — the measurement frame every before/after comparison in this plan uses. Log-spaced
  spectral integration per the existing ledger scripts (uniform-spacing integration
  under-reads ~5× — known trap, Fixit plan record).
- **The cliff KAT** (uniform 0.650 m no-physics boundary → seam, 2-minute stationary run)
  is the standing regression instrument for shelf-break/seam work (R1, V2). Its current
  answer: 0.578 m at the seam. Any change claiming seam improvement must move THIS number
  and say by how much.
- **`L1_NEST_MAX_AGE_H = 9`** carries over for the untriggered path; the WW3-leg age-gate
  analog gets its value in ADR-109 (not invented by agents).
- **Benchmark comparability rule (Phase F):** the WW3 benchmark runs the SAME archived
  cycle inputs as the SWAN baseline it is compared against (same boundary source data, same
  wind window), and reports the same ledger bands at the same seam coordinates. A benchmark
  not meeting this rule is reported as invalid, not adjusted.
- **WW3 global-step sizing starts at the manual's own guidance** (2–4× the critical
  propagation step; the Frontiers 2026 coastal application used 3×) — F2 fixes the value
  from measurement, ADR-109 records it.
- Reconstruction spectral constants (JONSWAP γ 3.3, cos²ˢ spreads s=28/s=7, adaptive σf
  rule, bin-sum identity ≤ 5%, HTSGW-inconsistency guard 0.1 m): **UNCHANGED** — PW4 adds
  an output format, never touches how a spectrum is built.

---

## SYNTAX PRESCRIPTIONS — binding; sources are model-matched (PRIME DIRECTIVE 10)

**SWAN side (LOCAL manual only, `docs/reference/swan-user-manual.txt`):**
1. Untriggered path: BOUNDSPEC per-wet-cell grammar carries over verbatim from the Fixit
   plan §SWAN SYNTAX (one command per offshore side, `[len]` ascending, endpoint copies,
   Appendix-D file grammar unchanged).
2. Triggered path, candidate A — **BOUNDNEST3**: reads a WAVEWATCH III nest file; the
   boundaries of the WW3 nest and the SWAN grid must coincide per manual :2701–2713, and
   the WW3 output "ha[s] to be created with the post-processor of WAVEWATCH III" (:2713).
   Candidate B — WW3 output → our existing Appendix-D spectra writer → BOUNDSPEC (grammar
   above, source data changes, mechanism doesn't). **ADR-109 picks A or B from Phase F
   evidence** (fidelity, file size, failure modes). Until then BOUNDNEST2/3 remain
   forbidden-in-production (Fixit rule carries over).
3. Never emit: `BOUNDSPEC … PAR`, TPAR, `BOUND SHAPE`, bare `DIFFRACTION` (process-rule
   standing prohibitions).

**WW3 side (WW3's OWN manual — committed at DOC-W.4 — + WW3 source; NEVER the SWAN manual):**
4. One-way nesting workflow: parent writes `nest.ww3` boundary spectra (up to 9 children);
   `ww3_bounc` builds boundary files from point spectra when the parent is external data
   (our case: reconstructed spectra from NOAA public output). Manual v5.16 §3.14, App. C.
5. Time-step hierarchy: four steps (global / spatial CFL / intra-spectral / source-term);
   the spatial CFL limit is PER FREQUENCY BIN (manual §3.2 p.102; source
   `w3pro3md.F90:923`) — decks are sized accordingly, global step per Named Constants.
6. Island representation: resolved dry cells at fine resolution AND/OR the obstruction-grid
   transmission mechanism for coarser WW3 grids — F2 tests both, ADR-109 fixes the choice
   per domain resolution. Obstruction inputs are versioned persisted files (PW1).
7. Grids are spherical (lat/lon) — the flat-projection strain that bound the big Cartesian
   L1 does not apply to the WW3 leg; SWAN legs stay Cartesian at their existing scales.

---

## PHASE F — WW3 feasibility build + benchmark — SCRATCH-ONLY, FIRST, no register row needed

**Owner:** lead-dispatched Sonnet agent (research/build class, not api-dev). **QC:**
adversarial auditor on the MEASUREMENT METHOD (results-free gate file) before numbers are
believed. **Nothing in this phase touches production paths, services, or repos beyond
read-only; all work under `/tmp/ww3-feas/` on librewxr (toolchain verified present
2026-08-15: gfortran 13.3.0, OpenMPI, NetCDF C+Fortran, cmake).**

### F1 — Build + smoke
Clone NOAA-EMC/WW3 (public, LGPL) to `/tmp/ww3-feas/`; build the standard regular-grid,
uncoupled configuration; run the smallest shipped regression/test case to prove the binary.
Deliverable: build log, switch file, binary hash, smoke-run evidence. Twice-failed build
step = STOP and report (no retry loops).

### F2 — Our-domain configuration
WW3 grid(s) for the current L1 domain footprint in spherical coordinates: bathymetry from
the same source data as L1 (ETOPO 2022 15s per ADR-108), islands as resolved dry cells at
~1 km; a SECOND coarser variant (~3–5 km + obstruction grid for the islands) to measure the
cost/accuracy trade the brief's precedent suggests (NOAA runs WW3 coarse + obstruction, not
fine). Boundary input: our reconstructed spectra for an ARCHIVED cycle (same cycle as the
ledger baselines), converted via `ww3_bounc`. Wind: the same cycle's wind store, regridded.
Time steps per SYNTAX PRESCRIPTIONS 5 + Named Constants.

### F3 — Benchmark marches
Run the archived cycle through both variants at production-like thread counts (respect the
running service: `nice`, thread cap, check for in-flight SWAN cycles first — Fixit protocol
carries over). Record wall-clock per march + peak memory.

### F4 — The three verdict measurements (the phase's point)
1. **Cost:** WW3 wall-clock vs the SWAN L1 baseline — which is the FULL-RUN march
   (~5280 s at 6 threads, A1.5 record; the ~50–70 min figure is the same march at the
   scratch experiments' 4 threads). Hourly cycles do not run L1 at all post-A1 (they are
   store-driven fills) — the comparison target is the full-run march, stated as such.
2. **Deep-corridor + island physics:** boundary→seam band ledger (Named Constants frame,
   same seam coordinates, same integration scripts, run from scratch copies — committing
   them into the repo as standing instruments happens at DOC-W.4, keeping Phase F pure
   scratch) vs the SWAN L1 numbers AND vs the buoys for the matched window. Explicit rows for:
   >11 s transmission, island-shadow refill in the lee, W-corridor 5–11 s survival.
3. **Handoff fidelity:** spectra at the L2 boundary line from WW3 vs from SWAN-L1 — the
   input L2 would actually receive (feeds the ADR-109 A-vs-B mechanism choice).
Deliverable: F-REPORT with the three measurement sets + build/deck artifacts; every number
traceable to a file.

### QC GATE F — adversarial, results-free
Auditor receives the METHOD (decks, scripts, comparability rule) without the numbers;
verifies the benchmark meets the Named-Constants comparability rule, the ledger scripts are
the same instruments as the SWAN baselines, and the seam sampling matches. Only then are
numbers opened and the report accepted. Gate FAIL = remeasure, not reinterpret.

---

## PHASE DOC-W — ADR-109 + governing docs to target state, BEFORE implementation code

**Owner:** `clearskies-docs-author` (Sonnet), content sourced ONLY from the research brief,
Phase F report, and this plan. **QC:** `clearskies-auditor` at Gate DOC-W. **No Phase W
dispatch until Gate DOC-W passes AND the operator has Accepted ADR-109.**

### DOC-W.1 — ADR-109 (Proposed → operator approval)
The WW3 deep-water leg decision: conditional trigger (or always, per Q1 ruling) with
threshold values; WW3 grid/resolution/obstruction choice per F; handoff mechanism A-vs-B
per F; deck time steps; refuse-gate values; file/dir layout for WW3 artifacts; scheduling
cadence. Drafted Proposed; operator reviews full content; Accepted before any W code.
ADR-108 gains a scope note (its L1 architecture remains the untriggered path — NOT
superseded).

### DOC-W.2 — ARCHITECTURE.md
Target-state passages: the two-path deep-water leg, trigger location, WW3 process/host
placement, handoff contract, health keys. Known-gaps section lists V-phase items.

### DOC-W.3 — PROVIDER-MANUAL + OPERATIONS-MANUAL + API-MANUAL touchpoints
PROVIDER-MANUAL: WW3-as-our-model section (inputs, boundary reconstruction reuse, cycle
flow). OPERATIONS-MANUAL: build/install story (from F1's proven steps), scheduling,
monitoring keys, refuse semantics, disk/retention for WW3 artifacts. API-MANUAL: any new
health/config surface (PW5). Help-content keys for wizard/admin surface changes (process
rule: same commit).

### DOC-W.4 — Reference docs committed
WW3 manual v5.16 text extraction → `docs/reference/ww3-user-manual-v5.16.txt` with a
provenance header (NOAA-hosted PDF, extraction date/method) + a short
`docs/reference/ww3-commands-extract.md` (frozen, syntax-lookup-only, same convention as
the SWAN extract). CLAUDE.md routing row gains the WW3 manual (SWAN row pattern: local
file authoritative, web-fetching WW3 docs forbidden once committed).

### QC GATE DOC-W — adversarial
Rows: ADR-109 internal consistency (every constant sourced to F evidence or named as
operator-set); ARCHITECTURE/manual passages match the ADR; no doc invents numbers Phase F
didn't measure; CLAUDE.md routing updated; plain-language standard met.

---

## PHASE W — WW3 deep-water leg implementation (triggered path)

**Owner:** `clearskies-api-dev` (Sonnet; marine repo). **Tests:** `clearskies-test-author`.
**QC:** `clearskies-auditor` per task round + lead gate. All code in
`repos/weewx-clearskies-marine/`. Task Files lists and Design-v1 blocks are authored by the
LEAD at dispatch (agents implement, never design) — the blocks below fix scope and
acceptance; exact function-level design lands per-round per the Fixit convention.

### W1 — WW3 runner service module
Build-artifact management (binary location, version pinning per OPERATIONS-MANUAL story),
process orchestration for grid-prep + march + post-processor steps, timeout, loud failure
(refusal semantics identical in spirit to SWAN cycle refusals — a failed WW3 leg NEVER
degrades to a silently-stale or fabricated boundary). Acceptance: KATs for
command-assembly; a failure-injection test proving refuse-not-degrade.

### W2 — Boundary reconstruction → WW3 input emitter (PW4)
The existing per-cell parametric spectra gain a WW3-consumable output path
(`ww3_bounc`-ready point spectra). Spectral construction constants untouched (Named
Constants). Acceptance: round-trip KAT — a known cell partition set → emitted file →
ww3_bounc ingest succeeds; bin-sum identity preserved.

### W3 — WW3→SWAN L2 handoff (PW3, mechanism per ADR-109)
Produce L2's boundary from WW3 output for triggered sites; L2 deck emission gains the
mechanism (BOUNDNEST3 line OR spectra-file BOUNDSPEC per ADR-109). Acceptance: handoff
round-trip KAT with a known spectrum (energy in = energy at L2 boundary within stated
tolerance); L2–L4 decks otherwise byte-identical to the untriggered path (KAT pins this).

### W4 — Trigger in grid-sizing (PW2) + depth-step detection (PW6, detection only this phase)
The mechanical trigger computed at config time with ADR-109 thresholds; decision logged
with its inputs (extent, islands, step-detection values). The depth-step DETECTION rule
lands here for both paths (logged), and placement preference applies to the triggered
path's WW3→L2 handoff only — the live untriggered seam does NOT move in this phase (PW6's
separate-deploy condition). Acceptance: trigger KATs (a simple-geometry fixture stays
SWAN-path; the HB-Pier geometry fixture triggers); step-detection KAT against the known
shelf-break profile; a no-silent-branch test (every decision logged); untriggered-path
deck diff EMPTY this round (consistency with Gate W's byte-identical row).

### W5 — Scheduling + health + config surface (PW5)
Cycle integration (full-run cadence for the WW3 leg, nest-age key + refuse gate at the
ADR-109 value), config keys, wizard/admin install-state surface via the API pass-through
(marine add-on invariant — everything through the API). Acceptance: health-key KATs;
age-gate frozen-clock KAT (the A1.4 pattern); wizard apply round-trip per the process
rule's Pydantic-contract check.

### W6 — Test consolidation round (test-author)
Cross-task suite: the full triggered-path chain on fixtures end-to-end; stale-test sweep
(anything pinning "L1 is the only deep-water model" updates IN the behavior commits, per
directive 5 — this round verifies none were missed).

### W-Accept (live, librewxr — deploy per PRIME DIRECTIVE 2/3/4)
Deployed with the trigger CONFIGURED OFF for production sites (dark launch): the code
ships, the WW3 leg runs for the triggered test site in SHADOW (producing artifacts,
serving nothing) alongside the live SWAN-L1 path. Reality gate rows: shadow-run liveness,
artifact sanity vs F-phase numbers, zero impact on the served path (baseline/diff).
**Serving cutover is NOT this phase** — that is V4, an operator ruling.

### QC GATE W — adversarial, per round + phase-close sweep
Standing rows: no physics constants changed anywhere; untriggered path byte-identical
(deck diffs empty); refuse-not-degrade proven; doc-code sync (manuals updated in the same
rounds); no forbidden syntax emitted.

---

## PHASE V — validation against reality + cutover ruling

**Owner:** lead + dispatched analysis agents; operator holds every ruling row. This phase
is the operator's "plenty of testing and tweaking" gate — nothing later starts until V4.

### V1 — Shadow-run campaign
≥ 10 consecutive cycles (including at least one long-period event ≥ 14 s if the window
provides one; if not, the campaign extends — event coverage is a named requirement, not
best-effort) with the WW3 leg in shadow at the triggered site. Per cycle: band ledger
boundary→L2-handoff for BOTH paths + matched-time buoy rows.

### V2 — The three deficit lines, measured
Against the research brief's budget: island-shadow refill, shelf-break/cliff KAT number
(the seam placement rule's effect measured HERE — PW6 authorized detection, V2 decides if
it helped), deep-corridor transmission. Each line: SWAN-L1 vs WW3-leg vs buoy truth.

### V3 — Served-quality comparison + carry-over eyeballs
Side-by-side served-payload simulation from the shadow leg vs live payloads vs
buoys/LOTUS/Surfline for matched times (the C7 apples-to-apples, systematized). The
C1–C4 eyeball re-accepts are UNBLOCKED already (carry-over register) and may close any
time the operator chooses; V3 is their consolidated round AT THE LATEST (cards + cam +
knob drill in one sitting).

### V4 — CUTOVER RULING (operator)
Evidence pack: V1–V3 tables + cost/wall-clock + failure-mode inventory from shadow
campaign. Operator rules: cutover triggered sites to the WW3 leg / extend campaign /
adjust (each adjustment cycles through DOC-W amendment if architectural). No cutover
without this ruling. Q1's conditional-vs-always answer is re-confirmable here with data.

### V5 — Post-cutover watch + decommission ruling (operator)
≥ 7 days watched (monitors + daily ledger row). Then the operator rules on the big-L1
path's disposition FOR TRIGGERED SITES (keep as fallback / retire). Retirement, if ruled,
is its own round with ADR-108 supersession notes — not implied by cutover.

---

## PHASE R — strengthening fixes from the research brief (independent tracks)

### R1 — Handoff placement off the shelf break (PW6) — REQUIRES Phase W machinery
Covered inside W4 (implementation) + V2 (measurement). Listed here so the brief's
R1-question lineage is traceable: the research verdict was "seam relocation unproven as a
fix" — this plan implements DETECTION + placement preference and lets V2's cliff-KAT
number deliver the verdict empirically. Whatever V2 shows is recorded in the brief's §9
as the answer.

### R2 — Fed E-side boundary (PW7)
R2.1 (read-only, any time after GO): re-derive the unfed-E census at the corrected time
index; deliver the real bound with the corrected arithmetic shown. R2.2 (only if R2.1
shows material loss AND operator confirms): E-side feeding via the existing mechanism;
ledger before/after; KATs. R2.1's number decides — no fix on a stale bound.

### R3 — Problem-2: served multiSwell selection (PW8 — verdict first, fix by ruling)
R3.1: T2 payload-stability audit (free, read-only) per P2-CONFIRMATION-PROTOCOL.md.
R3.2: T1/T3 capture per Q2's answered mechanism; 24–72 h window; pre-declared verdict
criteria from the protocol file bind. R3.3: verdict + fix proposal → operator; any
implementation is a NEW register row ruled at that time.

### R4 — Evidence-gated numerics experiments (scratch-only, opportunistic)
The refraction-rate limiter (CTHETA/CSIGMA) A/B on the NEW architecture's SWAN legs —
scratch decks only, ledger-measured, operator-informed. Production adoption would be a
formula-adjacent numerics change = operator ruling with the experiment as evidence. Low
priority; runs only when idle capacity exists.

---

## PHASE L — hybrid LUT system — LAST, gated on V4 acceptance + operator's defensibility ruling

**Opens ONLY after:** V4 cutover ruled AND the operator states the modeling system's
results are "accurate and defensible" (their words — this is an explicit ruling row, not
an inference). PW9: nothing here is pre-approved.

### L0 — Design round + ADR-110 (Proposed → operator)
Scope fixed by the operator's prior direction (2026-08-14 conversation, recorded in the
research brief's companion records): hybrid LUT — precomputed swell transfer (bin-separable
transfer matrices, CDIP/O'Reilly-Guza precedent per brief §4 Option D), live wind/tide/
currents; coverage: WW3 leg + SWAN nests + 1D models; partial rebuilds (e.g. expanding
swell-period coverage ahead of a storm); lifecycle invalidation hooked to the existing
geometry-change detection; operator rebuild notifications + education surface (wizard/
admin). The design round produces ADR-110 with the LUT build/rebuild cost model measured
from the by-then-live system, not estimated.

### L1+ — Implementation/validation tasks
Enumerated by ADR-110 once Accepted; they enter THIS plan as an amendment (the A1
convention: amendment block + register rows + gates) so the plan remains the single
architectural permission record.

---

## Round-close & bookkeeping (every phase)

- Gate record in THIS file (CURRENT STATE + per-phase ✅ markers with commits, accept
  numbers, deviations) — Fixit-plan convention carries over, including the INDEX rule
  (every new `##` section gets an INDEX entry the same commit).
- rules/verification.md round-close gate applies (independent lead verification of every
  agent claim; false-claim protocol on mismatch; known-answer tests for numerical kernels).
- Adversarial gates use results-free gate-definition files (2026-08-14 contamination
  lesson) — standing for every gate in this plan.
- Doc-sync in the same round as the code it describes; doc-truth sweeps at phase close.
- Lessons at close: triage into rules/ files per CLAUDE.md, surfaced to operator first.
- Pytest baselines recorded fresh at each phase dispatch; targeted suites only (never the
  full suite — rules/agents.md).
- Fable adversarial plan review (operator-ordered 2026-08-15): dispatched; the reviewer was
  STOPPED by the operator mid-run before writing its report file. Its progress note named
  five findings; the lead verified each against the draft and sources and applied all five
  (Gate-W/PW6 contradiction; Phase-F scratch-purity vs repo-copy; eyeball-freeze
  misstatement; missing Phase-T carry-over; full-run/hourly runtime mislabel). The review's
  remaining ~7 unpreviewed findings were LOST with the stop — a full replacement review
  runs only on operator request. This record deliberately does not claim a completed
  adversarial pass.

---

## OPEN OPERATOR QUESTIONS

*(Plain English, self-contained, newest at top. Answered items get their ruling recorded
here and applied.)*

### Q1 — Conditional WW3 or always-WW3? (the operator's own 2026-08-15 question)
Does our WW3 leg take over deep water ONLY when the computed domain trips the mechanical
trigger (large extent / islands inside / severe depth steps) — the lead's recommendation —
or for ALL marine sites regardless? Lead's case for conditional: the evidence localizes
SWAN's struggle to the forced-large-domain case; WW3 at 1 km is cost-parity, not savings;
simple sites keep the lighter proven stack; the trigger is one logged config-time decision
and both paths share the entire nearshore chain. Case for always: one path to test and
operate; every site gets spherical coordinates + obstruction machinery; no threshold to
tune. Structural impact of "always": W4's trigger becomes a constant; nothing else moves.
**Plan proceeds on CONDITIONAL unless ruled otherwise; the ruling can also be revisited at
V4 with shadow-campaign data in hand.**

### Q2 — Problem-2 capture mechanism (carried from the protocol file)
T1/T3 need per-hour handoff partition lists. Options: (a) scratch hourly collector on
librewxr reading existing artifacts (no code change), (b) temporary DEBUG logging level on
the `_aggregate_partition_breaks` logger for a 24–72 h window (one operational knob, no
code change). Which may we use?

### Q3 — Two pending rule-lessons (carried)
(a) results-free gate-definition files → rules/agents.md; (b) post-remediation reruns
must cover affected+adjacent suites → rules/verification.md. Write them?
