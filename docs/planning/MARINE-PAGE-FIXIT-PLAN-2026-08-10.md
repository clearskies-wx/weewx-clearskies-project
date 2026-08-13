# Marine Page Fixit Plan — boundary plug-in, ruled card fixes, break/zone redefinition (2026-08-10)

## INDEX — ALPHABETICAL (operator order 2026-08-13: keep this current; sections below sit in chronological log order, so FIND THINGS HERE. Every new `##` section gets an entry the same commit.)

Ctrl-F the exact heading text:

- `## 📍 CURRENT STATE` — live-deploy table, rulings, waiting-on-operator
- `## NAMED CONSTANTS` — plan-fixed values agents may not re-derive
- `## OPEN OPERATOR QUESTIONS`
- `## PHASE B2` — Boundary: one spectrum per wet WW3 cell
- `## PHASE DOC` — governing-doc updates (CLOSED)
- `## PHASE H` — Heat map + small display fixes
- `## PHASE K` — Break markers + crash-band impact zone
- `## PHASE M` — Main map layer reliability (CLOSED)
- `## PHASE S` — Swell-conditions card ruled ranges
- `## PHASE T` — Tide coherence
- `## PHASE Z` — Forecast-hole diagnosis + Z3 wind-gatherer rounds (Z3.1–Z3.11 records inside)
- `## PLAN AMENDMENT A1` — **Big-L1 / true-non-stationary FIX (ORDERED — the critical path)**
- `## PRE-APPROVAL REGISTER` — which architectural changes this plan authorizes
- `## PRIME DIRECTIVE`
- `## Round-close & bookkeeping`
- `## SWAN SYNTAX PRESCRIPTIONS`

## 📍 CURRENT STATE — updated every working session (last: 2026-08-13 ~07:55Z)

**2026-08-13 delta (authoritative over the older table below):** marine live = `338b899` (Z3.9
chain; **gate A PASSED live 06:21:39Z** — first successful store-driven full run, reality-gate
rows recorded in Phase Z). `634775b` (Z3.11 sub-5s dominant-eligibility floor, adversarial gate
PASSED 0 findings) **PUSHED 07:40Z, deploy pending** the post-06Z-full-run gap. **OPERATOR
RULINGS 2026-08-13:** R1 sub-5s never dominant (shipped, Z3.11); R2 wind double-count
investigation (done, Z3.10); **ALL EYEBALL ACCEPTS FROZEN — "not eyeballing anything else until
you get the model right." B2/S/K/H re-accepts resume only after PLAN AMENDMENT A1 (the ORDERED
big-L1 fix) passes its reality validation (task A1.5).** A1 is the critical path.

**RESUME POINTER (updated 2026-08-12 ~05:15Z sign-off): the 2026-08-12 session's scratchpad
`SESSION-STATE.md` (glob `%LOCALAPPDATA%\Temp\claude\c--CODE-weather-belchertown\*\scratchpad\SESSION-STATE.md`,
newest) holds the MORNING CHECKLIST — gate A verification (did the 06Z/12Z full runs fire),
retention/health checks, B2-Accept re-check, lessons queue, parking-lot additions, traps.
Authority order: this table → Phase records below → SESSION-STATE.md.**

| | |
|---|---|
| **Live on librewxr** | RUNNING SERVICE = marine **`1ff5124` (Z3.5 amended round) DEPLOYED 2026-08-11 21:50:44Z** (deploy-marine.sh full run; health 200, auth enforced; restart hit an idle service — the 20Z fast cycle had completed 21:42:02Z, 661s warm). **Post-deploy evidence:** zero display-wind warnings across 657 request-activity journal lines; served bundle probe: 67/67 timesteps wind-classified (glassy 36 / onshore 18 / cross-onshore 13, station t=0 + hrrr 66 — varied, non-null, hybrid working end-to-end); journal sweep: only pre-existing warning classes. Fast-cycle cadence real: 19Z (1175s) + 20Z (661s) both store-driven complete. Reality gate A (first store-driven FULL run) still pending 00Z assembly ~01:47Z — monitor armed; `/health` inputs artifact (ww3_boundary/bathymetry "unavailable" until first full run this process) expected to clear then. Prior history (12:31→20:30Z all-runs-refused window, fixes `c812d94`+`0ebdd01`): see Z3.5 STATUS block. |
| **Live on weather-dev** | dashboard `1d37593` **DEPLOYED** (dry-beach fix pushed + redeployed 2026-08-11; was parked) |
| **OPERATOR RULINGS 2026-08-11** | (1) T deploy **OK** → done; (2) CTHETA/CSIGMA L1 experiment **OK** → dispatched to wave-trace agent (scratch copy, deck-only change, no production edit — permanent limiter change stays an architectural decision for the operator); (3) push+deploy `1d37593` **OK** → done; (4) new-source investigation **NO** — source is **USGS NAIP Plus** via API exportImage proxy; operator pointed out we weren't requesting native resolution — CONFIRMED (measured: 75/99 live tile requests at z17 = 1.0 m/px vs 0.6 m native) → **remedy operator-approved ("fine") and DEPLOYED: tile raster 256→512px (api `e729a97`, deployed to weewx 2026-08-11), now ~0.5 m/px at-native; cache key versioned; live tile verified 512px + visibly sharp** |
| **Also live on weewx** | api `e729a97` (NAIP 512px raster) deployed 2026-08-11 |
| **STRUCK/OPEN** | B2-Accept (open until L1 wave corruption fixed — served list must show the real trains); H-Accept (open: dry-beach fix parked + ortho quality) |
| **Phases DONE** | ✅ **M** (dashboard `eb424fd`+`73d9017` DEPLOYED to weather-dev; Gate M PASS, repro capture clean — see Phase M gate record). ✅ **DOC** (meta `7e53927`, 12 files docs-only; Gate DOC PASSED 2026-08-10, adversarial audit 0 findings — rows 1–6 all PASS with evidence; lead independent checks: allowlist diff exact, ADR-106↔PA1–PA5 1:1, 25 m confirmed wording, zero Z2 content). ✅ **Z1** (diagnosis; Q1 answered by 2026-08-03 ruling). Z2 ruled no. |
| **Remaining** | Phase DOC → B2 → S → K → Z3 (marine chain, strict; Z3 = wind-gatherer migration steps 2–5 per the approved 2026-08-03 design) ; H → M (dashboard chain, may interleave after DOC) |
| **WAITING ON OPERATOR** | (1) S-Accept card eyeball; (2) K-Accept rows 1 (cam eyeball) + 3 (knob drill go); (3) H re-accept eyeball (both remediations deployed); (4) Phase T close acknowledgment. Q3 RULED 2026-08-11 ("built wrong, fix it" — permanent hybrid, defect-fix classification). **Z3.5b PUSH+DEPLOY PRE-AUTHORIZED (operator 2026-08-11 in chat: "you can push/deploy after the adversarial audit and fixes")** — sequencing: agent closeout → lead acceptance gate → adversarial auditor → remediations → commit → push → deploy-marine.sh → post-deploy reality checks (fallback-warning silence, publish-liveness, journal sweep) + reality gate A evidence (00Z store-driven full run, monitor armed). |

**Operator rulings received 2026-08-10 (in chat, at GO):** (1) **GO** — "Let's execute the
entirety of the plan"; (2) **crash-band width 25 m CONFIRMED** ("25m proposed crash-band width
is fine") — §Named constants default is final; (3) **Z2 ruled NO** ("Z2, no") — no data-age
badge / staleness display on cards; Z2 is CLOSED with no implementation, and Z3's potential
scope reduces to whatever Z1's forecast-hole ruling produces.

**Created:** 2026-08-10 (operator-directed, in chat: "turn this into a full plan now… design work
is done now, not left to an agent. It has granular tasks, qc gates and agent assignments. Need to
do any doc updates prior to any code work as agents depend on the docs").
**Status:** DRAFT-COMPLETE — execution begins on operator go.
**Evidence record / authority:** [MARINE-PAGE-FIXIT-2026-08-10.md](MARINE-PAGE-FIXIT-2026-08-10.md)
— the research log holding every measurement, screenshot transcription, root-cause trace, and the
operator rulings of 2026-08-10 (all issued in chat, quoted there). This plan does not restate the
evidence; it turns the rulings into tasks. Live-data artifacts referenced by tasks (DWR partition
table, decomposed boundary files, WW3 corridor survey values) are preserved in the session
scratchpad and their key numbers are quoted in the fixit log.

**THIS PLAN IS THE ARCHITECTURAL PERMISSION** (same convention as
L1-BOUNDARY-REBUILD-PLAN, operator 2026-08-08: "The plan serves as permission for architectural
changes, so if it is in the plan, it is allowed"). The **Pre-approval register** below enumerates
every authorized architectural change. A change NOT in that register remains under the CLAUDE.md
HARD BLOCK — the agent STOPs and reports; the coordinator takes it to the operator.

**Relationship to other live plans:**
- [L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md](L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md) stays ACTIVE
  (its deferred queue: Gate S wlevel → S1+S4a currents → Phase A → Gate C → V). THIS plan:
  (a) **supersedes its ruling D4 / register row P4's 1-km boundary-point spacing** (operator
  re-ruling 2026-08-10 — see PA1); (b) **absorbs the C3S "next-session first action"**
  (registration check → task H0 here); (c) **supersedes its P13 card-aggregate field set**
  (operator re-ruling — see PA3); (d) retires the parking-lot "SWAN 99-file command cap" concern
  (B2 cuts file count ~194 → ~20). Its Gate C row for C1 is satisfied-then-superseded: the C1
  card changes again in Phase S here. Cross-references land in that plan during Phase DOC.
- [MARINE-FORWARD-PLAN.md](MARINE-FORWARD-PLAN.md) open rows are untouched; its frozen-core list
  binds here except where a task's Files list names the file.

---

## PRIME DIRECTIVE — carried over, binding on every task

1. **Frozen core is OFF LIMITS unless a task's Files list names the exact file.** This plan
   NAMES (and therefore opens, for the named tasks only): `services/boundary_reconstruction.py`
   (B2.1), `services/swan_formats.py` boundary-emission block only (B2.2),
   `services/surf_1d_analytical.py` break-publication + zone-classification sections only (K2,
   K3), `endpoints/surf.py` aggregate block (S1), `endpoints/beach_profile.py` zone serving
   (K3). Everything else in the frozen-core lists of MARINE-FORWARD-PLAN / L1 plan stays closed
   — explicitly: wave physics marches, jacking, hotstart mechanics, convergence gate,
   serve-nothing guard, `CIRCLE 72 0.03 1.0 34`, `omp_num_threads = 6`, L2/L3/L4 sizing.
2. **Baseline before, diff after** every deploy (facing, DWR Hs, valid_fraction, publish size,
   cycle wall-clock, boundary file count/bytes). rules/coordinator.md §7.
3. **One functional change per deploy.** Phase order exists so each deploy is one comparable
   change.
4. **Reality gate on every deploy** (rules/verification.md): matched-time comparison vs NDBC
   46222/46253 + Surfline buoy cards + cam within one cycle, quantities chosen before looking;
   publish-liveness.
5. **Stale tests → STOP and surface** (rules/agents.md block, verbatim in every brief). Tests
   pinning behavior this plan changes are updated IN THE SAME COMMIT as the behavior change,
   per task spec; any OTHER failing test is a finding.
6. **Agent discipline:** every implementation task runs on a Sonnet agent with a written brief
   containing the rules/agents.md mandatory blocks (git, stale-test, architectural) + scope-ack
   before code + adversarial `clearskies-auditor` pass BEFORE the lead gate + doc-sync in the
   same round.
7. **Line numbers are hints, not gospel.** First action of every agent: verify quoted state;
   drift → STOP and report.
8. **No silent fallbacks.** Missing data → refuse loudly; constrained geometry → best physical
   answer, silently. Never a fabricated default.
9. **Plain-English displays.** Any operator-facing text an agent adds follows the fixit log's
   vocabulary, not internal codenames.

**Execution order (strict within each chain):**
**Phase DOC → Phase B2 → Phase S → Phase K** (marine repo — one round in flight at a time, one
deploy per phase). **Phase H → Phase M** (dashboard repo — dispatch after Gate DOC, may
interleave with the marine chain; H0 blocks the rest of H). **Phase Z** (Z1 read-only diagnosis
— may run any time; Z3 only after its ruling).
**Phase DOC precedes ALL code work (operator instruction 2026-08-10: "Need to do any doc updates
prior to do any code work as agents depend on the docs").**

---

## PRE-APPROVAL REGISTER — the architectural changes this plan authorizes (and no others)

| # | Change | Trigger(s) | Ruling |
|---|--------|-----------|--------|
| PA1 | L1 boundary data contract: 1-km per-L1-cell boundary points REPLACED by **one spectrum per wet WW3 cell** along each offshore side; SWAN performs the along-side spectral interpolation (manual-documented behavior). Supersedes ADR-104 P4 spacing + ruling D4. The spatial sampling layer (per-slot bilinear/nearest-wet parameter interpolation) in `boundary_reconstruction.py` is DELETED — root cause of the slot-mixing defect (fixit log Item 1) | 2, 3, 4 | operator 2026-08-10 chat: "We should be plugging in WW3 swells from its cell… why are we needing to average?" + "SWAN handles the interpolation, we should not be interpolating and then having SWAN interpolate our interpolation" |
| PA2 | Surf wire shape: ADD `periodMinS`/`periodMaxS`; REMOVE `combinedPeriodS` (physics-rejected: "the period should never be combining periods, that is not how the physics works") and `faceHeightMinFt`/`faceHeightMaxFt` (only consumer rebinds to `modelSurfHeightMin/Max`). Supersedes L1 plan P13's field set | 4 | operator 2026-08-10 chat (Item 2 rulings) |
| PA3 | New config keys `[surf] qb_breaking_onset` (default 0.05) and `[surf] impact_zone_width_m` (default 25.0), operator-adjustable, validated at config push | 1, 7 | operator 2026-08-10 chat: "I want the ability to adjust the breaking threshold" / "just make that a fixed distance" |
| PA4 | Published break markers DECOUPLED from the breaking-cessation machinery: one marker per distinct crash point (local dissipation maximum, prominence rule, §Named constants); published impact zone REDEFINED as a fixed-width crash band per marker, clipped at the waterline; foam zone becomes pure geometry (last band → waterline); `reformTrough` serves null. Internal physics marches UNTOUCHED. Amends ADR-102's published-output section | 1, 4 | operator 2026-08-10 chat (Item 4 rulings, incl. the marker-decoupling dependency accepted in chat) |
| PA5 | Beach-profile/impact-zone doc contract: dashboard `types.ts` "50% energy loss" impact-zone description replaced by the PA4 definition (resolves the 5%-vs-50% doc-code drift) | 4 (docs of a contract) | follows from PA4 |
| PA6 | Item-0 forecast-hole handling: **NOT pre-approved.** Z1 produces a ruling brief; any fix that moves the HRRR/GFS blend boundary, changes cycle scheduling, or adds a wait/retry cadence is architectural and goes to the operator | — | explicitly withheld |

Display-only changes (no trigger hit, listed for scope clarity): heatmap framing + tile budget
8 + smoothing raster + attribution/notes relocation + card 4x2 + fullscreen overlay (H); surf
score footer deletion (H5); beach-profile axis-label collision fix (H6); map tile-error
handling + atomic theme remount (M); card range-rendering rebinds (S2).

---

## NAMED CONSTANTS fixed by this plan (not re-derivable by agents)

- `qb_breaking_onset` default **0.05** (today's `Q_B_VISIBLE` value; becomes the config key's
  default — the constant moves, its value does not change at ship time).
- `impact_zone_width_m` default **25.0 m** — the fixed crash-band width, shoreward from each
  break marker, clipped at the waterline. **CONFIRMED by operator 2026-08-10 at GO**;
  adjustable at runtime, so a wrong default is a config edit, not a code change.
- `_BREAK_PROMINENCE_FRACTION = 0.30` — a local dissipation maximum publishes a marker only if
  its prominence ≥ 30% of its region's largest maximum (K2; keeps noise ripples from publishing
  markers). Pinned constant, not a config key.
- Existing `_MIN_BREAK_DEPTH_M` / `_MIN_BREAK_HS_M` marker filters: UNCHANGED, still applied.
- Q_b cessation 2% (`Q_B_CESSATION`): UNCHANGED and internal-only after K2 (physics state, no
  longer feeds publication).
- Boundary endpoint rule (B2.2): first/last supplied position per side = **len 0.0 and
  len = side length**, each a byte-copy of the nearest selected wet cell's spectrum file —
  guarantees full-side coverage independent of SWAN's beyond-endpoint behavior.
- Boundary viability floor (B2.1): **≥ 2 wet WW3 cells per offshore side**, else
  `BoundaryNotViableError` (loud refusal, existing role).
- Registration tolerance (H0): pier ground anchor projected through the data transform and the
  imagery transform must agree within **≤ 10 m ground distance**.
- Imagery: `IMAGERY_ZOOM_MIN/MAX` unchanged [14, 19]; `IMAGERY_MOSAIC_MAX_TILES_PER_SIDE`
  **4 → 8**; accept target background resolution **≤ 1.5 m/pixel** at default card size.
- Map tile-error policy (M1): after **3** consecutive tile errors on a layer → visible banner
  ("Map imagery failed to load — retrying"), retry with 5 s backoff, max **3** retries per
  mount; banner clears on first successful load.
- All reconstruction spectral constants (JONSWAP γ 3.3, cos²ˢ spreads s=28/s=7, adaptive σf
  rule `min(0.015, max(0.005, Δf/3))` within 45°, 35×72 spectral axes, bin-sum identity ≤ 5%,
  HTSGW-inconsistency guard 0.1 m): **UNCHANGED** — B2 changes WHERE spectra are built (per
  cell, no spatial averaging), never HOW a single cell's spectrum is built.

---

## SWAN SYNTAX PRESCRIPTIONS — from the LOCAL manual, binding on Phase B2

*(Sources: `docs/reference/swan-user-manual.txt` line cites below; L1-BOUNDARY-REBUILD-PLAN
§SWAN SYNTAX carries over except where amended here. Downloading SWAN docs is forbidden.)*

1. **Command grammar UNCHANGED:** `BOUNDSPEC SIDE <W|S|E|N> CCW VARIABLE FILE <len_1>
   'B_<side>_<0001>.txt' 1 …` — one command per offshore side, `[len]` in UTM metres from the
   side's CCW begin corner, strictly ascending, `[seq] = 1`, `&`-continuation wrapping per the
   B-Accept fix. Corner map (S begins SW, W begins NW, …) carries over verbatim.
2. **What changes is the POSITION LIST:** one `[len]` entry per selected wet WW3 cell (its
   centre projected onto the side) plus the two endpoint copies (len 0.0 and side length).
   Manual authority for letting SWAN fill the 1-km boundary grid points between entries:
   *"The wave spectra for grid points on the boundary of the computational grid are calculated
   by SWAN by the spectral interpolation technique described in Section 2.6.3"* (manual
   :2481-2486, VARIABLE FILE description); *"these points do not have to coincide with grid
   points of the computational grid"* (:2507-2509); `[len]` metres-in-Cartesian + ascending
   (:2509-2515). Spectral-space interpolation of the FILES' axes does not occur — we emit on
   the CGRID spectral axes exactly (35 log freqs / 72 dirs), unchanged.
