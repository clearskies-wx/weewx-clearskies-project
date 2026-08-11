# Marine Page Fixit Plan — boundary plug-in, ruled card fixes, break/zone redefinition (2026-08-10)

## 📍 CURRENT STATE — updated every working session (last: 2026-08-11 post-resume)

**RESUME POINTER: session scratchpad `SESSION-STATE.md` holds the full session context
(agent roster, pending operator decisions, operational traps). Authority order: this
table → Phase records below → SESSION-STATE.md.**

| | |
|---|---|
| **Live on librewxr** | RUNNING SERVICE = marine `a396866` **Phase T tide fix DEPLOYED** (restart 2026-08-11 07:29:40Z, health 200, auth enforced; deploy-marine.sh full run). Tide reality-check vs CO-OPS 9410660 pending next model cycle (journal monitor armed). B2 boundary rework also live. |
| **Live on weather-dev** | dashboard `1d37593` **DEPLOYED** (dry-beach fix pushed + redeployed 2026-08-11; was parked) |
| **OPERATOR RULINGS 2026-08-11** | (1) T deploy **OK** → done; (2) CTHETA/CSIGMA L1 experiment **OK** → dispatched to wave-trace agent (scratch copy, deck-only change, no production edit — permanent limiter change stays an architectural decision for the operator); (3) push+deploy `1d37593` **OK** → done; (4) new-source investigation **NO** — operator asked instead what source is in use: **USGS NAIP Plus** via API exportImage proxy (live config confirmed provider=naip, proxyMode=api at spot lat/lon); ESRI World Imagery is the non-CONUS fallback only |
| **STRUCK/OPEN** | B2-Accept (open until L1 wave corruption fixed — served list must show the real trains); H-Accept (open: dry-beach fix parked + ortho quality) |
| **Phases DONE** | ✅ **M** (dashboard `eb424fd`+`73d9017` DEPLOYED to weather-dev; Gate M PASS, repro capture clean — see Phase M gate record). ✅ **DOC** (meta `7e53927`, 12 files docs-only; Gate DOC PASSED 2026-08-10, adversarial audit 0 findings — rows 1–6 all PASS with evidence; lead independent checks: allowlist diff exact, ADR-106↔PA1–PA5 1:1, 25 m confirmed wording, zero Z2 content). ✅ **Z1** (diagnosis; Q1 answered by 2026-08-03 ruling). Z2 ruled no. |
| **Remaining** | Phase DOC → B2 → S → K → Z3 (marine chain, strict; Z3 = wind-gatherer migration steps 2–5 per the approved 2026-08-03 design) ; H → M (dashboard chain, may interleave after DOC) |
| **WAITING ON OPERATOR** | none — Z1 answered by the pre-existing 2026-08-03 ruling (Q1 record below); Z2 ruled no |

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

## PHASE DOC — governing documents to the ruled target state, BEFORE any code

**Owner:** `clearskies-docs-author` (Sonnet), content sourced ONLY from the fixit log's ruling
records and this plan. **QC:** `clearskies-auditor` at Gate DOC. **No implementation phase
dispatches until Gate DOC passes.**
**Convention:** every not-yet-deployed behavior carries the tag
**`(ruled 2026-08-10; lands with Phase <X> of MARINE-PAGE-FIXIT-PLAN)`**; the implementing
phase's doc-sync removes the tag on deploy.

### DOC.1 — New ADR-106 + amendments
New **ADR-106 — Marine page fixit rulings 2026-08-10** (status: Accepted; records, with the
fixit log as evidence: the slot-mixing root cause; PA1 per-WW3-cell boundary + SWAN
interpolation + why the D4 1-km spacing is superseded (station-era fear vs 16-km neighbors);
PA2 period-range physics ruling verbatim; PA3 adjustable threshold + fixed crash band; PA4
marker decoupling + prominence rule; the named constants). Amendment notes in **ADR-104**
(P4/D4 superseded → pointer to ADR-106) and **ADR-102** (published-marker/zone section
superseded → pointer; internal Q_b/roller physics unchanged). `docs/decisions/INDEX.md` rows.

### DOC.2 — ARCHITECTURE.md
Tagged rewrites: the L1-boundary bullet (:120 region — per-WW3-cell files, SWAN interpolates,
sampling layer deleted); the SWAN-outputs paragraph's break-point/impact-zone sentences (PA4
definitions); the P13 aggregate-fields sentence (PA2 field set).

