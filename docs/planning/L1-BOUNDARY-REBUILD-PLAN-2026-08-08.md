# L1 Boundary Rebuild Plan — island-aware sizing + partition-reconstruction boundary (2026-08-08)

**Created:** 2026-08-08 (operator-directed, in chat: "granular tasks, all design done now and not
left for agents, qc gates, agent assignments").
**Status:** ACTIVE — execution begins on operator go (see "Relationship to other live plans").
**Authority:** [briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md](briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md)
— brief COMPLETE, rulings **D1–D13** all operator-issued 2026-08-08. Facts, citations, and the
ruling record live in the brief; this plan does not restate them.

**THIS PLAN IS THE ARCHITECTURAL PERMISSION.** Operator, 2026-08-08 chat: *"The plan serves as
permission for architectural changes, so if it is in the plan, it is allowed."* The
**Pre-approval register** below enumerates every authorized architectural change,
trigger-by-trigger. A change NOT in that register remains under the CLAUDE.md HARD BLOCK — the
agent STOPs and reports; the coordinator takes it to the operator. The register is the ONLY
in-plan grant.

**Relationship to other live plans:** independent of
[SURF-REMEDIATION-PLAN-2026-08-08.md](SURF-REMEDIATION-PLAN-2026-08-08.md) (R5 touches
`endpoints/surf.py` / `endpoints/beach_profile.py`; this plan touches neither) and of
[MARINE-FORWARD-PLAN.md](MARINE-FORWARD-PLAN.md) open rows. Phases here may interleave with
those plans' rounds, but **this plan's own phase order is strict** (below) and each phase's QC
gate closes before the next phase dispatches.

---

## PRIME DIRECTIVE — carried over from MARINE-FORWARD-PLAN, binding on every task

1. **Frozen core is OFF LIMITS unless a task's Files list names the exact file:**
   `surf_1d_analytical.py`, `surf_1d_pipeline.py`, `transect_handoff.py`, `swelltrack_cache.py`,
   `invariants.py`, `breaker_height.py`, the spot-level `dominant_pbi` block
   (`beach_profile.py:495-528`), wave shapes/jacking, L2/L3/L4 sizing and physics, hotstart
   mechanics, the convergence gate, the serve-nothing guard, `endpoints/surf.py` and
   `endpoints/beach_profile.py` (R5's scope — **EXCEPT the exact sections Phase C names, and
   only after R5 closes**), `omp_num_threads = 6` (operator ruling), and the
   **spectral grid `CIRCLE 72 0.03 1.0 34`** — a directional-resolution increase is NOT in this
   plan (see PINNED).
2. **Baseline before, diff after** every deploy (facing, DWR Hs, valid_fraction, publish size,
   cycle wall-clock, L1 dims). rules/coordinator.md §7.
3. **One functional change per deploy.** The phase order below exists so each deploy is one
   comparable change.
4. **Reality gate on every deploy** (rules/verification.md §"Marine deploy verification"):
   matched-time comparison vs NDBC 46222/46253/Surfline/cam within one cycle, quantities chosen
   before looking; publish-liveness.
5. **Stale tests → STOP and surface** (rules/agents.md stale-test block, verbatim in every
   brief). This plan deletes named test files (B5, G8); ONLY those named may be deleted, each
   listed in the closeout.
6. **Agent discipline:** every implementation task runs on a Sonnet agent with a written brief
   containing the rules/agents.md mandatory blocks (git, stale-test, architectural) + scope-ack
   before code + adversarial `clearskies-auditor` pass BEFORE the lead gate + doc-sync in the
   same round.
7. **Line numbers are hints, not gospel.** First action of every agent: verify quoted state;
   drift → STOP and report.
8. **No silent fallbacks, no flagging apparatus** (operator rulings, 2026-08-08): missing DATA
   → refuse loudly with the reason (setup-time where structural, cycle-abort where transient).
   Constrained GEOMETRY → best physical answer, silently (D11). Never a fabricated default,
   never a report in lieu of the best achievable behavior.

**Execution order (strict for the model chain):
Phase DOC → Phase W → Phase B → Phase G → Phase S → Phase A → Phase V.**
**Phase DOC precedes ALL coding work (operator instruction, 2026-08-08: "an initial phase to
update all docs including architecture, manuals, ADRs, etc PRIOR to any coding work").**
**Phase C (surf-card display correctness, added by operator 2026-08-08 mid-planning) is
independent of the model chain and may interleave at any point — but dispatches only AFTER
the SURF-REMEDIATION R5 round closes** (shared files: `endpoints/surf.py`,
`BeachProfileChart.tsx`).
Rationale (a sequencing decision of this plan): **B lands the reconstruction boundary at the
CURRENT L1 extent first** — same grid, new boundary source, directly comparable against the
station-boundary baseline; **G then moves the grid** and the reconstruction adapts to any
extent automatically. Landing G first would strand the station selector at an extent with zero
qualifying stations (brief §5) and conflate two changes in one accept. W precedes everything
because an extended grid on today's wind path would silently run becalmed at its offshore edge
(brief §6). S is independent of B/G but ships as its own deploys; A needs S's and G's config
surfaces to exist; V closes the whole plan.

---

## PRE-APPROVAL REGISTER — the architectural changes this plan authorizes (and no others)

| # | Change | Trigger(s) | Ruling |
|---|--------|-----------|--------|
| P1 | Ocean fetch-fan horizon decoupled from shelf distance; fixed 100 km scan cap `L1_MAX_EXTENT_KM` | 1, 3 | D1, D2 |
| P2 | L1 offshore extent: island enclosure to `open_water_resume + 10 km` (≤ cap); near-lee clamp `W/(2·tan 15°)`, k=1 | 1, 3 | D1, D11 |
| P3 | New config key `[swan] l1_offshore_extent_km` (operator override, admin-exposed) | 7 | D1 |
| P4 | L1 boundary data contract: per-station `.spec` spectra REPLACED by per-L1-cell spectra reconstructed from gridded WW3 partition fields (ocean gfswave 0p16 + GLWU 2.5 km), spacing = L1 cell (1 km) | 2, 4 | D3, D4 |
| P5 | DELETE `services/ww3_station_selection.py`, `services/ww3_station_catalogue.py`, `data/ww3_station_catalogue.json`, and the station-fetch half of `services/ww3_spectrum.py` (the Appendix-D spectrum writer is extracted and kept) | 2 | D3 |
| P6 | Wind fetch bbox derived from the L1 domain (replaces spot ±1.0°); wind/current out-of-coverage silent fills replaced by cycle-abort raises; new no-publish slug `wind_coverage_failed` | 4, 5 | D5, D6 |
| P7 | New provider: RTOFS surface currents; current-source selection rule = OFS-if-domain-contained else **RTOFS + STOFS-velocity composite** (RTOFS is non-tidal; STOFS's tidal/surge velocity is summed in so every service-area region gets the COMPLETE current — designing for the service area, not the test case; operator directive 2026-08-08) | 2, 4, 7 | D9 + operator directive |
| P8 | New provider: STOFS-2D-Global water level; WLEVEL source chain = STOFS → CO-OPS-uniform (loud) → refuse; spatially-varying WLEVEL grid at all levels | 2, 4, 7 | D10 |
| P9 | Datum branch: tidal-offset conversion (CO-OPS `datums` product) for VDatum-less tidal-referenced regions (Hawaii); NAVD88 source there → refuse | 1, 2 | D13 |
| P10 | Setup-time per-input source/coverage report surfaced through config chain → admin | 4, 7 | D5 |
| P11 | Service area = CONUS + Great Lakes + Hawaii (AK/territories descoped, matrix kept) | — | D7, D12 |
| P12 | DEM index refresh: add Maui + Big Island (+ optionally PR, low priority) entries | 7 | D12/D13 |
| P13 | Surf response gains card-aggregate fields (`swellHeightMinFt/MaxFt`, `faceHeightMinFt/MaxFt` recomputed over eligible swells, `combinedPeriodS`) — additive wire-shape change, eligibility rule server-side | 4 | operator, 2026-08-08 chat (swell-card instruction) |
| P14 | Beach-profile chart draws the DOMINANT swell's wave train only (display; consumes R5's dominant-partition serving) | — (display) | operator, 2026-08-08 chat (beach-profile instruction) |
| P15 | Surf-height heatmap: ortho imagery rotated to the transect/beach frame, 50 m ortho buffer, y-axis labels, structure-affected-area overlay REMOVED (display-only; structure physics stays in SWAN L4) | — (display) | operator, 2026-08-08 chat (heatmap instruction) |

Named constants fixed by this plan (not re-derivable by agents): `L1_MAX_EXTENT_KM = 100.0`,
enclosure margin `10.0 km` (reuses the existing offshore-margin convention), near-lee
`SIGMA_THETA_REF = 15°`, `K_FILL = 1`, swell spread `σθ = 15°` (cos^2s s = 28), wind-sea
spread `σθ = 30°` (s = 7), swell frequency shape Gaussian `σf = 0.015 Hz`, wind-sea shape
JONSWAP `γ = 3.3`, boundary point spacing = L1 `dx` (1 km), wind bbox pad `0.3°`, STOFS
cutover bias gate `≤ 0.15 m`. Two constants are **measured then pinned** (method decided here,
value measured at implementation, bounded): B2's `r` (wind-sea mean→peak period ratio, bounds
[1.10, 1.35], measured vs 3 live `.spec` cycles) and S1's RTOFS endpoint choice (NOMADS grib
primary, ERDDAP griddap alternate — pinned after one live shape check). Out-of-bounds
measurement → STOP and surface, do not pick.

---

## SWAN SYNTAX PRESCRIPTIONS — pre-researched from the LOCAL manual, binding on every phase

*(Operator instruction 2026-08-08: "all SWAN syntax is pre-researched now in the plan and
prescribed, as this is an area of constant failure." Sources: `docs/reference/swan-user-manual.txt`
(v41.51 — line cites below), `docs/reference/swan-commands-extract.md`, PROVIDER-MANUAL §14.15
"Measured deviations of the deployed SWAN binary (41.51AB)". Agents implement EXACTLY this
grammar; a mismatch between this section and the manual is a finding to surface, never a
license to improvise. Downloading SWAN documentation is forbidden — the manual is in-repo.)*

### 1. Boundary command (Phase B3) — the ONLY new command grammar this plan introduces

One command per offshore side, exactly:

```
BOUNDSPEC SIDE <W|S|E|N> CCW VARIABLE FILE <len_1> 'B_<side>_<0001>.txt' 1 <len_2> 'B_<side>_<0002>.txt' 1 ...
```

- Grammar: manual :2380-2410 (`BOUndspec … SIDE … CCW … VARiable FILE < [len] 'fname' [seq] >`).
- `[len]` = distance from the side's CCW begin point, **in metres** (L1 is `COORDINATES
  CARTESIAN`/UTM since F1-proj) — manual :2507-2513 "[len] is the distance in m or degrees in
  the case of spherical coordinates". The 2026-08-01 R5 defect (degrees emitted into a metres
  frame, boundary collapsed to a corner) is the standing proof this line is load-bearing.
- `[len]` values **strictly ascending** per command (manual :2513-2514).
- `[seq] = 1` on every file (each file carries exactly one location; manual :2559-2563).
- CCW begin corners (rectangle walked SW→SE→NE→NW): **S begins SW** (len grows east),
  **E begins SE** (grows north), **N begins NE** (grows west), **W begins NW** (grows south).
  S and W are live-run-verified; N/E are derived from the same walk and are confirmed at the
  first N/E-fed deployment by "Normal end of run" + zero boundary warnings (SWAN rejects
  mis-ordered `[len]` outright — the check is structural, not hopeful).
- One point per L1 boundary cell (D4): `len_i = (i + 0.5) × dx` is NOT used — points sit AT
  cell-corner grid points `len_i = i × dx`, i = 0…N (SWAN computes boundary spectra at its
  own boundary grid points; supplying them exactly there eliminates along-side interpolation,
  manual :2480-2485).
- **FORBIDDEN, never emitted:** `BOUNDSPEC … PAR` (CONSTANT or VARIABLE — operator-rejected
  contract), TPAR files, `BOUND SHAPE` (meaningless when full 2-D spectra are supplied; its
  JONSWAP default must never silently shape anything), `BOUNDNEST2/3`. `BOUNDNEST1 NEST
  'nest_in.dat' CLOSED` remains the L1→L2/inner mechanism exactly as emitted today
  (`swan_formats.py` nest block — untouched by this plan).

### 2. Boundary spectrum file grammar (Phase B2 writer) — SWAN Appendix D, 2-D, nonstationary

Template (manual :7028-7031 header rule; :7041-7110 TIME/QUANT blocks; :7169-7306 2-D layout):

```
SWAN   1
$ Clear Skies partition-reconstruction boundary
TIME
     1