3. **File grammar UNCHANGED:** Appendix-D nonstationary 2-D spectra, `SWAN   1` header, TIME
   coding 1, AFREQ 35 / NDIR 72, VaDens m2/Hz/degr, per-timestep FACTOR, frequency-major
   matrix — the existing `write_swan_2d_spectrum_file()` writer is reused byte-for-byte in
   format. LOCATIONS carries the WW3 cell centre in UTM (truthful; ignored by SWAN for
   placement — :2555-2557).
4. **FORBIDDEN, never emitted** (unchanged): `BOUNDSPEC … PAR`, TPAR, `BOUND SHAPE`,
   `BOUNDNEST2/3`. `BOUNDNEST1 NEST 'nest_in.dat' CLOSED` nest chain untouched.

---

## PHASE DOC — governing documents to the ruled target state, BEFORE any code — ✅ CLOSED 2026-08-10 (all tasks done; Gate DOC PASS, 0 findings; meta `7e53927`)

**Owner:** `clearskies-docs-author` (Sonnet), content sourced ONLY from the fixit log's ruling
records and this plan. **QC:** `clearskies-auditor` at Gate DOC. **No implementation phase
dispatches until Gate DOC passes.**
**Convention:** every not-yet-deployed behavior carries the tag
**`(ruled 2026-08-10; lands with Phase <X> of MARINE-PAGE-FIXIT-PLAN)`**; the implementing
phase's doc-sync removes the tag on deploy.

### DOC.1 — New ADR-106 + amendments — ✅ DONE 2026-08-10
New **ADR-106 — Marine page fixit rulings 2026-08-10** (status: Accepted; records, with the
fixit log as evidence: the slot-mixing root cause; PA1 per-WW3-cell boundary + SWAN
interpolation + why the D4 1-km spacing is superseded (station-era fear vs 16-km neighbors);
PA2 period-range physics ruling verbatim; PA3 adjustable threshold + fixed crash band; PA4
marker decoupling + prominence rule; the named constants). Amendment notes in **ADR-104**
(P4/D4 superseded → pointer to ADR-106) and **ADR-102** (published-marker/zone section
superseded → pointer; internal Q_b/roller physics unchanged). `docs/decisions/INDEX.md` rows.

### DOC.2 — ARCHITECTURE.md — ✅ DONE 2026-08-10
Tagged rewrites: the L1-boundary bullet (:120 region — per-WW3-cell files, SWAN interpolates,
sampling layer deleted); the SWAN-outputs paragraph's break-point/impact-zone sentences (PA4
definitions); the P13 aggregate-fields sentence (PA2 field set).

### DOC.3 — PROVIDER-MANUAL — ✅ DONE 2026-08-10
§14.3a reconstruction spec rewritten to the per-cell design (B2.1/B2.2 content verbatim:
cell-row selection, endpoint copies, viability floor, constants unchanged table); note that
the corridor fetch (B1, §14.3) is untouched.

### DOC.4 — API-MANUAL + openapi + DASHBOARD-MANUAL + OPERATIONS-MANUAL + DESIGN-MANUAL — ✅ DONE 2026-08-10
API-MANUAL surf-bundle field table + `openapi-v1.yaml`: add `periodMinS/periodMaxS`, remove
`combinedPeriodS` + `faceHeightMinFt/MaxFt`, breakPoints may carry >1 entry, perBreakZones
band semantics (PA4), `reformTrough` always null (tagged). DASHBOARD-MANUAL: card 3 bindings
(modelSurfHeightMin/Max + period range), heatmap section (framing rule, tile budget 8,
smoothing raster, attribution/notes in info modal, 4x2 + overlay), map layer/error-handling
contract, beach-profile marker rendering (all served markers, unchanged) (tagged).
OPERATIONS-MANUAL: the two new `[surf]` config keys + validation + how to tune them (tagged).
DESIGN-MANUAL: marine card table gains the missing Heat Map row (4x2, overlay pattern);
`types.ts` impact-zone comment text prescribed (PA5).

### QC GATE DOC — `clearskies-auditor`, adversarial — ✅ PASS 2026-08-10 (0 findings)
Rows: (1) every doc statement traceable to a fixit-log ruling or a plan design line (spot-map
10 random claims; any orphan = FAIL); (2) every target-state section tagged; (3) no
live-behavior claim changed where behavior hasn't; (4) ADR-106 covers PA1–PA5 completely
(diff against the register); (5) INDEX consistent; (6) git diff shows docs only.

---

## PHASE B2 — Boundary: one spectrum per wet WW3 cell, SWAN interpolates *(PA1 — fixit Item 1)* — 🟡 CODE SHIPPED+DEPLOYED (B2.1–B2.3 ✅, Gate B2 ✅ PASS, mechanism proven live); **B2-ACCEPT ⛔ STRUCK/OPEN** — blocked on the L1 wave-corruption fix (served list must show the real trains). Investigation 2026-08-11: **refraction-limiter mechanism REFUTED** by controlled three-way scratch experiment on librewxr (control vs CTHETA 0.9/CSIGMA 0.9 vs Dietrich-2012 tuned 0.5/0.25 — west-swell energy flat 2.4–3.1% at all probes, south bearings locked 192–198° in all three; WAVE-TRACE-FINDINGS.md addendum). ALL internal candidates subsequently closed by experiment (NONSTAT short+48h; ST6→WESTHUYSEN A/B = exact null). ~~"PRIMARY gap is UPSTREAM (WW3 input-data limitation)"~~ **STRUCK BY OPERATOR 2026-08-11: invalid comparison.** The verdict compared buoy observations against the OFFSHORE WW3 boundary input — but 46222/46253 sit INSIDE L1's domain, landward of the islands, in the channel. Operator (verbatim intent): the buoys are equal to the OUTPUT of L1, not to WW3; the channel WSW wind-sea is locally generated water that never needed to cross the boundary — L1 must GROW it internally from wind forcing. What survives from Addendum 4: boundary reconstruction mirrors raw WW3 hour-for-hour (hour-offset ruled out); L1 interior tracks boundary TIMING; the ~2.5–3x west-energy attenuation remains real and unexplained. **CORRECTED analysis result (Addendum 5, 2026-08-11): WIND FORCING LOCATED AS THE DEFECT CLASS.** Both buoys confirmed INSIDE L1 (~11–23 km west of L2). L1 has NO output at their locations (no POINTS/TABLE anywhere in its INPUT — the like-for-like is formally unanswered; POINTS design on file). Decisive: our WIND.txt at both buoy cells sits 277–320° (WNW/NW) ALL DAY while the real channel wind station (PRJC1, LA Pier J) observes 240° WSW at 4.6 m/s — wrong direction by ~40° at the matched hour and ~30% weak. L1 cannot grow the WSW sea the buoys measure from wind that never blows WSW in its forcing. NOT yet established whether the bias is in raw HRRR or introduced by our gathering/stitching (raw-HRRR audit = named next step, NOT run). **Investigation STOOD DOWN 2026-08-11 on operator order (all effort to plan code phases); Z3 wind-gatherer migration (steps 2–5) rebuilds the implicated wind chain. Full record: WAVE-TRACE-FINDINGS.md Addenda 1–5, scratch artifacts on librewxr /tmp.**

**Owner:** `clearskies-api-dev` (Sonnet). **Tests:** `clearskies-test-author`. **QC:**
`clearskies-auditor` at Gate B2. All code in `repos/weewx-clearskies-marine/`.

### B2.1 — Reconstruction rework: per-cell spectra, sampling layer deleted — ✅ DONE 2026-08-11 (marine `39504a0`)
**Files:** `services/boundary_reconstruction.py`; `services/grid_sizing_chain.py` (config-time
viability check only).
**Design (decided, complete):**
- DELETE `_bilinear_corners`, `_sample_scalar`, `_sample_direction`, `_sample_train`,
  `_sample_point_partitions`, `_nearest_wet_value` and the per-point sampling loop — the
  entire spatial parameter-interpolation layer (root cause, fixit Item 1 UPDATE).
- **Cell selection per offshore side** (sides from the existing `_offshore_sides` logic,
  unchanged): for a S/N side (east–west line), the WW3 cell ROW whose centre latitude is
  nearest the side's latitude; for a W/E side (north–south line), the cell COLUMN nearest the
  side's longitude. From that row/column, every WET cell (existing ≥9998 missing-mask test on
  HTSGW) whose centre projects within [0, side_length] onto the side. Each selected cell →
  one boundary position at `len` = UTM projection of the cell centre onto the side.
- **Per-cell spectrum:** built from that cell's OWN partition values only — wind sea
  (`WVHGT/WVPER/WVDIR`, absent-if-missing = calm, legitimate) + swell slots 1–3
  (`SWELL/SWPER/SWDIR`; a missing slot contributes nothing). Single-cell construction math,
  constants, W0 adaptive σf, spreads, normalization, bin-sum identity guard, HTSGW
  inconsistency guard (all-slots-zero while cell HTSGW > 0.1 m → raise): ALL UNCHANGED —
  they now just read one cell's numbers with zero spatial math.
- **Viability:** < 2 selected wet cells on any offshore side → `BoundaryNotViableError`
  (cycle refusal, existing role). `grid_sizing_chain.py`'s config-time smoke test updates to
  the same criterion (was: every boundary point maps to wet cells).
- Timesteps unchanged: one file per position carrying every step of the cycle window.
**Verification command (agent, pre-closeout):** targeted pytest for
`tests/test_boundary_reconstruction.py tests/test_partition_fields.py` on librewxr (no full
suite; check no SWAN cycle in progress first).

### B2.2 — Emission: fewer positions, endpoint copies, grammar unchanged — ✅ DONE 2026-08-11 (same round; live: 15 files vs 194)
**Files:** `services/swan_formats.py` (`ww3_boundary_files_and_command()` only),
`services/swan_runner.py` (file-writing call site only).
**Design (decided):** position list = B2.1's per-cell `len`s, strictly ascending, PLUS the two
endpoint byte-copies (len 0.0 / len side_length, §Named constants). Same file naming scheme,
same `&`-wrapping, same one-command-per-side. Expected scale: ~7–10 cells + 2 copies per side
(≈ 20 files total vs today's 194). The 180-char line guard and continuation reader stay.

### B2.3 — Tests (test-author) — the misalignment case becomes a permanent KAT — ✅ DONE 2026-08-11 (`3ef48ed`+`d9301cf`; 8 KATs, 13 stale deleted per scope-ack)
**Files:** `tests/test_boundary_reconstruction.py` (rework), `tests/test_partition_fields.py`
(untouched unless imports break — B1 fetcher is out of scope).
KATs (all falsifiable — each demonstrated to fail against the OLD sampling code where
applicable): (a) **misaligned-slot fixture built from the REAL 2026-08-10 corridor survey
values** (fixit log Item 1 UPDATE: adjacent cells carrying 9.8 s/277° vs 3.6 s/259° vs
8.7 s/172° in the same slot) → each cell's emitted spectrum contains ONLY its own trains; a
distinct ~10 s west lobe exists at the west-side position whose cell carries it; NO position
anywhere emits a train whose period matches no source cell (the anti-fabrication property —
the 7.2 s ghost train must be impossible); (b) position/`len` geometry vs a hand-computed UTM
fixture incl. the two endpoint copies and ascending order; (c) wet-mask: a land cell in the
row is skipped and its neighbors' positions are unaffected; (d) < 2 wet cells on a side →
raise; (e) bin-sum identity per cell (kept from old suite, re-pointed); (f) K2-style direction
convention KAT re-pointed at the per-cell path. **Old sampling-layer tests:** updated or
deleted ONLY as enumerated in the scope-ack (stale-test protocol; every deletion listed in the
closeout with its replacement).

### B2-Accept (live, librewxr — deploy alone) — ⛔ OPEN (operator-struck 2026-08-11; see strike record below)
**⚠ GATE EVENT (2026-08-11 02:41Z, deploy restart):** the restart crash-looped
(status=226/NAMESPACE, `/run/weewx-clearskies` missing) — the deploy reinstalled the
repo/script unit, which still carried the Item-0 crash-loop defect the operator had
repaired live on 2026-08-10; the live fix was never mirrored into the repo. Remedy:
runtime dir recreated (~90 s outage, service recovered and immediately began the
restart-triggered 00Z full run on the NEW boundary code); durable fix landed twice —
marine `cb6bfb3` (packaging unit) and the meta deploy-script heredoc (the one that
actually installs) — `RuntimeDirectory=weewx-clearskies` + `Preserve=yes`, so a host
reboot can never reproduce the Item-0 crash loop again. Lesson queued: operator hotfixes
on deployed state must be mirrored into the repo/deploy script same-day.
1. Matched-cycle before/after: run the last pre-deploy cycle's WW3 inputs through the new
   path; **west-side boundary file at the cell nearest (33.33, −118.83) must show a distinct
   ~10 s lobe at ~277°** (the train today's file lacks — fixit log measurement); south-side
   file must show the 8.5 s SSE shoulder as its own lobe where its cell carries it.
2. First post-deploy cycle: "Normal end of run", zero NEW warning classes, publish-liveness,
   boundary file count/bytes recorded (expect ≈ 20 files; parking-lot 99-file concern retired).
3. **Reality gate (pre-declared):** served `multiSwell` at matched time vs the Surfline buoy
   cards: a genuine ~10 s-class W train present when WW3's corridor carries one (not a
   fabricated ~7 s intermediate); the SSE train present when carried; combined DWR Hs within
   ±25% of 46222/46253.
4. Baseline diff table (PRIME DIRECTIVE 2) incl. cycle wall-clock delta (expect neutral or
   faster — fewer files) and headline face-height delta RECORDED with the cam check.
5. Journal sweep: zero new ERROR/WARNING classes.

**B2-ACCEPT RECORD (2026-08-11 ~03:45Z; deploy `d9301cf`+unit fix, restart 02:42Z):**
- **Row 2 run/publish: PASS.** 00Z full cycle on the new code: "SWAN run complete in
  2515s — 1/1 spot(s) cached" (cold start, no hotstart — baseline 1464 s was hotstarted;
  true wall-clock delta measures on the next warm cycle). Boundary: side S = 6 wet cells,
  side W = 5, 25 timesteps each → **15 files** (8 S + 7 W incl. endpoint byte-copies) vs
  ~194 old; INPUT carries exactly 2 BOUNDSPEC commands, lens ascending from 0.0.
  (Housekeeping parking-lot: ~181 stale old-design B_*.txt remain on disk, inert — INPUT
  never references them; cleanup candidate.)