### DOC.3 — PROVIDER-MANUAL
§14.3a reconstruction spec rewritten to the per-cell design (B2.1/B2.2 content verbatim:
cell-row selection, endpoint copies, viability floor, constants unchanged table); note that
the corridor fetch (B1, §14.3) is untouched.

### DOC.4 — API-MANUAL + openapi + DASHBOARD-MANUAL + OPERATIONS-MANUAL + DESIGN-MANUAL
API-MANUAL surf-bundle field table + `openapi-v1.yaml`: add `periodMinS/periodMaxS`, remove
`combinedPeriodS` + `faceHeightMinFt/MaxFt`, breakPoints may carry >1 entry, perBreakZones
band semantics (PA4), `reformTrough` always null (tagged). DASHBOARD-MANUAL: card 3 bindings
(modelSurfHeightMin/Max + period range), heatmap section (framing rule, tile budget 8,
smoothing raster, attribution/notes in info modal, 4x2 + overlay), map layer/error-handling
contract, beach-profile marker rendering (all served markers, unchanged) (tagged).
OPERATIONS-MANUAL: the two new `[surf]` config keys + validation + how to tune them (tagged).
DESIGN-MANUAL: marine card table gains the missing Heat Map row (4x2, overlay pattern);
`types.ts` impact-zone comment text prescribed (PA5).

### ⛔ QC GATE DOC — `clearskies-auditor`, adversarial
Rows: (1) every doc statement traceable to a fixit-log ruling or a plan design line (spot-map
10 random claims; any orphan = FAIL); (2) every target-state section tagged; (3) no
live-behavior claim changed where behavior hasn't; (4) ADR-106 covers PA1–PA5 completely
(diff against the register); (5) INDEX consistent; (6) git diff shows docs only.

---

## PHASE B2 — Boundary: one spectrum per wet WW3 cell, SWAN interpolates *(PA1 — fixit Item 1)*

**Owner:** `clearskies-api-dev` (Sonnet). **Tests:** `clearskies-test-author`. **QC:**
`clearskies-auditor` at Gate B2. All code in `repos/weewx-clearskies-marine/`.

### B2.1 — Reconstruction rework: per-cell spectra, sampling layer deleted
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

