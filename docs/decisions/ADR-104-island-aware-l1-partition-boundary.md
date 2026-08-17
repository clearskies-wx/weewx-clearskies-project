---
status: Accepted
date: 2026-08-08
deciders: shane
supersedes:
superseded-by:
---

# ADR-104: Island-aware L1 sizing and partition-reconstruction WW3 boundary

## Context

L1's offshore extent was `GSFM shelf distance + 10 km` (`services/swan_domain.py:1123-1132`). At Huntington
Beach that distance is ~9.7–10.3 km, so the boundary sat ~20 km out — mid-channel, inshore of Catalina Island
(33.31–33.48 N, 118.30–118.60 W, ~49–59 km from the pier). SWAN never modeled the island's sheltering; it
inherited WW3's own smeared rendering of it, because the fetch-fan horizon that would have detected the
island was itself derived from the same shelf distance (`services/geography.py:21-23,114-115,170-190`) — a
horizon of ~20 km is shorter than the ~49 km to Catalina, so every ray toward the island terminated in open
water and classified `directly_open`. The shelf-edge criterion is circularly self-blinding on any coast where
WW3's real failure is island sheltering, seaward of the geomorphic shelf — not a mis-drawn GSFM line, but the
wrong criterion. Full verification, literature, and as-deployed facts are in
`docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` §1–§2.

A relocated boundary is coupled to a second defect: the current WW3 L1 boundary is fed by real per-station
`.spec` spectra (ADR-103), selected against L1's own extent. A Catalina-enclosing boundary selects **zero**
qualifying stations under that rule (brief §5) — the in-channel four become interior points and no outer
catalogue station is within one native WW3 cell of the new boundary. Relocating the boundary therefore forces
a ruling on the boundary's data source in the same decision.

A third, independently discovered defect (brief §6): several silent fallbacks in the SWAN input chain —
wind cells outside the fetched bbox written as calm 0 m/s, current timesteps with no OFS match zero-filled,
no coverage check that the OFS domain contains the SWAN grid — produce plausible-looking output from
fabricated input. These violate the standing "a model runs on all its inputs or it does not run" rule
(rules/coding.md §1) and become materially more dangerous once L1 is extended, because an extended grid on
today's wind path would silently run becalmed at its offshore edge.

A fourth, related finding (brief §6 row 5, §7 note 6): the OFS current/water-level catalogue has no coverage
for open-coast East Coast, Gulf, Alaska, or the territories, and the single-CO-OPS-station uniform water
level stamp was justified in-code by a domain size ("~30 km, gradient negligible") that no longer holds once
L1 grows. The operator directed (2026-08-08, verbatim) that the system must be built for the **entire service
area** — "at NO POINT do we just build out for our TEST CASE" — not just Huntington Beach.

This ADR records the full set of operator rulings resolving these four coupled questions, given in chat
2026-08-08 and reproduced in full at brief §8 (D1–D13). It is the operator's own ruling record — not a new
proposal — per the plan's authority statement: "THIS PLAN IS THE ARCHITECTURAL PERMISSION" and its
Pre-approval register P1–P15.

## Options considered

Every option evaluated is recorded in the brief; summarized here per ruling.

| Question | Options considered | Chosen |
|---|---|---|
| Boundary criterion (island-aware sizing) | (a) keep shelf-anchored horizon; (b) decouple horizon from shelf + enclose to island far edge, with operator override; (c) (b) without override | **(b)**, D1 |
| Hard extent cap | (a) no cap (grid grows to enclose any island); (b) fixed 100 km cap with loud refusal naming what was left un-enclosed | **(b)**, D2 |
| Boundary data contract | (a) station `.spec` only (fails — zero qualifying stations post-relocation); (b) per-partition reconstruction from gridded WW3 fields; (c) hybrid (reconstructed + station-anchored) | **(b)**, D3 — hybrid explicitly rejected ("keep it simple and follow what our competition does") |
| Boundary point spacing | (a) one point per native WW3 cell (~18.5 km); (b) match L1's own cell spacing (1 km), interpolation done in our code before reconstruction | **(b)**, D4 |
| Silent fallbacks | (a) keep as documented "acceptable" mitigations; (b) convert to loud aborts, availability reported at setup | **(b)**, D5/D6 |
| Currents gap-filler | (a) leave East Coast/Gulf/AK/territories on eternal abort loop; (b) adopt RTOFS-Global, OFS-first selection | **(b)**, D9 |
| Currents tidal component in RTOFS regions | (a) RTOFS alone (non-tidal, incomplete); (b) RTOFS + STOFS-velocity composite | **(b)**, S1/S2 design, promoted from PINNED same day (decision log) |
| Water level source | (a) keep single-CO-OPS-station uniform stamp; (b) adopt STOFS-2D-Global, spatially varying, CO-OPS as fallback | **(b)**, D10 |
| Hawaii datum | (a) refuse (no VDatum coverage); (b) tidal-datum-offset conversion via CO-OPS `datums` product, refuse only for a geodetic-referenced source | **(b)**, D13 |
| Near-lee (un-enclosed island) shadow | (a) accept the boundary wherever geometry lands it; (b) pull the boundary edge away from an un-enclosed island's near-lee shadow, best-achievable, no reporting apparatus | **(b)**, D11 |
| Service area | (a) CONUS-only; (b) CONUS + Great Lakes + Hawaii, AK/territories descoped (reversible) | **(b)**, D7 amended by D12 |

