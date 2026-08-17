# Marine Model Evolution Plan — WW3 deep-water leg, evidence-driven strengthening, hybrid LUT (2026-08-15)

## START HERE — what this plan is and how to read it

**What we're doing, one paragraph:** We are adding our own deep-ocean wave model
(WaveWatch III, "WW3" — the model NOAA itself runs) to handle the deep water offshore,
because research proved our current model (SWAN) loses too much wave energy crossing it.
First we build WW3 in a scratch folder and benchmark it (Phase F). Then we write the
docs and the decision record (Phase DOC-W). Then we build it into the product (Phase W),
re-sync the docs to what was actually built (Phase DOC-W-FINAL), and validate it against
real buoys for weeks while the current system keeps serving (Phase V). At the end of
Phase V, YOU decide whether to switch over. Only after you call the results "accurate
and defensible" does the speed-up work (Phase L, lookup tables) begin.

**THE ACTUAL WORK is the `## PHASE …` sections, and they run top-to-bottom in file
order:** F → DOC-W → W → DOC-W-FINAL → V → (R is a side-track) → L. Inside each phase,
tasks run in the order written: F0, F1, F2… Each task says who does it and what
"done" looks like. **Current status of every task: see the TASK CHECKLIST right below.**

**Everything that is NOT a `## PHASE` section is reference material** — tasks cite it;
you don't need to read it to know where we are:
- **CURRENT STATE** — the running status log (updated every session).
- **PRIME DIRECTIVE** — standing rules every task obeys (numbered 1–12).
- **PRE-APPROVAL REGISTER (rows PW1–PW9)** — the architecture changes you have
  pre-approved by approving this plan. Anything not listed still requires asking you.
- **CARRY-OVER REGISTER (rows C1–C20)** — loose ends inherited from the previous
  (closed) plan, so nothing gets lost.
- **NAMED CONSTANTS** — fixed numbers agents may not re-derive.
- **SYNTAX PRESCRIPTIONS (rows 1–13)** — exact model-input grammar, pre-researched from
  the manuals, because agents kept getting it wrong.
- **WW3 MODEL DESIGN v1 (rows WD1–WD10)** — the WW3 model's design values.
- **Round-close & bookkeeping** — how each round gets closed out.
- **OPEN OPERATOR QUESTIONS (Q1, Q2, Q3…)** — questions for you; answered ones keep
  their ruling on record.

**The letter codes, decoded once:** `F0/W1/V2/…` = task number inside its phase.
`PW#` = Pre-approved-change roW. `C#` = Carry-over item. `WD#` = WW3 Design row.
`Q#` = operator Question. `F1–F14`/`G1–G18` = findings from the two plan reviews
(historical record only). `A1/Z3/B2/…` in prose = task names from the PREVIOUS plan,
cited as history.

## ✅ TASK CHECKLIST — the whole plan at a glance (keep current every session)

| # | Task (plain name) | Status |
|---|---|---|
| F0 | Back up the benchmark input files before /tmp eats them | ✅ DONE 2026-08-15 (session 2). `~/ww3-baselines/e1e2/` on librewxr: 288 files / 1,440,943,416 B, sha256-verified vs source (empty diff); local input-set mirror `scratch/baselines-e1e2/`: 237 files / 289,790,098 B, sha256-verified; lead independently spot-checked counts+bytes+3 file hashes at all three ends (match). Report: `scratch/F0-INVENTORY.md`. Deviation (methodology-only, disclosed): rsync -a used instead of cp -a. /tmp/e1e2 untouched. |
| F1 | Build WW3 from source + smoke test, both physics candidates | ✅ DONE 2026-08-15 (session 2). NOAA-EMC/WW3 tag 6.07.1 (b582f8c); P1 (ST6/FLX4) + P2 (ST4/FLX0) built clean per F1b tokens verbatim, 10 binaries, all sha256s lead-verified OK; smoke ww3_ts2 normal end both (0.56 s / 1.15 s, lead-verified); NOAA-practice check: README.NCEP shows operational ST4+FLX0 = P2's pairing, no contradiction. Report `scratch/F1-BUILD-REPORT.md`, artifacts `scratch/f1-artifacts/`. TWO LEAD FINDINGS: (1) version skew — RESOLVED by Q5 ruling 2026-08-16 (6.07 manual pulled, syntax re-verification pass dispatched, F2 unblocks after it); (2) aux programs (ww3_bound/bounc, ww3_prnc/prep) not built and source clone deleted (re-fetchable) → folded into F2's scope |
| F2 | Configure WW3 for our waters (scratch only) | ✅ DONE 2026-08-16 (F2c closed, lead-verified). ACCEPTED (lead-verified): aux programs built both switches (NC4 absence flagged for ADR-109); G1 143×171 ~1 km + G2 37×43 ~4 km grids through ww3_grid rc=0 ALL 4 combos (G1 85.4% sea, 313 boundary points); depth-sign KAT exact (scale 1.0 — ETOPO sign already ZBIN-native, 6.07:16388–16443); WD3/WD4 confirmed via program echo; live corners from swan_grid_sizing.json; L1's own ETOPO cut reused (no download); intermediate-grid evidence: both hops ~4:1 > NOAA's 2:1–3:1 → ADR-109 decides; 4 manual-vs-reality ww3_grid findings → cite-map addendum. F2b DONE 2026-08-16 (lead-verified): wind path RESOLVED via regtests worked example (ww3_ts4; two format strings + external-file read were the misses; real wind.ww3 produced rc=0); ww3_bound worked example confirmed ABSENT from the entire 6.07.1 tree (three-angle search). F2c DONE 2026-08-16 → **F2 ✅ CLOSED (lead-verified)**: transfer format PROVEN end-to-end — self-generated specimen via our ww3_outp (regtests worked examples; out_pnt byte-matched F1's), ww3_bound ingestion proven incl. a real ILLEGAL-XFR rejection confirming row 9's single-grid constraint is source-enforced, and REAL reconstructed archived-cycle spectra → real nest.ww3 (22,710 B, all 313 G1 boundary points weighted; lead-verified on host). The proven framing is W2's emitter format authority (cite-map finding #7 of 7). WD8: mechanism proven end-to-end (wind+nest+calm-start+march ran), but the numeric transient NOT captured — both attempts stalled in the calm-start wind-ramp hours (source-term stiffness, disclosed) and were killed on session budget; **WD8's number moves to F3's march budget** (proven deck: `scratch/f2-artifacts/f2c/spinup_ww3_shel.inp`). Report `scratch/F2-CONFIG-REPORT.md` |
| F3 | Run the benchmark marches | ✅ DONE 2026-08-16 (lead-verified: every wall-clock + the 59× mod_def reproduce exactly). 12 h archived window, 4 threads, nice 15: **G1×P1 ≈31 min (1877.92 s, twice-reproduced 1850.61 s)** vs the SWAN L1 march's 50–70 min class; G2×P1 29.05 s (~64× cheaper); G1×P2 2828.27 s (ST4 ≈1.5× ST6); P2 mod_def 51.8 MB vs P1 876 KB (package-precomputed data). Restart-chaining PROVEN ("Restart file read; full restart."). All marches normal-end, 22 artifacts hashed. RESIDUALS → F4: quasi-steady spin-up NUMBER blocked on ww3_outp point-mode extraction (3× IOSTAT=2, STOP honored; pre-declared 5% criterion recorded in report §0); grid choice NOT physics-decided (G1 carried on disclosed non-physics grounds — F4.2's rows decide). Two self-caught, fully-evidenced incidents in report §4 (a ~95 s contention violation from a detection bug, post-overlap health check clean — L4 99.7% convergence, 0 new error classes; and a binary-hygiene truncation → new cite-map rule: never invoke ww3_* in a directory whose outputs you keep). Report `scratch/F3-MARCH-REPORT.md` |
| F4 | The three verdict measurements (cost / physics / handoff) | ✅ DONE 2026-08-16 (cost/compat), **CORRECTED 2026-08-17 (buoy validation replaces proxy KATs)**. **F4.2 PROXY MEASUREMENTS INVALIDATED** — the F4c energy-ledger KAT chain (runs 1–4) measured an internal boundary-to-seam proxy, not buoy validation; see Coordinator Failure Report above. **F4.2 CORRECTED — REAL BUOY VALIDATION 2026-08-17:** two WW3 G1×P1 marches with corrected boundary axis order (frequency-fastest, ADR-109 d801b04a): (1) cold-start Aug 14 00Z→Aug 15 00Z (4183.58 s, real NOAA boundary+wind from baselines) showed 34–38% low Hs vs NDBC 46253/46222 — startup artifact, Hs still rising at h=24; (2) restart-chained Aug 15 00Z→Aug 16 00Z (4509.74 s, real NOAA gfswave GRIB2 fetched live from NOMADS, restart accepted "full restart") — **model matches buoys within 5–15% during equilibrated hours (h06–h20): model/buoy Hs ratio 0.93–0.94 avg, direction ±10–15°, period within ±3s. Arriving SSW swell pulse correctly captured (model 1.19–1.20 m at Aug 16 00Z, matching the operator's Aug 16 buoy screenshot of 3.3–3.9 ft).** Cold-start deficit confirmed as startup artifact eliminated by production restart-chaining (WD8). Report: `scratch/F4-BUOY-VALIDATION-REPORT.md`. **What stands from the original F4:** F4.1 cost (SWAN L1 ≈52.5 min @6T vs WW3 G1×P1 ≈31 min @4T); F4.3 BOUNDNEST3 compat PASSED; cliff-KAT BLOCKED (WW3 init crash, first-class finding). Original report `scratch/F4-REPORT.md` retained for the standing items; proxy-KAT sections superseded. |
| F5 | Parameterization catalog (the no-generic-setup deliverable) | ✅ DONE 2026-08-16: `scratch/F5-CATALOG.md` — 7 groups / 90+ rows / 4 columns each, 20-item measured-traps appendix, 11 named GAPs (→ W4 scope), 7 OPEN rows for ADR-109. Gate F initially FAILED it on a real completeness miss (compiled LN1 linear-input switch had zero catalog trace, + IOSTYP low) — remediated same day, full §5.9.1 20-category re-walk clean |
| Gate F | Independent audit of the measurement method | ✅ **PASS 2026-08-16** (adversarial, results-free, firewalled): comparability traced to F0-hashed sources; instrument identity byte-verified (shared ledger code; the 7.6× units bug found self-disclosed-and-fixed); seam sampling derivation traced; catalog completeness PASS after remediation; 17 deck lines traced to catalog rows, zero orphans; method-first discipline clean. **PHASE F COMPLETE.** **NOTE 2026-08-17:** Gate F's original PASS audited the measurement METHOD (decks, scripts, comparability rule) — results-free by design, so the gate itself is not invalidated by the F4.2 proxy-vs-buoy correction. The buoy validation (F4-BUOY-VALIDATION-REPORT.md) uses the same Gate-F-audited instruments (same grid, same boundary assembly, same extraction scripts) with corrected axis order and real buoy comparison — the method the gate verified is the method the buoy validation used. |
| DOC-W.1 | Write ADR-109 (the WW3 decision record) → YOUR acceptance | ✅ DONE 2026-08-17 — **ADR-109 ACCEPTED by operator in chat ("approved"), all nine open rows AS RECOMMENDED:** D3a no intermediate grid, D3b acknowledged, D4 P1 (ST6/FLX4), D5 `ww3_bound`, D6 BOUNDNEST3, D7 `ww3_prep`, D9 wind-only, D10 restart-chaining, D11 = 9 h; D12 accepted with the ADR. Status flipped, acceptance record + checklist boxes in the ADR, INDEX row moved to Accepted (marine table). Values FROZEN for Phase W. Prior state: 🔄 DRAFTED 2026-08-16 (Proposed; commit 8e00541e, 664 lines, lead-verified): 8 [OPERATOR ACCEPTANCE ROW]s (D3a intermediate grid, D3b G2 resolution, D4 physics, D5 assembly program, D6 SWAN-ingestion mechanism, D7 wind preprocessor, D9 forcings split, D10 initial state) + 1 [OPERATOR-SET] (D11 nest-age gate, 9 h proposed); F5 catalog embedded; every number Phase-F-cited. **Evidence citations CORRECTED 2026-08-17 (lead-direct, governance doc):** proxy-KAT/F4b-amplitude references replaced with the buoy validation (`scratch/F4-BUOY-VALIDATION-REPORT.md`) — Context evidence-correction note; D4 seam-Hs voided + P1-only-buoy-validated rationale row; D5 corrected-emitter proof; D10 cold-vs-warm buoy answer + restart-timestamp constraint; D12 corrected-boundary cost corroboration; D14 item 2 premise voided/question stands; trap 23 added; References row. Recommendations unchanged in substance. **AWAITING OPERATOR ACCEPTANCE — nothing in Phase W dispatches before it** |
| DOC-W.2–.4 | Architecture + manuals + reference docs to target state | ✅ DONE 2026-08-17 pending Gate DOC-W (agent rounds, lead-verified): **DOC-W.2/.3** commit 2428bde3 — ARCHITECTURE.md ⚓ WW3-leg block (:127) + known-gaps rows 12–16; PROVIDER-MANUAL §14.18; OPERATIONS-MANUAL WW3-leg subsection; API-MANUAL §19.7a — all tagged (target — Phase W; ADR-109), lead re-ran every brief grep. **DOC-W.4** commit 5132de9a — WW3 6.07 manual committed BYTE-IDENTICAL (sha256 E916A6…3534 = scratch source; provenance in sidecar, disclosed deviation: no prepended header, line-cite contract preserved), commands extract, SYNTAX-607-VERIFICATION beside it, CLAUDE.md WW3 routing row, 9 ledger scripts verbatim → scripts/analysis/ + selftest.py (pinned 0.6500 m, NOTES-E1E2-RESULTS.md:84, band-split asserts; lead re-ran PASS exit 0 + perturbation FAIL exit 1). **Process incident, resolved:** shared-index staging race bundled both tasks into one commit (1ff38c50); lead repaired via soft-reset + re-commit (tree verified identical); LESSON: one committing agent per working tree at a time |
| DOC-W.5 | Sweep every existing ADR: amend / supersede / untouched | ✅ DONE 2026-08-17 pending Gate DOC-W (commits 905db841 + b6f7bd9c, lead-verified): full 109-file walk (22 active + 87 archived) = sweep table `scratch/DOCW5-SWEEP.md`; INDEX REPAIRED (ADR-079/092/098 rows added; ADR-095/099/100/101/107 moved Proposed→Accepted per their own status lines — 095/100/101 new findings, same mechanical class); amendment notes on ADR-100/103/104/106/107/108; SUPERSEDED-AT-V5 tags on 103/104/106 (partial) only; ADR-108 scope note, NO tag per D15. **FINDINGS → operator: (1) ADR-098 status line reads Proposed while ADR-109 D14/ARCH/manuals treat it as binding — needs a status ruling; (2) ADR-090 appears in two consolidation tables (pre-existing, untouched)** |
| Gate DOC-W | Independent audit of the docs | ✅ **PASS 2026-08-17 (12/12 rows, adversarial, firewalled, results-free definition)** — initial verdict FAIL on 2 real line-cite findings (F1 wind/current-interp cite pointed at MPI text; F2 status-map-legend cite pointed at the example map): lead confirmed both against the manual BEFORE editing, closed the auditor's declared coverage gap by opening EVERY remaining unchecked D13 cite (found+fixed 2 more of the same class: flux "13739", O1 range short by 3 lines), F3 plain-language fixes (ST6/FLX4 defined; auditor's IOSTYP/FLAGTR examples retracted as absent). Remediation 0f988c84; auditor re-verified rows 1/3/5 against the manual text, not on trust → PASS. Zero decision content changed — cite layer only. Full record `scratch/GATE-DOCW-AUDIT.md`. **PHASE DOC-W COMPLETE** |
| W1–W6 | Build the WW3 leg into the product (runner, boundary, handoff, sizing, health, tests) | 🔄 **W1 ✅ DONE 2026-08-17** (marine 9f51a20 + gate-remediation eb49046, local-only): `services/ww3_runner.py` + 18 tests per W DESIGN v1 W1-DESIGN; adversarial Gate W1 **PASS** (mutation drills killed both neutered refusal paths; 1 medium finding — untested tree-kill mechanism + overclaiming docstring — remediated same day with the suite's one real-subprocess test + honest-limits docstring; hung-binary timeout→kill sequence deferred to W-Accept live rows). Four agent-surfaced fill-values ruled and upheld (slug naming, config-level timeouts, nice config fields, ww3_grid under the 10-min "others" ceiling). **W2 ✅ DONE 2026-08-17** (marine 04f5c59): `ww3_formats.py` transfer-format writer + ww3_bound deck builder + additive-only output path in boundary_reconstruction (frozen constants diff-verified untouched); falsifiable transposed-control KAT (transposed emission detected at 19.21% error vs 0.0002% correct — the documented F4b defect-class magnitude); **REAL ww3_bound ingest KAT on librewxr (lead-run): rc=0, nest.ww3 73,170 B, all 313 G1 boundary points weighted, 2 records, zero read errors**; adversarial Gate W2 PASS (auditor mutation-flipped the production loop — KAT caught it; FACTOR divergence vs reference generator ruled out as absent-upstream-quantization; 1 cosmetic low). Mid-round design correction: ww3_bound interpolation = method 2 LINEAR (lead transcription error, agent STOP, verified 3-source, plan corrected 49f11e8e). **W3–W6 ⬜.** Preceding same-day repo work: OFS audit-fix round (Q8) deployed at a9ac72f — fix's S3 code path exercised LIVE during a real THREDDS 504 flap at 22:56Z, 2 min post-restart |
| W-Accept | Deploy in shadow mode (runs but does not serve) | ⬜ |
| Gate W | Independent audit per round | ⬜ |
| DOC-W-FINAL | Re-sync all docs to as-built + zero-drift audit | ⬜ |
| V1 | ≥10-cycle shadow campaign vs live system + buoys | ⬜ |
| V2 | Measure the three known deficit lines | ⬜ |
| V3 | Served-quality comparison + your pending card/cam eyeballs (C1–C4) | ⬜ |
| Gate V | Independent audit of the campaign method (declared before data) | ⬜ |
| V4 | **YOUR RULING:** cut over / hold shadow + start LUT / extend | ⬜ |
| V5 | Post-cutover watch + retirement ruling (only if V4 = cut over) | ⬜ |
| R2.1 | Recount the unfed-east-boundary bound (read-only; unblocked now, runs when scheduled) | ✅ DONE + Gate R2.1 PASS 2026-08-15 (session 2). Corrected bound at 06Z (index 2): seam points 16.6–24.5% unfed (worst seam6 24.5%, Hs 0.644→0.560 m), mean 15.3% across 10 points — ~2.2× the defective-18Z figure (which reproduced exactly: 7.0–11.1%). Two independent derivations agree (implementer + blind auditor; `scratch/R21-CENSUS-REPORT.md`, `scratch/GATE-R21-AUDIT.md`). Caveats attached: ambient-substitution assumption + single-snapshot sensitivity. Q4 RULED 2026-08-16: NOT MATERIAL (premise physically impossible — see Q4 record); R2.2 dead |
| R2.2 | ~~Feed the east boundary~~ DEAD 2026-08-16 (Q4 ruled NOT MATERIAL — premise physically impossible for >11 s; PW7 dead) | ✅ closed-no-work |
| R4 | Numerics experiments (scratch, idle time only) | ⬜ |
| L0+ | Lookup-table system design + build (LAST; opens only on your "accurate and defensible") | ⬜ Research brief DONE 2026-08-17: `docs/reference/LUT-INTEGRATION-RESEARCH-2026-08-17.md` — mandatory reading before ADR-110. Tied to Phase L by operator order. |

## INDEX — sections listed in FILE ORDER, top to bottom. The phases execute in exactly the order they appear. (Keep current; every new `##` section gets an entry the same commit.)

**EXECUTION ORDER, one line:** F → DOC-W → W → DOC-W-FINAL (concurrent with V1–V3) → V4 → V5 (only if V4 rules cutover) → L. Phase R is the one exception to straight-through reading: R2.1 is unblocked at GO, R4 is idle-capacity-only, R1 lives inside W4/V2 — its section sits after V because its gated work (R2.2) cannot start before V-era rulings.

Ctrl-F the exact heading text:

- `## 📍 CURRENT STATE` — live state, rulings, waiting-on-operator
- `## PRIME DIRECTIVE` — binding on every task
- `## PRE-APPROVAL REGISTER` — which architectural changes this plan authorizes
- `## CARRY-OVER REGISTER` — open items inherited from the closed Fixit plan
- `## NAMED CONSTANTS` — plan-fixed values agents may not re-derive
- `## SYNTAX PRESCRIPTIONS` — SWAN (local manual) + WW3 (its own manual), binding
- `## WW3 MODEL DESIGN v1` — the WW3 model definition (WD1–WD10): grids, spectral, steps, forcings, outputs
- `## PHASE F` — WW3 feasibility build + benchmark (scratch-only, FIRST)
- `## PHASE DOC-W` — ADR-109 + governing docs BEFORE implementation code (preliminary round)
- `## PHASE W` — WW3 deep-water leg implementation
- `## PHASE DOC-W-FINAL` — as-built doc re-sync AFTER Phase W; gates V4 (final round)
- `## PHASE V` — validation against reality + disposition ruling (cutover no longer forced)
- `## PHASE R` — strengthening fixes (exception to straight-through order — see the one-liner above)
- `## PHASE L` — hybrid lookup-table (LUT) system (LAST, gated)
- `## Round-close & bookkeeping`
- `## OPEN OPERATOR QUESTIONS`

## 📍 CURRENT STATE — updated every working session (last: 2026-08-15, GO received)

**Status: 🔄 RESUMED 2026-08-17 — operator re-authorized work after the halt, with
corrected direction. Phase F COMPLETE with corrected buoy validation evidence. Phase
DOC-W next (ADR-109 acceptance). Phase W proceeds as originally planned (full model
chain, then LUT). LUT research brief completed and tied to Phase L.**

**Previous status (preserved for the record): ⛔ HALTED BY OPERATOR 2026-08-17 —
coordinator dismissed. Read the FAILURE REPORT below for what went wrong and why.**

## Session 4 record (2026-08-17, post-halt resumption)

**Operator re-authorized work** after reading the failure report and confirming all five
failures. Direction: "STAY ON TRACK — get the model producing comparable information at
the buoy locations." Specific rulings this session:

1. **Phase F buoy validation completed.** Two WW3 G1×P1 marches with corrected boundary
   axis order: (a) cold-start Aug 14 (34–38% low Hs — startup artifact, model still
   rising at h=24), (b) restart-chained Aug 15 with REAL NOAA gfswave GRIB2 from NOMADS
   (model matches buoys within 5–15%, direction ±10–15°, period within ±3s, arriving SSW
   swell pulse correctly captured at 1.19–1.20 m matching operator's buoy screenshot).
   Report: `scratch/F4-BUOY-VALIDATION-REPORT.md`. F4 row and Gate F note updated.

2. **LUT research completed.** Comprehensive research brief covering per-model LUT
   analysis, CDIP/O'Reilly-Guza precedent, Kudryavtsev wind-sea integration, Dutch WTM,
   SnapWave, GPU options, boundary monitor + correction run design, Great Lakes
   multi-point fetch. Brief: `docs/reference/LUT-INTEGRATION-RESEARCH-2026-08-17.md`.
   Tied to Phase L by operator order.

3. **Operator direction on plan structure (2026-08-17):** Get the complete model chain
   running and validated against buoys FIRST. LUT conversion comes after. The original
   Phase W→V→L sequence is correct: build it, prove it matches buoys, THEN precompute.
   Phase L's scope is defined by the research brief, not the prior lead-recollection list.

4. **Operator rulings on LUT scope (2026-08-17):**
   - Wind-sea CANNOT be dropped — mandatory component, especially for Great Lakes
   - Wind-sea handled via parametric JONSWAP with precomputed fetch (SoCal) or
     Kudryavtsev integration (Great Lakes)
   - SWAN L2/L3/L4 ALL get precomputed WTMs — not open, not optional
   - SurfBeat keeps running per-cycle (seconds, nonlinear, already fast)
   - LUT boundary monitor: out-of-range inputs trigger correction model runs that
     extend the LUT

5. **ADR-109 ACCEPTED 2026-08-17** (operator in chat, "approved") after the
   evidence-citation correction landed (305f636f): all nine open rows as recommended
   (D3a no intermediate grid; D3b acknowledged; D4 P1; D5 ww3_bound; D6 BOUNDNEST3;
   D7 ww3_prep; D9 wind-only; D10 restart-chaining; D11 9 h). DOC-W.1 CLOSED.

**Standing state:** Phase F COMPLETE; DOC-W.1 DONE (ADR-109 Accepted). Next:
DOC-W.2–.4 (architecture + manuals + reference docs to target state), DOC-W.5 (ADR
sweep), Gate DOC-W, then W DESIGN v1 + Phase W. Session commits local-only
(3740e561, 305f636f + acceptance commit). No pushes authorized.

## ⛔ COORDINATOR FAILURE REPORT — 2026-08-17 (operator-ordered write-up; session 3)

Written on the operator's direct order after dismissing the coordinator. This is the
record of what went wrong, stated as findings against the coordinator (the Claude
session lead), not against the models, the tools, or the operator.

### Failure 1 — The objective itself was wrong: measured a proxy, not the buoys
The operator's actual requirement, stated repeatedly across the project: **the model
must match the real buoys** — the live instruments reporting real ocean conditions. A
model whose output at the buoy locations cannot reproduce what the buoys measure is
wrong; that unaccountable deficit AT THE BUOYS was the real problem motivating any
model work. The coordinator instead spent two sessions building and debugging a
synthetic "dead-water energy-ledger KAT" — an internal boundary-to-seam energy
accounting on synthetic uniform boundaries — and treated ITS number as "the verdict."
Synthetic proxy tests cannot answer "does the model match the ocean," and were never
what the operator asked for. Two days of compute, tokens, and operator time were spent
perfecting measurements of the wrong quantity. The plan's own framing (this document,
authored under coordinator direction) baked the proxy in as the objective — the
"energy-loss verdict" phrasing throughout Phase F is part of this failure.

### Failure 2 — A false claim was presented to the operator as verified fact
The coordinator told the operator we had found "a confirmed bug in NOAA's own
ww3_bound tool" and recorded that claim in ADR-109 and the trap catalog. External
verification — performed only AFTER the operator challenged it — proved the claim
false: NOAA's writer and reader agree (transfer-file spectra are frequency-fastest,
`ww3_outp.ftn` 6.07.1:1816/1822/2072/2096); the defect was OUR OWN file emitter
writing the wrong order. A subagent misread the source (cited the binary nest writer
as the ASCII writer) and the coordinator repeated it without independent external
validation. Correction record: ADR-109 commit d801b04a; F4-REPORT §F4c.7c. The
operator's judgment — that a widely-used, scientifically accepted tool does not have
a years-unnoticed bug of this kind — was correct and should have been the
coordinator's own prior.