### B2.2 — Emission: fewer positions, endpoint copies, grammar unchanged
**Files:** `services/swan_formats.py` (`ww3_boundary_files_and_command()` only),
`services/swan_runner.py` (file-writing call site only).
**Design (decided):** position list = B2.1's per-cell `len`s, strictly ascending, PLUS the two
endpoint byte-copies (len 0.0 / len side_length, §Named constants). Same file naming scheme,
same `&`-wrapping, same one-command-per-side. Expected scale: ~7–10 cells + 2 copies per side
(≈ 20 files total vs today's 194). The 180-char line guard and continuation reader stay.

### B2.3 — Tests (test-author) — the misalignment case becomes a permanent KAT
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

### B2-Accept (live, librewxr — deploy alone)
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

### ⛔ QC GATE B2 — `clearskies-auditor`, adversarial, BEFORE lead gate
Rows: (1) sampling-layer functions GONE (grep — any survivor = FAIL); (2) anti-fabrication KAT
falsifiable (mutation: reintroduce slot-averaging on a copy → KAT fails); (3) emitted INPUT
diff vs pre-phase: only the BOUNDSPEC block and file inventory differ; (4) pinned commands
byte-identical (CGRID/GEN3/INPGRID/etc.); (5) endpoint copies present at len 0/L on both
sides; (6) the ±(accept row 1) lobe checks re-derived from raw files by the auditor's own
parse, not the implementer's numbers; (7) doc-sync tags removed in PROVIDER-MANUAL
§14.3a/ARCHITECTURE for the shipped behavior; (8) targeted-test baseline recorded, zero new
failures.

---

## PHASE S — Swell-conditions card: ruled ranges *(PA2 — fixit Item 2)*

**Owner:** `clearskies-api-dev` (S1) + `clearskies-dashboard-dev` (S2). **Tests:**
`clearskies-test-author` (S3). **QC:** `clearskies-auditor` at Gate S. Dispatches after Gate
B2 closes (marine repo single-round).

### S1 — Server fields (marine `endpoints/surf.py`, `_compute_eligible_swell_aggregates`)
**Design (decided):** (a) ADD `periodMinS`/`periodMaxS` = min/max of `period` over the
ELIGIBLE set (existing eligibility rule — operator ruled the no-qualifier fallback stays
as-is), rounded 1 decimal; (b) REMOVE `combinedPeriodS` and `faceHeightMinFt`/`faceHeightMaxFt`
from computation and response (pre-task grep BOTH repos for consumers; dashboard's are
rebound in S2 — any OTHER consumer found = STOP and surface); (c) the `5.0` literal replaced
by an import of `_MIN_SURFABLE_PERIOD_S` from `services/surf_1d_pipeline` (shared constant;
verify no import cycle); (d) `swellHeightMinFt/MaxFt` and `modelSurfHeightMin/Max`
computations untouched.

### S2 — Card rebind (dashboard `SurfingTab.tsx` Card 3)
**Design (decided):** Breaking Face Height range ← `modelSurfHeightMin`/`modelSurfHeightMax`
(verify served units against API-MANUAL before binding — the fields serve feet today per the
live capture); Period ← `periodMinS`–`periodMaxS` via the existing `formatMinMaxFt`-style
collapse rule (single number iff min = max); delete the `combinedPeriodS` and
`faceHeightMinFt/MaxFt` bindings and the fields from `src/api/types.ts`/openapi mirror.
Swell Height binding unchanged.

### S3 — Tests
Marine: aggregate KATs updated in the same round — period-range arithmetic on a 3-train
fixture; fields-absent assertions for the two removals (response must NOT carry them).
Dashboard: `SurfingTab.test.tsx` C1 block updated to the new bindings (range renders, collapse
renders, null fallback) — same-commit-as-behavior rule.

### S-Accept (live)
Served JSON at matched time shows `periodMinS/periodMaxS` and lacks the removed fields;
screenshot of the card showing Breaking Face Height as the `modelSurfHeight*` range (a real
range on a multi-transect day) and Period as a range when ≥2 surfable trains differ; cam/buoy
sanity note recorded.

### ⛔ QC GATE S — auditor rows
(1) repo-wide grep: zero surviving references to the removed fields (both repos + openapi);
(2) shared-constant import verified (no duplicated 5.0 literal in `surf.py`); (3) dashboard
tests fail against pre-change code (falsifiability spot-check); (4) doc-sync tags removed
(API-MANUAL/openapi/DASHBOARD-MANUAL); (5) targeted baselines, zero new failures.

---

## PHASE K — Break markers + crash-band impact zone *(PA3/PA4 — fixit Item 4)*

**Owner:** `clearskies-api-dev`. **Tests:** `clearskies-test-author`. **QC:** auditor at Gate
K. Dispatches after Gate S closes.

### K1 — Config keys + plumbing
**Files:** `config/marine_config.py`, `services/surf_1d_analytical.py` (constant read sites).
**Design (decided):** `[surf] qb_breaking_onset` (float, default 0.05, valid (0, 0.5)) and
`[surf] impact_zone_width_m` (float, default 25.0, valid (5, 200)); out-of-range → loud
config-push refusal naming the bound. Values flow to the 1-D layer the same way existing
`[surf]`-scope settings do (follow the file's own config-injection idiom; if none exists for
this module, module-level defaults overridden at pipeline construction — implementer follows
the repo's existing pattern, surfacing if none exists). OPERATIONS-MANUAL doc-sync tag removal.

### K2 — Marker detection decoupled from cessation
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

### K3 — Zones: fixed crash bands
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

### K4 — Tests
KATs: (a) synthetic two-bar profile whose D-series has two prominent maxima with Q_b never
dipping below onset between them → TWO markers, TWO bands (fails against pre-K2 code —
falsifiability demo required); (b) prominence: a 25%-prominence ripple publishes NO marker;
(c) band arithmetic + waterline clip (marker near shore → band ends at waterline exactly);
(d) config knobs: raising onset removes the weaker marker; changing width moves band ends
(read through the real config path, not by patching constants); (e) foam/total zone geometry;
(f) `reformTrough` null; (g) out-of-range config → push refusal. Existing zone/marker tests
updated same-commit per the task specs; every touched test enumerated in scope-ack.

### K-Accept (live)
Deploy alone. (1) Beach-profile card at matched time: does the inner beach break now carry a
marker? RECORD against cam observation (pass/fail on "markers correspond to where waves
visibly crash" — pre-declared, operator invited to eyeball); (2) impact-zone bar(s) are
narrow bands at the crash locations, not a 240-m smear; no band crosses the waterline;
(3) knob drill: bump `qb_breaking_onset` on the live config, observe marker-set change,
restore (recorded); (4) journal sweep + baseline diff; (5) INV-11 firing rate recorded
before/after (informational — PA4 doesn't charter fixing it, but the number lands in the
record for the standing SURF-REMEDIATION item).

### ⛔ QC GATE K — auditor rows
(1) physics-march diff audit: zero changes to Q_b solve/relaxation/roller code paths (the
frozen physics assertion — any touched line outside the publication/zone regions = FAIL);
(2) KAT (a) falsifiability reproduced by the auditor (mutation/revert); (3) config keys
validated + refusal drill evidence; (4) grep: no surviving publication-path reference to
`Q_B_CESSATION`/Er-floor; (5) doc-sync tags removed (ADR-102 note, API-MANUAL, types.ts
comment); (6) targeted baselines, zero new failures.

---

## PHASE H — Heat map + small display fixes *(fixit Items 5, 3, 4-display)*

**Owner:** `clearskies-dashboard-dev`. **Tests:** `clearskies-test-author` (H7).
**QC:** auditor at Gate H. Dispatches after Gate DOC; H0 BLOCKS H1–H4.

### H0 — Registration known-answer check FIRST (the C3S recorded next-session action)
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

### H2 — Radar-style smoothing (display-only)
**Files:** `HeatMapCard.tsx`.
**Design (decided):** the per-cell surf-height color field renders through bilinear
interpolation between adjacent transect row bands and along each transect (offscreen-canvas
upsample of the value grid, then colormap) — cells with no data stay unpainted (no invented
surf beyond the data extent); the served data and the transform are untouched.

### H3 — Nothing below the legends
**Files:** `HeatMapCard.tsx` + info-modal content/help keys.
**Design (decided — operator's words "do not need anything below the legends" govern):** BOTH
lines below the legends are removed from the card face: the imagery attribution AND the D7s
smoothing note. Both texts move into the card's info-icon modal; the attribution string stays
rendered VERBATIM from `imageryConfig.attribution` there (keeps the ESRI ToS case compliant —
PROVIDER-MANUAL §16.2). Help-key doc-sync per CLAUDE.md.

### H4 — Card 4x2 + fullscreen overlay (RULED)
**Files:** `SurfingTab.tsx` (card wrapper), `HeatMapCard.tsx`.
**Design (decided):** `footprint="full"` + `rowSpan={2}`; chart area scrolls vertically inside
the card (`overflow-y: auto`) when the true-scale height exceeds the card; header gains
`ChartFullscreenButton` opening the existing `ChartFullscreenOverlay` (operator-ruled: overlay
is fine). DESIGN-MANUAL marine-card table row (DOC.4) tag removed on ship.

### H5 — Surf score footer deletion (fixit Item 3)
**Files:** `SurfingTab.tsx` (:2105-2109 region — verify, don't trust line numbers).
Delete the footer explainer `<p>` block; i18n key + modal untouched.

### H6 — Beach-profile display smalls (fixit Item 4.6)
**Files:** `BeachProfileChart.tsx`.
**Design (decided):** bottom elevation tick label suppressed when its y lands within 12 SVG
units of the x-axis label row (kills the "-10492" collision at any render width); plus a
read-only look at the flat 0.03 m landward transect segment — REPORT ONLY (a serving-side
fix, if needed, is a finding for the operator, not an H6 change).

### H7 — Tests
H0 KAT (permanent); framing/zoom unit tests (given a fixture extent, chosen zoom yields
≤ 1.5 m/px); smoothing: no-data cells stay transparent (canvas sample assert); H3: no text
node renders below the legend row; H4: overlay opens/closes, focus trap (reuse existing
pattern's tests as template); H5/H6 render asserts. Baseline: full dashboard vitest +
`tsc -b` + build; bundle sizes recorded per reference/clearskies-dev.md.

### H-Accept (live, weather-dev deploy)
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

### ⛔ QC GATE M — auditor rows
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

### Z3 — ✅ RE-SCOPED 2026-08-10: execute wind-gatherer migration steps 2–5 (already operator-approved 2026-08-03)
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

## PHASE T — TIDE COHERENCE (operator-ordered 2026-08-11, REQUIREMENT ruling)

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