## Decision

Adopted in full, as ruled (brief §8, D1–D13):

**D1 — Island-aware autosizing.** The ocean fetch-fan horizon is decoupled from shelf distance. L1's offshore
extent enclosing a wrap-candidate island is sized to the island's far edge plus a margin, not the full
horizon. An operator override (`[swan] l1_offshore_extent_km`) replaces the autosized extent; the override is
exposed in the admin UI, not just a config-file key. When an island sits at or beyond the cap and cannot be
enclosed, the autosizer must detect it and avoid placing the boundary in that island's near-lee shadow (D11).

**D2 — 100 km hard cap.** `L1_MAX_EXTENT_KM = 100.0`. An island that cannot be enclosed within the cap is not
enclosed; its shadow is a recorded residual, mitigated by D11's near-lee avoidance, never silently clipped.

> **SUPERSEDED FOR L1 (ADR-108, 2026-08-13).** The 100 km cap and the island-avoidance siting
> rationale (D1's enclosure + D11's near-lee clamp) are superseded FOR L1 by ADR-108's
> island-containment approach: L1 extends to **contain** both Catalina and San Clemente (SW corner
> 32.60°N, 119.25°W; cap raised to 175 km FOR L1 ONLY), and switches to true non-stationary
> compute (`COMPUTE NONSTAT` dt=10 MIN) — eliminating the stationary-validity constraint that
> motivated the 100 km cap. The cap, the per-axis clamp, the near-lee machinery, and the Great
> Lakes exemption all remain in effect for non-L1 levels and regimes. See ADR-108 for the full
> ruling record.

**Amendment 2026-08-09 (operator ruling, in chat; plan Q6/G9):** the cap binds the **L1 BOX SIZE per
axis**, not each scan ray's reach from the spot. The Phase-G implementation shipped the per-ray reading and
produced a 91×131 km live box — no single ray exceeded 100 km, but the envelope of the fan did, and L1's
hourly stationary solves cannot physically support a 131 km span (15 s swell crossing time ~3.1 h vs the
1 h forcing step). Operator: "The 100km is not supposed to be a cap on the length of the ray, it is
supposed to be a cap on the box size itself." Switching L1 to nonstationary computes was REJECTED in the
same ruling ("compute unwieldy"). Enacted by plan task G9: a final envelope clamp pulls in only the
offshore edge of any axis exceeding the cap; coast-side edges never move; the per-ray logic remains as the
candidate-generating pre-filter. **Implementation note (2026-08-09, deployed marine `3065289`):** the
per-axis offshore side resolves from `_offshore_sides()` by cardinal MEMBERSHIP — the function returns a
closeness-ranked pair, not an axis-ordered one (`91b6e2d` fixed a positional unpacking that was correct at
HB only by coincidence and would have moved the coast edge on east-facing coasts). **Great Lakes regime is
EXEMPT from the box clamp** (lead ruling, plan-contradiction resolution: the GL fetch+10 sizing is
deliberately uncapped by design and pinned by test; whether this cap should extend to lakes is an open
operator question — L1-BOUNDARY-REBUILD-PLAN §OPEN OPERATOR QUESTIONS, G9-GL).

