# Marine & Maps Plan — finish the surf system, fix the maps (2026-08-27)

## START HERE — what this plan is and how to read it

**What we're doing, one paragraph:** Two threads, one document. **Maps:** CARTO, the company
whose free map tiles every dark-theme map in the product used, started watermarking them
"API KEY REQUIRED" on ~2026-08-25 and is retiring the product. The fix is three rounds, all
ruled by the operator in chat on 2026-08-27: Clear Skies gets its own product basemap (OSM
light kept, Protomaps dark from an extract we serve ourselves) for **every Clear Skies map box
— marine, seismic, radar/satellite, and the surf height map** (Q6: radar providers are
overlay-only, so the radar box keeps a Clear Skies basemap AND labels, sourced from the product
basemap instead of CARTO; nothing moves into the LibreWxR fork; Q5: Esri/NAIP leave every
user-facing surface). **Surf:** the WW3 → SWAN → SwellTrack chain is live and serving, but a
list of things is still owed — the forecast beyond +6 h only becomes real once the Q17 fix
deploys and its gate passes; the seam-fidelity ledger row (C6); the consistency score the
operator approved in Q14 but that was never coded (Q3 re-ask pending, Q10); stale docs and
naming left by the L1 → WW3 substitution; test debt; the first-install warm-start mechanism;
and — **operator-ordered LAST** — the island-shadowing energy deficit, whose first mechanical
piece (S8.1) the operator ordered run now. No validation campaign (Q1). The lookup-table phase
(Phase L) stays last, unchanged. **Adversarially reviewed 2026-08-27
(`scratch/ADVERSARIAL-PLAN-REVIEW-2026-08-28.md`, 26 findings) — corrections applied the same
hour; the items needing an operator ruling are collected in Q10.**

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
| M0 | Map extent inventory + extract-size measurements (read-only) | ✅ DONE 2026-08-27 — `scratch/M0-MAP-EXTENTS.md`; lead reproduced the four sizes on weewx. world z0–6 **42.8 MB** (≤ 100 MB ✓); local z7–15 union box **513.6 MB** (> 400 MB ceiling → **Q12 finding**, not a re-fit); radar z0–12 **195.1 MB**; marine box alone z15 3.1 MB. Union box = seismic box (marine nests inside). `protomaps-leaflet` 5.1.0 + `@protomaps/basemaps` 5.7.2: flavors LIGHT/DARK/…; labels-only = `labelRules(namedFlavor('dark'),'en')` + `paintRules: []` |
| M1 | **CS-BASEMAP** — Clear Skies product basemap for EVERY Clear Skies map box (marine, seismic, radar/satellite, surf height map): OSM light kept, Protomaps dark + labels layer from a self-served extract, CARTO removed | 🔄 2026-08-27 — **M1-API ACCEPTED** (gate PASSED 13/13 after F1/F2 fixes; 41 tests); **M1-STACK ACCEPTED** (`065ac62`, 22 tests); **M1-DOCS ACCEPTED** (ADR-078 Amendment 2 Proposed → operator, journal J3); **M1-DASH dev+test CLOSED OUT** (dashboard `eb7c915`…`43afaee` + tests `47ac0e5`…`c183473`; meta DASHBOARD-MANUAL `0397b897`; lead reproduced tsc 0 / vitest 27 passed / CARTO greps empty / renders inspected) — **Gate M1-DASH auditor running** (`scratch/GATE-M1-DASH-DEFINITION.md`). M3 radar rebase landed inside M1-DASH (`ec27bfd`). Remaining under M1: surf height map = M4 |
| M2 | ~~LIBREWXR-BASEMAP~~ **CANCELLED 2026-08-27 (Q6 ruling)** — LibreWxR, RainViewer and every radar provider are overlay-only; the client brings the basemap AND its labels, so nothing moves into the fork. Kept as a row so the reversal is on record | ✅ closed-no-work |
| M3 | ~~RADAR-STRIP~~ → **RADAR-REBASE** — the radar/satellite box keeps a Clear Skies basemap; only its SOURCE changes: CARTO dark → product basemap dark; CARTO satellite labels + ADR-078 outlines → the product basemap's labels/outlines layer; the standalone ADR-078 feature is absorbed into M1's basemap machinery (one extract family, one endpoint family) | ⬜ RULED 2026-08-27 (Q6) — part of the M1 build |
| M4 | **SURF-MAP-BASEMAP** — the surf height map's background becomes the product basemap (light OSM / dark Protomaps); Esri World Topo (IMAGERY-MAP) and NAIP removed from every user-facing surface; the wizard's Esri satellite toggle STAYS (operator-only, not user-facing) | 🔄 **M4-API landed 2026-08-27** (API `f4a42a7`, `87924c9`, `07e0322`, tests `39cd51a`; meta `897a79b3` openapi Imagery paths — a pre-existing contract gap closed; API-MANUAL §12a as-built): `/imagery/config` always answers `provider: "basemap"` (light OSM template + dark `basemap/local` tier, zoom 0–19), never 404s; `[imagery] provider` values are ignored with one startup WARNING (modules/key/admin/wizard stay — Q10-6 open). Lead reproduced **56 passed**. **M4-DASH dispatched 2026-08-27** (dashboard-dev + test-author; 98 vitest passing per the test-author's status, closeouts pending); Gate M4 file `scratch/GATE-M4-DEFINITION.md`. **M4-B IMAGERY-REMOVAL dispatched 2026-08-27** (Q10-6 ruled "get rid of it": API imagery modules + `/imagery/tiles` + `[imagery]` key + admin section + wizard selector removed; `/imagery/config` and the marine-step satellite toggle stay; brief `M4B-IMAGERY-REMOVAL-BRIEF-2026-08-27.md`; gate `scratch/GATE-M4B-DEFINITION.md`) |
| Gate M | Adversarial gate per round + one end-to-end row (every map surface rendered in both themes, screenshots side-by-side) | ⬜ |
| S1 | **C6 seam-fidelity ledger row** — WW3-handed vs SWAN-absorbed at the L2 boundary, every cycle | ✅ **ACCEPTED 2026-08-27 — Gate S1 PASSED 11/11, 0 findings** (auditor's own fixtures through the real writers/parsers, `scratch/gate-s1/probe_seam.py`; lead re-ran it: hs_ratio 0.9997–1.0262 across bands, dir_diff ≈ 0.0006°, mirrored-axis drill → 180.0°, ×0.8 scale → 0.8944 and flagged, missing/garbage `SPEC_SEAM.txt` → named errors, row never skipped). Live rows held until push. Code + KATs landed (marine `3958c7d`, `a3c6437`, `dd62663`; KATs `a638026`, `4595303`; meta docs `b4c23419`): `SEAM` output point one L2 cell inside the most seaward `L2P####` transfer point; ledger schema 3 with the `seam` block (bands < 0.09 / 0.09–0.20 / > 0.20 Hz, `hs_ratio`, `dir_diff_deg`, `within_tolerance`, `error`); row always written. Finding: the two real writers store the frequency axis at 4 vs 6 significant figures → a ≈0.3 % `hs_ratio` noise floor (documented; KAT tolerance 5e-3). Lead reproduced **7 KATs + 334 passed / 1 skipped**. Adversarial gate `scratch/GATE-S1-DEFINITION.md` dispatched; live per-cycle rows held for the push |
| S2 | **CONSISTENCY-SCORING** — code the Q14-approved set-timing/set-amplitude definitions into the surf score (ADR-101 row-5 amendment first). NOT in code today — the scorer still runs the interim swell-dominance bucketing | ⏸ APPROVED 2026-08-23 (EVO-Q14); sub-decisions A–E **NOT ruled** — the Q3 "yes" rested on a false "it's in code" premise (review #4); re-asked as Q10 item 1 |
| S3 | **Substitution cleanup** — CORRECTED after the adversarial review: `_reused_l1_boundary_command_lines()`, the `swan/level1/` directory and `ww3_chain_enabled` are LIVE dependencies (production L2 scaffold; buoy-ledger gate) and are NOT deleted. Remaining: `level1` label rename (cosmetic), the health `ww3_boundary` entry (record it or remove it — Q10), doc corrections (ARCHITECTURE.md:130/132 wrong "no-op"/"vestigial" claims + gap rows #12–#16, PROVIDER-MANUAL:2529 swell-card bullet, API-MANUAL §17 `swellSource` + `closeoutFraction`, ADR-109 G7 struck, D14 item 2 disposition), hotstart-age gate (Q10: drop or own row) | ✅ DONE 2026-08-27 except (b) — (a) doc round landed (meta `60738f16`, `d4e89b87`, `16dfe52e`, `5422800a`, `1d56f7a8`; lead corrected one over-claim the same hour: the chain path and scaffold reuse are unconditional, the flag gates ONLY the buoy-ledger writers); (c) `ww3_boundary` recorder landed (marine `ee406a7`, guard tests `d6d4a1e`, lead reproduced 23 passed; Q10-7); (d) dropped (Q10-5). **(b) the `level1` label rename is deferred to after S8.1 closes** (170 occurrences across the files three concurrent rounds are editing — the last marine code round of the plan) |
| S10 | **FOG-REVERT** (API) — revert the 2026-08-24 fog cross-check narrowing (API `1ad6e74` + `f2c5ecd`): two nights of live testing showed the night-time standalone ≤ 1 °F rule cries wolf (conditions right, fog rarely formed); the provider cross-check returns at every level, as before. The uncommitted API-MANUAL edit documenting the narrowing is discarded | 🔄 CODE DONE (API `96bec7b` + `cf0318d`, local `git revert`s; `tests/test_fog_provider_crosscheck.py` 68 passed on Windows — host run owed after deploy; CHANGELOG entry NOT yet written) — **awaiting operator "push"** |
| S11 | **INVARIANT-1** — health is `degraded` since the BREAK-REFORM deploy (08-26 09Z; ~7,600 firings): (1) read-only look at where BREAK-REFORM now places the outermost break marker relative to the per-transect handoff (untided terms), and what in `57af5d6` moved it; (2) then fix the check to compare like with like (tided break depth vs tided handoff, or both untided) with a guard test that fails pre-change | 🔄 (1) DONE 2026-08-27 — `scratch/inv1/S11-FINDINGS.md`: firings began at the `57af5d6` deploy hour (0/day before); the check adds tide to one side only (bug); AND the primary marker now sits at the beach model's first node in 37 % of transect-hours (10.7 % before), median distance from handoff 0.90 → 0.41 m — the roller-based cessation keeps a boundary-started zone alive so its first dissipation step becomes the marker. Options A/B/C → **Q11**; (2) waits on Q11 |
| S12 | **HANDOFF-RESTART** — the beach model's handoff is set dynamically WITHIN the cycle: run the 1-D from the formula's station; if its first break lands on (or within the margin of) its own starting node, step the handoff one SWAN band station seaward and re-run, until the first break is interior or the band's deep end is reached (then refuse loudly for that transect-hour). SWAN's per-transect band tables already carry Hs/Tp/Dir + partitions at every 10 m station, so no SWAN re-run. Absorbs the invariant-1 tide-datum fix (S11-2) | ✅ CLOSED LOCALLY 2026-08-27 (live rows held for the push) — **adversarial gate PASSED 13/14** (G5 tide sub-case partial: code-verified at both sites + clearance leg empirically; KAT (a1) covers the tide dimension on real data — tide +0.70 m, invariant quiet); the auditor independently confirmed the fca09ec fix through `run_pipeline()` and ruled out marker-suppression (G13) and the T4B.4 no-band path (G14). Marine `47254a2`, `7174e65`, `69167aa`, `3f489e1`, `a29acf7`, `9743500`, **`fca09ec`** (KATs `4eb9cca`; meta docs `eee239be`: ARCHITECTURE/PROVIDER-MANUAL/API-MANUAL/ADR-093 Amendment 9 Proposed). Ruling mid-round: the loop is per TRANSECT-hour (see design block). **The KATs caught a real defect:** the production call site never passed the two new kwargs, so the loop was silently disabled and an exhausted transect would have been served — fixed `fca09ec`. Lead reproduced 5/5 KATs and the regression set at the pre-existing 14-failure baseline (366 passed). Live reality gate (item 6) waits on the push |
| S4 | **Test-debt triage** — two test files, 18 failing tests (`test_serve_nothing_on_failure` 8, `test_service_full_run_trigger` 10; re-verified 2026-08-27), one ruling per class (repair harness / delete stale pin / keep) | ✅ DONE 2026-08-27 — marine `e7e917a`, `e2e3809` (+ expanded to the same-class adjacent failures `b0af6ec`, `3785f44`): 1 Class A delete (the SWAN-L1 convergence test, superseded by `3c550ae`), 21 Class B harness repairs (`chain=`/`l1_nest_source` fixtures; WW3-leg + chain-spec stubs), 0 Class C; 18→0 failed in the original two files, 4→0 in the two adjacent; lead reproduced **51 passed, 0 failed** across the five files. Assertion intent unchanged. **S4b DONE 2026-08-27** (marine `3fdea40`, `8f2dee1`, `079a8fc`, `4c1b0c3`, `4810294`): the 14 `tests/services` failures + one in `test_service_vchain_trigger.py` — 7 Class A deletes (pins of the pre-CHAIN-SERVES `boundnest1` default, the SWAN-L1 legacy fill path, and the "leg is a no-op when the flag is off" guard, all removed by `3226723`/`3c550ae`), 7 Class B harness repairs (assertions byte-identical), 1 Class D probe-keyed skip (Windows: no `/etc/weewx-clearskies`), 0 Class C; lead reproduced **`tests/services` 323 passed / 1 skipped / 0 failed**. The marine model's own suite is now clean on this checkout |
| S5 | **First-install WW3 warm-start bootstrap** — the durable mechanism EVO-Q9 parked as a pre-ship row | ✅ DONE 2026-08-27 (marine `dcec2d8`, `a1e4113`, tests `85c45e8`; meta `41c81662`: OPERATIONS-MANUAL "First install — WW3 warm start" step + ADR-109 D10 amendment Proposed). `restart_<token>.provenance.json` beside the restart file is accepted ONCE (age gate still applies), consumed after the leg succeeds; mismatch/no note → today's refusal byte-identical. Three guard tests (pre-change transcript via `git show`); lead reproduced **63 passed** across the leg/trigger/health suites. Not needed for this install — it is the fresh-install path |
| S6 | ~~ADR-109 gap closure~~ **DISSOLVED 2026-08-27 (Q9)** — G7 is built (one-line ADR edit → S3); G10 (`ww3_grid` rebuild hook) is part of S8.1; D14 stays a note | ✅ closed-no-work |
| S7 | ~~Live-chain validation campaign~~ **DROPPED 2026-08-27 (Q1: "THIS IS ALL TESTING... NO ONE IS ACTUALLY VISITING THE SITE")** — no formal campaign, no ceremony gate. The per-cycle buoy ledger keeps running as the standing instrument; the operator checks the site as they see fit; when Phase L opens is the operator's call, not a gate this plan computes | ✅ closed-no-work |
| S8 | **Island shadowing** — the S-swell <0.1 Hz 0.56–0.60× deficit (narrow reconstruction lobe σθ 15° vs measured 27–31°, no diffraction, Catalina lee). **S8.1 (transparency field) ordered first (Q7 "run now")**; the rest (lobe width, diffraction) stays LAST | 🔄 2026-08-27 — Q10-2/-3 ruled (PA8). **S8.1-PRE landed** (`scratch/S8.1-PREFLIGHT.md`). **S8.1-A ACCEPTED** (marine `2b492e5` CRM Vol.6 resolver, `42260b3` `ww3_grid_files.py`, `3a49fa9` `derive_ww3_setup(fine_dem=)` FLAGTR=2, `270be88` caller wiring, `1e3cd7a` CHANGELOG; KATs a–d `4691356` + harness mock `c19da47`→ fixed `8fd5a24` (mock had patched the wrong binding — real CRM fetch ran in tests; caught by the dev); meta `0116037c` ADR-109 amendment Proposed + PROVIDER-MANUAL + ARCHITECTURE. Lead reproduced **38 passed**; KAT (d) on the real G1 box: today 3,433 dry / 21,020 wet → CRM-fraction 3,237 / 21,216; flips dry→wet 198, wet→dry 2; CRM-depth override cells 198). **S8.1-B dispatched** (brief `docs/planning/briefs/S8.1B-GRID-REBUILD-HOOK-BRIEF-2026-08-27.md`: the G10 hook in `_run_ww3_leg`, `mod_def.provenance.json`, `derivation_sha256` over deck + NAME files, `ww3_grid_rebuilt_cold_start`, health fields, OPERATIONS-MANUAL procedure). Gate S8.1 (T1–T14) after B. S8 rest (lobe width, diffraction) stays LAST |
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
Q17 fixes (2) and is committed locally, awaiting "push". (3) **Health is `degraded`:**
`invariant fired: 1:break_depth_le_handoff_depth` — 130 firings, last 2026-08-27T05:38Z,
Huntington transects 4–7: "break depth 2.15–2.20 m > handoff depth 1.98–2.17 m for partition 0
(11.9 s 205°)". Found by the adversarial review; began after the BREAK-REFORM / PEEL-SEGMENTS
deploy. Disposition owed → Q10 (not a task until the operator rules). (4) Nothing is watching
the service for failures (the old monitor died with its chat session) → Q10.

**Local, unpushed:** marine `2a05856` (Q17); API `96bec7b` + `cf0318d` (S10 fog revert; 68 fog
tests pass on Windows, host run owed post-deploy, CHANGELOG entry not yet written); meta plan
commits. **Operator 2026-08-27: "nothing needs pushed, there are plenty of changes this plan
will make everything can wait."** → S0's push + live gate and S10's deploy are DEFERRED; they
ride the plan's later push. Nothing is pushed or deployed until the operator says "push".

**Session 2026-08-27 (UTC; 08-26 evening PDT):** Q17 traced, ruled (a), coded lead-direct,
doc-synced. CARTO break traced to the source; rulings taken in chat (no Esri; OSM light stays;
Protomaps for dark; Q6 — radar providers are overlay-only, Clear Skies keeps basemap + labels
from the product basemap, nothing moves into the fork; Q5 — surf map gets the product basemap).
This plan created; predecessor closed. Carry-over register re-audited (Q9). Adversarial plan
review run; corrections applied; Q10 opened.

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
14. **The basemap is sized from Clear Skies' own config, never from a radar provider.**
    (Reworded 2026-08-27 after the operator's Q10-4 ruling: the first wording — "pretend the
    provider's information does not exist" — came from the pre-research ruling that Q6
    reversed once the fork's docs showed LibreWxR serves only radar + satellite and Clear
    Skies is responsible for the basemap.) What stands: the basemap extract's extent comes
    from station + earthquake radius + marine locations, never from any provider field, because
    most installs will not run LibreWxR at all. What is ALLOWED and already in code: the radar
    window's pan limits, minimum zoom and outside-mask come from the provider's declared
    coverage box (`[radar] librewxr_bounds` → capability `bounds` → `radar-map.tsx`
    `MapBoundsEnforcer`/`BoundsMask`) — that is the provider saying where its own overlay has
    data, and it stays. **And the radar map's basemap is sized to that same coverage box**
    (Q8 closed 2026-08-27): the radar view cannot pan or zoom beyond the box, so the box IS the
    extent the basemap under it must cover, at the radar's own zoom range (provider max zoom 12).
    A provider with no coverage box (RainViewer) falls back to the station box. The
    marine/seismic/surf maps keep the config-derived station box.
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
| PA9 | **SURF-MAP-BASEMAP** (M4): the surf height map's background switches from Esri World Topo / NAIP to the product basemap; `providers/imagery/{naip,esri,esri_topo}.py` and the `[imagery] provider` selection are removed from user-facing use (the wizard's own Esri satellite toggle is untouched). **EXTENDED 2026-08-27 (Q10-6 ruled): the imagery provider modules, `/imagery/tiles` NAIP proxy, `[imagery]` config key, admin "Imagery" section and wizard "Imagery provider" selector are DELETED (round M4-B); `/imagery/config` (basemap answer) and the marine-step satellite toggle stay** | 2, 7 | Operator 2026-08-27 in chat (Q5): "get rid of the orthophotography for the surf height map and replace it with a regular basemap ... eliminates [NAIP] completely from user facing work"; Q10-6: "if we dont need it then get rid of it" |
| PA10 | **FOG-REVERT** (S10): revert API `1ad6e74` + `f2c5ecd` (night-time standalone ≤ 1 °F fog rule) to the prior provider-cross-checked behaviour | 1 (a threshold inside a criterion) | Operator 2026-08-27 in chat (Q4): "we actually need to revert the change ... we are crying wolf most of the time" |
| PA5 | **C6 seam-fidelity ledger row**: one SWAN L2 output point just inside its boundary + a per-cycle ledger field comparing WW3-handed vs SWAN-absorbed spectra | 7 | Operator 2026-08-25, chat "ok" on EVO-Q16 (C6 named there; "droppable on request") |
| PA6 | **CONSISTENCY-SCORING**: ADR-101 row-5 amendment + parse-time attachment of per-partition group statistics (ν, Qp, κ, Tm02, T_set) to the DWR spectral entries (a data-contract change inside the marine service), scorer reads them | 1, 4 | Operator 2026-08-23, chat "q14 recommendation is fine" (EVO-Q14 record). **Sub-decisions A–E: NOT yet ruled** — the Q3 "yes" was conditioned on "that is what is in code correct?", which was false; re-asked in Q10. S2 blocked until then |
| PA8 | **WW3 G1 transparency field for partially-land cells** (S8.1): fraction-based land/sea mask + `FLAGTR = 2` cell-centre transparencies derived at setup from a fine DEM; `F_DRY` | 1, 3, **7** (new obstruction NAME file + deck block; the grid-file writers and the regional DEM download S8.1 turns out to need — see S8.1 design) | Operator 2026-08-27, chat: "it should also apply to cells that are not 100 percent island … so you are not OVERCOUNTING an island"; Q7 "run now". **`F_DRY` NOT confirmed** — Q7 asked for the number and the ruling answered only the scheduling; re-asked in Q10. The trigger-7 items are also in Q10. **S8.1 does not dispatch until both are ruled** |
| PA7 | **Substitution cleanup** (S3): doc corrections + the `level1` label rename + removal of the health `ww3_boundary` entry OR its recorder (Q10) | none for the doc/rename parts. **The adversarial review (finding #1, BLOCKER) showed the register's "dead code" claims were WRONG:** `_reused_l1_boundary_command_lines()` and the `level1/` directory are a live per-cycle production dependency (`vchain.py:727`, `CHAIN_SCAFFOLD_MISSING` → no publish), and `ww3_chain_enabled` gates the buoy-ledger writers (`vchain.py:914, :978`; live config `true`). NONE of those three is deleted under this row | Standing rule for the doc/rename parts; anything touching the three live items needs its own design block and ruling |

Withheld: model-physics changes of any kind (island shadowing S8 included — research and
ruling first); anything in the frozen-core lists; removal of the `[imagery]` config key and
provider modules from the API (Q10 — PA9 only un-wires them from the surf map); Phase L
entirely (ADR-110 first).

---

## CARRY-OVER REGISTER — every open item inherited, with the operator interaction that validated it

Per rules/verification.md "Carried-over items must cite an operator-validated premise": an item
without a citation enters tagged **UNVALIDATED — surface before any work** and is worked only
after the operator confirms it in Q2.

**RE-AUDITED 2026-08-27 (Q9 — operator: "i am very nervous about all of the carry over tasks
without going through each one and assessing what has been done and if it is still needed").**
Every row was checked against marine HEAD, the live service, and the predecessor's own close
records. Result: three rows were ALREADY DONE when this plan was created (C7 ×2/3, C8, C18 —
lead error: carried from the predecessor's original C15/C16 rows without reading its Q6 close),
two were moot (C3, C4), five were operator-dropped in this pass (C1, C2, C5, C6, C14) — C5 and
C6 had been discussed and settled in chat earlier but never marked closed in any plan, which is
exactly why they kept resurfacing. (A rule paragraph written for this was removed on the
operator's ruling, Q10-10 "worthless".)

| # | Item | Premise citation | Lands in |
|---|---|---|---|
| ~~C1~~ | ~~Operator eyeballs owed (multiSwell trains, surf card, cam + knob drill, dry-beach re-accept)~~ | operator 2026-08-27 "c1 drop" | DROPPED — the operator looks at the site nightly; no formal sign-off rows |
| ~~C2~~ | ~~Fresh buoy apples-to-apples for the 18 s SSW event~~ | operator 2026-08-27 "c2 drop" | DROPPED — the per-cycle buoy ledger is the same comparison, continuously |
| ~~C3~~ | ~~~181 stale `B_*.txt` on librewxr~~ | verified 2026-08-27: the service work root holds 88 `B_*.txt`, all 2026-08-19, all referenced by the live L2 INPUT — not stale; the 176 under `/home/claude/ww3-baselines/e1e2/` are the PRESERVED research baselines (EVO-F0) — never delete | MOOT. Residue: `swan/level1/` (34 files, 08-19) is the removed L1 level's directory — folded into C19 (the stationary fill still reads its INPUT) |
| ~~C4~~ | ~~Currents tail-hold never live-exercised~~ | verified 2026-08-27: live health `currentsTailHeld: {hours: 21, reachUntil: 2026-08-29T03Z, recorded_at: 2026-08-27T03:26Z}` | DONE — exercised live |
| ~~C5~~ | ~~Parked physics candidates (L4/1-D deep-ledge handoff loss; 5° nearshore directional bins)~~ | operator 2026-08-27: "these were discussed" — settled in chat earlier, never recorded as closed | DROPPED. If the island work (S8) does not close the deficit they return WITH evidence, not as guesses |
| ~~C6~~ | ~~Phase T (tide coherence) close acknowledgment~~ | deployed 2026-08-11; operator 2026-08-27 "if this was done why did you not mark it complete?" | CLOSED |
| C7 | V14 residuals — **two of three FIXED 2026-08-16** (marine `43744de` bounded lock, `de2738f` cooldown persistence; both in HEAD). Surviving: **no hotstart-age gate** (nothing checks the warm-start file's age before reuse) | EVO-Q6 ruled 2026-08-16; the age gate was ruled "fold into the health/refuse design" | S3 (one item) |
| ~~C8~~ | ~~`model_wave_source.py` bare `swells[0]`~~ | FIXED 2026-08-16 marine `09c0a1b` (floor at `model_wave_source.py:543–547`, in HEAD) | DONE |
| C9 | L1-BOUNDARY-REBUILD-PLAN deferred queue: Gate S wlevel (blind audit) → S1+S4a currents ladder → S-Accept currents rows → Phase A (A1/A2 service-area/setup report) → Gate A → Gate C (C1–C3 rows) → V1/V3/V4 | That plan is operator-approved 2026-08-08 ("the plan serves as permission") and its status block says "Remaining: …"; several items have since landed by other rounds (STOFS wlevel live, currents ladder live per ARCHITECTURE, `currentsTailHeld` live) — **state not re-verified since 2026-08-09** | **OUT OF THIS PLAN** (Q2 ruling 2026-08-27) — separate operator conversation |
| C10 | SURF-REMEDIATION-PLAN R1–R4 (min/max range served; reform/second break; fixed chart scale + `/var/lib` work root; R4 parallel report) | Operator-approved 2026-08-08; R2's subject was re-done by BREAK-REFORM 2026-08-26; `/var/lib/weewx-clearskies/swan` is live (health `ledgerPath`) | **OUT OF THIS PLAN** (Q2 ruling 2026-08-27) — separate operator conversation |
| C11 | SURF-PHYSICS-REMODEL-PLAN rounds Y/X/Z + DOC-0/DOC-1 debts; MARINE-FORWARD-PLAN open rows; EYEBALL-FIX residuals (subsumed into the remodel plan per its own header) | Operator-approved 2026-08-06 / 2026-08-02 / 2026-08-04 | **OUT OF THIS PLAN** (Q2 ruling 2026-08-27) — separate operator conversation |
| ~~C12~~ | ~~LIBREWXR-SATELLITE-SEAM~~ | operator 2026-08-27: "c12 has nothing to do with this plan" | REMOVED — a LibreWxR item; its pin (2026-08-08) is the fork's record, not this plan's |
| C13 | Pre-existing test failures — **re-run 2026-08-27 (Windows)**: `test_serve_nothing_on_failure` 8 FAIL and `test_service_full_run_trigger` 10 FAIL, identical to baseline; `test_h4_chunked_json` and `test_double_break_transect55_kat` PASSED this run (the first was always a wall-clock flake); `test_wind_gatherer::TestColdStartReconcile` is Windows-path only. 18 failing tests in the model's own suite | Each recorded in an EVO checklist row with the lead's checkout-verified reproduction | S4 (two test files) |
| ~~C14~~ | ~~Marine failure monitor armed~~ | operator 2026-08-27 "c14 no" | DROPPED. Fact: the old monitor was a previous chat session's watch and died with it — nothing watches the marine service now |
| ~~C15~~ | ~~Island-shadowing deficit~~ | operator 2026-08-27: "why c15 is needed if we replaced it with a new task" | FOLDED — S8 IS this item; no separate row |
| ~~C16~~ | ~~ADR-109 gaps G7/G10, D14~~ | verified 2026-08-27: **G7 (wind onto the WW3 grid) is BUILT** — the horizon march's wind path (`service.py:831`); **G10 (`ww3_grid` rebuild on geometry change) is NOT** — `service.py:938–947` refuses, and the live `mod_def.ww3` was hand-minted 2026-08-18; **D14** is a note about a test that could not be run, not a defect in the running model | DISSOLVED 2026-08-27 — lead's reading after the plain-English explanation; the operator's next message raised no objection (no verbatim "yes" on record — review #22): G7 → one-line ADR-109 edit (S3 doc round); G10 → part of S8.1 (the island round rebuilds the grid and needs this hook); D14 items 1/3 → notes in ADR-109; D14 item 2 (WW3-leg vs SWAN-path quality, "for Phase V") → S3 doc round re-homes or closes it since Phase V is dropped (review #15) |
| C17 | First-install warm-start bootstrap | EVO-Q9 ruling 2026-08-19: seed executed; durable mechanism "PARKED as a pre-ship row" | S5 (parked; not needed for this install) |
| ~~C18~~ | ~~Uncommitted API-MANUAL fog-section edit~~ | discarded (`git checkout`) 2026-08-27 under Q4 | DONE |
| C19 | Leftovers of the SWAN-L1 removal — **CORRECTED 2026-08-27 by the adversarial review (findings #1/#2/#20/#26), lead re-verified:** `ww3_chain_enabled` is a no-op ONLY for the WW3-leg gate (`service.py:668`); it still gates the buoy-ledger writers (`vchain.py:914`, `:978`) and is `true` in live config — NOT dead. `_reused_l1_boundary_command_lines()` is a LIVE per-cycle production dependency (`vchain.py:727` → `CHAIN_SCAFFOLD_MISSING` → no publish) and `swan/level1/INPUT` + its 22 `B_*.txt` are what it reads — NOT dead, NOT deletable. Still real: `level1` naming (170 occurrences, cosmetic); health lists `ww3_boundary` as a REQUIRED input nothing records (live `available: false`; exempt from red only because never-recorded inputs are skipped, `health.py:446–458`) — record it or remove it (Q10). ARCHITECTURE.md:130/132 carry the same wrong "no-op"/"vestigial" claims and are corrected in S3 | ARCHITECTURE.md follow-ups (two of them wrong); `/health` 2026-08-27 | S3 (docs + rename; no deletions) |
| C20 | Doc drift, CONFIRMED 2026-08-27: PROVIDER-MANUAL:2529 "Feeds the swell display card" (true only via fallback since Q16-B); API-MANUAL §17 lacks `swellSource` + `closeoutFraction` | EVO Q16-ROUND-B row; PEEL-SEGMENTS CHANGELOG entry | S3 (doc round; Q4 is ruled so the file is unblocked) |

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

## PHASE M — maps (operator-ruled 2026-08-27; repos: dashboard, api, stack — NOT the librewxr fork)

**Order:** M0 → M1, with M3 and M4 as rounds inside M1's build. Q8 closed 2026-08-27 — nothing
in Phase M is blocked on a ruling.
**Owner:** coordinator designs; `clearskies-dashboard-dev` (dashboard) / `clearskies-api-dev`
(API endpoints + the stack admin page: `admin/routes.py`, `templates/admin/geographic_features.html`,
locale files) implement; `clearskies-auditor` gates. Every brief carries the three mandatory
blocks and PRIME DIRECTIVE 13–15 verbatim.

### M0 — Extent inventory + measurements (read-only, no ruling needed)

Deliverable `scratch/M0-MAP-EXTENTS.md`: (a) for each Clear Skies map surface, the extent
source and zoom range **as coded** (marine `LocationMap.tsx`, seismic `seismic.tsx`, radar
`radar-map.tsx` + the capability `bounds`); (b) for this install, the derived boxes from live
config (station 33.657/−117.983, quake radius 200 km, the marine locations from
`/api/v1/marine`) and the radar coverage box from `/api/v1/capabilities`; (c) measured
`pmtiles extract` sizes and tile counts for: the union box at z7–15, the marine box at z15,
the world at z0–6, the radar coverage box at z0–12 — run on weewx where the CLI already lives,
into a named scratch dir; (d) the `protomaps-leaflet` 5.x theme API (which built-in themes exist, how label-only
rules are expressed) verified from the installed package, not from memory.

### M1 — CS-BASEMAP (design block; implement after M0)

**Extent derivation (API, config-time):** a new `services/basemap_extract.py` computes
`bounds = union(seismic_box, marine_box)` from `api.conf` + the marine locations the API
already holds; no operator-typed box; recomputed by the same admin action that runs the
extract. **Radar map (Q8 closed 2026-08-27):** its basemap extent is the radar provider's
declared coverage box (`[radar] librewxr_bounds` → capability `bounds`), at z0–12 (the radar's
own zoom range); when the provider declares no box, the station box above. Files under
`/etc/weewx-clearskies/`: `basemap-world.pmtiles` (z0–6, global — the fallback ground for any
pan outside the boxes on the non-radar maps), `basemap-local.pmtiles` (z7–15, the union box),
and `basemap-radar.pmtiles` (z0–12, the radar coverage box). M0 measures all three. Served by one endpoint family
`/api/v1/basemap/{world,local}/tiles` (Range requests, same mechanism ADR-078's endpoint uses
today) + `/api/v1/basemap/status`. Admin page: one "update basemap" action + status.
`pmtiles` CLI stays a documented API-host prerequisite (OPERATIONS-MANUAL).
**Dashboard:** marine and seismic maps — light theme unchanged (OSM raster); dark theme =
`protomaps-leaflet` `leafletLayer` over the two tiered sources (world z0–6 under local
z7–15; there is no separate "regional" file — the local file's z7–10 levels ARE the regional
view), Protomaps dark theme tuned to the current sparse look. **Required content of the dark
basemap (operator, 2026-08-27): water, land/coastline, admin boundaries, place labels, and
FREEWAYS** — the Protomaps `roads` layer's motorway + trunk classes drawn at every zoom of
the local tier (visible from z7, so the seismic view shows the interstate network, not just
at street zooms); primary roads from z11; nothing smaller. **ADR-078 (geographic features):**
a plan cannot change an ADR's status — M1's first deliverable is a Proposed ADR-078 amendment
("superseded by the product basemap"), accepted by the operator before the feature's extract/
endpoint/config key are replaced; `docs/decisions/INDEX.md:151` still carries the stale
"OSM via Overpass API" title and is fixed in the same edit. Marine label overlay (both themes) = a labels-only rule set from the same sources. `CARTO_OSM_ATTRIBUTION` deleted; attribution becomes
"© OpenStreetMap contributors © Protomaps" (About page row already exists). Tile-error
banner logic (M1 fixit constants) kept.
**Also served by this basemap (Q6 + Q5 rulings, 2026-08-27):** the radar/satellite box (M3
RADAR-REBASE — dark base + the labels/outlines layer over satellite) and the surf height map
(M4 — replaces Esri World Topo / NAIP). **Not touched:** wizard/admin maps (OSM raster +
the operator-only Esri satellite toggle).
**Extent consequence, accepted by the operator (directive 14):** detail only inside the
derived box; coarse world baseline beyond it.
**Lead mechanics — API side (2026-08-27, coordinator; agents execute these; a deviation is a
finding):**
- `services/basemap_extract.py`: `TIERS = {"world": (0, 6), "local": (7, 15), "radar": (0, 12)}`;
  files `/etc/weewx-clearskies/basemap-{tier}.pmtiles`. `compute_local_bounds()` = union of
  the seismic box (station from `services/station.get_station_info()`, radius
  `settings.earthquakes.default_radius_km × 1.15`, km→deg: lat/111.32, lon/(111.32·cos lat)) and
  the marine box (bounding box of the locations returned by
  `companion_proxy.marine_discovery_get("/marine", {})` — the API's only marine channel — padded by
  40 px at z15: 40 × 156543.03·cos(lat)/2^15 m); no marine service configured → seismic box
  alone (structural, not a failure); marine service configured but unreachable → the extract
  REFUSES loudly (rules/coding.md "a model runs on all its inputs"). `compute_radar_bounds()` =
  `settings.radar.librewxr_bounds` when set, else `None` → the radar tier is extracted from the
  station box (directive 14). Extraction = the existing `pmtiles extract` mechanics
  (`services/geographic_features.py:108–160`: today/yesterday build fallback, temp file + atomic
  move, 1800 s per tier) with `--minzoom`/`--maxzoom` per tier, run world→local→radar in ONE
  daemon thread (`start_extract_in_background()` → `False` if already running); status carries
  per-tier `{available, size_bytes, updated_at, bounds, minzoom, maxzoom}` plus `updating`,
  `last_error`, `last_started_at`, `last_finished_at`. A tier whose extract fails leaves the
  previous file in place and names the error in `last_error`.
- `endpoints/basemap.py`: `GET /api/v1/basemap/{tier}/tiles` (tier ∉ TIERS → 404 problem;
  file absent → 404 JSON like ADR-078's), `FileResponse` + `Accept-Ranges: bytes` +
  `Cache-Control: public, max-age=86400`; `GET /api/v1/basemap/status`; `POST /setup/basemap/update`
  (proxy-secret auth exactly as `endpoints/geographic_features.py:69–81, 176–187`; 202
  `{"status": "started"}` / 409 `{"status": "already_running"}`); `wire_basemap_settings()`.
  Wiring mirrors `app.py:54–56, 139–141, 193–205` and `__main__.py:83, 986–988`.
- `config/settings.py`: `BasemapSettings` for `[basemap]` with ONE key, `enabled` (bool, default
  true). No operator-typed box, no zoom knobs (directive 14; PRIME DIRECTIVE 11). **As built
  (2026-08-27, accepted):** `enabled=false` gates ONLY the tiles endpoint (404); status and the
  update action stay reachable so an operator can see and fix the state.
- **M1-API round landed 2026-08-27** (API local `45d1b63`, `94e9437`, `ecdd3d4`, `fc7cdfa`,
  `6fda155`; lead re-ran the four test files: 38 passed; commit stats all inside the allowlist).
  Computed for this install: local bounds `-120.4649,31.5907,-115.5005,35.7229`, radar
  `-129.5,26.75,-105.5,40.75`. **Adversarial gate PASSED 2026-08-27** (13/13 rows met by the
  auditor's own probes; 2 findings): F1 (medium) — a marine service installed but with no locations
  answers 404 on `/marine`, which the extractor read as an outage and refused the local tier
  forever → FIXED lead-direct (API `MarineDiscoveryUnavailableError.status_code`; 404 = seismic box
  alone; 3 guard tests; 41 tests pass); F2 (low) — OPERATIONS-MANUAL claimed 0640 for the basemap
  files while `mkstemp` yields 0600 (ADR-078's precedent identical) → manual corrected to 0600.
  Docs round M1-DOCS landed (ADR-078 Amendment 2 Proposed, ARCHITECTURE, API-MANUAL §12b, openapi,
  OPERATIONS-MANUAL, CHANGELOG).
- ADR-078's feature stays in place this round (additive build); its removal is the final Phase M
  commit after the operator accepts the ADR-078 amendment (journal J3).

**Lead mechanics — dashboard side (2026-08-27, coordinator; M1 + M3 in one round; M4 separate):**
- NEW `src/lib/basemap.ts` — the ONE place that knows the product basemap: `BASEMAP_TIERS`
  (`world` z0–6, `local` z7–15, `radar` z0–12) → `/api/v1/basemap/{tier}/tiles`;
  `useBasemapStatus()` (`GET /api/v1/basemap/status` through the existing `useApiQuery`/`fetchApi`
  layer); rule builders derived from the installed `@protomaps/basemaps` flavors (M0 (d)):
  `darkBasePaintRules()` = `paintRules(namedFlavor('dark'), 'en')` with the `buildings`,
  `landuse` and `pois` layers dropped (the "current sparse look") and the flavor's `roads` rules
  REPLACED by exactly two: freeways — `kind === 'highway'` (Protomaps v4 = motorway + trunk;
  verify the kind value against `docs/reference/pmtiles-protomaps-reference.md` and cite) drawn at
  every zoom ≥ 6 (RESTYLED 2026-08-27 after the lead's render review — the first stops, 0.6 px in
  `DARK.highway` #474747 at z7, were unreadable on the dark seismic/radar maps), width
  `exp(1.6, [[6, 1.4], [8, 2.0], [10, 2.6], [13, 3.4], [15, 4.5]])`, colour `#a0a0a0` (contrast
  vs the dark ground ≥ 3:1, measured);
  second tier — `kind === 'major_road'` from z11 (CORRECTED 2026-08-27 by the dashboard-dev's
  schema verification: the Protomaps `roads` layer has no `kind_detail === 'primary'`; its kinds are
  highway/major_road/medium_road/minor_road/other/path/rail — `@protomaps/basemaps/src/base_layers.ts`),
  width `exp(1.6, [[11, 1.0], [15, 2.6]])` (restyled 2026-08-27), colour `#828282` (re-ruled the same day: #6f6f6f measured 2.45:1 over DARK.water; one step
  dimmer than the freeway grey); nothing smaller. Initial zooms verified at 1400×900: seismic z7, radar z7 — the local tier's z7 start holds. `labelRulesFor(theme)` =
  `labelRules(namedFlavor(theme === 'dark' ? 'dark' : 'light'), 'en')` filtered to the `places`
  and `water` label rules (no road shields, no POIs). `SATELLITE_OUTLINE_PAINT_RULES` = the four
  ADR-078 `LineSymbolizer` rules moved verbatim from `radar-map.tsx:480–520`.
  `<ProtomapsLayer tier mode pane zIndex minZoom maxZoom />` — an imperative react-leaflet
  component on the `GeoFeaturesLayer` pattern (`radar-map.tsx:522–571`): `leafletLayer({ url: new
  PMTiles(tileUrl) as any, paintRules, labelRules, attribution: PROTOMAPS_OSM_ATTRIBUTION, pane,
  maxDataZoom: tier max })`; `mode` ∈ `dark-base` (paint = dark base rules, labels = dark labels),
  `labels` (paint `[]`, labels per theme), `satellite-outlines` (paint = outline rules, labels =
  dark labels). Renders nothing when `useBasemapStatus()` says the tier is unavailable (and the
  marine map shows its existing tile-error banner with a new i18n key `map.basemapUnavailable`,
  13 locales); seismic/radar show nothing extra.
- Two-tier stacking on the marine and seismic maps (dark theme): `<ProtomapsLayer tier="world"
  mode="dark-base" />` with NO `maxZoom` (over-zoomed z6 data is the ground beyond the box) under
  `<ProtomapsLayer tier="local" mode="dark-base" minZoom={7} />`. Labels: `world` labels layer
  `maxZoom={6}`, `local` labels layer `minZoom={7}` — never both at one zoom.
  **AS BUILT (dashboard-dev finding 2026-08-27, accepted):** the zoom windows are NOT passed as
  Leaflet `GridLayer` `minZoom`/`maxZoom` options — Leaflet's `Map._addZoomLimit`/`_updateZoomLevels`
  (leaflet-src.js `:7012–7055`) aggregates every layer's `maxZoom` and force-overrides the map's
  current zoom, which collapsed the marine map's `fitBounds` from z12 to z6. The windows are applied
  per rule instead (`withZoomWindow()` in `basemap.ts` sets `minzoom`/`maxzoom` on each
  PaintRule/LabelRule; evaluated inside the canvas paint, no map-level side effect). The
  labels-once invariant (world ≤ 6, local ≥ 7) holds on the rule sets.
- `LocationMap.tsx`: dark base (`:72–75`, `:305–313`) → the two-tier stack; the CARTO label
  overlay (`:54–59`, `:318–326`) → `ProtomapsLayer mode="labels"` per theme (both variants, both
  tiers as above); `useTileErrorRecovery` stays on the light OSM layer only; `TILE_CONFIG` keeps
  only `light`.
- `seismic.tsx`: same dark swap (`:130–139`, `:293–297`); attribution string for dark =
  `PROTOMAPS_OSM_ATTRIBUTION` + the fault attribution as today.
- `radar-map.tsx` (M3): `TILE_CONFIG.dark` (`:397–400`) → `<ProtomapsLayer tier="radar"
  mode="dark-base" />` when `!satelliteActive && resolvedTheme === 'dark'` (single tier — Q8);
  light OSM unchanged; `satelliteActive` → ONE `<ProtomapsLayer tier="radar"
  mode="satellite-outlines" zIndex={300} />` replacing BOTH the CARTO labels `TileLayer`
  (`:1347–1353`) and `<GeoFeaturesLayer />` (`:1357`); delete `SATELLITE_LABELS_URL`,
  `SATELLITE_OVERLAY_ATTRIBUTION`, `GEO_FEATURES_PAINT_RULES`, `GeoFeaturesLayer`, and the
  `protomaps-leaflet`/`pmtiles` imports from that file. `MapBoundsEnforcer`/`BoundsMask`
  untouched (directive 14).
- `map-attribution.ts`: add `PROTOMAPS_OSM_ATTRIBUTION` = "© OpenStreetMap contributors © Protomaps"
  (linked); delete `CARTO_OSM_ATTRIBUTION`; delete `OSM_ODBL_ATTRIBUTION` if it has no remaining
  user (grep). `about.tsx:28` CARTO row deleted; the Protomaps row (`:29`) stays.
- Dev-only, env-gated Vite proxy (no effect on the build or on anyone who does not set the vars):
  `vite.config.ts` `"/api"` target = `process.env.API_DEV_ORIGIN ?? "http://localhost:8765"`
  (`secure: false`), and a `"/api/v1/basemap"` rule targeting `process.env.BASEMAP_DEV_ORIGIN`
  when set, rewriting `/api/v1/basemap/<tier>/tiles` → `/basemap-<tier>.pmtiles` and `/status` →
  `/status.json`. The lead serves the M0 extracts from `scratch/basemap-dev/` with `npx http-server`
  (Range-capable) so the round can render the real dark basemap before any deploy.
- Docs, same round (meta repo): DASHBOARD-MANUAL §10 "Basemap swap" + "Geographic features vector
  tile overlay" paragraphs and §12 map-layer contract rewritten to the as-built; DESIGN-MANUAL only
  if it names CARTO (grep).

**Gate rows (results-free file, stated now):** both maps render in both themes with no
watermark and no blank inside the derived box (screenshots side-by-side vs today's light
theme); **freeways visible on the dark seismic map at its initial zoom and on the dark marine
map at z14** (named roads checked against the light OSM map at the same view — I-405/I-5/
SR-55 for this install); a pan outside the box shows the world baseline, not blank; `grep -r cartocdn`
across dashboard/api/stack = 0; extract sizes **≤ 100 MB world + ≤ 400 MB local (ceiling
stated before M0 measures; a larger measurement is a Q8 finding, not a gate re-fit)**; attribution
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

### M4 — SURF-MAP-BASEMAP (Q5 ruling; PA9) — lead mechanics (2026-08-27; executes after M1-API + M1-DASH land)

**What the surf height map is (M0 finding):** `HeatMapCard.tsx` is not a Leaflet map. It is an SVG
whose background is a hand-rolled mosaic of north-up raster tiles (`<image href=…>`, `:1892–1907`),
fetched at z14–19 from the URL template `GET /api/v1/imagery/config` returns
(`useImageryConfig.ts`), rotated to the beach bearing. So "the product basemap" means: same
mosaic mechanism, different tile source per theme.
- **API (`endpoints/imagery.py`):** `/imagery/config` answers with ONE user-facing provider,
  `"basemap"`, regardless of `[imagery] provider` (naip/esri/map/auto are no longer reachable from
  any user-facing surface — PA9; the modules, key, admin section and wizard selector stay until
  Q10-6 is ruled, and the API logs ONE startup WARNING naming the ignored value). Response
  (additive over `ImageryConfigResponse`; `provider: "basemap"`, `proxyMode: "direct"`):
  `light: {tileUrl: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" with `{s}` pre-expanded to
  `a`, attribution: OSM}`, `dark: {pmtilesUrl: "/api/v1/basemap/local/tiles", maxDataZoom: 15,
  attribution: "© OpenStreetMap contributors © Protomaps"}`, `zoomMin: 0`, `zoomMax: 19`. The legacy
  top-level `tileUrl`/`attribution` fields carry the light values so an old client still renders.
  `/imagery/tiles/{z}/{x}/{y}` (NAIP proxy) is untouched (unreferenced after this round; Q10-6).
- **Dashboard (`HeatMapCard.tsx` + `useImageryConfig.ts` + `src/lib/basemap.ts`):** light theme →
  `href = substituteTileUrl(light.tileUrl, …)` exactly as today. Dark theme → `href` = a PNG data
  URL rasterized in the browser from the local tier: `basemap.ts` gains `rasterizeBasemapTile(z, x,
  y): Promise<string>` built on protomaps-leaflet's exported primitives — `new View(new
  TileCache(new PmtilesSource(url, true), 1024), 15, 2)`, `view.getDisplayTile({z, x, y})`, then
  `paint(ctx, z, new Map([[key, [tile]]]), null, darkBasePaintRules(), bbox, origin, true)` on an
  offscreen 256×256 canvas → `canvas.toDataURL('image/png')` (the exact call sequence is
  `node_modules/protomaps-leaflet/src/frontends/leaflet.ts`'s `renderTile`; mirror it). No labels
  in the surf-map dark tiles (per-tile label placement without cross-tile collision handling
  clips text; the map is a 50 m-buffered study rectangle, not a navigational map). A hook
  `useRasterizedTiles(tiles, enabled)` resolves the data URLs; tiles render as they resolve; the
  attribution string in the info modal follows the theme. Over-zoom above z15 is vector
  magnification (crisp). Light OSM tiles at z14–19 are browser-direct exactly like the Leaflet
  light maps.
- **Removed from user-facing use:** every Esri/NAIP template read in `HeatMapCard.tsx`; the
  `[imagery]` API modules stay (Q10-6). Attribution rows on the About page for Esri/NAIP are
  removed only if no user-facing surface still uses them (the wizard's toggle is not a dashboard
  surface).
- **Gate rows:** the surf height map renders in both themes with the product ground under the heat
  cells (screenshots side-by-side vs today's Esri render); no request to `arcgisonline`/`usgs`
  leaves the browser from the marine page (network log); the mosaic geometry (rotation, pivot,
  tile placement) is byte-identical to today (KAT b lineage — diff the `imageryLayer` object);
  vitest for `useImageryConfig` + the rasterizer (mocked View); `tsc` zero.

### Gate M

Per round + a phase-close sweep: every map surface, both themes, screenshots side-by-side;
directive 13/14 check (the radar box renders the PRODUCT basemap + labels layer — no
provider-specific basemap; no basemap extent derived from any provider field; the radar
VIEW-bounds coupling disposition per Q10); attribution audit; DASHBOARD-MANUAL §12 rewritten
to the as-built.

---

## PHASE S — surf system (repos: marine, api, dashboard)

### S0 — Q17 push + live gate (owed now)

On the operator's "push": push marine + meta → `scripts/deploy-marine.sh` → post-deploy
journal sweep. **Gate (stated before looking):** the first 00Z cycle after the gatherer has
fetched a GFS cycle to f108 — `ww3Horizon.lastSuccessCycleTime` = that cycle,
`coverageEndTime` = cycle + 96 h, `wallClockS` ≤ 5 h, no overlap with the 06Z production
run (`ExecMainStartTimestamp` and run timestamps pasted — **the guard is one-directional:
the march skips if a full run is in flight (`service.py:2216`) but the full-run trigger
(`:2074`) does not check the march; arithmetic says a ~4.3 h march starting ~03:36Z ends
~07:54Z, right when the 06Z extended wind completes (~07:51Z). An observed overlap = gate
FAIL, reported to the operator with the timings; the reciprocal guard is a code change that
gets its own ruling, not a same-round fix**); the following full cycle shows
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

**S1 lead mechanics (2026-08-27, coordinator; dispatch after S12 closes — same `swan_runner.py`):**
- **The seam point.** The WW3 leg already emits its transfer spectra at the L2 boundary points
  (`WW3SetupDerivation.l2_boundary_points`, persisted in `swan_grid_sizing.json`'s `ww3_leg` block;
  each transfer point carries a name and lat/lon — `vchain.parse_transfer_file()`). The WW3-handed
  side = the transfer point with the largest projection onto the open-water bearing from the L2
  centre (the most seaward boundary point). The SWAN-absorbed side = ONE new L2 output point
  `SEAM`, placed one L2 cell (100 m) inward from that transfer point along the bearing (toward the
  L2 centre), written into the L2 deck's existing DWR block (`swan_runner.py:3600–3790`, the
  `_dwr_lines` insertion before COMPUTE) as `POINTS 'SEAM' x y` + `SPECOUT 'SEAM' SPEC2D ABS
  'SPEC_SEAM.txt'` with the same OUTPUT clause the DWR points use; UTM via the same transform
  `_tx,_ty` use. Both coordinates and the transfer point's name go into the ledger row.
- **Bands.** `SEAM_BAND_EDGES_HZ = (0.09, 0.20)` (NAMED CONSTANT: < 0.09 / 0.09–0.20 / > 0.20 Hz),
  `SEAM_HS_TOLERANCE = 0.10` (±10 % Hs per band, stated before looking), in `vchain.py`.
  `integrate_spectrum()` gains an optional `f_lo_hz`/`f_hi_hz` mask (additive kw-only; default =
  today's whole-spectrum result, byte-identical). The SWAN SPECOUT (`swan_spectral.parse_specout_file`)
  is converted to the transfer file's density basis (per-radian, "going-to" radians) BEFORE
  integration — the agent verifies both units from the two parsers' docstrings and cites them.
- **The row.** In `record_chain_cycle_ledger_row()` success path (after `row["ww3"]`): read
  `swan/level2/SPEC_SEAM.txt`; for the first timestep common to the transfer records and the
  SPECOUT, `row["seam"] = {"label": "model-vs-model (WW3 handed vs SWAN absorbed), NOT a truth
  check", "transfer_point": {name, lat, lon}, "swan_point": {lat, lon}, "time", "bands": {"lt_0p09":
  {"ww3": {hs, tp, dir}, "swan": {…}, "hs_ratio"}, "0p09_to_0p20": {…}, "gt_0p20": {…}},
  "within_tolerance": bool, "error": null}`; any parse/alignment failure → `"error": "<named>"`
  and the other keys `null` — the row is written EITHER way (never skipped), and `error` is
  logged at WARNING. Never raises (the ledger's own contract).
- **KATs.** (a) a synthetic transfer spectrum + the same spectrum scaled 0.8 in energy per band
  → `hs_ratio` ≈ 0.894 (√0.8) per band, `within_tolerance` False; (b) identical spectra → ratios
  1.0, True; (c) the mutation drill the plan names: mirror the transfer directions (θ → θ+180°)
  and assert the row's per-band `dir` differs by ~180° while Hs ratios stay 1.0 — the row must
  CATCH it (a direction-difference field `dir_diff_deg` per band, flagged when > 30°); (d) the
  masked `integrate_spectrum` with no mask equals the unmasked result byte-for-byte.
- **Docs.** OPERATIONS-MANUAL monitoring (the `seam` row, its label, the two constants);
  PROVIDER-MANUAL §14.15 (the SEAM output point); CHANGELOG.

**S3 lead mechanics (2026-08-27):** (a) doc round = docs-author, meta repo only, the exact
lines listed above plus ARCHITECTURE Known-gaps #12–#16 re-stated (12: built — `service.py:831`;
13: the point list exists — `WW3SetupDerivation.l2_boundary_points`; 14: unbuilt, moves to S8.1;
15: note stays; 16: closed — Phase V dropped, Q1, the buoy ledger is the standing instrument);
(b) `level1` label rename is DEFERRED until S8.1 closes (170 occurrences across the same files
S12/S1/S8.1 edit — a rename round in the middle of three concurrent code rounds is how merges go
wrong; it is the last marine code round of the plan, cosmetic by the plan's own word); (c) the
`ww3_boundary` recorder: `state.record_input("ww3_boundary", available=True)` immediately after
`boundary_reconstruction.ww3_boundary_files_and_deck()` succeeds at `service.py:899–901` and in
the horizon march's twin at `:1359–1361`; `available=False` in both `except BoundaryNotViableError`
branches (`:902–911`, and the march's) — nothing else; guard test: the leg's boundary failure path
records `ww3_boundary` unavailable and `/health` lists it, pre-change transcript pasted; (d)
hotstart-age gate: dropped (Q10-5) — C7 closed, no code.

**S5 lead mechanics (2026-08-27; EVO-Q9 option 2):** `service.py:798–810` — when the restart file
exists but `lastSuccessCycleTime` is absent (today: "untrusted, refusing"), look for a provenance
note `restart_<token>.provenance.json` beside it: `{"generating_cycle": "<ISO Z>", "source":
"bootstrap", "created_at": "<ISO Z>", "note": "<free text>"}`; if present AND its
`generating_cycle` parses AND equals the restart token's cycle → accept ONCE: log WARNING naming
the note, set `last_success_dt` from it (so the D11 age gate still applies), and DELETE the note
after the leg's successful completion (consumed — a second cold install writes a new one). Any
mismatch → today's refusal, with the note's contents quoted in the ERROR. Install procedure
(OPERATIONS-MANUAL "Marine service deployment": a "First install — WW3 warm start" step giving the
exact `cat > …provenance.json` snippet); ADR-109 D10 amendment (Proposed). Guard tests: note
present+matching → leg proceeds and the note is gone afterwards; note mismatching → refusal
`ww3_restart_missing` with the quoted note; no note → today's behaviour byte-identical.

### S2 — CONSISTENCY-SCORING (PA6; blocked on Q3)

Inputs on record: brief `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md`
§3.2/§3.3/§4.3/§7; verification deliverables `WAVE-GROUP-FORMULAS-VERIFICATION-2026-08-23.md`
(Kimura 1980 route, Tm02 lag) and `PARTITION-NARROWNESS-SURVEY-2026-08-23.md` (ν ≈ 0.17 /
κ ≈ 0.59 dominant groundswell; ν ≈ 0.53 windsea; half-way band rule). Sequence: ADR-101
row-5 amendment (Proposed → operator) → coding brief (parse-time group statistics attached
per partition in `swan_runner.py` ~:3900–3974; scorer reads scalars) → KATs against the
V1 worked numbers → firewalled gate → deploy → reality row (a groundswell day and a windsea
day ranked as the operator expects).

### S3 — Substitution cleanup (PA7; C7 survivor, C19, C20) — CORRECTED 2026-08-27 after the adversarial review

**What the review found (finding #1, BLOCKER; #2, HIGH) and the lead re-verified at the code:**
`_reused_l1_boundary_command_lines()` is called EVERY production chain cycle from
`vchain._stage_l2_boundary()` (`vchain.py:727`) — it reads the BOUNDSPEC scaffold out of
`swan/level1/INPUT` and copies the 22 spectrum files it references into level2; `None` →
`CHAIN_SCAFFOLD_MISSING` → "no SWAN run, no publish". `ww3_chain_enabled` (live `true`) gates
both buoy-ledger writers (`vchain.py:914`, `:978`) — removing it silently stops the ledger.
The register's "vestigial" / "no-op" wording (and ARCHITECTURE.md:130/132, which say the same)
was wrong. **Nothing live is deleted under this task.** Retiring the L1 scaffold would be a
change to how the L2 deck's boundary commands are produced — a design block with its own
ruling, if ever wanted.

**Remaining scope:** (a) doc round — ARCHITECTURE.md:130/132 corrected to the above; ARCHITECTURE
Known-gaps rows #12–#16 (still "unbuilt"/"Phase V") re-stated; PROVIDER-MANUAL:2529 swell-card
bullet; API-MANUAL §17 `swellSource` + `closeoutFraction`; ADR-109 G7 row struck as built;
ADR-109 D14 item 2 (WW3-leg vs SWAN-path served quality "for Phase V") re-homed or closed since
Phase V/S7 is dropped. (b) `level1` label rename in code/cache names (170 occurrences, cosmetic;
cache-file rename needs a migration note — do NOT rename the on-disk `swan/level1/` directory).
(c) health `ww3_boundary` required-input entry: Q10 — record the input (the NOAA boundary IS an
input; PRIME DIRECTIVE 8 prefers visibility) or delete the entry. (d) hotstart-age gate: Q10 —
EVO-Q6 folded it into the W5 health/refuse design, which shipped without it; recommend drop.
C7's other two items and C8 are already in HEAD (`43744de`, `de2738f`, `09c0a1b`).

### S12 — HANDOFF-RESTART (Q11 ruling 2026-08-27; triggers 1 and 3, authorized by that ruling)

**Plain English.** Today the ocean model (SWAN) hands the wave to the beach model (the 1-D
SwellTrack run) at one station per transect, chosen by a formula from wave height. The beach
model then trusts that starting point. If the wave is already breaking there, the beach model
reports the break on its own starting line — which is what the health alarm has been catching
since Tuesday. The operator's design: the beach model checks its own result, and if the break is
wrong (at the start), it moves its starting point seaward and runs again, in the same cycle,
until the break is genuinely inside its domain.

**What exists that this builds on (verified 2026-08-27):**
- Per transect, SWAN writes a TABLE at every station of the transect's band, 10 m apart, from the
  deep end to the breaking contour: `HSIGN HSWELL TM01 DIR DEPTH QB DISSURF DSPR PTHSIGN PTRTP
  PTDIR PTDSPR` (`swan_formats.py:2375–2380`; `_TRANSECT_BAND_SPACING_M = 10`, `swan_runner.py:1576`).
  The beach model runs per partition on `PTHSIGN/PTRTP/PTDIR` at the selected station only.
- `select_hourly_handoff()` (`services/transect_handoff.py:680`) picks the station nearest
  `1.3 × Hs / 0.73` inside the band, strictly seaward of SWAN's own suspected break zone (BD-1/2).
- `_truncate_bathy_at_handoff()` (`surf_1d_pipeline.py:597`) trims the beach profile to start at
  the seaward-most node ≤ the handoff depth (untided) and the 1-D run (`_ddd_breaking_march`,
  `surf_1d_analytical.py:776`) starts breaking at node 0 when the 5 % onset is already met there
  (`:1042–1046`); the zone's marker is its maximum-dissipation point (`:1091–1093`).

**Design (executes verbatim; a deviation is a finding):**
1. **Restart loop, per transect × partition × hour, inside the cycle.** Start from the station
   `select_hourly_handoff()` picks today. Run the 1-D. **Acceptance test:** the outermost break
   marker (`break_points[0]`) lies at least `HANDOFF_BREAK_CLEARANCE_M` shoreward of the handoff
   station (named constant, proposed 10 m = one SWAN band station, `_TRANSECT_BAND_SPACING_M`,
   so the settled handoff is always ≥ one station seaward of the break) — AND the wave at the
   profile's first node is below the onset criterion (`Qb(node 0) < Q_B_VISIBLE`). If either
   fails, take the next station seaward in the band (its own `PTHSIGN/PTRTP/PTDIR` for this
   partition, its own depth as the new handoff), re-truncate the profile, re-run. Repeat until
   the test passes. **Two spacings, not to be confused (lead error 2026-08-27):** the SWAN band
   stations the handoff moves between are 10 m apart; the beach model's own profile is the
   variable-resolution PCHIP profile from the 3 m bathymetry download — ~1.5 m nodes in the
   fine/breaking zone, ~4 m in the shoaling zone, native points beyond 15 m
   (`enrichment/bathymetry.py:1129–1132`). The clearance is a DISTANCE, never a node count.
2. **Termination.** The band's deep end reached without passing → that transect-hour-partition
   is REFUSED with a named reason (`handoff_restart_exhausted`), counted in health, never served
   from the last attempt (PRIME DIRECTIVE 8, "a model runs on all its inputs or it does not run").
   A hard cap on attempts equal to the band length (≤ 150 stations) — no other cap.
3. **The published handoff depth** for the transect-hour becomes the station the loop settled on
   (`handoff_depth_m` in the wire payload, `handoff_selection` trace stage gains
   `restart_attempts` and `restart_reason`). The formula's station remains the FIRST attempt only.
4. **Invariant 1 re-defined on one basis:** compare the break depth and the handoff depth both
   UNTIDED (subtract `tide_level` from `break_points[0].depth_m`, or carry the node's chart-datum
   depth on `BreakPoint`), and require the outermost marker ≥ `HANDOFF_BREAK_CLEARANCE_M`
   shoreward of the handoff — the same test the loop enforces, so a firing after S12 means the
   loop failed, not the tide.
5. **KATs:** (a) Huntington transect 4, 2026-08-27T05Z, from the journal firing (break 2.15 m
   tided / handoff 1.98 m / tide from the STOFS record of that cycle): with the loop, the settled
   station is seaward of the first, the marker is interior, invariant 1 is quiet; (b) a synthetic
   profile where node 0 is below onset → zero restarts, byte-identical output to today;
   (c) a synthetic profile breaking at every band station → `handoff_restart_exhausted`, nothing
   served. (d) Regression: `tests/test_break_reform_kat.py`, `test_double_break_transect55_kat.py`
   unchanged. Each KAT's pre-change failure transcript pasted.
6. **Reality gate (stated before looking):** after deploy, over one full day: invariant-1 firings
   = 0; the fraction of transect-hours whose marker sits within 5 cm of node 0 falls from 37 % to
   < 5 % (`scratch/inv1/compare.py` re-run on that day's trace); median restart count and the
   count of `handoff_restart_exhausted` pasted; served face heights at Huntington compared to the
   day before (same swell within ±10 % Hs at 46222) — a change > 20 % is a finding to surface.
7. **Docs, same round:** ARCHITECTURE.md handoff paragraph, ADR-093 amendment (the handoff is
   selected by restart, not by the formula alone), PROVIDER-MANUAL §14.15, API-MANUAL §17
   (`handoff_depth_m` semantics), invariants docstring, CHANGELOG.

**`HANDOFF_BREAK_CLEARANCE_M = 10` ✅ RULED 2026-08-27** — operator: "if that is the size of the
L4 grid then that is fine." It is: L4 is the fixed 10 m structure grid (operator ruling
2026-07-27) and `_TRANSECT_BAND_SPACING_M = 10` matches it. Constant documented as "one L4 cell".
S12 is fully ruled; brief on the operator's go.

**Lead mechanics (2026-08-27, coordinator; fills the design block's implementation gaps — agents
execute these too; a deviation is a finding):**
- **M1. Where the seaward stations come from.** `swan_runner._select_l3_handoff_position_and_spectrum()`
  already holds every band station's PT* partitions per timestep (`pt_by_band_idx[station_idx][time_iso]`,
  `swan_runner.py:1058`). Each published entry (`:1088–1094`) gains one additive key
  `"band_stations"`: a list, ordered SEAWARD-most first, of
  `{"station_index": int, "depth_m": float, "components": [...]}` for every band station strictly
  seaward of the selected station (indices `0 .. selection.station_index-1`), each with that
  station's own PT* components for the timestep (empty list when SWAN emitted none there). Only the
  stations seaward of the pick are carried (rules/coding.md §12.2 — the loop can only move seaward).
  The T4B.4 fixed-15 m L2 path (`:3981–3985`) carries no band → key absent → the loop has nowhere
  to go → a failed acceptance test there is `handoff_restart_exhausted` immediately.
- **M2. Plumbing.** `surf_pipeline_timestep.py` gains `resolve_band_stations_by_transect()` beside
  `resolve_partitions_by_transect()` (same read-only shape rules) → `run_pipeline(band_stations_by_transect=)`
  (new kw-only, default `None` = today) → `_run_pipeline_per_transect(band_stations_for_transect=,
  bathy_full_for_transect=)`. `run_pipeline` keeps the UNTRUNCATED profile per transect
  (`_bathy_full`, `surf_1d_pipeline.py:2963`) in a parallel list so the loop can re-truncate.
- **RULING 2026-08-27 (lead, on the dev's finding): the loop is per TRANSECT-hour, not per
  partition.** Partitions restarted independently settle at different stations → different
  truncated profiles → different post-refine grid lengths → the (untouched) RSS-combination step
  drops any partition whose profile length differs from the first (`surf_1d_pipeline.py`
  "length mismatch — treating as None") — the mainline restart outcome, not a corner case. So:
  ONE handoff per transect-hour (also the physically faithful reading of Q11 — SWAN hands the
  whole spectrum over at one station). Every surfable partition (Tp ≥ 5 s floor) runs from the
  shared station/profile; the transect PASSES only when every run passes the test below; any
  failure steps the transect one station seaward, re-truncates the shared profile once, and
  re-runs all surfable partitions with their period-matched components (M4) — a partition with
  no match at that station is absent there (one WARNING per transect-hour with the count) and
  does not block the transect. Exhaustion refuses the WHOLE transect-hour (every partition
  `None`). Published handoff = the settled station. M6/M7/M8 below read with "transect-hour" in
  place of "transect-hour-partition" and without the "deepest across partitions" rule.
- **M3. The loop lives in `_run_pipeline_per_transect`** around the `run_1d_analytical()` call
  (`:2242–2264`). Attempt 0 = today's inputs. Acceptance test after each run, both parts:
  (i) `not result.onset_at_node0` — a new additive `Analytical1DResult` field set by
  `_ddd_breaking_march` from its node-0 onset branch (`surf_1d_analytical.py:1042–1046`); and
  (ii) if `result.break_points` is non-empty, `bathy[:, 0].max() - result.break_points[0].distance_m >=
  HANDOFF_BREAK_CLEARANCE_M` (distance from shore of the profile's seaward node minus the outermost
  marker's distance — AS BUILT: `.max()`, because `_refine_bathy_profile()` returns the profile in
  ASCENDING distance order so `bathy[0, 0]` would read the shoreward-most node; dev finding, folded
  into `fca09ec`; gate G2 verified). Failure → next candidate = next entry of `band_stations` walking seaward
  (index `selection.station_index-1`, then `-2`, …).
- **M4. Which partition at the new station.** SWAN-sourced partitions are matched by period: the
  new station's component with the smallest `|Tp − Tp_partition|`, accepted only when ≤ 2 s (tie →
  nearest direction). No match → that station is skipped for this partition (one WARNING per
  transect-hour-partition, with the count) and the walk continues seaward. An F5-synthesized
  wind-sea partition (`is_wind_sea`, seeded at `height 0`) has no station component: it restarts
  with the same seed, its growth recomputed from the new station's fetch and depth exactly as the
  first attempt did (`:2230–2234`).
- **M5. Re-truncation.** `_truncate_bathy_at_handoff(bathy_full, new_station.depth_m, t_idx)`;
  `None` → treat as a skipped station (WARNING) and continue seaward.
- **M6. Termination.** Candidates exhausted (or none) → `p_results.append(None)`, WARNING naming
  `handoff_restart_exhausted`, transect/partition/hour, attempts; nothing from the last attempt is
  kept. Attempt cap = `len(band_stations) + 1` (never exceeds the band; the ≤ 150 station clamp
  already bounds the band).
- **M7. Published handoff.** The transect-hour's published `handoff_depth_m` = the DEEPEST settled
  station across its partitions (the profile the transect effectively starts from);
  `handoff_for_transect[t_idx]` is replaced by that settled tuple before the wire/trace/invariant-4
  reads (`:3007–3011`, `:3491`). Trace stage `handoff_selection` gains `restart_attempts` (max over
  partitions) and `restart_reason` (`None` | `"onset_at_node0"` | `"clearance"` |
  `"handoff_restart_exhausted"`).
- **M8. Health count.** `state.py` gains `record_handoff_restart_outcome(*, attempts: int,
  exhausted: bool)` keeping in-memory counters since service start — `runs`, `restartedRuns`,
  `exhausted`, `attemptsHistogram` (dict attempts→count, keys ≤ 151), `lastExhaustedAt` — and
  `/health` gains a `handoffRestart` block reporting them (count only; no status change).
- **M9. Invariant 1 both sites** (`surf_1d_pipeline.py:2255–2264` and `:3330–3336`): compare
  UNTIDED (`break_points[0].depth_m - tide_level`) against the SETTLED handoff depth, AND require
  the clearance test (ii) — the loop's own test, so a post-S12 firing means the loop failed.
  `HANDOFF_BREAK_CLEARANCE_M = 10.0` lives in `services/transect_handoff.py` beside the other
  handoff constants, documented "one L4 cell (10 m); `_TRANSECT_BAND_SPACING_M` matches".
- **M10. ADR-093 amendment** is written as Amendment 5, status Proposed, quoting the Q11 ruling
  verbatim as its basis; the operator accepts the text (rules/clearskies-process.md ADR discipline).
- **Tests run locally** (`.venv_local`) because librewxr's checkout cannot see unpushed code; the
  host run is owed after the push (journal J5).

### S4 — Test-debt triage (C13)

Scope (re-verified 2026-08-27, Windows run: 18 failed / 36 passed across the four named
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

### S6 — ~~ADR-109 gap closure~~ DISSOLVED 2026-08-27 (Q9)

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
   the cell's footprint with depth < 0. **Fine source — CORRECTED (pre-flight 2026-08-27 +
   review finding #19):** no fine DEM covering the G1 box is cached. The L2/L3/L4 caches cover
   only the spot's nested boxes (L2 ≈ 7.6 × 8.3 km), not Catalina / San Clemente; the only
   G1-wide grid is the ETOPO 15″ L1 cache (~460 m → ≤ 4–5 samples per 1 km cell, steps of
   ~0.2). Meeting KAT (b) needs a ONE-TIME regional DEM download of the G1 box (NCEI CRM ~90 m
   or equivalent) persisted beside the other bathymetry caches — **a new persisted file + fetch
   (trigger 7), ruled in Q10 before dispatch.** If refused, KAT (b)'s tolerance is re-derived
   from the ETOPO sample density and stated before looking.
2. Land/sea mask becomes fraction-based: cell is DRY iff `f ≤ F_DRY` (named constant,
   proposed 0.05 — **NOT yet confirmed; Q10**), WET otherwise; wet cells carry transparency
   `τ = f` (F_DRY < f < 1 → partial; f = 1 → 1.0). The S-row/W-column boundary-cell wet test
   reads the same mask (no second criterion).
3. `ww3_grid.inp` gains `FLAGTR = 2` in `&MISC` and the transparency field block (scale
   factor 1.0, same IDLA/IDFM conventions as the depth block, SYNTAX row 6a); `mod_def.ww3`
   rebuilt. **Components that do NOT exist and S8.1 must build (pre-flight 2026-08-27 + review
   finding #6):** (i) writers for the NAME files the deck references — `G1_bottom.txt`,
   `G1_status.txt` and the new obstruction file (`build_ww3_grid_deck`, `swan_domain.py:3439–3506`,
   names them; nothing in the service writes them — the live `level0/mod_def.ww3` was
   hand-minted 2026-08-18); (ii) the production `ww3_grid` execution hook on geometry change
   (Gap G10 — `service.py:938–947` refuses today; `WW3Runner.run_grid`, `ww3_runner.py:326`,
   exists standalone); (iii) an operator-visible procedure for replacing the live `mod_def.ww3`
   (baseline copy, diff, restart-chain consequence stated — the restart file was generated
   against the old grid file). (i) and (ii) add persisted files/lifecycle steps → trigger 7/5,
   in Q10.
4. KATs: (a) a hand-built 3×3 fine grid with a known tip → exact f per cell; (b) a synthetic
   island whose true area is known → summed f × cell area reproduces it to < 2 % while the
   old nearest-sample mask errs by its measured amount; (c) transfer-file byte-identity for a
   region with no partial cells (guards the depth block); (d) a real G1 derivation diff:
   count of cells that flip dry↔wet and the distribution of τ, pasted.
5. Reality gate (stated before looking): S-swell (<0.1 Hz) model/buoy ratio at 46222/46253
   vs the standing 0.56–0.60×; the cliff-KAT seam aggregate vs 0.578 m; direction unchanged
   within ±5°. Improvement expected but NOT assumed — the lobe-width and diffraction items in
   S8 remain separate.
**Pre-flight LANDED 2026-08-27 (`scratch/S8.1-PREFLIGHT.md`; read-only):** (1) no shipped NCEI
regional DEM contains the G1 box; (2) **NOAA NCEI CRM Vol. 6 — Southern California** (3 arc-second
≈ 90 m, public domain, THREDDS/OPeNDAP `…/thredds/dodsC/crm/crm_vol6.nc`) fully covers it — a new
catalog path (`bathymetry_resolver._OPENDAP_BASE_URL` is pinned to the `regional/` collection);
(3) samples per 1 km cell: ETOPO ≈ 5.6 (fraction step ≈ 18 % — fails KAT (b)'s 2 %), CRM ≈ 139
(step ≈ 0.7 % — meets it); (4) the LIVE mask today: 3,433 dry / 21,020 wet of 24,453 cells, and the
L1 ETOPO cache's resolution equals G1's 1:1 — **one sample per cell, no sub-cell information at all**
(the "nearest sample at the centre" rule is literally the whole mask); (5) WW3 `FLAGTR = 2` grammar
and IDLA/IDFM quotes captured from the local manual; (6) nothing writes `G1_bottom.txt`/`G1_status.txt`
today (confirmed). Datum note (journal J10): CRM is MLLW/NAVD88 while the ETOPO L1 cache is LMSL —
the wet/dry sign test at the ±0.5 m intertidal margin will move a few coastline cells; KAT (d)
reports the flip count.

**Lead mechanics (2026-08-27; now firm — the pre-flight settled the source):**
- Sequence: S8.1-PRE (done) → S8.1-A (marine: `derive_ww3_setup()` gains `open_water_fraction`,
  `depths`, `status`, `transparency` arrays; the fine-DEM fetch = CRM Vol. 6 via OPeNDAP through a
  new `bathymetry_resolver.fetch_crm_grid(bbox)` (native 3″, no coarsening; a second base-URL
  constant for the `crm/` collection; the volume name/bounds/datum/var as a small named table in
  the module, provenance-logged) persisted as `/etc/weewx-clearskies/swan_bathymetry_G1_fine.npz`
  (`numpy.savez_compressed`: `lat`, `lon` axes + `elev` int16/float32 array + a JSON metadata
  string — NOT a monolithic JSON of ~3 M floats, rules/coding.md §12.1) beside the other caches;
  refuse loudly if unfetchable (no ETOPO substitution — the pre-flight proved ETOPO cannot meet
  the KAT); `f` per cell = share of fine samples with elevation < 0 inside the cell footprint
  (centre ± half a cell; vectorised binning, no Python loops over 3 M samples); `write_ww3_grid_name_files(derivation, dir)` writing
  `G1_bottom.txt`, `G1_status.txt`, `G1_obstr.txt` in the manual's IDLA/IDFM convention; deck gains
  `FLAGTR = 2` + the obstruction read line; KATs a–d) → S8.1-B (marine `service.py`: the G10 hook —
  at the WW3 leg's start, if `level0/mod_def.provenance.json` is missing or its `derivation_sha256`
  ≠ the current derivation's, write deck + NAME files to a staging dir, `WW3Runner.run_grid()`,
  keep the old file as `mod_def.ww3.prev-<token>`, write the provenance note, and REFUSE the
  restart for that cycle with the named reason `ww3_grid_rebuilt_cold_start` (the restart was
  generated against the old grid) — a cold start follows exactly as today's cold-start path;
  operator-visible: health `ww3.gridRebuiltAt`, OPERATIONS-MANUAL procedure with the baseline/diff
  commands) → adversarial gate → reality gate (item 5) after the push.
- `F_DRY = 0.05` (Q10-2 ruled) in `swan_domain.py` beside the other WW3 G1 constants.
- **Depth values (lead, 2026-08-27):** `G1_bottom.txt` carries the ETOPO L1-cache nearest-sample
  elevation for every cell exactly as the live grid was minted (F2's convention), EXCEPT a cell
  that is WET by fraction (`f > F_DRY`) while its centre sample is land (≥ 0): that cell needs a
  water depth to be a sea point, so its bottom value = the mean of the fine-DEM samples below
  zero inside the cell (CRM, datum note J10). Cells dry by fraction keep their value (status 0
  makes it irrelevant). KAT (d) reports the count of such CRM-depth cells alongside the flips.
  Status map: 0 = excluded (dry by fraction), 1 = sea, 2 = active boundary (the existing S-row/
  W-col wet rule, now evaluated on the fraction mask); every code and the array ordering quoted
  from the local manual (pre-flight Q5: IDLA 1 = line-by-line bottom to top, free format).
- The transparency `τ = f` for wet cells; dry cells get τ = 0 in the file (irrelevant to WW3 for
  land, but keeps the array total); boundary S-row/W-col wet test reads the SAME mask.

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

D1: ARCHITECTURE.md, the four manuals, ADR-078 (per the operator-accepted amendment from M1),
ADR-101 (row-5), ADR-109 (gaps closed, D10 bootstrap), CHANGELOG — re-synced to the as-built
state; zero-drift audit by a firewalled auditor; **this plan's own** artefacts archived. The
C9–C11 plans are NOT touched by D1 (Q2 — they are the separate conversation's).

## PHASE L — lookup tables (LAST, unchanged)

Opens only on the operator's "accurate and defensible" ruling, given whenever the operator
chooses (Q1: no campaign computes it). Mandatory reading before ADR-110:
`docs/reference/LUT-INTEGRATION-RESEARCH-2026-08-17.md`.

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

### Q12 (2026-08-27) — ✅ CLOSED (operator 2026-08-27: "q12 that is fine" → option (a) accepted; the local tier stays one z7–15 file at 514 MB; Gate M1-API's size row re-based to the measured number). Original text kept below.

Plain English. The dark-theme map data for the area around the station is one file. The plan said,
before measuring, that this file should be at most 400 MB. M0 measured it: **513.6 MB** (the box is
the earthquake map's box — 200 km around the station × 1.15 — from zoom 7 to zoom 15, the marine
map's street-level zoom). The world file is 42.8 MB (under its 100 MB ceiling) and the radar file
is 195 MB (no ceiling was stated). Disk on the API host has 397 GB free, so nothing breaks; the
extract takes 11 seconds. The plan says a larger measurement is a finding for you, not a reason to
change the gate quietly. **I am building it as designed (one local file, zoom 7–15) and reporting
the number.** Options if you want it smaller: (a) accept 514 MB; (b) cap the local file at zoom 14
(coarser than street level everywhere — the marine map's z15 view would be rendered from z14 data,
which Protomaps does by over-zooming; expect roughly a quarter of the size); (c) keep zoom 15 only
for the marine box (3 MB measured) and zoom 7–14 for the rest — a fourth file, so a design change.
**Recommendation: (a)** — 0.05 % of the disk, and the operator-visible cost is one admin action.

### Q11 (2026-08-27) — ✅ RULED by the operator's own design, superseding options A/B/C:

> "the handoff point is never SET IN STONE, it needs to continuously change based upon the break
> locations. That means if it is unusually larger waves the handoff is going to move seaward …
> that is the way it was supposed to work" / "No you cannot fucking set the next cycle based upon
> the previous cycle, you need to dynamically set the handoff, if 1d starts running and finds the
> break is wrong, then it restarts the run from the correct location"

→ **S12 HANDOFF-RESTART** (design block in Phase S). The alarm's tide-datum bug (A) is fixed inside
S12, since the check's two sides are re-defined by the same round. Lead's finding that led here:
the coded "30 % margin" is measured against full breaking (`Hs/0.73`), while the beach model
calls onset at 5 % breaking fraction, which occurs at 1.72 × Hs vs the handoff's 1.78 × Hs — a
3.5 % margin in practice; and no feedback from the beach model's own break exists.

### ~~Q11 (original)~~ — the degraded-health alarm has two causes; which do we fix?

Plain English (full evidence `scratch/inv1/S11-FINDINGS.md`). The alarm compares "how deep the
wave breaks" against "how deep the ocean model hands the wave to the beach model". Two things:
(1) the alarm adds the tide to the first number and not the second — a bug in the alarm.
(2) Since Tuesday's surf change (BREAK-REFORM), the beach model reports the main break AT its own
starting line about a third of the time (was a tenth), and the typical break sits 0.4 m from that
line instead of 0.9 m. A break "at the starting line" means the wave was already breaking when it
was handed over — the handoff is placed 30 % seaward of breaking precisely so that cannot happen.
**Options:** A — fix the alarm only (compare like with like). B — also stop publishing a marker on
the starting line itself: a zone that begins at the boundary takes its marker from the first
interior point instead (changes the break-detection rule — trigger 1). C — instead/also move the
handoff deeper (changes the `1.3` margin constant — trigger 1). *Recommend: A now; B next, with a
known-answer test built from Huntington transect 4 at 2026-08-27T05Z; C only if B leaves the
"arrives breaking" fraction high, measured.*

### Q10 (2026-08-27) — ✅ FULLY RULED: the rulings the adversarial plan review showed are missing (`scratch/ADVERSARIAL-PLAN-REVIEW-2026-08-28.md`; lead re-verified #1, #2, #14, #18 at the code/live service before recording)

**Operator, 2026-08-27, verbatim: "q10 1. yes. 2. yes. 3. ok 5. ok 6. we still need the api
for the admin do we not? 7. ok 8. UMMM this is an issue is it not? … 9. FUCK OFF 10. what?"**
→ **All ten items are now ruled (6 and 8 closed 2026-08-27 later the same day; 10 ruled "worthless").**
1 RULED yes (S2 unblocked; PA6 sub-decisions A–E stand). 2 RULED `F_DRY = 0.05`. 3 RULED
(the DEM download, grid-file writers and rebuild hook are part of S8.1 — PA8 trigger-7 items
authorized). 5 RULED drop (hotstart-age gate gone; C7 closed). 7 RULED record the input
(S3 wires a `ww3_boundary` recorder instead of deleting the health entry). 9 RULED no watch.
6, 8, 10 answered back in chat, still open — see below. Item 4 ruled (a) earlier.

Each item is one decision. Plain English; the letter in brackets is the review finding.

1. ~~**[#4] Consistency score, sub-decisions A–E.**~~ ✅ yes.
2. ~~**[#5] Island transparency — the dry threshold.**~~ ✅ 0.05.
3. ~~**[#19, #6] Island transparency — three things that must be built or fetched first**~~ ✅ ok —
   (i) a one-time finer seabed download of the WW3 box (~90 m; the cached data is 1 km);
   (ii) the writers for the grid-file inputs the deck names; (iii) the rebuild-on-geometry-change
   hook — all part of S8.1.
4. ~~**[#7] Radar box view bounds.**~~ ✅ RULED (a) 2026-08-27 — operator: "Yes, but then when
   you did the research on the librewxr code, that reverse that as we found out that librewxr
   does NOT provide anything but the radar and satellite data and that we ARE responsible for
   the basemap." The provider's coverage box may shape the radar VIEW (pan limits, min zoom,
   mask — existing code, untouched); the basemap extract is sized from our own config only.
   Directive 14 reworded to say exactly that.
5. ~~**[#8] Warm-start file age check**~~ ✅ drop.
6. ~~**[#11] Esri/NAIP in the API**~~ ✅ RULED 2026-08-27 — operator: "q10/6 if we dont need it then
   get rid of it." → REMOVE (round **M4-B**, brief `docs/planning/briefs/M4B-IMAGERY-REMOVAL-BRIEF-2026-08-27.md`;
   PA9 extended). History: operator first asked "we still need the api for the admin do we
   not?" Answer given: no — the API's imagery modules, the `[imagery]` key, the admin "Imagery"
   section (`admin/routes.py:384`, `imagery_section.html`) and the wizard's "Imagery provider"
   selector (`wizard/routes.py:2113–2126`) exist ONLY to choose the surf map's aerial-photo source;
   the wizard's satellite toggle on the marine map step is a direct Esri URL in the browser
   (`step_marine.html:931`), independent of all of that, and stays. "Remove" therefore means API
   modules + key + admin section + wizard selector (API and stack repos). Awaiting the word.
7. ~~**[#26] Health's `ww3_boundary` "required input".**~~ ✅ record it.
8. ~~**[#14] Health `degraded`**~~ ✅ CLOSED — ruled "8 ok" the same day (the heading below was stale;
   operator 2026-08-27: "q10/8 why are you still marking this open?"). The task it produced (S11, absorbed
   into S12 HANDOFF-RESTART) LANDED and passed Gate S12 13/14: the check now compares untided depths at
   both sites with a 10 m clearance, and the restart loop re-runs the 1-D from the next seaward band station.
   Live confirmation (invariant 1 quiet) is held with every other live row until the push. History: the
   lead's first description was wrong. Operator: "UMMM
   this is an issue is it not? … you have NO CLUE what the fuck that error means do you." Correct.
   Traced 2026-08-27 (read-only): the check compares the beach model's break depth WITH the tide
   added (`surf_1d_analytical.py:2352`, `depths = bathy + tide_level`) against the handoff depth
   WITHOUT the tide (`_truncate_bathy_at_handoff` docstring: "RAW (chart-datum) profile depth, NOT
   tide-adjusted"). Newport Beach tide at the firing hour (05Z 08-27) was +0.88 m above MSL, so a
   break at 1.27 m of untided water reads 2.15 m and "beats" a 1.98 m handoff. The check is
   comparing two different measures — that part is a defect in the CHECK. But it only started
   firing when BREAK-REFORM (`57af5d6`) deployed: journal counts 0/day on 08-22…08-25, then 1,885
   in 08-26 09Z and ~8,000 since — so BREAK-REFORM moved the outermost break marker seaward, to
   within one tide-height of the handoff, which the 30 % handoff margin was designed to prevent.
   ✅ RULED 2026-08-27 "8 ok" — both: (b) the read-only look first, then (a) the check fix.
   → task **S11 INVARIANT-1** (checklist). Second journal count confirmed: 0 / 0 on 08-24, 08-25;
   2,219 + 4,239 + 1,184 since the deploy.
9. ~~**[#14] Monitoring.**~~ ✅ no ("FUCK OFF").
10. ~~**[#23]**~~ ✅ RULED 2026-08-27 "10 worthless" — the paragraph is removed from
    `rules/verification.md`; the register preamble's "LESSON … applied to rules/verification.md"
    claim is void.

### Q9 (2026-08-27) — ✅ RULED: carry-over register re-audit. Operator: "i am very nervous about all of the carry over tasks without going through each one and assessing what has been done and if it is still needed." Rulings, verbatim: "c1 drop c2 drop c5 again these were discussed, the fact that you did not mark that is disconcerting c6 if this was done why did you not mark it complete? geesh." / "c14 no" / "c12 has nothing to do with this plan" / "why c15 is needed if we replaced it with a new task" / C16 dissolved after a plain-English explanation. Lead findings the same pass: C7 ×2/3, C8, C18 already done; C3, C4 moot; C13 re-verified at 18 failures in two files; C19/C20 confirmed live. Register rewritten; S6 dissolved; S3/S4 rows corrected. Also disclosed: nothing is watching the marine service for failures now (the old monitor died with its chat session).

*(Plain English, self-contained, newest at top. Answered items keep their ruling here.)*

### Q8 (2026-08-27) — ✅ CLOSED by Q6 + Q10-4 (the lead kept re-asking an answered question; operator: "YOU CANNOT FUCKING ZOOM OUT BEYOND THE EXTENTS OF THE BBOX!"). The radar map is hard-limited to the provider's coverage box (`MapBoundsEnforcer` + `BoundsMask`), so its basemap is sized to exactly that box — the provider's declared coverage IS the radar view, and Clear Skies is responsible for the basemap under it. There is no "basic/world" tier for the radar map. A provider with no coverage box (RainViewer, worldwide) gets the station box under Clear Skies' own config, same as every other map — that is the only case the earlier "size from our own config" wording ever applied to. Directive 14 and M1 amended accordingly; the "coarse world beyond the box" consequence text is struck for the radar map.

### ~~Q8 (original)~~ — the radar box spans SoCal to New Mexico; the derived basemap box is ~230 km. How do we cover the dark radar view without reading the radar provider's extent?

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

### Q6 (2026-08-27) — ✅ RULED: "Ok wait, so you did not do it wrong, i apologize. So we needed to bring our own basemap. Did we need to bring our own legends too or do those need to move into librewxr?" — Answer given: yes, labels too — a radar provider's contract is overlay-only, labels are a basemap layer, so both stay in Clear Skies from the product basemap. **Operator's acceptance of that answer, next message: "q6 correct... but the radar box will blow all of our other sizings out the window as it covers most of the SW well into New Mexico"** (the second half opened Q8). M2 cancelled, M3 becomes RADAR-REBASE, directive 13 amended, the two capability fields are NOT added. (Review finding #3 flagged the missing acceptance quote; it existed in chat and is now recorded.)

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