- **Row 1 lobe check: PASS.** Lead's independent decode of the live W-side files:
  B_W_0003–0006 carry a distinct **9.7 s lobe at 265–280°** (15–18% of cell energy)
  alongside the dominant 13.2 s @ 190–195° S groundswell; cells 0000–0002 (whose WW3
  cells don't carry it) correctly lack it; endpoint copies byte-identical. NO ~7 s ghost
  at any position. The per-cell fidelity the fix promises, live.
- **Row 5 journal sweep: PASS.** Error classes during the run: HRRR posting-lag 404s
  (pre-existing), WCOFS `NetCDF: file not found` (18 hits in prior 3 days —
  pre-existing), stofs_wlevel 404 (pre-existing). **Zero new classes.**
- **Row 3 reality gate: FAIL AS PRE-DECLARED, ruling surfaced to operator.** Matched time
  03:00Z vs buoys 02:56Z. Dominant train: served 0.46 m @ 13.4 s @ 196° vs 46253 swell
  0.6 m @ 13.3 s S / 46222 0.5 m @ 14.3 s SSE → −8%..−23%, WITHIN ±25%. But TOTAL: served
  quadrature 0.59 m vs buoy WVHT 0.9/0.8 m → **−34%, outside the pre-declared ±25%**. The
  entire miss sits in the mid-period W/WSW band (46222 wind-wave 0.7 m @ 8.3 s WSW; we
  serve only 3.7 s chop there). Context the ruling needs: (a) the boundary NOW carries the
  9.7 s W energy faithfully (row 1) — the deficit arises between boundary and the 15 m
  DWR, where Catalina/San Pedro shadowing of W energy is real physics the deep unsheltered
  buoys don't feel; (b) the OLD code's better-looking totals in this band were partly
  FABRICATED (the 7.2 s ghost carried invented W energy) — rolling back would restore
  agreement-by-fabrication, the exact "total right, distribution wrong" failure mode;
  (c) the ±25% row compared a deep-ocean buoy total against a sheltered 15 m nearshore
  reference — arguably not like-for-like. **Lead recommendation: ACCEPT B2 (no rollback),
  open a follow-up item to (i) verify the W-band attenuation boundary→DWR is physical
  (SWAN field inspection next cycle) and (ii) re-pin the reality-gate quantity to a
  like-for-like comparison.** Operator ruling awaited; Phase S dispatch HELD until then.
- **Follow-up (i) EVIDENCE (lead decode of `SPEC_DWR_1.txt`, the 15 m reference's own
  spectrum):** 13.2 s @ 198° (75%) + **10.7 s @ 198° (9%) — a distinct secondary S train
  the old smearing had merged away, now resolved** + 16.2 s @ 198° (5%) + 3.8 s @ 282°
  chop (8%). The boundary's 9.7 s W lobe attenuates crossing to the reference —
  consistent with Catalina/Palos Verdes shadowing of W energy at this spot, which the
  deep unsheltered buoys don't feel. The W-band deficit vs buoy totals is
  geometry-consistent physics, not lost input: the energy enters the domain (row 1) and
  SWAN shadows it. Strengthens the ACCEPT recommendation.
- Tag lift (PROVIDER-MANUAL §14.3a / ARCHITECTURE) held with the same ruling.

**⛔ OPERATOR STRIKE (2026-08-11, chat): B2-ACCEPT REJECTED; ALL WORK FROZEN; RESEARCH
ROUND ORDERED.** The operator rejected the accept recommendation and the shadow/refraction
explanations as unresearched: (1) the served list STILL shows one swell — failing the
fixit log's own Item-1 acceptance ("the served list must show a real ~10 s west train …
and the SSE train") — the coordinator wrongly recommended accept on boundary-mechanism
evidence instead of the served outcome; (2) buoys LANDWARD of Catalina measure the 8 s W
train at 0.7–1.4 ft, killing the island-shadow explanation — in-model extinction is OUR
defect; (3) S (170°) vs SSW (195–200°) are 5–6 directional bins apart and must NEVER
merge — the 5° bins exist for this; (4) tide runs at eta_shore=0.000 during a
flood-advisory high tide (the L1-plan STOFS wlevel chain shipped with Gate S never run;
the coordinator also read past the 0.000 line during the accept); (5) orthophoto quality
still unacceptable at operator viewport (source-tile quality, not tile count); (6) heat
map painted dry-beach padding as surf (display fix written, committed LOCALLY at
dashboard `1d37593`, NOT pushed/deployed — parked on operator freeze). Two READ-ONLY
investigation agents dispatched (operator-ordered): WAVE-TRACE (hop-by-hop WW3→L1→L2→DWR→
partitioner energy/direction audit, SWAN manual as authority) and TIDE-TRACE (eta_shore
zero: defective step, start date, should-be value). Briefs + findings in session
scratchpad. NO code/config/deploy work until operator rules on findings.

### QC GATE B2 — `clearskies-auditor`, adversarial, BEFORE lead gate — ✅ PASS 2026-08-11 (code-level rows; does NOT close B2-Accept above)
Rows: (1) sampling-layer functions GONE (grep — any survivor = FAIL); (2) anti-fabrication KAT
falsifiable (mutation: reintroduce slot-averaging on a copy → KAT fails); (3) emitted INPUT
diff vs pre-phase: only the BOUNDSPEC block and file inventory differ; (4) pinned commands
byte-identical (CGRID/GEN3/INPGRID/etc.); (5) endpoint copies present at len 0/L on both
sides; (6) the ±(accept row 1) lobe checks re-derived from raw files by the auditor's own
parse, not the implementer's numbers; (7) doc-sync tags removed in PROVIDER-MANUAL
§14.3a/ARCHITECTURE for the shipped behavior; (8) targeted-test baseline recorded, zero new
failures.

---

## PHASE S — Swell-conditions card: ruled ranges *(PA2 — fixit Item 2)* — 🟡 S1/S2/S3 ✅ DONE 2026-08-11 (marine `9562d28`, dashboard `355a83e`), Gate S ✅ PASS (1 LOW doc finding, remediated lead-direct same day); ⏳ S-ACCEPT pending deploy (dashboard deploying; marine deploy bundled after T2 lands)

**GATE S RECORD (2026-08-11): PASS, all 5 rows,** auditor's own falsifiability runs (marine
9/9 new KATs fail on pre-change code; dashboard 2/34 period assertions fail pre-change,
face-height pre-existing-fallback explanation verified); no import cycle; zero live
retired-field references either repo or either openapi; dynamic heightUnit ruled correct
against API-MANUAL group_wave_height. F1 [LOW]: DASHBOARD-MANUAL C1 bullet stale +
Phase-S tag unlifted — REMEDIATED lead-direct (C1 bullet folded to shipped state).
Round notes: s-dash-dev disclosed 2 pre-ack in-scope edits (kept, logged); pre-existing
drift finding — retired fields were never present in the dashboard openapi mirror.

**Owner:** `clearskies-api-dev` (S1) + `clearskies-dashboard-dev` (S2). **Tests:**
`clearskies-test-author` (S3). **QC:** `clearskies-auditor` at Gate S. Dispatches after Gate
B2 closes (marine repo single-round).

### S1 — Server fields (marine `endpoints/surf.py`, `_compute_eligible_swell_aggregates`) — ✅ DONE 2026-08-11 (marine `9562d28`)
**Design (decided):** (a) ADD `periodMinS`/`periodMaxS` = min/max of `period` over the
ELIGIBLE set (existing eligibility rule — operator ruled the no-qualifier fallback stays
as-is), rounded 1 decimal; (b) REMOVE `combinedPeriodS` and `faceHeightMinFt`/`faceHeightMaxFt`
from computation and response (pre-task grep BOTH repos for consumers; dashboard's are
rebound in S2 — any OTHER consumer found = STOP and surface); (c) the `5.0` literal replaced
by an import of `_MIN_SURFABLE_PERIOD_S` from `services/surf_1d_pipeline` (shared constant;
verify no import cycle); (d) `swellHeightMinFt/MaxFt` and `modelSurfHeightMin/Max`
computations untouched.

### S2 — Card rebind (dashboard `SurfingTab.tsx` Card 3) — ✅ DONE 2026-08-11 (dashboard `355a83e`)
**Design (decided):** Breaking Face Height range ← `modelSurfHeightMin`/`modelSurfHeightMax`
(verify served units against API-MANUAL before binding — the fields serve feet today per the
live capture); Period ← `periodMinS`–`periodMaxS` via the existing `formatMinMaxFt`-style
collapse rule (single number iff min = max); delete the `combinedPeriodS` and
`faceHeightMinFt/MaxFt` bindings and the fields from `src/api/types.ts`/openapi mirror.
Swell Height binding unchanged.

### S3 — Tests — ✅ DONE 2026-08-11 (9 marine KATs in `9562d28`; 3 C1 tests rewritten in `355a83e`; falsifiability auditor-reproduced)
Marine: aggregate KATs updated in the same round — period-range arithmetic on a 3-train
fixture; fields-absent assertions for the two removals (response must NOT carry them).
Dashboard: `SurfingTab.test.tsx` C1 block updated to the new bindings (range renders, collapse
renders, null fallback) — same-commit-as-behavior rule.

### S-Accept (live) — ✅ SERVER EVIDENCE PASS 2026-08-11 (operator card-eyeball invited)
Served JSON (cycle 10:33Z, fetched 11:20Z): `periodMinS 10.2 / periodMaxS 13.4` as a real
range; `combinedPeriodS` + `faceHeightMinFt/MaxFt` absent from the ENTIRE response;
`modelSurfHeightMin/Max` present. Dashboard card rebind deployed (`355a83e`).
Served JSON at matched time shows `periodMinS/periodMaxS` and lacks the removed fields;
screenshot of the card showing Breaking Face Height as the `modelSurfHeight*` range (a real
range on a multi-transect day) and Period as a range when ≥2 surfable trains differ; cam/buoy
sanity note recorded.

### QC GATE S — auditor rows — ✅ PASS 2026-08-11 (record at phase header)
(1) repo-wide grep: zero surviving references to the removed fields (both repos + openapi);
(2) shared-constant import verified (no duplicated 5.0 literal in `surf.py`); (3) dashboard
tests fail against pre-change code (falsifiability spot-check); (4) doc-sync tags removed
(API-MANUAL/openapi/DASHBOARD-MANUAL); (5) targeted baselines, zero new failures.

---

## PHASE K — Break markers + crash-band impact zone *(PA3/PA4 — fixit Item 4)* — 🟡 K1–K4 ✅ DONE 2026-08-11 (marine `57ee18d`+`daa0b14`+`d75e507`+`9bbc292`); Gate K ⏳ IN PROGRESS; K-Accept pending deploy

**K2 COORDINATOR RULING (a), 2026-08-11:** the plan's literal "maximal contiguous runs where
Qb_i ≥ qb_breaking_onset" contradicted the plan's own examples (transect-55 two-break KAT +
"multi-bar ⇒ multiple markers" consequence) — on the real fixture, raw Qb dips to 0.0475 at
the bar crest, so single-threshold regions delete the bar marker. Ruled per CLAUDE.md's
same-plan-contradiction clause toward the examples: `qb_breaking_onset` gates region START
only; continuity uses the existing `Q_B_CESSATION` (0.02, value/march-role untouched) as the
stay-alive floor, mirroring the march's own onset/cessation asymmetry. Documented in
`_select_break_markers()` docstring; pinned by the K4 hysteresis-isolation KAT pair; Gate K
row 4's literal "no Q_B_CESSATION in publication path" amended accordingly (one sanctioned use).
Round notes: config-plumbing allowlist extension (pipeline call sites + beach_profile kwarg
threading — coordinator-ruled, enumerated); 1 pre-existing transect-55 reform failure + 4
pre-existing wind-sea F4/F5 failures disclosed and worktree-verified at `b4dfb40` baseline;
k-tests skipped scope-ack-wait (2nd occurrence this session, disclosed, retro-approved).

**Owner:** `clearskies-api-dev`. **Tests:** `clearskies-test-author`. **QC:** auditor at Gate
K. Dispatches after Gate S closes.