**D3 — Boundary data contract: per-partition reconstruction, no hybrid.** The L1 offshore boundary is built
by reconstructing a full 2-D spectrum at every boundary point from NOAA's gridded WW3 partition fields
(ocean `gfswave.global.0p16`, Great Lakes `glwu.grlc_2p5km`) — per-partition bulk parameters (wind sea
WVHGT/WVPER/WVDIR; up to 3 swell trains SWELL/SWPER/SWDIR) summed into one true 2-D file per point. The
per-station `.spec` boundary path (ADR-103) is superseded for L1. This supersedes, for this specific
summed-per-partition-2-D-file form only, the 2026-07-26 `VARIABLE PAR` rejection — that rejection's
multimodality concern (one parametric train collapsing multi-swell seas) is preserved by construction, since
each partition remains its own train inside a true 2-D file. `VARIABLE PAR` itself stays forbidden.

**D4 — Boundary point spacing = L1's own cell spacing (1 km).** One reconstructed 2-D spectrum is emitted at
every L1 boundary cell. Interpolation of the WW3 partition parameters between the outer model's coarser
cells happens in Clear Skies' own code, in parameter space per partition (directions interpolated as unit
vectors), before reconstruction — SWAN is never asked to interpolate between two distant spectra. Boundary
file volume/SWAN read time must be measured at accept; infeasibility is a STOP-and-surface, never a silent
narrowing of the spacing.

> **SUPERSEDED 2026-08-10 (ADR-106 R1, PA1; `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md`).** This
> D4 ruling — and P4's per-L1-cell-spacing wire form of the same ruling — is superseded. Live measurement
> after Phase B deployed (fixit log Item 1) found the deleted-spatial-averaging premise of D4 was itself the
> root cause of a slot-mixing defect: averaging each WW3 partition slot by NUMBER across the four surrounding
> cells (the D4-mandated "our own code" interpolation) does not guarantee the same physical wave system, and
> a live corridor survey proved adjacent cells carry unrelated systems in the same slot number. D4's own
> justification — spacing at L1's 1 km cell size specifically so SWAN never interpolates between two DISTANT
> spectra — is superseded because that fear was station-era (stations sat 100+ km apart); adjacent WW3 cells
> are ~16 km apart, and SWAN's own documented mixture between 16-km-separated neighbors is the wanted
> behavior, not a risk to avoid. **New ruling (ADR-106 R1, `(ruled 2026-08-10; lands with Phase B2 of
> MARINE-PAGE-FIXIT-PLAN)`):** the per-L1-cell spatial sampling layer in `services/boundary_reconstruction.py`
> is deleted; boundary positions become one per wet WW3 cell along each offshore side (plus two endpoint
> byte-copies), built purely from that cell's own partition values, with SWAN's own spectral interpolation
> (SWAN manual §2.6.3) filling the space between. See ADR-106 for the full ruling record.

**D5 — Setup-time availability reporting + pull-to-the-grids.** Data-source viability is decided at setup;
setup must tell the operator when data is not available for the configured location, and why. Runtime keeps
its loud aborts, but structural absences must be caught at setup, not discovered as an eternal abort loop.
All input fetches are derived from the actual model grids — wind bbox from the L1 domain, coverage asserted
for wind/wlevel/currents the way bathymetry already is.

**D6 — Wind coverage fix.** Wind fetch bbox is derived from the L1 domain plus margin; coverage is asserted
at fetch time; the calm-fill (NaN → 0.0000 m/s) is replaced with a hard abort. This lands before or with any
L1 extension (sequencing prerequisite — an extended grid on the old wind path would silently run becalmed at
its offshore edge).

**D7 (amended by D12) — Service area.** CONUS + Great Lakes + Hawaii. Every input chain must either serve
every region in scope or refuse at setup with the reason (D5) — no region discovers its gap as a runtime
abort loop. Alaska and the territories are descoped (reversible; D12).

