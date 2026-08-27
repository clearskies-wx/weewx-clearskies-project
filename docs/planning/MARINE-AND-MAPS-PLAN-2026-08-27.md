# Marine & Maps Plan — finish the surf system, fix the maps (2026-08-27)

## START HERE — what this plan is and how to read it

**What we're doing, one paragraph:** Two threads, one document. **Maps:** CARTO, the company
whose free map tiles every dark-theme map in the product used, started watermarking them
"API KEY REQUIRED" on ~2026-08-25 and is retiring the product. The fix is three rounds, all
ruled by the operator in chat on 2026-08-27: Clear Skies gets its own basemap (OSM light kept,
Protomaps dark from an extract we serve ourselves) for the **marine and seismic maps only**;
the radar/satellite box stops being decorated by Clear Skies at all (an empty Leaflet box plus
whatever the provider sends); and the labels that were wrongly coded into Clear Skies move to
the LibreWxR fork where they belonged. **Surf:** the WW3 → SWAN → SwellTrack chain is live and
serving, but a list of things is still owed — the forecast beyond +6 h only becomes real once
the Q17 fix deploys and its gate passes; the seam-fidelity ledger row (C6); the consistency
score the operator approved in Q14 but that was never coded; dead keys and stale docs left by
the L1 → WW3 substitution; test debt; the buoy-validation campaign the previous plan designed
for a shadow chain that is now the production chain; the first-install warm-start mechanism;
and — **operator-ordered LAST** — the island-shadowing energy deficit. The lookup-table phase
(Phase L) stays last, unchanged.

**THE ACTUAL WORK is the `## PHASE …` sections, in file order:** M (maps) and S (surf) run
CONCURRENTLY — they touch different repos — with Phase D (as-built docs) and Phase L (LUT) after.
Inside a phase, tasks run in the order written. **Current status of every task: TASK CHECKLIST
below.**

**Everything else is reference:** CURRENT STATE (session log), PRIME DIRECTIVE (standing rules,
carried from the previous plan, renumbered 1–12 unchanged), PRE-APPROVAL REGISTER (what the
operator has already authorized — nothing else is), CARRY-OVER REGISTER (every open item
inherited from the closed plan and the other live plans, each with the operator interaction
that validated it, per rules/verification.md), NAMED CONSTANTS, Round-close rules, OPEN
OPERATOR QUESTIONS (bottom, newest first).

**Predecessor:** [MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md](MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md)
— CLOSED 2026-08-27 by this plan. Its Phase F / DOC-W / W / CHAIN-SERVES / Q15–Q18 records,
the WW3 MODEL DESIGN, the SYNTAX PRESCRIPTIONS and the 23-trap catalog stay there as the
historical and design record; this plan cites them, it does not restate them.