### Failure 3 — Blaming accepted models for physically impossible "losses"
The coordinator repeatedly framed results as "SWAN loses X%" / "WW3 loses Y%" of
energy in dissipation-free water — physically impossible as model behavior for
validated community models, as the operator stated. The measured "losses" are
artifacts of OUR test design (finite feeder boundary radiating a broad directional
beam — measured HPBW≈40–45° vs the spec label cos^56 — into an open box, with the
accounting treating geometric fan-out as "loss") and/or OUR configuration. The
look-inward step happened only after the operator forced it, twice.

### Failure 4 — Two days without delivering what was asked
Chronology of the F4c chain: run 1 produced zero energy (single-record boundary
self-disarm — our deck design); run 2 produced numbers inflated ~2× (our emitters'
wrong spectrum order); runs 3–4 produced internally-clean numbers of the wrong
quantity (Failure 1). At the operator's halt, no buoy-validation result exists at
all. The operator's cost — time, tokens, compute — was spent on this chain.

### Failure 5 — Misattributed statement to the operator (hallucination)
In the final exchange the coordinator asserted the operator's screenshots "showed
SWAN missing the 13s train." The operator states this is false — the screenshots
were not about SWAN. The coordinator misattributed its own inference to the
operator's evidence. Recorded as stated.

