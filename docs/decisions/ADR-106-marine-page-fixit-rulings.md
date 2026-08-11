---
status: Accepted
date: 2026-08-10
deciders: shane
supersedes: ADR-104 (D4/P4 boundary-point-spacing ruling only, see below); ADR-102 (published break-marker/impact-zone section only, see below)
superseded-by:
---

# ADR-106: Marine page fixit rulings 2026-08-10 — per-WW3-cell boundary, ranged headline fields, decoupled break markers + fixed crash band

## Context

The operator's live review of the surf/marine pages on 2026-08-10 (screenshots + a same-day
diagnostic pass) surfaced six defects/gaps; six operator rulings resolved them in chat the same
day. The full evidence — buoy/Surfline comparisons, code traces, live-data captures — is recorded
in `docs/planning/MARINE-PAGE-FIXIT-2026-08-10.md` ("the fixit log"); the rulings are turned into
granular tasks in `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md` ("the fixit plan"), whose
PRE-APPROVAL REGISTER (PA1–PA6) is the authorization for every architectural change this ADR
records. This ADR is the decision record; it does not restate the evidence beyond what is needed
to explain each ruling, and it records no ruling the fixit plan does not already authorize.

This document is written entirely from the fixit log and the fixit plan — no code has shipped for
PA1–PA5 as of this writing (Phase DOC precedes all code work, operator instruction 2026-08-10).
Every consequence below is future/target state, tagged per the fixit plan's own convention.

### Item 1 — the swell list doesn't match Surfline or the buoys (slot-mixing defect)

Full trace: fixit log Item 1. The dashboard's served swell list (1 groundswell + 2 windswells, no
west train) diverged sharply from Surfline's spot card and five buoy cards, which showed 3–5
directionally distinct trains spanning 114° of bearing. Root cause, confirmed in code
(`boundary_reconstruction.py:442-446` with `:383-407`): the L1 boundary reconstruction averaged
each WaveWatch III (WW3) "swell slot" (1, 2, 3) across the four surrounding grid cells **by slot
number** — height with height, period with period, direction with direction — but NOAA does not
promise slot 2 means the same physical wave system from one cell to the next. A live corridor
survey proved adjacent cells carry unrelated systems in the same slot (slot 2 = 9.8 s west swell
277° next to slot 2 = 3.6 s chop 259° next to slot 2 = 8.7 s SSE 172°). Averaging across misaligned
slots fabricated trains that exist nowhere (a 10 s west swell averaged with 4 s chop produced the
served 7.2 s @ 264° "west" train), annihilated real trains (no distinct 277° or 172° train survived
to the edge file), and homogenized directions.

Operator follow-up, verbatim, recorded in the fixit log: *"why average at all — why not plug each
WW3 cell's swells straight into the adjacent L1 boundary cells?"* Answer, and the ruled direction:
*"Let SWAN do the interpolating... We should not be interpolating and then having SWAN interpolate
our interpolation."* SWAN's own `BOUNDSPEC` boundary command interpolates between listed positions
bin-by-bin — a true mixture (an in-between point carries both neighbors' trains at partial
strength, never averaged periods or directions).

### Item 2 — the three headline numbers should be ranges, but show single values