**Letter codes:** `M#`/`S#`/`D#`/`L#` = task inside its phase. `PA#` = Pre-Approved row.
`C#` = Carry-over item. `Q#` = operator Question (numbering restarts at Q1 in this plan; the
predecessor's Q1–Q18 are cited as `EVO-Q#`).

---

## ✅ TASK CHECKLIST — the whole plan at a glance (keep current every session)

| # | Task (plain name) | Status |
|---|---|---|
| S0 | **Q17 push + live gate** — GFS far-window fetch f096→f108 so the daily 96 h WW3 horizon march finally runs | 🔄 CODE DONE (marine `2a05856`, meta `b7142574`; 31/1-known tests) — **awaiting operator "push"**; live gate at the next 00Z cycle after deploy (rows in S0) |
| M0 | Map extent inventory + extract-size measurements (read-only) | ⬜ NEXT — no ruling needed (read-only) |
| M1 | **CS-BASEMAP** — Clear Skies product basemap for EVERY Clear Skies map box (marine, seismic, radar/satellite, surf height map): OSM light kept, Protomaps dark + labels layer from a self-served extract, CARTO removed | ⬜ RULED 2026-08-27 (EVO-Q18 Round 1; scope widened by Q6 + Q5 rulings, same day) — design block below; brief after M0 |
| M2 | ~~LIBREWXR-BASEMAP~~ **CANCELLED 2026-08-27 (Q6 ruling)** — LibreWxR, RainViewer and every radar provider are overlay-only; the client brings the basemap AND its labels, so nothing moves into the fork. Kept as a row so the reversal is on record | ✅ closed-no-work |
| M3 | ~~RADAR-STRIP~~ → **RADAR-REBASE** — the radar/satellite box keeps a Clear Skies basemap; only its SOURCE changes: CARTO dark → product basemap dark; CARTO satellite labels + ADR-078 outlines → the product basemap's labels/outlines layer; the standalone ADR-078 feature is absorbed into M1's basemap machinery (one extract family, one endpoint family) | ⬜ RULED 2026-08-27 (Q6) — part of the M1 build |
| M4 | **SURF-MAP-BASEMAP** — the surf height map's background becomes the product basemap (light OSM / dark Protomaps); Esri World Topo (IMAGERY-MAP) and NAIP removed from every user-facing surface; the wizard's Esri satellite toggle STAYS (operator-only, not user-facing) | ⬜ RULED 2026-08-27 (Q5) — after M1 |
| Gate M | Adversarial gate per round + one end-to-end row (every map surface rendered in both themes, screenshots side-by-side) | ⬜ |
| S1 | **C6 seam-fidelity ledger row** — WW3-handed vs SWAN-absorbed at the L2 boundary, every cycle | ⬜ APPROVED 2026-08-25 (EVO-Q16 C6) — after S0's gate passes |
| S2 | **CONSISTENCY-SCORING** — code the Q14-approved set-timing/set-amplitude definitions into the surf score (ADR-101 row-5 amendment first). NOT in code today — the scorer still runs the interim swell-dominance bucketing | ⬜ APPROVED 2026-08-23 (EVO-Q14); sub-decisions A–E RULED 2026-08-27 (Q3 "yes") — ready to brief after S8.1 |
| S3 | **Substitution cleanup** — dead `ww3_chain_enabled` key, `level1` label rename, stale `inputs.ww3_boundary` health entry, vestigial `_reused_l1_boundary_command_lines()` + the on-disk `swan/level1/` directory, hotstart-age gate (C7 survivor), PROVIDER-MANUAL §14.15 swell-card bullet, API-MANUAL §17 `swellSource` + `closeoutFraction`, ADR-109 G7 "unbuilt" note struck | ⬜ methodology (dead code / doc drift). Register re-audited 2026-08-28 (Q9) |
| S10 | **FOG-REVERT** (API) — revert the 2026-08-24 fog cross-check narrowing (API `1ad6e74` + `f2c5ecd`): two nights of live testing showed the night-time standalone ≤ 1 °F rule cries wolf (conditions right, fog rarely formed); the provider cross-check returns at every level, as before. The uncommitted API-MANUAL edit documenting the narrowing is discarded | ⬜ RULED 2026-08-27 (Q4 "we actually need to revert the change") — lead-direct `git revert` + fog tests on weewx + CHANGELOG; deploy on "push" |
| S4 | **Test-debt triage** — two test files, 18 failing tests (`test_serve_nothing_on_failure` 8, `test_service_full_run_trigger` 10; re-verified 2026-08-28), one ruling per class (repair harness / delete stale pin / keep) | ⬜ |
| S5 | **First-install WW3 warm-start bootstrap** — the durable mechanism EVO-Q9 parked as a pre-ship row | ⬜ pre-ship; not needed for this install |
| S6 | ~~ADR-109 gap closure~~ **DISSOLVED 2026-08-28 (Q9)** — G7 is built (one-line ADR edit → S3); G10 (`ww3_grid` rebuild hook) is part of S8.1; D14 stays a note | ✅ closed-no-work |
| S7 | ~~Live-chain validation campaign~~ **DROPPED 2026-08-27 (Q1: "THIS IS ALL TESTING... NO ONE IS ACTUALLY VISITING THE SITE")** — no formal campaign, no ceremony gate. The per-cycle buoy ledger keeps running as the standing instrument; the operator checks the site as they see fit; when Phase L opens is the operator's call, not a gate this plan computes | ✅ closed-no-work |
| S8 | **Island shadowing** — the S-swell <0.1 Hz 0.56–0.60× deficit (narrow reconstruction lobe σθ 15° vs measured 27–31°, no diffraction, Catalina lee). **S8.1 (transparency field) RUNS NOW (Q7 "run now")**; the rest (lobe width, diffraction) stays LAST | 🔄 S8.1 briefing now; S8 research LAST |
| S9 | ~~Inherited-queue reconciliation~~ **OUT OF THIS PLAN (Q2: "keep that crap out of here. Let's chat separately")** — the other plans' open rows are NOT tracked here | ✅ removed |
| D1 | As-built doc re-sync + zero-drift audit (the predecessor's DOC-W-FINAL) | ⬜ after M and S close |
| L0+ | Lookup-table system (design round + ADR-110) | ⬜ LAST — opens only on the operator's "accurate and defensible" (unchanged) |

---

## INDEX — sections in FILE ORDER

1. START HERE · 2. TASK CHECKLIST · 3. INDEX · 4. CURRENT STATE · 5. PRIME DIRECTIVE ·
6. PRE-APPROVAL REGISTER · 7. CARRY-OVER REGISTER · 8. NAMED CONSTANTS · 9. PHASE M — maps ·
10. PHASE S — surf system · 11. PHASE D — docs · 12. PHASE L — LUT · 13. Round-close &
bookkeeping · 14. OPEN OPERATOR QUESTIONS.

---

## 📍 CURRENT STATE — updated every working session (last: 2026-08-27)

**Live:** marine `b62008f` on librewxr (Q16 A+B, INV11-RETIRE, BREAK-REFORM, DREF-MERGE-FIX,
PEEL-SEGMENTS), API `a5e45a9` (IMAGERY-MAP), dashboard `125b642`. The chain publishes every
cycle (`fullRun.lastSuccessCycle` 2026-08-27T00Z). **Known-broken right now:** (1) every
CARTO-tiled map surface is watermarked in both themes; (2) the WW3 horizon march has never
run (`ww3Horizon.lastSuccessCycleTime: null`, `ww3_horizon_wind_short`), so
`fullRun.l2BoundaryExhausted` is still TRUE — the forecast beyond +6 h is a frozen ocean.
Q17 fixes (2) and is committed locally, awaiting "push".

**Session 2026-08-27:** Q17 traced, ruled (a), coded lead-direct, doc-synced. CARTO break
traced to the source; four rulings taken in chat (no Esri; OSM light stays; Protomaps for
dark; radar box is provider-only and the satellite labels move to the LibreWxR fork). This
plan created; predecessor closed.

---

## PRIME DIRECTIVE — carried from the predecessor, binding on every task (unchanged text, by reference)

Rules 1–12 of MARINE-MODEL-EVOLUTION-PLAN §PRIME DIRECTIVE apply verbatim: (1) frozen core
off-limits unless a task's Files list names the file — the frozen-core lists of
MARINE-FORWARD-PLAN / L1-BOUNDARY-REBUILD-PLAN remain closed; (2) baseline before, diff after,
every deploy; (3) one functional change per deploy; (4) reality gate on every deploy;
(5) stale tests → STOP; (6) agent discipline — Sonnet agents, written briefs with the three
mandatory blocks, scope-ack, results-free adversarial gate BEFORE the lead gate, doc-sync in
the round; (7) line numbers are hints; (8) no silent fallbacks; (9) plain English;
(10) model-behavior source rule (SWAN from the SWAN manual, WW3 from the WW3 manual, never
cross-inferred); (11) no generic model setup, zero model-setup controls on product surfaces;
(12) design lives in the plan — agents implement design blocks, never produce them.

**Added by this plan (operator rulings 2026-08-27, map thread; 13 amended the same day):**
13. **Radar providers are overlay-only; Clear Skies brings the basemap — the PRODUCT basemap.**
    LibreWxR (ours or public), RainViewer and any other radar provider serve transparent radar
    and opaque satellite tiles and require the client to supply the ground underneath, labels
    included (verified in the fork's own integration guide). So the radar/satellite box gets
    the same Clear Skies basemap as every other map box — never a provider-specific one, never
    anything derived from the provider — and nothing of ours is moved into LibreWxR. (Earlier
    same-day wording "Clear Skies provides NOTHING for the radar box" was withdrawn by the
    operator once the provider contract was verified: "you did not do it wrong, i apologize.")
14. **External providers' extents are not inputs.** LibreWxR is an external provider like
    RainViewer. Its BBOX, tiles and satellite imagery are never read by anything Clear Skies
    derives (basemap extents included). Most installs will not run LibreWxR at all. Consequence,
    accepted: the dark basemap is detailed only inside the box derived from Clear Skies' own
    config; a radar view dragged far outside it shows the coarse world baseline.
15. **No Esri, no aerial photography, on any USER-FACING surface** (compliance + caching
    restrictions; the low-tide NAIP finding). The surf height map's background becomes the
    product basemap (Q5). The wizard's Esri satellite toggle stays — operator-only, not
    user-facing.

---

## PRE-APPROVAL REGISTER — the architectural changes this plan authorizes (and no others)

| # | Change | Trigger(s) | Ruling basis |
|---|---|---|---|
| PA1 | **GFS far-window fetch depth f096 → f108** (`wind_gatherer._GFS_FAR_FETCH_END_HOUR`) so the daily horizon march's wind is already held when it fires | 7 (changes the Q16.1-approved "+96 h" number) | Operator 2026-08-27, chat: "a" (EVO-Q17 option a). DONE marine `2a05856` |
| PA2 | **CS-BASEMAP**: a Clear Skies product basemap for EVERY Clear Skies map box (marine, seismic, radar/satellite, surf height map) — dark theme + labels/outlines layer from a Protomaps extract Clear Skies derives from its own configuration (station + earthquake radius, marine locations) and serves itself; light theme stays OSM raster; CARTO removed from the product; the ADR-078 geographic-features feature is ABSORBED into this machinery (its extract, endpoint, admin action and config key are replaced by the basemap's, ADR-078 → Superseded by this plan) | 2, 4, 7 | Operator 2026-08-27 in chat: "NO ESRI!"; keep OSM light; Protomaps for dark; extent from our own config only; Q6 ("we needed to bring our own basemap") and Q5 rulings same day |
| PA3 | ~~RADAR-STRIP~~ **WITHDRAWN 2026-08-27** (Q6 — the provider contract requires the client's basemap; see directive 13). Replaced by M3 RADAR-REBASE inside PA2 | — | Operator 2026-08-27 in chat |
| PA4 | ~~LIBREWXR-BASEMAP~~ **WITHDRAWN 2026-08-27** (Q6 — nothing moves into the fork) | — | Operator 2026-08-27 in chat |
| PA9 | **SURF-MAP-BASEMAP** (M4): the surf height map's background switches from Esri World Topo / NAIP to the product basemap; `providers/imagery/{naip,esri,esri_topo}.py` and the `[imagery] provider` selection are removed from user-facing use (the wizard's own Esri satellite toggle is untouched) | 2, 7 | Operator 2026-08-27 in chat (Q5): "get rid of the orthophotography for the surf height map and replace it with a regular basemap ... eliminates [NAIP] completely from user facing work" |
| PA10 | **FOG-REVERT** (S10): revert API `1ad6e74` + `f2c5ecd` (night-time standalone ≤ 1 °F fog rule) to the prior provider-cross-checked behaviour | 1 (a threshold inside a criterion) | Operator 2026-08-27 in chat (Q4): "we actually need to revert the change ... we are crying wolf most of the time" |
| PA5 | **C6 seam-fidelity ledger row**: one SWAN L2 output point just inside its boundary + a per-cycle ledger field comparing WW3-handed vs SWAN-absorbed spectra | 7 | Operator 2026-08-25, chat "ok" on EVO-Q16 (C6 named there; "droppable on request") |
| PA6 | **CONSISTENCY-SCORING**: ADR-101 row-5 amendment + parse-time attachment of per-partition group statistics (ν, Qp, κ, Tm02, T_set) to the DWR spectral entries (a data-contract change inside the marine service), scorer reads them | 1, 4 | Operator 2026-08-23, chat "q14 recommendation is fine" (EVO-Q14 record); the per-partition data path was disclosed in that row as covered by the Q14 approval. Open sub-decisions → Q3 |
| PA8 | **WW3 G1 transparency field for partially-land cells** (S8.1): fraction-based land/sea mask + `FLAGTR = 2` cell-centre transparencies derived at setup from the finest cached DEM; `F_DRY = 0.05` | 1, 3 | Operator 2026-08-27, chat: "it should also apply to cells that are not 100 percent island … so you are not OVERCOUNTING an island"; Q7 "run now"; 5 % floor accepted by silence on the stated default |
| PA7 | **Substitution cleanup** (S3): deletion of provably-dead keys/code left by the L1 → WW3 substitution | none (methodology: nothing was being done; nothing stops being done — CLAUDE.md table) | Standing rule; each deletion still gets the pre-deletion grep + post-deletion green accept (rules/coding.md "Never keep dead code") |

Withheld: model-physics changes of any kind (island shadowing S8 included — research and
ruling first); anything in the frozen-core lists; Esri removal from imagery/wizard (Q5);
Phase L entirely (ADR-110 first).

---

## CARRY-OVER REGISTER — every open item inherited, with the operator interaction that validated it

Per rules/verification.md "Carried-over items must cite an operator-validated premise": an item
without a citation enters tagged **UNVALIDATED — surface before any work** and is worked only
after the operator confirms it in Q2.

**RE-AUDITED 2026-08-28 (Q9 — operator: "i am very nervous about all of the carry over tasks
without going through each one and assessing what has been done and if it is still needed").**
Every row was checked against marine HEAD, the live service, and the predecessor's own close
records. Result: three rows were ALREADY DONE when this plan was created (C7 ×2/3, C8, C18 —
lead error: carried from the predecessor's original C15/C16 rows without reading its Q6 close),
two were moot (C3, C4), five were operator-dropped in this pass (C1, C2, C5, C6, C14) — C5 and
C6 had been discussed and settled in chat earlier but never marked closed in any plan, which is
exactly why they kept resurfacing. LESSON (rule-shaped, applied to rules/verification.md): a
chat ruling that closes an item is written into the plan the same hour; a carried row cites the
predecessor's CLOSE record, not its OPEN row.

| # | Item | Premise citation | Lands in |
|---|---|---|---|
| ~~C1~~ | ~~Operator eyeballs owed (multiSwell trains, surf card, cam + knob drill, dry-beach re-accept)~~ | operator 2026-08-28 "c1 drop" | DROPPED — the operator looks at the site nightly; no formal sign-off rows |
| ~~C2~~ | ~~Fresh buoy apples-to-apples for the 18 s SSW event~~ | operator 2026-08-28 "c2 drop" | DROPPED — the per-cycle buoy ledger is the same comparison, continuously |
| ~~C3~~ | ~~~181 stale `B_*.txt` on librewxr~~ | verified 2026-08-28: the service work root holds 88 `B_*.txt`, all 2026-08-19, all referenced by the live L2 INPUT — not stale; the 176 under `/home/claude/ww3-baselines/e1e2/` are the PRESERVED research baselines (EVO-F0) — never delete | MOOT. Residue: `swan/level1/` (34 files, 08-19) is the removed L1 level's directory — folded into C19 (the stationary fill still reads its INPUT) |
| ~~C4~~ | ~~Currents tail-hold never live-exercised~~ | verified 2026-08-28: live health `currentsTailHeld: {hours: 21, reachUntil: 2026-08-29T03Z, recorded_at: 2026-08-27T03:26Z}` | DONE — exercised live |
| ~~C5~~ | ~~Parked physics candidates (L4/1-D deep-ledge handoff loss; 5° nearshore directional bins)~~ | operator 2026-08-28: "these were discussed" — settled in chat earlier, never recorded as closed | DROPPED. If the island work (S8) does not close the deficit they return WITH evidence, not as guesses |
| ~~C6~~ | ~~Phase T (tide coherence) close acknowledgment~~ | deployed 2026-08-11; operator 2026-08-28 "if this was done why did you not mark it complete?" | CLOSED |
| C7 | V14 residuals — **two of three FIXED 2026-08-16** (marine `43744de` bounded lock, `de2738f` cooldown persistence; both in HEAD). Surviving: **no hotstart-age gate** (nothing checks the warm-start file's age before reuse) | EVO-Q6 ruled 2026-08-16; the age gate was ruled "fold into the health/refuse design" | S3 (one item) |
| ~~C8~~ | ~~`model_wave_source.py` bare `swells[0]`~~ | FIXED 2026-08-16 marine `09c0a1b` (floor at `model_wave_source.py:543–547`, in HEAD) | DONE |
| C9 | L1-BOUNDARY-REBUILD-PLAN deferred queue: Gate S wlevel (blind audit) → S1+S4a currents ladder → S-Accept currents rows → Phase A (A1/A2 service-area/setup report) → Gate A → Gate C (C1–C3 rows) → V1/V3/V4 | That plan is operator-approved 2026-08-08 ("the plan serves as permission") and its status block says "Remaining: …"; several items have since landed by other rounds (STOFS wlevel live, currents ladder live per ARCHITECTURE, `currentsTailHeld` live) — **state not re-verified since 2026-08-09** | **OUT OF THIS PLAN** (Q2 ruling 2026-08-27) — separate operator conversation |
| C10 | SURF-REMEDIATION-PLAN R1–R4 (min/max range served; reform/second break; fixed chart scale + `/var/lib` work root; R4 parallel report) | Operator-approved 2026-08-08; R2's subject was re-done by BREAK-REFORM 2026-08-26; `/var/lib/weewx-clearskies/swan` is live (health `ledgerPath`) | **OUT OF THIS PLAN** (Q2 ruling 2026-08-27) — separate operator conversation |
| C11 | SURF-PHYSICS-REMODEL-PLAN rounds Y/X/Z + DOC-0/DOC-1 debts; MARINE-FORWARD-PLAN open rows; EYEBALL-FIX residuals (subsumed into the remodel plan per its own header) | Operator-approved 2026-08-06 / 2026-08-02 / 2026-08-04 | **OUT OF THIS PLAN** (Q2 ruling 2026-08-27) — separate operator conversation |
| ~~C12~~ | ~~LIBREWXR-SATELLITE-SEAM~~ | operator 2026-08-28: "c12 has nothing to do with this plan" | REMOVED — a LibreWxR item; its pin (2026-08-08) is the fork's record, not this plan's |
| C13 | Pre-existing test failures — **re-run 2026-08-28 (Windows)**: `test_serve_nothing_on_failure` 8 FAIL and `test_service_full_run_trigger` 10 FAIL, identical to baseline; `test_h4_chunked_json` and `test_double_break_transect55_kat` PASSED this run (the first was always a wall-clock flake); `test_wind_gatherer::TestColdStartReconcile` is Windows-path only. 18 failing tests in the model's own suite | Each recorded in an EVO checklist row with the lead's checkout-verified reproduction | S4 (two test files) |
| ~~C14~~ | ~~Marine failure monitor armed~~ | operator 2026-08-28 "c14 no" | DROPPED. Fact: the old monitor was a previous chat session's watch and died with it — nothing watches the marine service now |
| ~~C15~~ | ~~Island-shadowing deficit~~ | operator 2026-08-28: "why c15 is needed if we replaced it with a new task" | FOLDED — S8 IS this item; no separate row |
| ~~C16~~ | ~~ADR-109 gaps G7/G10, D14~~ | verified 2026-08-28: **G7 (wind onto the WW3 grid) is BUILT** — the horizon march's wind path (`service.py:831`); **G10 (`ww3_grid` rebuild on geometry change) is NOT** — `service.py:938–947` refuses, and the live `mod_def.ww3` was hand-minted 2026-08-18; **D14** is a note about a test that could not be run, not a defect in the running model | DISSOLVED (operator 2026-08-28): G7 → one-line ADR-109 edit (S3 doc round); G10 → part of S8.1 (the island round rebuilds the grid and needs this hook); D14 → stays a note in ADR-109, no task |
| C17 | First-install warm-start bootstrap | EVO-Q9 ruling 2026-08-19: seed executed; durable mechanism "PARKED as a pre-ship row" | S5 (parked; not needed for this install) |
| ~~C18~~ | ~~Uncommitted API-MANUAL fog-section edit~~ | discarded (`git checkout`) 2026-08-27 under Q4 | DONE |
| C19 | Leftovers of the SWAN-L1 removal, all CONFIRMED 2026-08-28: `ww3_chain_enabled` is a no-op (`service.py:668`); `level1` naming — 170 occurrences in 11 files; `_reused_l1_boundary_command_lines()` still runs in the stationary-fill path (`swan_runner.py:4686`, `vchain.py:727`) reading the dead `level1/INPUT`; health lists `ww3_boundary` as a REQUIRED input that nothing records (live: `inputs.ww3_boundary.available: false`; only exempt from turning the status red because never-recorded inputs are skipped, `health.py:446–458`); plus the `swan/level1/` directory on disk (from C3) | ARCHITECTURE.md records the first three as tracked follow-ups; the fourth found 2026-08-27 in `/health` | S3 |
| C20 | Doc drift, CONFIRMED 2026-08-28: PROVIDER-MANUAL:2529 "Feeds the swell display card" (true only via fallback since Q16-B); API-MANUAL §17 lacks `swellSource` + `closeoutFraction` | EVO Q16-ROUND-B row; PEEL-SEGMENTS CHANGELOG entry | S3 (doc round; Q4 is ruled so the file is unblocked) |

---

## NAMED CONSTANTS (carried; not re-derivable by agents)

- Energy-ledger band edges **< 0.09 / 0.09–0.2 / > 0.2 Hz**; log-spaced integration.
- The **cliff KAT** deck and its current answer **0.578 m** (EVO §NAMED CONSTANTS) — the
  standing seam instrument for S8.
- `L1_NEST_MAX_AGE_H = 9`, `WW3_RESTART_MAX_AGE_H = 9` (refuse-on-stale, operator-confirmed).
- `_WW3_HORIZON_SPAN_H = 96`, horizon cycle **00Z**, `_GFS_FAR_FETCH_END_HOUR = 108` (PA1),
  `_OCEAN_FORECAST_HOURS = 99`.
- Reality-gate tolerances (stated before looking, every deploy): Hs ±30 % / dominant Tp ±2 s /
  direction ±30° vs NDBC 46222/46253 at the matched hour.
- **Map extents (M1):** seismic = station ± `default_radius_km` × 1.15 (the seismic map's own
  initial-bounds rule, `seismic.tsx:203–210`); marine = bounding box of all marine locations +
  the map's own 40 px padding, detail zoom **15** (hero view is z14, `HERO_ZOOM`); world
  baseline zoom **0–6**. Numbers to be MEASURED (file sizes, tile counts) in M0, not assumed.

---

## PHASE M — maps (operator-ruled 2026-08-27; repos: dashboard, api, stack, librewxr fork)

**Order:** M0 → M1 and M2 in parallel (different repos) → M3 only after M2 is serving.
**Owner:** coordinator designs; `clearskies-dashboard-dev` / `clearskies-api-dev` implement;
`clearskies-auditor` gates. Every brief carries the three mandatory blocks and PRIME DIRECTIVE
13–15 verbatim.

### M0 — Extent inventory + measurements (read-only, no ruling needed)

Deliverable `scratch/M0-MAP-EXTENTS.md`: (a) for each Clear Skies map surface, the extent
source and zoom range **as coded** (marine `LocationMap.tsx`, seismic `seismic.tsx`; the radar
box is excluded by directive 13); (b) for this install, the derived boxes from live config
(station 33.657/−117.983, quake radius 200 km, the marine locations from `/api/v1/marine`);
(c) measured `pmtiles extract` sizes and tile counts for: the union box at z7–15, the marine
box at z15, the world at z0–6 — run on weewx where the CLI already lives, into a named scratch
dir; (d) the `protomaps-leaflet` 5.x theme API (which built-in themes exist, how label-only
rules are expressed) verified from the installed package, not from memory.

### M1 — CS-BASEMAP (design block; implement after M0)

**Extent derivation (API, config-time):** a new `services/basemap_extract.py` computes
`bounds = union(seismic_box, marine_box)` from `api.conf` + the marine locations the API
already holds; no operator-typed box; recomputed by the same admin action that runs the
extract. Two files, both under `/etc/weewx-clearskies/`: `basemap-world.pmtiles` (z0–6,
global) and `basemap-local.pmtiles` (z7–15, the union box). Served by one endpoint family
`/api/v1/basemap/{world,local}/tiles` (Range requests, same mechanism ADR-078's endpoint uses
today) + `/api/v1/basemap/status`. Admin page: one "update basemap" action + status.
`pmtiles` CLI stays a documented API-host prerequisite (OPERATIONS-MANUAL).
**Dashboard:** marine and seismic maps — light theme unchanged (OSM raster); dark theme =
`protomaps-leaflet` `leafletLayer` over the tiered sources (world under regional under
local), Protomaps dark theme tuned to the current sparse look. **Required content of the dark
basemap (operator, 2026-08-27): water, land/coastline, admin boundaries, place labels, and
FREEWAYS** — the Protomaps `roads` layer's motorway + trunk classes drawn at every zoom of
the regional and local tiers (visible from z7, so the seismic view shows the interstate
network, not just at street zooms); primary roads from z11 in the local tier; nothing
smaller. Marine label overlay (both themes) = a labels-only rule set from the same sources. `CARTO_OSM_ATTRIBUTION` deleted; attribution becomes
"© OpenStreetMap contributors © Protomaps" (About page row already exists). Tile-error
banner logic (M1 fixit constants) kept.
**Also served by this basemap (Q6 + Q5 rulings, 2026-08-27):** the radar/satellite box (M3
RADAR-REBASE — dark base + the labels/outlines layer over satellite) and the surf height map
(M4 — replaces Esri World Topo / NAIP). **Not touched:** wizard/admin maps (OSM raster +
the operator-only Esri satellite toggle).
**Extent consequence, accepted by the operator (directive 14):** detail only inside the
derived box; coarse world baseline beyond it.
**Gate rows (results-free file, stated now):** both maps render in both themes with no
watermark and no blank inside the derived box (screenshots side-by-side vs today's light
theme); **freeways visible on the dark seismic map at its initial zoom and on the dark marine
map at z14** (named roads checked against the light OSM map at the same view — I-405/I-5/
SR-55 for this install); a pan outside the box shows the world baseline, not blank; `grep -r cartocdn`
across dashboard/api/stack = 0; extract sizes within the M0-measured envelope; attribution
string present on both maps; dashboard `tsc` zero errors; vitest for the two components.

### M2 — ~~LIBREWXR-BASEMAP~~ CANCELLED 2026-08-27 (Q6). Text below kept as the record of what was verified in the fork and why the reversal followed.

**Q6 ruling (operator, chat):** "you did not do it wrong, i apologize. So we needed to bring our
own basemap." Verified consequence: LibreWxR is overlay-only and its integration guide tells
every client to supply its own basemap — labels included, since labels are a basemap layer.
Therefore nothing moves into the fork; the radar box keeps a Clear Skies basemap and gets it from
the product basemap (M1/M3). The tile-family design below is NOT built. The fork's own broken
CARTO example page is the fork's business, not this plan's.

**What the fork is (read: `repos/librewxr` CLAUDE.md, AGENTS.md, `docs/web-integration-guide.md`,
`docs/configuration-reference.md`, `src/librewxr/api/routes.py`, `tiles/*`):** a RainViewer-
compatible OVERLAY server. Radar tiles are transparent PNG/WebP squares at
`/v2/radar/{ts}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.{ext}` (only query: `?arrows=light|dark`,
rendered server-side); satellite tiles are opaque imagery at `/v2/satellite/{ts}/{size}/{z}/{x}/{y}/0/0_0.{ext}`;
`LIBREWXR_MAX_ZOOM` = 12; a compute/present split with a byte-capped `TileGeometry` cache
(200 MB single mode) and a per-timestamp warmer; BBOX `LIBREWXR_BBOX` crops regions, satellite
selection and warm lists; memory is tight (container ~3.2 GB resident on the 5.7 GB box).
**LibreWxR has NO basemap concept** — its integration guide tells every client to bring its own
basemap (its bundled `examples/leaflet.html` uses CARTO dark and is broken today too). Nothing in
its pipeline renders ground or labels; nothing in it reads OSM data.

**Design consequences (why "bake it into the tiles" is wrong):** radar tiles MUST stay
transparent overlays — the dashboard fades them (opacity ≤ 0.8) and every RainViewer-style client
expects the same; ground painted into them would fade with the rain and break the public contract.
So the fork gains a **new tile family**, not a change to existing tiles:
- `GET /v2/basemap/{theme}/{size}/{z}/{x}/{y}.{ext}` — OPAQUE ground: land, water, coastline,
  admin boundaries, freeways (motorway+trunk from z≥5, primary from z≥9), place labels;
  `theme` ∈ {`light`,`dark`}; z 0–12 (the fork's max); `size` 256/512 like the other families.
- `GET /v2/labels/{theme}/{size}/{z}/{x}/{y}.{ext}` — TRANSPARENT labels + outlines, for use
  over satellite imagery (replaces the CARTO overlay + ADR-078 outlines in one layer).
- Both rendered server-side from a Protomaps extract of `LIBREWXR_BBOX` (OSM data; `pmtiles`
  CLI or the Python `pmtiles` reader + `mapbox-vector-tile` decode + PIL/numpy raster draw —
  M2.0 picks), cached to disk under `LIBREWXR_CACHE_DIR` (a static layer, NOT the per-timestamp
  geometry cache), pre-rendered for the BBOX at startup/refresh by a separate warmer pass; outside
  the BBOX → transparent/empty tile, never an error. Attribution string added to the catalog.
- Advertised in `/public/weather-maps.json` (additive keys, e.g. `basemap: {light: path,
  dark: path}`, `labels: {…}`) so any client can discover it — the same pattern the fork already
  uses for `satellite.infrared`. Upstream-mergeable: a generic feature, not a Clear Skies hook.

**M2.0 (read-only design round in the fork, BEFORE M2.1):** tile-count and byte arithmetic for
the deploy BBOX (26.75,−129.5,40.75,−105.5) at z0–12; decode/draw cost per tile in Python and the
disk footprint of a full pre-render vs on-demand+disk-cache; memory ceiling; the exact Protomaps
layer/kind values for freeways/boundaries/places at the v4 schema; where the family plugs into
`routes.py` / `warmer.py` / `cache.py` / `config.py` (new `LIBREWXR_BASEMAP_*` settings). Output:
a design block appended here (directive 12) — no code before it.

**M2.1 (implement in the fork) — the companion to M3: everything M3 deletes from Clear Skies is
re-created here as LibreWxR's own output.** Item by item:

| Deleted from Clear Skies by M3 | Re-created in the LibreWxR fork by M2.1 |
|---|---|
| OSM light / CARTO dark base under the radar (`radar-map.tsx` `TILE_CONFIG`) | `/v2/basemap/{light|dark}/…` opaque ground tiles, drawn by the dashboard UNDER the radar frames |
| CARTO `voyager_only_labels` overlay on the satellite view | `/v2/labels/{theme}/…` transparent labels, drawn ABOVE the satellite frames |
| ADR-078 outlines (`GeoFeaturesLayer`) on the satellite view | the same `/v2/labels/…` layer (outlines + labels in one) |
| `[geographic_features] bounds` + admin extract action (API host) | the fork's own extract of `LIBREWXR_BBOX`, refreshed on the fork's schedule — nothing in Clear Skies |

**The one Clear Skies-side change this needs — Q6 (data contract, trigger 4):** the radar
provider capability gains two optional fields, `basemapTileUrlTemplate` (per theme) and
`labelsTileUrlTemplate`, populated by `providers/radar/librewxr.py` from the catalog and null for
RainViewer/iframe; the dashboard's radar box draws them only when present. This is the ONLY way
the box can be "empty Leaflet + whatever the provider sends" AND still show the provider's ground —
the box has to be told the provider sends one. With RainViewer (no basemap) the box shows radar
over nothing, which is the operator-accepted state.

Source data: OSM via Protomaps; not CARTO, not Esri. The fork's own `examples/leaflet.html`
switches from CARTO to the new family in the same round. Gate: the fork serves labelled tiles for both radar and satellite at every zoom
the dashboard requests; memory within budget; C12's seam untouched.

### M3 — RADAR-REBASE (Q6 ruling 2026-08-27; replaces the RADAR-STRIP text below, kept as record)

The radar/satellite box keeps a Clear Skies basemap; only the SOURCE changes, inside the M1
build: `radar-map.tsx` `TILE_CONFIG.dark` CARTO → product basemap dark (Protomaps, same layer
stack as the marine/seismic maps); `TILE_CONFIG.light` OSM raster unchanged; the CARTO
`voyager_only_labels` satellite overlay AND the ADR-078 `GeoFeaturesLayer` outlines → the product
basemap's single labels/outlines layer, drawn above the satellite frames; `SATELLITE_LABELS_URL`
and the direct `/api/v1/geographic-features/tiles` read deleted. The API's standalone
geographic-features feature (endpoints, extract service, admin action, `[geographic_features]`
config) is absorbed into the basemap machinery — one extract family, one endpoint family, one
admin action — ADR-078 → Superseded by this plan. Provider contract untouched: the box still
draws whatever radar/satellite tiles the provider sends, with nothing derived from the provider.
Gate: radar view renders in both themes with no watermark; satellite view shows labels + outlines
from our layer; `grep -r cartocdn` = 0; RainViewer still works.

~~RADAR-STRIP (withdrawn) — original text:~~ Delete from Clear Skies: `TILE_CONFIG` base under the radar map, `SATELLITE_LABELS_URL` +
its TileLayer, `GeoFeaturesLayer` + the `protomaps-leaflet`/`pmtiles` import IN THAT FILE
(the packages stay — M1 uses them), API `endpoints/geographic_features.py` +
`services/geographic_features.py` + settings section + app wiring, stack admin page +
routes, `[geographic_features]` from example configs, ADR-078 → Superseded (by this plan's
PA3), ARCHITECTURE/OPERATIONS/DASHBOARD-MANUAL/API-MANUAL passages. The radar map becomes:
Leaflet container + provider tiles + the provider's alert polygons/wind arrows as today.
Gate: radar view renders the provider's ground+labels (from M2) with nothing of ours under
it; `grep -r geographic.features` across all four repos = 0; RainViewer provider still
works (its own transparent radar over an empty box is the operator-accepted state).

### Gate M

Per round + a phase-close sweep: every map surface, both themes, screenshots side-by-side;
directive 13 grep (no basemap/label/outline code path reachable from the radar component);
attribution audit; DASHBOARD-MANUAL §12 rewritten to the as-built.

---

## PHASE S — surf system (repos: marine, api, dashboard)

### S0 — Q17 push + live gate (owed now)

On the operator's "push": push marine + meta → `scripts/deploy-marine.sh` → post-deploy
journal sweep. **Gate (stated before looking):** the first 00Z cycle after the gatherer has
fetched a GFS cycle to f108 — `ww3Horizon.lastSuccessCycleTime` = that cycle,
`coverageEndTime` = cycle + 96 h, `wallClockS` ≤ 5 h, no overlap with the 06Z production
run (`ExecMainStartTimestamp` and run timestamps pasted); the following full cycle shows
`fullRun.l2BoundaryExhausted: false` and zero "data on boundary file exhausted" lines in
SWAN L2's PRINT; the served dominant partition varies beyond ±0.02 m / ±0.05 s across
hours 7–72 when NOAA's forecast varies (EVO-Q16 acceptance (ii)); +24 h / +48 h reality
rows vs NDBC as those hours arrive.

### S1 — C6 seam-fidelity ledger row (PA5)

Design per EVO-Q16 C6: one SWAN L2 SPECOUT point just inside the L2 boundary on the WW3
side; per cycle, the ledger row gains `seam: {ww3_handed: {hs, tp, dir per band},
swan_absorbed: {…}, band_ratio}`; labelled model-vs-model in the ledger and in
OPERATIONS-MANUAL monitoring. Gate: row present every cycle; band agreement within a
tolerance stated before looking (recommend ±10 % Hs per band, the interpolation error class
of BOUNDNEST3); a deliberate mirrored-boundary mutation in a scratch run is CAUGHT by the row.

### S2 — CONSISTENCY-SCORING (PA6; blocked on Q3)

Inputs on record: brief `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md`
§3.2/§3.3/§4.3/§7; verification deliverables `WAVE-GROUP-FORMULAS-VERIFICATION-2026-08-23.md`
(Kimura 1980 route, Tm02 lag) and `PARTITION-NARROWNESS-SURVEY-2026-08-23.md` (ν ≈ 0.17 /
κ ≈ 0.59 dominant groundswell; ν ≈ 0.53 windsea; half-way band rule). Sequence: ADR-101
row-5 amendment (Proposed → operator) → coding brief (parse-time group statistics attached
per partition in `swan_runner.py` ~:3900–3974; scorer reads scalars) → KATs against the
V1 worked numbers → firewalled gate → deploy → reality row (a groundswell day and a windsea
day ranked as the operator expects).

### S3 — Substitution cleanup (PA7; C7 survivor, C19, C20)

One deletion round in the marine repo (dead-key grep proofs in the brief): `ww3_chain_enabled`,
`level1` rename, `_reused_l1_boundary_command_lines()` + the stationary-fill dependence on
`level1/INPUT`, the `ww3_boundary` required-input entry in health, the on-disk `swan/level1/`
directory (operator-visible before deletion), and the hotstart-age gate (the health/refuse
design's last V14 item). One doc round: PROVIDER-MANUAL:2529 swell-card bullet, API-MANUAL
§17 `swellSource` + `closeoutFraction`, ADR-109 G7 row struck as built. C7's other two items
and C8 are already in HEAD (`43744de`, `de2738f`, `09c0a1b`) — nothing to do.

### S4 — Test-debt triage (C13)

Scope (re-verified 2026-08-28, Windows run: 18 failed / 36 passed across the four named
files): `test_serve_nothing_on_failure.py` (8 — L4-nesting harness class) and
`test_service_full_run_trigger.py` (10 — the WW3-chain-unconditional change). `test_h4_chunked_json`
and `test_double_break_transect55_kat` passed and leave the row; the wind-gatherer cold-start
test is a Windows-path artefact, not a defect. One brief: for each class, the lead's ruling
(repair harness to current design / delete a pin of superseded behaviour / keep with a
probe-keyed skip) with the reason; test-author implements; nothing in production code moves.
Baseline count before, count after.

### S5 — First-install WW3 warm-start bootstrap (C17)

Design (EVO-Q9 option 2): the install procedure drops a provenance note beside the
restart file; the service accepts it once; ADR-109 D10 amendment. Not needed for this
install; required before any fresh install.

### S6 — ~~ADR-109 gap closure~~ DISSOLVED 2026-08-28 (Q9)

Plain English record: ADR-109 (the decision record for our own deep-water model) listed three
unfinished things when it was accepted. (1) Putting the gathered wind onto the model's grid —
built; the daily 96 h run uses it (`service.py:831`). Closes with one ADR line, in S3's doc
round. (2) Rebuilding the model's grid file when the grid changes — NOT built; the service
refuses on a geometry change (`service.py:938–947`) and the live grid file was hand-made on
2026-08-18. The island round (S8.1) changes the grid, so it builds this hook — same task, not a
separate one. (3) A crash hit while trying a sensitivity test — a note about a test that could
not run, not a defect in the running model; stays a note in ADR-109.

### S7 — ~~Live-chain validation campaign~~ DROPPED 2026-08-27 (Q1)

**Ruling (operator, chat):** "THIS IS ALL TESTING... NO ONE IS ACTUALLY VISITING THE SITE." No
formal campaign, no ceremony gate; the per-cycle buoy ledger stays on as the standing
instrument and the operator judges the site directly. Phase L's opening is the operator's call.
Text below kept as record only.

The predecessor's V1–V4 assumed a shadow chain beside a serving SWAN-L1. Since CHAIN-SERVES
(2026-08-19) the WW3 chain IS production and SWAN L1 no longer exists, so "cut over / hold
shadow" is moot. Proposed replacement (Q1): ≥10 consecutive cycles of the buoy ledger
(already written every cycle) summarised as model/buoy ratios per band + direction + period;
the three deficit lines measured on the live chain (wind-sea band, S-swell island lee,
W-band source); served-quality vs Surfline for the same hours; the C1 eyeballs; an
"accurate and defensible" ruling by the operator that opens Phase L. Results-free Gate V
file written before the campaign starts.

### S8 — Island shadowing (C15) — LAST

Research brief first (reconstruction lobe width σθ 15° vs measured 27–31°; diffraction;
Catalina/San Clemente lee at the S edge), with the cliff KAT as the instrument; operator
ruling; nothing dispatches before S1–S7 close and Q2 is answered.

**S8.1 — Partially-land cells: WW3 transparency field on G1 (operator direction 2026-08-27:
"it should also apply to cells that are not 100 percent island … so you are not OVERCOUNTING
an island when you may only have the tip in the grid").** Verified state today
(`swan_domain.py:3153–3179`, `:3295–3313`; ADR-109 D3 table): the production G1 grid runs
`FLAGTR=0` — no obstruction information — and every 1 km cell is called wet or dry from the
ONE ETOPO 15″ (~460 m) sample nearest its centre (`_ww3_nearest_source_depth`, round-to-
nearest index; dry iff that sample ≥ 0). A coastline cell is therefore all-block or all-pass
on the luck of which sample sits at its centre: island outlines are quantised to the 1 km
grid and jitter ±½ cell, over-counting on some edges and under-counting on others; a tip
covering 20 % of a cell is either a full wall or absent. The only transparency field ever
built was for the rejected 4 km G2 (`FLAGTR=2`, mean 0.854; `scratch/REFERENCE-gen_grids.py`
"obstruction-fraction generator").
**WW3's own mechanism (manual §3.4.7, :6722–6793; codes :15349–15363; file grammar
:15927–16018):** `&MISC FLAGTR = 2` = transparencies AT CELL CENTRES, read as a second field
in `ww3_grid.inp` after the depths (same unit 10, own scale factor, `NX*NY` values). For a
cell of transparency τ, inflow through its upstream face is 0.5(1+τ), outflow 1, and the next
cell's inflow 2τ/(1+τ), so the product across the cell is exactly τ; consecutive partial cells
multiply. Regular grids only (ours is). No compile switch — grid-preprocessor only.
**Design (executes S8.1's block verbatim; a deviation is a finding):**
1. At WW3 setup derivation (`derive_ww3_setup()`, config-time, PRIME DIRECTIVE 11), compute
   per G1 cell the **open-water fraction** `f ∈ [0,1]` = share of fine-source samples inside
   the cell's footprint with depth < 0. Fine source = the finest regional DEM already cached
   for the region (NCEI ~90 m CRM / ~10 m regional DEM where present; ETOPO 15″ only as the
   fallback — at ~460 m it yields ≤ 4–5 samples per cell, i.e. steps of ~0.2, disclosed).
2. Land/sea mask becomes fraction-based: cell is DRY iff `f ≤ F_DRY` (named constant,
   proposed 0.05 — operator to confirm), WET otherwise; wet cells carry transparency `τ = f`
   (F_DRY < f < 1 → partial; f = 1 → 1.0). The S-row/W-column boundary-cell wet test reads
   the same mask (no second criterion).
3. `ww3_grid.inp` gains `FLAGTR = 2` in `&MISC` and the transparency field block (scale
   factor 1.0, same IDLA/IDFM conventions as the depth block, SYNTAX row 6a); `mod_def.ww3`
   rebuilt (geometry-change trigger — S6's G10 gets exercised for real here).
4. KATs: (a) a hand-built 3×3 fine grid with a known tip → exact f per cell; (b) a synthetic
   island whose true area is known → summed f × cell area reproduces it to < 2 % while the
   old nearest-sample mask errs by its measured amount; (c) transfer-file byte-identity for a
   region with no partial cells (guards the depth block); (d) a real G1 derivation diff:
   count of cells that flip dry↔wet and the distribution of τ, pasted.
5. Reality gate (stated before looking): S-swell (<0.1 Hz) model/buoy ratio at 46222/46253
   vs the standing 0.56–0.60×; the cliff-KAT seam aggregate vs 0.578 m; direction unchanged
   within ±5°. Improvement expected but NOT assumed — the lobe-width and diffraction items in
   S8 remain separate.
**Triggers:** 1 and 3 (obstruction input to the propagation scheme; wet/dry criterion) —
authorized by the operator's chat direction above, recorded as PA8. **Ordering:** S8 is
operator-ordered LAST; S8.1 is mechanical and manual-native, so it CAN run ahead of the S8
research if the operator says so → Q7.

### S9 — ~~Inherited-queue reconciliation~~ REMOVED 2026-08-27 (Q2: "NO NO NO, keep that crap out of here. Let's chat separately about that")

The other plans' open rows (C9–C11) are not tracked by this plan. Text below kept as record only.

For every row in the L1-BOUNDARY-REBUILD, SURF-REMEDIATION, SURF-PHYSICS-REMODEL,
MARINE-FORWARD and EYEBALL-FIX plans still marked open: verify against the live code and
the deploy record whether it was closed by a later round, is still open, or is moot after
the L1 → WW3 substitution. Deliverable: `scratch/S9-INHERITED-QUEUES.md` + Q2 rewritten
with the survivors only. Those plans are then marked CLOSED with a pointer here.

---

## PHASE D — as-built docs (after M and S)

D1: ARCHITECTURE.md, the four manuals, ADR-078 (Superseded), ADR-101 (row-5), ADR-109
(gaps closed, D10 bootstrap), CHANGELOG — re-synced to the as-built state; zero-drift audit
by a firewalled auditor; the `docs/planning/` directory reduced to this plan + briefs.

## PHASE L — lookup tables (LAST, unchanged)

Opens only on the operator's "accurate and defensible" ruling from S7. Mandatory reading
before ADR-110: `docs/reference/LUT-INTEGRATION-RESEARCH-2026-08-17.md`.

---

## Round-close & bookkeeping (every round)

rules/verification.md round-close gate, rules/coordinator.md §2 acceptance gate and §7
deploy discipline apply unchanged. Each round: results-free gate file in `scratch/`,
firewalled auditor, lead reproduces every number, checklist row updated in the closing
commit, CURRENT STATE updated every session, lessons routed per CLAUDE.md "Capture lessons
in the right place". Deploy only on the operator's word "push"; deploy is a separate
authorization from commit.

---

## OPEN OPERATOR QUESTIONS

### Q9 (2026-08-28) — ✅ RULED: carry-over register re-audit. Operator: "i am very nervous about all of the carry over tasks without going through each one and assessing what has been done and if it is still needed." Rulings, verbatim: "c1 drop c2 drop c5 again these were discussed, the fact that you did not mark that is disconcerting c6 if this was done why did you not mark it complete? geesh." / "c14 no" / "c12 has nothing to do with this plan" / "why c15 is needed if we replaced it with a new task" / C16 dissolved after a plain-English explanation. Lead findings the same pass: C7 ×2/3, C8, C18 already done; C3, C4 moot; C13 re-verified at 18 failures in two files; C19/C20 confirmed live. Register rewritten; S6 dissolved; S3/S4 rows corrected. Also disclosed: nothing is watching the marine service for failures now (the old monitor died with its chat session).

*(Plain English, self-contained, newest at top. Answered items keep their ruling here.)*

### Q8 (2026-08-27) — the radar box spans SoCal to New Mexico; the derived basemap box is ~230 km. How do we cover the dark radar view without reading the radar provider's extent?

Operator: "the radar box will blow all of our other sizings out the window as it covers most of
the SW well into New Mexico." Directive 14 forbids sizing anything from the provider. Options:
- **(A) Raise the world baseline tier from zoom 0–6 to zoom 0–8, for everyone.** Worldwide, so it
  depends on nothing local; at zoom 8 (~600 m/pixel) a regional radar view shows states,
  coastlines, cities, interstates. Detail beyond zoom 8 only inside the derived box. Cost is a
  bigger one-time world extract — M0 measures it (expected hundreds of MB, not GB); if it measures
  badly, zoom 0–7.
- **(B) Dark theme for the RADAR box only = the light OSM raster tiles darkened in the browser**
  (a CSS invert/hue-rotate/desaturate filter — a standard Leaflet trick). Worldwide, no extract,
  no sizing, available today; marine/seismic keep the Protomaps dark basemap. Downside: it shows
  every street, so the radar's dark view is busier than the other dark maps, and it rides on OSM's
  tile server (which we already use for light).
**Recommendation: (A)**, with (B) as the fallback if the world extract measures too large.
**Ruling needed:** A, B, or both (A for everything, B until A ships).

### Q7 (2026-08-27) — ✅ RULED "q7, run now." S8.1 dispatches now; `F_DRY = 0.05` stands (stated default, not objected to).

*(original question)*

Today every 1 km WW3 cell is all-land or all-water from one ~460 m bathymetry sample at its
centre, so island edges are quantised to the grid and a cell holding only an island's tip
is either a full wall or nothing. You said it should be fractional. WW3 supports exactly that
(`FLAGTR = 2`, transparency per cell; manual §3.4.7): a cell that is 20 % land passes 80 %.
S8.1 designs it: open-water fraction per cell from the finest DEM we already cache, cells
below a small floor (`F_DRY`, proposed 0.05) stay dry, everything else is water with its
fraction as transparency. It's mechanical and manual-native, but it is part of the island
problem you ordered LAST. **Ruling needed:** (a) run S8.1 now as its own round (after the Q17
push), or (b) hold it inside S8. Also confirm `F_DRY = 0.05` or give a number.

### Q6 (2026-08-27) — ✅ RULED: "Ok wait, so you did not do it wrong, i apologize. So we needed to bring our own basemap. Did we need to bring our own legends too or do those need to move into librewxr?" — Answer recorded: yes, labels too — a radar provider's contract is overlay-only, labels are a basemap layer, so both stay in Clear Skies from the product basemap. M2 cancelled, M3 becomes RADAR-REBASE, directive 13 amended, the two capability fields are NOT added.

*(original question)*

Verified in the LibreWxR fork's own docs and code: LibreWxR serves only transparent radar
overlays and opaque satellite imagery; it has no basemap of its own and tells every client to
bring one. Painting ground into the radar tiles would break the RainViewer-compatible contract
(radar must stay a fade-able overlay). So M2 gives the fork a new tile family — `/v2/basemap/…`
(opaque ground + freeways + labels, light/dark) and `/v2/labels/…` (transparent labels +
outlines for over satellite) — advertised in its catalog like satellite already is.
For the dashboard's radar box to draw them, the radar provider capability needs two optional
fields (`basemapTileUrlTemplate` per theme, `labelsTileUrlTemplate`), filled by the LibreWxR
provider module from the catalog, null for RainViewer/iframe. The box draws them only when
present — Clear Skies still derives nothing, decorates nothing; it just stacks what the provider
sends. **Ruling needed:** approve the two fields (recommended), or rule that the box shows
radar/satellite over nothing even when the provider offers ground.

### Q5 (2026-08-27) — ✅ RULED: surf height map → "a regular basemap" (the product basemap); NAIP "eliminated completely from user facing work"; the wizard's Esri satellite toggle stays ("I just do not want to use it in user facing situations when we do not have to"). → M4, PA9, directive 15.

*(original question)*

Esri World Topo tiles became the surf height map's background yesterday (IMAGERY-MAP,
API `a5e45a9`, config `[imagery] provider = map`), and the wizard's marine step has an Esri
World Imagery satellite toggle. Both are browser-direct (the API never caches their bytes),
non-commercial, no key. Your "NO ESRI!" today was about basemaps. **Ruling needed:** leave
these two as they are, or replace them too (with what — the NAIP aerial provider is
public-domain but was rejected for its abnormal-low-tide photography; a Protomaps-rendered
topo is not photography).

### Q4 (2026-08-27) — ✅ RULED: REVERT. "I have tested that over the past two nights and we actually need to revert the change. Just because we hit the right conditions, we are rarely getting the fog formed so we are crying wolf most of the time which is why we had the provider check there." → S10 FOG-REVERT (PA10); the uncommitted API-MANUAL edit was discarded (`git checkout`) the same hour.

*(original question)*

An edit to API-MANUAL's fog cross-check section has sat uncommitted in the working tree
since 2026-08-24. It documents code that is already live (API `1ad6e74`, `f2c5ecd`: the
provider cross-check now applies only at night and only in the 1–4 °F dewpoint-depression
band; ≤ 1 °F is fog on the station's own reading). Every doc-sync since has stepped around
the file, which now also blocks the `swellSource`/`closeoutFraction` additions to §17.
**Ruling needed:** commit it as written, or tell me what's wrong with it.

### Q3 (2026-08-27) — ✅ RULED: "yes as that is what is in code correct?" — A–E accepted as recommended. CORRECTION recorded back to the operator: it is NOT in code yet; the scorer runs the interim swell-dominance bucketing, and this ruling authorizes the S2 coding round.

*(original question)*

On 2026-08-23 the coordinator put five sub-decisions to you in chat after the V1/V2
verifications; the plan row says "rulings to be recorded here when given" and nothing was
recorded before SurfBeat removal and Q15/Q16 took over the session. Restated, with the
lead's recommendation each:
- **A — set-wave threshold:** H > H1/10 (matches the code's existing set-wave definition;
  gives T_set ≈ 7.6 min on the measured groundswell, spanning the graded curve) rather than
  H > Hs (saturates at ~2.6 min).
- **B — waves-per-set term:** the Kimura theory yields 1–3 waves above threshold per run at
  every threshold, so the brief's 3–6 waves-per-set curve cannot be fed by it → drop the
  waves-per-set term (timing weight 1.0 on the interval curve) rather than invent a mapping.
- **C — partition band rule:** half-way-between-peaks (recovers 0.92–1.17 of each
  partition's own energy in the survey).
- **D — data path:** compute the group statistics at parse time where the spectrum exists
  and attach scalars per partition (no 2-D arrays attached).
- **E — formula route:** Kimura 1980 Markov + Battjes–van Vledder κ at lag Tm02 (verified),
  not the unreachable Longuet-Higgins closed form.
**Ruling needed:** accept all five as recommended, or say which differ.

### Q2 (2026-08-27) — ✅ RULED: "NO NO NO, keep that crap out of here. Let's chat separately about that." S9 removed; C9–C11 marked out of this plan.

*(original placeholder)*

Placeholder: S9 lists, for each still-open row of the L1-BOUNDARY-REBUILD, SURF-REMEDIATION,
SURF-PHYSICS-REMODEL, MARINE-FORWARD and EYEBALL-FIX plans, whether it is closed by later
work, still open, or moot — and the UNVALIDATED items (C5: L4/1-D deep-ledge handoff loss;
5° nearshore directional resolution; C6: Phase T close nod). You rule per survivor.

### Q1 (2026-08-27) — ✅ RULED: "THIS IS ALL TESTING... NO ONE IS ACTUALLY VISITING THE SITE." No campaign; S7 dropped; the buoy ledger keeps running; Phase L's opening is the operator's call.

*(original question)*

The previous plan's Phase V was written for a WW3 chain running in shadow beside a serving
SWAN-L1, ending in a "cut over / hold shadow / extend" ruling. Since your 2026-08-19 order
the WW3 chain IS the production pipeline and SWAN L1 is deleted, so there is nothing to cut
over from. **Proposed:** replace V1–V5 with S7 as written above — ten consecutive cycles of
the buoy scorecard, the three deficit lines measured live, served-quality vs Surfline, your
C1 eyeballs — ending in a single "accurate and defensible" ruling that opens Phase L (or
sends the deficits back for work, S8 first). **Ruling needed:** accept that framing, or say
what the campaign must measure instead.