**D8 — Region-aware wind sourcing.** HRRR CONUS for CONUS; HRRR-AK for Alaska (dormant per D12's descope);
GFS-alone wherever no HRRR product exists (Hawaii, territories).

**D9 — Currents: RTOFS adopted, OFS-first.** SWAN current-forcing source selection at setup: an OFS model
whose domain covers the L1 grid wins; RTOFS-Global everywhere else. Fills every currents gap in the D7
matrix. RTOFS is non-tidal (circulation only, no tidal current). Tidal-current compositing (promoted from
PINNED to scheduled the same day, decision log): in RTOFS regions the served current field per cell per
timestep is `u = u_RTOFS + u_STOFS`, `v = v_RTOFS + v_STOFS` — no double-counting by construction, since
RTOFS carries zero tidal signal and STOFS zero circulation. A timestep where either component is missing
raises rather than compositing a partial current. OFS regions never composite (OFS models are already
tidal-inclusive).

**Amendment 2026-08-09 (operator "ok fine" on the lead-researched replacement; plan register P7 amended,
decision log):** the composite is VOID — its premise field does not exist. Live inspection (regional GRIB2
via eccodes, global netCDF headers) and NOAA's own NOMADS STOFS description confirm **STOFS-2D-Global
publishes no velocity in any product** (water levels only). Replacement: a containment LADDER of
tidal-inclusive sources — regional OFS → STOFS-3D-Atlantic total-current velocity (US East/Gulf/PR; 3-D
baroclinic, so its velocity already carries circulation+tide+surge and is used ALONE) → PacIOOS ROMS Main
Hawaiian Islands (Hawaii; TPXO tidal elevation+velocity forcing, 4 km/3-hourly, ERDDAP/THREDDS) →
~~RTOFS-Global alone (non-tidal, loudly logged, last resort)~~. **Amendment 2026-08-09 (operator, in
chat, same day): the RTOFS-alone rung is REMOVED — "The fallback is not a fallback... it is missing
information... garbage data." Ladder exhausted → REFUSE (`CurrentCoverageError` →
`currents_fetch_failed`-class no-publish naming the uncovered bbox). Non-tidal-only currents are missing
required input; a site no tidal-inclusive source contains does not run. The three remaining rungs blanket
the D12 service area (West Coast + Great Lakes: regional OFS; East/Gulf/PR: OFS + STOFS-3D-Atl; Hawaii:
PacIOOS ROMS), so the refusal is a coverage-hole tripwire surfacing at setup time, not an expected runtime
path. No RTOFS module is created; the direct-NOMADS route research is retained in PROVIDER-MANUAL §14.10a
as historical record.** No summing on any rung; per-cycle source
selection, never per-timestep. See PROVIDER-MANUAL §14.10a (rewritten) and plan Q5 closure block.