Full trace: fixit log Item 2. Swell Height was working as designed (an honest single-number
collapse when only one swell is surfable). Breaking Face Height was wired to the wrong field — the
spread across *swell trains* (collapses to one number whenever one swell dominates) rather than
the spread across the *best-surf strips of beach* (`modelSurfHeightMin`/`Max`, already computed and
served, held a real 3.4–3.6 ft range at the screenshot's hour). Period had no range field at all:
the server sends one energy-weighted `combinedPeriodS`.

Operator ruling, verbatim: *"the period should never be combining periods, that is not how the
physics works."* Periods of separate wave trains do not combine into a meaningful average; a range
is the physically honest representation.

### Item 4 — the second break isn't marked, and the impact zone is wrong

Full trace: fixit log Item 4. Break markers only publish when breaking CEASES (Q_b falls back
below 2%); on the operator's beach the breaking fraction never drops below 2% between the outer
break and the sand, so the outer and inner breaks glue into one zone with one marker — the beach
break, which visibly crashes, gets nothing. The same glue produces an over-wide impact zone (262 m
→ 19.5 m from the waterline on the sampled hour) because nothing bounds it once no second break
exists to stop it at.

Operator ruling, in substance: the break zone is where the wave CRASHES, not where it produces
whitewater; the crash happens in one place; a surfer needs to know where to paddle out behind, not
how long the broken wave rolls. **The impact zone becomes a fixed-width crash band per break
marker**, and **marker detection decouples from the stopped-breaking machinery** — each distinct
crash point (a local peak of energy loss above threshold) gets its own marker, independent of
whether breaking later ceases. The breaking-onset threshold (today a fixed 5% Q_b constant) and the
crash-band width both become operator-adjustable configuration, tuned against the webcam rather
than re-derived by the model. The safety ruling stands: the band never crosses the waterline
(swash is never included). At GO (2026-08-10), the operator confirmed the proposed default crash-
band width: **"25m proposed crash-band width is fine"** — CONFIRMED, not proposed, per this ADR.

## Options considered

| Question | Options | Chosen |
|---|---|---|
| Item 1 boundary fix | (a) keep averaging, fix only the slot-alignment bug; (b) cross-cell train-matching (re-pair slots by nearest period/direction across cells); (c) emit one spectrum per wet WW3 cell, no spatial mixing, let SWAN interpolate; (d) our own 1-km-point spectrum mixture (no averaging, more code) | **(c)**, PA1 — (b) explicitly DROPPED (fixit log Item 1); (d) retained as a documented fallback only if SWAN's mixture proves unacceptable at accept |
| Item 1 boundary point spacing | (a) keep 1-km L1-cell spacing (ADR-104 D4); (b) one position per wet WW3 cell along each side, plus two endpoint copies | **(b)**, PA1 — supersedes ADR-104 D4/P4 |
| Item 2 Breaking Face Height source | (a) keep the per-swell-train spread; (b) rebind to `modelSurfHeightMin`/`Max` (best-surf-strip pair, already served) | **(b)**, PA2 |
| Item 2 Period | (a) keep `combinedPeriodS` (energy-weighted mean); (b) new `periodMinS`/`periodMaxS` range fields, `combinedPeriodS` retired | **(b)**, PA2 |
| Item 4 breaking-onset threshold | (a) fixed constant, no operator control; (b) operator-adjustable config key, default = today's value | **(b)**, PA3 |
| Item 4 impact zone | (a) keep whitewater-decay-driven zone (roller energy floor); (b) fixed-width crash band per marker, config-adjustable width, clipped at the waterline | **(b)**, PA3/PA4 |
| Item 4 marker detection | (a) keep cessation-gated marker publication; (b) decouple markers from cessation — one marker per local dissipation maximum above onset, subject to a prominence rule | **(b)**, PA4 |

## Decision

Adopted in full, as ruled (fixit log Items 1, 2, 4; fixit plan PA1–PA5). Every item below is
**future/target state as of this ADR's acceptance** — it lands with the fixit plan phase named,
and carries that phase's tag until the phase's own doc-sync removes it.

**R1 — Boundary data contract: one spectrum per wet WW3 cell, SWAN interpolates.** *(PA1;
supersedes ADR-104 D4/P4, `(ruled 2026-08-10; lands with Phase B2 of MARINE-PAGE-FIXIT-PLAN)`)*
The spatial parameter-interpolation layer in `services/boundary_reconstruction.py` (bilinear/
nearest-wet sampling across four surrounding WW3 cells) is DELETED — it is the confirmed root cause
of the slot-mixing defect. In its place: for each offshore side, select the WW3 cell row/column
nearest that side; every wet cell whose centre projects within the side's span becomes one boundary
position, built purely from that cell's own partition values (no spatial mixing). The two side
endpoints (`len = 0.0` and `len = side length`) are byte-copies of the nearest selected cell's
spectrum file, guaranteeing full-side coverage. `BOUNDSPEC SIDE ... VARIABLE FILE` command grammar
is unchanged; SWAN's own documented spectral interpolation between listed positions (SWAN manual
§2.6.3, cited verbatim in the fixit plan's SWAN SYNTAX PRESCRIPTIONS) does the work the deleted
layer used to do badly. Viability floor: fewer than 2 wet cells on a side raises
`BoundaryNotViableError` (existing refusal role, unchanged). All single-cell spectrum-construction
math (JONSWAP wind-sea, Gaussian swell shapes, cos²ˢ directional spreads, normalization, bin-sum
identity guard, HTSGW-inconsistency guard) is UNCHANGED — this ruling changes WHERE a spectrum is
built (per cell, zero spatial averaging), never HOW a single cell's spectrum is built. Why ADR-104
D4's 1-km spacing is superseded, not merely revised: D4 existed to stop SWAN interpolating between
DISTANT spectra — a station-era fear, when boundary sources sat 100+ km apart. Adjacent WW3 cells
are ~16 km apart; SWAN mixing between neighbors 16 km apart is exactly the behavior this ruling
wants, not a risk to avoid.

**R2 — Surf wire shape: period range replaces combined period; face-height range rebinds; dead
fields removed.** *(PA2, `(ruled 2026-08-10; lands with Phase S of MARINE-PAGE-FIXIT-PLAN)`)*
New served fields `periodMinS`/`periodMaxS` = lowest/highest peak period across the eligible
surfable swells (same eligibility rule as today, including its existing no-qualifier-fallback
behavior — RULED to stay as-is, fixit log Item 2 recommendation 3). `combinedPeriodS` is REMOVED
from computation and the served response — operator, verbatim: *"the period should never be
combining periods, that is not how the physics works."* `faceHeightMinFt`/`faceHeightMaxFt` are
also REMOVED — their sole consumer (the Swell Card) rebinds to the already-served
`modelSurfHeightMin`/`modelSurfHeightMax` (the best-surf-strip pair), which is what the operator's
original Breaking Face Height definition actually describes. `swellHeightMinFt`/`MaxFt` and
`modelSurfHeightMin`/`Max` computations are untouched. The card's Period display shows the new
range (single number when min = max, same collapse rule the other ranges already use).

**R3 — Adjustable breaking-onset threshold and fixed crash-band impact zone.** *(PA3/PA4,
`(ruled 2026-08-10; lands with Phase K of MARINE-PAGE-FIXIT-PLAN)`)* Two new operator-adjustable
config keys: `[surf] qb_breaking_onset` (float, default **0.05** — today's `Q_B_VISIBLE` constant,
unchanged value, now config-controlled) and `[surf] impact_zone_width_m` (float, default **25.0
m** — CONFIRMED by the operator at GO 2026-08-10, "25m proposed crash-band width is fine"; both
adjustable at runtime, validated at config push). Published break markers decouple from the
breaking-cessation state machine (`Q_B_CESSATION`, unchanged, becomes internal-physics-only): after
the wave-height march completes, markers are derived from the recorded per-step dissipation series
— candidate regions are contiguous runs where `Qb_i ≥ qb_breaking_onset`; within each region, a
local maximum of dissipation publishes a marker only if its topographic prominence is ≥30% of the
region's tallest maximum (`_BREAK_PROMINENCE_FRACTION = 0.30`, a pinned constant, not a config
key — keeps noise ripples from publishing spurious markers); each kept maximum, after the existing
`_MIN_BREAK_DEPTH_M`/`_MIN_BREAK_HS_M` publication filters (unchanged), becomes one published
marker. This is a deliberate, operator-accepted dependency: multi-bar profiles can now publish
multiple markers per region even when Q_b never dips between them — the whole point, since that was
the exact case the beach break's missing marker demonstrated. The published impact zone is
REDEFINED as a fixed-width crash band per marker: `impactZone = [d_m, max(d_m −
impact_zone_width_m, waterlineDistance)]`, clipped at the waterline (the swash-exclusion safety
ruling carries over unchanged), bands may overlap when markers sit closer than the width (served as
computed, no merging). `foamZone` becomes pure geometry — the shoreward edge of the most shoreward
band to the waterline — with no roller-energy term. `reformTrough` is served null (the concept no
longer applies once whitewater-decay termination leaves the published path). The internal
wave-transformation physics — Q_b solve, one-sided relaxation, roller-energy reservoir, the
INVARIANT_11 closure check — is entirely UNTOUCHED by this ruling; only the published markers and
zone definition change.