LOCATIONS
     1
  <x_utm>  <y_utm>
AFREQ
    35
  <f_1> … <f_35>
NDIR
    72
  <θ_1> … <θ_72>
QUANT
     1
VaDens
m2/Hz/degr
  -0.9900E+02
<yyyymmdd.HHMMSS>
FACTOR
  <factor>
<35 rows × 72 integer columns>
… (next timestep: date line, FACTOR, matrix — repeated for every step)
```

- First line literally `SWAN   1` (file-recognition keyword, manual :7029-7031).
- `TIME` + coding option `1` = nonstationary (manual :7049-7051); one date line
  `yyyymmdd.HHMMSS` per timestep, strictly increasing, spanning the full computation window
  `[TSTART, TEND]` (ocean product: 3-hourly steps f000–f072; GLWU: hourly).
- `LOCATIONS` (Cartesian) with the point's UTM coordinates — **coordinates are read but
  IGNORED for placement; geographic position comes from `[len]` in the BOUNDSPEC command**
  (manual :2555-2557). They are still written truthfully for debuggability.
- `AFREQ` (absolute frequencies — no ambient current at the offshore boundary) = exactly the
  CGRID ladder: **35** log-spaced values 0.03→1.0 Hz (msc=34 ⇒ msc+1 = 35 frequencies, manual :1532/:3719; live-verified 2026-08-09 against the deployed binary's own SPECOUT `AFREQ / 35`; `swan_formats.py` gamma ≈ 1.1086; plan originally mis-transcribed this as 34 — corrected by coordinator ruling during B2)
  so SWAN performs NO spectral-grid interpolation of our boundary.
- `NDIR` = 72 nautical directions (coming-from, degrees, clockwise from true north — manual
  "Units and coordinate systems"; the in-repo convention proof chain is
  PROVIDER-MANUAL:2344-2363: WW3→SWAN needs only the `(deg+180)%360` from/to flip where the
  source is going-to). **Direction-convention pin for the GRIB2 partition fields:** B2 adopts
  the identical convention handling `providers/marine/wavewatch.py` already applies to
  SWDIR/WVDIR/DIRPW for the forecast cards (live-verified), cross-checked once against a
  same-cycle station `.spec` before the constant `r` is pinned — the two independent sources
  must agree on direction to within 15° or B2 STOPs and surfaces.
- `QUANT 1 / VaDens / m2/Hz/degr / -0.9900E+02` — variance density, NOT `EnDens` (true-energy
  J/m²/Hz/degr — manual :7395-7396); exception value written but never used by our writer.
- Per-timestep `FACTOR` block: matrix values are integers; real density =
  `integer × factor` (manual :7276-7306). Factor per timestep =
  `max_density / 990000` (six-significant-digit headroom), zero-energy timestep → `FACTOR`
  `1.0` + all-zero matrix (never the `NODATA` keyword — a calm boundary is data).
- **Matrix orientation: frequency-major** — 35 rows (one per frequency), 72 columns (one per
  direction), matching SWAN's own SPECOUT layout; the writer is kept as the structural mirror
  of `swan_spectral.py::parse_specout_file` (live-verified). NOTE the documented trap: NOAA's
  station `.spec` files are DIRECTION-major (PROVIDER-MANUAL:1356, the 24%-Hs bug) — that
  layout must never leak into files we EMIT.

### 3. Commands PINNED UNCHANGED (regression protection — byte-identical emission)

`CGRID REG … CIRCLE 72 0.03 1.0 34` (`swan_formats.py:1663-1664`); `INPGRID BOTTOM … EXCEPTION`
+ `READINP BOTTOM` (:1667-1681); `INPGRID/READINP WIND … NONSTAT` (:1708-1710); `INPGRID/READINP
WLEVEL … NONSTAT` (:1720-1726 — Phase S2 changes the VALUES in `WLEVEL.txt`, never the command
grammar); `INPGRID CURRENT REG … / READINP CURRENT 1. 'CURRENT.txt' 3 0 FREE` (:1728-1736 —
same: values only); `GEN3 ST6 … SSWELL ZIEGER 0.00025 / NEGATINP 0.04` (L1) and `GEN3
WESTHUYSEN` (L2+) physics blocks; `INIT HOTSTART 'hotstart.dat'` **keyword-less form — measured
accepted by the deployed 41.51AB binary** (PROVIDER-MANUAL §14.15); `NESTOUT`/`BOUNDNEST1`
nest chain; OBSTACLE emission. Gate rows in B and G include an INPUT-file diff: only the
BOUNDSPEC block and grid-extent numerals may differ from the pre-phase INPUT.

### 4. Deployed-binary deviations that bind accept tooling (PROVIDER-MANUAL §14.15)

PT* table output carries **6 columns per keyword, not the manual's "at most 10"**; `PTDIR`'s
exception value is `-999` while every other PT* uses `-9`; **absent partition slots at wet
points are `0.00000`, never a sentinel** (parse with the `HsPT0k ≈ 0` primary-absence rule,
`12f9ddc`); individual partition indices cannot be requested (`PTHSIGN` block only). Any
accept-phase comparison that reads `TABLE_1.txt` PT* columns follows these, not the manual.

## PHASE DOC — Governing documents updated to the ruled target state, BEFORE any code

**Owner:** `clearskies-docs-author` (Sonnet), content sourced ONLY from the brief and this
plan — no invented detail. **QC:** `clearskies-auditor` at Gate DOC. **No implementation
phase dispatches until Gate DOC passes.**

**Convention (decided):** every section describing not-yet-deployed behavior carries the tag
**`(ruled 2026-08-08; lands with Phase <X> of L1-BOUNDARY-REBUILD-PLAN)`**. The implementing
phase's own doc-sync REMOVES the tag on deploy. Docs therefore lead the code without ever
claiming unshipped behavior is live (doc-truth discipline preserved; H3-style sweeps stay
meaningful).

### DOC.1 — New ADR + amendments  ✅ (2026-08-08, meta `9dc1fe3` — shipped as **ADR-104**; the "ADR-101" number below was a stale placeholder, ADR-101/102/103 already existed. ADR-103 also amended — it documents the station path Phase B deletes.)
New **ADR-101 — Island-aware L1 sizing and partition-reconstruction WW3 boundary** (status:
Accepted — records operator rulings D1–D13 with the brief as evidence; captures: horizon
decoupling + 100 km cap + near-lee criterion with ratified constants; boundary contract
(per-L1-cell reconstruction, spacing = L1 dx); wind region sourcing; RTOFS/STOFS adoption;
Hawaii tidal-offset datum branch; service area CONUS+GL+HI; no-silent-fallback vs
best-achievable-geometry distinction). Amendment notes in **ADR-093** (L1 boundary/inputs)
and **ADR-100** (horizon no longer shelf-derived; enclosure to island far edge) pointing to
ADR-101. `docs/decisions/INDEX.md` row added. Format per rules/clearskies-process.md.

### DOC.2 — ARCHITECTURE.md  ✅ (2026-08-08, `9dc1fe3` — tagged bullets inside the :98-129 GEOMETRY MODEL blockquote; the plan's :108/:118/:122 hints are three points inside ONE blockquote, structure preserved)
Rewrite the three affected regions to the target state (tagged): the L1 sizing paragraph
(:108/:118 region — autosizing, cap, near-lee, override key), the boundary paragraph
(:122 region — reconstruction replaces station selection; deleted modules named), the SWAN
inputs paragraph (wind bbox from domains; WLEVEL chain STOFS→CO-OPS; current source
OFS-contained→RTOFS; no silent fills; new no-publish slug), service-area statement (D7/D12).

### DOC.3 — PROVIDER-MANUAL  ✅ (2026-08-08, `9dc1fe3` — §14.3a/b tagged superseded-pending-deletion + reconstruction spec; new §14.10a RTOFS, §14.13a STOFS; §14.12 note; §14.14 D8 wind sourcing)
§14.3a rewritten as the reconstruction spec (B1/B2 design verbatim — constants, eligibility
of wet cells, guard); new RTOFS-currents and STOFS-wlevel sections (products, cadences,
selection rules, non-tidal/tide-only caveats); §14.12 RTOFS-role note; wind region sourcing
(D8); station-path sections marked superseded-pending-deletion (tag).

### DOC.4 — API-MANUAL + openapi + DASHBOARD-MANUAL + OPERATIONS-MANUAL  ✅ (2026-08-08, `9dc1fe3` — P13 fields tagged Phase C, `wind_coverage_failed` §19.7 tagged Phase W, C2/C3 tagged, admin panel/override tagged Phase A/G. Pre-existing openapi drift logged in session scratch, untouched.)
P13 card-aggregate fields (API-MANUAL data model + `openapi-v1.yaml`, tagged); C2/C3 display
behavior (DASHBOARD-MANUAL, tagged); admin sources panel + override field (OPERATIONS-MANUAL
+ help-key inventory list, tagged); new no-publish slug in API-MANUAL §19.7 (tagged).

### ⛔ QC GATE DOC — `clearskies-auditor`, adversarial — **PASSED 2026-08-08** (blind audit of `9dc1fe3`: 7/7 rows with auditor's own evidence — 10-claim spot-map zero orphans, 28 tags all placed, no live-claim rewrites, D1–D13 + constants verbatim, INDEX consistent, docs-only stat, ADR-104 numbering correct. 0 findings. Lead independently verified commit stat vs allowlist + ADR-104 content spot-check.)
Rows: every doc statement traceable to a brief ruling or a plan design line (auditor
spot-maps 10 random claims back to source — any orphan = FAIL); every target-state section
tagged; no live-behavior claim changed where behavior hasn't; ADR-101 decision list is
D1–D13-complete (auditor diffs against the brief §8); INDEX.md consistent; zero code changes
in the round (git diff shows docs only).

## PHASE W — Wind & current input hardening *(D5/D6 — prerequisite for everything)*

**Owner:** `clearskies-api-dev` (Sonnet). **Tests:** `clearskies-test-author`. **QC:**
`clearskies-auditor` at Gate W. All code in `repos/weewx-clearskies-marine/`.

### W1 — Wind bbox derived from the L1 domain  ✅ (marine `f7c2b04` W1–W4 combined; live bbox verified in journal at W-Accept)
**Files:** `config/marine_config.py` (`_HRRR_MARGIN_DEG`, `hrrr_bbox` at :1036, :1112-1117),
`service.py` (:335-341, :422), `services/wind_gatherer.py` (`_bbox_for_locations`, :468-480),
`providers/nearshore/swan.py` (`outer_bbox` use, :2666, :2691, :2726).
**Design (decided):** new `wind_fetch_bbox(domains) -> tuple` in `config/marine_config.py`:
L1 bbox from the sizing cache padded `0.3°` on every side (covers one GFS 0.25° cell + slack;
HRRR 3 km ≪). All four call sites route through it. No sizing cache → the existing
`no_grid_sizing_cache` abort (no new path). The spot ±1.0° arithmetic is deleted at all three
duplication sites. `outer_bbox` keeps its name; its VALUE becomes domain-derived.

### W2 — Kill the calm-fill: out-of-coverage wind aborts  ✅ (marine `f7c2b04`)
**Files:** `services/swan_formats.py` (:386-388 NaN→`0.0000`), `providers/nearshore/swan.py`
(catch + no-publish), `state.py` (slug registry).
**Design (decided):** `hrrr_to_swan_wind()` raises new `WindCoverageError` (message: offending
cell count, first offending lat/lon, wind-grid bounds vs CGRID bounds). Runner catches →
no-publish slug **`wind_coverage_failed`** (14th instrumented exit; extends H1's registry —
doc-sync API-MANUAL §19.7 in the same round). The NaN branch is deleted, not conditioned.

### W3 — Fetch-time wind coverage assert (fail fast)  ✅ (marine `f7c2b04`; criterion corrected to require-L1-exactly in `95abc74` after live firing — see GATE EVENT in session handoff + Gate W record)
**Files:** `providers/nearshore/swan.py` (post-fetch, before SWAN input build).
**Design (decided):** after wind fetch/stitch, compare the blended field's bounds vs the L1
bbox (+ pad). Shortfall → same `WindCoverageError`/slug BEFORE any SWAN work. This makes W2's
runtime raise a defense-in-depth backstop, not the primary detector.

### W4 — Current zero-fills become aborts  ✅ (marine `f7c2b04`)
**Files:** `services/swan_runner.py` (`_write_current_txt`, :2407-2459).
**Design (decided):** unmatched timestep (no OFS entry within 2 h) or U/V grid shape short of
`(myc+1)×(mxc+1)` → raise `CurrentCoverageError` → existing `currents_fetch_failed` slug. The
`_ZERO_BLOCK` and row/col `0.0000` padding are deleted. (OFS 3-hourly × wind hourly ⇒ nearest
within 1.5 h always exists when the fetch succeeded — the raise fires only on genuine holes.)

### W5 — Tests (test-author)  ✅ (test commits `35f98f6`/`9cb1b43` + F1 remediation fixtures `6ab1df0`/`84f4757`; final 139 tests pass lead-reproduced — see Gate W record)
KATs: (a) wind grid one cell smaller than CGRID → `WindCoverageError` naming the count; (b)
fetch-time assert fires on undersized bbox; (c) current timestep gap → raise; (d) shape
mismatch → raise; (e) regression: full existing suite on librewxr, 0 new failures vs baseline
(record baseline commit + counts in the round record).

### W6 — Read the HRRR wind-grid rotation properly (operator-ruled 2026-08-09, Q3) ✅ **CLOSED — code `70d442f` lead-verified (12 KATs, falsifiability 9/12 reproduced); DEPLOYED proc 05:23:23Z; W6-Accept PASSED 2026-08-09 06:15Z**
**W6-Accept record (lead, all numbers from fresh commands):** (1) Lambert WARNING: **188
occurrences** in the pre-deploy window (03:12–05:23Z) → **0** since deploy — gone. (2)
Matched-cycle wind diff: the live post-deploy run consumed HRRR t04z — the same cycle as
the committed fixture at the identical live bbox; computed rotation field on it:
**mean −12.74°** (min −13.18, max −12.31, spread 0.87° across the box) vs predicted
−12.75°; pre-fix was identically 0° (no-op). Served matched-valid-hour diff (03:17Z run
vs 05:27Z run, 6 common hours): break height −1%…−8%, at-break direction within ~2°
except one dominant-partition switch at 00Z. Deep-water catalog at 06Z: groundswell
UNCHANGED (0.551→0.556 m, 18.2 s, 200.0° — swell boundary untouched, as designed);
wind swell re-aimed 269.7°→275.2° (+5.5°, the rotation propagating through SWAN). (3)
Journal sweep: zero new WARNING/ERROR classes (all present pre-deploy; INV-11 the known
health reason). (4) Reality gate (pre-declared ±25% Hs): combined deep Hs
√(0.67²+0.556²)=**0.87 m vs 46222 0.8 m (+9%) / 46253 0.9 m (−3%)**; period 18.2 s vs
buoy DPD 17 s; buoy MWD noisy (46253 swung 184°→157° in 30 min), groundswell 200°
recorded against it without a pass/fail claim. Cycle wall-clock 05:23→06:00:56 ≈ 37.5 m.
**Operator ruling (chat):** "Yes we want that fixed so we are reading it properly and not
estimating based upon wobble we are causing because it is not reading properly."
**Files:** `providers/wind/hrrr.py` (the Lambert-parameter extraction that currently
fails with "could not extract Lambert Conformal parameters" every fetch, and
`_rotate_wind_field`'s approximation fallback).
**Design (decided):** diagnose WHY eccodes fails to read LoV/Latin1/Latin2 from the
fetched GRIB2 (key names/subregion handling), fix the extraction so rotation uses the
file's own projection metadata + per-point longitudes (the exact `lons_2d` path that
already exists); the lon_first/lon_last approximation remains only as a last-resort
fallback that now logs at ERROR (it should never fire). If the filtered files genuinely
do not carry the projection metadata → STOP and surface (hardcoding HRRR's published
constants is an operator decision, not a fallback). KAT: extraction succeeds on a
recorded GRIB2 fixture; property test: two different fetch areas covering L1 produce
identical rotated wind at the same L1 points (bbox-independence — the "wobble" gone).
Accept: the WARNING disappears from the journal post-deploy; one matched-cycle
before/after wind diff recorded. **Dispatches after Gate B closes** (keeps the marine
repo single-round).

### W-Accept (live, librewxr)  ✅ **RECORDED 2026-08-09 01:30Z** (deployed `95abc74`, proc 00:41:16Z; accept cycle 18z rerun 00:42:16→01:19:00Z = 36m44s vs 37m41s baseline)
1. **WIND.txt byte-identity: FAILED-as-worded, root-caused, accepted as inherent.** Baseline md5 `fb2e0e52…`/1,120,722 B vs post `bc276709…`/1,122,704 B; matched-hour headline −5.3% (face 1.089→1.031 m). Cause: `hrrr.py::_rotate_wind_field` approximates per-column lon from the FETCHED grid's `lon_first/lon_last` (eccodes Lambert-param extraction fails, pre-existing WARNING), so the registered P6 bbox change inherently shifts every rotation angle a fraction of a degree; tighter L1-centered box = MORE accurate approximation. Wind-sea day (3.5–4.6 s) = maximal sensitivity. The plan's byte-identity assumption didn't account for this. Deviation recorded, not a defect.
2. **Forced drill: PASSED via REAL firing** (00:34:28Z, first post-deploy cycle, before the W3 criterion fix): `/health` degraded + full-bounds `wind_coverage_failed` reason, last-good preserved (200, prior headline served), loud 300s retry, recovery after fix redeploy. Firing exposed the assert wrongly requiring L1+pad coverage — fixed `95abc74` (require L1 exactly, C-90 pattern; mutation-verified call-site KAT).
3. **Baseline diff:** wall-clock −57s; L1 dims unchanged (1064 cells); publish live (lastRunTime 00:44:23Z); new fetch bbox live-verified in journal URLs = L1+0.3° exactly as designed.
4. **Reality gate (pre-declared: model DWR combined Hs vs nearer buoy ±25%):** model 0.62 m vs 46253 0.9 m (−31%), 46222 0.8 m (−22%); dominant period 17.5 vs 17 s ✓; direction 202° vs 167/161° (~35–40° gap in the island-shadow window). = the documented PRE-PLAN boundary defect (swell source untouched by W); stands as the "before" measurement for V1/V2.
5. Journal sweep: zero new ERROR/WARNING classes. `/health` reason `invariant fired: 11:roller_closure_within_one_percent` = the known INV-11 noise (open operator item from SURF-REMEDIATION, pre-existing).
Deploy alone. (1) Matched cycle: `WIND.txt` byte-identical to pre-deploy same-cycle rebuild
(current extent ⇒ zero behavior change intended); (2) forced drill: temporarily configure an
undersized test bbox on a scratch config → loud abort with `wind_coverage_failed` in
`/health` reasons, last-good preserved, recovery next cycle (H1 drill pattern); (3) baseline
diff table per PRIME DIRECTIVE 2.

### ⛔ QC GATE W — `clearskies-auditor`, adversarial, BEFORE lead gate — **PASSED 2026-08-09** (blind audit of `f7c2b04`+`35f98f6`+`9cb1b43`: 6/7 rows PASS with mutation evidence, F1 MEDIUM-HIGH accepted → remediated `6ab1df0`/`84f4757` (quick-update path wiring + 5 fixture repairs incl. one false-positive test) → re-audit 4/4 rows PASS, mutation-verified. Then live W3 firing → criterion fix `95abc74` (require L1, not L1+pad). Final: 139 tests pass, lead-reproduced. W1–W5 all ✅: marine `f7c2b04` `35f98f6` `9cb1b43` `6ab1df0` `84f4757` `95abc74`; meta `96070c2` `5870b45`.)
Rows: W1 all four call sites route through the new function (grep for surviving ±1.0
arithmetic = FAIL); W2/W4 fills deleted not conditioned (mutation test: reintroduce NaN → KAT
catches); W3 fires before SWAN input build (code order verified); slug visible in `/health`;
doc-sync landed; pytest baseline delta = 0.

---

## PHASE B — Partition-reconstruction boundary at the CURRENT extent *(D3/D4)*

**Owner:** `clearskies-api-dev` (Sonnet). **Tests:** `clearskies-test-author`. **QC:**
`clearskies-auditor` at Gate B. Brief §5 is the design record; SWAN behavior questions go to
the LOCAL manual only (`docs/reference/swan-user-manual.pdf` + `swan-commands-extract.md`) —
downloading SWAN docs is forbidden (reference/clearskies-dev.md).

### B1 — Gridded partition-field fetcher  ✅ (marine `10c8d70` — live-verified vs real NOMADS both products; GLWU pinned to filter_glwu.pl; found+fixed 0..360 longitude convention defect)
**Files (new):** `services/ww3_partition_fields.py`. **Reuse:** `providers/_common/http.py`
client + rate limiter; `grib_processor.py` eccodes backend; the ≥9998 missing guard
(PROVIDER-MANUAL §14.3 conventions); GLWU hourly-cycle fallback idiom from
`select_boundary_stations_with_cycle_fallback` (retire the module, keep the idiom).
**Design (decided):** fetch, per forecast step, the corridor bbox = L1 bbox + one native WW3
cell pad, fields `WVHGT/WVPER/WVDIR`, `SWELL/SWPER/SWDIR` seq 1–3, `HTSGW` (validation only).
Ocean: NOMADS `filter_gfswave.pl`, product `gfswave.tCCz.global.0p16`, f000–f072 3-hourly
(same CGI family §14.3 already uses). GLWU: NOMADS glwu filter if present, else `.idx`
byte-range subset of `glwu.grlc_2p5km` — both named; pin after one live check (bounded
decision). Product routing by L1-centre region (`classify_region`, same rule the station path
used). Any missing field/step → raise (`BoundaryNotViableError` retained as the type; new
message).

### B2 — Reconstruction module  ✅ (marine `f81e520` + r-pin `5ebc1fa`; AFREQ corrected to 35 by coordinator ruling; r=1.0 operator-ruled; bin-sum identity exact on smoke; direction convention live-confirmed 2.4°/2.5°)
**Files (new):** `services/boundary_reconstruction.py`. **Files (modified):**
`services/swan_formats.py` (extract the Appendix-D 2-D spectrum writer from
`ww3_spectrum_to_swan_boundary` into a shared `write_swan_2d_spectrum_file()`; direction
convention: WW3 grib directions are nautical; SWAN files use nautical coming-from — apply the
documented `(deg+180)%360` flip ONLY where the source is going-to; verify per-field
`DIRPW/SWDIR` convention against one `.spec` station cross-check cycle and record it).
**Design (decided, complete):**
- **Boundary points:** every L1 boundary CELL along the two offshore sides (sides resolved
  from `open_water_bearing` via the existing `_offshore_sides` logic, which moves into this
  module when the station module is deleted). Spacing = L1 `dx` = 1 km (D4).
- **Parameter sampling per point per partition:** bilinear over the 4 surrounding WW3 cells
  using WET cells only with renormalized weights; 0 of 4 wet → nearest wet cell within 2
  cells; none → raise. Directions interpolate as unit vectors. A partition missing (9999) at
  contributing cells → that partition contributes zero energy at that point (partitions die
  out spatially — legitimate); ALL partitions zero while interpolated `HTSGW > 0.1 m` → raise
  (inconsistent source).
- **Spectrum per point:** `E(f,θ) = Σ_p (Hs_p²/16) · S_p(f) · D_p(θ)`, emitted on the CGRID
  spectral axes (35 log freqs 0.03–1.0 Hz — msc+1, see syntax §2 correction — 72 dirs) so SWAN never interpolates spectra.
  Wind-sea train: JONSWAP `γ=3.3`, `Tp = r × WVPER` (r measured-then-pinned, bounds
  [1.10, 1.35], vs 3 live `.spec` cycles), spread cos^2s `s=7` (σθ≈30°). Swell trains:
  Gaussian `σf = 0.015 Hz` centred at `1/SWPER` (narrow-band: mean≈peak), spread cos^2s
  `s=28` (σθ≈15°). Each `S_p(f)`/`D_p(θ)` normalized to unit integral on the discrete grid
  BEFORE scaling by `Hs_p²/16` — bin-sum identity is then exact by construction.
- **Runtime guard:** per point, `|4√m0 − √(ΣHs_p²)| ≤ 5%` (discretization identity) → raise
  on breach. NO runtime guard against HTSGW (a 4th WW3 partition legitimately makes the
  partition sum < HTSGW); HTSGW comparison is KAT-only.
- **Time:** nonstationary files, one file per boundary point carrying all timesteps
  (ocean 3-hourly steps; SWAN interpolates in time per manual BOUNDSPEC nonstationary
  handling; GLWU hourly).
### B3 — Emission  ✅ (marine `dcfd84a`)
**Files:** `services/swan_formats.py` (`ww3_boundary_files_and_command()` — reworked in
place, same public name), `services/swan_runner.py` (file writing, :4497 region).
**Design (decided):** `BOUNDSPEC SIDE <s> CCW VARIABLE FILE <len_1> 'B_<side>_<i>.txt' 1 …`
per offshore side, `[len]` in UTM metres from the side's CCW begin corner — the R5 emission
convention and corner map carry over verbatim (S/W run-verified; N/E derived — first
deployment on an N/E-fed coast must show "Normal end of run" with zero boundary warnings
before N/E is called verified; recorded, not flagged).

### B4 — Retire the station path  ✅ (marine `f190fcd`; ww3_spectrum.py = docstring stub per coordinator ruling; live PASS + land-locked REFUSAL smoke of the new config-time viability check; doc-sync meta `b22e80f`)
**Files (deleted, P5):** `services/ww3_station_selection.py`,
`services/ww3_station_catalogue.py`, `data/ww3_station_catalogue.json`. **Files (modified):**
`services/ww3_spectrum.py` (station fetch + parser deleted AFTER the writer extraction in B2;
if the SPECOUT-mirror parser is used by `swan_spectral.py` tests, the parser stays — verify,
report in scope-ack), `services/grid_sizing_chain.py` (config-time viability: station check
replaced by a partition-fetch smoke test — one live cycle, corridor bbox, all fields present,
every boundary point maps to wet cells; failure = same loud config-push refusal role),
`providers/nearshore/swan.py` (`_run_all_spots_locked` boundary call site).
**Design (decided):** the kd/depth/distance criteria retire with the stations (boundary
points now sit ON our grid; suitability is the wet-cell mapping). H2.2's
fetch-backoff/rate-limit courtesy conventions migrate to B1's fetcher.

### B5 — Tests (test-author)  ✅ COMPLETE 2026-08-09 (marine `c217d8f` + `e1c315e` + `11b5768`; 31 tests, lead-reproduced 31/31; K1/K2/K5 mutation-and-revert falsifiability demos performed live — the K2 demo exposed that the original K2 KATs bypassed the real GRIB2 direction-extraction path, closed by `11b5768`'s TestK2ExtractionPathConvention, mutation-confirmed)  🔄 was IN FLIGHT at session checkpoint 2026-08-09 (scope-ack confirmed: K1–K7 + 2 authorized deletions (test_ww3_fetch_backoff.py, test_boundspec_len_meters.py — subjects gone; [len]-metres lesson survives as K5; backoff idiom lives in _common/http.py, verified) + 7 intent-preserving repairs. Agent told to commit partial state; see its checkpoint closeout in the session handoff.)
KATs (new `tests/test_boundary_reconstruction.py` + `tests/test_partition_fields.py`):
K1 bin-sum identity per partition and total (synthetic 3-train input, Hs recovery ≤ 1%);
K2 direction convention (synthetic due-W swell → energy at 270° coming-from in the emitted
file); K3 multimodality (3 trains → 3 distinct peaks; the anti-`VARIABLE PAR` property);
K4 wet-cell fallback ladder incl. the raise; K5 `[len]`/corner geometry vs a hand-computed
UTM fixture (reuses R5's lesson); K6 GLWU variant (hourly cadence, 2.5 km corridor);
K7 missing-field raise. **Deleted test files (the ONLY ones):** the station-selection suites
(`tests/` files pinning `ww3_station_selection` / catalogue behavior — enumerate exhaustively
in the scope-ack; each listed in the closeout per the stale-test rule).

### B-Accept (live, CURRENT extent — the comparability deploy)  🔶 **RUN 2026-08-09, 3 rows PASS / 2 criterion breaches surfaced (Q4)** — deployed `5cc28e8` 03:12:56Z after a GATE EVENT on the first attempt (03:07Z: `no-publish swan_fatal` — the 43-point BOUNDSPEC command was 1085 chars on one line; `build_swan_input`'s 180-char guard correctly refused; last-good preserved. Fix same round, lead-direct: `&`-continuation wrapping per manual :1219-1220/B.4 + continuation-aware E8 reuse reader + 2 KATs that fail pre-fix; marine `5cc28e8`). Matched 00Z cycle rerun 03:17:19→03:47:30Z:
- (1) norm_end "Normal end of run v1" ✓. "Differences in wave height at the boundary" WARNING class is PRE-EXISTING (station baseline PRINT: 14 over 4 points = 3.5/point; new: 56 over 66 points = 0.85/point — per-point rate improved; the row's "zero boundary warnings" was never met by the station baseline either — recorded deviation).
- (2) Station-position ±10%: **PASS all 4** (independent parse of preserved station BOUND_* vs nearest new B_* file, first common timestep 18z: 46223 −0.7% @1.1 km; 46222 −9.3% @13.1 km (station lies outside L1 — farthest match, noted); 46253 −4.0% @0.14 km; 46256 −3.3% @2.0 km).
- (3) Headline matched-hour (00Z): breakingFaceHeight 1.4649→1.1639 m = **−20.5%, BREACHES ≤15%** → Q4. Reality check (pre-declared): combined DWR Hs 1.008 m vs 46253 0.9 m (+12% ✓) / 46222 0.8 m (+26% marginal); period 18.4 s vs DPD 17 s ✓; swell dir 199° vs MWD 164–209° spread — the pre-plan 35–40° gap is GONE. Every quantity moved TOWARD the buoys vs W-Accept's "before" (0.62 m, −31%/−22%).
- (4) Wall-clock: 30m11s vs matched station run 26m54s = **+3m17s, grazes ≤+3min** → Q4 (vs the plan's other stated baseline "~37min incl. fetches" it is −7m30s).
- (5) Boundary volume: 66 files, 12,484,979 B total (station path: 4 files, 36.1 MB) — SMALLER. WIND.txt md5 differs from baseline solely by the shifted computation window (leading values byte-identical; explained, wind path untouched by B). Journal sweep: zero NEW classes (INV-11 + L4-handoff-selection classes present in baseline window too). Publish-liveness ✓ (lastRunTime 03:17:19Z, /surf 200).
**✅ CLOSED 2026-08-09 — Q4 ruled: operator accepted both deviations ("the height change matches surfline and surf-forecast, so that is not a bad thing" — external corroboration on top of the buoy agreement).** Parking lot: SWAN caps one command at 99 file names (manual :1223) — 66 today, Phase G growth could approach it.
Deploy alone. Matched cycle vs the last station-boundary cycle: (1) "Normal end of run", zero
boundary warnings; (2) boundary Hs sampled at the 4 old station positions within ±10% of the
same-cycle `.spec` m0 at those stations (the old boundary is the reference for the SAME
water); (3) published headline face height delta ≤ 15% absolute at the matched hour, delta
RECORDED with the cam/buoy reality check (quantities pre-declared); (4) cycle wall-clock
delta ≤ +3 min; boundary file count/bytes/SWAN-read-time measured and recorded (D4's
measurement); (5) baseline diff table. Wall-clock breach → STOP and surface (do NOT thin
spacing — D4 is ruled).

### ⛔ QC GATE B — `clearskies-auditor`, adversarial — **PASSED 2026-08-09** (blind audit of `95abc74..11b5768`: rows 1,3,4,5,6,8 PASS on the auditor's own mutation/generation/mocked-run evidence — K1/K2/K5 mutations each produced failures and reverted clean; forbidden-emissions grep zero; 9 pinned command strings byte-identical vs 95abc74; zero surviving station-module imports; refusal drill ERROR+None via monkeypatched raise. Row 2 PASS: writer grammar verified against the auditor's own manual reading; the live-SPECOUT cross-check was permission-blocked for the auditor and closed by the LEAD's own read (`sudo head SPEC_DWR_1.txt` → `AFREQ / 35`, ascending 0.0300/0.0333 — matches the writer's ladder). Row 7 FAILED then remediated lead-direct: PROVIDER-MANUAL §14.3a still carried the pre-pin "NOT-YET-PINNED (1.20) / bounds [1.10,1.35]" r-constant text from doc-sync `b22e80f`, which predates the r-pin `5ebc1fa` by 12 min — fixed same round (PROVIDER-MANUAL two spots + ADR-104 named-constants amendment note; sweep found no other stale copies in governing docs; plan text governed by its own decision-log supersession entry). Findings: F1 MEDIUM accepted+remediated, F2 LOW noted (KATs stopping at a hand-built intermediate object don't exercise the extraction path — already closed by `11b5768`, kept as KAT-design lesson). Test baseline: 31 passed / 0 failed, lead-reproduced. NOTE: the ±10% station-position comparison moved to B-Accept/V4 per the audit brief — needs the live deploy.)
Rows: K1–K7 falsifiable (mutation: break normalization → K1 fails); no surviving import of
the deleted modules (grep); grid_sizing_chain refusal fires on a cut network (drill); the
±10% station-position comparison is the auditor's own recomputation from raw files, not the
implementer's number; doc-sync (PROVIDER-MANUAL §14.3a rewritten; ARCHITECTURE.md:122 boundary
paragraph rewritten) landed same round; pytest baseline recorded.

---

## PHASE G — Island-aware autosizing, cap, near-lee, override plumbing *(D1/D2/D11/D12)*

**Owner:** `clearskies-api-dev` (Sonnet). **Tests:** `clearskies-test-author`. **QC:**
`clearskies-auditor` at Gate G.

### G1 — Horizon decoupled + cap constant  ✅ (marine `036a2ec`)
**Files:** `services/geography.py` (:114-115, :170-190).
**Design (decided):** `L1_MAX_EXTENT_KM = 100.0` module constant in `geography.py` (single
source; `swan_domain.py` imports it). Ocean path of `resolve_regime_horizon_km()` returns the
cap unconditionally (shelf lookup no longer consulted for the HORIZON; `find_shelf_distance`
still sizes the BASE offshore extent in `_compute_level1` — unchanged, including its 30 km
fallback and the Great Lakes fetch path). Great Lakes horizon stays 200 km (its own cap; L1
lake sizing is fetch-based and unchanged). Overpass bbox scales with the horizon by existing
code (`_bbox_from_horizon`) — config-time cost only; note in the round record.

### G2 — Ray march records where open water resumes  ✅ (marine `036a2ec`)
**Files:** `services/geography.py` (`RayResult` :135-150, `_classify_ray` :296-351).
**Design (decided):** `RayResult` gains `open_water_resume_km: float | None` — for
`wrap_candidate`, the distance of the FIRST water step of the qualifying ≥5 km run (the march
already walks it; record `distance_km − (run_count−1)·_RAY_STEP_KM` at qualification); `None`
for other classifications. Pure addition; existing consumers unaffected (dataclass field
append, no positional construction survives — verify in scope-ack).

### G3 — Enclosure to the island's far edge; beyond-cap islands are NOT enclosed  ✅ (marine `3f98613`)
**Files:** `services/swan_domain.py` (`_compute_level1` :1168-1187 wrap block).
**Design (decided):** per wrap ray, enclosure distance = `resume + 10.0` km. If
`resume + 10.0 > L1_MAX_EXTENT_KM` → the ray is treated as un-enclosable (NO enclosure point
— partial enclosure would put the boundary ON the island) and joins the near-lee set (G4).
Otherwise the enclosure point sits at that distance along the ray bearing (replaces today's
point-at-full-horizon). Every extent computation clamps to the cap.

### G4 — Near-lee clamp (D11, ruled closed — constants σθ=15°, k=1)  ✅ (marine `3f98613`; angular-extent lead ruling in decision log + ADR-104 D11 note)
**Files:** `services/swan_domain.py` (same function; new private helper
`_near_lee_max_extents(rays, base_offshore_km)`).
**Design (decided):** un-enclosable blocker set = {wrap rays with `resume+10 > cap`} ∪
{`truly_blocked` rays with `first_land_distance_km > base_offshore_km` (an offshore island,
not the coast)}. Cluster adjacent rays (gap ≤ 2 ray steps = 10°) into islands. Per cluster:
`W = mean(first_land) × angular_extent_rad` (chord width), `L_fill = W / (2·tan 15°)`,
max offshore extent along the cluster's bearings =
`max(base_offshore_km, mean(first_land) − L_fill)`. Applied by clamping the offshore aim
point and any enclosure/wrap point whose bearing falls inside the cluster's sector, BEFORE
the min/max envelope. Enclosure requirements from OTHER islands are not reduced —
where geometry conflicts, the envelope that results IS the answer (best-achievable, silent,
per D11 — no reporting apparatus; sizing trace keeps ordinary numbers only).

### G5 — Operator override key (marine side)  ✅ (marine `3f98613` swan_domain half + `e207d79` config/plumbing)
**Files:** `config/marine_config.py` (new key `[swan] l1_offshore_extent_km`, optional
float), `services/grid_sizing_chain.py`, `services/swan_domain.py`.
**Design (decided):** when present and > 0: the autosized offshore extent (base + enclosures
+ near-lee) is REPLACED by the operator value, clamped to the cap; lateral sizing and
landward margin unchanged; wrap enclosure points suppressed (the operator owns the extent).
Absent/0 = autosize. Admin UI exposure is Phase A (this task is config plumbing + validation:
negative/NaN/> cap → config-push refusal naming the cap).

### G6 — UTM-zone span validation  ✅ (marine `e207d79`)
**Files:** `services/grid_sizing_chain.py`.
**Design (decided):** at config push, after L1 sizing: the L1 bbox's longitudes must lie
within ±3.5° of the locked UTM zone's central meridian → else loud config-push refusal naming
the span and the cap. (Zone 11 handles all of SoCal incl. San Clemente; this guard exists for
arbitrary future coasts, not HB.)

### G7 — Cold-start guard verification (no code)  🔶 code-read half DONE (lead: `_domain_geometry_signature` includes L1 bbox+resolution, grid_sizing_chain.py:309-331); live observation lands at G-Accept
Verify (read-only) the F1 geometry-compare guard treats the L1 bbox change as
cold-start + forced full run. Evidence: the guard's compare includes L1 bbox (it does per
ARCHITECTURE:115 — confirm at HEAD) + one live observation at G-Accept.

### G8 — Tests (test-author)  ✅ (marine `eecfabc`, 12 KATs; falsifiability 8 FAIL pre-G / row-(c) anchor + row-(d) declared non-falsifiable; row-(e) deviation lead-approved, see decision log)
KATs (`tests/test_island_autosizing.py`): synthetic coastline fixtures — (a) island at
50 km, 8 km wide → wrap; enclosure at `resume+10`; (b) island at 95 km → un-enclosable →
near-lee clamp computed per G4's exact arithmetic (hand-computed expected extents); (c) plain
open coast → box identical to pre-G sizing (regression pin); (d) Great Lakes fixture →
horizon 200, sizing unchanged; (e) Huntington OSM fixture → Catalina enclosed
(W edge past −118.60+10 km-equivalent), SCI clamps the S extent to max-achievable, box ≈
brief §4 S1 within ±15% per axis; (f) override set → exact operator extent, enclosures
suppressed; (g) zone-span refusal. Baseline suite: 0 new failures.

### G-Accept (live — the relocation deploy)  🔶 **RUN 2026-08-09 (session 4) — deployed `eecfabc` (proc 08:22:05Z), config re-pushed 08:23:13Z, new L1 live and publishing since; 4 rows PASS, 2 deviations + 1 fired guard surfaced as Q6 (operator ruling needed to close)**
**Record (all numbers lead-collected from fresh commands; baseline = the 07:23:14Z pre-deploy
cycle, payload + file inventory archived in session scratchpad):**
- **Sizing (row 1): PART PASS / PART BREACH.** New L1 bbox lon −118.7598..−117.7725, lat
  32.8994..34.0806 = 93×132 cells (12,276; was 37×27=1,064). E-W 91.4 km vs brief S1 ~90 km
  (+1.6% ✓, W edge −118.76 ≈ S1's −118.75); **N-S 131.3 km vs S1 ~57 km (+130% — BREACHES
  ±15%/axis → Q6).** Catalina fully inside, boundary W edge seaward of it ✓. **S edge (32.90)
  crosses San Clemente Island's footprint** (SCI ~32.80–33.03) — the D11 envelope outcome;
  ~5–8 boundary points sit over SCI land; the B2 wet-cell ladder mapped them (smoke test
  PASSED, 225 points) → Q6.
- **G7 cold start (row 2): PASS.** 08:56:33Z: "grid geometry changed on this config push
  (L1, L2) — clearing persisted SWAN run state … an immediate full run is now signalled";
  stale hotstarts removed; subsequent runs on 91×131 live grid.
- **Full cycle (row 3): PASS.** 13:04 extended cycle: L1 91×131 @1 km "Normal end of run v1"
  + STOP; L1 wall-clock 13:08:33→13:22:57 = 14m24s (vs brief est ~4.3 min at ~5,100 cells —
  scales with the 2.4× cell count); full cycle 13:04:23→13:40:19 = **35m56s < 45 min hard ✓**;
  publish live (lastRunTime 13:08:25Z, /surf 200). Peak SWAN RSS measurement armed for the
  next run (monitor); STOP threshold 300 MB not yet confirmed either way.
- **Boundary adaptation / 99-file cap (row 4): PASS with a measured deviation.** 225 points
  (S=93 files, W=132 files), zero Phase-B code change (decoupling proof ✓).
  **The W-side BOUNDSPEC carries 132 file names in ONE command — the manual's :1223 99-file
  cap did NOT bite on the deployed 41.51AB binary** (multiple Normal-end runs) → record in
  PROVIDER-MANUAL §14.15 measured deviations at doc-sync. Boundary volume 44.9 MB
  (66 files/12.7 MB pre-G; station era 36.1 MB). L1 PRINT boundary WARNING 35/225 points =
  0.16/pt (B-Accept: 0.85/pt) — improved.
- **Reality gate (row 5, quantities pre-declared): PASS.** Combined deep Hs 0.636 m vs
  46222 0.8 m (−20.5% ✓ within ±25%) / 46253 0.8 m @15:26Z (−20.5% ✓; the 14:56Z 0.9 m
  reading would be −29%). **W-NW shadow window: wind swell 0.65 m @275° → 0.336 m @264°
  (energy −73%) — the pre-declared DROP, islands now modeled ✓;** S groundswell survives
  0.552→0.534 m and gains a second 19.3 s / 179° train. Matched-hour headline +8%…+29.5%
  (mean ≈ +15%) — CHANGE was expected; faces RISE because the shadowed wind swell no longer
  steals dominance (period at the 14–16Z hours 10.9→16.7 s: groundswell stays dominant).
- **Journal sweep (row 6): PASS.** No new WARNING/ERROR classes: transect SUBSTITUTION class
  = 326 hits in the PRE-deploy window (pre-existing, = the tracked L4-handoff target-depth
  class); HRRR Lambert WARNING still absent ✓; INV-11 the only health reason.
- **FIRED GUARD (gate event, rules/coordinator.md §7.3): L3 smart-sizing viability FAILED
  at the config push** — 08:26:41Z "structure unreachable by ~229 m … L3 disabled for this
  cluster; handoff falls back to L2 at ~15 m". The chain then wrote the COARSE L3 nest
  (52×47, contains L4 ≥200 m clearance) and live cycles run L3[0] 51×46 + L4 — the exact
  pre-G L3 dims, so the operative nest chain appears unchanged. **PRE-EXISTENCE CONFIRMED:
  the identical guard fired at the last pre-G config push, 2026-08-03 06:12:32Z ("unreachable
  by ~235 m") — not a Phase-G effect; belongs to the tracked smart-L3 disposition item.**
Config push on librewxr → new L1. (1) Sizing trace: box vs S1 estimate recorded; Catalina
inside the domain (land-masked by ETOPO), boundary seaward of it; (2) bathymetry chain: ETOPO
covers, C-90 coverage rows pass, cold start observed (G7); (3) full cycle "Normal end of
run"; L1 wall-clock + RSS recorded vs the brief's ~4.3 min / ~90 MB estimates (RSS > 300 MB
or cycle > 45 min → STOP and surface); (4) boundary point count grew, reconstruction adapted
(no code change in B needed = the decoupling proof); (5) matched-hour reality check
(pre-declared): headline vs cam + 46222 + 46253 — a CHANGE is expected (islands now modeled);
record the delta and the W-NW-swell sanity direction (shadowed window energy should DROP);
(6) baseline diff table.

### ⛔ QC GATE G — `clearskies-auditor`, adversarial — **PASSED 2026-08-09, 0 findings**
(Blind audit at `eecfabc`, 8 rows, all with pasted live evidence: R1 G4 arithmetic
re-derived from D11+implementation-note alone — 79.5300/47.2263 km match KAT literals and
code on both fixture shapes; R2 grep = single legitimate find_shelf_distance use (BASE
extent, swan_domain :1270), zero shelf→horizon coupling; R3 cap mutation (100→30) broke
4/12 KATs at 3+ distinct call sites, reverted, tree clean (lead re-verified clean at
`eecfabc`); R4 override chain traced parse→validate→plumb→replace/clamp/suppress, no gap;
R5 zone-span guard order + locked-zone + meridian arithmetic verified; R6 KAT literals from
from-scratch reimplementations + true cross-commit pin `_PRE_G_L1` at 70d442f; R7 doc-sync
landed; R8 exactly the 3 tracked pre-existing failures. Auditor named ruled-out failure
modes; row-(e) full S1 box comparison correctly identified as deferred to G-Accept.)
Rows as specified: G4 arithmetic re-derived independently by the auditor from D11's formula (not from the
implementation); fixture (e) box vs brief S1 checked by the auditor's own numbers; no
surviving `horizon` derivation from shelf distance (grep); override end-to-end (set → sized →
suppressed enclosures) demonstrated; cap enforced at every extent site (mutation: cap=30 →
fixtures fail); doc-sync (ARCHITECTURE.md:108/118 L1-sizing paragraphs, ADR-100 amendment
note) landed; baselines.

---

## PHASE S — Sources: RTOFS currents, STOFS water level, Hawaii datum *(D9/D10/D13)*

**Owner:** `clearskies-api-dev` (Sonnet). **Tests:** `clearskies-test-author`. **QC:**
`clearskies-auditor` at Gate S. Two deploys: S1+S4a (currents) and S2+S4b (wlevel) ship
separately (PRIME DIRECTIVE 3).

### S1 — RTOFS surface-current provider + OFS-contains-domain selection  ⬜
**Files (new):** `providers/ocean/rtofs_currents.py`. **Files (modified):**
`providers/ocean/ofs.py` (`find_ofs_model` gains `find_current_source(l1_bbox)`:
an OFS qualifies only if its `OFS_DOMAINS` box CONTAINS the L1 bbox — containment, not
centre-in-box; highest-resolution qualifier wins; none → `"RTOFS"`), `providers/nearshore/swan.py`
(:3086-3140 fetch site routes through the selector; C-77 abort semantics unchanged).
**Design (decided):** RTOFS product = NOMADS `rtofs_glo` 2-D surface (`2ds`) prognostic
files, 3-hourly u/v, via grib filter (primary) or ERDDAP griddap (alternate) — pinned after
one live shape check (bounded decision, register). Output shape identical to
`fetch_surface_currents` (list of {time, u_grid, v_grid} at SWAN grid dims) so
`_write_current_txt` is untouched. Selection logged once per cycle at INFO (provenance, not
flagging).
**Tidal-current compositing (operator directive 2026-08-08 — the service area, not the test
case, is the design target):** RTOFS is non-tidal (circulation only); STOFS-2D publishes the
complementary tidal/surge velocity. In RTOFS regions the served current field is the SUM per
cell per timestep: `u = u_RTOFS + u_STOFS`, `v = v_RTOFS + v_STOFS`. No double-counting by
construction — RTOFS contains zero tidal signal and STOFS zero circulation. STOFS velocity is
depth-averaged; the tidal component is barotropic (near-uniform over depth in shelf water), so
depth-averaged ≈ surface for exactly the component STOFS supplies — stated in the manual
section, not hidden. STOFS velocity arrives via S2's fetcher (same files carry u/v; one fetch
serves both WLEVEL and the tidal velocity). Time matching: same nearest-within-2h rule as
`_write_current_txt`; a timestep where either component is missing → `CurrentCoverageError`
(no partial composite — half a current is a fabricated current). OFS regions are untouched
(regional OFS models are tidal-inclusive natively; adding STOFS there WOULD double-count —
the composite applies to the RTOFS branch only, and a KAT pins that).

### S2 — STOFS water-level provider + WLEVEL chain  ⬜
**Files (new):** `providers/ocean/stofs_wlevel.py`. **Files (modified):**
`providers/nearshore/swan.py` (:3021-3080 tide fetch site → chain), `services/swan_runner.py`
(`_write_wlevel_txt` spatially-varying path generalized from the L3 profile writer to a
field-based writer for all levels; :2285-2352).
**Design (decided):** STOFS-2D-Global (`stofs_2d_glo`), 4 cycles/day, forecast to 180 h; the
regional GRIB2 grid covering the domain (CONUS West grid for HB; Hawaii/Pacific grid for HI —
exact product filenames pinned from the NCO inventory at implementation, candidates named in
the brief). Per-timestep water-level grid sampled to SWAN grid dims. **The fetcher extracts BOTH the
water-level field and the velocity (u/v) field from the same files — one fetch serves WLEVEL
(all regions) and the S1 tidal-velocity composite (RTOFS regions).** Datum: STOFS ≈ LMSL;
**cutover gate:** before STOFS becomes primary, 24 h of STOFS values at the tide-station cell
vs CO-OPS predictions, |mean bias| ≤ 0.15 m — breach → CO-OPS stays primary, STOP and
surface. Chain (decided): STOFS → CO-OPS-uniform (fallback selection logged loudly at fetch,
bathymetry-chain pattern) → refuse (`tide_fetch_failed`). The "~30 km uniform tide"
justification comment is deleted with the uniform-primary path.

### S3 — Hawaii/VDatum-less datum branch  ⬜
**Files:** `services/vertical_datum.py`, `data/ncei_regional_dem_index.json` (P12 refresh).
**Design (decided):** when the domain has no VDatum separation-grid coverage AND every
bathymetry source in play is tidal-referenced (MHW/MSL/MLLW): convert via tidal-datum offsets
from the CO-OPS `datums` product at the station nearest the domain centre (cached at config
push; same keyless API), constant across the domain. Any geodetic-referenced source (NAVD88
etc.) in such a region → `DatumConversionError` (refuse, never approximate). Precedent
pattern: the Great Lakes LWD/IGLD85 branch. Index refresh: add Maui + Big Island 1/3″ DEM
entries (and PR, low priority) from the NCEI catalogue via the index's existing generation
path (verify the generator script exists; if hand-authored, entries cite the catalogue URL).

### S4 — Tests (test-author)  ⬜
(a) selection KAT: containment-covered bbox → that OFS; open-Atlantic bbox → RTOFS+STOFS
composite; lake bbox → the lake OFS; (b) RTOFS fetch parse KAT from a recorded fixture;
(c) STOFS grid → WLEVEL.txt shape KAT; (d) chain fallback order + loud log + refuse;
(e) Hawaii datum KAT (Oahu fixture, synthetic station datums, MHW→LMSL arithmetic exact;
NAVD88 source → raise); (f) **composite KATs:** synthetic RTOFS + STOFS fields → summed
u/v exact per cell; missing either component at a timestep → raise; OFS branch never
composites (mutation: add STOFS to an OFS fixture → KAT fails); (g) baselines 0-delta.

### S-Accept (live)  ⬜
Currents deploy: HB continues on WCOFS (selection INFO line proves the rule ran); RTOFS
smoke-verified from librewxr against a Jersey-shore test bbox (fetch + parse once, config-time
style, nothing published). WLEVEL deploy: bias gate result recorded; post-cutover cycle
publishes with STOFS WLEVEL; matched-hour headline delta recorded (expected ≪ 0.1 m effect);
baseline diffs both deploys.

### ⛔ QC GATE S — `clearskies-auditor`, adversarial
Rows: containment (not centre) proven by fixture; the bias-gate numbers recomputed by the
auditor from raw fetches; no silent fallback anywhere in the two chains (grep for zero-fill
patterns; mutation drill on a cut STOFS URL → loud CO-OPS fallback line); Hawaii branch
refuses NAVD88 (KAT e falsifiable); doc-sync (PROVIDER-MANUAL new RTOFS/STOFS sections +
§14.12 note, ARCHITECTURE:122 inputs paragraph) landed; baselines.

---

## PHASE A — Setup-time source report + admin override UI *(D5, D1; cross-repo)*

**Owners:** A1 `clearskies-api-dev`; A2 `clearskies-dashboard-dev` (config UI) +
`clearskies-docs-author` (help keys + Operator Manual). **QC:** `clearskies-auditor` at Gate A.

### A1 — Per-input source/coverage report from the config chain  ⬜
**Files:** `services/grid_sizing_chain.py`, marine `/config` surface (`endpoints/config.py`).
**Design (decided):** the config-push chain already decides every source (bathymetry chain,
wind region, current source, WLEVEL chain, boundary product, datum path). A1 collects those
decisions into one structured block on the existing sizing trace + `/config` payload:
`inputs: [{input, source, coverage: ok|refused, reason?}]`. Refusals carry the exact refusal
string the chain already raises. No new decision logic — reporting of decisions made.

### A2 — Admin: marine sources panel + L1 offshore override field  ⬜
**Files:** stack repo admin template + routes (the `/health` `reasons[]` render path from
H1.4 is the precedent), help content keys `help.admin.marine_sources.*`, Operator Manual
section.
**Design (decided):** read-only sources table from A1's block; one numeric override field
writing `[swan] l1_offshore_extent_km` (validation mirrors G5: blank = autosize; > cap
rejected with the cap named). Help keys + Operator Manual land in the same round (CLAUDE.md
doc-sync table).

### ⛔ QC GATE A — `clearskies-auditor`
Rows: report shows a REAL refusal end-to-end (drill: rename sizing cache → refusal visible in
admin); override round-trips (set in admin → config push → G5 honors → sizing trace shows
operator extent); help keys exist for every new admin element; Operator Manual updated;
cross-repo doc-sync complete.

---

## PHASE C — Surf-card display correctness *(operator-added 2026-08-08; dispatch AFTER R5 closes)*

**Owners:** C1 `clearskies-api-dev` (server aggregates) + `clearskies-dashboard-dev` (card);
C2 `clearskies-dashboard-dev`. **Tests:** `clearskies-test-author` (API KATs), dashboard
vitest. **QC:** `clearskies-auditor` at Gate C. Independent of the model chain; both tasks
consume R5's dominant-partition serving and therefore wait for its round close.

### C1 — Current Swell Conditions card: range/combination over ELIGIBLE swells  ⬜
**Operator instruction (2026-08-08, verbatim intent):** show the swell height RANGE from
min/max across swells by type — not just the dominant; min/max breaking face height; and the
period from the COMBINATION of swells. Wind-swell rule throughout: **a wind swell with period
< 5 s does not count.**
**Files:** `endpoints/surf.py` (headline/summary assembly section ONLY — NOT the R5
breakPoints/zones sections), API-MANUAL data-model section, dashboard swell-conditions card
component (name resolved at scope-ack from the dashboard repo), `docs/contracts/openapi-v1.yaml`.
**Design (decided — server-side aggregation, dashboard stays a dumb renderer):**
- **Eligibility:** a swell component is eligible unless it is classified wind swell AND its
  period < 5.0 s. If NO component is eligible (pure short-chop day), the aggregates are
  computed over all components — the card must always show the real conditions, never blank.
- **Swell Height:** `swellHeightMinFt`/`swellHeightMaxFt` = min/max deep-water height over
  eligible components (screenshot case: 1.1–1.5 ft, not 1.5). Card renders "min–max ft"
  (single value collapses to one number).
- **Breaking Face Height:** `faceHeightMinFt`/`faceHeightMaxFt` = min/max of the per-swell
  breaking face heights at the representative break over eligible components (the
  per-partition face heights the 1D pipeline already computes; R5's per-transect dominant
  machinery is read, not modified).
- **Period:** `combinedPeriodS` = energy-weighted mean period over eligible components,
  weights `Hs_i²` (screenshot case: (1.5²·16.4 + 1.1²·12.8)/(1.5²+1.1²) ≈ 15.1 s). One
  number, one decimal.
- Additive fields only (P13); existing fields untouched (R3/R5 consumers unaffected). The
  incoming-swell table on the card is unchanged — it already lists every component.
- KATs: eligibility boundary (4.9 s wind swell excluded, 5.0 s included), all-excluded
  fallback, weighted-period arithmetic pin, single-swell collapse.
**Accept (live):** card shows range + combined period consistent with the served component
list on the same refresh; screenshot-case arithmetic verified against the live payload;
API-MANUAL + openapi doc-sync same round.

### C2 — Beach Profile card: draw ONLY the dominant swell's wave train  ⬜
**Operator instruction (2026-08-08):** the profile's water-surface rendering must draw the
dominant swell only, not all swells interleaved (screenshot: overlapping trains).
**Files:** `BeachProfileChart.tsx` (wave-surface generation region ONLY — the :585-594
break-marker filter stays as R5 left it), dashboard vitest for the selection helper.
**Design (decided):** the drawn train is the partition R5 serves — select by the
`partitionInfo.partitionIndex` carried on the served breakPoints (all entries share it
post-R5); fallback when no breakPoints are served: the largest-face component from the swell
list (mirrors the backend's own dominance criterion; no second definition invented).
Amplitude/wavelength/breaking envelope of the drawn train unchanged — only WHICH train(s)
draw. DASHBOARD-MANUAL doc-sync same round.
**Accept (live):** profile shows one coherent train matching the headline swell; no
interleaved secondary crests; matched against the card's dominant direction on the same hour.

### C3 — Surf-height heatmap: ortho alignment, buffer, y-axis, structure-overlay removal  ⬜
**Operator instruction (2026-08-08):** (a) the orthophotography must be ALIGNED with the
transect bearing (the heatmap's beach frame), not true north — "so that way IT MATCHES";
(b) 50 m of orthophotography buffering around the heatmap extent so the user can get their
bearings; (c) y-axis labels; (d) REMOVE the structure-affected-area overlay — confusing, and
the structure effect is already in the wave action itself (SWAN L4).
**Files:** dashboard heatmap component (LM-2's ortho rendering, dashboard `fe0b8e9` lineage —
exact component named at scope-ack), dashboard vitest, DASHBOARD-MANUAL. Imagery API
endpoints (LM-1) are READ-ONLY — contract consulted, not modified.
**Design (decided):**
- **Rotation client-side, provider-agnostic:** the imagery layer is drawn rotated by the
  beach bearing about the chart frame so imagery and heatmap share the beach-aligned frame
  (the heatmap grid itself is already beach-frame and does not change). The imagery REQUEST
  bbox becomes the north-up enclosing box of the rotated heatmap footprint + buffer — padding
  is computed, never hardcoded.
- **Buffer:** 50 m of visible ortho beyond the heatmap extent on all four sides.
- **Axes:** y-axis gets tick labels + unit title in the same unit family the x-axis uses; if
  the x-axis lacks a title, both are labeled in this task (verified at scope-ack).
- **Structure overlay:** the affected-area layer + its legend entry deleted, dashboard-only —
  the API field keeps serving (deprecation noted in DASHBOARD-MANUAL); SWAN L4 physics
  untouched.
**Accept (live):** side-by-side on weather-test — an ortho landmark (pier, jetty) lines up
with its heatmap/transect position; buffer measured ≈ 50 m at chart scale; y-axis labeled;
no structure overlay; bundle-size baseline recorded.

### ⛔ QC GATE C — `clearskies-auditor`
Rows: eligibility rule single-sourced server-side (grep: no dashboard reimplementation);
weighted-period KAT falsifiable (mutation: weights Hs¹ → fails); C1 touched ONLY the summary
section of `endpoints/surf.py` (diff review vs R5's sections); C2 selection uses served
partitionIndex, not a locally re-derived dominance; both cards visually verified on
weather-test with a screenshot in the gate record; doc-sync landed (API-MANUAL, openapi,
DASHBOARD-MANUAL); bundle-size baseline recorded (ADR-033 budget).

## PHASE V — Plan-close validation *(evidence collection; weather rows stay open until met)*

**Owner:** lead + `clearskies-auditor` (blind walk). Quantities pre-declared per
rules/verification.md §"Validate against reality".

- **V1 — W-NW swell event:** matched-time headline + break structure vs cam/Surfline/46222.
  Pre-declared expectation: shadowed-window energy at HB DROPS vs the pre-plan model;
  groundswell faces within ±20% of Surfline's range on the comparable hour.  ⬜
- **V2 — S swell event:** served vs 46253/46222 observations (the water down-wave of San
  Clemente) — records how WW3's partially-healed shadow performs at the new boundary
  (measurement evidence; D11 means no further action regardless, unless the operator reopens).  ⬜
- **V3 — Performance budget:** full cycle ≤ 45 min hard / target ≤ 40; SWAN peak RSS
  ≤ 300 MB at `omp_num_threads=6`; boundary file volume + SWAN read time within B-Accept's
  recorded envelope across 5 consecutive cycles.  ⬜
- **V4 — Blind auditor walk** of Gates W/B/G/S/A evidence (the Gate H 8/8 pattern): every row
  re-verified by the auditor's own command or prior adversarial artifact — zero rows on
  implementer/coordinator word.  ⬜

Plan closes when V1–V4 are recorded and the decision log below is complete.

---

## PINNED (operator-ruled or deferred — do NOT dispatch from this plan)

- **Directional resolution increase (CIRCLE 72 → finer)** for sharper island shadows —
  runtime ~linear in bins; revisit only after V1/V2 evidence, operator decision.
- **Alaska + territories re-entry** — descoped by D12; the brief's D7 matrix is the re-entry
  record (HRRR-AK clause dormant in D8).
- **PR DEM index entries** — low priority, may ride along with P12 if trivial.

## Decision log

- **2026-08-09 (session 4) — Two lead rulings from the Phase-S scope-ack findings, both
  code-verified by the lead before ruling:** (1) `providers/tides/coops.py` ADDED to the
  S allowlist for S3, additive `datums` product only (no datums support exists today —
  verified: `_DEFAULT_PRODUCTS` = predictions/water_level/water_temperature; P9 already
  authorizes the datums-product conversion, so the file addition is implementation of a
  registered change, not a new architectural grant). (2) S dev brief corrected:
  `_write_wlevel_txt` (:2285) is the spatially-UNIFORM stamp; the spatially-varying
  writer ALREADY EXISTS as `_write_wlevel_grid_txt` (:2329-2352) — S2 is wiring STOFS
  fields into the existing grid writer, not generalizing the uniform one. Third finding
  (RTOFS route, both plan candidates dead) surfaced as Q5 — out-of-bounds per the plan's
  own named-constants rule, not lead-ruled. (operator, in chat): B-Accept's two criterion deviations
  accepted** — headline −20.5% ("the height change matches surfline and surf-forecast,
  so that is not a bad thing"; buoy reality gate had already improved on every
  pre-declared quantity) and wall-clock +3m17s vs the matched station cycle. B-Accept
  CLOSED; Phase B complete end-to-end (deployed `5cc28e8`).
- **2026-08-09 — INCIDENT RESOLVED ~07:18Z: librewxr DHCP lease expiry.** ROOT CAUSE:
  unattended-upgrades restarted systemd-networkd on Aug 1 06:47Z (openssl upgrade); the
  restarted daemon wedged silently (zero journal entries for 8 days, no T1/T2 renewals);
  the lease (LIFETIME=1w1d, acquired Aug 1 06:47) expired Aug 9 06:47Z — the death
  minute — dropping eth0's IPv4. librewxr is an LXD CONTAINER (not a physical host —
  coordinator error cost diagnostic time); fix = `systemctl restart systemd-networkd`
  in-container via ratbert lxc exec → 192.168.7.22 + default route restored, SSH OK,
  CheckMK agent OK, marine service recovered (had refused loudly + preserved last-good,
  by design). Coordinator errors recorded: stale memory-pressure bias; misread Windows
  ping (router "unreachable" replies counted as received → false "ICMP alive"); raw-IPv4
  diagnostics instead of FQDNs (rule added to CLAUDE.md); premature "flapping" claim
  from a wall-clock arithmetic error. FOLLOW-UPS (parked): (1) monitor DHCP lease age /
  networkd log-liveness to catch a deaf networkd before expiry; (2) per-minute failing
  `check_mk_agent` docker-exec spam in container journal; (3) SWAN stdin FD leak (below).
  **Historical record of the investigation as it unfolded:** TOTAL network death — no ARP,
  no ICMP, no TCP. The coordinator's earlier "ICMP alive" claim was a misread: Windows
  `ping` counts the ROUTER's "Destination host unreachable" replies (from 192.168.2.254)
  as received packets, so "0% loss" was the gateway talking, never the box (operator
  caught it: "ping is not responding either"). tracert confirms: dies at the gateway,
  host unresolvable at L2. **Operator RESTARTED the box and it did NOT return to the
  network** → persistent across reboot → candidates now: not booting at all (power/
  disk/kernel), NIC/driver failure, cable/switch port. Physical console is the next
  diagnostic. CheckMK metrics flat to the last datapoint 06:45Z (RAM 1.88 GB of
  11.2 GiB, CPU 8%, no ramp — resource exhaustion RULED OUT); uptime 25 d at death,
  no reboot before it. NOT deploy-correlated: W6 deployed 05:23Z, clean full cycle
  ended 06:00:56Z, box healthy 06:15Z; nothing deployed after. **Both code-review
  hypothesis rankings below were briefed with the false ICMP-alive premise — the
  docker-iptables-wedge hypothesis loses its signature fit and is DOWNGRADED
  accordingly; the code-level findings (marine cleared; FD leak; unbounded build
  cache; hourly rebuild cron existence) stand as facts.** Two read-only code
  investigations complete: (1) marine code CLEARED — no mechanism for cross-process TCP
  death; W6 diff verified parse-time-only with finally-closed handles; retry loops
  bounded (≤1 attempt/5 min/input). (2) LibreWXR repo: LEAD HYPOTHESIS = hourly
  `scripts/auto-update.sh` cron (`docker compose up -d --build`; heavy no-cache build
  could run ~46 min from an 06:00Z fire, landing dockerd's iptables/NAT rewrite at the
  06:46Z death minute — the classic ICMP-alive/TCP-dead netfilter wedge class); 43 GB /
  95-active BuildKit cache (no pruning anywhere in repo) corroborates repeated in-place
  rebuilds. DECISIVE PENDING FACT: whether `.auto-update-enabled` or
  `LIBREWXR_AUTO_UPDATE=1` is set on the host — unset collapses the hypothesis toward a
  kernel/driver event. Post-reboot checklist: sentinel/env → update log 06:00-06:46Z →
  docker events + docker journal (prev boot) → kern.log netfilter/NIC → rule out
  EMFILE/conntrack-full.
- **2026-08-09 — DEFECT FOUND (parking lot, unrelated to incident): SWAN subprocess
  stdin FD leak** — `services/swan_runner.py:5474` `_spawn_swan()` and
  `services/surfbeat_runner.py:531` pass `input_file.open("r")` to `subprocess.run`
  without ever closing it (any path). ~20-30 FDs/day leaked in the marine process.
  Slow, self-confined, cannot explain the incident; needs a small fix round (with-block
  or explicit close in finally).
- **2026-08-09 — G8 row-(e) deviation (lead-approved):** the plan's "box ≈ brief §4 S1
  within ±15% per axis" is not honestly claimable from a single-spot synthetic RayResult
  fixture (S1's E/N edges come from multiple real spots + lateral margins). Test-author
  surfaced it rather than overclaiming; the full-box ±15% check MOVES to G-Accept row 1
  (live sizing trace vs S1). The KATs assert what the plan names concretely: Catalina
  W-edge enclosure, SCI clamp to max-achievable, W/S edge match (which DID land on S1's
  values). Deviation stated in the test-file docstring.
- **2026-08-09 — Marine repo pre-existing test failures TRACKED (parking lot):** 3
  failures present at `70d442f` (pre-Phase-G) and unchanged since, reproduced
  independently by dev and lead: `tests/services/test_double_break_transect55_kat.py::
  TestDoubleBreakOnRealTransect55::test_wave_reforms_between_the_two_breaks`;
  `tests/services/test_wind_gatherer.py::TestColdStartReconcile::
  test_loads_store_then_polls_and_persists` (lastPollAt None);
  `tests/services/test_wind_timeline_store.py::TestDiskPersistence::
  test_save_then_load_round_trips_timeline_and_incoming`. Plus one flaky
  environment-timing test seen once during W6 checks: `tests/test_h4_chunked_json.py::
  test_after_chunked_encode_passes_the_threshold` (heartbeat max_gap 0.162s vs 0.15s).
  None caused by W6/G work; need their own triage round.
- **2026-08-09 — G1 stale-test ruling (lead):** `test_geography.py::
  test_resolve_regime_horizon_km_ocean_fallback_and_margin` pins the pre-G1
  shelf-driven ocean horizon (superseded by P1). Dev STOPped per the stale-test block;
  ruled: update that one test in the SAME commit as G1 to pin the new behavior (ocean
  horizon = L1_MAX_EXTENT_KM = 100.0 unconditionally, no shelf dependence; unrelated
  assertions preserved) — evidence-hygiene rule, same-commit. Deletion and
  leave-it-red both rejected.
- **2026-08-09 — G4 `angular_extent_rad` lead-ruled (same-document ambiguity; operator
  may override before G-Accept deploy):** neither G4 nor ADR-104 D11 defines the
  cluster's angular extent. Ruled: `(bearing_max − bearing_min) + one 5° ray step`, in
  radians — each blocked ray represents its own 5° sector (the same semantics G4's own
  clustering rule uses, "gap ≤ 2 ray steps = 10°"); contiguous N-ray cluster ⇒ N×5°;
  single ray ⇒ 5°, never zero (a zero-width island would get NO clamp, contradicting
  D11's stated purpose); internal 1–2-step gaps are spanned. Dev-surfaced STOP,
  dev continued G3/G5/G6 while waiting — correct protocol.
- **2026-08-09 — W6 CODE COMPLETE (marine `70d442f`, lead-verified) + W-Accept item 1
  root-cause REFRAMED.** Empirical diagnosis from a real captured NOMADS GRIB2 fixture:
  the eccodes key was misspelled (`LovInDegrees` vs correct `LoVInDegrees`), and the
  single combined try/except zeroed all three Lambert parameters on every fetch. Because
  per-point longitudes (`lons_2d`) are read OUTSIDE that try/except, the pre-fix rotation
  was NOT the lon_first/lon_last approximation the old WARNING text claimed — it was a
  no-op (`latin1=latin2=0 → n=0 → alpha=0`): **winds were never earth-rotated at all.**
  W-Accept item 1's "bbox-dependent approximation wobble" attribution is superseded; the
  byte-diff observed there was NOMADS-side resubsetting between bboxes, not rotation
  wobble. Post-deploy expectation (predicted, not tuned): wind direction shifts ≈ −12.75°
  at the L1 domain-center longitude (alpha = sin(38.5°)·(242.02°−262.5°)). Fix: three
  independent metadata reads (both eccodes + pygrib backends), corrected log text,
  approximation branch kept as last resort now logging at ERROR. 12 KATs, 9/12 fail
  pre-change (falsifiability independently reproduced by lead: `9 failed, 3 passed`).
- **2026-08-09 — W6 created (operator, in chat, Q3): fix the HRRR Lambert-parameter
  extraction so wind rotation reads the file's own projection metadata** instead of the
  bounds-derived approximation ("not estimating based upon wobble we are causing because
  it is not reading properly"). Task spec in Phase W above; dispatches after Gate B.
- **2026-08-09 — Page-weight budget relaxed to a guideline (operator, in chat, Q2):**
  "we need to be mindful to ensure pages are as efficient as possible, but it should not
  be a hard rule." ADR-033 amended in place; reference/clearskies-dev.md baseline table
  reworded to per-chunk awareness tracking. Gate C's bundle row = record the numbers,
  no pass/fail on them.
- **2026-08-09 — `r` pinned = 1.0 (operator, in chat: "Q1: ok" accepting the
  recommendation).** Measured 1.0136/1.0559 vs the plan's [1.10, 1.35] mean-period
  premise; the gridded WVPER field behaves as (near-)peak period, so no mean→peak
  inflation is applied. Marine commit `5ebc1fa`. The named-constants block's bound is
  superseded for this constant by this ruling.

- **2026-08-08 — Tidal-current composite promoted from PINNED to scheduled (S1/S2/S4).**
  Operator directive in chat: the service area is the design target — "we are not designing
  for Huntington Beach." The RTOFS-region current field (open Atlantic/Gulf coasts, Hawaii —
  where tidal currents are strongest) was missing its tidal component; now composited from
  STOFS velocity per the S1 design. P7 register row amended accordingly.
- **2026-08-08 — Plan created.** Authority: L1-ISLAND-BOUNDARY-RELOCATION-BRIEF (rulings
  D1–D13). Operator instructions in chat: granular tasks, all design in-plan, QC gates, agent
  assignments, plan-as-architectural-permission, decisions now not later. Sequencing decision
  (this plan): W → B(current extent) → G(relocation) → S → A → V, so every deploy is one
  comparable change and the boundary contract lands before the grid moves.

---

# ❓ OPEN OPERATOR QUESTIONS — maintained by the coordinator; newest at top

*(Operator request 2026-08-09: questions live HERE so they don't get lost in agent
chatter. Each is self-contained: context, options, recommendation. Answered items move to
the decision log.)*

## Q6 — The relocated grid is live and healthier than before, but it came out much
## bigger than estimated, its south edge crosses San Clemente Island, and an internal
## safety check fired. Keep it, or roll back?

**Context, plain English:** The island-aware grid (Phase G) deployed today and has been
publishing all day. Everything the change was supposed to do, it did: Catalina is now
inside the model, the west boundary sits seaward of it, and the westerly wind-chop that
Catalina should block dropped by three-quarters while the southerly groundswell came
through untouched. The forecast now agrees with both nearby buoys within the tolerance we
declared in advance (we read about 20% below them; the allowance was 25%). The full run
takes 36 minutes (hard limit 45).

**The three things that need your ruling:**

1. **The grid is much bigger north-south than the brief estimated** — 131 km instead of
   ~57 km (the east-west size landed within 2% of the estimate). This is the ruled sizing
   arithmetic doing what it says: the 100 km open-water scan fan, pointed southwest,
   reaches far to the south, and nothing in the ruled design pulls the south edge back in.
   The brief's sketch underestimated that. Cost: the outer grid's compute time went from
   ~2 to ~14 minutes; total cycle 36 min (was 30 pre-G, budget 45). Memory check on the
   next run is armed; 300 MB is the stop line.
2. **The south edge happens to slice through San Clemente Island.** The plan's own rule
   (D11) says: where island geometry conflicts, the resulting envelope IS the answer, no
   flagging. The ~5–8 boundary points that fall on SCI land were fed from the nearest wet
   ocean data (the designed fallback); SWAN masks the land itself. It works, but "the
   boundary line crosses an island" is exactly the picture G3 said enclosure must avoid —
   I want your explicit OK that the envelope outcome is acceptable here, or a ruling to
   change it (that would be new design work, not in the current plan).
3. **An internal safety check fired during setup** ("L3 viability: structure unreachable
   by ~229 m — L3 disabled"). Same check class as the 2026-07-31 incident, which is why I
   stopped to surface it. **RESOLVED as pre-existing (journal evidence, 2026-08-09):** the
   identical line fired at the last pre-G config push on 2026-08-03 06:12:32Z
   ("unreachable by ~235 m") — Phase G did not cause it, and today's number is marginally
   BETTER (229 vs 235 m). The system falls back to the same coarse inner-grid layout it
   was already running (identical 51×46 dims), the pier grid still nests, runs normal.
   This is the already-tracked "smart-L3 disposition" open item (rules/coordinator.md
   §4b's example), not a Phase-G finding. Item 3 needs no ruling; items 1 and 2 still do.

**Options:** (a) accept the deviations, close G-Accept, proceed to Phase S (my
recommendation — every pre-declared reality check passed and the shadow physics is
visibly working; the size cost is real but inside budget); (b) keep it running but have
me investigate pulling the south extent in (design change → would need a plan amendment);
(c) roll back to the pre-G grid.
**RECOMMENDATION: (a)**, with the SCI-crossing and N-S-size facts recorded as accepted
deviations, and the L3-guard question resolved by the journal check either way.

## Q5 — Which internet address do we download the RTOFS ocean-current data from?

**Context, plain English:** Phase S adds a new data source — RTOFS, the Navy-style
global ocean model NOAA runs — to supply ocean currents in regions where no regional
model covers us. The plan named two ways to download it and said "try one, pick
whichever works." The problem: when the agent checked on 2026-08-09, **both** of the
plan's named download routes turned out to no longer exist on NOAA's side (one was a
download-helper page that was never set up for RTOFS; the other was a data service NOAA
retired across the board this year). The plan also says that when a measured answer
falls outside the bounds it wrote down, I must stop and ask rather than pick.

**The one route that DOES work (live-verified):** downloading the model's raw output
files directly from NOAA's NOMADS server (the same server, and the same file family, our
existing regional-current code already uses). Each file is about 155 MB and covers one
3-hour step; we would read just our small corner of it with the netCDF tools already in
the project. No new software dependencies.

**Options:** (a) approve the direct-download route just described — the only live one
found; (b) have me investigate further for other routes (e.g. subsetting servers that
would cut download size, but none NOAA-operated were found alive for RTOFS); (c) drop
RTOFS (this would leave open-Atlantic/Hawaii regions with no background current —
against the ruled design D9).
**RECOMMENDATION: (a).** It is the plan's own intent ("whichever works after one live
check"); the file size is larger than ideal but bounded (25 files per run window,
fetched once per cycle, same cadence as everything else). A separate finding — the
provider manual's table describing the retired service — gets fixed in the Phase S
doc-sync either way.

**Phase S sequencing while this is open:** S1 (currents) cannot dispatch without the
ruling. S2/S3 (water level, Hawaii datum) don't depend on it. The phase's two deploys
were already ordered currents-first; if this question is still open when the marine repo
frees up after G-Accept, I will dispatch S2+S3 work first and slot S1 in when ruled.

## ~~Q4 — Accept the new boundary's headline change?~~ ANSWERED 2026-08-09 (operator:
"the height change matches surfline and surf-forecast, so that is not a bad thing") →
**both deviations accepted, B-Accept CLOSED.** Moved to decision log. Original question
kept below for the record.

**Context, plain English:** The new wave-boundary system is deployed and running. When we
compared the new forecast against the old one for the same hour, the headline surf height
dropped 20.5% (from about 4.8 ft faces to about 3.8 ft) — the plan allowed at most a 15%
change. The full model run also took 3 minutes 17 seconds longer than the old one — the
plan allowed 3 minutes.

**Why the height change is probably GOOD news:** we checked the new numbers against the
two real ocean buoys near Huntington. The old system read the offshore waves 22–31% too
LOW and pointed the swell 35–40 degrees in the wrong direction. The new system reads wave
height within 12% of the nearer buoy, gets the wave period right, and the direction error
is gone. The 20.5% headline drop is the old, wrong boundary being replaced by a more
accurate one — which is the entire purpose of this plan. The 15% guardrail was written
assuming the old and new boundaries would describe similar water; the comparison itself
proved the old one was off.

**The extra 3 minutes:** the new system downloads 25 forecast files per run instead of 4
larger ones, inside the timed window. Total run: 30 minutes (the plan's hard budget in
Phase V is 45).

**Options:** (a) accept both deviations as measured-and-explained, close B-Accept, move
on to the wind-rotation fix (W6); (b) roll back to the old boundary and rethink.
**RECOMMENDATION: (a).** Every reality-check quantity improved; the service is healthy;
nothing was lost (the fallback protections all worked during the one failed attempt).

## ~~Q1 — Pin the `r` constant~~ ANSWERED 2026-08-09 ("Q1: ok") → **r = 1.0 pinned**,
marine commit `5ebc1fa`. Moved to decision log.

## ~~Q2 — page-weight speed limit~~ ANSWERED 2026-08-09 → **guideline, not hard rule.**
"Be mindful pages are as efficient as possible" — sizes recorded per file at round close
for awareness, no gate fails on the number. ADR-033 amended, dev-reference table updated.
Moved to decision log.

## ~~Q3~~ ANSWERED 2026-08-09 → **note 1: fix scheduled as task W6** (read the wind
grid's real rotation from the file; stop estimating; dispatches after Gate B closes so
one round runs in the repo at a time). Note 2 (missed "before" snapshot on R5) stands as
a recorded process miss, no action requested. Moved to decision log.