### K1 — Config keys + plumbing — ✅ DONE 2026-08-11 (`57ee18d`; SurfConfig + real wiring to both pipeline call sites + beach_profile)
**Files:** `config/marine_config.py`, `services/surf_1d_analytical.py` (constant read sites).
**Design (decided):** `[surf] qb_breaking_onset` (float, default 0.05, valid (0, 0.5)) and
`[surf] impact_zone_width_m` (float, default 25.0, valid (5, 200)); out-of-range → loud
config-push refusal naming the bound. Values flow to the 1-D layer the same way existing
`[surf]`-scope settings do (follow the file's own config-injection idiom; if none exists for
this module, module-level defaults overridden at pipeline construction — implementer follows
the repo's existing pattern, surfacing if none exists). OPERATIONS-MANUAL doc-sync tag removal.

### K2 — Marker detection decoupled from cessation — ✅ DONE 2026-08-11 (`57ee18d`+`daa0b14` ruling (a); zero march-loop lines touched)
**Files:** `services/surf_1d_analytical.py` — break-publication region ONLY (`onset_indices`
mechanics + `_find_break_points()`); the physics march variables (Q_b solve, one-sided
relaxation, roller reservoir) are OUT of scope.
**Design (decided, mechanical):** after the march completes, markers are derived from the
recorded per-step series (dissipation `D_i = max(y_prev − y_i, 0)` and `Qb_i`, both already
computed): (1) candidate regions = maximal contiguous index runs where `Qb_i ≥
qb_breaking_onset`; (2) within each region, find local maxima of `D_i`; (3) keep a maximum iff
its topographic prominence ≥ `_BREAK_PROMINENCE_FRACTION × max(D_i in region)` (the region's
tallest maximum always survives); (4) each kept maximum = one published marker, then the
existing `_MIN_BREAK_DEPTH_M`/`_MIN_BREAK_HS_M` filters apply unchanged. The
append-at-cessation logic no longer feeds publication (cessation stays as internal physics
state). Multi-bar profiles ⇒ multiple markers per region even when Q_b never dips — the
operator-accepted dependency.

### K3 — Zones: fixed crash bands — ✅ DONE 2026-08-11 (`57ee18d`+`d75e507`; reformTrough always null, wire-locked in beach_profile)
**Files:** `services/surf_1d_analytical.py` (`_classify_zones` + per-break variant),
`endpoints/beach_profile.py` (serving shape only — field names/nullability unchanged except
`reformTrough` now always null).
**Design (decided):** per marker at shore-distance `d_m`: `impactZone = [d_m,
max(d_m − impact_zone_width_m, waterlineDistance)]`; bands may overlap if markers are closer
than the width — served as computed (no merging logic). `foamZone` = [shoreward edge of the
most shoreward band, waterlineDistance] (pure geometry, no roller-energy term).
`totalSurfZone` = [outermost marker, waterlineDistance]. `reformTrough` = null. The
roller-energy zone scan (`_WHITEWATER_ER_FLOOR_FRACTION` and the next-break clamp) leaves the
published path entirely. Dashboard `types.ts` comment updated per PA5 (DOC.4 prescription).

### K4 — Tests — ✅ DONE 2026-08-11 (`9bbc292`; 16 KATs covering (a)-(g) + ruling-(a) hysteresis pair; lead re-ran 16/16)
KATs: (a) synthetic two-bar profile whose D-series has two prominent maxima with Q_b never
dipping below onset between them → TWO markers, TWO bands (fails against pre-K2 code —
falsifiability demo required); (b) prominence: a 25%-prominence ripple publishes NO marker;
(c) band arithmetic + waterline clip (marker near shore → band ends at waterline exactly);
(d) config knobs: raising onset removes the weaker marker; changing width moves band ends
(read through the real config path, not by patching constants); (e) foam/total zone geometry;
(f) `reformTrough` null; (g) out-of-range config → push refusal. Existing zone/marker tests
updated same-commit per the task specs; every touched test enumerated in scope-ack.

### K-Accept (live) — 🟡 SERVED-SHAPE EVIDENCE 2026-08-11 (cam eyeball + knob drill pending)
First post-K cycle (10:33Z) serves TWO break markers where one glued zone used to be:
outer ~121.5 m (depth 1.05 m) + inner beach break ~92.4 m (depth 0.39 m) — the fixit
Item-4 outcome (beach break carries a marker). Rows 1 (cam correspondence, operator
eyeball) and 3 (live knob drill, needs a cycle per change) remain open.
Deploy alone. (1) Beach-profile card at matched time: does the inner beach break now carry a
marker? RECORD against cam observation (pass/fail on "markers correspond to where waves
visibly crash" — pre-declared, operator invited to eyeball); (2) impact-zone bar(s) are
narrow bands at the crash locations, not a 240-m smear; no band crosses the waterline;
(3) knob drill: bump `qb_breaking_onset` on the live config, observe marker-set change,
restore (recorded); (4) journal sweep + baseline diff; (5) INV-11 firing rate recorded
before/after (informational — PA4 doesn't charter fixing it, but the number lands in the
record for the standing SURF-REMEDIATION item).

### QC GATE K — auditor rows — ✅ PASS 2026-08-11 after remediation (rows 1–4 clean under auditor's own drills: frozen-march diff zero loop-body lines, hysteresis mutation flips the KAT, real-config-path wiring verified, publication-path grep exactly one sanctioned Q_B_CESSATION use). Findings: **F1 HIGH** — undisclosed NEW failure `test_handoff_clamp_depth.py` (fixed-signature stub vs K1 kwargs; introduced `57ee18d`, auditor-traced) → REMEDIATED lead-direct (`**_kwargs` absorb, 8/8); **F2 MEDIUM** — dashboard `types.ts` PA5 comment update never attempted → REMEDIATED lead-direct (impactZone/foamZone/reformTrough JSDoc to K3 semantics, tsc clean). Doc-sync tags lifted at deploy (OPERATIONS-MANUAL, API-MANUAL ×3 incl. ruling-(a) hysteresis amendment, ADR-102). Informational: 2 additional pre-existing failures in `test_landward_boundary_amendment4.py` (auditor-verified at baseline, parking lot).
(1) physics-march diff audit: zero changes to Q_b solve/relaxation/roller code paths (the
frozen physics assertion — any touched line outside the publication/zone regions = FAIL);
(2) KAT (a) falsifiability reproduced by the auditor (mutation/revert); (3) config keys
validated + refusal drill evidence; (4) grep: no surviving publication-path reference to
`Q_B_CESSATION`/Er-floor; (5) doc-sync tags removed (ADR-102 note, API-MANUAL, types.ts
comment); (6) targeted baselines, zero new failures.

---

## PHASE H — Heat map + small display fixes *(fixit Items 5, 3, 4-display)* — 🟡 ALL TASKS ✅ SHIPPED+DEPLOYED (Gate H ✅ PASS); **H-ACCEPT ⛔ STRUCK 2026-08-11 → both remediations DEPLOYED 2026-08-11** (dry-beach clip `1d37593` on weather-dev; ortho NAIP raster 256→512px api `e729a97` on weewx — measured z17 requests were 1.0 m/px vs 0.6 m native, now 0.5 m/px) — re-accept awaits operator eyeball

**Owner:** `clearskies-dashboard-dev`. **Tests:** `clearskies-test-author` (H7).
**QC:** auditor at Gate H. Dispatches after Gate DOC; H0 BLOCKS H1–H4.

### H0 — Registration known-answer check FIRST (the C3S recorded next-session action) — ✅ GREEN 2026-08-10 (`8fdbf4c`; 40.9 m defect found+fixed → 0.00006 m; permanent KAT)
**⚠ H0 RESULT 2026-08-10: FAIL — registration defect CONFIRMED.** Pier-base anchor
projected through the data transform vs the imagery transform disagrees by **40.95 m
alongshore** (cross-shore exact to <0.001 m; tolerance 10 m). The C3S registration doubt is
now a measured finding: the defect isolates to the alongshore/tangent basis handling when
the north-up imagery mosaic is rotated into the chart frame — not scale (S), not pivot.
Lead ruling: repairing it is a defect fix against the documented C3S single-ground-frame
contract (display-only, no trigger) — fix ordered as part of H0 closure, KAT must go green
at ≤10 m; H1-frame (held on Q2 anyway) and H2 stay blocked until H0 is green; H3/H5/H6
(registration-independent) proceed.
**✅ H0 GREEN 2026-08-10 (dashboard `8fdbf4c`):** root cause = alongshore-handedness — one
north-up→chart rotation can only align both axes for one chirality of (offshore, tangent);
the other case (cross2D < 0, ~50% of real coastlines incl. this fixture convention) rendered
the alongshore axis mirrored. Fix: `alongshoreFlipNeeded()`/`foldAlongM()` applied at all
three alongM→Y sites (row bands, Y ticks, imagery pivot) — data+photo move as one unit;
rotation formula, S, served data untouched. Post-fix registration delta **0.00006 m**
(pre-fix 40.9 m; tolerance 10 m). HeatMapCard tests 52/52, SurfingTab 33/33, tsc clean.
3 stale ground-truth tests updated same-commit, each re-deriving handedness independently.
Viewer-visible change: a spot's alongshore top/bottom orientation now follows its real
geometry (may mirror vs pre-fix), matching the photo. H2 + H1-tile-budget now unblocked;
H1-frame still held on Q2.
**Files:** `HeatMapCard` test file (new KAT); read-only vs component code.
**Design (decided):** project ONE ground anchor (the pier-base transect origin served by the
profile endpoint — `originLat/originLon` of the pier transect) through (a) the data-layer
ground→chart transform and (b) the imagery-tile ground→pixel math; assert agreement
≤ 10 m ground-equivalent. Failure = STOP the phase and surface (the C3S registration doubt
becomes a finding, not a rework guess). This KAT stays in the suite permanently.

### H1 — Framing + tile budget — ✅ RESOLVED 2026-08-11: tile budget SHIPPED; frame term CANCELLED (operator: the whole-pier framing was never asked for — Q2 record above; only correct ortho scale/placement matters, which H0 gates)
**Files:** `HeatMapCard.tsx` (framing constants + `IMAGERY_MOSAIC_MAX_TILES_PER_SIDE`).
**Design (decided):** cross-shore frame seaward edge = max(data extent, pier seaward tip's
cross-shore position) + the existing 50 m buffer (frame includes the whole pier for context);
tile budget 4 → 8. Single-ground-scale rule PRESERVED (one S, both axes — DASHBOARD-MANUAL
C3S rule untouched). Accept numbers: background ≤ 1.5 m/px at default card size; row strips
at or below their pre-C3S on-screen height; H0 KAT green.

### H2 — Radar-style smoothing (display-only) — ✅ DONE 2026-08-11 (`53ebd38`, SVG bilinear subdivision)
**Files:** `HeatMapCard.tsx`.
**Design (decided):** the per-cell surf-height color field renders through bilinear
interpolation between adjacent transect row bands and along each transect (offscreen-canvas
upsample of the value grid, then colormap) — cells with no data stay unpainted (no invented
surf beyond the data extent); the served data and the transform are untouched.

### H3 — Nothing below the legends — ✅ DONE 2026-08-11 (`382ab4f`)
**Files:** `HeatMapCard.tsx` + info-modal content/help keys.
**Design (decided — operator's words "do not need anything below the legends" govern):** BOTH
lines below the legends are removed from the card face: the imagery attribution AND the D7s
smoothing note. Both texts move into the card's info-icon modal; the attribution string stays
rendered VERBATIM from `imageryConfig.attribution` there (keeps the ESRI ToS case compliant —
PROVIDER-MANUAL §16.2). Help-key doc-sync per CLAUDE.md.

### H4 — Card 4x2 + fullscreen overlay (RULED) — ✅ DONE 2026-08-11 (`382ab4f`)
**Files:** `SurfingTab.tsx` (card wrapper), `HeatMapCard.tsx`.
**Design (decided):** `footprint="full"` + `rowSpan={2}`; chart area scrolls vertically inside
the card (`overflow-y: auto`) when the true-scale height exceeds the card; header gains
`ChartFullscreenButton` opening the existing `ChartFullscreenOverlay` (operator-ruled: overlay
is fine). DESIGN-MANUAL marine-card table row (DOC.4) tag removed on ship.

### H5 — Surf score footer deletion (fixit Item 3) — ✅ DONE 2026-08-11 (`382ab4f`)
**Files:** `SurfingTab.tsx` (:2105-2109 region — verify, don't trust line numbers).
Delete the footer explainer `<p>` block; i18n key + modal untouched.

### H6 — Beach-profile display smalls (fixit Item 4.6) — ✅ DONE 2026-08-11 (`382ab4f`; flat-segment report filed below)
**Files:** `BeachProfileChart.tsx`.
**Design (decided):** bottom elevation tick label suppressed when its y lands within 12 SVG
units of the x-axis label row (kills the "-10492" collision at any render width); plus a
read-only look at the flat 0.03 m landward transect segment — REPORT ONLY (a serving-side
fix, if needed, is a finding for the operator, not an H6 change).

### H7 — Tests — ✅ DONE 2026-08-11 (95/95 + 2 disclosed pre-existing; H-ACCEPT-STRUCK KATs added with `1d37593`)
H0 KAT (permanent); framing/zoom unit tests (given a fixture extent, chosen zoom yields
≤ 1.5 m/px); smoothing: no-data cells stay transparent (canvas sample assert); H3: no text
node renders below the legend row; H4: overlay opens/closes, focus trap (reuse existing
pattern's tests as template); H5/H6 render asserts. Baseline: full dashboard vitest +
`tsc -b` + build; bundle sizes recorded per reference/clearskies-dev.md.

### H-Accept (live, weather-dev deploy) — ⛔ STRUCK 2026-08-11 → remediations deployed same day (dry-beach + ortho raster); ⏳ RE-ACCEPT PENDING operator eyeball
Screenshots at default card size + fullscreen overlay + a phone-width viewport: cells vs
pre-C3S size, photo legibility (operator eyeball invited — this card's accepts have been
operator-struck twice), nothing below legends, chevron works, surf forecast card position
restored above the fold. H0/H1 numeric records in the round log.

**GATE H RECORD (2026-08-11): PASS** — commits `8fdbf4c`/`382ab4f`/`53ebd38`, all rows MET
by independent auditor verification (H0 mutation drill: dropping the handedness fold fails
the KAT at 17.8 m; auditor's own falsifiable no-data probe; single-S grep; overlay
confirmed the shared component, not a fork; 95/95 + 2 disclosed pre-existing failures
exact; tsc clean). Bundle: entry 203.01 KB gz (neutral), marine chunk 44.49 KB gz (was
41.73 — +2.76 for modal/fullscreen/smoothing). H2 shipped as bounded SVG-rect bilinear
subdivision (16x2/row) instead of a literal canvas raster — lead-accepted methodology
substitution (jsdom testability; bounded cost). Findings: F1 MEDIUM missing H6 report —
REMEDIATED below; F2 LOW — the plan's "no-data cells stay unpainted" is CONDITIONAL in
code: a pre-existing break-point-proximity extrapolation still paints a modeled value when
a no-data cell's row carries breakPoints (predates this round; H2 did remove the worse
hs=0 fabrication); text corrected at tag-lift, fallback surfaced to operator at H-Accept.
F3 INFO — fullscreen overlay keeps a second card instance always-mounted (existing
pattern); performance note parked.

**H6 FLAT-SEGMENT REPORT (F1 remediation; read-only finding, NO fix made):** the flat
~0.03 m landward segment on the beach-profile chart has two candidate mechanisms, not
distinguishable from code alone: (a) the CUDEM survey's own native near-shore resolution
genuinely flattening the profile (a real bathymetry characteristic); or (b) — only when
the served `beachElevation` field is absent and the chart falls back to `tide −
depth` — the existing 0.01 m solver-depth clamp producing an artificially flat swash
segment when consecutive points sit at the floor (real fixture data in the repo shows 3
consecutive 0.01 m points). Distinguishing requires a live-serving check; any fix would be
serving-side and is the operator's call, not chartered by this plan.

**H-ACCEPT EVIDENCE (2026-08-11, deployed to weather-dev at `53ebd38`): OPERATOR EYEBALL
PENDING.** Screenshots in session scratchpad (h-desktop.png / h-fullscreen.png /
h-phone.png), captured via Playwright through local Caddy. Observed: aerial photo now SHARP
(individual cars/pier structure resolvable — the blocky-photo complaint is gone); the
WHOLE pier visible in the fullscreen frame; color field smoothly blended alongshore (H2);
nothing below the legends; fullscreen overlay opens/closes ("View chart fullscreen"
button); surf-score footer gone; phone width stacks cleanly. **One item flagged for the
operator eyeball:** a solid uniform BLUE block of shoreward cells appears to overlay dry
sand and part of the back-beach/parking area on the photo's shore side. Candidate benign
explanation: the 1-D model's landward boundary is HAT (up the beach face), so low-height
shoreward cells can legitimately extend past the photo's capture-time waterline; candidate
defect: shoreward cell extent misrendered. The H0 KAT pins pier-anchor registration to
0.00006 m, so gross misregistration is excluded — but cell EXTENT vs the real waterline is
exactly the kind of call the operator's eye settles. Formal ≤1.5 m/px measurement rides
with the held H1-frame term (Q2).
(1) H0 KAT present, passing, and falsifiable (mutation: perturb the imagery transform → KAT
fails); (2) single-ground-scale rule intact (DASHBOARD-MANUAL C3S rule vs code — two-ruler
regression grep); (3) smoothing never paints no-data cells (auditor's own canvas probe);
(4) attribution string byte-identical in the modal; (5) doc-sync (DESIGN-MANUAL row,
DASHBOARD-MANUAL heatmap section, help keys) landed, tags removed; (6) vitest/tsc/build
baselines, zero new failures; (7) H6 report filed (flat-segment finding surfaced, not fixed).

---

## PHASE M — Main map layer reliability *(fixit Item 6)* — ✅ CLOSED 2026-08-10

**Gate record:** dashboard `eb424fd` (M1+M2+M3) + `73d9017` (Gate M finding F1: clear
pending retry timer — lead-direct). Gate M adversarial audit: PASS, 1 LOW finding
(remediated), mutation drill proved test falsifiability (threshold mutation → 3/6 fail;
handler-removal mutation → 2/6 fail). Verification (lead-independent, weather-dev):
LocationMap vitest 6/6 + `tsc -b` clean at `73d9017`. Deployed via full
redeploy-weather-dev (entry chunk 203.01 KB gz — neutral vs 203.00 baseline). Repro
capture (Playwright on weather-dev, via local Caddy HTTP — public HTTPS terminates at an
upstream openresty proxy that 403s container-origin requests): marine page 1 leaflet
container, 36/36 tiles HTTP 200 (base openstreetmap + labels cartocdn), forced dark-theme
pass 36/36 fresh tile loads, banner correctly absent, zero silent-gray. Caveat recorded:
the theme flip was exercised via reload (unit tests pin the in-place remount); the wild
intermittent was not reproducible post-fix — both candidate mechanisms are closed by
construction. DASHBOARD-MANUAL tag lifted to LIVE (this commit). Parking lot: 2
pre-existing dashboard vitest failures found by the gate (useRealtimeObservation UV key;
grid gap-token) — unrelated to M, tracked in P2 below; dashboard "92/92" baseline is stale.

**Owner:** `clearskies-dashboard-dev`. **Tests:** `clearskies-test-author`. **QC:** auditor at
Gate M. May run parallel to Phase H (different files).

### M1 — Tile-error handling
**Files:** `LocationMap.tsx`.
**Design (decided):** both `TileLayer`s get `tileerror`/`tileload` handlers via
`eventHandlers`; per §Named constants: 3 consecutive errors → non-blocking banner over the map
("Map imagery failed to load — retrying"), retry via layer redraw with 5 s backoff, max 3
retries per mount, banner clears on success. Silent gray becomes impossible: either tiles or
a banner.

### M2 — Atomic theme remount
**Files:** `LocationMap.tsx`.
**Design (decided):** the per-layer `key={baseTile.url}` moves UP: `MapContainer` itself keyed
on `resolvedTheme` (whole map remounts atomically on a theme flip; labels can never outlive
the base layer). No change to theme-provider logic.

### M3 — Tests + repro capture
Vitest: banner appears after 3 simulated tileerror events; clears on tileload; MapContainer
key changes with theme. Accept: one browser session (devtools network log) through
full→detail navigation and a forced theme flip, recorded in the round log — confirming which
failure mode the wild intermittent was, and that neither reproduces silent gray post-fix.

### QC GATE M — auditor rows — ✅ PASS 2026-08-10 (record above)
(1) no remaining unkeyed/mixed-key layer state (code walk); (2) banner tests falsifiable;
(3) repro capture artifact present; (4) DASHBOARD-MANUAL map contract tag removed;
(5) baselines, zero new failures.

---

## PHASE Z — Forecast-hole diagnosis + staleness ruling *(fixit Item 0; PA6: NOT pre-approved)*

### Z1 — Diagnose the mid-window hole — ✅ DONE 2026-08-10 (read-only; ruling brief delivered)
Mechanism confirmed from the 18:00Z run's journal + code: the HRRR wind fetcher treats "file
not posted yet" (404) the same as "reached the end" — it stops early and reports success with
however many hours it got (23 of 49 that run), and nothing downstream checks the count. The
HRRR/GFS stitcher then blends the short set, leaving hours 23–48 empty with no warning, and
the run publishes normally. The existing loud-refusal guard covers total GFS failure but
never checks HRRR completeness — that is the gap. A fully-built poll-until-complete retry
module (`wind_gatherer.py`) already exists in the repo but is deliberately dormant (no effect
on the live path). Full brief with journal/code citations: session scratchpad
`Z1-RULING-BRIEF.md`; operator ruling row in OPEN OPERATOR QUESTIONS below.
**Owner:** `clearskies-api-dev` in READ-ONLY mode (or lead-direct).
Establish from journal + code: why the 19:24Z run published a forecast missing the hours whose
HRRR extended files 404'd (f34–f48 posting lag), instead of waiting/backfilling/refusing.
Deliverable: a ruling brief — the mechanism, and costed options (bounded wait-and-retry for
the extended set; publish-then-backfill on the next fill cycle; GFS gap-fill — flagged
ARCHITECTURAL, moves the blend boundary; status quo + visible gap). NO code.

### Z2 — Operator ruling row: data-age on cards — ✅ RULED NO (operator 2026-08-10 at GO: "Z2, no")
No data-age badge, no staleness refusal on cards. CLOSED, no implementation. Z1's brief no
longer needs to carry data-age options.

### Z3 — RE-SCOPED 2026-08-10 (wind-gatherer migration steps 2–5, operator-approved 2026-08-03) — 🟡 STEP 2 ✅ CLOSED 2026-08-11 (`9e43e7a`+`9aba413`, gate PASS after F1 end-to-end-KAT remediation, DEPLOYED `0d46a82` 11:18Z, reality gate PASS: store-sourced wind classification served, zero request-path fetches, no fallback warning; gatherer live, 7 MB timeline actively topping up); **STEP 3 ✅ GATED+DEPLOYED 2026-08-11** (`7aab009`+meta `db4748a3`; two design gaps stopped-and-ruled pre-code: (i) GFS far-window — interpolation STAYS in `_stitch_wind`, only raw-hour source moves to the store via new regime-aware `get_wind_records()` (72 h window intact — the window-shrink and store-relocation readings were both declined as unauthorized triggers); (ii) forced-run immediacy — service loop keeps its 300s signal check invoking the SAME `run_full_swan_cycle_from_store()`, pending-signal handoff so the gatherer's asyncio thread never runs SWAN. Gate: 0 findings, all 4 adversarial drills flipped real KAT failures, double-fire wrinkle traced bounded, `_stitch_wind`/`run_quick_update` provably byte-unchanged. Deployed 11:57Z; reality gate armed — next extended-cycle assembly must fire a store-driven full run consuming 49/49). **STEP 4 ✅ GATED+DEPLOYED 2026-08-11** (`8897c9c`+`ceda60c`+meta `1337f372`, deployed ~12:4xZ): hourly fast cycle gets its REAL `hourly_cycle_assembled` trigger (finding-13's unreachable path made live), 12 h scope (operator "half a day", ONE enforcement site at the runner trim), store-read with cycle-time anchoring, no forced-bypass analog (Q3). Gate: 4/5 rows clean under mutation drills; F1 MEDIUM (cross-fire seam had no negative KAT — code correct, suite blind) remediated lead-direct with a falsifiability-proven KAT (`ceda60c`). Round notes: Z3.3's "zero new failures" claim was FALSE — `test_c8_forced_run_no_op` regression introduced at `7aab009`, missed by grep AND the `-k` sweep, caught by lead cross-check during Z3.4 close; remediated at the new seam (`aec462c`) per false-claim protocol. Reality gates armed: first store-driven full run (next extended assembly) + FIRST-EVER production fast cycle (next hourly assembly). **Step 5 (deletions + doc batch — final code round) dispatching.**

**Z3.5 STATUS (2026-08-11 ~21:15Z session, lead-verified from journal + git + live host — every number below re-derived this session):**
- **Work product exists, UNCOMMITTED, hold gate intact.** The step-5 agent's deletion round
  sits in the marine working tree on top of `0ebdd01` (21 files, −1467/+510: service.py
  legacy-branch deletions, surf.py fallback deletion, swan.py `wind_for_display` build
  removal, test dispositions). Backups: marine stash@{0} "Z3.5 + reality-gate-fixes,
  pre-split" + scratchpad `z35-plus-fixes-full.patch` (prior session). Meta repo carries the
  uncommitted step-5 doc batch (ADR-107 draft + PROVIDER-MANUAL/ARCHITECTURE/INDEX edits).
  Per the brief's HOLD GATE, nothing commits until BOTH production reality gates pass — and
  gate B's aftermath now BLOCKS part of the deletion inventory (Q3 below).
- **Reality-gate day record (pre-fix failures, all on old code, process 386440):** full runs
  13:51Z (12Z cycle) and 19:47Z (18Z cycle) refused — window `now..now+72h` instead of
  `cycle..cycle+72h` hit hours the store cannot hold (e.g. "no timeline entry for
  2026-08-13T13:00"); fast cycles 12:31/13:21/14:32/15:28/16:34/17:30/18:42/19:17Z refused —
  window start at an already-aged-out hour. Fixes `c812d94`+`0ebdd01` pushed + deployed,
  restart 20:30:26Z. All refusals were loud no-publishes; last-good cache never overwritten.
- **Reality gate B (first-ever production fast cycle): PASS 2026-08-11 20:56:00Z.** Evidence
  (journal, process 484919, running `0ebdd01`): 20:30:31 `hourly_cycle_assembled cycle=19Z`
  from the gatherer → 20:36:24 "hourly_cycle_assembled trigger firing fast SWAN cycle" →
  stationary full-nest fill, STOFS-2D-Global WLEVEL "73 hourly grid(s), sole source" (T design
  live in the fast path) → 20:56:00 "SWAN quick update complete in 1175s — 1 spot(s)" +
  "Marine runner: fast SWAN cycle complete (store-driven)" + forecast cache persisted 18.6 MB.
  Post-restart journal sweep: zero new ERROR/WARNING classes (INV-11, DDD-runaway, L4-handoff
  clamp, roller-closure all pre-existing tracked).
- **Reality gate A (first store-driven full run): ❌ FAILED 2026-08-12 01:50:43Z — STRUCTURAL,
  fix round dispatching.** The 00Z extended cycle assembled 01:50:15Z, full run fired
  01:50:43Z on `1ff5124` and refused: `gap:missing_hour: no timeline entry for
  2026-08-12T00:00:00Z (requested 00:00..08-15T00:00)`. Root cause (both ends): (near) the
  cycle-anchored window's first ~2 hours are ALWAYS aged out by assembly time — `age_out()`
  drops everything before wall-clock now, destroying part of the assembled set the trigger
  exists to consume (contradicts the 2026-08-03 design's own "ONE fully assembled wind set"
  promise); (far) the 3-hourly window to cycle+72h can exceed posted GFS coverage at trigger
  time (the matching GFS cycle posts hours later). The refusal also CONSUMED the pending
  trigger (no retry ticks in journal) — so the store-driven full run has structurally never
  been runnable. Same built-wrong defect class as Q3. Old inline path evidently forced from
  cycle start successfully at ~cycle+2.5h (e.g. 08-11 00Z ran 02:42Z) — read-only
  investigation (z36-trace) dispatched to pin its exact window semantics before the fix is
  designed. NOT a publish outage: fast cycles keep passing hourly (19Z/20Z/21Z-era, 01Z
  02:41:36Z, 02Z 03:36:57Z all store-driven complete), display hybrid serving; cost = the
  12–72h forecast tail still dates from the 08-11 06Z full run and ages until fixed.

**Z3.6 ROUND (gate-A fix) — operator-ruled 2026-08-12 in chat ("why the fuck are you not
asking for more information from that model and saving it so we just use the existing GFS
that we have when we need to run the model instead of waiting"), dispatched ~04:3xZ.**
Fact-finding (z36-trace2, full brief in session record) pinned three independent defects,
each with file:line + journal evidence: (1) `age_out()` deleted the 00Z cycle's own start
hour at 01:03:30Z — 47 min BEFORE assembly completed — because retention has no floor below
wall-clock now while the run window is cycle-anchored; (2) GFS fetch depth f048–f072 is
anchored to GFS's OWN cycle, which structurally lags the HRRR extended cycle ≥6h, so the
run's far edge (cycle+72h) is unreachable at ANY assembly timing (masked in the journal —
the near-end error raises first); (3) the pending trigger is consumed unconditionally
before the run executes; refusal = swallowed, unlike the geometry-forced path's proven
level-triggered retry. **Design (BRIEF-Z36-DEV.md): D1** age_out floor =
min(now, `_incoming["hrrr_extended"].cycle_time`) — in-module state, bounded ≈8h extra
retention; **D2** gatherer-local GFS depth f048→f084 (13 files; `gfs.py` defaults + inline
path untouched — pinned by KAT); **D3** pending signal cleared only on success,
newer-cycle-overwrite-safe, superseded-without-running logs one INFO; **D4** window anchor
(cycle start = dedup key = SWAN t_start = served first timestep) UNCHANGED — historical
semantics preserved. All KATs falsifiability-proven vs HEAD `1ff5124`. Pipeline: implement
→ lead acceptance → adversarial gate → deploy (same operator authorization pattern as
Z3.5b); gate A retries on the next extended assembly post-deploy.

**Z3.6 GATE + SHIP RECORD (2026-08-12): ✅ GATE PASS 8/8 rows (adversarial; every mutation
drill flipped its KATs, scratch copies hash-restored). Findings: F1 [MEDIUM] pending-signal
wedge on an already-completed cycle (real TOCTOU between the gatherer's status write and the
callback, combined with the forced-geometry path) → REMEDIATED (marker check before
dispatch, CAS-clear without dispatching; KATs falsifiability-proven); F2 [LOW] stale
"DORMANT" store docstring → fixed. Lead acceptance: independent runs reproduced implementer
numbers exactly at every step (100 passed / 2 disclosed pre-existing; adjacent net 28/28).
Committed marine `acdfa0c`, pushed, DEPLOYED 04:58:16Z.**

**⚠ DEPLOY OUTAGE + HOTFIX (2026-08-12 04:58–05:04Z, 6 minutes, surf page empty):** the
04:58 restart refused the on-disk forecast cache as ">12h stale (saved 08-11T11:16Z)" and
came up cold; every marine endpoint served no-model-data and the public surf endpoint served
`forecast: []`. Root cause (new latent defect, exposed because this was the first restart
>12h after the last successful FULL run): `_update_forecast_cache_on_disk()` (the fast-cycle
merge persist) deliberately carried the PREVIOUS `saved_at` forward, so 11 fresh fast-cycle
persists all bore the last full run's stamp — the loader refused a file whose newest content
was 12 minutes old. The fast cycle also cannot bootstrap an empty cache (skips spots with no
existing entry), so no self-heal before the next successful full run (~5.5h). Recovery:
hotfix marine `ed1f26d` (merge persist stamps `saved_at=now`; KAT falsifiability-proven —
fails with the carried-over stamp) + one-time in-place repair of the live file's false stamp
to its true content time (04:52:03Z, the file's own mtime; in-place rewrite, ownership
untouched) + deploy 05:04:30Z → "restored forecast cache from disk (saved 04:52)"; public
endpoint verified serving 67 timesteps again, lastRunTime 04:41Z. Lesson queued: restart
recovery had never been exercised across a >12h full-run gap; the staleness stamp semantics
were only ever tested same-day. Doc-sync: PROVIDER-MANUAL GFS-depth passage, ARCHITECTURE
gatherer bullet, ADR-107 "Amendment (Z3.6 runnability fixes, 2026-08-12)" (all this commit).
**Gate A retry pending: 06Z extended assembly ~07:50Z — far edge needs GFS 06Z (~10:32Z)
because the 00Z GFS batch was fetched pre-deploy at the old 9-file depth; D3 retry carries
the trigger until it succeeds. First fully-on-time run expected at 12Z (~13:50Z). Monitor
armed.**

**GATE A SECOND FAILURE (2026-08-12, live): ❌ STRUCTURAL — far-window stitch shape
mismatch. STOP-AND-SURFACED to operator (architectural triggers 4/7); awaiting ruling.**
Timeline: D2/D3 verifiably WORKED — the GFS 06Z batch assembled ~10:30Z at the new 13-file
depth, the store window filled, the refusal cleared, and the trigger fired the run. The run
then CRASHED at the wind-stitch step (`swan_runner.py:2894`, `IndexError`), and has crash-
looped on D3 retry every ~5–10 min since 10:49Z (06Z cycle, then 12Z cycle identically;
`no-publish: swan_fatal`, last-good cache preserved every time — site keeps serving
fast-cycle-refreshed content, but the 72h tail is aging and each retry re-downloads WW3
boundary + STOFS + tide from NOAA). Root cause (code- and live-data-verified): the store
keeps ONE record per hour, "fresher cycle wins, equal cycle keeps first writer"
(`record_hour()`); HRRR-extended and the GFS batch for the same forecast cycle carry the
SAME `cycle_time` label and HRRR assembles first, so the boundary hour (cycle+48h) is ALWAYS
HRRR-sourced (65×60 grid) and GFS's own f048 copy is ALWAYS discarded. `_stitch_wind()`
interpolates the far-window pair (48h→51h) elementwise using the first grid's dimensions —
HRRR-shaped anchor (65×60) vs GFS-shaped neighbor (6×7) → IndexError, every cycle, forever.
The `get_wind_records()` docstring explicitly promises "HRRR's last grid at hour 48 AND
GFS's own f048 both present" — the store cannot honor that promise by construction; the old
inline-fetch path had both because each provider returned its own file. Verified live:
timeline hours ≤ cycle+48 all `src=hrrr nj=65 ni=60`, hours > cycle+48 all `src=gfs nj=6
ni=7` (wind_timeline.json, 19:00Z). Fix options surfaced: (1) RECOMMENDED — store keeps the
GFS-native record alongside HRRR for overlap hours; far-window reads prefer GFS-native
(reproduces the legacy stitch inputs exactly; store schema + persisted-file change,
triggers 4/7); (2) regrid HRRR hour-48 onto the GFS grid at read time (no schema change but
changes the numbers feeding the 49–50h interpolation — formula-adjacent); (3) flip merge
precedence so GFS wins ≥48h — REJECTED, poisons the near-window's hour-48 with a GFS-shaped
grid (same crash, other side).

**OPERATOR RULING (2026-08-12 in chat): OPTION 2** — "we go with option 2." At store-read
time, in the run adapter only, any far-window grid whose geometry differs from the GFS target
geometry is resampled onto the GFS grid via the existing canonical sampler
(`swan_formats._bilinear_interp()`, the same routine that projects wind onto SWAN grids), with
nearest-edge clamping for the GFS box's ≤0.061° overhang past the HRRR box (exceeds the
sampler's built-in one-cell tolerance — measured live). h49–50 interpolation now anchors on
HRRR's own hour-48 state instead of legacy GFS f048 — deliberate, approved (smoother handoff;
the model is HRRR-forced through hour 48). Store schema, gatherer merge, `_stitch_wind()`
unchanged. **Z3.7 ROUND DISPATCHED** (~19:45Z): z37-dev (clearskies-api-dev) on brief
`BRIEF-Z37-DEV.md` (scratchpad); pre-round baseline `z37-preround-hashes.txt` captured BEFORE
dispatch (Z3.5b F2 lesson applied); marine HEAD `ed1f26d` clean. Scope: swan.py adapter helper
+ far-window construction, wind_timeline_store.py docstring-only, test_z3_full_run_from_store.py
(4 new KATs incl. falsifiable repro + 1 named production-shaped seed fix), PROVIDER-MANUAL
passage. New refusal reasons: `far_window_no_gfs_records`, `far_window_resample_failed`.
ADR-107 "Amendment (Z3.7 …)" appended (coordinator).

**Z3.7 GATE + SHIP RECORD (2026-08-12 ~20:50Z): ✅ GATE PASS 9/9 rows, 0 findings.**
Dev z37-dev delivered marine `6d0c5ff` (3 files: swan.py helper+construction, store docstring-only,
tests +394 lines incl. 4 new KATs) + meta `22bd8ee6` (PROVIDER-MANUAL passage). Lead acceptance:
independent pytest `28 passed in 0.29s` (3 test files); commit stat = allowlist exact; 4 frozen
files hash-verified untouched; store diff byte-verified docstring-only; clamp/lon-frame/refusal-
ordering spot-checked in code. Falsifiability: with the fix stashed, the repro-KAT fails with
`IndexError` at `swan_runner.py:2894` — the exact live defect line. Adversarial gate (z37-gate,
firewalled from dev report): own affine-field repro with closed-form hand checks at interior AND
clamped-edge points (exact match); drill A (fix reverted → 4 tests fail incl. the exact
IndexError); drill B (clamp neutered → 2 tests fail; proves clamp is load-bearing vs the sampler's
one-cell tolerance); drill C (lat/lon transposed → dev tests AND auditor's own script flip — not
right-by-accident); refusal drivers (both new reasons return False before any cache write,
`record_input(wind, True)` unreachable from either); pass-through purity (all-GFS list byte-equal,
0 resample logs); frame consistency (returned metadata stays 0–360, normalization never leaks);
tree restored byte-identical (lead re-verified sha256 post-audit). Auditor named its blind spots:
no real-SWAN execution locally, no real-grid float noise, no concurrency case.
Dev-found bonus defect in the old h49 test: its seed relied on `record_hour()`'s freshness gate
silently DISCARDING the boundary-hour write (same cycle_time), leaving the seed accidentally
homogeneous — the exact non-production-shaped gate blindness that shipped the bug; now seeds
mixed geometry through the production path. **Restart fact (code+production-verified): the pending
trigger does NOT survive a restart (in-memory, no cold-start reconcile, no startup re-emit) — the
deploy drops the crash-looping 18Z trigger; first store-driven full run on Z3.7 code fires at the
00Z extended assembly ~01:48Z. Deployed ~20:55Z under the round-pipeline authorization; live
gate-A verdict + reality gate + B2-Accept re-check at ~01:50Z.**

**GATE A THIRD FAILURE (2026-08-13 02:27Z, live): ❌ STOFS water-level depth — same disease as
D2, next organ. → OPERATOR ORDERED FULL ADVERSARIAL AUDIT (Z3.8) instead of another iterative
fix.** The 00Z trigger fired on time (~02:22Z); the Z3.7 wind fix WORKED (run passed the stitch,
setup, and into `_write_input_files`); it then crashed at `STOFSGridCoverageError`: no STOFS
water-level match within 2h of wind timestep C+69h (2026-08-15T21:00Z). Arithmetic: STOFS 00Z not
yet posted at 02:23Z (observed 404) → fallback to 18Z cycle; we fetch `forecast_hours=72` from
STOFS's OWN cycle (swan.py:3657, :5098) → coverage ends C+66h < C+72h. STOFS publishes to f180
(manual §14.13a; f084 probed 200 live), so depth is the whole problem. Same trap found waiting
next: WW3 boundary `_OCEAN_FORECAST_HOURS = 72` (ww3_partition_fields.py:319; gfswave f084
probed 200). Crash loop retries every ~10 min, cache preserved, site serving. Coordinator's
monitor missed the new class overnight (filter listed old signatures + success only) — logged as
lesson 7. Proposed STOFS/WW3 72→84 held per operator order; folded into the audit round.
**Z3.8 AUDIT DISPATCHED (~03:40Z), three adversarial auditors in parallel, read-only:**
z38-audit-coverage (every external input: anchor/depth/fallback/worst-case posting-clock
arithmetic/loud-vs-silent, full-run + fast-cycle paths), z38-audit-swan (every generated SWAN
command + input file vs the LOCAL SWAN manual — top question: where does SWAN accept deficient
input silently), z38-audit-state (every mutable state item: restart survival, races, staleness
honesty, wedge states — the saved_at/pending-trigger class). Briefs:
BRIEF-Z38-AUDIT-{COVERAGE,SWAN,STATE}.md (scratchpad). Deliverable: one consolidated defect list
→ ONE operator ruling → ONE fix round → ONE deploy.

**✅ GATE A PASSED LIVE (2026-08-13 06:21:39Z) — first successful store-driven full run in the
project's history.** Z3.9 (marine `8cac6d1`→`338b899`, gate 12/12 + F1/F2 remediation KATs,
deployed 05:20:29Z): the new cold-start reconcile armed the restart-dropped 00Z cycle at the
first post-warmup tick (05:25:31Z — after a lead-direct fix for a startup race found in live
verification: the one-shot reconcile ran 0.4s before the gatherer's store load; now retries per
tick, falsifiable test), fired immediately, and completed in 3064s. Every input reached the
window: STOFS coverage-derived depth, WW3 boundary + coverage check, currents (WCOFS 03Z aligned
— zero tail held this run, note null as designed). REALITY GATE (tolerances picked before
looking — dominant train Hs ±0.3m / Tp ±2s / dir ±30° vs NDBC 46253 @05:56Z): served tail
Aug 16 00:00Z exact ✓; health all-inputs-available + fullRun success block + overdue false ✓;
tide −0.196m nonzero ✓; period 16.6s vs 16.7s ✓ (Δ0.1s); height 0.23m vs 0.5m ✓ (Δ0.27m, at
edge); direction 203° vs 166° ✗ MARGINAL (Δ37°, 7° outside tolerance — buoy is San Pedro South,
not the spot; recorded honestly, not waved through). **B2-Accept: served multiSwell now resolves
FOUR trains** (0.59m/4.1s/268° wind chop; 0.29m/12.8s/201° + 0.29m/11.8s/183° S-SSW; 0.23m/
16.6s/203° groundswell matching the buoy's dominant 16.7s SSE swell) — vs the single train that
opened this plan. Lessons routed (`c7041006`).
Next watch: 06Z cycle ~07:50Z exercises the normal event path + currents tail-hold on an
unaligned WCOFS cycle.

**❌ B2-ACCEPT FAILED (operator eyeball, 2026-08-13 ~06:35Z): multi-train structure present but
energy distribution WRONG.** Operator evidence (screenshots: our card vs Surfline vs 5 buoys vs
surf-forecast): our dominant = W 2.0ft @ 4.1s (268°) — physically implausible in light observed
wind ("not realistic for this area without a storm"); real dominant everywhere = S/SSE 13s
~1.6–1.7ft; our S trains 30–50% low (SSW 1.3ft@12.2s + 0.7ft@16.7s vs buoy 46253 spectral
0.5m@16.7s); card headline direction 268° and 0° closeout driven by the fake dominant. Operator:
"prior to all of these changes when we picked up from ww3 in the channel, at least we got the
right basic swell information."
**OPERATOR RULINGS (2026-08-13 in chat):** (R1) a train with period < 5s must NEVER be flagged
DOMINANT — it may exist and be listed, but is dominant-ineligible (clarified: not a display
filter, an eligibility floor on dominant selection). (R2) investigate WIND DOUBLE-COUNTING —
across the nested grids, and (coordinator's added suspect) a parametric wind-sea added on top of
SWAN output in the 1-D pipeline. **Z3.10 INVESTIGATION DISPATCHED (~06:45Z, both read-only):**
z310-wind (dominant-selection path + ≥5s floor placement + every dominant consumer; nest wind
double-count vs LOCAL manual; WIND.txt-vs-observed-station bias at matched hours — the Addendum-5
raw-HRRR audit finally running) and z310-boundary (stage-by-stage S-energy number table: WW3
source → station selection → boundary reconstruction → nest handoffs incl. §2.6.3 directional
resolution → spot output → served trains; cycle-staleness vs structural dilution split). Briefs:
BRIEF-Z310-{WIND,BOUNDARY}-INVESTIGATION.md (scratchpad). No fixes until findings are before the
operator.

**Z3.10 RESULTS (2026-08-13 ~07:00Z; wind report delivered, boundary report RETRACTED once then
REVISED after operator challenge + lead's own hands-on decode).**
*z310-wind:* F1 CONFIRMED root cause of the fake dominant — THREE (later found: FOUR) parallel
dominant-selection implementations with no period test, while `_MIN_SURFABLE_PERIOD_S=5.0`
already exists and guards the breaking-face channel; the 0.593m@4.14s@268° partition (real SWAN
watershed output, is_wind_sea:False, classified by Tp<10 only) wins all of them and drives the
268° headline AND the peel/closeout math. Double-count: nest-level per-grid WIND confirmed
manual-correct (not a bug); parametric add-on ruled OUT on the display channel (F4/F5 growth is
gated+scoped); nest-compounding contribution UNRESOLVED (needs controlled run). Wind bias:
model wind at the spot ran 40-65% LIGHTER than PRJC1 observed at matched hours (directions
agree ~W) — over-forcing ruled out; PRJC1 is in-harbor (caveat).
*z310-boundary (REVISED after operator pushback — original "deficit is in raw WW3" retracted):*
lead + agent hand-decoded the run's own 00Z f006 grids. 16s-SSW-train ledger: open Pacific
seaward of San Clemente 0.43-0.45m (matches surf-forecast) → our L1 S-boundary line (33.1667N)
0.22-0.38m per cell (-30-45%: WW3's own island-attenuation zone; boundary is seaward of
Catalina per design, San Clemente still stands between it and open water for SSW) → our
boundary spectra 0.24-0.34m (faithful) → served 0.23m. 12s S train: 0.47 → ~0.43 → 0.41
(healthy). Buoy holds 0.5m@16.7s INSIDE the bight where WW3's cell says 0.21 — WW3's coarse
grid over-attenuates across the islands vs reality. Git archaeology: THREE boundary-feed
generations; the oldest (operator-remembered "channel read") was a single-scalar domain-CENTER
read that never split trains — masked the directional bias a partitioned display now exposes.
Cycle freshness + wcoast/global byte-identity + reconstruction-faithfulness all verified. OPEN:
whether the G9 100km clamp is proximate cause of boundary siting (unresolved, trigger-3).
**ARCHITECTURE DISCUSSION (operator, 2026-08-13 ~07:20Z, no ruling yet):** move-the-handoff-out
path examined with numbers: >100km breaks the hourly fast cycle's stationary validity (16s
group speed ~12.5m/s → 3-4h crossing at 170km); "flat grid" costs = UTM meridian-convergence
skew ~0.5° at edges + scale ~0.05% at 170km (SMALLER than the 5° directional bins — Cartesian
likely acceptable, documented); manual line 255-256 forbids mixed-coordinate native nesting
(spherical L1 + Cartesian L2 needs a custom seam adapter — proven pattern at the WW3 edge);
hourly-on-old-L1 proposal ≈ current design already (hourly reuses 6h-old WW3 B-files and
recomputes L1 stationary; the delta is losing hourly fresh-wind response over L1's outer belt
only, swell timing preserved via time-indexed NESTOUT). NEXT: PLAN AMENDMENT A1 — ORDERED by the
operator 2026-08-13 as THE FIX (task chain A1.1 measure → A1.5 reality-validate) (the "51-min nonstationary run" phrasing first used here was
WRONG — operator-corrected; the full run is a QUASI-STATIONARY march, see A1 §fact-base). Parking lot: model_wave_source.py:121 blind swells[0] on non-surf marine
cards (z311 sweep find); NDBC fetch stagger; RTOFS currents; hotstart age; graceful degradation.

**Z3.11 ROUND (R1 dominant-eligibility floor) — dev CLOSED, lead-ACCEPTED (2026-08-13 ~07:25Z),
adversarial gate z311-gate RUNNING.** Marine `634775b` + meta `50d8157b` (API-MANUAL callout):
floor wired at FOUR sites (dev traced a 4th the investigation's call-chain framing missed —
`_effective_swell()`, the actual 268° headline source — ruled into scope; plus `_score_power()`
assert→neutral). 15 new KATs (13 falsifiable at HEAD; 2 boundary cases trivially-true,
disclosed); WC-K5 stale pin updated; 5th-implementation sweep clean for surf path. Lead
acceptance: independent re-run 4 failed/115 passed with the 4 failures VERIFIED pre-existing at
`338b899` by lead checkout-and-run (not trusted from the dev). Deploy after gate.

**Z3.11 GATE PASSED (2026-08-13 ~07:38Z, z311-gate closeout): 0 findings, all 7 rows PASS.**
Own four-site numeric driver (fresh numbers, hand-computed `_effective_swell` blend branch,
exact-5.0s inclusive boundary case incl. eligible-lower-height-beats-ineligible-taller at the
endpoint); mutation drills — floor unwired at `_effective_swell()` alone and
`_compute_peel_angle()` alone, plus the classic filtered-list-position-vs-original-index bug —
each caught by named round tests, tree restored with sha256 proof; every zero-eligible fallback
byte-wise traced via git diff to pre-existing contracts (None / `_POWER_NEUTRAL` / `default=None`
/ bulk-fallback line / `(None,None,None)` sentinel — none invented); sub-5s trains proven still
listed (multiSwell built from UNfiltered `ts_spectral`; dominance-ratio machinery untouched);
scope exactly the 5 declared files, 4 claimed-untouched files diff-empty vs `338b899`; the 4
known pre-existing failures byte-identical at both revs; independent 13-file sweep (gate's own
selection) 4 failed/115 passed. Bonus: gate found two argmax sites NOT in the dev's disclosure
(`_combine_partition_faces_11_3`, `_select_primary_break_point`) and cleared them itself — their
input is built downstream of the PRE-EXISTING stricter WC-D2 floor (sub-5s partitions get
`p_results.append(None)` before break-point computation), so structurally unreachable by sub-5s
trains. Tree byte-identical to `634775b` (status/diff empty, hashes match baseline).
**PUSHED 07:40Z (`338b899..634775b`). Deploy deferred to the post-06Z-run gap (~08:45–09:25Z)**
— Z3.11 is selection/serving-layer only, and the 06Z run (first normal-event-path run on Z3.9
code, first live currents tail-hold) should be observed WITHOUT a mid-run service restart.
After deploy: verify served card's dominant flips to the southerly train, sub-5s train still
listed; then B2 re-accept goes back to the operator.

**Z3.8 AUDIT RESULTS (2026-08-13 ~05:00Z, all three closed out; lead spot-verified every
load-bearing claim in code/manual/live probes). 14 findings; consolidated below.**
*Coverage auditor (3 CRITICAL + 1 info):* (V1) STOFS WLEVEL anchored to WALL CLOCK not the run
cycle, with a hardcoded 2h posting-lag assumption vs ~6h measured live (stofs_wlevel.py:681,
:149; depth 72 at swan.py:3657) — the live crash-loop; also STOFSGridCoverageError never caught
by name in swan.py (0 refs) → logged as generic `swan_fatal` "this is a bug". (V2) WW3 boundary
depth `_OCEAN_FORECAST_HOURS=72` from floor6(C) with zero lag buffer (ww3_partition_fields.py:319,
:547) → 2–7h structural shortfall on ~5/6 cycles, −18h worst with fallbacks. (V3) OFS currents:
wall-clock anchor (ofs.py:265) against WCOFS `cycles=[3]` ONCE-DAILY, max_fhr=72 — with the
D2-widened C+72h window the currents model STRUCTURALLY cannot reach the far edge on ANY cycle
(best case ~3h short); CurrentCoverageError IS caught by name → once V1/V2 fixed this becomes
the next guaranteed refuse-loop. POLICY RULING REQUIRED (C-77 amendment or new source). (info)
Fast cycle hardcodes ofs_currents=None (swan_runner.py:4641). Wind chain confirmed SAFE live.
*SWAN-manual auditor (1 CRITICAL + 1 MEDIUM; 13 conforming rows):* (V4) NO coverage check exists
between the reconstructed WW3 boundary's last timestep and L1's own COMPUTE end
(swan_formats.py:2551-2652 + call site swan_runner.py:5018 — verified: zero time comparison);
manual §2.6.2 (swan-user-manual.txt:588-595, quote lead-verified) documents constant-hold-last
for nonstationary inputs → most plausible behavior is SILENT stale-boundary tail propagated
L1→L2→L3 undetected. Live: current run's boundary ends 08-15T18Z vs compute end 08-16T00Z (6h
gap, masked only by V1 crashing earlier). (V5) `cycle_used` returned by reconstruct_boundary is
never logged/compared vs the run cycle — gap invisible in logs. Conforming: WIND/WLEVEL/CURRENT
series-vs-COMPUTE by construction; nest windows shared-source; mxc/myc off-by-one correct; HRRR
Lambert→earth rotation; BOTTOM/WLEV sign; GEN3 deck byte-matches manual example.
*State auditor (3 CRITICAL + 2 HIGH + 2 MEDIUM + 2 LOW; full inventory):* (V6) retry loop has NO
backoff/failure-counter/escalation — a permanent bug retries at full cadence forever, invisible;
22h+ full-run outage while every /health signal read fresh. (V7) staleness-honesty:
`record_input(..., True)` fires per-substep BEFORE the crash point every retry → /health inputs
read green during outages; last_run kept fresh by fast cycle. (V8) `state._inputs` pure
in-memory, no restore → every restart shows false "failed / inputs unavailable" until next full
run (the recorded post-restart artifact, now root-caused). (V9) forced-run signal
(`force_full_run_signal`) lost on restart AND unrecoverable by config re-push (geometry already
persisted); (V10) service.py forced-path fallback reads gatherer `lastExtendedCycleAssembledAt`
(NOT restart-safe) instead of `tracks.hrrr_extended.lastCompleted` (restart-safe). (V11) hourly
fast-cycle trigger cleared BEFORE the attempt (service.py:609-613) — no retry, asymmetric with
the D3 fix. (V12) run-dedup marker MemoryCache-only (no Redis configured — verified), restart
wipes 6h dedup → duplicate-run waste risk. (V13) swan_grid_sizing.json plain write, only
non-atomic persist in the service. (V14) LOW: blocking no-timeout lock in geometry-push path;
post-restart cooldown forgotten; hotstart-token age gate unverified (parked).
- **⚠ NEW FINDING (blocks Z3.5 item 2, surfaced as Q3):** the Z3.2 display-wind store read is
  structurally failing on EVERY request — 16/16 requests post-restart logged "display wind
  fell back to run-cached field: gap:missing_hour". Mechanism (code-verified at `0ebdd01`):
  `surf.py` reads `get_wind_series(first_ts, last_ts)` over the ENTIRE served timeline,
  all-or-nothing; the store's `age_out()` deletes every hour before wall-clock now (design §2
  "self-bounding") and holds +48–72h at GFS-native 3-hourly cadence — so a range starting at
  cycle start (past within 1h of any run) and/or crossing +48h ALWAYS refuses. The transition
  fallback is carrying display wind in production; deleting it (step-5 inventory item 2)
  would null display wind. Z3.2's reality-gate PASS was measured in the only narrow window
  where the read can succeed — a gate-design lesson for round-close triage.
- **Health artifact (recorded, watch at gate A):** `/health` currently `status:"failed",
  reasons:["required input unavailable: ww3_boundary","required input unavailable:
  bathymetry"]` while the fast cycle publishes fine — those are full-run inputs no run has
  fetched since the 20:30Z restart (both full-run attempts refused pre-restart, at the wind
  step). Expected to clear when gate A's full run fetches them; if it persists past a
  successful full run, it is a real health-semantics defect.
- Wind gatherer store healthy: 53 hours (47 HRRR + 6 GFS), oldest 20:00Z, newest 08-14T12:00Z.

**Z3.5b ROUND + QC GATE Z3.5b RECORD (2026-08-11 ~22:30Z): ✅ GATE PASS, 0 remediations.**
Round = the Q3-ruling amendment of the held Z3.5 tree: new tolerant store accessor
`get_present_hours()` (never refuses on gaps); surf.py display read swapped to it
(store-primary per hour, `wind_for_display` PERMANENT fallback, both-absent → null; single
WARNING only on zero-hours-while-gatherer-enabled); every wind_for_display deletion reversed
byte-identical to HEAD (swan.py machinery + 11 test files' stale adaptations, incl.
`test_h5_pipeline_wind.py` whole-file and a 1-line `test_rw1_cards_from_model.py` fixture
restore lead-direct); the prior round's service.py legacy-trigger deletions + health
`inputs.wind` re-sourcing RETAINED. Lead acceptance: independent runs reproduced implementer
numbers exactly at every step (`2 failed, 99 passed` core set; `3 failed, 169 passed`
extended — 2 disclosed date-dependent pre-existing + 1 GRIB2-library-missing local-env-only,
lead-verified `import eccodes`/`pygrib` both fail on DILBERT). Adversarial gate (auditor
firewalled from implementer report): 7/8 rows clean PASS, row 4 PASS-with-finding; mutation
drills — reverting the display read to all-or-nothing `get_wind_series` flips 2 real
endpoint KATs; neutering the accessor flips 6 store-wins tests while fallback tests stay
green; exact-valid_time matching + no None→0 coercion confirmed; old per-request fallback
WARNING string absent; out-of-scope files hash-verified untouched. **F1 [MEDIUM] PUSHED BACK
with primary evidence:** lead diffed HEAD vs `stash@{0}` for test_h5_pipeline_wind.py — 0
hits for any legacy-inline marker; every changed symbol is wind_for_display content; the
brief's "preserve category-(b) content in this file" premise was factually empty, whole-file
restore correct. **F2 [LOW] ACCEPTED as coordinator-process finding:** the pre-round hash
baseline was captured ~2 min AFTER agent resume, so the agent's first edit (the accessor)
leaked into it; the real pre-round deletions are independently proven by the pre-dispatch
diff hunks in the session record. Lesson queued: capture audit baselines BEFORE dispatch.
Doc batch (meta repo) revised to the hybrid by docs round (incl. one committed stale
passage found+fixed per doc-code sync); ADR-107 stays Proposed, carries a Q3 Amendment
section. Ship authorized by operator ("push/deploy after the adversarial audit and fixes").

**Z3.2 SPLICE RULING (coordinator, 2026-08-11):** the design's §3 "Today" column was stale —
H5 (2026-08-02) had already collapsed the request-time HRRR fetch into a per-cycle resample of
the run's own blended field, cached as `wind_for_display`. The approved end state ("display
wind reads the store") is spliced at surf.py `_resolve_timestep_wind()` as a REQUEST-TIME
`get_wind_series()` read (store primary) — not at the swan.py precompute, which would keep
display wind refreshing only when a SWAN run completes, preserving the coupling the 2026-08-03
operator ruling exists to kill. Transition semantics: run-cached `wind_for_display` is the
fallback ONLY on store refusal/empty (one WARNING per request, named reason); fallback and the
swan.py build are deleted in step 5. Wire shape + `windSource` unchanged. Grid shapes verified
compatible; `_sample_wind_at_point()` reused unmodified. 8 new KATs; 40/40 targeted green;
2 pre-existing wind-store/gatherer disk-persistence test failures disclosed (stash-verified
at HEAD, parking lot).
PA6's withholding is MOOT — operator approval exists (WIND-PROVIDER-ARCHITECTURE-DESIGN-
2026-08-03.md, FULLY APPROVED, trigger classification §6). Z3 = §5 migration steps 2–5 of
that design, each its own deployed + reality-gated round, run in the marine chain AFTER
Gate K closes (single-round-in-flight rule): step 2 display wind → store; step 3 full-run
trigger on `extended_cycle_assembled` + store reads + gap-refusal invariant; step 4 fast
cycle 12 h on `hourly_cycle_assembled`; step 5 deletions + doc batch (incl. lifting the
design into ADR/PROVIDER-MANUAL as the doc-sync this ruling never got). The C-77-class
completeness gap Z1 found is closed structurally by step 3 (runs can no longer read a
partial fetch).

---

## PHASE T — TIDE COHERENCE (operator-ordered 2026-08-11, REQUIREMENT ruling) — 🟡 IMPLEMENTED ✅ (marine `53eea82`+`a8a27e2`), Gate T ✅ PASS (adversarial, mutation-proven), **DEPLOYED 2026-08-11 07:29:40Z on operator go** — **✅ REALITY CHECK PASS 2026-08-11 11:20Z:** served tideLevel 67/67 timesteps nonzero STOFS values (lead independently reproduced the exact values via scratch re-fetch+sample — byte-identical, same source/anchor proven); vs CO-OPS 9410660 observed −1.068 m MSL at 11:12Z, served brackets −1.215→−1.122 (11:00→12:00Z) — correct phase (falling through the morning low), ~0.13 m agreement, NOT zero. ONE-SOURCE verified live (STOFS forces WLEVEL + display; the only CO-OPS fetch is the permitted tide-chart predictions feed). **T2 ✅ SHIPPED** (`0aa0ebf`+`b4dfb40` KAT remediation, adversarial gate PASS after F1/F2 fixes) **+ refusal-logging fix `0d46a82`** (first live cycle's all-null was undiagnosable — silent refusal branch now logs the reason; turned out to be the stale pre-T2 run, but the gap was real). Phase T CLOSE pending operator acknowledgment.

**Operator ruling (chat, 2026-08-11, verbatim intent):** single water-level truth is "not a
DESIGN CHOICE, that is a FUCKING REQUIREMENT" — the 1-D surf pipeline and the beach-profile
endpoint MUST use the SAME water level SWAN itself is forced with, per cycle. This ruling
is the operator authorization for the data-flow change (the tide-trace found the S2
migration orphaned these consumers at swan.py:3097-3125 → manufactured 0.0 at
swan.py:2425/2603 and silent 0.0 at beach_profile.py:1147-1165, since 2026-08-09 22:09Z).
**Design (T1 — FINAL, operator rulings 2026-08-11 in chat, escalating sequence):**
(1) "that is a REQUIREMENT" — 1-D pipeline + beach profile use the SAME water level SWAN
is forced with; (2) "NO ONE USES COOP" — quick-update's CO-OPS-primary forcing dies;
STOFS forces EVERY run type (stationary plumbing change authorized); (3) **"ONE SOURCE.
THAT IS IT."** — the CO-OPS fallback rung DIES ENTIRELY from the model water-level path.
Final design: water level = STOFS, sampled at the spot per timestep for the 1-D/profile
consumers and forcing all SWAN runs; STOFS unavailable → the run REFUSES loudly
(tide_fetch_failed no-publish; journal + health reason) — no fallback, no uniform stamp,
no substituted value anywhere. beach_profile.py silent-0.0 branch → refuse/null, logged.
CO-OPS may persist ONLY for non-model display consumers (tide charts) if any exist —
model path loses it completely. **Supersedes ADR-104 D10 / P8's CO-OPS fallback rung
(operator chat override; ADR/manual amendment lands with this phase's doc-sync).**
Stage-2 setup dead code + the old eta_shore wave-setup diagnostic remain OUT of scope
(separate tracked finding). Evidence: scratchpad TIDE-TRACE-FINDINGS.md. Tests: KATs for
nonzero STOFS tide propagation end-to-end (both run types) + refusal KATs (STOFS absent →
no-publish, nothing runs CO-OPS), same-commit. Deploy only on explicit operator go.

**T IMPLEMENTED (2026-08-11): marine `53eea82` + `a8a27e2`** (agent surfaced the
architectural triggers once, complied on the coordinator's formal approval statement per
the 2026-08-05 protocol; both commit messages cite the operator rulings). Windows local
verification 300 passed / 8 pre-existing (stash-verified). Pushed + librewxr synced
`a8a27e2` (NO restart — running process still pre-T; an unexplained-but-clean
administrative service restart occurred 06:31:18Z, systemd stop/start, not a crash —
possibly operator-issued; the 06Z cycle runs pre-T code). Container test run queued
behind the in-flight 06Z cycle. **T2 follow-up (required before phase close, flagged by
implementer): the served `tideLevel` DISPLAY field's own cache path
(`swelltrack_tide_predictions`/`resolve_ondemand_tide_level()`) is not yet wired to
STOFS — after deploy it reads null (honest, no longer 0.0) until T2 lands.** Deploy
awaiting operator go.

## Round-close & bookkeeping (every phase)

- Gate record in THIS file (CURRENT STATE table + per-phase ✅ markers with commits, accept
  numbers, deviations) — same convention as the L1 plan.
- rules/verification.md round-close gate applies (independent lead verification of every
  agent claim; false-claim protocol on mismatch).
- Doc-sync tags removed by the shipping phase; H3-style doc-truth sweeps stay meaningful.
- Lessons at close: triage into rules/ files per CLAUDE.md "Capture lessons in the right
  place" (candidate already visible: "never interpolate a source's partition slots across
  cells" belongs in PROVIDER-MANUAL/rules/weather-skin lessons; final routing at close,
  surfaced to operator first).
- Pytest/vitest baselines recorded fresh at each phase dispatch (last known: marine 270
  pass / 3 tracked pre-existing; dashboard 92/92 + tsc clean; entry chunk 203.00 KB gz).

---

## OPEN OPERATOR QUESTIONS

*(Coordinator appends here anything NOT answerable from the docs/plan/fixit log — plain
English, self-contained, newest at top. Answered items move to the decision log. Operator
instruction 2026-08-10: "create a list of questions in the plan for items THAT ARE NOT
ANSWERABLE BY THE DOCS, if they are answerable by DOCS, do not ask me.")*

### Q3 — ✅ ANSWERED (operator 2026-08-11, in chat): "Q3 that is fine, I do not understand why that is even a question? It is apparent you built the mechanism wrong, and need to fix it."

**Ruling recorded:** Option A semantics, classified by the operator as a DEFECT FIX, not a
design choice — the display read was built wrong (all-or-nothing whole-timeline read against
a store that by design cannot hold that range). Corrected design: store is PRIMARY for every
hour it actually holds; the run-forced wind field (`wind_for_display`) permanently serves
past hours, far-window off-slot hours, and any store-absent hour; both-absent → null.
The Z3.5 deletion inventory is amended: the `wind_for_display` build + fallback SURVIVE
(no longer "transition"); the rest of the deletions proceed. ADR-107 draft + doc batch to be
revised to match before commit. Implementation round Z3.5b dispatched 2026-08-11 ~21:30Z.

### Q3-original (question text as asked, for the record)

**Context, plain English:** you approved a design where the wind shown on the surf page is
read from the wind-gatherer's assembled store (so it can refresh hourly without waiting for a
model run), with the old run-cached wind kept only as a temporary safety net, to be deleted in
the final cleanup round (Z3.5, currently held uncommitted). This session verified the safety
net is not temporary — it is carrying the page on EVERY request. The store read fails by
construction, for two reasons the store itself is DESIGNED to have: (1) it throws away hours
older than the current hour, but the served forecast timeline starts at the model run's start
hour, which is in the past within an hour of any run; (2) beyond +48 hours it only holds
every-3rd-hour wind (that is all GFS provides natively), but the read demands every hour or
refuses entirely. So "read the whole timeline from the store" can essentially never succeed.
Deleting the safety net as planned would blank the forecast wind display.

**Options (each amends the approved 2026-08-03 design's end state, so each needs your ruling):**
- **A — make the hybrid permanent (RECOMMENDED).** Store stays primary for the hours it
  covers (now → +48h); for past hours and the 3-hourly far window, the display permanently
  uses the wind field the model run itself was forced with (the existing run-cached field).
  The step-5 deletion list shrinks: the run-cached display field and its fallback stay; the
  rest of the deletions (dead legacy branches, old fetch orchestration) proceed. Honest
  provenance, no fabricated values, smallest change.
- **B — make the store hold what the display needs.** Keep past hours back to the serving
  run's start instead of deleting them at the current hour, and fill the far window to hourly
  (the hourly-filling question was already deferred once — it moves interpolation into the
  store, which you previously declined as a relocation). Bigger change, touches the store's
  approved "self-bounding" design.
- **C — give up on store-driven display wind.** Display wind reverts to the run-cached field
  only (what H5 shipped); the store remains solely the model-forcing source. Simplest, but
  loses the "wind refreshes hourly between runs" property the 2026-08-03 ruling asked for —
  and with fast cycles now running hourly (Z3.4 live), a new run refreshes the cache hourly
  anyway, so the practical loss may be near zero. Worth weighing against A.

**Recommendation:** A, with a note that C is defensible now that hourly fast cycles are real.
Either way the ADR-107 draft + doc batch (uncommitted) need matching revision before commit.

### Q2 — ✅ VOID (operator 2026-08-11): the premise was the coordinator's misreading

Operator, verbatim: "I NEVER STATED that you had to show 'the whole pier.' … YOU DO NOT
EVEN NEED TO KNOW WHERE THE PIER IS. … you only need to scale and locate the
orthophotography IN THE RIGHT PLACE. If you did that right, the pier shows up. Does it all
fit in the card? No, and I never expected it to." Consequences: (1) H1's
frame-seaward-edge term is CANCELLED — no served pier field, no per-spot preset, no frame
change; H1 = tile-budget raise only, which is SHIPPED. (2) Phase H has NO held terms
remaining — correct imagery scale/placement is exactly what H0 now gates permanently
(registration ≤10 m; measured 0.00006 m). (3) Strip on-screen size is whatever true scale
dictates in the ruled 4x2+scroll+fullscreen card — judged at the H-Accept eyeball, not by
a frame rule. Options A/B/C below are DEAD.

### Q2-void (original question text, superseded by the above)

**Context, plain English:** you ruled the heat map should frame enough ground to include the
whole pier (which also shrinks the colored strips and sharpens the photo). Implementing
that, we found the dashboard has no way to know how far out the pier reaches: the server
computes the pier's footprint internally for the wave model, but never sends any of it to
the browser. The plan's wording assumed it was available; it isn't. Inventing it in the
browser (hard-coding "567 m" for this one beach) would break the dashboard for any other
site. Everything else in the heat map round proceeds — only the "how far seaward to frame"
number is on hold.

**Options (A and C add a field to what the server sends, which is an architectural change
needing your sign-off):**
- **A — serve the pier's seaward extent (RECOMMENDED).** One small additive field on the
  heat-map response (the server already computes the footprint; this just exposes its
  seaward tip distance). Generic for any spot/structure; the frame formula then works
  exactly as you ruled.
- **B — display-only workaround.** Widen the frame by a fixed factor or fixed extra ground
  (e.g. +400 m seaward). No server change, strips shrink and photo sharpens, and at this
  beach the pier happens to fit — but the number is arbitrary and spot-blind.
- **C — per-spot display preset.** A configured "frame this much ground" value per spot
  (same pattern as the beach-profile display window). More operator control, slightly more
  plumbing than A.

**Recommendation:** A.

### Q1 — ✅ ANSWERED (operator 2026-08-10 + pre-existing ruling 2026-08-03) — see decision log entry below; Z3 re-scoped accordingly

**The question was already ruled on 2026-08-03 and the coordinator failed to find it before
asking.** The ruling: wind is gathered by an independent background component that keeps ONE
fully assembled wind set, polling/top-up-fetching until every hour of a cycle is held; model
runs trigger only on "cycle fully assembled" — never on a partial fetch; the previous
assembled set provides the immediate fill on cold start / backfill. Recorded, operator-
approved twice, in: `briefs/AUDIT-OPUS-WINDOW-2026-08-03.md` decision item 9 (operator
directives verbatim) and `briefs/WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03.md` ("✅ FULLY
APPROVED 2026-08-03", §2 one-assembled-set store, §5 five-step migration order, §6 trigger
classification "All authorized by the 2026-08-03 operator ruling"), plus the V3-F1 row in
MARINE-FORWARD-PLAN.

**Why it still exists (traced 2026-08-10):** only migration step 1 (gatherer + store,
DORMANT by design) was ever built and deployed (marine `dd301af` + fixes). Steps 2–5 —
switching the display wind, the full-run trigger, the fast cycle onto the store, then
deleting the inline-fetch path — were never turned into tracked task rows in any active
plan. Their only trace is a "HOLD until step-1 gate passes" note in a session-resume brief
(`briefs/SESSION-RESUME-2026-08-04-POSTCOMPACT.md:84`); when that session closed, the queue
vanished — the exact "deferred item buried in narrative" failure rules/verification.md
Step 3 exists to prevent. The approved design also never became ADR/manual target-state, so
Z1's diagnosis (and this plan's PA6) treated the question as open.

*(Original question text retained below for the record; options A–D are VOID — the 2026-08-03
architecture, which subsumes A and B, governs.)*

### Q1-void (2026-08-10, from Z1) — original question text (superseded by the above)

**Context, plain English:** our forecast runs need wind data files from the government's
HRRR weather model. Those files appear on the download server gradually over an hour or two
after each HRRR cycle. On 2026-08-10 our run started before the later files were posted, the
fetcher quietly stopped at the last file it found and called that success, and we published
a forecast with a 26-hour empty stretch in the middle — no warning anywhere. Our own rule
says a model runs on all its inputs or refuses loudly; today it does neither. (A ready-made
"keep checking until the files appear" module already exists in the repo but is deliberately
switched off; wiring it in would be its own decision.)

**Your options (all except D change when/how runs happen, so per the plan's PA6 row each
needs your sign-off — none is pre-approved):**
- **A — wait and retry (RECOMMENDED).** When files are missing, keep re-checking for a
  bounded time (e.g. up to ~90 min) before running; if still missing, refuse loudly instead
  of publishing a forecast with a hole. Cost: forecasts publish later on affected cycles.
  Matches the existing "all inputs or loud refusal" principle already enforced for the other
  wind model. The dormant retry module could be reused (sub-decision: yes/no to wiring it).
- **B — publish, then backfill.** Publish the partial forecast immediately, then fill the
  hole on a follow-up run once the files appear. Cost: the hole still exists (and is
  visible) for a while; more moving parts.
- **C — fill the hole from the other wind model (GFS).** Architectural: moves the agreed
  HRRR/GFS boundary. Fastest publish, but blends coarser wind into hours we promised to
  HRRR.
- **D — status quo.** Keep publishing with silent holes. Contradicts the loud-refusal rule.

**Recommendation:** A. Full evidence: scratchpad `Z1-RULING-BRIEF.md`.

---

## PLAN AMENDMENT A1 — Big-L1 / true-non-stationary FIX (2026-08-13, ORDERED — operator: "put the fix in the plan, not just a timing experiment")

**Problem this addresses (operator-verified, 2026-08-13).** The served southerly swell runs
30–45% below reality, and the deficit was traced with hand-decoded numbers to WHERE our L1
boundary samples the WW3 grid: the boundary line (33.1667°N) is seaward of Catalina by design,
but San Clemente Island still stands between it and open water for SSW swell, and WW3's coarse
grid attenuates energy crossing the islands HARDER than reality does (buoy 46253 holds 0.5 m of
the 16 s train inside the bight where WW3's own cell says 0.21 m). Ledger for the 16 s SSW train,
2026-08-13 00Z f006: open Pacific seaward of San Clemente **0.43–0.45 m** (matches
surf-forecast's WW3 read) → our boundary cells **0.22–0.38 m** → our boundary spectra files
0.24–0.34 m (faithful write) → served **0.23 m**. The 12 s S train passes healthily
(0.47 → 0.41 m). The only way to beat WW3's island bias — not just relocate it — is a domain
large enough to CONTAIN the islands and do the shadowing ourselves with real bathymetry.

**Fact base (all code/manual-verified this date; corrects two coordinator misstatements):**
1. **The full run is NOT non-stationary** (operator-corrected after the coordinator misread this
   repeatedly): `swan_formats.py` T1.0 emits `MODE NONSTATIONARY` (which only enables
   time-tagged inputs) followed by a SEQUENCE of `COMPUTE STAT [t]` — one stationary
   equilibrium solve per forecast hour, a quasi-stationary "frozen march." There is NO
   wave-propagation time-marching anywhere in the system today. Consequence: today's model
   equilibrates the whole domain instantly each hour — swell effectively teleports across L1,
   arriving hours early in principle. True non-stationary would fix arrival timing as a genuine
   physics gain at ANY domain size.
2. **The 100 km stationary-validity cap (G9, operator ruling 2026-08-09) binds EVERY run**, not
   just the hourly fast cycle, because every solve is stationary. A 16 s swell crosses a 170 km
   domain in 3–4 h (group speed ~12.5 m/s) — quasi-stationary is indefensible at that extent.
3. **Hourly cycle today**: stationary full-nest snapshot reusing the last full run's WW3-derived
   L1 boundary FILES (6–8 h stale at the WW3 edge already) but RE-COMPUTING L1 stationary each
   hour with fresh wind.
4. **Coordinates**: all levels are Cartesian (UTM meters, `CGRID REG`). SWAN manual line
   255-256: native nesting requires the SAME coordinate type parent↔child — spherical L1 over
   Cartesian L2 is not natively possible; a custom seam adapter (extract L1 spectra at L2's
   boundary, write file-based spectra — the proven pattern we already use at the WW3→L1 edge)
   would be required if spherical were ever chosen.
5. **Cartesian error at ~170 km** (operator accepted in principle if tolerable): direct size
   error negligible (~0.02–0.06% scale); the real term is DIRECTION/position — ~0.5–0.9°
   meridian-convergence skew + up to ~2 km lateral ray displacement (straight-line vs great
   circle). Height is touched only indirectly where direction matters most (island shadow
   edges, tight refraction windows: ~1° rotation moves a shadow boundary a couple of km).
   All bounded below the current 5° directional bin width. Validation must spot-check
   shadow-edge sensitivity.

### A1 DESIGN v1 (2026-08-13, lead-authored; grounded in the LIVE production L1/L2 decks read
### this date and the LOCAL manual. Agents implement THIS — they do not design.)

Live baseline (read from `/var/lib/weewx-clearskies/swan/level{1,2}/INPUT`, 06Z run):
L1 = `COORDINATES CARTESIAN` (UTM 11N), origin (335934.64, 3672592.58), **92.8 × 98.8 km**,
`CGRID REG … 91 100 CIRCLE 72 0.03 1.0 34` (~1020×988 m cells; 72 dir × 35 freq), boundary
`BOUNDSPEC SIDE S + SIDE W CCW VARIABLE FILE`, `GEN3 ST6 … U10PROXY 28.0 AGROW`,
`NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=500 alfa=0.01`,
`NGRID 'inner'` + `NESTOUT 'inner' 'nest_out.dat' OUTPUT <C> 1 HR`, then the hourly
`COMPUTE STAT` march. **L2 already ingests the nest via `BOUNDNEST1 NEST 'nest_in.dat'
CLOSED` while itself marching `COMPUTE STAT <t>` through the whole horizon — the time-indexed
seam mechanism the hourly rewire needs is ALREADY in production.**

**D1 — Domain.** Extend L1's S and W edges only; N and E unchanged. Geographic targets:
**SW corner (32.60°N, 119.25°W)** — south of San Clemente's southern tip (~32.80°N) with
open-Pacific WW3 cells seaward (the verified-accurate zone, ledger 0.43–0.45 m); NE corner
stays (~34.07°N, ~117.77°W). Result ≈ **138 km E-W × 163 km N-S**, UTM 11N Cartesian as today
(skew tolerance quantified in the fact base). Cell size stays ~1.0 km → ≈ **138 × 163 meshes
(~22.5k cells, 2.47× today's 9.1k)**. Spectral resolution unchanged (`CIRCLE 72 0.03 1.0 34`).
Code: `swan_domain.py` sizing gains an ISLAND-CONTAINMENT union — L1 box = union(spot-derived
box as today, fixed containment corners `L1_CONTAINMENT_SW = (32.60, -119.25)`); cap
`L1_MAX_EXTENT_KM` **100 → 175** (geography.py:133). Both constants operator-ordered under this
amendment; G9's 100 km rationale (stationary validity) is superseded FOR L1 ONLY because L1
stops being stationary (manual line 5718-5719: <100 km stationary recommended, otherwise
non-stationary advised). Catalina (already interior) and San Clemente resolve as dry cells
(~30×8 cells at 1 km) — OUR bathymetry does the shadowing; no OBSTACLE commands at L1.

**D2 — Compute mode (full run L1 ONLY; L2–L4 unchanged).** Keep `MODE NONSTATIONARY`; replace
the 57–73-solve `COMPUTE STAT` march with the manual's own canonical pattern (lines 5708-5713):
```
COMPUTE STAT <C+0>                      ! spin-up: stationary equilibrium = initial state
COMPUTE NONSTAT <C+0> 10 MIN <C+72h>    ! true time-marching, dt = 10 min
```
`NUMERIC` gains `NONSTAT mxitns=1` (manual 5730-5731: ≤10-min dt → 1 iteration/step); the
STOPC stationary criteria stay for the spin-up solve. **dt = 10 MIN** (manual 5721: at most
10 minutes advised). Courant (manual 5725-5728, <10 for fastest/dominant): dominant 16 s
cg≈12.5 m/s → C≈7.5 ✓; 25 s forerunners cg≈19.5 → C≈11.7, marginally over for the rare
extreme tail — mitigation ladder if A1.1's physics row shows noise: dt = 6 MIN (C≈7.0 for
25 s, ×1.67 step cost). All L1 inputs (WIND/BOUND/WLEV/CUR) are already time-tagged files —
non-stationary interpolates them natively, zero input-side changes. `NESTOUT … 1 HR`
unchanged (same L2 contract, and the 48–72 h tail gains hourly nest records vs today's
3-hourly solves). L1 hourly hotstart files retired (nothing consumes them once the fast cycle
drops L1); full-run initial state = the spin-up solve, no hotfile dependency.

**D3 — Boundary.** Per-wet-cell WW3 reconstruction (ADR-106 R1) mechanism UNCHANGED; the
perimeter moves with the box: S side at 32.60°N (~7–8 gfswave 0p16 wet cells), W side at
119.25°W (~9 cells). Same source, same time axis, same coverage-window rule (Z3.9a).

**D4 — Bathymetry.** Existing chain unchanged: NCEI regional DEM → **CRM fallback (~90 m)**
(bathymetry_resolver.py); NOAA CRM's Southern California volume nominally covers the whole big
box incl. San Clemente and the basin. A1.1 PROBES actual tile coverage/fill at the SW quadrant.
A GEBCO-class new provider is scoped ONLY if the probe finds a hole. Datum deltas (MSL vs
NAVD88, <1 m) are noise at basin depths.

**D5 — Hourly (fast) cycle rewire.** Fast cycle runs L2→L3→L4 + SwellTrack/1-D exactly as
today; **L1 is SKIPPED**. L2's `nest_in.dat` := the ARCHIVED `nest_out.dat` of the most recent
COMPLETED full run (per-run retained copy `level1/nest_out_<cycle>.dat`, kept ≥24 h; the live
workdir file is not depended on). L2's deck is byte-unchanged — `BOUNDNEST1 NEST CLOSED` +
`COMPUTE STAT <t>` already reads the time-tagged record stream mid-file (production behavior
today; A1.1 runs the one cheap disambiguation: a SINGLE mid-file `COMPUTE STAT` against a
multi-record nest file). Fresh wind still forces L2–L4 every hour — the accepted loss is
confined to L1's belt outside L2 (~6–8 h worst-case latency on new offshore wind). NEW health
surface: `l1NestAge` + hourly-run refusal when the archived nest exceeds
`L1_NEST_MAX_AGE_H = 9` (one missed full run + margin) — refuse-loudly per standing no-publish
posture; **constant flagged below as the one open ruling**.

**D6 — Wind store impact.** Gatherer bbox derives from the L1 box (existing derivation) →
grows ~2.5×; HRRR CONUS + GFS both cover 32.6°N offshore; disk/transfer growth bounded and
trivial vs. the existing store. No schedule/cadence change, no store schema change.

**D7 — NOT changing (scope fence for every A1 agent):** L2/L3/L4 grids and decks, spectral
resolution at every level, GEN3 ST6 physics line, SwellTrack/1-D/SurfBeat, the per-wet-cell
reconstruction algorithm, provider modules other than bbox inputs, API/served contracts, the
5° directional-resolution question (separate parked experiment).

**D8 — Failure/rollback.** Full-run failure → hourly keeps serving off the last archived nest
until the D5 age gate refuses (existing refuse-loudly UX). Rollback = git revert of the domain
constants + runner switch; no data migration; stale hotstart/nest artifacts are inert files.

**D9 — Predicted cost (A1.1 CONFIRMS, does not choose).** Iteration-sweep units on today's
grid=1: march today ≈ 57–73 solves × I_stat iterations × 1.0; big-L1 non-stat ≈ (I_stat spin-up
+ 432 steps × 1 iter) × 2.47. At I_stat≈15 → ≈ parity with today's L1 wall-clock share; worst
plausible (well-warmed I_stat≈8) ≈ 2× L1's share. The full run's L1 share is unknown until
A1.1's per-level split — hence measurement before the cadence call is final. The HOURLY cycle
gets strictly FASTER (drops its L1 solve entirely).

**TASK BREAKDOWN (strict order — the fix ships at A1.5, not at A1.1; every task implements
the DESIGN above, verbatim; design deviations are findings to surface, never agent calls):**

- **A1.1 VALIDATE THE DESIGN'S PREDICTIONS (scratch measurement round, librewxr off-cycle,
  nothing published, production-idle windows only).** Six rows, all specified by the design:
  (a) per-level wall-clock split of the current production full run (parse existing work-dir
  PRINT/log timestamps — no new runs); (b) measure I_stat (iterations per stationary solve,
  distribution across the march) from the live PRINT files; (c) timing run of the D1 big grid
  under D2 (`COMPUTE NONSTAT`, dt=10 MIN, mxitns=1) — CRM bathy if the (f) probe passes, flat
  deep extension otherwise (timing-only caveat); parametric boundary proxy acceptable, caveat
  stated; (d) physics arrival row on the CURRENT extent with REAL decks: march vs non-stat,
  arrival-time delta of the ≥12 s front at a probe point (quantifies "swell teleports");
  (e) the D5 seam disambiguation: single mid-file `COMPUTE STAT` against a multi-record nest
  file — pass/fail with PRINT evidence; (f) CRM coverage/fill probe of the big box SW quadrant
  (D4). Output: measured numbers beside D9's predictions + the dt confirmation (10 vs 6 MIN
  per D2's ladder). NOT in scope: choosing extent, seam mechanism, or whether to proceed.
- **A1.2 BATHYMETRY PER D4.** If A1.1(f) passes: wire the existing chain to the big bbox and
  verify island dry-cell rendering (San Clemente ~30×8 cells) — small task. If it fails: STOP,
  surface, and scope the GEBCO-class provider as its own ruled round.
- **A1.3 BIG-L1 NON-STATIONARY FULL RUN PER D1+D2+D3.** Domain constants
  (`L1_CONTAINMENT_SW`, cap 175) + union sizing in swan_domain.py; D2 deck emission in
  swan_formats.py (spin-up `COMPUTE STAT` + `COMPUTE NONSTAT <C> 10 MIN <C+72h>`,
  `NONSTAT mxitns=1`); boundary perimeter follows the box (D3, mechanism untouched); retire L1
  hourly hotstarts (D2). Wind-store bbox growth rides the existing derivation (D6).
- **A1.4 HOURLY CYCLE REWIRE PER D5.** Fast cycle skips L1; per-run nest archive
  (`nest_out_<cycle>.dat`, ≥24 h retention); L2 fed the archived nest (deck byte-unchanged);
  `l1NestAge` health surface + `L1_NEST_MAX_AGE_H = 9` refuse gate (constant pending the open
  ruling below).
- **A1.5 VALIDATE AGAINST REALITY — gate for everything downstream.** Re-run the 16 s-train
  ledger vs buoy 46253 spectral at matched hours (target: served S-train no longer 30–45% low);
  shadow-edge sensitivity spot-check (the Cartesian ~0.5–0.9° skew tolerance); arrival-timing
  sanity (march vs non-stationary on the same case). **Operator ruling 2026-08-13: no further
  eyeball accepts until the model is right — B2/S/K/H re-accepts unfreeze only after A1.5
  passes.**

**Open ruling for the operator (ONE, non-blocking until A1.4):** when the archived L1 nest
exceeds `L1_NEST_MAX_AGE_H = 9` (a full run missed its slot), the hourly cycle REFUSES
(no-publish, loud) per the design default — confirm, or choose serve-stale-with-health-flag.

**Historical notes:**
- Whether the G9 100 km clamp was the proximate cause of today's boundary siting (unresolved by
  Z3.10; moot once A1.3 lands).
- Interim posture while A1 is in flight: current siting stays; its ~30–45% long-period SSW bite
  is a STATED KNOWN BIAS of the served forecast (recorded here, 2026-08-13).

**Related but independent (not gated on this amendment):** the in-chain ~10–20% long-period
loss candidates — the L4/1-D handoff at deep ledges (K-round clamp = mitigation, never a
physics fix) and 5° directional resolution vs the manual's ≤2°-for-swell guidance (§2.6.3) —
are attackable as controlled experiments WITHOUT touching the domain, and remain on the
parking lot with the R1 dominant-floor fix (Z3.11) covering the display-layer symptom now.