**R4 — Beach-profile / impact-zone documentation contract.** *(PA5, follows from R3;
`(ruled 2026-08-10; lands with Phase K of MARINE-PAGE-FIXIT-PLAN)`)* The dashboard's `types.ts`
impact-zone comment currently describes a "50% energy loss" criterion that has never matched the
shipped code (the shipped code used a 5% roller-energy-floor criterion, ADR-102 X-D3) — a doc-code
drift the fixit log's Item 4 investigation surfaced independently of this round's other findings.
When K3 ships, that comment is replaced with the R3 fixed-crash-band definition; there is no longer
a whitewater-decay percentage of any kind driving the published zone.

### Named constants ratified by this ADR (not re-derivable by implementers; see the fixit plan's
own "NAMED CONSTANTS" section for the complete list including SWAN/imagery/map constants outside
this ADR's scope)

- `qb_breaking_onset` default **0.05** — today's `Q_B_VISIBLE` value, unchanged; becomes a config
  key's default (the constant moves, its value does not change at ship time).
- `impact_zone_width_m` default **25.0 m** — CONFIRMED by operator 2026-08-10 at GO.
- `_BREAK_PROMINENCE_FRACTION = 0.30` — pinned constant, not a config key.
- `_MIN_BREAK_DEPTH_M` / `_MIN_BREAK_HS_M` marker filters — UNCHANGED, still applied after marker
  detection.