**D10 — Water level: STOFS adopted.** STOFS-2D-Global becomes the spatially-varying WLEVEL source at all
levels, replacing the single-CO-OPS-station uniform stamp. ~~Chain: STOFS → CO-OPS-uniform (loud fallback,
logged) → refuse (`tide_fetch_failed`). A cutover bias gate (24 h of STOFS at the tide-station cell vs
CO-OPS predictions, `|mean bias| ≤ 0.15 m`) must pass before STOFS becomes primary; breach → CO-OPS stays
primary, STOP and surface.~~
**AMENDED 2026-08-11 (operator ruling in chat, MARINE-PAGE-FIXIT-PLAN Phase T: "ONE SOURCE. THAT IS
IT."): the CO-OPS fallback rung is REMOVED from the model water-level path.** Water level = STOFS,
period, for every run type (full cycles AND the hourly stationary fill, which previously ran
CO-OPS-uniform forcing) and for every model consumer (SWAN WLEVEL forcing, the 1-D surf pipeline's
per-timestep tide, the beach-profile serving path — all sample the same STOFS field). STOFS
unavailable → the run REFUSES loudly (`tide_fetch_failed` no-publish); no fallback, no uniform stamp,
no substituted value. Context: the original chain's S2 implementation orphaned the non-SWAN consumers
(silent tide=0.0 from 2026-08-09 22:09Z; see MARINE-PAGE-FIXIT-PLAN Phase T + TIDE-TRACE findings);
the never-run Gate S bias check is superseded by this removal. CO-OPS remains in use ONLY by
display/informational consumers outside the model path (tide charts, fishing/beach-safety overlays).
Landed: marine `53eea82` + `a8a27e2`.

**D11 — Near-lee fallback criterion, CLOSED.** For every blocking island that cannot be enclosed (a
wrap-candidate whose enclosure would exceed the D2 cap, or a truly-blocked ray beyond the base offshore
extent): compute, per affected bearing sector, the island's cross-swell width `W` and
`L_fill = W / (2·tan σθ_ref)` — the down-wave distance at which the directional-spreading cones from the
island's two edges meet and the shadow's un-refilled core closes. Where the boundary rectangle can sit
`≥ k·L_fill` down-wave of the island along those bearings without violating the cap or another island's
enclosure requirement, it must. Where geometry conflicts and no compliant position exists, the sizer takes
the maximum achievable down-wave distance, and **that is the behavior — there is no flagging apparatus**.
Constants ratified: `σθ_ref = 15°`, `k = 1`. **The distinction, stated exactly as ruled, binding on every
future case:** missing data → refuse loudly with the reason (D5); constrained geometry → best physical
answer, silently (D11). The two are never conflated. The sizing trace keeps its ordinary engineering record
(bearings, achieved km) for debugging — nothing more.

> **Implementation note (lead ruling 2026-08-09, Phase G; operator may override before the G-Accept
> deploy):** D11 as ruled did not define an un-enclosable cluster's angular extent for the chord width
> `W = mean(first_land) × angular_extent_rad`. Ruled: `angular_extent_rad = radians((bearing_max −
> bearing_min) + one 5° ray step)` over the cluster's blocked rays — each ray represents its own 5° fan
> sector (the same semantics the clustering gap test "≤ 2 ray steps" uses), so a contiguous N-ray cluster
> subtends N×5° and a single blocked ray subtends 5°, never zero (a zero-width island would receive no
> clamp at all, contradicting this ruling's purpose). Implemented in
> `services/swan_domain.py::_near_lee_max_extents()` (marine `3f98613`), KAT-pinned with hand-derived
> literals (`tests/test_island_autosizing.py`).

**D12 — Service area amended.** CONUS + Great Lakes + Hawaii; Alaska and the territories descoped. The
descope is reversible — the D7 coverage matrix retains the AK/PR-USVI/Guam-AS columns as the re-entry
record; any future re-entry reopens exactly those gap cells. Hawaii is the one hard remaining problem
(datums, D13); Hawaii wind/currents/wave-boundary/geometry are already covered by D8/D9/gfswave/D1.

**D13 — Hawaii datum strategy, CLOSED.** VDatum does not cover Hawaii and Hawaii has no NAVD88 at all — every
relevant Hawaii source (ETOPO L1, all three indexed Hawaii DEMs) is already tidally referenced (MSL or MHW).
The only conversion Hawaii ever needs is MHW→LMSL, plain tidal-datum arithmetic from the CO-OPS `datums`
product at the nearest station (or interpolated between an island's stations), applied across the L2/L3
domain. A geodetic-referenced source (NAVD88 etc.) appearing in a no-VDatum region is refused, never
approximated. Precedent: the existing Great Lakes LWD/IGLD85 region-dependent datum branch.

### Named constants (fixed by this decision, not re-derivable by implementers)

`L1_MAX_EXTENT_KM = 100.0`; enclosure margin `10.0 km` (reuses the existing offshore-margin convention);
near-lee `SIGMA_THETA_REF = 15°`; `K_FILL = 1`; swell spread `σθ = 15°` (cos²ˢ `s = 28`); wind-sea spread
`σθ = 30°` (`s = 7`); swell frequency shape Gaussian `σf = 0.015 Hz`; wind-sea shape JONSWAP `γ = 3.3`;
boundary point spacing = L1 `dx` (1 km); wind bbox pad `0.3°`; STOFS cutover bias gate `≤ 0.15 m`.

Two constants are **measured then pinned** — the method is decided here, the value is measured at
implementation, within a bound:
- B2's `r` (wind-sea mean→peak period ratio): bounds `[1.10, 1.35]`, measured vs 3 live `.spec` cycles.
  **Amendment 2026-08-09 (operator ruling, plan decision log):** the measurement came in below the floor
  (1.0136/1.0559); the operator ruled the gridded `WVPER` field behaves as (near-)peak period and pinned
  **`r = 1.0`** (no mean→peak inflation; marine commit `5ebc1fa`). The bound above is superseded for this
  constant; the out-of-bounds → STOP-and-surface protocol was followed and is unchanged for future constants.
- S1's RTOFS endpoint choice: NOMADS grib primary, ERDDAP griddap alternate, pinned after one live shape
  check.

Out-of-bounds measurement → STOP and surface, do not pick.

## Consequences

- **New config key:** `[swan] l1_offshore_extent_km` (P3), operator override, admin-exposed.
- **Data contract change:** L1 boundary spectra are gridded-WW3-partition-reconstruction, not per-station
  `.spec` files (P4). `services/ww3_station_selection.py`, `services/ww3_station_catalogue.py`,
  `data/ww3_station_catalogue.json` are deleted, and the station-fetch half of `services/ww3_spectrum.py` is
  removed (the Appendix-D spectrum writer is extracted and kept) (P5).
- **New providers:** RTOFS surface currents (P7); STOFS-2D-Global water level (P8).
- **New silent-fallback-to-abort conversions:** wind out-of-coverage (P6), current timestep/shape gaps.
- **New setup-time reporting:** per-input source/coverage report surfaced through the config chain to admin
  (P10).
- **Service area amended:** CONUS + Great Lakes + Hawaii; Alaska/territories descoped, reversibly (P11).
- **DEM index refresh:** Maui + Big Island entries added; PR low priority (P12).
- **Datum branch:** Hawaii tidal-offset conversion via CO-OPS `datums`; NAVD88 in a no-VDatum region refuses
  (P9).
- **No fallback-tier reintroduction:** ADR-103's refuse-don't-degrade posture for the L1 boundary is
  preserved in spirit — the reconstruction path refuses (raises) on missing fields/steps/wet-cell coverage,
  never substitutes.
- **Wind/current/wlevel fabricated defaults removed:** the NaN→calm wind fill, the current zero-fill block,
  and the single-CO-OPS-station uniform WLEVEL stamp are deleted, not conditioned.

## Acceptance criteria

- [ ] `L1_MAX_EXTENT_KM = 100.0` is a single module constant in `services/geography.py`; `swan_domain.py`
  imports it; every extent computation clamps to it.
- [ ] A wrap-candidate island encloses at `open_water_resume_km + 10.0 km`, capped at `L1_MAX_EXTENT_KM`; an
  island whose enclosure would exceed the cap is not enclosed and joins the near-lee set.
- [ ] The near-lee clamp reproduces `L_fill = W / (2·tan 15°)`, `k = 1`, exactly, on a hand-computed fixture;
  a constraint conflict resolves to the maximum-achievable position with no flagging output.
- [ ] `[swan] l1_offshore_extent_km` overrides the autosized extent end-to-end (set → sized → enclosures
  suppressed), validated against the cap at config-push, admin-exposed.
- [ ] The L1 boundary is built from per-L1-cell reconstructed 2-D spectra (spacing = L1 `dx`), not per-station
  `.spec` files; no surviving import of the deleted station-selection modules.
- [ ] `VARIABLE PAR` is never emitted anywhere in this path.
- [ ] A missing WW3 field/step, or a boundary point with no wet WW3 cell within 2 cells, raises rather than
  substituting a value.
- [ ] Wind/current/water-level out-of-coverage conditions raise (with the offending extent/count named)
  rather than filling calm/zero/uniform defaults.
- [ ] Current-source selection is containment-based (OFS domain contains the L1 bbox), not centroid-based;
  RTOFS is the fallback everywhere no OFS qualifies; the RTOFS+STOFS tidal composite applies only in RTOFS
  regions, never OFS regions.
- [ ] WLEVEL chain is STOFS → CO-OPS-uniform (logged) → refuse; the cutover bias gate is checked before STOFS
  becomes primary.
- [ ] Hawaii's datum path converts MHW→LMSL via CO-OPS `datums`; a geodetic-referenced source in a no-VDatum
  region raises.
- [ ] Setup-time reporting surfaces a real refusal end-to-end (drill: remove a structural input, refusal
  visible in the admin sources panel).
- [ ] Service area coverage matrix (D7, amended D12) is current in this ADR and in ARCHITECTURE.md.

Checked at Gate DOC (this document's own completeness), and at each implementing phase's own QC gate
(W/B/G/S/A) against the specific criteria that phase lands.

## Implementation guidance

- **SWAN command syntax is pre-researched and pinned** — see the plan's "SWAN SYNTAX PRESCRIPTIONS" section
  (`docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md`) for the exact `BOUNDSPEC`/Appendix-D grammar, the
  `[len]` corner-walk convention, and the commands pinned unchanged (`CGRID`, `INPGRID`/`READINP` families,
  `GEN3`/`SETUP` physics blocks, `INIT HOTSTART`, nest chain). Implementers use that grammar exactly; a
  mismatch against the local SWAN manual is a finding to surface, never a license to improvise.
- **Execution order is strict:** Phase W (wind hardening) precedes Phase B (boundary at current extent)
  precedes Phase G (relocation) precedes Phase S (sources) precedes Phase A (admin surfacing). Phase C
  (display) is independent and interleaves after the SURF-REMEDIATION R5 round closes. Rationale: B lands the
  reconstruction boundary at the CURRENT extent first for direct comparison against the station-boundary
  baseline; G then moves the grid and the reconstruction adapts automatically (no B-side code change needed —
  the decoupling proof).
- **Out-of-scope for this ADR:** the L3/L4 nesting boundary (`BOUNDNEST1`, internal to SWAN's own grid chain),
  the SWAN→SwellTrack handoff (ADR-093), any physics formula inside SWAN itself, and the directional
  resolution `CIRCLE 72` (a separate, deferred, operator-gated decision — see the plan's PINNED section).
- **Files this governs:** `services/geography.py`, `services/swan_domain.py`, `services/swan_formats.py`,
  `services/swan_runner.py`, `services/grid_sizing_chain.py`, `services/ww3_partition_fields.py` (new),
  `services/boundary_reconstruction.py` (new), `providers/ocean/rtofs_currents.py` (new),
  `providers/ocean/stofs_wlevel.py` (new), `services/vertical_datum.py`, `config/marine_config.py`,
  `providers/nearshore/swan.py`. Exact call sites and line-number hints are in the plan's per-task tables —
  verify against actual file state before acting (plan PRIME DIRECTIVE 7: line numbers are hints, not
  gospel).

## Amendment (2026-08-17): scope note vs the WW3 deep-water leg — ADR-109

**Status: Accepted.** Recorded by the DOC-W.5 full-index ADR impact sweep
(`docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md`, Phase DOC-W, task DOC-W.5), following
acceptance of **ADR-109** ("WW3 deep-water leg"). Pointer + scope note only — no ruling above is
re-opened.

**L1-sizing rulings — SUPERSEDED-AT-V5 (tag only; the supersession note itself lands at Phase V5,
never before).** D1 (island-aware autosizing) and D2 (the 100 km hard cap, already superseded for L1
by ADR-108 at 175 km — see D2's own supersession note above) govern the **live SWAN-L1 serving
path** and continue to do so until at least Phase V4's cutover verdict, and indefinitely under a
verdict-2 or verdict-3 ruling (ADR-109 D15). They are tagged SUPERSEDED-AT-V5 because L1's own
offshore-domain-sizing job is exactly the job ADR-109's WW3 leg takes over if and when Phase V5 rules
retirement of the SWAN-L1 path — at that point D1/D2's L1-sizing rulings become moot, not before.

**Reconstruction (D3), no-silent-fallback (D5/D6), and whole-service-area (D7/D12) rulings — CARRY
FORWARD unchanged, NOT tagged.** These rulings are not about L1's domain size — they are about *how*
a boundary is built once a domain exists (D3: per-partition reconstruction from gridded WW3 fields,
refuse-don't-degrade), *how loudly* missing inputs are handled (D5/D6: setup-time availability
reporting, hard aborts over silent fallbacks — the "a model runs on all its inputs or it does not
run" rule, rules/coding.md §1), and *what geographic area* the system must serve (D7/D12: CONUS +
Great Lakes + Hawaii, every input chain must serve or refuse with a reason). None of these are
domain-boundary-specific to L1 — they apply identically to the WW3 leg's own boundary-assembly and
setup-time reporting (ADR-109 D5/D6/D9's own refuse-don't-degrade posture, W2/W4's own no-silent-
default logging requirement, PRIME DIRECTIVE 11). They carry forward into the WW3 leg unchanged and
are explicitly **not** part of this SUPERSEDED-AT-V5 tag.

## References

- Brief: `docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` — full findings, literature,
  as-deployed facts, and rulings D1–D13 (§8) this ADR records.
- Plan: `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — Pre-approval register (P1–P15), named
  constants block, SWAN syntax prescriptions, per-phase task design.
- Related ADRs: ADR-093 (SWAN nearshore model — amended, boundary/inputs sections point here); ADR-100
  (geography-aware study-area geometry — amended, horizon/enclosure sections point here); ADR-103
  (multi-station real spectral boundary — amended, superseded for L1 when Phase B lands); ADR-091 (ocean data
  resolver, water-level compositor — consumed by the RTOFS/STOFS selection rules); ADR-109 (WW3 deep-water
  leg — Amendment above, DOC-W.5).