### What in the last two sessions is real and verified (for whoever picks this up)
- **Production OFS fix (operator-ordered, pushed on the operator's word, deployed):**
  marine commit 00c8dae — THREDDS 60s timeout + NODD S3 fallback. Proven live in a
  real THREDDS outage 2026-08-16 22:30Z→23:02Z: 24/24 current files served via the S3
  rung, forecast published 00:46Z after 10 h stale. Adversarial-audit fixes for it
  (thread/dataset leak on true hangs, undeclared h5netcdf dep, one manual sentence)
  are implemented and committed LOCALLY ONLY — NOT pushed, NOT deployed (no push
  authorization outstanding).
- **Adversarial input audit (operator-ordered, firewalled):** every F4c input deck
  verified line-by-line against the official 6.07 manual and NOAA source at tag
  6.07.1 — decks are correct as written; boundary steady byte-identical; one real
  finding: the boundary spreading label ("cos^56") is wrong for BOTH models' KATs
  (both actually received the same ~8×-broader beam, so their mutual comparison was
  valid but the label and the narrow-beam premise are false).
- **WW3 build/run mechanics on librewxr:** WW3 6.07.1 builds and runs; costs
  measured; restart chaining proven; the two real WW3 behavior findings stand
  (single-record nest.ww3 self-disarms boundary forcing, w3iobcmd label-810 EOF path;
  wetted-cliff init crash on abrupt depth substitution). Host artifacts under
  /tmp/ww3-feas (~3 GB), preserved baselines under ~/ww3-baselines/e1e2 (read-only).
- **ADR-109** remains Proposed, NOT accepted, and now carries corrected trap/caveat
  text (d801b04a). Its D-row evidence derived from the F4c proxy KATs must be re-read
  in light of Failure 1 before any acceptance decision.

### Standing state at halt
All agents dormant; no marches running; no pushes pending authorization except as
noted above; meta repo local-only commits ahead of origin; marine repo has the
unpushed audit-fix commit(s) on top of deployed 00c8dae. Any successor session:
read scratch/SESSION-STATE-EVOLUTION.md, then this report, before acting. The
operator's stated requirement for any future model work: **validation against the
real buoys is the objective — not internal energy ledgers.**
**Session 2/3 checkpoint (2026-08-16 22:25Z):** Phase F COMPLETE (Gate F PASS); ADR-109 Proposed (8e00541e) AWAITING OPERATOR. Operator-ordered OFS fix (THREDDS 60s timeout + NODD S3 fallback, marine 00c8dae + 3 Q6 fixes) PUSHED + DEPLOYED 22:20:48Z on the operator's push word — post-deploy reality gate + adversarial audit of 00c8dae OWED next session. F4c dead-water WW3 KAT (the energy-loss verdict number) running on librewxr. Full checkpoint: scratch/SESSION-STATE-EVOLUTION.md.
**Session 2 (2026-08-15, "get it done" order):** the GO session's F0 + R2.1 dispatches
died with that session before producing output (no ~/ww3-baselines, no F0-INVENTORY, no
R2.1 report — verified, not assumed). Pre-flight re-verified: /tmp/e1e2 intact 1.4 GB,
meta repo clean at bee94fa0, marine service active. Both tasks RE-dispatched. New facts:
corners.py (R2.1's census script) lives at /tmp/march-loss/corners.py — outside F0's
preservation set and at /tmp-cleanup risk; the R2.1 brief preserves its text to scratch.
Session-local detail: `scratch/SESSION-STATE-EVOLUTION.md`.
Pre-flight at GO: `/tmp/e1e2` intact on librewxr (1.4 GB), marine service active, no march
in flight, meta repo clean except the five files riding this GO commit. F0 dispatched
first (blocks F1–F4); R2.1 dispatched in parallel (read-only, unblocked at GO). Adversarial review history: (1) the
first Fable review was STOPPED by the operator mid-run; its five previewed findings were
verified and applied. (2) A FULL replacement adversarial review ran 2026-08-15 on operator
order (report: `scratch/PLAN-CRITIC-REPORT.md`) — 14 findings (F1–F14), ALL applied
2026-08-15 on the operator's ruling "proceed with all fixes"; see Round-close record.
(3) A FINAL pre-GO adversarial review ran 2026-08-15 on operator order, results-free
(the reviewer barred from the prior report; `scratch/PLAN-CRITIC-REPORT-FINAL.md`) —
18 findings (G1–G18: 1 blocker, 5 major, 12 minor), ALL applied 2026-08-15 on the
operator's ruling "fix them"; see Round-close record. Predecessor [MARINE-PAGE-FIXIT-PLAN-2026-08-10.md](../archive/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md)
CLOSED 2026-08-15 and archived; its open items live in this plan's CARRY-OVER REGISTER.

**Evidence record / authority:**
[SWAN-ENERGY-LOSS-RESEARCH-2026-08-15.md](../reference/SWAN-ENERGY-LOSS-RESEARCH-2026-08-15.md)
— the formal research brief this plan operationalizes. Every physics/architecture claim in
this plan cites that brief (coordinator-verified manual/code cites inside it) or a named
experiment record; the few plan-level SWAN-manual cites outside the brief's verified ranges
(BOUNDNEST3 :2701–2716) were re-verified against the local manual during the 2026-08-15
adversarial review. This plan does not restate the evidence; it turns it into tasks.
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
   should take over ALL L1 functionality regardless?" → **Q1 RULED 2026-08-15 (in chat):
   ALWAYS — "Yup it is option 2 for sure now." No conditionality, no mixing within an
   install; full record + reasoning in the Q1 entry under OPEN OPERATOR QUESTIONS.**
4. Implement the other major strengthening areas from the brief.
5. LUT system LAST — "only after plenty of testing and tweaking to make sure we are getting
   what we feel are accurate and defensible results from the modeling system."
6. Adversarial Fable review of this plan before it lands (first run stopped mid-run, five
   findings applied; FULL replacement review completed 2026-08-15, 14 findings applied on
   operator order — see Round-close record).
7. **No-generic-setup directive (2026-08-15, in chat, with the Q1 ruling), verbatim
   intent:** "This was part of our problem with SWAN, we just deployed a generic setup and
   only after multiple failures did we learn the intricacies of setting up the model
   correctly. I do not have the time to make that same mistake again. We need to make sure
   our ray tracing, our bathymetry analysis, etc… are geared towards collecting the
   information needed to size WW3 grid cells correctly, determine WW3 boundary correctly,
   adjust which parameters and plugins are used (if those exist)… That cannot be an after
   the fact thing here." → PRIME DIRECTIVE 11 + task F5 (parameterization catalog) + the
   PW2 rewrite (setup DERIVATION, not trigger).
8. **ADR impact disposition (2026-08-15, in chat):** "This is obviously going to impact
   other existing ADRs, so we need to know what ADRs also need amended, and the plan needs
   to amend those, or what are completely superseded, and the same needs done." → task
   DOC-W.5 (full-index sweep, provisional impact table, AMEND-NOW edits in-round,
   SUPERSEDED-AT-V5 tags for the V5 retirement round).
9. **Two documentation rounds (2026-08-15, in chat):** "a preliminary round to update
   architecture and manuals so the agents are coding off the right information, and then a
   final update based upon tweaks and changes that happened during the coding process." →
   PHASE DOC-W is the preliminary round; NEW PHASE DOC-W-FINAL (as-built re-sync +
   adversarial zero-drift gate, prerequisite for V4) is the final round — the A1.0/A1.6
   convention made plan-wide.
10. **Detailed syntax prescriptions (2026-08-15, in chat):** "syntax prescriptions NEED
    TO BE DETAILED IN THE PLAN and researched now against SWAN Manual and WW3 manual, as
    that is a weak area that the agents ALWAYS screw up resulting in hours of
    troubleshooting and failed model runs." → §SYNTAX PRESCRIPTIONS rewritten in full:
    16 rows (13 + rows 6a/6b/6c added at the 2026-08-15 final review, which caught the
    grid-file-read / ww3_shel / wind-preprocessor grammar missing), every one
    re-verified 2026-08-15 against the local SWAN manual or the WW3
    v5.16 manual text with line cites; a construct not prescribed there is a
    STOP-and-surface, never an agent improvisation.
11. **WW3 physics configuration designed in-plan (2026-08-15, in chat — after the
    operator called out two rounds of handwaving on it):** the P1 (ST6, same family as
    our SWAN deck) vs P2 (ST4, Ardhuin swell-decay pedigree) candidate design, the
    manual-defaults-untouched rule, and measurement-decided selection → task F1b; the
    switch file is a designed artifact, never a default (SYNTAX row 7).
12. **WW3 model definition designed in-plan (2026-08-15, in chat: "how about the WW3
    model we need to set up? There is still NO MENTION of how that model needs
    configured"):** → §WW3 MODEL DESIGN v1 (WD1–WD10) — domain/grid variants,
    bathymetry/mask/obstructions, exact-match spectral grid, candidate time-step lines,
    forcings split (wind-only candidate, explicit ADR-109 acceptance row), boundary,
    per-cycle initial-state candidates, outputs, run sequence + persisted artifacts.
    Candidate-value discipline: stated here → F confirms → ADR-109 freezes → W DESIGN v1
    implements as-frozen.
13. **Cutover un-forced (2026-08-15, in chat: "if we end up retooling everything with
    LUTs, then the whole slow/fast kind of goes away" → operator approved the fix):**
    V4 becomes a three-verdict DISPOSITION ruling (cut over / hold shadow + open Phase L
    / extend); Phase L's gate is the defensibility ruling alone, cutover NOT required;
    V5 runs on the cutover branch only; W5's production serving flip is designed but not
    built until a cutover verdict. The model build and validation (F/DOC-W/W1–W4/V1–V3)
    are unchanged — the LUT needs a proven model on every branch.

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
  NOT absorbed. Phase W lands the WW3 leg for ALL sites (Q1 ruled always); that plan's
  L1-specific rows apply to the LIVE SWAN-L1 path during the transition (until the
  V4/V5 disposition rulings — cutover only if V4 rules verdict 1); cross-references
  land during DOC-W.
- [MARINE-FORWARD-PLAN.md](MARINE-FORWARD-PLAN.md) open rows untouched; its frozen-core
  list binds here except where a task's Files list names the file.

---

## PRIME DIRECTIVE — carried over from the Fixit plan, binding on every task

1. **Frozen core is OFF LIMITS unless a task's Files list names the exact file.** The
   frozen-core lists of MARINE-FORWARD-PLAN / L1 plan remain closed — explicitly: SWAN wave
   physics marches, jacking, hotstart mechanics, convergence gate, serve-nothing guard,
   `CIRCLE 72 0.03 1.0 34`, `omp_num_threads = 6`, L2/L3/L4 sizing. Phase tasks below name
   their files at dispatch; a file not named is not open.
2. **Baseline before, diff after** every deploy (facing, DWR Hs [DWR = the 15 m deep-water
   reference point; Hs = significant wave height], valid_fraction, publish size, cycle
   wall-clock, boundary file count/bytes; Phase W adds WW3-leg wall-clock and nest-file
   size). rules/coordinator.md §7.
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
11. **No generic model setup (operator order 2026-08-15).** The SWAN lesson — a generic
    deploy whose intricacies were learned only through repeated failures — is NOT repeated
    with WW3. Every WW3 configuration input (grid definition, the four time steps,
    switch-file physics-package selections, namelist constants, boundary placement,
    obstruction inputs, spectral discretization) traces to an F5-catalog derivation rule
    grounded in the WW3 manual, NOAA practice, or an F-phase measurement — and the setup
    analyses (ray tracing / fetch fan, bathymetry analysis, OSM chain) are extended to
    COLLECT the site information those rules need, up front. A deck or switch value with
    no catalog row is a defect, not a default. **Product-facing surfaces expose ZERO
    model-setup controls (operator clarification 2026-08-15: "the operators want to pick
    a surf location and be done with it. We need to be making the proper decisions on
    model setup here in the code"):** universal selections (physics packages, scheme,
    namelist constants) are fixed by ADR-109 and baked into the build + deck emitter;
    site-specific values are DERIVED in code from the picked location. "Operator
    approval" in this plan means the PROJECT operator accepting ADR-109 — a one-time
    design-governance step, never a wizard/admin knob. Binding on every W-phase brief,
    ADR-109, and every gate that reads a WW3 deck.
12. **Design lives in the plan (operator order 2026-08-15: "all DESIGN must take place in
    the plan, agents are for implementation/coding… we do not have to spell out how to
    code, but we need to make sure they are not needing to determine what to code").**
    Every implementation task executes a design block recorded IN THIS PLAN before its
    dispatch — designs land as plan amendments once their evidence exists (W DESIGN v1
    after ADR-109 acceptance; R2.2's design after the R2.1 materiality ruling; Phase L via
    the ADR-110 amendment). Design = mechanisms, data flow, decision trees, file
    responsibilities, acceptance numbers — not code. Agents implement their block
    verbatim; a design deviation is a finding to surface, never an agent call; dispatch
    briefs carry reading lists, scope blocks, and verification commands — never design
    the plan does not contain.

**Execution order (strict):** Phase F → Phase DOC-W (preliminary docs) → Phase W →
Phase DOC-W-FINAL (as-built docs) running CONCURRENTLY with V1–V3 (the shadow campaign
starts at W-Accept; only V4 waits for Gate DOC-W-FINAL) → V4 (disposition ruling) →
Phase L last (opens on the V4 defensibility ruling — with or without cutover). Phase R:
**R2.1 is read-only and UNBLOCKED AT GO**; R2.2 holds to its own condition (R2.1's bound
+ operator materiality ruling); R3 DROPPED (operator 2026-08-15); R4 is opportunistic. R1 requires Phase W's handoff machinery. Docs precede code in every phase
(operator standing instruction) — for Phase R that means the affected
PROVIDER-MANUAL/ARCHITECTURE passages go to target state (tagged) before R2.2 dispatches.

---

## PRE-APPROVAL REGISTER — the architectural changes this plan authorizes (and no others)

All rows contingent on: operator GO of this plan + ADR-109 Accepted (DOC-W.1). Phase F is
scratch-only and needs no register row (no production change of any kind).

| # | Change | Trigger(s) | Ruling basis |
|---|--------|-----------|--------------|
| PW1 | **WW3 deep-water leg added to the modeling system**: the WW3 model binary (built from NOAA-EMC/WW3 source, LGPL v3) runs as OUR process for the deep-water domain at ALL sites (Q1 RULED 2026-08-15: always — no per-site or per-install conditionality, no mixing); SWAN's chain then begins at L2. Until a V4 verdict-1 (cutover) ruling — which may never be given (verdict 2 holds shadow and opens Phase L) — the WW3 leg runs in SHADOW only; the live SWAN-L1 path keeps serving (a transition state, not a site class). New dependency (WW3 build), new persisted files (WW3 grids, obstruction masks, nest/boundary files), new schedule entries (WW3 cycle runs), computation moves host-internal from SWAN-L1 to WW3. Deck/grid specifics fixed in ADR-109 from Phase F measurements. | 2, 3, 5, 6, 7 | Operator 2026-08-15 in chat ("we should go ahead and implement and test our own WW3 system for deep water"; Q1 ruling "it is option 2 for sure"); research brief §4 Option E + §7 (NWPS precedent) |
| PW2 | **WW3 setup DERIVATION in grid-sizing (Q1 RULED: always — the conditional trigger is DEAD)**: mechanical, config-time derivation of the WW3 leg's configuration in `compute_domains()`-adjacent sizing code, per the F5 catalog rules: grid extent/resolution (and grid COUNT, if NOAA's 2:1–3:1 hop practice demands an intermediate grid between NOAA's ~16 km output and our target resolution), boundary placement in NOAA-trusted open water (the A1 containment lesson generalized — the offshore domain reads the REGION's geometry, e.g. the Channel Islands, never the spot's local features, which belong to L3/L4), the four WW3 time steps, obstruction inputs. Every derived value logged with the site inputs that produced it; NEVER a hand-tuned per-site deck. Derivation rules + this install's values fixed in ADR-109. | 3, 6 | Operator 2026-08-15: Q1 ruling ("option 2 for sure") + the no-generic-setup directive (PRIME DIRECTIVE 11) |
| PW3 | **WW3→SWAN L2 handoff contract**: L2's boundary source becomes WW3 output — target state, ALL sites (mechanism — BOUNDNEST3 nest file vs Appendix-D spectra files — fixed in ADR-109 per F evidence; SYNTAX PRESCRIPTIONS bind grammar). The existing per-wet-cell BOUNDSPEC-into-L1 mechanism stays for the LIVE SWAN-L1 path until a V4 verdict-1 (cutover) ruling, if given (transition state, not a site class). | 3, 4 | Research brief §7 (BOUNDNEST3 manual-native); ADR-109 |
| PW4 | **Boundary reconstruction gains a WW3-input emitter**: the existing parametric-spectra reconstruction (constants UNCHANGED) gains an output path writing WW3 boundary input for the WW3 leg's offshore boundary — assembled by ww3_bound OR ww3_bounc, whichever ADR-109 picks from F evidence (SYNTAX row 9; this row does not pre-decide it). | 4, 7 | Research brief §7 (nesting mechanism); reuse of the solved reconstruction problem |
| PW5 | **WW3-leg operational surface**: health keys (WW3 nest age analog of `l1NestAge`), refuse gates, config keys for the WW3 leg **including the per-site shadow-mode key (run-without-serving — the mechanism W-Accept's dark launch uses)**, wizard+admin surface for install/health status DISPLAY only (read-only — there is NO enable/disable knob: WW3 is always-on per Q1, and the sole write-capable key is the TRANSITION-ONLY shadow-mode key, which dies with the transition at cutover/retirement); no model-setup controls of any kind reach a product surface (PRIME DIRECTIVE 11). Key names/values fixed in ADR-109. | 6, 7 | Refuse-loudly posture carry-over; OPERATIONS-MANUAL sync; Q1 always-ruling (no enable state exists to surface) |
| PW6 | **Handoff placement rule (R1) — DETECTION ONLY**: grid-sizing gains the depth-step DETECTION rule (brief §5: per-cell depth-change ratio), computed and logged as a standing diagnostic and as an F5-catalog input to WW3 grid sizing. Placement preference is APPLIED only to the new WW3→L2 handoff at Phase W. **Relocating the LIVE SWAN-L1 path's L1→L2 seam is WITHHELD** — the research verdict is that seam relocation is UNPROVEN as a fix (brief §2); if V2's cliff-KAT measurement shows it helps, the relocation returns to the operator and, if ruled, enters by plan amendment with its own task row, gate, and separate deploy. (Fix 2026-08-15, adversarial review F3 — the prior text pre-authorized an unproven change that no task owned.) | 3 | Research brief §2 + §5; V2 delivers the verdict; operator rules |
| PW7 | **DEAD 2026-08-16** (operator ruling, Q4: NOT MATERIAL — "the east side is land?"). Was: fed E-side boundary (R2.2) contingent on a materiality ruling over R2.1's bound. The bound was arithmetically verified twice (16.6–24.5%) but rested on a physically impossible premise for >11 s energy (coast/Baja-blocked directions filled with open-ocean ambient). Nothing is authorized by this row; R2.2 never dispatches. | — | Operator ruling 2026-08-16 (Q4 record) |
| PW8 | **DROPPED 2026-08-15** (operator, in chat: "drop it"). Was: the Problem-2 multiSwell-selection fix, withheld pending a confirmation protocol whose underlying observation the operator was never shown. Nothing is authorized by this row; any future multiSwell selection/assembly change starts from scratch as a new operator ruling. | — | Operator ruling 2026-08-15 |
| PW9 | **LUT system (Phase L)**: WITHHELD ENTIRELY. Phase L opens with its own design round and ADR-110; nothing in Phase L is authorized by this register. Listed so the boundary is explicit. | all | Operator: LUT is last, gated on defensible model results |

Withheld in general: model-physics changes of any kind (SWAN or WW3 source terms, breaking,
friction — any formula/constant; the INITIAL WW3 switch-file/namelist selections are fixed
in ADR-109 via the F5 catalog and operator-Accepted there — changing them afterwards is a
physics change and returns to the operator); cutover/decommission decisions (V4/V5 are
operator ruling rows); anything touching the live SWAN-L1 path's frozen core (its status
changes only through the V4/V5 rulings).

---

## CARRY-OVER REGISTER — inherited open items (from the closed Fixit plan + session)

| # | Item | State at close | Where it lands |
|---|------|----------------|----------------|
| C1 | B2-Accept (served multiSwell shows real trains) | **UNBLOCKED since 2026-08-14**: the operator's freeze condition ("not eyeballing anything else until you get the model right" = A1 passing its reality validation, A1.5) is SATISFIED — A1.5 PASSED 2026-08-14 | Operator may eyeball ANY TIME; V3 offers a consolidated round at the latest |
| C2 | S-Accept card eyeball | pending operator; unblocked (same A1.5 condition) | Any time; V3 at the latest |
| C3 | K-Accept rows 1 (cam eyeball) + 3 (knob drill go) | pending operator; unblocked (same) | Any time; V3 at the latest |
| C4 | H re-accept (dry-beach + ortho remediations deployed) | pending operator; unblocked (same) | Any time; V3 at the latest |
| C5 | Unfed-E census re-derivation at corrected time index (06Z = index 2 in 3-hourly files) | derivation error found, not redone. Premise citation (carried-premise rule): the census and its index correction are research-brief §1 items, and the operator's 2026-08-15 order to operationalize the brief (CURRENT STATE items 2/4) covers them; the resulting bound STILL goes to the operator before any fix (PW7) | Task R2.1 (read-only, first R2 step; Gate R2.1 audits the arithmetic) |
| C6 | ~~Problem-2 confirmation protocol~~ **DROPPED 2026-08-15** (operator, in chat: "drop it, it is not an issue right now I want to deal with") — the underlying observation was a prior session's hypothesis, drafted "for operator review" but never shown to or validated by the operator (premise failure; see Round-close record) | dropped | No task. The protocol file stays in `scratch/` as a record only. V3's served-quality comparison backstops this symptom class with real evidence if it exists |
| C7 | Fresh buoy apples-to-apples (18s SSW event; old probe hung, killed) | owed | On request any time (read-only). NOTE: the SPECIFIC event's buoy data leaves NDBC's ~45-day realtime window (~2026-09-26) — if the operator wants THAT event, it runs before then; otherwise V3 substitutes a fresh matched-time event and says so |
| C8 | ~~Two rule-lessons pending operator go/no-go~~ ✅ RESOLVED 2026-08-15: Q3 approved ("ok") — both carried lessons WRITTEN into the rules files, plus two new ones from this session (SSH scratch carve-out; carried-premise validation). See Q3 record | resolved | rules/agents.md + rules/verification.md edited this session (uncommitted; ride the next meta commit) |
| C9 | Unpushed local commits: meta repo ahead (A1 as-built docs, gate records, research brief chain, this plan's closeout/creation commits); marine ahead 1 (`e40d2c9` F2 citation comments) | local-only | Pushed only on the operator's word "push" (standing rule); inventory kept current here |
| C10 | Marine failure monitor `b4omhq1fs` | armed | Stays armed through this plan |
| C11 | L1-BOUNDARY-REBUILD-PLAN deferred queue (Gate S wlevel → S1+S4a currents → Phase A → Gate C → V) | that plan's own queue | NOT absorbed; noted for scheduling awareness only |
| C12 | Research-round scratch artifacts worth keeping (WW3 manual text extraction, energy-ledger scripts, and the `/tmp/e1e2` pinned baseline inputs + cliff-KAT deck) | `scratch/` holds the manual extraction. The ledger scripts were /tmp-ONLY until 2026-08-15 — the final review (G18) caught this row claiming otherwise — and are NOW mirrored to `scratch/energy-ledger-scripts/` (9 .py files copied from /tmp/e1e2 the same day). The /tmp/e1e2 pinned INPUTS + decks remain /tmp-only and NOT re-fetchable (the WW3 source clone was DELETED 2026-08-15 per the SSD cleanup — re-fetchable) | DOC-W.4 commits the WW3 manual text to docs/reference AND the ledger scripts to `scripts/analysis/` (repo changes belong to DOC-W, keeping Phase F pure scratch); task F0 still preserves the FULL /tmp/e1e2 pinned-input set + cliff-KAT deck at GO, BEFORE any other work (the script mirror does not shrink F0's scope — checksummed inventory of everything) |
| C13 | Phase T (tide coherence) close acknowledgment — the archived plan's WAITING-ON-OPERATOR item 4, deployed but never nodded closed | owed since 2026-08-11 | One-line operator acknowledgment (or reopen) at any convenience; listed so it isn't lost |
| C14 | ~~Un-answered `L1_NEST_MAX_AGE_H = 9` semantics~~ ✅ RULED 2026-08-15 (operator, in chat: "yes a"): **REFUSE** — when the archived nest exceeds 9 h, the hourly cycle stops publishing, the site serves the last good forecast, health goes red with the named reason. The live default is now operator-confirmed | resolved | ADR-109 copies these semantics to the WW3-leg age gate; the same refuse posture is the precedent for LUT-era input-freshness gates |
| C15 | Z3.8 state-audit findings with NO recorded closure: V6 (retry loop: no backoff/failure-counter/escalation), V7 (staleness-honesty — health reads green during outages), V11 (hourly trigger cleared before the attempt, no retry), V12 (run-dedup MemoryCache-only, lost on restart), V13 (non-atomic `swan_grid_sizing.json` persist), V14 (parked LOWs) | ✅ DISPOSITION AUDIT DONE 2026-08-15 (session 2, lead-spot-checked): **V6/V7/V11/V12/V13 CLOSED** by marine `237b34c` (Z3.9b, operator-ruled 2026-08-13 "all the mechanical fixes need done"; verified un-reverted at HEAD). **V14 STILL OPEN** (3 sub-items: blocking no-timeout lock in geometry-push path; post-restart cooldown in-memory only; no hotstart-age gate). Full evidence `scratch/C15C16-DISPOSITION.md` | Surviving list → **Q6 (operator)**. Findings feed W5's health/refuse design |
| C16 | Z3.10/Z3.11 parking lot: `model_wave_source.py:121` blind `swells[0]` on non-surf marine cards; NDBC fetch stagger; RTOFS currents; hotstart age; graceful degradation | ✅ DISPOSITION AUDIT DONE 2026-08-15 (session 2, lead-spot-checked): `model_wave_source.py` gap REAL but archive framing WRONG (module is surf-spot-only; the live gap is the missing `_MIN_SURFABLE_PERIOD_S` 5 s floor every other selection site has — bare `swells[0]` now at :123). "Hotstart age" = V14 sub-item 3 (not double-counted). NDBC stagger / RTOFS currents / graceful degradation: **CANNOT ESTABLISH** — archive gives bare phrases, no testable claim. Evidence `scratch/C15C16-DISPOSITION.md` | Surviving + unresolvable items → **Q6 (operator)** |
| C17 | ~181 stale old-design `B_*.txt` on librewxr disk (inert — INPUT never references them; B2-Accept record) | cleanup candidate | Housekeeping round, operator-visible before any deletion |
| C18 | Currents tail-hold path (Z3.9 ruling (a)) never live-exercised | verification queue. Premise citation (carried-premise rule): Z3.9 ruling (a) IS an operator ruling, recorded in the archived Fixit plan | Watch during the V1 shadow campaign: confirm on a cycle where WCOFS demonstrably falls short of coverage_end |
| C19 | Parked physics candidates from the archive's close: L4/1-D deep-ledge handoff loss; 5° directional-resolution experiment for the NEARSHORE chain (E7 closed the directional question for the L1 seam ONLY) | parked. **UNVALIDATED — surface to operator before any work** (carried-premise rule: lead/agent-parked candidates; no operator ruling on either is on record) | Experiment-class (R4 pattern): scratch-only, idle capacity, operator-INFORMED FIRST (the tag above makes that mandatory, not courtesy); listed so they are not lost |
| C20 | ~~ADR-107 (wind gatherer) still Proposed~~ ✅ RESOLVED 2026-08-15: **Accepted by the operator in chat ("yes adr107 is approved")** — status flipped in the ADR + INDEX same session | resolved | DOC-W.5 still amends it (the WW3 leg becomes a second consumer of the assembled wind store) |

---

## NAMED CONSTANTS fixed by this plan (not re-derivable by agents)

- **Energy-ledger band edges: < 0.09 Hz / 0.09–0.2 Hz / > 0.2 Hz** (>11 s / 5–11 s / <5 s)
  — the measurement frame every before/after comparison in this plan uses. Log-spaced
  spectral integration per the existing ledger scripts (uniform-spacing integration
  under-reads ~5× — known trap, recorded at `scratch/BRIEF-ENERGY-LEDGER.md:19`; provenance
  corrected 2026-08-15 — it is NOT in the archived Fixit plan).
- **The cliff KAT** — KAT = known-answer test, a check against an independently-derived
  expected value (rules/verification.md) — is the standing regression instrument for
  shelf-break/seam work (R1, V2). Its FULL spec (run e8b2, `scratch/NOTES-E1E2-RESULTS.md`
  + the deck preserved by F0): uniform 0.650 m boundary spectrum (Tp 14 s, from 197°,
  cos^56 spread), islands WETTED, wind zeroed, ALL source terms off (wind growth /
  quadruplets / whitecapping / breaking), single stationary solve (~2-min wall-clock),
  sampled at the 7 standing S-edge seam points. Its current answer: **0.578 m** seam
  aggregate. Re-running it means THIS deck — re-deriving "a cliff KAT" from the headline
  description alone (e.g. with real islands) produces a different, non-comparable number.
  Any change claiming seam improvement must move THIS number and say by how much.
- **`L1_NEST_MAX_AGE_H = 9`** carries over for the live SWAN-L1 path (until the V4/V5
  disposition rulings); the WW3-leg age-gate analog gets its value in ADR-109 (not invented by
  agents). Refuse-on-stale semantics operator-CONFIRMED 2026-08-15 (C14 ruling: "yes a").
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

## SYNTAX PRESCRIPTIONS — binding; DETAILED per operator order 2026-08-15; sources model-matched (PRIME DIRECTIVE 10)

*(Operator order 2026-08-15: "syntax prescriptions NEED TO BE DETAILED IN THE PLAN and
researched now against SWAN Manual and WW3 manual, as that is a weak area that the agents
ALWAYS screw up." Every row below was re-verified against the LOCAL SWAN manual
(`docs/reference/swan-user-manual.txt`) or the WW3 manual text on 2026-08-15, with line
cites. **WW3 manual authority is v6.07 as of the 2026-08-16 Q5 ruling**
(`scratch/ww3-manual-6.07.txt`, committed at DOC-W.4). **6.07 re-verification COMPLETE
2026-08-16 (lead-spot-checked): every WW3-side row's grammar, code table, and quoted
numeric value is UNCHANGED at 6.07 digit-for-digit** — the manual was reorganized (new
Ch.6, deck examples → new App. G, appendix relettering C→B/D→C/E→D, §5.4.x→§5.9.x), so
the `:NNNN` cites in the WW3-side rows below are 5.16-era HISTORICAL locations; the
authoritative per-claim 6.07 line cites live in `scratch/SYNTAX-607-VERIFICATION.md`
(committed at DOC-W.4 beside the manual). Gates syntax-checking decks use the 6.07
cites from that report. One substantive 6.07 delta, absorbed by design: ST6's
calibration-table defaults changed from 5.16 (see the F1b note).
**Standing rule: a deck/input construct NOT prescribed here is a STOP-and-surface, never
an agent improvisation; every gate that reads an emitted deck syntax-checks it line by
line against these rows AND the cited manual text.**)*

**SWAN side (LOCAL manual only):**

1. **Live-path BOUNDSPEC grammar (restated IN FULL from the Fixit plan — no more
   by-reference to the archive):** `BOUNDSPEC SIDE <W|S|E|N> CCW VARIABLE FILE <len_1>
   'B_<side>_<0001>.txt' 1 …` — one command per offshore side; `[len]` in UTM metres from
   the side's CCW begin corner (corner map: S begins SW, W begins NW, N begins NE, E
   begins SE), strictly ascending; `[seq] = 1`; `&`-continuation wrapping with the
   180-char line guard. Manual authority: SWAN itself interpolates boundary spectra
   between supplied positions (:2481–2486); supplied points need not coincide with grid
   points (:2507–2509); `[len]` metres-in-Cartesian, ascending (:2509–2515).
2. **Position list:** one `[len]` per selected wet WW3 cell (cell centre projected onto
   the side) PLUS two endpoint copies (len 0.0 and len = side length, each a byte-copy of
   the nearest selected wet cell's file) — full-side coverage independent of SWAN's
   beyond-endpoint behavior. Viability floor ≥ 2 wet cells per side
   (`BoundaryNotViableError`).
3. **Boundary file grammar (Appendix-D nonstationary 2-D spectra):** `SWAN   1` header;
   TIME coding 1; AFREQ 35 / NDIR 72 — the CGRID spectral axes EXACTLY, so SWAN's
   file-axis interpolation (:2552–2555 — file axes need not coincide; SWAN interpolates
   when they don't) is never exercised; VaDens in m2/Hz/degr; per-timestep FACTOR;
   frequency-major matrix; LOCATIONS carries the cell centre in UTM (truthful; ignored by
   SWAN for placement, :2555–2557). Writer: the existing `write_swan_2d_spectrum_file()`
   byte-for-byte.
4. **BOUNDNEST3 (WW3-leg candidate A) — full researched grammar (:2694–2756):**
   `BOUndnest3 WW3 'fname' <UNFormatted|FREe> <CLOSed|OPEN> [xgc] [ygc]`
   - `'fname'` = the WW3-computed spectra file; `UNFORMATTED` = binary, `FREE` =
     formatted (:2735–2737) — MUST match how the WW3 post-processor wrote it (row 11).
   - `CLOSED`/`OPEN` = whether the boundary curve in the file closes a rectangle
     (:2738–2739).
   - CGRID must be issued BEFORE this command (:2702–2705); the SWAN computational area
     is the area bounded by the WW3 nest — their boundaries "should be (nearly)
     identical" (:2705–2708).
   - Spectral axes need NOT match — SWAN interpolates to the CGRID axes (:2708–2711).
   - Acceptance window: a SWAN boundary point is fed only if it lies within a rectangle
     between two consecutive WW3 output locations, width 0.1× their spacing on either
     side (:2723–2727) — sloppy WW3 point placement silently starves boundary segments.
   - WW3 locations must be written IN SEQUENCE along the nest boundary, clockwise or
     counterclockwise (:2722–2723); the boundary need not be closed and may cover land
     (:2720–2721).
   - `[xgc] [ygc]`: REQUIRED when SWAN runs Cartesian (our L2) — the SWAN grid's SW
     corner in geographic degrees, mandatory if the WW3 nest's SW corner is on land;
     ignored for spherical SWAN (:2740–2756). TRAP: the manual's own text misprints
     "longitude" for both — `[xgc]` is longitude, `[ygc]` latitude.
   - Not available for 1D SWAN computations (:2729). Curvilinear nests must conform to
     the rectangular coarse-grid nest boundary (:2731–2733).
   - Candidate B — WW3 output → our Appendix-D writer → BOUNDSPEC per rows 1–3 (source
     data changes, mechanism doesn't). **ADR-109 picks A or B from Phase F evidence.**
     Until then BOUNDNEST2/3 stay forbidden-in-production (Fixit rule carries over).
5. **Never emit:** `BOUNDSPEC … PAR`, TPAR, `BOUND SHAPE`, bare `DIFFRACTION`,
   BOUNDNEST2 (standing prohibitions). L2's live-path `BOUNDNEST1 NEST 'nest_in.dat'
   CLOSED` chain untouched (same-coordinate-system rule :2592; CGRID-before-BOUNDNEST1
   :2575–2576).

**WW3 side (v6.07 manual + WW3 source per the Q5 ruling; NEVER inferred from the SWAN
manual; line cites below are 5.16-era pending the 6.07 re-verification amendments):**

6. **`ww3_grid.inp` structure (the model-definition input):**
   - Spectral definition line: frequency increment factor, first frequency (Hz), number
     of frequencies, number of directions, relative offset of first direction in
     [−0.5,0.5] (:7372–7386; manual example `1.1 0.04118 25 24 0.`; the manual's
     recommendation — stated for the exact nonlinear-interaction computation, not
     general grid sizing — is ~40 frequencies at increment factor **1.07**, :1233–1235;
     misquote of 1.1 fixed 2026-08-15). OURS must bracket the reconstruction axes' range
     (0.03–1.0 Hz class) — exact values are F5-catalog rows fixed in ADR-109.
   - Model flags line `FLDRY FLCX FLCY FLCTH FLCK FLSOU` (:7390–7402).
   - Time-steps line — FOUR values, THIS order, all seconds: maximum global step, maximum
     CFL step for x-y (CFL = the Courant stability limit — the longest time step a wave
     can take without crossing more than one grid cell per step; beyond it the numerics
     destabilize), maximum CFL step for k-theta, minimum source-term step
     (:7406–7417; example `900. 950. 900. 300.`). Global step per Named Constants (2–4×
     the critical CFL step); the x-y CFL limit is applied PER FREQUENCY BIN internally
     (§3.2 p.102; `w3pro3md.F90:923`).
   - Namelist section (a namelist is Fortran's named parameter-group input format,
     `&GROUP key = value /`; open-ended, closed by `END OF NAMELISTS`): physics tunings
     live here; **`&MISC … FLAGTR = n /`** declares sub-grid obstruction data — 0 none,
     1 transparencies at cell BOUNDARIES, 2 transparencies at cell CENTERS, 3/4 = 1/2
     with continuous ice (:8062–8076; example :8175). If FLAGTR > 0, the obstruction
     field is read as additional bottom-style input (:8609–8615; read grammar row 6a) —
     versioned persisted files per PW1.
   - Input-boundary points for a nested run are MARKED in the child's `ww3_grid.inp`
     (manual §4.4.2 — status-map value 2 or segment lines, row 6a), and the `!/O1`
     switch must be compiled in to list them (App. C.1 step 3, :16985–16994).
6a. **`ww3_grid.inp` grid-definition + file-read grammar (the block WD2's files flow
    through — added 2026-08-15, final review G1; rows researched from §4.4.2):**
   - Grid-definition lines for our rectilinear spherical grid (worked example
     :8410–8416): grid type + closure `'RECT' T 'NONE'` (T = spherical); `NX NY`;
     grid increments + scaling DIVISOR; coordinates of point (1,1) + scaling DIVISOR.
   - Bottom-depth read line (:8357–8363): limiting depth (m) discriminating land from
     sea, minimum water depth (m), unit number, SCALE FACTOR for depths
     (MULTIPLICATIVE), IDLA, IDFM, format string, FROM (`'UNIT'`|`'NAME'`), filename.
     IDLA layout codes: 1 = line-by-line bottom-to-top, 2 = like 1 in a single read,
     3 = line-by-line TOP-to-bottom, 4 = like 3 in a single read (:8365–8373). IDFM
     format codes: 1 = free format, 2 = fixed per the format string, 3 = unformatted
     (:8375–8381). Unit 10 = the field follows INLINE in ww3_grid.inp, no comment
     lines inside it (:8391–8397). TRAP — sign convention rides the scale factor: the
     manual's own example (`-0.1 2.50 10 -10. 3 1 '(....)' 'NAME' 'bottom.inp'`,
     :8418) turns POSITIVE file digits into water via a NEGATIVE scale; ETOPO stores
     water as NEGATIVE elevations, so OUR scale/limiting-depth pair must be derived
     together and KAT-checked against a known cell (an inverted sign silently lands
     the whole domain).
   - Obstruction read, only when FLAGTR > 0 (:8612–8630): unit number (if EQUAL to
     the bottom unit, the manual assumes the SAME file without further checks,
     :8634–8638), scale factor for fractional obstruction (example: 0.2 scaling
     single-digit 0–5 data to 0–1 fractions, :8630), IDLA, IDFM, format, FROM,
     filename — then TWO fields (x- and y-transparencies), each NX×NY (:8650–8703).
   - Status-map / boundary-point block (:8707–8719): unit, IDLA, IDFM, format, FROM,
     filename; `FROM = 'PART'` = segmented data inline. Map legend: 0 = land, 1 =
     regular sea, **2 = active boundary point** (how row 6's nested-run boundary
     marking is actually written), 3 = excluded (:8753–8763). Segment lines are
     `IX IY connect-flag` (connect fills intermediate points on a line/diagonal),
     closed by the MANDATORY `0 0 F` (:8778–8798).
6b. **`ww3_shel.inp` structure (the march deck rows 8/11 edit — §4.4.9 :9687–10431):**
   - Forcing-flags block, FIXED order (ice/mud parameter lines appear only when IC
     switches are compiled in): water levels, currents, winds, ice concentrations,
     3× assimilation — each line a use flag (F/T/C) plus a homogeneous-field flag
     (:9729–9766). Row 11's boundary-only validation = winds flag F here (plus no
     restart file present).
   - Time frame: start line, then end line, `yyyymmdd hhmmss` (:9770–9780).
   - IOSTYP output-server line — 1 is the manual's general recommendation
     (:9788–9816).
   - Output types 1–7 IN ORDER, each opening `first-time interval(s) last-time`;
     interval 0 disables a type (:9820–9828). Type 2 (point output): one
     `lon lat 'NAME'` line per point (names ≤ 10 chars, no spaces advised), list
     closed by the literal name `'STOPSTRING'` (:10253–10302) — WD9's handoff/seam/
     buoy points live here. Type 4 = restart-file cadence (:10322–10330, WD8). **Type
     5 = boundary (nest) data — THE activation times row 8 references**; begin/
     increment/end here decide the child-nest data cadence (:10334–10342). Type 6 is
     a dummy line; Type 7 (coupling) stays FULLY commented unless the COU switch is
     compiled (:10346–10366).
   - Homogeneous-field data closes the deck; `'STP'` is the MANDATORY stop string
     (:10397–10423).
6c. **Wind-field preprocessor decks (WD6's ww3_prnc/prep path):**
   - `ww3_prep` (ASCII, §4.4.6 :9225–9433): field-type line `'WND' 'LL' T T` (field
     type, format type AI/LL/F1/F2, time-in-file flag, header flag, :9253–9306 —
     provenance correction 2026-08-16: the manual's own §4.4.6 worked example is
     `'ICE' 'LL' F T` (6.07 :17983); our `'WND' 'LL' T T` is the same grammar with the
     wind field type and time-in-file TRUE, composed from the field-definition table,
     not a verbatim manual example); for
     `'LL'` a grid-range line `x0 xn nx y0 yn ny` (degrees or metres, :9320–9328);
     data-file definition — FROM/IDLA/IDFM + format string(s), then unit + filename
     per file (:9374–9384; unit 10 = data inline, :9391–9393). Product: `wind.ww3`.
   - `ww3_prnc` (NetCDF, §4.4.7 :9445–9578): field-type line `'WND' 'LL' T T`; a
     dimension-names line (the time dimension MUST be named `time`, Julian/Gregorian
     calendar, :9532–9540); a variable-names line (e.g. `UV`, :9544–9548); the
     filename line (:9562–9568).
   - ADR-109 picks prep-vs-prnc with the wind-store output format. TRAP: the pinned
     `WIND.txt` (F0) is a SWAN-format wind file — it is NEVER fed to ww3_prep as-is;
     F2 tooling re-emits its DATA in the 'LL' deck grammar above (same numbers, WW3's
     own read format — PRIME DIRECTIVE 10 applies to file formats too).
7. **The switch file IS a physics design decision, never a default.** Switch-string
   grammar per the manual's own example (:14459: `F90 NOGRB … SHRD NOPA PR3 UQ FLX2 LN1
   ST2 STAB2 …`) — one token per category: propagation scheme, flux, linear input,
   source-term package, stability, etc. OUR switch content is designed in §PHASE F task
   F1b (the P1/P2 physics candidates) and frozen in ADR-109 with every token traced to an
   F5-catalog row. An agent never chooses a switch token.
8. **Nest generation, parent side (App. C.1, :16960–17055):** the parent writes boundary
   data activated by begin/increment/end times in `ww3_shel.inp` (deck grammar row 6b,
   output type 5); first nest file is
   `nest1.ww3` (up to 9 per run), renamed to `nest.ww3` in the child's run directory; the
   child processes it automatically. MANDATORY verification duties (the manual's own):
   the child's `ww3_shel` output must report `nest.ww3` "has been processed and has been
   found OK" with no incompatible/missing-boundary warnings, and `log.ww3` must show
   boundary updates at the expected times (:17034–17042).
9. **External boundary assembly — our offshore edge (App. C.2, :17057–17070; §4.4.4
   :9042–9114):** when the boundary comes from external data (our reconstructed spectra
   from NOAA public output), `nest.ww3` is built by **`ww3_bound`** (ASCII spectra in the
   ww3_outp transfer format, `WRITE` mode, interpolation method 1=nearest/2=linear, list
   of spectra files) or **`ww3_bounc`** (same job, NetCDF spectra, :9110). HARD
   CONSTRAINT either way: every input spectra file must share ONE spectral grid
   (:17066–17067) — W2's emitter emits all cells on a single spectral grid. ADR-109
   picks bound-vs-bounc from F evidence.
10. **WW3→SWAN transfer file (candidate A's pairing):** produced by `ww3_outp` with
    ITYPE=1 (spectra), OTYPE=3 (transfer file) — additional inputs: scaling factors,
    unit number, unformatted flag (:12049–12069). Record structure (:12073–12101): file
    ID + nfreq/ndir/npoints + grid name; bin frequencies in Hz; bin directions in
    RADIANS, oceanographic convention; then per time (yyyymmdd hhmmss), per point: name,
    lat, lon, depth, wind speed/direction, current speed/direction, then E(f,θ).
    Formatted output is free-format readable. PAIRING RULES: the unformatted flag must
    match SWAN's `UNFORMATTED`/`FREE` keyword (row 4); the output points must be the
    SWAN nest-boundary locations in boundary sequence (rows 4/8). **F-phase compatibility
    row (mandatory before ADR-109 picks A): one real transfer file written by OUR
    6.07.1-built `ww3_outp` (version per F1-as-built + Q5 ruling) and read by OUR SWAN 41.51AB `BOUNDNEST3`, end to end — a
    reader/writer format mismatch here is exactly the hours-of-troubleshooting class
    this section exists to prevent.**
11. **The boundary-only validation run is a standing instrument:** the WW3 manual's own
    recommended nest test — run the child with wind OFF and no restart file, so energy
    can enter ONLY through the boundary (:17043–17049; deck mechanics per row 6b). This is the WW3-side analog of
    our e8 cliff KAT; F2/F4 use it for the handoff-fidelity rows and W3's round-trip KAT
    mirrors it.
12. **Island representation:** resolved dry cells at fine resolution AND/OR the
    obstruction-grid transmission mechanism (FLAGTR, row 6) for coarser grids — F2/F3
    test both, ADR-109 fixes the choice per domain resolution.
13. **Grids are spherical (lat/lon)** for the WW3 leg — the flat-projection strain that
    bound the big Cartesian L1 does not apply; SWAN legs stay Cartesian at their
    existing scales (BOUNDNEST3's `[xgc]/[ygc]` bridges the frames, row 4).

---

## WW3 MODEL DESIGN v1 — the model definition (added 2026-08-15, operator order: the WW3 setup itself must be designed in the plan)

*(The WW3 counterpart of A1's D1–D9: lead-authored, in-plan, operator-visible. Discipline
per row: a CANDIDATE value is stated here → Phase F confirms or corrects it by
measurement → ADR-109 freezes it → W DESIGN v1 implements it as-frozen. Every value is
also an F5-catalog row. Agents implement; they never pick a value this section leaves
open — an open value is a STOP.)*

- **WD1 — Domain & grid variants (spherical, SYNTAX row 13).** Extent = the current L1
  footprint in geographic coordinates (ADR-108's box: SW ≈ 32.60°N, 119.25°W; NE ≈
  34.07°N, 117.77°W — exact corners recomputed from the live sizing at F2, not retyped).
  Variant **G1**: ~1 km cells (≈0.0090° lat × ≈0.0107° lon at 33.3°N), islands as
  resolved dry cells. Variant **G2**: ~3–5 km cells + obstruction grids (FLAGTR, SYNTAX
  rows 6/12). Open decision row: whether an INTERMEDIATE grid belongs between NOAA's
  0.16° (~16 km) output and the target resolution — NOAA's own practice steps 2:1–3:1
  per hop (feasibility record); F2/F3 evidence answers it; ADR-109 fixes grid COUNT.
- **WD2 — Bathymetry, mask, obstructions.** ETOPO 2022 15s, LMSL (Local Mean Sea Level,
  the vertical datum the depths are referenced to) — the SAME source and
  datum as L1 (ADR-108; ADR-098 match-at-source discipline binds). Depth/land-mask files
  in `ww3_grid.inp`'s own read conventions (scale factor and the IDLA/IDFM
  layout-and-format read tokens per SYNTAX row 6a, including its depth-sign TRAP —
  stated in the deck, never defaulted). G2's obstruction/transparency fields are
  GENERATED from the same coastline+bathymetry data (the Chawla & Tolman lineage, brief
  §6); the generator is F2 tooling and its outputs are versioned persisted files (PW1).
- **WD3 — Spectral grid: EXACT match to the reconstruction axes.** Increment factor
  ≈1.1086 (the CGRID log spacing), first frequency 0.03 Hz, 35 frequencies, 72
  directions (5°), relative offset 0 (offset exists to mitigate the garden-sprinkler
  error — the coarse-directional-grid artifact where a smooth swell field breaks into
  discrete spokes, like a lawn sprinkler — on first-order schemes, :7378–7381; not
  needed with PR3). Rationale: one spectral
  grid end-to-end (reconstruction → ww3_bound/bounc's single-grid constraint, SYNTAX
  row 9 → WW3 → handoff → SWAN CGRID axes) eliminates spectral interpolation at BOTH
  seams; the feasibility cost arithmetic already assumed 34×72-class bins, so this buys
  fidelity at no unbudgeted cost. 72 directions is deliberate (brief §2.6.3: swell wants
  5°–2°) and is 2–3× NOAA's typical count — the F3 wall-clock verdict prices it.
- **WD4 — Time steps (SYNTAX row 6's four-value line, seconds), candidates:** global
  **100** (3× the 33.4 s critical CFL step at 1 km/0.03 Hz — Named Constants; the
  Frontiers 2026 application used the same 3× ratio); max x-y CFL **33**; k-theta **50**
  (deep-water guidance: global down to half, manual §3.2/App. B.1); source-term floor
  **10** (the manual's 5–15 s band). G2's coarser cells relax the CFL step ~3–5×; its
  line is derived by the same rules. F3 confirms; ADR-109 freezes.
- **WD5 — Physics:** per task F1b (P1 = ST6 family-match vs P2 = ST4 swell-decay
  pedigree; manual defaults untouched; decided on F4.2's rows; frozen in ADR-109).
- **WD6 — Forcings (an explicit ADR-109 acceptance row, NOT a silent omission).**
  Candidate: **wind only** at the deep leg — the assembled wind store regridded onto the
  WW3 grid through the ww3_prnc/prep path (deck grammar SYNTAX row 6c; archived-cycle
  exception for benchmarks: F0's pinned WIND.txt, re-emitted per row 6c's format TRAP). Water level and currents stay SWAN-side (L2 down): tide-scale depth
  modulation is negligible over the leg's ≥hundreds-of-metres depths, and currents
  remain the L1-BOUNDARY-REBUILD plan's own queued program. The operator accepts or
  overrides this split at ADR-109.
- **WD7 — Boundary.** Offshore edges fed from our reconstructed NOAA spectra assembled
  into `nest.ww3` via ww3_bound or ww3_bounc (SYNTAX row 9; W2's emitter writes ONE
  spectral grid = WD3); boundary placement on the NOAA-trusted open-water line (PW2's
  derivation — the containment lesson); coastal edges closed as land.
- **WD8 — Initial state per cycle (F3 measures, ADR-109 freezes).** Candidates:
  (i) restart-file chaining (`restart.ww3`, WW3's native hotstart) with a staleness
  gate, or (ii) cold start with a spin-up LEAD — begin the march 6–12 h before the
  cycle window on boundary+wind data so the domain is developed when the served window
  opens (the deep leg's analog of SWAN's stationary spin-up solve). F3's spin-up
  transient measurement decides the lead length / the chaining choice. Refuse-loudly:
  neither path ever fabricates an initial sea state silently.
- **WD9 — Outputs per cycle.** Hourly point spectra at the L2 boundary locations (the
  handoff product — transfer file for mechanism A per SYNTAX row 10, or spectra for our
  Appendix-D writer for mechanism B); hourly field output for the ledger instruments
  (F0-preserved scripts); point output at the standing seam/buoy points (validation);
  retention per the OPERATIONS-MANUAL story (DOC-W.3).
- **WD10 — Run sequence & persisted artifacts.** `ww3_grid` runs ONLY on geometry/config
  change (its product `mod_def.ww3` is versioned and hooked to the existing
  geometry-change detection); per cycle: wind prep → boundary assembly
  (ww3_bound/bounc) → `ww3_shel` march → handoff extraction (`ww3_outp` or spectra
  pull). Every persisted artifact (mod_def, nest, restart, outputs) is named in
  ADR-109's file/dir layout (PW1) with the WW3-leg age/refuse gates (PW5) reading them.

---

## PHASE F — WW3 feasibility build + benchmark — SCRATCH-ONLY, FIRST, no register row needed

**Owner:** a general-purpose Sonnet agent on a written brief (no bespoke agent definition
exists for build/benchmark work; rules/agents.md brief rules apply in full — NOT
`clearskies-api-dev`, whose scope is the api repo). **QC:** adversarial auditor on the
MEASUREMENT METHOD (results-free gate file) before numbers are believed. **Nothing in this
phase touches production paths, services, or repos beyond read-only; all work under
`/tmp/ww3-feas/` on librewxr (toolchain verified present 2026-08-15: gfortran 13.3.0,
OpenMPI, NetCDF C+Fortran, cmake).**

**Host-write authorization (operative at GO of this plan):** Phase F and R4 scratch work on
librewxr — clone, build, and benchmark runs under `/tmp/ww3-feas/` (F), `~/ww3-baselines/`
(F0), and the R4 scratch deck dirs — is an operator-authorized exception to
rules/agents.md's "SSH is read-only" rule, scoped to exactly those directories and tasks;
everything else on the host stays read-only. Written into rules/agents.md permanently
2026-08-15 (Q3(c) approved — the carve-out section there cites this plan).

### F0 — Preserve the baselines FIRST (blocks F1–F4)
The benchmark comparability rule (Named Constants) depends on artifacts that today live
ONLY in `/tmp/e1e2/` on librewxr — and /tmp on that host is already subject to cleanup
(the WW3 source clone was deleted by one, C12). Before anything else: copy the pinned
archived-cycle inputs (decks, `B_*` boundary files, WIND.txt), the cliff-KAT deck (e8b2)
with its edited BOTTOM file and seam-point list, and the energy-ledger scripts to
`~/ww3-baselines/` on librewxr (home directory — survives /tmp cleanups) AND mirror the
set to project `scratch/baselines-e1e2/`. Deliverable: file inventory with sizes +
checksums at both ends. If `/tmp/e1e2` is already gone: STOP — Phase F is blocked on an
operator ruling (the comparability rule cannot be met and the benchmark would be invalid
by the plan's own definition).

### F1 — Build + smoke
Clone NOAA-EMC/WW3 (public, LGPL) to `/tmp/ww3-feas/`; build BOTH F1b physics-candidate
configurations (P1 and P2 switch files — regular-grid, uncoupled, grammar per SYNTAX
row 7); run the smallest shipped regression/test case on each binary. Deliverable: build
logs, both switch files (every token cited per F1b), binary hashes, smoke-run evidence.
Twice-failed build step = STOP and report (no retry loops).

### F1b — WW3 physics configuration: the two candidates (DESIGNED HERE — operator order 2026-08-15)
The WW3 counterpart of the settled SWAN physics line (`GEN3 ST6 … AGROW` +
`SSWELL ZIEGER 0.00025` + `NEGATINP 0.04` — argued over weeks, never defaulted) —
designed in-plan, decided by measurement, frozen in ADR-109:
- **P1 — ST6 (BYDRZ), manual :2522–2800:** the SAME physics family as our SWAN deck
  (Babanin/Young/Donelan/Rogers/Zieger — Zieger and Rogers are authors of both models'
  ST6 implementations); carries the negative-input term our `NEGATINP` maps to (:2673)
  and its own swell dissipation with a published calibration table (:2746–2769).
  Rationale: physics CONSISTENCY across the WW3→SWAN handoff — the deep leg and the
  nearshore legs grow and decay swell in the same family, and our measured ST6 behavior
  (the E-round ~4.6-pt swell-decay share) transfers as prior knowledge.
- **P2 — ST4 (Ardhuin et al. 2010), manual §2.3.10 :2232–2520:** explicit swell
  dissipation built from the Ardhuin et al. (2009a) swell-decay OBSERVATIONS — the
  strongest published pedigree for exactly the deep-water swell-transport job this leg
  exists to do; named default tunings (the TEST471 family, :2381–2412).
- **Namelist tunings: each package's manual defaults, UNTOUCHED in Phase F** (ST6 table
  :2746–2769; ST4 TEST471 defaults :2381–2412). Phase F measures the packages AS
  PUBLISHED — it does not calibrate them; any tuning away from defaults is a
  physics-constant change and an operator ruling (register withheld line).
  **"Defaults" means the 6.07 defaults (2026-08-16, from the Q5 syntax
  re-verification):** 6.07's ST6 Table 2.8 carries a genuine new vers-6.07 default
  column differing from 5.16 (SDSP1 a1 3.74E-7→4.75E-6; SINA0 a0 5.24E-6→7.00E-5;
  β/CSTB1 28.0-hardcoded→32.0-namelist; 6.07 text :3070/:3139) — our 6.07.1 build
  picks these up automatically under the untouched rule; ADR-109 quotes the 6.07
  column, never 5.16-era ST6 numbers. CDFAC=0.09 (the one value F1b names) is
  unchanged at 6.07.
- **Companion tokens (designed now, grammar per SYNTAX row 7):** propagation `PR3 UQ`
  (the third-order, garden-sprinkler-alleviated scheme — the default operational scheme
  per the feasibility report's source read of `w3pro3md.F90`); `LN1` linear input for
  seeding (:14459 example); FLAGTR per SYNTAX rows 6/12 on the obstruction variant
  (no-ice values — SoCal); shallow-water terms (depth-limited breaking, bottom friction)
  at manual defaults and STATED in the deck — near-irrelevant on the deep leg, but
  PRIME DIRECTIVE 11 bans silently-defaulted values.
- **Remaining mandatory switch categories (completed 2026-08-15, final review G17 —
  §5.4.1 :13677–13869 lists the groups, exactly ONE token per group; the manual names
  NO model-wide default, :14041–14045, so every token is stated here):**
  - **Flux:** P1/ST6 pairs **FLX4** — ST6's authors selected and implemented Hwang 2011
    as FLX4, and ST6's own calibration table binds CDFAC as an FLX4 namelist parameter
    (:2652–2662, :2762, :2801–2802). P2/ST4 pairs **FLX0** — the WAM4-family input
    computes stress INSIDE the source terms via its own lookup tables (:2088–2093),
    and FLX0 is defined as exactly that case (:13739).
  - **Stability:** the stabN switches are OPTIONAL, package-bound add-ons (stab2 ↔ ST2
    only; stab3 ↔ ST4 only, :13755–13765). P1 carries none (ST6 has no stab switch);
    P2 runs WITHOUT STAB3 in Phase F (defaults-untouched rule — adding the gustiness
    response later is a physics change, register withheld line).
  - **Nonlinear:** **NL1** (DIA) for both candidates — the exact-interaction NL2/WRT is
    the research-grade tool whose own computation-grid demands (~40 freqs at 1.07,
    :1233–1235) price it out of a per-cycle leg.
  - **Deep-leg shallow/ice/misc groups:** **BT1** (JONSWAP friction) + **DB1**
    (Battjes-Janssen breaking) — the stated-not-silent shallow terms above; **TR0 BS0
    XX0 REF0 IC0 IS0** (no triads, bottom scattering, supplemental terms, reflection,
    or sea ice on a SoCal deep leg — consistent with FLAGTR's no-ice values).
  - **Wind/current interpolation:** **WNT1 WNX1 CRT1 CRX1** (linear — candidates,
    confirmed in F1 against the shipped center example switch files the manual points
    at, :14046–14050).
  - **Build/machine tokens per the F3 budget:** **F90 NOGRB LRB4 NOPA SHRD OMPG OMPX**
    — the manual's pure-OpenMP combination (:13946–13960), honoring
    `OMP_NUM_THREADS ≤ 4`.
- **NOAA's own operational package choice is VERIFIED during F1b from NOAA's own
  documentation** (allowed source, PRIME DIRECTIVE 10) — not asserted here from memory;
  if what NOAA runs contradicts this candidate frame OR any pairing above, STOP and
  surface before F3.
- **How P1-vs-P2 is decided:** F3 runs the physics A/B on the winning grid variant;
  F4.2's rows (>11 s transmission, island refill, corridor survival, the cliff analog)
  against the buoys ARE the discriminators; ADR-109 records the choice with the numbers
  and the operator Accepts it there.
Deliverable: both switch files + namelist sets as reviewable artifacts, every token
cited to a manual line/section (each is also an F5-catalog row).

### F2 — Our-domain configuration (implements §WW3 MODEL DESIGN v1 in scratch form)
Build the WD1–WD10 configuration as scratch artifacts: grid variants G1 (~1 km, resolved
dry-cell islands) and G2 (~3–5 km + generated obstruction grids — the ~3–5 km figure is
a lead-chosen test point inside NOAA's documented 2:1–3:1 hop practice, not a brief-cited
value), extents recomputed from the live sizing per WD1; bathymetry/mask per WD2 (ETOPO
2022 15s, LMSL, ADR-098 discipline); spectral grid per WD3 (exact reconstruction-axes
match); time-step lines per WD4; physics per F1b. Boundary input: our reconstructed
spectra for an ARCHIVED cycle (same cycle as the ledger baselines, from the F0-preserved
pinned copies), assembled per WD7/SYNTAX row 9. Wind: the pinned archived WIND.txt from
that cycle (F0) — NOT the wind-gatherer store, which deletes past hours by design
(`age_out`) and structurally cannot hold an archived cycle. F2 also measures the WD8
spin-up transient (cold start vs lead length) and reports the WD1 intermediate-grid
question with evidence. A WD row F2 cannot satisfy as designed is a STOP-and-surface,
never a scratch improvisation.

### F3 — Benchmark marches
Run the archived cycle through the march ladder: grid A/B (1 km resolved-islands vs
~3–5 km + obstruction) under P1 first — the grid choice — then the P1-vs-P2 physics A/B
on the winning grid; 3–4 marches total. **Binding contention budget (the E1/E2
protocol, now mandatory numbers):** `OMP_NUM_THREADS ≤ 4` (matches the 4-thread scratch
baseline — apples-to-apples), `nice -n 15`, never START a march while a production FULL
run is in flight; overlap that BEGINS after the march starts is tolerated at this
thread/nice budget — including a production FULL run starting mid-march, which at
6-hourly fulls and 50–70-min marches happens roughly one march in five (the E2
precedent is exactly this case: its march overlapped the 06Z FULL production run
without incident, `scratch/NOTES-E1E2-RESULTS.md`; precision fix 2026-08-15, final
review G14);
`/tmp/ww3-feas/` disk ceiling 20 GB, free space verified before clone/build, build
intermediates deleted after F1. Exceeding any bound = STOP and surface. Record wall-clock
per march + peak memory, with the thread count stated on every number.

### F4 — The three verdict measurements (the phase's point)
1. **Cost:** WW3 wall-clock vs the SWAN **L1 march ONLY** — the leg WW3 would replace.
   The baseline is L1's isolated share of a real full run, extracted from the run's
   per-level PRINT timestamps (the A1.1(a) method), stated at its thread count. Known
   anchors: L1 was ~35% of the pre-A1 51-min run (A1.1 row (a)); the big-L1 march measured
   50–70 min in the /tmp/e1e2 scratch runs at 4 threads (the F3 budget matches, so the
   comparison is apples-to-apples). The A1.5 figure of 5280 s is the WHOLE cycle
   (L1+L2+L3+L4+SwellTrack+post) and is NOT the comparison target — the F-REPORT states
   both numbers separately (fix 2026-08-15, adversarial review F1). Hourly cycles do not
   run L1 at all post-A1 (store-driven fills).
2. **Deep-corridor + island physics:** boundary→seam band ledger (Named Constants frame,
   same seam coordinates, same integration scripts, run from scratch copies — committing
   them into the repo as standing instruments happens at DOC-W.4, keeping Phase F pure
   scratch) vs the SWAN L1 numbers AND vs the buoys for the matched window. Explicit rows for:
   >11 s transmission; island-shadow refill in the lee; W-corridor 5–11 s survival (a
   lead-added operational check from the B2/Z3.10 record, not a brief deficit line); and
   the **shelf-break/cliff analog** — the e8-style uniform-boundary KAT (F0-preserved
   deck: same 0.650 m imposed spectrum, same seam sampling) transplanted to both WW3
   variants, WW3's number beside SWAN's 0.578 m — so ADR-109 is written KNOWING whether
   WW3 changes the cliff line at 1 km (the brief documents no WW3 advantage there;
   Option E's cliff cell is empty). The F1b physics A/B (P1 vs P2) is decided by these
   same rows, run under both candidates on the chosen grid.
3. **Handoff fidelity:** spectra at the L2 boundary line from WW3 vs from SWAN-L1 — the
   input L2 would actually receive (feeds the ADR-109 A-vs-B mechanism choice) —
   including SYNTAX row 10's MANDATORY transfer-file compatibility check (one real file:
   our `ww3_outp` writes it, our SWAN `BOUNDNEST3` reads it, end to end) and row 11's
   boundary-only validation run (wind off, no restart — energy enters only at the
   boundary).
Deliverable: F-REPORT with the three measurement sets + build/deck artifacts; every number
traceable to a file.

### F5 — WW3 parameterization catalog (the no-generic-setup deliverable — PRIME DIRECTIVE 11)
The anti-"generic deploy" instrument, ordered by the operator 2026-08-15. Enumerate EVERY
WW3 configuration input across build and runtime: switch-file physics-package selections
(propagation scheme; source-term package; nonlinear, friction, breaking, obstruction
flags — the "plugins"; the P1/P2 candidates are DESIGNED in F1b and this catalog carries
their tokens as rows), `ww3_grid.inp` namelist parameters, grid definition (extent,
resolution, and COUNT — one jump from NOAA's ~16 km output to ~1 km is ~16:1 against
NOAA's own 2:1–3:1 hop practice, so whether an intermediate grid is needed is a catalog
question F2/F3 evidence answers), the four time steps, spectral discretization (must match
the reconstruction axes and L2's ingest), boundary placement + point spacing (the
NOAA-trusted open-water rule — the A1 containment lesson generalized), obstruction-grid
generation, wind regridding, and nest-output point placement (must coincide with L2's
boundary if ADR-109 picks mechanism A). For EACH input, four columns: the governing rule
(WW3-manual section / NOAA practice / F-phase measurement), the site information that
determines it, the derivation formula or criterion, and which existing setup analysis
(ray tracing / fetch fan, bathymetry analysis, OSM chain) supplies that information — or a
named GAP where the setup chain must be extended (**the gap list becomes W4's scope**).
Sources: the WW3 manual (v6.07 per the Q5 ruling — scratch extraction `scratch/ww3-manual-6.07.txt` until DOC-W.4
commits it), NOAA's practice record (feasibility report), F1–F4 hands-on results.
Deliverable: the catalog document — it lands in ADR-109 + PROVIDER-MANUAL at DOC-W, and
every F2 deck line must trace to one of its rows.

### QC GATE F — adversarial, results-free
Auditor receives the METHOD (decks, scripts, comparability rule) without the numbers;
verifies the benchmark meets the Named-Constants comparability rule, the ledger scripts are
the same instruments as the SWAN baselines, and the seam sampling matches. Only then are
numbers opened and the report accepted. Additional row (PRIME DIRECTIVE 11): the F5
catalog is COMPLETE against the manual's own input inventory — the auditor walks the full
`ww3_grid.inp` input list and the switch-file category list; any input without a catalog
row = FAIL — and every F2 deck line traces to a catalog row. Gate FAIL = remeasure (or
re-catalog), not reinterpret.

---

## PHASE DOC-W — ADR-109 + governing docs to target state, BEFORE implementation code

**Owner:** `clearskies-docs-author` (Sonnet), content sourced ONLY from the research brief,
Phase F report, and this plan. **QC:** `clearskies-auditor` at Gate DOC-W. **No Phase W
dispatch until Gate DOC-W passes AND the operator has Accepted ADR-109.**
**This is the PRELIMINARY of the two operator-ordered documentation rounds (2026-08-15):
target-state docs so agents code off the right information. The FINAL as-built round is
PHASE DOC-W-FINAL, after Phase W.**

### DOC-W.1 — ADR-109 (Proposed → operator approval)
The WW3 deep-water leg decision: the always-WW3 assignment (Q1 RULED 2026-08-15 — no
conditionality, no per-site or per-install classifier); WW3 grid/resolution/obstruction
choice per F; handoff mechanism A-vs-B
per F; deck time steps; refuse-gate values; file/dir layout for WW3 artifacts; scheduling
cadence; the per-site shadow-mode mechanism (run-without-serving key, PW5) and the shadow
campaign's compute budget — serial-vs-parallel with the SWAN cycle, thread split, and the
per-cycle wall-clock ceiling, numbers from F3's measurements. **The F5 parameterization
catalog lands in ADR-109 in full: this install's fixed values AND the per-install
derivation rules the setup chain implements (PW2) — including the switch-file/namelist
physics selections, made explicit in the ADR for the PROJECT operator's one-time
approval, never defaults-by-accident, and NEVER product-facing settings (PRIME DIRECTIVE
11: an installing operator picks a location; the code decides the model setup).** Drafted Proposed; operator reviews full content; Accepted before
any W code.
ADR-108 gains a scope note (its L1 architecture remains the LIVE serving path until a
V4 verdict-1 (cutover) ruling, if given — under verdict 2 it keeps serving into Phase
L; NOT superseded by this ADR; any supersession belongs to V5's disposition ruling).

### DOC-W.2 — ARCHITECTURE.md
Target-state passages: the WW3 deep-water leg (always — Q1 ruling) with the live SWAN-L1
transition state named as such, the setup-derivation location (PW2), WW3 process/host
placement, handoff contract, health keys. Known-gaps section lists V-phase items.

### DOC-W.3 — PROVIDER-MANUAL + OPERATIONS-MANUAL + API-MANUAL touchpoints
PROVIDER-MANUAL: WW3-as-our-model section (inputs, boundary reconstruction reuse, cycle
flow). OPERATIONS-MANUAL: build/install story (from F1's proven steps), scheduling,
monitoring keys, refuse semantics, disk/retention for WW3 artifacts. API-MANUAL: any new
health/config surface (PW5). Help-content keys for wizard/admin surface changes (process
rule: same commit).

### DOC-W.4 — Reference docs committed
WW3 manual v6.07 text extraction (Q5 ruling — matches the built 6.07.1 binaries) → `docs/reference/ww3-user-manual-v6.07.txt` — plus `scratch/SYNTAX-607-VERIFICATION.md` committed beside it (the authoritative 6.07 line-cite map for the SYNTAX rows) — with a
provenance header (NOAA-hosted PDF, extraction date/method) + a short
`docs/reference/ww3-commands-extract.md` (frozen, syntax-lookup-only, same convention as
the SWAN extract). CLAUDE.md routing row gains the WW3 manual (SWAN row pattern: local
file authoritative, web-fetching WW3 docs forbidden once committed). **Plus (C12): the
energy-ledger scripts committed to `scripts/analysis/`** with a provenance note tying them
to the Fixit-round baselines, and a one-number self-test (a known baseline input → the
recorded ledger number) so a drifted script is caught at commit time.

### DOC-W.5 — ADR impact sweep (operator order 2026-08-15: "we need to know what ADRs also need amended… or what are completely superseded")
Walk the FULL ADR index — `docs/decisions/INDEX.md` AND `docs/archive/decisions/` — and
give EVERY ADR a disposition: **UNTOUCHED** / **AMEND NOW** (the edit lands this round,
same commit as its INDEX row) / **SUPERSEDED-AT-V5** (tagged now in the ADR's header
notes; the supersession note itself lands in the V5 retirement round — never before,
since the live SWAN-L1 path serves until V4). Provisional table from the lead's
2026-08-15 read of the active series — the sweep VERIFIES, corrects, and completes it:

| ADR | Provisional disposition | What changes |
|---|---|---|
| ADR-100 (geography-aware study area) | AMEND NOW | The geography subsystem gains the WW3 setup derivation as a consumer (F5 gap extensions → W4); its "WaveWatch III boundary sides" language feeds OUR WW3 domain at target state |
| ADR-101 (surf score) | UNTOUCHED (expected) | Downstream of L2; the deep-leg swap is invisible to it |
| ADR-102 (breaking/roller, 1-D) | UNTOUCHED (expected) | 1-D internals; the chain from L2 down is unchanged |
| ADR-103 (spectral boundary) | AMEND NOW + partial SUPERSEDED-AT-V5 | The reconstruction lineage gains the `ww3_bounc` output consumer (PW4); its L1-emission remnant (already superseded-for-L1 by ADR-104's mechanism per its 2026-08-08 amendment) dies fully at V5 |
| ADR-104 (island-aware L1 + per-cell reconstruction) | AMEND NOW + partial SUPERSEDED-AT-V5 | Scope note: its L1-sizing rulings govern the live path until V4/V5; its reconstruction, no-silent-fallback, and whole-service-area rulings CARRY FORWARD into the WW3 leg unchanged |
| ADR-106 (fixit rulings PA1–PA5) | AMEND NOW (PA1 scope note) + PA1 partial SUPERSEDED-AT-V5 | Per-cell spectrum construction feeds both paths; PA1's SWAN-side-interpolation half retires with L1; PA2–PA5 untouched |
| ADR-107 (wind gatherer) | **ACCEPTED 2026-08-15** (operator in chat; C20 resolved) + AMEND NOW | Amendment: the WW3 leg becomes a second consumer of the assembled store (current cycles only — the archived-cycle exception is F0/F2's, documented there). The sweep also physically re-files its INDEX row from the Proposed table to the right Accepted table (the status annotation landed 2026-08-15; the row move did not) |
| ADR-108 (big-L1 non-stationary) | Scope note per DOC-W.1 | SUPERSEDED-AT-V5 only via the disposition ruling — not before |
| Remaining active series walk (ADR-093/095/096/097/098/099 + the consolidated set — label corrected 2026-08-15: all six live in ACTIVE `docs/decisions/`, not the archive; the archive is walked too per the task text) | Sweep verifies each; **the sweep also REPAIRS the INDEX itself** — verified 2026-08-15: ADR-079, ADR-092, and ADR-098 appear in NO INDEX table at all (an index-driven walk would never visit them — Gate DOC-W's completeness row keys off the index, so index gaps are FAIL-class), and ADR-099's file says Accepted (2026-07-26) while the INDEX still lists it under Proposed | Known candidates: ADR-093 (the nest parent — L1's role transitions), ADR-098 (datum match-at-source — BINDS the WW3 bathymetry too; ADR-109 must cite it; its own status line still reads Proposed — the sweep surfaces its status to the operator), ADR-099/add-on invariant (W5 cites it, unchanged) |

### QC GATE DOC-W — adversarial
Rows: ADR-109 internal consistency (every constant sourced to F evidence or named as
operator-set); ARCHITECTURE/manual passages match the ADR; no doc invents numbers Phase F
didn't measure; CLAUDE.md routing updated; ledger scripts present in `scripts/analysis/`
and their self-test reproduces the recorded baseline number; DOC-W.5 sweep COMPLETE — the
auditor re-walks the FULL index (active + archive), any marine-relevant ADR without a
disposition = FAIL, and every AMEND-NOW is verified landed with its INDEX row;
plain-language standard met.

---

## PHASE W — WW3 deep-water leg implementation (all sites — Q1 ruled ALWAYS; shadow until V4)

**Owner:** `clearskies-api-dev` (Sonnet; marine repo). **Tests:** `clearskies-test-author`.
**QC:** `clearskies-auditor` per task round + lead gate. All code in
`repos/weewx-clearskies-marine/`. **Each task below carries a BINDING indicative Files
list** (fix 2026-08-15, adversarial review F6 — the Fixit convention names files in the
plan, not at dispatch). Dispatch-time briefs may NARROW a task's list; any file BEYOND
it — and ANY file on a frozen-core list, always — returns to the operator before dispatch.
**Design lives in THIS plan (PRIME DIRECTIVE 12):** after ADR-109 is Accepted and before
ANY W task dispatches, the lead authors **W DESIGN v1** into this plan as an amendment
block — per-task designs (mechanisms, data flow, decision trees, acceptance numbers)
sourced from ADR-109 + the F-REPORT — operator-visible in the plan, the A1-DESIGN-v1
convention. W DESIGN v1 REFINES §WW3 MODEL DESIGN v1 to its ADR-109-frozen values; it
does not re-open WD rows. The task blocks below fix scope and acceptance; W DESIGN v1 fixes WHAT gets
built; agents implement it verbatim and surface deviations as findings.

### W DESIGN v1 — per-task designs, frozen to ADR-109 (lead-authored amendment, 2026-08-17, post-Gate-DOC-W)

*(Authored after ADR-109 acceptance (2026-08-17, all rows as recommended) and Gate
DOC-W PASS, per PRIME DIRECTIVE 12. REFINES §WW3 MODEL DESIGN v1 to the ADR-109-frozen
values; re-opens no WD row. Every value below cites ADR-109 (D-rows, D13 catalog,
traps 1–23) or a Phase F/buoy-validation measurement. An agent hitting a value this
section does not fix STOPS and surfaces — it never picks.)*

**Frozen inputs (ADR-109, for reference throughout):** G1 grid only, no intermediate
grid (D3a); P1 = ST6/FLX4 (D4); `ww3_bound` ASCII assembly (D5); BOUNDNEST3 ingestion
(D6); `ww3_prep` wind path (D7); D8's spectral grid `1.1086 0.030 35 72 0.` and G1
time-step line `100 33 50 10`; wind-only forcing (D9); restart-chaining (D10);
`WW3_RESTART_MAX_AGE_H = 9` (D11); `level0/` layout, 6-hourly full-run cadence, serial
execution at `OMP_NUM_THREADS ≤ 4` nice 15 (D12).

**W1-DESIGN — `services/ww3_runner.py`.** Single responsibility: orchestrate one WW3-leg
run as a step sequence, refuse loudly on any failure. (a) **Binary management:** binary
dir + expected sha256 pins come from config (values recorded at deploy from the
OPERATIONS-MANUAL build story); before any step the runner verifies every needed binary
exists and hashes match — mismatch/missing = refuse `ww3_binaries_invalid`, no
degrade-to-skip. (b) **Step sequence (WD10):** `ww3_grid` is NOT a per-cycle step (runs
only on geometry change — W4/W5 wire the hook); per cycle: wind-prep (`ww3_prep`) →
boundary assembly (`ww3_bound`) → march (`ww3_shel`) → handoff extraction (`ww3_outp`).
(c) **Invocation hygiene (traps 12/13):** every `ww3_*` binary runs in a FRESH throwaway
working directory assembled per step (symlink/copy in `mod_def.ww3` + inputs, harvest
outputs, delete); `ww3_outp`'s deck is literally named `ww3_outp.inp` in that CWD, no
stdin redirect. (d) **Environment:** `OMP_NUM_THREADS` from config capped at 4, `nice 15`
— the runner sets both itself; it never inherits an uncapped environment. (e) **Per-step
timeouts (lead-derived ceilings from D12 measurements, stated here so agents don't
invent):** march 180 min (≈2.3× the worst measured production-shaped 24 h march,
78.4 min, F4b/buoy runs 69.7–75.2 min); each of prep/bound/outp 10 min (all measured in
the seconds-to-minute class in Phase F). Timeout = kill process tree, refuse
`ww3_step_timeout:<step>`. (f) **Refusal contract:** any step rc≠0, timeout, or missing
expected output artifact refuses the WHOLE leg cycle with a named reason; partial
artifacts are deleted, never left where a later step or reader could mistake them for
complete (PRIME DIRECTIVE 8). Log lines carry the step, rc, wall-clock, artifact sizes.
**Acceptance (task row unchanged):** command-assembly KATs pin exact argv/CWD/env per
step against a fixture config; failure-injection proves refuse-not-degrade for each of:
nonzero rc, timeout, missing output, hash mismatch.

**W2-DESIGN — WW3-input emitter (PW4): `services/ww3_formats.py` (writer) + the output
path in `services/boundary_reconstruction.py`.** Spectral CONSTRUCTION is untouched
(Named Constants); this adds serialization only. (a) **Format (SYNTAX row 10, proven by
F2c + the buoy round):** ww3_outp ASCII transfer format; ONE file per geographic
boundary position (trap 15); every file ≥2 time records bracketing the run window
(trap 22 — single-record self-disarm); spectrum block written FREQUENCY-FASTEST —
`for ith in dirs: for ik in freqs:` emission order matching Fortran `SPEC2D(NK1,NTH1)`
column-major (trap 21; the corrected `gen_boundary_buoy_val.py` on librewxr is the
proven reference implementation, read-only). (b) **Axes:** exactly WD3/D8 —
35 freqs from 0.03 Hz factor 1.1086, 72 directions/5°; directions converted
nautical-FROM-degrees → oceanographic-TO-radians via `rad = radians((deg_from + 180)
mod 360)` (trap 17); all files share this ONE spectral grid (row 9 hard constraint,
source-enforced via XFR check, trap 8). (c) **Data flow:** per-wet-cell partition sets
(existing ADR-104/106 reconstruction) → E(f,θ) on WD3 axes → one transfer file per G1
boundary position (S-row + W-column wet perimeter cells, D13 Group 2) → `ww3_bound`
WRITE mode, interpolation method **2 (linear)** per the proven F2c deck → `nest.ww3`.
*(Corrected 2026-08-17 mid-W2: the lead's original text here said "nearest-neighbor" —
a transcription error conflating this flag with D9's wind-regrid resample. The W2
implementing agent STOPped on the contradiction; verified against
REFERENCE-gen_boundary_buoy_val.py, F4-REPORT §linear-branch trace
(`ww3_bound.ftn:479`), and SYNTAX-607-VERIFICATION's digit-for-digit manual-example
match — all three agree on method 2. The design's own cited authority, "the proven
F2c deck," always meant this value.)*
(d) `ww3_bound`'s spectra-file list closes with the literal `'STOPSTRING'` (trap 6).
**Acceptance (task row unchanged, plus):** the round-trip KAT's known-answer set
includes a deliberately direction-fastest (transposed) control that must FAIL the
known-answer comparison — the KAT is falsifiable against the exact defect class that
voided F4b (rules/verification.md known-answer mandate); bin-sum identity ≤ 5%.

**W3-DESIGN — WW3→SWAN L2 handoff (PW3): `services/swan_formats.py` L2
boundary-source block + `services/swan_runner.py` call site.** (a) **Grammar (SYNTAX
row 4):** `BOUNDNEST3 WW3 'fname' FREE CLOSED [xgc] [ygc]` — FREE because `ww3_outp`
writes formatted output (the unformatted flag and SWAN keyword MUST agree, row 10
pairing); `[xgc]/[ygc]` are MANDATORY (L2 is Cartesian): the L2 grid's SW corner in
geographic degrees, longitude then latitude (row 4's misprint trap), sourced from the
live sizing json — never retyped. CGRID precedes the command (row 4). (b) **Point
placement contract with W2/W4:** WW3 output points are written IN SEQUENCE along the
nest boundary; consecutive-point spacing must respect SWAN's 0.1×-spacing acceptance
window (row 4 trap — sloppy placement silently starves boundary segments), and ≥2
boundary points always (F4.3's measured SWAN floor). (c) **Shadow discipline:** the
BOUNDNEST3-emitting path exists behind the shadow artifacts only — the LIVE L2 deck
emission is untouched this phase; the serving flip that would make L2 consume WW3
output in production is DESIGNED (a single boundary-source selector in
`swan_formats.py` with the live path as default) but NOT BUILT-INTO-SERVING until a V4
verdict-1 ruling (W5 note below). **Acceptance (task row unchanged):** handoff
round-trip KAT with a known spectrum (energy at L2 boundary within a stated tolerance
the implementer computes from the KAT construction, not invents); live L2–L4 decks
byte-identical (KAT-pinned).

**W4-DESIGN — setup derivation (PW2) + depth-step detection (PW6):
`services/swan_domain.py` + `services/grid_sizing_chain.py`.** All derivation is
config-time, regional-input-only, logged-with-provenance. (a) **Derivations (each a
D13 catalog rule):** G1 extent = the `level1` block of `swan_grid_sizing.json` read
live (D3/WD1); resolution = L1's existing `resolution_m` (~1 km); NX/NY from
extent/resolution; time-step line via D8's formula (`critical_xy = 33.4 s ×
min_cell_km`; `global = 3×critical`; `k-theta = global/2`; source floor 10) — for G1
today that reproduces `100 33 50 10` exactly, and the formula (not the constants) is
what's implemented; spectral line fixed `1.1086 0.030 35 72 0.`; `FLAGTR = 0` (G1
resolved-dry-cell islands); boundary marking = status 2 on wet S-row + W-column
perimeter cells only (Q4: east is land), status-map segment block closed by the
mandatory `0 0 F` (row 6a); output-boundary-points section always `0. 0. 0. 0.  0`
(trap 3); model-flags line `F T T T F T` space-separated (trap 1). (b) **Gap closures
assigned here (ADR-109 GAP SUMMARY):** G2 — the bottom-read line's limiting-depth and
minimum-water-depth values are STATED in the emitted deck from the F2 as-built deck
values, with a derivation comment (never a silent default); G1(gap) — the PR3/UQ
namelist question is resolved as "6.07 defaults, deliberately untouched" and logged as
such (a considered choice, recorded, mirroring the ST6 rule); G8 — the REAL L2
boundary/seam point list is derived from the live L2 grid geometry (the handoff points
W3 consumes), replacing F-phase placeholders. (c) **Depth-step detection (PW6,
DETECTION ONLY):** the per-cell depth-change-ratio diagnostic computed over the G1
bathymetry at config time, logged with the cells and ratios — feeds nothing yet; the
live L1→L2 seam does NOT move (WITHHELD, V2 decides). (d) **Bathymetry:** ETOPO 2022
15s LMSL, same source+datum as L1 (ADR-098 discipline, D14 item 3); depth scale factor
1.0 with the sign-KAT from F2 §3 re-run as a unit test (trap 14). **Acceptance:** as
the task row states (two hand-derived fixtures, step-detection KAT, no-silent-default
test, live-path deck diff EMPTY).

**W5-DESIGN — scheduling + health + config (PW5): `service.py`, `state.py`,
`endpoints/health.py`, `config/marine_config.py` (+ API pass-through files named at
dispatch).** (a) **Cadence & ordering:** the WW3 shadow leg runs on the 6-hourly FULL
cycle only, STARTING AFTER the production SWAN full run has published (serial, never
concurrent — D12's contention protocol; the shadow leg must never delay serving).
(b) **Restart chaining mechanics (D10 + trap 23):** each leg run writes its restart
stamped at the NEXT cycle's exact start time (WW3 rejects any timestamp mismatch,
`w3iorsmd.ftn` EXTCDE(20), no fallback); the runner consumes the newest restart whose
stamp equals the current cycle start. (c) **Staleness gate:** `ww3RestartAge` computed
from the consumed restart's cycle stamp (not file mtime — mtime lies after copies);
age > `WW3_RESTART_MAX_AGE_H = 9` → the leg REFUSES the cycle (C14 semantics: no
publish of leg artifacts, health red with named reason `ww3_restart_stale`); a missing
restart entirely = cold-start is NOT silently substituted — refuse
`ww3_restart_missing` and surface (the buoy round measured a 24 h cold start 34–38%
low; a silent cold start would serve exactly the deficit this plan exists to kill).
Recovery from a missing/stale restart is an operator-visible action (documented in
OPERATIONS-MANUAL at DOC-W-FINAL): a deliberate spin-up run, not an automatic fallback.
(d) **Wind production path (Gap G7, closed here):** per cycle, read the assembled wind
store (ADR-107's second consumer — current cycles only), regrid nearest-neighbor onto
G1's exact NX×NY (trap 16: dimensions must match exactly), emit via row 6c's `ww3_prep`
deck grammar (two format strings, `FROM='NAME'`, trap 5). (e) **Config:**
`ww3_shadow_mode_enabled` per-site boolean through the existing config-push — the SOLE
writable key; everything else read-only display via the API pass-through (§19.7a as
documented at DOC-W.3). (f) **Health:** leg status block — last cycle result, named
refuse reason (slug convention), `ww3RestartAge`, last march wall-clock vs the 180-min
ceiling, artifact sizes. (g) **Cutover-only piece:** the serving flip (L2 consuming WW3
via W3's selector) is DESIGNED here — flip = one config-side switch changing the L2
boundary source, gated on a V4 verdict-1 operator ruling — and explicitly NOT BUILT.
**Acceptance:** as the task row (health-key KATs, frozen-clock age-gate KAT at the
exact 9 h boundary, wizard round-trip), plus a restart-timestamp KAT: a restart
stamped ≠ cycle start must be refused, not consumed.

**W6-DESIGN — test consolidation.** Full-chain fixture test: fixture partitions → W2
files → real `ww3_bound` → (mocked-or-real per test tier) march artifacts → W3 deck
emission → assertions on each seam; stale-test sweep greps for "L1 is the only
deep-water model"-class pins across the suite. No new design surface.

**Cross-cutting rows binding every W task:** every emitted deck line traces to a D13
catalog row (PRIME DIRECTIVE 11 — Gate W checks line-by-line); a construct not in
SYNTAX PRESCRIPTIONS is a STOP; live serving path byte-identical throughout (Gate W
standing row); doc-sync in the same round for any behavior the manuals describe;
LUT-era note (session-4 operator direction): W1's runner keeps march invocation
callable for an arbitrary window/config independent of cycle scheduling — Phase L's
correction-model runs will reuse it unchanged; this costs nothing now and is a design
constraint, not new scope.

### W1 — WW3 runner service module
**Files:** NEW `services/ww3_runner.py` (+ its test file). Wiring into the cycle is W5's
job, not W1's.
Build-artifact management (binary location, version pinning per OPERATIONS-MANUAL story),
process orchestration for grid-prep + march + post-processor steps, timeout, loud failure
(refusal semantics identical in spirit to SWAN cycle refusals — a failed WW3 leg NEVER
degrades to a silently-stale or fabricated boundary). Acceptance: KATs for
command-assembly; a failure-injection test proving refuse-not-degrade.

### W2 — Boundary reconstruction → WW3 input emitter (PW4)
**Files:** `services/boundary_reconstruction.py` (WW3-output emitter path only) and, if a
standalone writer is cleaner, NEW `services/ww3_formats.py` — both named here so the
opening is operator-visible; spectral-construction code stays untouched.
The existing per-cell parametric spectra gain a WW3-consumable output path (point
spectra ready for the boundary-assembly program ADR-109 picked — ww3_bound or
ww3_bounc, SYNTAX row 9; the emitter's format follows that pick, never pre-decides
it). Spectral construction constants untouched (Named Constants). Acceptance:
round-trip KAT — a known cell partition set → emitted file → ingest by the
ADR-109-picked assembly program succeeds; bin-sum identity preserved.

### W3 — WW3→SWAN L2 handoff (PW3, mechanism per ADR-109)
**Files:** `services/swan_formats.py` (L2 deck boundary-source block ONLY) +
`services/swan_runner.py` (handoff call site).
Produce L2's boundary from WW3 output (all sites at target state; shadow-only until a
V4 verdict-1 ruling, if given); L2 deck emission gains the mechanism (BOUNDNEST3 line OR spectra-file
BOUNDSPEC per ADR-109). Acceptance: handoff round-trip KAT with a known spectrum (energy
in = energy at L2 boundary within stated tolerance); L2–L4 decks otherwise byte-identical
to the live path (KAT pins this).

### W4 — WW3 setup derivation in grid-sizing (PW2, Q1 ruled ALWAYS) + depth-step detection (PW6 — diagnostics; live-seam relocation WITHHELD)
**Files:** `services/swan_domain.py` + `services/grid_sizing_chain.py` (derivation +
detection + decision logging); the setup-analysis extensions from F5's gap list (ray
tracing / bathymetry analysis), named at dispatch under the beyond-list rule.
The setup chain DERIVES the WW3 leg's configuration mechanically at config time per the
F5 catalog rules with ADR-109 values: grid extent/resolution/count, boundary placement in
NOAA-trusted open water, the four time steps, obstruction inputs. Every derived value is
logged with the site inputs that produced it — no silent defaults (PRIME DIRECTIVE 11).
The offshore-domain inputs (extent, islands-inside, depth steps) are REGIONAL — the
spot's local features (piers, break type) belong to L3/L4 and never enter this
derivation. The depth-step DETECTION rule lands here as a standing logged diagnostic and
a grid-sizing input; the live SWAN-L1 seam does NOT move in this phase or any other
without a NEW operator ruling (PW6: relocation WITHHELD pending V2's verdict — moot for
this install if V5 rules retirement).
Acceptance: derivation KATs — the Bight-domain fixture (islands inside the computed
offshore domain) and a clean-offshore fixture each produce the hand-derived expected
grid/boundary/time-step set (expected values hand-computed from catalog rules,
falsifiable); step-detection KAT against the known shelf-break profile; a
no-silent-default test (every derived value logged with provenance); live-path deck diff
EMPTY this round (consistency with Gate W's byte-identical row).

### W5 — Scheduling + health + config surface (PW5)
**Files:** `service.py` (cycle integration), `state.py`, `endpoints/health.py`,
`config/marine_config.py`; the API-repo pass-through endpoint files (marine add-on
invariant) named at dispatch under the same beyond-list rule.
Cycle integration (full-run cadence for the WW3 leg, nest-age key + refuse gate at the
ADR-109 value), config keys incl. the per-site shadow-mode key, wizard/admin install-state
surface via the API pass-through (marine add-on invariant — everything through the API).
**Durable vs cutover-only (amended 2026-08-15):** everything above is DURABLE — needed
for shadow runs and for the LUT-precompute role alike. The one CUTOVER-ONLY piece — the
serving flip that makes the published forecast come from the WW3 chain — is designed in
W DESIGN v1 but NOT BUILT in this phase; it is built only if V4 rules cutover (verdict 1).
Acceptance: health-key KATs; age-gate frozen-clock KAT (the A1.4 pattern — archived Fixit
plan task A1.4: pin the clock inside the test so the exact age boundary is deterministic,
not wall-clock-racy); wizard apply round-trip per the process rule's Pydantic-contract
check.

### W6 — Test consolidation round (test-author)
**Files:** test files only.
Cross-task suite: the full WW3-leg chain on fixtures end-to-end; stale-test sweep
(anything pinning "L1 is the only deep-water model" updates IN the behavior commits, per
directive 5 — this round verifies none were missed).

### W-Accept (live, librewxr — deploy per PRIME DIRECTIVE 2/3/4)
Deployed with the WW3 leg's SERVING effect CONFIGURED OFF everywhere; the per-site
shadow-mode key (PW5/ADR-109 — run-without-serving) is ON for this install's test site, so
the WW3 leg runs and stores artifacts while the live SWAN-L1 path serves untouched.
Reality gate rows: shadow-run liveness; artifact sanity vs F-phase numbers; zero impact on
the served path (baseline/diff); shadow compute inside ADR-109's budget (per-cycle
wall-clock recorded).
**Serving cutover is NOT this phase** — that is V4, an operator ruling.

### QC GATE W — adversarial, per round + phase-close sweep
Standing rows: no physics constants changed anywhere; the LIVE SWAN-L1 serving path
byte-identical until a V4 verdict-1 (cutover) ruling, if given (deck diffs empty —
under verdict 2 this row holds indefinitely); every WW3 deck line traces
to an F5-catalog row (PRIME DIRECTIVE 11); refuse-not-degrade proven; doc-code sync
(manuals updated in the same rounds); no forbidden syntax emitted.

---

## PHASE DOC-W-FINAL — as-built documentation round AFTER Phase W (the FINAL of the two operator-ordered doc rounds)

**Owner:** `clearskies-docs-author`. **QC:** `clearskies-auditor` at Gate DOC-W-FINAL.
**Runs after W-Accept passes; V4 does not convene without this gate's PASS. V1–V3 MAY
run concurrently with this phase** — the shadow campaign accumulates calendar time and
touches no documents, so it starts at W-Accept; only V4 waits for this gate (ambiguity
resolved 2026-08-15, final review G16, per this gate's own only-V4-blocks text). (Operator
order 2026-08-15: "a preliminary round to update architecture and manuals so the agents
are coding off the right information, and then a final update based upon tweaks and
changes that happened during the coding process" — the A1.0/A1.6 docs-first/docs-final
convention, made plan-wide.)

### DOC-W-FINAL.1 — As-built re-sync
Every DOC-W document re-synced to AS-BUILT: read the LIVE decks, artifacts, config keys,
and health surface on librewxr — never the repo's intent (the Gate DOC-A1-FINAL lesson).
ADR-109's acceptance-criteria checkboxes checked with evidence citations; every W-round
deviation, lead ruling, or mid-round tweak folded into ARCHITECTURE / PROVIDER-MANUAL /
OPERATIONS-MANUAL / API-MANUAL; the DOC-W.5 ADR dispositions re-checked against as-built
(a W-phase tweak can change a disposition); W DESIGN v1 annotated with as-built deltas;
CLAUDE.md routing verified current.

### QC GATE DOC-W-FINAL — adversarial
Zero-drift verdict: every behavior-governing number and mechanism in the DOC-W documents
independently re-derived from the live system and matched (the Gate DOC-A1-FINAL
convention). FAIL = remediate and re-verify; V4 stays blocked until PASS.

---

## PHASE V — validation against reality + disposition ruling

**Owner:** the lead — who also authors Gate V's results-free definition file BEFORE the
campaign's first cycle (named author, fix 2026-08-15 final review G12); V1–V3
measurement/analysis tasks run on general-purpose Sonnet agents per written brief;
`clearskies-auditor` holds Gate V; the operator holds every ruling row. This phase
is the operator's "plenty of testing and tweaking" gate — nothing later starts until V4.

### V1 — Shadow-run campaign
≥ 10 consecutive WW3-leg cycles (at the ADR-109 cadence — full-run cadence per W5;
including at least one long-period event ≥ 14 s if the window provides one; if not, the
campaign extends — event coverage is a named requirement, not best-effort) with the WW3
leg in shadow at this install's test site. Per cycle: band ledger boundary→L2-handoff for BOTH
paths + matched-time buoy rows. Comparison quantities and tolerances for every V1–V3 row
are DECLARED in a results-free gate file BEFORE the campaign's first cycle (Gate V).

### V2 — The three deficit lines, measured
Against the research brief's budget: island-shadow refill, shelf-break/cliff KAT number
(measured HERE — PW6 authorized detection + WW3-handoff placement; V2's number is the
evidence for any operator ruling on the WITHHELD live-seam relocation), deep-corridor
transmission. Each line: SWAN-L1 vs WW3-leg vs buoy truth.

### V3 — Served-quality comparison + carry-over eyeballs
Side-by-side served-payload simulation from the shadow leg vs live payloads vs
buoys/LOTUS/Surfline for matched times (the C7 apples-to-apples, systematized). The
C1–C4 eyeball re-accepts are UNBLOCKED already (carry-over register) and may close any
time the operator chooses; V3 is their consolidated round AT THE LATEST (cards + cam +
knob drill in one sitting).

### QC GATE V — adversarial, results-free (before any V4 evidence pack)
The V-campaign's METHOD is audited exactly as Phase F's is: BEFORE the first campaign
cycle, the per-row comparison quantities and tolerances for V1–V3 are written into a
results-free gate-definition file (the A1.5 / `A15-PREDECLARED-ONLY.md` convention); the
auditor — never shown any campaign numbers — verifies the method (matched-time
discipline, same ledger instruments as Phase F, Named-Constants band/seam frames, buoy
selection stated with its caveats) and the tolerances' provenance. Only after method-PASS
are campaign numbers read against the declared rows. Gate FAIL = re-declare and
re-measure, not reinterpret. The V4 evidence pack carries this gate's record; V4 does not
convene without it. (Added 2026-08-15, adversarial review F4 — the decisive evidence phase
had no gate while the lower-stakes Phase F benchmark had one.)

### V4 — DISPOSITION RULING (operator; amended 2026-08-15 — cutover is no longer forced)
Evidence pack: V1–V3 tables + cost/wall-clock + failure-mode inventory from shadow
campaign + the Gate V record + the Gate DOC-W-FINAL PASS record (V4 does not convene
without it). The operator rules ONE of THREE verdicts:
1. **Cut over** — the install switches to the WW3 leg, ALL its sites at once (mixing
   deep-water implementations within one install is ruled out — Q1; then V5 runs);
2. **Hold shadow + open Phase L** — the site keeps serving as it does today, the WW3 leg
   stays validated-in-shadow as the LUT's precompute engine, and Phase L's design round
   opens now (the "accurate and defensible" ruling is satisfied by THIS evidence pack —
   no production switchover required first);
3. **Extend the campaign** (or adjust — each adjustment cycles through DOC-W amendment
   if architectural).
No cutover and no Phase L without this ruling. (Q1 was RULED — always — 2026-08-15; V4
does not re-open it. Why the amendment: as first written, the plan FORCED verdict 1
before Phase L could open — building the production switchover just to tear it out if
the LUT replaces per-cycle serving. Operator caught it 2026-08-15: "if we end up
retooling everything with LUTs, then the whole slow/fast kind of goes away.")

### V5 — Post-cutover watch + decommission ruling (operator) — CUTOVER BRANCH ONLY (V4 verdict 1)
Runs only if V4 ruled cutover; on verdict 2 this task is skipped and the SWAN system
keeps serving until the LUT replaces serving (its retirement then belongs to Phase L's
own plan rows). ≥ 7 days watched (monitors + daily ledger row). Then the operator rules on the SWAN
deep-water leg's disposition (keep as fallback / retire). Under the Q1 always-ruling the
retirement track is PRODUCT-WIDE — no site class remains for the SWAN-L1 deep leg — so
retirement, if ruled, covers the L1 march machinery, its per-wet-cell boundary feed, and
`l1NestAge`, as its own round with ADR-108 supersession notes — not implied by cutover.

---

## PHASE R — strengthening fixes from the research brief (independent tracks)

**Owners (fix 2026-08-15, final review G12 — the Fixit bar names owners per phase):**
R2.1 runs on a general-purpose Sonnet agent (read-only brief); its Gate R2.1 auditor is
`clearskies-auditor`. R2.2, if ruled: `clearskies-api-dev` implements,
`clearskies-test-author` owns tests, `clearskies-auditor` holds Gate R2. R4:
general-purpose Sonnet agent on a scratch brief; lead reviews. R1 has no tasks of its
own (W4/V2 own its work under their owners).

### R1 — Handoff placement off the shelf break (PW6) — REQUIRES Phase W machinery
Covered inside W4 (implementation) + V2 (measurement). Listed here so the brief's
R1-question lineage is traceable: the research verdict was "seam relocation unproven as a
fix" — this plan implements DETECTION + placement preference and lets V2's cliff-KAT
number deliver the verdict empirically. Whatever V2 shows is recorded in the brief's §9
as the answer. Any relocation of the LIVE SWAN-L1 seam is WITHHELD (PW6) — if V2's
number supports it, it returns to the operator and enters by amendment with its own task
row, gate, and separate deploy.

### R2 — Fed E-side boundary (PW7)
R2.1 (read-only, UNBLOCKED AT GO): re-derive the unfed-E census at the corrected time
index; deliver the real bound with the corrected arithmetic shown. **QC Gate R2.1
(adversarial, results-free — added 2026-08-15, final review G5):** BEFORE the bound
goes to the operator for the PW7 ruling, an auditor independently recomputes it from
the raw boundary files at the corrected index — never shown R2.1's number — and the
two derivations must agree; the original census failed on exactly this arithmetic
(C5), and PW7's ruling rests on this one number. R2.2 (ONLY on the
operator's explicit materiality ruling over R2.1's bound — PW7, no numeric default): docs
first (PROVIDER-MANUAL/ARCHITECTURE passages to target state, tagged); E-side feeding via
the existing mechanism; ledger before/after; KATs. R2.1's number decides — no fix on a
stale bound. R2.2's design block lands in THIS plan (amendment, PRIME DIRECTIVE 12) after
the ruling and before dispatch. **QC Gate R2 (adversarial):** ledger before/after re-derived by the auditor
from raw files (the Gate-B2 row-6 convention); KAT falsifiability reproduced; deck diff
confined to the E-side BOUNDSPEC block; doc tags lifted at deploy. **R2-Accept (live,
deploy alone):** reality gate per PRIME DIRECTIVE 4 with quantities pre-picked;
baseline/diff per PRIME DIRECTIVE 2.

### R3 — ~~Problem-2: served multiSwell selection~~ DROPPED 2026-08-15 (operator ruling)
Dropped in chat: "drop it, it is not an issue right now I want to deal with." The item
rested on a prior session's single-day observation (2026-08-14, recorded in
`scratch/P2-CONFIRMATION-PROTOCOL.md`, "draft for operator review") that was never put
before the operator — a premise failure, not an evidence-based deprioritization. No R3
work of any kind runs. If the symptom class is real, V3's served-quality comparison
(served output vs buoys, matched times, systematized) is the instrument that will surface
it WITH evidence, and any resulting work enters this plan as a new operator-ruled
amendment. Q2 is VOID with this drop; PW8 carries the dropped marker.

### R4 — Evidence-gated numerics experiments (scratch-only, opportunistic)
The refraction-rate limiter (CTHETA/CSIGMA) A/B on the NEW architecture's SWAN legs —
scratch decks only, ledger-measured, operator-informed. Production adoption would be a
formula-adjacent numerics change = operator ruling with the experiment as evidence. Low
priority; runs only when idle capacity exists.

---

## PHASE L — hybrid LUT system — LAST, gated on the operator's defensibility ruling (cutover NOT required — amended 2026-08-15)

**Opens ONLY after:** the operator states the modeling system's results are "accurate and
defensible" (their words — an explicit ruling row, not an inference). That ruling can be
given at V4 on the shadow-campaign evidence alone (V4 verdict 2) — a production cutover
is NOT a prerequisite. On the verdict-1 (cutover) branch the ruling has no fixed slot
and cutover alone is NOT the ruling: the operator may say the words at V4, after V5's
7-day watch, or later — Phase L waits for the words either way (added 2026-08-15,
final review G8). PW9: nothing here is pre-approved.

### L0 — Design round + ADR-110 (Proposed → operator)

**GOVERNING RESEARCH BRIEF (operator-ordered tie, 2026-08-17):**
[docs/reference/LUT-INTEGRATION-RESEARCH-2026-08-17.md](../reference/LUT-INTEGRATION-RESEARCH-2026-08-17.md)
— the comprehensive LUT integration research conducted 2026-08-17. This brief is the
MANDATORY starting point for Phase L. It covers: the per-model LUT analysis (what gets
precomputed, what keeps running, what the build method is for each), the CDIP/O'Reilly-Guza
backward ray tracing precedent (swell), Kudryavtsev characteristic-form integration
(wind-sea), Dutch WTM methodology (nearshore with breaking), precomputation cost analysis,
GPU acceleration options, the boundary monitor + correction run design (out-of-range input
handling), Great Lakes multi-point fetch research, and all open ADR-110 design questions
with their options and dependencies. **Read this brief in full before drafting ADR-110.**

**Operator direction (2026-08-17):** Get the complete model chain running and validated
against buoys FIRST. The LUT converts a PROVEN model chain, not an unvalidated one.
Phase L opens only after Phase V confirms the end-to-end chain (WW3 → SWAN L2 →
SWAN L3/L4 → SurfBeat) matches real buoy observations.

**Scope from the research brief (supersedes the prior lead-recollection list):**
- **Swell transfer:** backward ray tracing transfer coefficients (CDIP/O'Reilly-Guza,
  WaveRay open-source tool). Precomputed once per geometry.
- **Wind-sea:** Kudryavtsev characteristic-form ray integration to build a wind-sea LUT
  indexed by (wind speed, wind direction) with precomputed fetch. Parametric JONSWAP for
  SoCal; Kudryavtsev for Great Lakes long-fetch installations.
- **Nearshore (L2/L3/L4):** precomputed Wave Transformation Matrix (Dutch WTM approach) —
  stationary SWAN or SnapWave runs for a condition matrix (Hs, Tp, direction, water level).
  Per-spot grids.
- **SurfBeat:** keeps running per-cycle (seconds, nonlinear physics, no proven LUT method).
- **Boundary monitor:** per-cycle bounds check; out-of-range inputs trigger a correction
  model run that extends the LUT (refuse-not-extrapolate).
- **Lifecycle:** invalidation hooked to the existing geometry-change detection; LUT extends
  over time as correction runs cover the site's full observed climate.
- **GPU:** prototype on CPU first; add GPU if precomputation cost warrants it (backward ray
  tracing is an ideal GPU workload; librewxr has an RTX A400).

The design round produces ADR-110 with the LUT build/rebuild cost model measured
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
  misstatement; missing Phase-T carry-over; full-run/hourly runtime mislabel).
- **FULL replacement adversarial review COMPLETED 2026-08-15** (operator-ordered; report:
  `scratch/PLAN-CRITIC-REPORT.md`). It verified the five prior fixes (2 clean, 3
  partial/defective) and delivered 14 findings (F1–F14), among them: the F4.1 cost
  yardstick conflated the whole-cycle 5280 s with the L1 march WW3 replaces (fixed); the
  benchmark baselines + cliff-KAT deck lived unpreserved in /tmp (→ new task F0); PW6
  pre-approved the unproven live-seam relocation (→ WITHHELD); Phase V had no gate
  (→ Gate V); carry-over gaps (→ C14–C19); Phase-W Files lists restored; host-write
  carve-out made explicit (→ Q3(c)); L0's scope provenance corrected. **Operator ruling:
  "proceed with all fixes" — all 14 applied 2026-08-15.** Dimension verdicts and the
  could-not-assess list are in the report file.
- **Q1 RULED + no-generic-setup directive applied (2026-08-15, operator in chat, same
  session as the review):** "always" ruling recorded in Q1 with the full discussion
  reasoning; PW1/PW2/PW3/PW5/PW6 + withheld line rewritten (trigger → setup derivation;
  triggered/untriggered site classes → live-path-until-cutover transition frame); PRIME
  DIRECTIVE 11 added; task F5 (WW3 parameterization catalog) added with its Gate F row;
  W3/W4/W5/Gate W/W-Accept/V1/V4/V5/SYNTAX labels/plan-relationship note swept to match;
  V5 retirement track widened to product-wide.
- **Three further operator orders applied same session (2026-08-15, in chat):**
  (1) model-setup decisions live in CODE, never product surfaces — PRIME DIRECTIVE 11
  extended, DOC-W.1 + PW5 clarified (product operators pick a location, period);
  (2) ADR impact disposition — task DOC-W.5 (full-index sweep + provisional table:
  ADR-100/103/104/106/107 AMEND NOW, 103/104/106/108 partial-or-full SUPERSEDED-AT-V5,
  101/102 untouched, archive walk mandated) + Gate DOC-W completeness row + C20 (ADR-107
  found still Proposed since 2026-08-11 — surfaced, and ACCEPTED by the operator later
  the same session: "yes adr107 is approved"; C20 resolved);
  (3) two documentation rounds — DOC-W confirmed as the PRELIMINARY round; NEW PHASE
  DOC-W-FINAL (as-built re-sync + adversarial zero-drift gate) added as a V4
  prerequisite; INDEX + execution order updated;
  (4) design-lives-in-the-plan — PRIME DIRECTIVE 12 (verbatim-intent capture), Phase W
  preamble rewired to the W-DESIGN-v1-as-plan-amendment convention (A1 pattern), R2.2
  design-block requirement added.
- **Problem-2 DROPPED (2026-08-15, operator in chat: "drop it, it is not an issue right
  now I want to deal with").** During the Q2 walk-through the operator established the
  underlying issue had NEVER been raised with them — the item was a prior session's
  single-day observation (P2-CONFIRMATION-PROTOCOL.md, "draft for operator review,"
  never reviewed), carried into this plan as if established. R3/PW8/C6/Q2 all carry
  dropped/void markers; V3 backstops the symptom class. LESSON (→ Q3(d)): carried items
  must cite an operator-validated premise; the adversarial review checked carry-over
  fidelity to the archive but never asked whether the operator had validated the premise
  itself — both this lead and the review own that miss.
- **Q3 ANSWERED (2026-08-15, operator: "ok"):** all four rule-lessons written —
  rules/agents.md gained the results-free-gate-briefs section and the scratch-experiment
  SSH carve-out; rules/verification.md gained the post-remediation adjacent-rerun rule
  and the carried-premise validation rule. C8 resolved. Rules edits uncommitted, riding
  the next meta commit with this plan.
- **Syntax + physics orders applied (2026-08-15, operator in chat):** §SYNTAX
  PRESCRIPTIONS rewritten to 13 detailed rows, each re-verified same-day against the
  local SWAN manual (full BOUNDNEST3 grammar :2694–2756 incl. the [xgc]/[ygc]
  Cartesian trap and the 0.1×-spacing acceptance window; BOUNDSPEC/Appendix-D grammar
  restated in full, no longer by archive reference) and the WW3 v5.16 manual text
  (ww3_grid.inp spectral/flags/time-step/namelist structure; FLAGTR 0–4; switch-file
  grammar; App. C.1/C.2 nesting procedure incl. the child's mandatory nest.ww3
  verification duties; ww3_bound vs ww3_bounc; ww3_outp ITYPE=1/OTYPE=3 transfer-file
  record structure — radians, oceanographic convention — and the SWAN-pairing rules;
  the boundary-only wind-off validation run adopted as a standing instrument). NEW task
  F1b designs the WW3 physics configuration IN-PLAN after the operator called out two
  rounds of handwaving: P1 = ST6/BYDRZ (:2522–2800, same family as our SWAN deck,
  negative-input analog :2673) vs P2 = ST4/Ardhuin 2010 (:2232–2520, observation-based
  swell decay, TEST471 defaults :2381–2412); manual defaults untouched in Phase F;
  decided by F3's physics A/B on F4.2's deficit-line rows; frozen in ADR-109. F1 builds
  both candidates; F3's march ladder and F4.2/F4.3 discriminator rows updated; SYNTAX
  row 10's ww3_outp→BOUNDNEST3 end-to-end compatibility check made mandatory before
  ADR-109 may pick mechanism A.
- **WW3 model definition designed in-plan (2026-08-15, operator called the remaining
  gap):** new §WW3 MODEL DESIGN v1 (WD1–WD10, the A1 D1–D9 analog for the WW3 leg) —
  domain/grid variants with degree conversions, bathymetry/mask/obstruction generation,
  spectral grid as an EXACT reconstruction-axes match (≈1.1086 factor / 0.03 Hz / 35
  freqs / 72 dirs — interpolation-free at both seams), candidate time-step line
  (100/33/50/10 s at G1), wind-only forcings candidate as an explicit ADR-109 acceptance
  row, boundary assembly, restart-vs-spin-up-lead initial-state candidates, per-cycle
  outputs, run sequence + persisted artifacts. F2 rewired to implement WD1–WD10 in
  scratch form; W DESIGN v1 refines-not-reopens; INDEX entry added same commit.
- **Cutover un-forced (2026-08-15, operator caught it, then "ok"):** V4 rewritten as a
  three-verdict disposition ruling; Phase L gates on the defensibility ruling alone;
  V5 cutover-branch-only; W5's serving flip deferred to a cutover verdict. See
  operator-order item 13.
- **FINAL pre-GO adversarial review + fixes (2026-08-15, operator: "fix them"):**
  a fresh results-free Fable review (barred from the prior report;
  `scratch/PLAN-CRITIC-REPORT-FINAL.md`) delivered 18 findings, all applied same day.
  BLOCKER G1: the syntax section had NO grammar for the ww3_grid.inp file reads
  (IDLA/IDFM/scale — including the depth-sign trap), ww3_shel.inp, or the wind
  preprocessors, while WD2 dangled a cite at "row 6" for it — new rows 6a/6b/6c
  researched from the local manual and cross-refs repaired. MAJORs: row 6's
  frequency-factor misquote corrected (manual says 1.07 for the nonlinear-interaction
  grid, not 1.1); DOC-W.5's ADR-107 row unstuck from "STILL PROPOSED" (accepted same
  session); PW4/W2 made bound-vs-bounc neutral (ADR-109's pick, not the register's);
  Gate R2.1 added (independent recomputation of the unfed-E bound before the PW7
  ruling); C15/C16/C19 tagged unvalidated per the carried-premise rule (C5/C18 given
  explicit premise citations). MINORs: the ADR-sweep row corrected (ADR-093–099 are
  ACTIVE, not archive; ADR-079/092/098 missing from the INDEX entirely; ADR-099
  file-vs-INDEX status drift — sweep now repairs the INDEX), residual forced-cutover
  phrasing swept to "verdict-1, if given" + Phase L's verdict-1 timing stated, PW5's
  "enable state" removed (display-only + transition-only shadow key; cutover flips
  ALL an install's sites), stale Q3(c) forward-reference closed, row 3's
  interpolation claim fixed (SWAN does interpolate file axes — ours just never
  triggers it), owners named for Phases V/R + the Gate-V file author, five jargon
  terms defined at first use (CFL, garden-sprinkler, LMSL, IDLA, namelist), F3's
  mid-march full-run-start case stated (E2 precedent), INDEX header corrected,
  V1–V3/DOC-W-FINAL concurrency stated, F1b's switch-token categories completed
  (FLX4-for-ST6 / FLX0-for-ST4, stab rules, NL1, deep-leg zeros, interpolation +
  build tokens), and the ledger scripts ACTUALLY mirrored to
  `scratch/energy-ledger-scripts/` (C12's location claim had been false). Verified
  sound by the same review: ~40 manual line cites (39 exact), every load-bearing
  number traced to its source, directives 11/12 with task-row teeth, no circular
  dependencies.

---

## OPEN OPERATOR QUESTIONS

*(Plain English, self-contained, newest at top. Answered items get their ruling recorded
here and applied.)*

### Q8 — ✅ RULED 2026-08-17 (operator, in chat): "yes, the fact that things do not get deployed is not my issue here, you need to make sure you are deploying things properly."
**Ruling applied:** option (a) — the three OFS audit fixes are re-implemented for real
(agent round + adversarial QC), and the coordinator owns carrying them through
deployment properly (deploy-marine.sh, baseline/diff, reality gate, journal sweep —
the full PRIME DIRECTIVE 2/3/4 + coordinator.md §2/§7 discipline). Push itself still
happens on the operator's push word per the standing git rule. W1's hold is lifted —
the repo state is understood; the false claim is now a recorded fact, not an unknown.
Original question preserved below.

### Q8 — original text (2026-08-17, Phase W pre-flight): the marine repo does not match the failure report's description — the claimed "unpushed OFS audit-fix commits" do not exist
**Context, plain:** Before dispatching the first Phase W coding task I checked the
marine repo's state. The session-3 failure report states the adversarial-audit fixes
for the deployed OFS fix (a thread/connection leak when a download truly hangs, a
missing declared dependency `h5netcdf`, one manual sentence) were "implemented and
committed LOCALLY ONLY — NOT pushed." **They are not there.** The repo's HEAD is the
deployed `00c8dae`, level with GitHub, and the local history log (reflog, complete
back to Aug 13) shows no commit after it ever existed in this checkout. Consequence if
this stands: the deployed OFS fallback code is running WITHOUT its audit remediations
— the dismissed coordinator's claim that they were implemented appears to be another
false claim (same class as its Failure 2). Also found: a `warm-start-fix` branch (3
"WS2" commits, per-hour SWAN warm-start chain) exists locally and on GitHub — it looks
like legitimate earlier work from another plan's lineage, but it is not referenced
anywhere in this plan; I have not touched it.
**Options:** (a) I add a small task to re-implement the three OFS audit fixes properly
(agent round + adversarial QC, local commits only, push/deploy on your word) —
recommended, since the deployed code carries known-but-unfixed audit findings; (b) you
tell me the fixes live somewhere I haven't looked; (c) defer. **Phase W's first
dispatch (W1) into this repo is HELD until you answer** — the repo's main branch
itself is clean and matches GitHub, so the hold is caution about acting on a falsified
state description, not a technical blocker.

### Q7 — OPEN (2026-08-17, from the DOC-W.5 sweep): ADR-098's status says "Proposed" but everything treats it as accepted. Should it be marked Accepted?
**Context, plain:** ADR-098 is the decision record that says all water-depth data
(bathymetry) and water-level data must use the same vertical reference point (datum),
because the wave models cannot detect a mismatch themselves. Its own file still says
"Status: Proposed." But in practice it is treated as a binding rule everywhere:
ADR-109 (which you accepted today) explicitly says ADR-098's discipline binds the new
WW3 model's bathymetry; the architecture document and manuals apply its rules; ADR-108
cites it. **Options:** (a) rule it Accepted — one word in chat; the file and index get
updated to match how it is actually used (recommended — the decision has been operating
as accepted for weeks); (b) leave it Proposed and tell us why. **Until ruled, nothing
is blocked** — the sweep filed it under Proposed in the index with a note marking the
contradiction.

### Q6 — ✅ RULED 2026-08-16 (operator, in chat): "If they still matter with the new plan, and need fixed, then fix them, if they are moot under the new plan, who cares."
**Lead triage under the ruling (this chat ruling is the authorization for the named
fixes, including their mechanical trigger-7 edges — new persisted shadow file, new
timeout constant):**
**ROUND CLOSED 2026-08-16:** all three fixes landed as marine locals 43744de (V14a) /
de2738f (V14b) / 09c0a1b (C16 floor) with same-commit tests (falsifiability proven:
period-floor tests verified by actual revert-and-run 3-fail/4-pass; V14a/V14b by
structural argument). Lead independently reproduced the targeted suite (25 passed),
verified the allowlist diff (7 files exact), and confirmed the one uncertain
pre-existing failure at baseline e40d2c9 via temp-clone rerun. Adversarial audit
(results-free, firewalled): **could-not-disprove, 0 defects**, 2 LOW observations —
(F1) the pre-existing `run_grid_sizing_chain()` catch-all makes a lock-timeout abort
indistinguishable from other chain failures at the health surface → routed to W5's
health/refuse design (same bucket as V14c); (F2) theoretical unguarded reconstruction
race, single-caller-path, convergent — no action. Commits LOCAL ONLY (C9 inventory:
marine now ahead by 4); deploy + authoritative librewxr test rerun happen at the next
operator-authorized push/deploy round. Incident on record: the round's triage briefly
applied a stale Aug-11 pre-split stash (content already landed as 1ff5124) via
`git stash pop` in the shared checkout — agent froze correctly, lead verified
staleness and restored the tree (`git reset --hard HEAD`, stash ref preserved);
stash-ref disposal + the no-git-stash rule-lesson pending with the operator.
- **FIX NOW (live serving path, matters through the whole transition and beyond):**
  (1) V14a — bounded, loud lock acquisition in the geometry-push path
  (`grid_sizing_chain.py:407`, `tools/reestablish_spot.py:402`): timeout 7200 s (above
  any legitimate ~88-min full-run hold), on timeout refuse loudly with named reason —
  never hang, never proceed lock-less; (2) V14b — post-restart cooldown survival:
  on-disk shadow of the last-full-run time (the V9/V12 Z3.9b shadow pattern, atomic
  persist per V13), reconstructed on restart; (3) C16 period floor —
  `model_wave_source.py` swell-slot selection gains the Z3.11
  `_MIN_SURFABLE_PERIOD_S` (5 s) eligibility floor every other selection site already
  has (imported from `surf_1d_pipeline`, the surf.py pattern). Round: `clearskies-api-dev`
  implements + same-commit tests; adversarial auditor pass; lead gate. Deploy is a
  SEPARATE later authorization (needs the push word; commits stay local per C9).
- **FOLD INTO W5 (moot as standalone — the new plan owns it):** V14c hotstart-age gate —
  exactly W5's health/refuse design territory, and SWAN hotstart mechanics are frozen
  core besides. No separate work.
- **DROPPED (moot/unfalsifiable):** "NDBC fetch stagger," "RTOFS currents," "graceful
  degradation" — bare phrases with no describable defect (C15/C16 audit: CANNOT
  ESTABLISH). Dead unless a real symptom ever surfaces with evidence.

### ~~Q6 (original question, kept for the record)~~ Old audit leftovers — what survives, what's dead. Your call on each.

**Plain English.** Last week's deep audit of the marine service produced a list of
mechanical defects. Most were fixed then; a few were parked with no ruling from you on
record. A read-only audit (evidence: `scratch/C15C16-DISPOSITION.md`, spot-checked by
the lead) has now established exactly what remains. Five of the six main findings are
CONFIRMED FIXED (commit `237b34c`, which you ordered on 2026-08-13). What survives:

1. **Three small "V14" leftovers** (all graded LOW at the time): (a) one code path that
   grabs the model-run lock with no timeout — if the model hangs, that caller hangs
   forever behind it; (b) the "don't re-run too soon after a full model run" cooldown is
   forgotten whenever the service restarts; (c) nothing checks the age of the model's
   warm-start file before reusing it.
2. **One real gap in the wave-source module:** it picks the first swell in the list with
   no minimum-period sanity floor — every other place in the code that picks a dominant
   swell now requires ≥ 5 s period first. (The archived description of this item was
   wrong about where it applies; the audit corrected the record.)
3. **Three items too vague to judge** — "NDBC fetch stagger," "RTOFS currents,"
   "graceful degradation" exist in the archive only as bare phrases with no described
   defect. They cannot be verified or refuted as written.

**Your options, per item or wholesale:** (a) fund as small tracked fix rows in this plan
(items 1–2 are mechanical, each small); (b) defer — e.g. fold into Phase W's health/
refuse design where V14's themes already land; (c) drop (especially the three vague
ones, which would otherwise sit unfalsifiable forever). No work happens on any of them
without your word.

### Q5 — ✅ RULED 2026-08-16 (operator, in chat): use the 6.07 manual — "if 6.07 is the current model, then you should pull the manual for it… And update the plan to reflect the current manual."
**Applied same day:** NOAA's official v6.07 manual (2019 Tech Note, the NOAA-EMC/WW3
wiki's own copy) downloaded and extracted to `scratch/ww3-manual-6.07.txt` (22,961
lines); it REPLACES the 5.16 text as the project's WW3 authority everywhere forward
(binding sections swept below; DOC-W.4 now commits the 6.07 manual). ALL WW3-side
SYNTAX line cites pointed into the 5.16 extraction — a re-verification pass of every
WW3-side row (6–13 + F1b's cites) against the 6.07 text was dispatched at the ruling;
its corrections land as plan amendments BEFORE F2 writes any deck. F2 dispatches after
that pass. Historical round-close entries keep their 5.16 mentions (they describe what
happened then).

### ~~Q5 (original question, kept for the record)~~ The WW3 we can build is version 6.07.1; the plan's manual and grammar research are version 5.16. How do you want the mismatch handled?

**Plain English.** The plan's detailed model-input grammar rules (the SYNTAX
PRESCRIPTIONS you ordered researched in advance) were researched against the WW3 user
manual version 5.16 — the manual text we have on disk — and the plan in places assumes a
"v5.16-built" model. But when the build agent went to NOAA's official code repository,
the ONLY released versions available to build are 6.07 and 6.07.1 (5.16 is a 2016-era
release that predates NOAA's move to GitHub; there is no 5.16 to check out). So we now
have working 6.07.1 binaries and a 5.16 rulebook. The input-file formats are largely
stable between these versions, but "largely" is not a guarantee, and the whole point of
the syntax prescriptions was to stop grammar surprises.

**Lead recommendation:** keep the 6.07.1 binaries (they are what NOAA actually maintains
and what our decision record would freeze anyway), and BEFORE F2 writes any deck, run a
verification pass of all 16 syntax-prescription rows against the version 6.07 manual
(NOAA publishes it; fetching it is allowed — it is NOAA's own documentation), amending
any row that changed with a marked correction. DOC-W.4 would then commit the 6.07 manual
as the project's authoritative WW3 reference instead of 5.16. Alternative if you prefer:
attempt to obtain and build the old 5.16 source from NOAA's legacy archives — not
recommended (unmaintained code, toolchain friction, and ADR-109 would freeze a version
NOAA no longer supports).

**F2 (our-domain configuration) HOLDS until you rule** — its decks depend on exactly the
grammar in question. F1's binaries and everything else already done are unaffected.

### Q4 — ✅ RULED 2026-08-16 (operator, in chat): NOT MATERIAL — R2.2 is DEAD. Ruling delivered as a premise challenge: "Ummm the east side is land?"
**What the challenge established (lead verification, commands in session record):** the
census's arithmetic was correct twice over, but its QUESTION was physically senseless
for the headline band. The E-exit directions are azimuths 100–170° (from the ESE–SSE);
beyond the grid's East edge lies ~50–60 km of water and then the San Diego/Baja
coastline — no fetch, Baja shadowing — so >11 s swell cannot arrive from those
directions. The census substituted open-ocean southern-boundary energy into
coast-blocked direction bins, manufacturing the 16.6–24.5% figure. Common-sense premise
check failed before any arithmetic mattered. R2.2 does not run; PW7 authorizes nothing
(marked DEAD below); the only physical residue (occasional short-period easterly
wind-sea) is V3's to catch with real evidence if it ever matters, and the WW3 leg's
NOAA-fed boundaries (real geography, Baja included) make the question obsolete at
target state. LESSON routed at the ruling: premise-sanity-before-arithmetic →
rules/verification.md (pending operator OK on the wording, offered in chat).

### ~~Q4 (original question, kept for the record)~~ Is the corrected unfed-East-boundary number big enough to fund the fix (the PW7 ruling)?

**Plain English.** Our wave model's offshore box has four sides. We feed real wave data
in through the South and West sides; the East side gets nothing. For waves arriving from
directions that would have entered through the East side, the model substitutes a
stand-in guess. An earlier count of how much energy this affects used the wrong hour of
the day by mistake (18Z instead of 06Z). Task R2.1 redid the count at the right hour,
and an independent auditor — never shown the first result — recomputed it from the raw
files and got the same numbers, so the count is now trustworthy.

**The corrected numbers:** at the seven measurement points along the model handoff line,
16.6–24.5% of the long-period wave energy would have entered through the unfed East side
(worst point: 24.5%, which would move wave height there from 0.64 m to 0.56 m if the
stand-in guess were exactly wrong). Averaged over all ten check points: 15.3%. The old,
wrong-hour figure was roughly half that (7–11%) — so the correction made the problem
look BIGGER, not smaller.

**Two honest caveats from the audit:** (1) this is an upper BOUND resting on an
assumption — nobody has East-side data (that's the problem itself), so the count assumes
unfed directions would carry energy like the South side's average; (2) it is a snapshot
from one 3-hour instant, and the number moved ~2.2× between two instants of the same
day, so it is sensitive to when you look.

**Your ruling (PW7 — no numeric default, deliberately):** is this material enough to
build the fix (R2.2: feed the East side using the same mechanism the South and West
sides already use)? Options: (a) YES — material: R2.2's design block gets written into
this plan, then docs, then implementation with its own gate and solo deploy; (b) NO —
not material: recorded, no work; (c) DEFER — let the V-phase shadow campaign's
served-quality evidence decide later. Recommendation: none offered — the plan
deliberately reserves this call for you.

### Q1 — ✅ RULED 2026-08-15 (operator, in chat): ALWAYS — our WW3 owns the deep-water leg for every install ("Yup it is option 2 for sure now")
The discussion that produced the ruling, recorded so future phases argue in the right
frame (it dismantled the lead's conditional recommendation piece by piece):
- **"One model path" was a false frame.** SWAN always runs the nearshore (L2 everywhere;
  L3/L4 only where the spot's local features demand them), so no ruling produces a
  one-model system at complex sites. Install burden was also a false differentiator —
  both models ship in the Docker image, and native installs already compile SWAN from
  source (OPERATIONS-MANUAL §deployment).
- **The WW3 decision variable is REGIONAL, not local.** The pier trips L3/L4; the
  Channel Islands — the offshore domain the deep leg must cross — are what implicate the
  deep-water model. Sites in one install share their offshore water, so per-site
  conditionality was never physically meaningful, and the operator ruled mixing
  deep-water implementations within one install environment out entirely.
- **The decisive point (operator): a setup-time classifier only knows the failure classes
  somebody already found — and this project only found SWAN's through months of model
  failures.** A misclassified install fails SILENTLY: plausible-but-wrong forecasts, the
  defect class that took operator buoy-checking to catch here and that no other install's
  operator would ever catch. A classifier conservative enough to be safe routes most real
  coastlines to WW3 anyway. So: no classifier. Every install runs the identical
  V-phase-validated WW3 leg; failures found once are fixed for everyone; refuse-loudly
  guards the leg; the SWAN deep-leg subsystem goes on the V5 product-wide retirement
  track.
**Structural effect, applied 2026-08-15:** PW2 rewritten from conditional trigger to
setup-time DERIVATION; W4 rewritten accordingly; triggered/untriggered language replaced
plan-wide by the transition frame (live SWAN-L1 path serves until V4 cutover).
**Companion order (same date) — the no-generic-setup directive → PRIME DIRECTIVE 11 +
task F5.** Operator, verbatim intent: "This was part of our problem with SWAN, we just
deployed a generic setup and only after multiple failures did we learn the intricacies of
setting up the model correctly. I do not have the time to make that same mistake again.
We need to make sure our ray tracing, our bathymetry analysis, etc… are geared towards
collecting the information needed to size WW3 grid cells correctly, determine WW3
boundary correctly, adjust which parameters and plugins are used (if those exist)… That
cannot be an after the fact thing here."

### Q2 — ✅ VOID 2026-08-15: Problem-2 DROPPED by operator ruling ("drop it, it is not an issue right now I want to deal with")
The question asked which capture mechanism (scratch collector vs a temporary DEBUG-logging
window) could record the per-hour handoff train lists for the Problem-2 tests. With
Problem-2 dropped (see R3 / PW8 / C6), no capture happens and neither mechanism is
authorized. Root cause of the drop recorded honestly: the item was a prior session's
unvalidated hypothesis carried forward as if established — the operator was never shown
the underlying observation (rule-lesson candidate Q3(d)).

### Q3 — ✅ ANSWERED 2026-08-15 (operator: "ok" — all four approved) — RULES WRITTEN
All four rule-lessons written the same session (working tree, uncommitted):
(a) **Adversarial gate briefs are results-free** → rules/agents.md (new section after the
false-claim protocol); (b) **Post-remediation reruns cover affected + adjacent suites** →
rules/verification.md (new section, cites the Z3.3→Z3.4 miss); (c) **Scratch-experiment
carve-out** to the agents' "SSH is read-only" rule (operator-authorized,
named-directory-scoped, contention rules bind) → rules/agents.md (inside the
container-edit hard-ban section); (d) **Carried-over items must cite an
operator-validated premise** (from the Problem-2 drop; carry-over reviews check premise
validation, not just paper-trail fidelity) → rules/verification.md (new section, cites
the Problem-2 incident).