- `Q_B_CESSATION` (2%) — UNCHANGED; internal-only after K2 ships (physics state, no longer feeds
  publication).
- Boundary endpoint rule: first/last supplied position per side = `len 0.0` and `len = side
  length`, each a byte-copy of the nearest selected wet cell's spectrum file.
- Boundary viability floor: ≥2 wet WW3 cells per offshore side, else `BoundaryNotViableError`.
- All reconstruction spectral constants (JONSWAP γ 3.3, cos²ˢ spreads s=28/s=7, adaptive σf rule,
  35×72 spectral axes, bin-sum identity guard ≤5%, HTSGW-inconsistency guard 0.1 m): UNCHANGED by
  R1 — R1 changes where spectra are built, never how a single cell's spectrum is built.

## Consequences

- **Data contract change (marine repo, Phase B2):** `services/boundary_reconstruction.py`'s spatial
  sampling functions (`_bilinear_corners`, `_sample_scalar`, `_sample_direction`, `_sample_train`,
  `_sample_point_partitions`, `_nearest_wet_value`) are deleted. `services/swan_formats.py`'s
  `ww3_boundary_files_and_command()` position list shrinks from ~1 point per L1 km-cell (~194
  files) to ~7–10 wet cells + 2 endpoint copies per side (~20 files total).
- **Wire shape change (marine repo, Phase S):** `endpoints/surf.py` gains `periodMinS`/`periodMaxS`,
  loses `combinedPeriodS` and `faceHeightMinFt`/`faceHeightMaxFt`. Additive/removal only — no other
  field's shape changes.
- **New config keys (marine repo, Phase K):** `config/marine_config.py` gains `[surf]
  qb_breaking_onset` and `[surf] impact_zone_width_m`, both operator-adjustable with loud
  out-of-range refusal at config push.
- **Publication-path change (marine repo, Phase K):** `services/surf_1d_analytical.py`'s
  `_find_break_points()` / `onset_indices` mechanics and `_classify_zones`/`_classify_zones_per_break`
  change; the physics march (Q_b solve, relaxation, roller reservoir) does not.
- **Dashboard rebind (Phase S/K):** `SurfingTab.tsx` Card 3 rebinds Breaking Face Height and Period
  to the new/changed fields; `BeachProfileChart.tsx`'s `types.ts` impact-zone comment updates to the
  R3/R4 definition.
- **ADR-104 amended:** its D4/P4 boundary-point-spacing ruling is superseded for the reason stated
  in R1 above; see ADR-104's own amendment note.
- **ADR-102 amended:** its published break-marker/impact-zone section (X-D1's onset/cessation
  publication semantics, the `_WHITEWATER_ER_FLOOR_FRACTION` zone criterion) is superseded for the
  published path only; internal Q_b/roller physics is explicitly unaffected. See ADR-102's own
  amendment note.

## Acceptance criteria

Checked at Gate DOC (this document's own completeness — no code exists yet) and at each
implementing phase's own QC gate (B2/S/K) against the specific criteria that phase lands:

- [ ] R1: `services/boundary_reconstruction.py`'s spatial sampling layer is gone; a KAT built from
  the real 2026-08-10 misaligned-corridor values demonstrates no fabricated train and no annihilated
  train (Phase B2, KAT B2.3a).
- [ ] R2: served response carries `periodMinS`/`periodMaxS`, lacks `combinedPeriodS` and
  `faceHeightMinFt`/`faceHeightMaxFt`; the Swell Card's Breaking Face Height and Period read the new
  fields (Phase S).
- [ ] R3: `[surf] qb_breaking_onset` and `[surf] impact_zone_width_m` are live, adjustable, validated
  at config push; a synthetic two-bar profile publishes two markers and two bands (Phase K, KAT K4a).
- [ ] R4: `types.ts`'s impact-zone comment matches the R3 definition (Phase K doc-sync).

This ADR's own acceptance is: PA1–PA5 (the fixit plan's PRE-APPROVAL REGISTER) are each covered by
exactly one of R1–R4 above, verified by the DOC.1 self-check against the register (Gate DOC row 4).

## Implementation guidance

- **SWAN command syntax is pre-researched and pinned** — see the fixit plan's "SWAN SYNTAX
  PRESCRIPTIONS" section for the exact `BOUNDSPEC`/position-list grammar R1 uses; a mismatch against
  the local SWAN manual is a finding to surface, never a license to improvise.
- **Execution order is strict:** Phase B2 (boundary) precedes Phase S (headline ranges) precedes
  Phase K (break markers/zones) — all marine-repo, one round in flight at a time.
- **Out of scope for this ADR:** internal wave-transformation physics (Q_b solve, one-sided
  relaxation, roller-energy balance, closure invariants) — untouched by every ruling above; the
  Item-0 forecast-hole handling (fixit log Item 0, fixit plan Phase Z) — explicitly NOT
  pre-approved (PA6), any fix there that moves the wind-blend boundary or changes cycle scheduling
  requires separate operator approval.
- **Files this governs:** `services/boundary_reconstruction.py`, `services/swan_formats.py`
  (boundary-emission block only), `services/swan_runner.py` (file-writing call site only),
  `services/grid_sizing_chain.py` (config-time viability check only), `endpoints/surf.py`
  (`_compute_eligible_swell_aggregates` only), `config/marine_config.py`, `services/surf_1d_analytical.py`
  (break-publication + zone-classification sections only), `endpoints/beach_profile.py` (zone
  serving shape only). Frozen-core lists from MARINE-FORWARD-PLAN / L1-BOUNDARY-REBUILD-PLAN stay
  closed for everything else, per the fixit plan's PRIME DIRECTIVE 1.

## References

- Evidence: `docs/planning/MARINE-PAGE-FIXIT-2026-08-10.md` — Items 0–6, all raw measurements,
  code traces, and operator rulings quoted verbatim.
- Plan: `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md` — PRE-APPROVAL REGISTER (PA1–PA6),
  NAMED CONSTANTS, SWAN SYNTAX PRESCRIPTIONS, per-phase task design (Phase B2/S/K).
- Related ADRs: ADR-104 (island-aware L1 sizing and partition-reconstruction WW3 boundary —
  amended by R1 above); ADR-102 (statistical breaking fraction and roller energy balance — amended
  by R3 above, internal physics unaffected); ADR-093 (SWAN + SwellTrack nearshore model, the
  1-D model's parent); ADR-097 (beach profile endpoint — the zone-extent consumer).
- `docs/ARCHITECTURE.md` — L1-boundary bullet, SWAN-outputs paragraph, P13 aggregate-fields
  sentence (this ADR's doc-delta counterparts, DOC.2).
- `docs/manuals/PROVIDER-MANUAL.md` §14.3a — reconstruction spec (DOC.3).
- `docs/manuals/API-MANUAL.md`, `docs/contracts/openapi-v1.yaml`, `docs/manuals/DASHBOARD-MANUAL.md`,
  `docs/manuals/OPERATIONS-MANUAL.md`, `docs/manuals/DESIGN-MANUAL.md` (DOC.4).
