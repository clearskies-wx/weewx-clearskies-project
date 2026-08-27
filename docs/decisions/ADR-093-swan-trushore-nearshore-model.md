---
status: Accepted
date: 2026-07-16
deciders: shane
supersedes: ADR-084
superseded-by:
---

# ADR-093: SWAN+SwellTrack replaces NWPS as nearshore wave model

## Context

The surf endpoint depends on NWPS (Nearshore Wave Prediction System) as its primary nearshore data source. NWPS is an NWS operational tool for forecasters, not a public data service. Its run schedule is gated on human forecaster input (2–8 runs/day, no fixed schedule). When a cycle has not posted, NOMADS returns 404 and our 30-minute cache TTL discards valid data, forcing fallback to WaveWatch III — a 50km deep-water model with no nearshore physics. On fallback, the surf forecast returns identical wave values across all 144 timesteps and all four wave_transform.py supplements are skipped.

No commercial surf forecast provider depends on NWPS. Surfline, MSW, WindGuru, and SwellWatch all run their own nearshore models on fixed automated schedules.

NWPS IS SWAN — it runs the same Fortran spectral wave model we would run ourselves. The only things NWPS adds are forecaster-edited wind grids (marginal value for routine conditions per published research) and operational infrastructure across 36 WFOs (irrelevant — we serve specific configured locations). Full research at `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md`.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Keep NWPS as primary (current) | No new code. Leverages NWS infrastructure. | Human-gated schedule, no guaranteed availability. 404 → cache discard → WW3 fallback. WW3 fallback produces flat-line forecasts. Sole external dependency for surf data quality. |
| NWPS with extended cache TTL | Mitigates cache discard. No new infrastructure. | Still human-gated. Stale NWPS data can be 12+ hours old. Does not fix the WW3 fallback problem — just delays it. |
| Own SWAN instance + SwellTrack (chosen) | Fixed hourly schedule, guaranteed availability. Same physics as NWPS. HRRR at 3km is finer than NWPS's 5km NDFD input. Cache-last-good-run eliminates WW3 fallback for surf. Existing wave_transform.py and surf_scorer.py wire directly. SwellTrack proprietary 1D model provides high-resolution surf zone physics. | SWAN Fortran binary dependency. HRRR wind provider needed. NWPS code/docs must be removed. |

## Decision

Replace NWPS with a locally-run SWAN instance paired with SwellTrack (proprietary analytical 1D cross-shore wave transformation model). NWPS is eliminated entirely — code, documentation, cache warmer schedule, and config keys are removed. There is no legacy mode and no `nearshore_model` config key. When the `[nearshore]` pip extra is installed, SWAN+SwellTrack runs as the only nearshore model.

**SwellTrack** is the named 1D analytical wave transformation model that runs per-transect from the SWAN handoff depth to shore. It replaces the generic "analytical 1D" label used during development.

**SurfBeat strip** is a complementary SWAN run (stationary 2D strip with the SURFBEAT command) that produces infragravity (IG) wave energy — set/lull timing that SwellTrack cannot compute (phase-averaged model). SurfBeat runs at 3-hour intervals alongside SwellTrack's hourly cadence. Enabled per-spot via `surfbeat_enabled` config. **[Amended 2026-08-23, operator rulings in chat (SURFBEAT-CYCLE round): SurfBeat runs EVERY forecast hour, inside the forecast cycle's per-spot precompute next to SwellTrack — never at request time; the strip spans the full cached profile from the 15 m contour to the shore, is fed at that start by the hour's deep-water-reference 2-D spectrum (the 15 m-contour point) rotated into the strip frame, at 1 m spacing (= the 1-D model's), 500 m wide; its sea-swell Hs is NOT used for the beach profile (that blend was removed the same day). `surfbeat_cadence_hours` is dead pending removal. See ARCHITECTURE.md SurfBeat paragraph and PROVIDER-MANUAL §14 "SurfBeat strip".]** **[Amended again 2026-08-23 (later the same day), operator ruling in chat "surfbeat is gone": the SurfBeat strip is REMOVED from the system entirely — no model run, cache key, API field, config key, ledger key or dashboard row. Reason: its infragravity peak is the within-set wave-group period (25–200 s), not the set interval, and the surf score's set timing/strength inputs come from the wave spectrum and SwellTrack directly (docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md); with no consumer it was an expensive instrument with no purpose. The "complementary SurfBeat strip" in this ADR's Decision and Amendment 2 ("SwellTrack and the SurfBeat strip model from there to the beach") therefore reads as SwellTrack alone from the handoff to the beach. ARCHITECTURE.md SurfBeat paragraph holds the record.]**

**SWASH and XBeach are ruled out entirely** — for production, LUT precomputation, and referee/benchmark use. SWASH is unvalidated itself and cannot serve as a truth standard. XBeach surfbeat's runtime (~2 min for a 30-min simulation) is incompatible with the 72-timestep forecast pipeline.

**Compute offloading** is operator-configurable via `surf_compute_host` in `api.conf`. When set, SwellTrack computations (and SurfBeat's, until SurfBeat was removed 2026-08-23) run on a remote compute service (e.g., librewxr) instead of in-process on the weewx host. Fallback to in-process when unconfigured or unreachable.

The four supplements from ADR-084 (γ correction, structure effects, spatial interpolation, topographic focusing) survive unchanged and apply to SWAN output. Only the primary nearshore source decision changes.

## Consequences

- **New dependency:** SWAN Fortran binary (compiled from source — pre-compiled binaries are ABI-incompatible across gfortran versions). Installed via `[nearshore]` pip extra pattern following the eccodes precedent. Source: https://gitlab.tudelft.nl/citg/wavemodels/swan
- **Nested grid architecture:** SWAN runs with a two-level nested grid (standard operational practice per NWPS, PacIOOS, USGS CoSMoS). Level 1: coarse outer grid (~2–3 km) for shelf wave propagation. Level 2: fine inner nest (~200–500m) around each surf spot for nearshore feature resolution. Total memory: ~200–300 MB. See research brief §2 "Grid Configuration: Nested Grids" for operational precedents and domain sizing.
- **New provider:** `providers/wind/hrrr.py` — HRRR forecast wind at 3km from NOMADS, hourly fixed schedule (0–48h). See ADR-094.
- **New provider:** `providers/wind/gfs.py` — GFS forecast wind at 0.25° from NOMADS for hours 48–72 (HRRR only extends to 48h on extended cycles; GFS extends to 384h). Required to fill the 72-hour surf forecast card.
- **New service:** `services/swan_runner.py` — writes SWAN input files for each nesting level, spawns SWAN subprocess, parses TABLE output to `MarineForecastPoint` objects.
- **NWPS eliminated:** `providers/marine/nwps.py`, its tests, cache warmer entry, config keys (`nwps_wfo`, `nearshore_model`), and all documentation removed. ADR-084 archived as superseded.
- **No WW3 surf fallback:** WW3 remains the deep-water boundary input to SWAN and continues serving the marine endpoint's offshore forecast. WW3 is never used as a surf forecast source. The surf endpoint serves last-successful SWAN cache on runner failure.
- **Surf data quality:** Wave data varies across all forecast timesteps. All four supplements fire on every run.

## Acceptance criteria

- [ ] SWAN binary installed and callable from the API process when `[nearshore]` extra is present
- [ ] HRRR wind provider returns earth-relative wind fields for the configured coastal bounding box
- [ ] SWAN runner produces `MarineForecastPoint` objects with physically reasonable values (Hs 0.1–10m, Tm01 5–20s) for the test domain
- [ ] Wave data varies across forecast timesteps (not identical values)
- [ ] All four wave_transform.py supplements fire on SWAN output
- [ ] `grep -ri "nwps" repos/weewx-clearskies-api/` returns zero hits (excluding git history)
- [ ] No `nearshore_model` config key exists anywhere
- [ ] WW3 never appears as a surf endpoint data source
- [ ] SWAN failure retains last-good cache — no fallback to WW3 for surf

## Implementation guidance

- **Pip extra:** `[nearshore]` in `pyproject.toml`, following the `[marine]` pattern (which adds eccodes). Includes cfgrib/xarray, HRRR provider, SWAN binary documentation.
- **SWAN compiled from source:** Pre-compiled binaries from SourceForge are ABI-incompatible with Ubuntu 24.04's gfortran 13.3 (Fortran allocatable array metadata layout differs between runtime versions). Docker images compile SWAN at build time, eliminating the ABI issue. Native installs use `install_swan.sh` which builds from the TU Delft GitLab source.
- **Nested grid execution:** Two sequential SWAN runs per cycle. Outer grid completes first, producing boundary condition files that feed the inner nest. SWAN natively supports this via its `NESTOUT`/`NGRID` commands. Domain sizing follows NWPS SGX pattern: outer ~200km at ~3km, inner ~20km at ~200–500m.
- **Wind forcing:** HRRR (3km, hours 0–48) blended with GFS (0.25°, hours 48–72) to fill the 72-hour forecast card. HRRR and GFS wind grids are interpolated onto the SWAN computational grid independently; the SWAN runner stitches them at the 48-hour boundary.
- **Schedule:** SWAN runs on the HRRR extended cycle schedule (4×/day at 00/06/12/18Z) when the 48-hour HRRR is available. Not in the request path — the surf endpoint reads from cache.
- **Cache policy:** TTL 6 hours (matching the extended cycle interval). On failure, retain last-good cache indefinitely. Stale SwellTrack data is always preferred to no data.
- **Optional separated service:** `weewx-clearskies-trushore` pip package for operators who want SWAN on dedicated hardware. API reads from it via `[trushore] service_url`. See Phase 4 of the implementation plan.
- **Memory budget:** Total SWAN memory must stay under 300 MB (both grid levels combined) to coexist with the API, MariaDB, Redis, and weewx on a 2 GB host.

## Amendments

### Amendment 1 (2026-07-21): Multi-transect architecture and optional L3

Per SURF-ZONE-MODEL-BRIEF and SURF-1D-IMPLEMENTATION-PLAN:

**1. L3 grid is now optional per location.** L3 is enabled automatically when Overpass API discovers structures near the spot, disabled for open beaches. The operator can override in admin (force L3 on/off per location). Spots with no structures skip L3 entirely — SPECOUT extracted from L2 at ~15m depth.

**2. When L3 is enabled, grid is smart-sized around structures.** L3 bbox is computed from structure positions + shadow zone extent (structure length + 2× structure length downstream in predominant wave direction) + 100m pad. A single pier on a 1km beach produces a ~500m L3 grid, not a 1km+ grid. Transects outside the L3 bbox hand off from L2 at ~15m depth.

**3. Multi-transect architecture replaces single-pin transect.** The operator draws a shoreline segment (not a pin) to define the surfable zone. The system generates transects perpendicular to local isobath orientation at 10m spacing across the segment. Each transect is cross-checked against OBSTACLE structures — transects crossing an OBSTACLE are flagged as "structure-affected" and excluded from headline metrics (best peak, spot average). Structure-affected transects are still rendered on the heat map.

**4. 1D model runs from handoff to shore per transect.** SWAN runs 2D all the way to shore. At the handoff depth (10m default, shallower for structure-shadowed transects, per the pre-model handoff algorithm), the full 2D spectrum is extracted via SPECOUT. A 1D cross-shore wave transformation model then runs independently per transect from the handoff to shore, providing Hs at 3-5m resolution, break points, breaker classification, wave shapes, surf zone widths, jacking factor, and peel angle. Model selection pending Phase 1 benchmark (analytical, XBeach-1D surfbeat, SWASH-1D).

**5. Compute budget updated.** L3 compute is proportional to structure coverage, not beach length. Spots with no structures skip L3 entirely. The 1D analytical model adds ~30-90ms per spot (30 transects × 3 partitions × ~1ms) — negligible relative to SWAN runtime.

**6. Pin-based configuration replaced entirely.** No backwards compatibility needed (no other operators). The shoreline segment replaces `spot_lat`, `spot_lon`, `beach_facing_degrees` with `segment_start_lat/lon`, `segment_end_lat/lon`, and `transect_spacing_m`.

### Amendment 2 (2026-07-25): L3 cross-shore extent, the handoff surface, and the L3 viability test

**Why this amendment exists.** Amendment 1 made L3 optional and smart-sized it *alongshore*
(its worked example — "a single pier on a 1km beach produces a ~500m L3 grid" — is an
alongshore number). It never addressed L3's *cross-shore* extent. L3 therefore kept the
pre-1D geometry: offshore edge at the 15 m contour, shoreward edge at the shoreline. Both
were derived when SWAN modelled to shore by itself. Neither survives the introduction of
SwellTrack and the SurfBeat strip. Full analysis:
`docs/planning/briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md`.

**1. L3 does not run to shore.** Its shoreward boundary is the SWAN→SwellTrack handoff
surface. SwellTrack and the SurfBeat strip model from there to the beach. L3's shoreward
boundary and the handoff depth are **one quantity, not two** — no configuration can place
the handoff outside the grid.

**2. The handoff is NOT a fixed depth chosen at setup. The grid is fixed; the extraction
point moves per forecast hour.**

Grid geometry must be frozen at setup — that rule is unchanged and binding
(`rules/clearskies-process.md`, "All SWAN grid geometry is fixed at setup time"). But *which
cell we read the handoff spectrum from* is a sampling choice, not geometry, and it can move
every forecast hour.

```
At setup:    size the L3 grid to reach as far shoreward as it is EVER useful
             (i.e. down to the shallowest depth at which any forecast hour's
             handoff could sit — small-swell days break shallow)

Per hour:    breaking depth this hour = Hs(hour) / gamma
             read the handoff spectrum from just SEAWARD of that contour
```

*Why this replaces the earlier fixed-depth rule.* An earlier draft of this amendment set the
handoff at `1.3 × max_hs_m / gamma` — the breaking depth for the spot's **largest** swell —
and held it there all year. That is wrong in both directions. On a typical day it hands off
far seaward of anything breaking, giving SwellTrack (the weaker model) a long leg SWAN could
have carried. And it shrinks L3 to a thin band that fails to reach the very structures it
exists for. The breaking zone at HB Pier moves between roughly 1.4 m depth (1 m swell) and
5.5 m (4 m swell) across a year; freezing the handoff at the deep end throws away the other
eleven months.

*The margin above breaking — DECIDED: reuse the 1.3 factor, applied per hour.*

```
handoff depth (this hour) = 1.3 * Hs(hour) / gamma
grid shoreward reach      = the smallest value that expression ever produces
                            for this spot's conditions
```

SwellTrack needs only enough room to (a) observe the `Hs/d = gamma` crossing inside its own
domain rather than on its boundary, and (b) have an approach value seaward of the outer bar
for the jacking factor. It does NOT need wavelengths of shoaling run-up — SWAN has already
shoaled the wave, and SwellTrack traverses the nonlinear inner zone regardless of where it
starts. A 30% margin on the hour's own breaking depth satisfies both and introduces no new
constant.

The 1.3 factor was never the defect. Feeding it `max_hs_m` — the year's largest swell — and
then freezing the result was. Applied to the hour's actual Hs it moves with conditions:
1 m swell → hand off at 1.8 m; 2 m → 3.6 m; 4 m → 7.1 m. At HB Pier the grid must therefore
reach ~1.8 m depth, which spans the pier end to end.

*Rejected, for the record — the Deltares `cg/c < 0.9` criterion.* It was briefly adopted here
and then withdrawn. That condition governs models which reconstruct a water surface from a
boundary spectrum (XBeach, SWASH), where imposing a linear spectrum in nonlinear water
produces a wrong wave train from the first step. SwellTrack marches bulk parameters per
partition and reconstructs no surface, so the failure mode does not apply. Applying it would
have pushed the handoff to ~15 m and handed almost the entire transformation to the weaker
model.

**3. L3 trigger — operator classification, not structure discovery alone.** L3 turns on when
either a manmade structure is discovered **or** the operator has classified the spot as a
point break, headland, or bay break. The pre-existing trigger looked only for manmade objects
via Overpass API, which meant a point break — the case where 2D refraction matters most and
where SwellTrack is structurally least able to help — could never turn L3 on.

*Why operator classification and not automatic detection.* A point break is defined by
**alongshore** geometry: the shoreline bends and the depth contours fan around the point. A
single cross-shore profile cannot see this by construction. Detecting it automatically
requires analysing how contour orientation varies along the shoreline segment — new analysis
that is specified nowhere and built nowhere (SURF-ZONE-MODEL-BRIEF §2.6 calls for deriving
contour orientation for transect placement, and flags it as not yet implemented). The
operator already supplies the classification and knows the answer. **Decision: use it.**

*Scope boundary — what is and is not in.* **IN:** all depth-based calculation from the
setup-time bathymetry, which the apply-time chain already produces — depth contour positions,
local seabed slope, breaking depths, the horizontal span between the offshore edge and the
handoff, grid extents and cell counts, profile relief. These are expected and required; L3
sizing and the viability test are built on them. **OUT:** anything that infers *shoreline or
contour shape* — contour curvature, orientation variation along the segment, headland
detection, automatic classification of break type. That is new analysis, it is specified
nowhere, and the operator's classification supplies the same answer today.

**4. L3 viability test at setup.** The trigger is necessary but not sufficient. Compute L3's
extent, then test it: if the grid cannot reach the feature it was created for — structure or
headland — L3 provides nothing and is **disabled** for that cluster. That spot runs
L1 → L2 → SwellTrack from L2's ~15 m reference, as an open beach does.

**When the test disables a grid it MUST log why** — which feature was unreachable and by how
much. The two failure directions are not equally visible: a grid reaching too far shoreward
shows up at runtime as breaking inside L3, but a grid that stops too far seaward is silently
indistinguishable from a legitimate "nothing here to model" result. The log is what makes the
second one visible.

**5. HB Pier status — UNDETERMINED, pending the margin decision.** An earlier draft recorded
HB as failing the viability test, on the reasoning that the pier tip (~7 m) and the frozen
handoff depth (~7.1 m) coincided. That reasoning is void: with a per-hour handoff, the grid
is sized to reach the shallow end of the breaking range, not the deep end, and a grid
reaching ~2 m depth would span the pier end to end. **HB Pier may well be viable.** Do not
carry the "HB is disabled" conclusion forward — it was an artefact of the fixed-depth error.

> **RESOLVED 2026-07-25 — HB Pier IS viable; L3 is enabled.** Measured by running the real
> apply-time chain against live NCEI bathymetry on librewxr (T4A.5). The 1.8 m contour sits
> **85 m** offshore of the coastline anchor; L3 was sized with a shoreward reach of 85 m and an
> alongshore extent from the 567 m pier; the §4 viability test passed and the chain logged
> `1 of 1 cluster(s) enabled`. The prediction in this section — "a grid reaching ~2 m depth
> would span the pier end to end" — held. Evidence and the two recorded deviations are in
> `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` under T4A.5.

**5a. Where L3 earns its keep (guidance, not a rule).** On steep, feature-driven seabed —
reef ledges, points, canyon rims — the band between clean water and breaking is a few hundred
metres, so a 10 m grid across it is small and resolves 10–50 m features nothing coarser can
see. On a gentle sand shelf that same band is kilometres wide, the grid is enormous, and what
it would resolve is sandbars that SwellTrack already handles from the depth profile. Cost and
value both point the same way. This informs the viability test's sizing but is not itself a
pass/fail criterion.

**5b. Supplement 4's topographic multipliers are removed.** The hand-entered adjustments
(point break ×1.1, headland ×1.2, bay break ×0.9, straight beach ×1.0 — API-MANUAL §17)
stand in for refraction the model now computes. They predate nesting: once L2 existed at
100 m it began computing that refraction itself, so the multipliers have been double-counting
since. They are removed outright, not made conditional. The operator's classification is
retained — its job becomes the L3 trigger (§3), not a fudge factor.

**6. Future direction (noted, not scoped).** A ray-tracing add-on to SwellTrack would supply
2D shadow geometry at 1D cost, restoring modelled structure shadows without a 2D grid. That
path removes L3 **permanently** rather than conditionally. L3 work should not be
over-invested in ahead of it.

**L3's offshore (seaward) edge stays at the 15 m contour — question closed.** It was
briefly reopened on the reasoning that a fixed 15 m handoff would collapse the grid to zero
thickness (start at 15, hand off at 15). With a per-hour handoff that collapse cannot happen:
the grid runs from 15 m down to the shallow end of the breaking range and is thick at every
spot. The reason to change the offshore edge no longer exists, so it does not change.

**Unchanged by this amendment.** Amendment 1's alongshore smart-sizing rule stands.

### Amendment 3 (2026-07-27): L3 rescoped as need-driven; L4 introduced as the structure grid; L3's 15 m offshore edge retired for the structure-grid case

**This amendment documents an already-made operator ruling — it is not a new decision.** The ruling was
given in chat during the Marine Model Restoration Plan Phase E review session, 2026-07-27, and is
recorded in full at `docs/planning/briefs/SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md` §0A (rulings D1–D8)
and implemented per `docs/archive/MARINE-MODEL-RESTORATION-PLAN.md` Phase E, tasks E1–E9. This
amendment's job is only to reconcile ADR-093 itself with that ruling — Amendment 2 predates it and, on
the point below, is superseded.

**What changed.** Amendment 2 §2/§4 sized L3 as a single per-cluster fine grid (10 m) reaching from a
fixed **15 m offshore (seaward) edge** down to the per-hour breaking-depth contour, and closed the
question of moving that offshore edge ("L3's offshore (seaward) edge stays at the 15 m contour —
question closed"). Findings §0A ruling **D2** replaced that single-purpose L3 with a need-driven grid
that exists for exactly two reasons and never otherwise: (a) as the coarse nesting step under a new,
separate fine grid — the **structure grid, tier L4** (`services/swan_domain.py`
`compute_structure_grid_domain()` / `StructureGridDomain`) — a true rotated rectangle fixed at 10 m
resolution, sized to the structure's own principal axis [**⛔ this axis method is superseded by
Amendment 6 (2026-08-01) — current rotation is the beach facing, not a structure axis; kept here as the
original Amendment 3 wording**]; or (b) as the working refraction grid at an
operator-classified point break, headland, or bay break, unchanged from Amendment 2's cross-shore
sizing. Ruling **D6 item 1** — *"Retire the 15 m-contour offshore edge; adopt the structure grid" —
Approved* — is the specific line item that reverses Amendment 2's "question closed" statement.

**Scope of the reversal — role (a) only.** For a role-(a) cluster (structure present), L3's cross-shore
extent is no longer the 15 m contour on either edge: it is sized directly around the already-sized L4
structure grid, extent = L4's footprint plus clearance of at least 2 L2 cells on every side, plus the
cluster's alongshore pin span (`size_l3_coarse_nest()`). The 15 m contour has no role in sizing a
role-(a) L3 at all. For a role-(b) cluster (classification, no structure) L3's cross-shore extent is
**unchanged** — Amendment 2 §2's breaking-depth-criterion shoreward edge and the 15 m contour offshore
edge both still apply exactly as written there. A cluster with neither a structure nor a classification
runs no L3 at all, byte-identical to production before this ruling (D2's own strongest acceptance
criterion).

**Consequences also decided by the same ruling, recorded here for completeness (implemented E1–E9):**
- L3's resolution changes from the fixed 10 m Amendment 2 assumed to a fixed **40 m**
  (`_L3_RESOLUTION_M`, `services/swan_domain.py`) — D6 item 5, "L3 at 30–40 m for refraction spots,
  diffraction off there."
- `DIFFRACTION` moves from L3 (Amendment 2's era) to **L4 only** — plan task E7 — because at L3's now
  coarser 40 m (and L1/L2's 1 km/100 m) diffraction is sub-resolution; smoothing (`smnum`) scales with
  the grid's own `dx`.
- The variance-test / conditional-band mechanism that Amendment 2 (and the earlier §2.2/§2.3 research)
  proposed to gate L3 is **struck entirely** — D2's consequences, D6 item 6.
- L4's resolution is a **fixed 10 m constant**, not derived from wavelength (operator ruling, verbatim:
  *"Just use a 10m grid for when L4 is needed, period"*) — superseding the `min(L_tip/8, 15m)` floor-10
  derivation that plan task E1 had implemented immediately prior to this ruling.

**Unchanged by this amendment.** Amendment 1's alongshore smart-sizing rule (structure shadow-zone
extent) stands and now sizes L4's alongshore extent as well as L3's, per `services/swan_domain.py`.
Amendment 2's handoff-depth criterion (`1.3 × Hs(hour) / gamma`) is unchanged and now applies uniformly
to whichever of L3/L4 a transect hands off from (Marine Model Restoration Plan E5, ruling D3).

### Amendment 4 (2026-07-29): the 1-D model's LANDWARD boundary — the maximum-total-water-level criterion

**Why this amendment exists.** Every prior amendment specifies the 1-D model's **seaward** end — the
handoff surface at `1.3 × Hs(hour) / gamma`, fed by L4 (or L2 fallback) per Amendment 3. None specifies
its **landward** end. Amendment 2 just says SwellTrack "and the SurfBeat strip model from there to the
beach," leaving *how far landward the profile runs* and *how tide interacts with it* undefined. That gap
is a real defect (tracked as TA-C18): above roughly +0.5 m of tide the served surf collapses to zero
(`best_peak = 0.00 m`, `peel = nan`, marine invariant 8 fires) across all open transects at Huntington
City Beach Pier. It is not physics — a real wave always breaks as it runs up the beach — it is a
too-short model domain.

**Root cause (verified against the deployed cache and grids, 2026-07-29).**
1. Each per-transect bathymetric profile starts at that transect's **SWAN sampling-band anchor**
   (`_band_ray_origin`, shared with the per-transect POINTS bands), which legitimately sits ~1 m *seaward*
   of the true waterline because SWAN deliberately stops before the swash. The cached per-transect
   profiles for HB begin at depth **1.01–2.83 m** at `distance_from_shore = 0`; the shared per-spot
   profile, anchored at the true shoreline, begins at **0.00 m**. So the 1-D model imports SWAN's offshore
   boundary as its own shoreward start.
2. The profile sampler then **deletes the subaerial beach twice**: `_grid_depth_below_msl()` returns
   `max(0.0, -elev)`, clamping every land cell to depth 0; the downstream `depth_m > 0` filter
   (`providers/nearshore/swan.py`, `endpoints/beach_profile.py`) drops those zeros. The beach face the DEM
   *does* contain is discarded before the 1-D model sees it.
3. The 1-D model adds tide to every depth (`depths = seabed + tide_level`). With the profile floored ~1 m
   deep and the beach face deleted, a rising tide lifts the shallowest modeled point above breaking depth
   (`Hs/gamma`). Above ~+0.5 m the wave never reaches breaking depth inside the domain → no break points →
   zero surf. Sharp cliff because all open transects share a similar shoreward floor.

**Data is not the constraint.** The cached grids around the pier carry full topobathy: land elevations up
to **+15.1 m** (L4/L3 nest), +17.6 m (L2). We have been deleting the beach, not lacking it.

**Decision — the landward boundary is the Highest Astronomical Tide (HAT), computed ONCE at setup.**
This follows the established principle for cross-shore wave-transformation models — place the domain's
landward boundary above the highest still-water shoreline so the moving shoreline stays inside the domain
at every tide (CSHORE extends into the wet/dry zone above still water). We cap at HAT rather than the full
flood-planning Total Water Level (which adds storm surge and wave runup) **because this is a surf model,
not a flood model**: it forecasts surfable conditions, not the storm-driven extremes above HAT. It is the
symmetric complement of Amendment 2's seaward rule ("size to reach as far shoreward as it is *ever*
useful"): size the profile to reach as far **landward** as it is ever useful for a surfable tide — i.e. to
HAT.

**Why setup-once, not per cycle (operator ruling 2026-07-29).** The profile cache is built at
config-receipt (`services/grid_sizing_chain.py`, `source: config_receipt_pchip`), and "all SWAN grid
geometry is fixed at setup time" is a binding rule (`rules/clearskies-process.md`). The landward extent is
therefore sized once to the spot's **worst case** — its configured maximum swell and its tide station's
high-water datum — not recomputed per forecast hour. Per-cycle self-scaling would buy nothing here: the
per-hour tide already moves through the existing wet/dry clamp inside a fixed-geometry profile, so a
profile sized to the worst case is wet exactly as far up the beach as each hour's actual water level
requires, with no accuracy lost.

Concretely:

1. **Decouple each transect from the SWAN band anchor.** Each 1-D transect finds its *own* shoreline
   (walk shoreward through the covering grid until elevation crosses 0, as `find_shoreline_from_grid`
   already does for the shared anchor) and runs an independent line from its handoff depth to that
   shoreline and beyond — never starting at the SWAN POINTS-band anchor. This is the independence the 1-D
   model is supposed to have from SWAN except at the handoff.

2. **Landward extent = the Highest Astronomical Tide (HAT), computed at setup:**
   ```
   E_landward = HAT
   ```
   in the DEM's own vertical datum (LMSL at HB; datum consistency guaranteed by ADR-098 match-at-source, so
   tide and seabed share a datum). **No storm-surge term, no wave (setup/runup) term.** This is a *surf*
   forecast model, not a flood model: storm surge and wave runup are the domain of the storm that produces
   them, and nobody is surfing that. Under normal astronomical conditions the still-water line never rises
   above HAT, so a profile that reaches the HAT elevation always has wet ground for the wave to break on at
   every hour's tide — which is all the 1-D model needs.

   `HAT` is taken from **the same tide model already feeding `tide_level`** — the CO-OPS harmonic
   predictions for the spot's configured station (`coops_station_ids[0]`, `providers/tides/coops.py`, the
   source `resolve_ondemand_tide_level()` resolves; `providers/nearshore/swan.py:2397`). HAT is by
   definition the maximum of that harmonic prediction; at setup it is obtained as the max over a ≥1-year
   prediction window (equivalently the station's published HAT, same constituents), requested in the DEM
   datum (match-at-source). Same source, same station, same datum as the runtime tide — no new or distant
   source is introduced. On a prediction-fetch failure, log a WARNING and degrade per this chain's posture.

   Each transect's profile is extended up its own beach face to `E_landward = HAT`.

3. **Sample signed depth; stop filtering land.** For the 1-D profile, return the *signed* value
   (`-elev`, negative on land) instead of clamping land to 0, and drop the `depth_m > 0` filter, so the
   beach face keeps its true elevation. The existing `depth = max(seabed + tide, 0.01)` line in
   `run_1d_analytical` then does the per-hour wet/dry automatically: a beach-face cell is dry (~0.01 m) at
   low tide and wet at high tide. No new machinery, no per-hour geometry change — grid geometry stays
   fixed at setup (profile sized once to the worst-case landward reach), only the wet/dry state moves.

4. **Guard, never a silent cap.** If a spot's topobathy cannot reach `E_landward` at setup (data runs out
   up the beach), log a WARNING naming the spot, the shortfall, and the affected transects — an
   operator-visible flare, not a silent zero. With +15 m of land available at HB this is a backstop, not
   the normal path.

**Scope — landward end only.** The seaward handoff (`1.3 · Hs/gamma`, from L4/L2 per Amendment 3) and all
SWAN grid geometry are unchanged. No physics formula changes: shoaling, refraction, Battjes-Janssen
breaking, and the roller model are untouched; this amendment only defines *how far landward the profile
extends* and *that land is sampled with its real elevation* so those existing formulas have ground to run
on at high tide.

**Files this governs (implementation to follow, separately reviewed):** `services/grid_sizing_chain.py`
(per-transect anchor + landward extent), `enrichment/bathymetry.py` (signed-depth sampling for the 1-D
profile + landward walk to `E_landward`), the `depth_m > 0` filters in `providers/nearshore/swan.py` and
`endpoints/beach_profile.py`. `services/surf_1d_analytical.py` is unchanged (its wet/dry clamp already
handles the new points).

**Best-practice basis:**
- CSHORE (Kobayashi, U. Delaware CACR) — the directly analogous 1-D cross-shore wave/current model;
  its domain extends into the wet/dry zone above the still-water shoreline, which is the principle
  adopted here. We take the still-water ceiling as HAT (astronomical), deliberately excluding the
  storm-surge and wave-runup terms that flood-planning TWL adds (FEMA / Stockdon 2006), because a surf
  model has no reason to model ground that is only submerged during the storm.

### Amendment 5 (2026-07-31): Geography-aware study-area geometry — isobath-normal facing, open-water L1 aim, OMBB L4 axis, curvature-derived break-type, obstacle representation

**Status: Accepted.** Approval of `docs/archive/MARINE-GEOMETRY-MODEL-PLAN.md` IS the acceptance of this
amendment's architecture (operator ruling 2026-07-30, recorded in that plan). This amendment records the
SWAN-model-**derivation** changes of the Marine Geometry-Model Plan — architecture decisions **AD-1, AD-3,
AD-4, AD-5, AD-8**. The net-new geography-**determination** subsystem those decisions consume (OSM coastline,
the wrap-aware fetch/openness fan, water-body classification, and the two-stage study-area basis — AD-2, AD-6,
AD-7) is a distinct decision recorded in **ADR-100**, which this amendment cross-references throughout.

**Scope discipline — what this amendment does NOT change.** It changes *what bearing / exposure / open-water
direction / grid axis is passed into the existing, validated sizing and handoff code* — **not** the sizing
formulas (`1.3 × Hs / γ`, γ = 0.73, `_MIN_DESIGN_HS_M`, the 30 m/15 m contour criteria, tier resolutions, the
shadow-union + 2λ formula), **not** the 2D→1D handoff surface or its first-match L4→L3→L2 control flow, **not**
the convergence gate, the hotstart mechanism, the all-stationary COMPUTE sequence, the `CIRCLE 72` directional
resolution, the HAT landward boundary (Amendment 4), the deep-water reference (always L2 at the spot's own 15 m
contour), or L1/L2/L3 axis-alignment (only L4 rotates). It also changes **no SWAN command syntax** — only the
computed **values** that flow into the existing, working `CGRID`/`NGRID`/`INPGRID`/`READINP`/`BOUNDSPEC`/
`OBSTACLE`/`NESTOUT`/`BOUNDNEST1` emission (MARINE-GEOMETRY-MODEL-PLAN "OFF LIMITS"; operator directive
2026-07-30). See that plan's OFF-LIMITS fence for the exhaustive list.

**Why this amendment exists.** The single-cross-shore-facing model — one beach-normal per spot, derived as the
perpendicular of the operator-drawn shoreline segment (`_segment_bearing`→`_perpendicular_bearing`,
`config/marine_config.py`) — is inadequate for the US coasts this system must serve: curved shores, point
breaks, bays, island-sheltered coasts, and the Great Lakes. Amendments 1–4 built the working nearshore model
against a straight-open-beach mental model; this amendment replaces the *derivation* of where and which way that
model looks — beach facing, transect bearing, L1 aim, the WaveWatch III boundary sides, exposure, the L4 axis,
and the L3 trigger — with a **geography-aware, automated** determination grounded in bathymetry isobaths and the
actual open-water geometry.

**AD-1 — Shore-facing is the isobath-normal, derived per-transect (replaces segment-perpendicular).**
> **⛔ METHOD SUPERSEDED 2026-07-31 by AD-1R (below). The isobath 2 m/5 m ray-fit produced a wrong facing —
> 202° at Huntington vs the true ~220°: it measured the offshore contours (bent by sandbars, channels, and the
> pier's own scour), and the production call site handed it the 1 km L1 grid so the 300 m search sampled bilinear
> noise inside a single cell. AD-1's *intent* stands (a derived, per-transect, geography-aware facing; coverage-
> driven L2/L3 sizing); its *method* below is dead. `isobath_normal_bearing` and its KATs were deleted with the
> replacement (MARINE-GEOMETRY-MODEL-PLAN G1R.2, marine `73df829`). Read AD-1R for the current method.**

`beach_facing_degrees` and each transect bearing are derived from the **local shallow-isobath heading** (the
2 m / 5 m depth-contour trend from the setup-time bathymetry), smoothed over ≈ the surf-zone width / the ~300 m
study segment, taken **perpendicular** (seaward sense) as the shore-normal — **per-transect** where the shore
curves, collapsing to a single value on a straight beach. Isobath heading is **datum-robust** (a datum shift
slides a contour, barely rotates it), which sidesteps the DEM 0 m-datum sensitivity of the drawn segment.
Degenerate/flat bathymetry falls back to the segment-perpendicular value with a WARNING. **This REOPENS
Amendment 2 §3's deferral of contour-orientation derivation** ("specified nowhere and built nowhere") — it is
now specified (this amendment / MARINE-GEOMETRY-MODEL-PLAN G1) and built. **Sizing stays coverage-driven** (a
settled operator framing, 2026-07-30): with per-transect bearings the offshore contour is measured per-transect
and L2 encloses the **union** of all transects' reaches (the covering envelope it already computes), not a
single representative bearing; the bearing's only sizing role is the direction the contour distance is measured
along. Implemented MARINE-GEOMETRY-MODEL-PLAN G1 (`enrichment/bathymetry.py` new heading helper;
`config/marine_config.py`; `services/swan_formats.py`; `services/grid_sizing_chain.py`; `services/swan_domain.py`
L2/L3 sizing).

**AD-1R — Beach facing = the smoothed-0 m-shoreline normal (DSAS/CliffMetrics), at spot-definition time,
operator-overridable (SUPERSEDES AD-1's ray-fit method; operator-approved in chat 2026-07-31).** The facing is the
**seaward perpendicular of the smoothed 0 m shoreline's local tangent**, not the 2 m/5 m isobath ray-fit. The 0 m
shoreline is traced from the finest bathymetry as an ordered polyline (seeded along the drawn segment), its
coordinates moving-average-smoothed over an alongshore window swept **500 → 2500 m in 500 m steps until the heading
stabilizes** (successive-window change ≤ 5°; "Option B"), and the normal is taken from the smoothed tangent — the
USGS **DSAS** smoothed-baseline and **CliffMetrics v1.0** (Payo et al. 2018) method. It is computed **at
spot-DEFINITION time** and depends on **nothing but the drawn segment** — no SWAN grid, domain, or L1–L4 sizing
exists yet (they are sized AFTER, from this facing), so a spot with **no structures never has an L4 (possibly no
L3)** and the facing is still defined. The wizard calls a new marine geometry endpoint (via the API — INVARIANT)
with just the segment; the strip-bathymetry fetch builds its own coverage box from the segment alone. The computed
value pre-fills the wizard field; the operator may adjust; the confirmed value is **stored in config**
(`beach_facing_degrees` returns as a stored key — reversing T2.1's removal) with a source tag
`beach_facing_source ∈ {operator, computed, fallback_segment_perp}` (only `operator` is an override; it wins at
every consumer, and per-transect bearings are then uniform = the override). The config-push chain
(`run_grid_sizing_chain`) READS the stored facing and only re-derives it when the source is `fallback_segment_perp`
or absent (a deterministic retry now that the strip fetch may succeed); it derives the **per-transect** bearings
from the same strip and persists them to the profile cache (G1.6 shape unchanged) — never during model runs.
Degenerate/short-run shoreline falls back to the segment-perpendicular + WARNING. Datum-robust (a datum shift
slides the 0 m line but barely rotates its heading over ≥ 500 m). **The pinned equations and constants
(`W_MIN=500`, `W_MAX=2500`, `W_STEP=500`, `STABILITY_TOL_DEG=5.0`, `TRACE_DEPTH_M=0.0`, `MAX_CROSS_SEARCH_M=1000.0`)
live in MARINE-GEOMETRY-MODEL-PLAN §AD-1R** and are implemented verbatim there. Implemented G1R.1 (`shoreline_normal_bearing`
+ strip fetch, marine `7f07075`) and G1R.2 (chain/`compute_spot_transects` rewire, `beach_facing_degrees`/
`beach_facing_source` config keys restored, `isobath_normal_bearing` deleted, marine `73df829`); the definition-time
wizard endpoint + API pass-through + apply-model acceptance is G1R.3. **Validated on the real Huntington config
2026-07-31: the chain resolved the facing to 217.0° from the shoreline strip (within the 220° ± 5° known-answer;
the broken 202° did not reproduce).**

**AD-3 — L1 offshore aim and WW3 boundary sides come from open water, not the beach bearing.** `_compute_level1`
aims its offshore extension along the **open-water bearing** (ADR-100 fetch fan) instead of
`mean_offshore_bearing_deg`; `ww3_station_selection`'s offshore-**side** selection uses the same open-water
bearing (the single shared source). L1 and L2 **remain axis-aligned** — only the aim/extent value moves, never
rotation. **Islands, headlands, and peninsulas in a swell corridor** (an ADR-100 *wrap-candidate* direction):
L1 is enlarged to **enclose the intervening land AND the open water beyond it** so SWAN computes the
refraction/diffraction wrap-around at the spot — *"islands are MODELLED, not flagged,"* extended to headlands
and peninsulas. **The fetch fan sizes the domain and picks the boundary side; SWAN computes the wave** — the fan
never decides how much energy arrives. **Great Lakes:** L1 is sized from lake-geometry/fetch (no shelf edge;
`find_shelf_distance` returns the nearest *ocean* shelf and would oversize a lake L1), routed to the GLWU WW3
product that already exists. The WW3 station **qualification** criterion (`deep water OR tanh(kd)`) and the
`BOUNDSPEC SIDE VARIABLE FILE` emission are unchanged — only the aim/side *input* changes. The selection
pipeline stays **cardinal-only (N/E/S/W)**; the side set is not extended to diagonals. Implemented
MARINE-GEOMETRY-MODEL-PLAN G2 (`services/swan_domain.py`, `services/ww3_station_selection.py`,
`services/shelf_boundary.py` lake branch). *Resolves Phase-5 D6c (enlarged-L1 Bolsa → 0 qualifying stations) as
a validation gate — root-cause first, then validate on the real 2-spot config, not a pre-marked fix.*

**AD-4 — One oriented-bounding-box (OMBB) primitive; L4 axis from it; multi-obstacle proximity clustering.** A
new `services/structure_geometry.py` provides an OMBB helper (shapely `minimum_rotated_rectangle`), built once
and consumed by **both** the obstacle router (structure polygon alone — centerline + width) and the L4 axis in
`compute_structure_grid_domain`, which replaces the `_most_distant_pair` two-point axis with the OMBB long-axis
of the *obstacle-plus-shadow* (single) or *merged-cluster* footprint. Re-deriving the axis **re-anchors
tip/base** (tip = farther-from-anchor) so the tip-depth lookup and the 1-wavelength along-axis margin still
work. Obstacle boxes **merge when < 500 m apart** (`cluster_distance_m = 500.0`) into ONE L4 grid = the OMBB of
the merged footprint, minimum box 200 m × 200 m (20 × 20 cells at 10 m). **Separate-box multiple-L4-grids is
DEFERRED** (a follow-up plan): far-apart obstacles give the single L4 to the primary structure (the one covering
the served transects / nearest the pin), the rest logged to the concerns file — still a strict improvement over
today's degenerate cross-structure axis. Only the computed `alpc`/`alpn` values and extents change; the
CGRID/NGRID emission is unchanged. Implemented MARINE-GEOMETRY-MODEL-PLAN G0.1 + G4 (`services/swan_domain.py`).

**AD-5 — Break-type derived from curvature drives the L3 trigger; operator classification demoted to optional
override.** Point-break / headland / bay classification is **derived** from the measured shoreline/isobath
curvature (the same isobath analysis AD-1 builds) and becomes the **L3-enable trigger** (which currently reads
`topographic_feature`). The operator `topographic_feature` field is **no longer a required input**; it is
retained as an **optional override** for a sub-grid feature bathymetry cannot see — e.g. a submerged reef
(operator ruling 2026-07-31). This **amends Amendment 2 §3**, which chose operator classification precisely
because contour-shape derivation was "specified nowhere and built nowhere"; this amendment builds it. L3's
CGRID/NGRID emission and its viability test are unchanged — only *whether* L3 emits. Implemented
MARINE-GEOMETRY-MODEL-PLAN G5 (`services/swan_domain.py` L3 trigger; `config/marine_config.py`; stack wizard).

**AD-8 — Obstacle representation: bathymetry-injection fork + static cited coefficients** (folds the working-model
Track B architectural sign-off into this plan; no separate mid-run sign-off). **Line-vs-footprint fork:** a
structure **≥ 3 L4 cells (~30 m) wide AND solid** (`breakwater|jetty|groin|seawall|mole`) → **burn its footprint
into the L4 BOTTOM** as emergent cells, no OBSTACLE line; everything else (all piers; any solid structure
< 3 cells) → an **OBSTACLE line** on the simplified OMBB centerline. **`shapely` only — no `rasterio`** (deps
unchanged). **Static, cited per-type coefficients** (`Kt` is a wave-HEIGHT ratio): pier `TRANSM 0.74` (Elgar
2001, ~45 % energy blocking); seawall `REFL 0.9 RSPEC` (smooth vertical / sheet-pile, JMSE 2021);
breakwater/jetty/groin keep their existing static `DAM …` forms unchanged. **Dynamic per-segment crest `Rc` and
Seelig–Ahrens reflection are DEFERRED** (need data no config carries) — a Phase-5 design task. **Presence check:**
a structure already emergent in the DEM (emergent-cell fraction ≥ 0.65 AND an elevation-anomaly ridge) → skip
injection, logged (no double-count). This touches OBSTACLE `TRANSM`/`REFL` and `BOTTOM.txt` **values** only —
the OBSTACLE and INPGRID/READINP BOTTOM **syntax is unchanged**. Implemented MARINE-GEOMETRY-MODEL-PLAN
G4.3–G4.5 (`services/swan_formats.py`, `services/swan_runner.py`).

**Phase F (Young & Verhagen 1-D wind-sea term) is DROPPED from scope** (operator, 2026-07-30). SWAN grows wind
sea over the real domain fetch (GEN3 physics from the wind field), and the Great Lakes get their wind sea via the
GLWU boundary + SWAN growth — the same architecture as the ocean, not a 1-D term. `services/wind_sea_growth.py`
stays in the repo, **unwired**. A real wind-sea gap at a reality check is a SWAN wind-forcing/physics
investigation, not a 1-D addition.

**Implementation status (2026-07-31, at this amendment's writing).** The architecture above is the **approved
target**; the code migrates across MARINE-GEOMETRY-MODEL-PLAN phases G0–G6. Sections of ARCHITECTURE.md, the
PROVIDER-MANUAL, and the OPERATIONS-MANUAL that describe this target while the code is still migrating carry a
"(target — Phase GX)" annotation, per that plan's Phase D convention, so a target description is never mistaken
for a false claim of current state.

**Acceptance criteria (Amendment 5).**
- [ ] `beach_facing_degrees` and per-transect bearings reflect the isobath-normal on real bathymetry, collapsing
  to the segment-perpendicular on a straight beach and falling back (with WARNING) on degenerate bathymetry.
- [ ] L1 offshore aim and WW3 boundary sides track the open-water bearing; a wrap-candidate direction enlarges L1
  to enclose the intervening land + open water beyond; a Great Lakes spot sizes L1 by lake fetch, not ocean shelf.
- [ ] L4 `alpc` derives from the OMBB long-axis with tip/base re-anchored; obstacles < 500 m apart merge to one
  L4; a separate far obstacle is logged to concerns, not given a second grid.
- [ ] The L3 trigger reads the derived break-type; a config `topographic_feature` still overrides; a config
  without it validates.
- [ ] Pier emits `TRANSM 0.74`; seawall `REFL 0.9 RSPEC`; a wide solid structure burns into L4 BOTTOM with no
  OBSTACLE line; an already-emergent structure injects 0 cells (logged).
- [ ] No SWAN command syntax changed anywhere; a real 4-level run parses, runs, and converges on the re-aimed /
  re-sized / re-axed grids (Gate GR).
- [ ] The served headline re-validates against the contemporaneous cam/Surfline at the Phase-3 pinned tolerance
  after the geometry lands (Gate GR — non-negotiable, because the per-transect bearing flows into the shadow
  classification and the headline aggregate).

### Amendment 6 (2026-08-01): L4 sizing reversed from the OMBB structure axis to a beach-frame transect-shadow envelope; no primary-structure selection

**Status: Accepted.** Operator-approved in chat, 2026-08-01 ("Phase R, R3 residual").

**What this amendment reverses.** Amendment 5's **AD-4** (above) — L4 `alpc`/`alpn` derived from the
oriented-bounding-box (OMBB) long-axis of the obstacle-plus-shadow footprint, with multi-obstacle proximity
clustering and a primary-structure selection for far-apart obstacles — **never reached a converged deployment**.
Gate G4 failed (the sized grid landed on land/straddled the waterline) and, after the AD-1R facing replacement
(Amendment 5 above) still did not resolve it, root-caused to the AD-4 axis method itself: an OMBB axis rotates
independently of the cross-shore transects the grid must supply a handoff to, so the grid and the transects
co-register only by coincidence (`MARINE-MODEL-RESTORATION-PLAN.md` §R3, "L3-strip viability + frame integrity
under AD-1R facing" — measured 333/352 handoff points landing outside the rotated grid, `valid_fraction` 5.2%).
AD-4's acceptance-criteria bullet above ("L4 `alpc` derives from the OMBB long-axis... obstacles < 500 m apart
merge to one L4...") is **superseded by this amendment and was never met in production** — left in place above
as the historical record of what was approved and attempted, per this project's ADR-correction convention (edit
the amendment that is wrong; add a new amendment for a fundamentally distinct decision, which this is).

**Decision — new design (`compute_structure_grid_domain()`, marine `4e79d21`).** `rotation_deg` = the resolved
**beach facing** (`avg_bearing`, the same AD-1R shoreline-strip-derived bearing every transect and L2/L3 sizing
already use) — never a structure axis. The grid is the beach-frame bounding rectangle of **every eligible
structure's own footprint UNION the handoff points of every surf-area transect any one of them shadows**:
- **Shadow test**, per structure (never a union footprint — a gap between two structures must not itself be
  shadowed): against the ADR-100 geography fetch fan's open rays (any classification but `truly_blocked`;
  `wrap_candidate` counts as open, conservative coverage) — see the companion consumers note added to ADR-100.
- **Shoreward edge** = the minimum-`u` shadowed-transect handoff point (each transect's own first seaward
  crossing of this ADR's `l3_shoreward_edge_depth_m()` ≈1.78 m contour, on its own profile) — never a structure
  footprint point, so a pier root sitting on the beach cannot drag the grid landward.
- **Seaward edge** = the seaward-most footprint point across every eligible structure + one margin wavelength
  (unchanged tip-depth/dispersion arithmetic — only the lookup point moved).
- **Lateral extent** = footprint UNION shadowed handoff points, ± one grid cell (10 m) of slack.
- Zero shadowed transects → L4 is skipped for that cluster (not sized).

**No primary-structure selection (same-day amendment, operator ruling 2026-08-01).** A beach may have no
dominant structure — two equal breakwaters, or a jetty with adjoining breakwaters. Every operator-identified
eligible structure participates in the ONE sized grid; `_cluster_structures_by_proximity()`/
`_select_primary_group()` are deleted. AD-4's "far-apart obstacles give the primary structure the L4, others
logged to concerns" behaviour no longer exists.

**Operator rulings recorded with this amendment:**
- Shadow selection decides grid **inclusion only, never physics** — over-inclusion is benign ("when in doubt,
  include — SWAN inside the box is the authority on the physics").
- The spot PIN is a site designator only and has **zero bearing on any actual measurement** (the operator may
  relocate it along the beach without affecting sizing); the new sizer is pin-independent by construction.
- Transect spacing stays 10 m pending performance data from the first full test run.
- Grid **orientation is decoupled from the structure**: rotation is the beach frame; the structure's true
  orientation is preserved inside the model as the OBSTACLE geometry (AD-8, unaffected by this amendment).

**Scope discipline — unchanged by this amendment.** Same fence as Amendment 5: no SWAN command syntax changes
(only `alpc`/`alpn`/extent values), no change to the 2D→1D handoff surface's first-match L4→L3→L2 control flow,
no change to `l3_shoreward_edge_depth_m()`'s own formula (`1.3 × Hs / γ`, `_MIN_DESIGN_HS_M`), no change to the
convergence gate, HAT landward boundary, or deep-water reference.

**Verification status as of this doc-sync pass (2026-08-01):** commit `4e79d21` is deployed (measured HB regen:
facing 216.4°, L4 46×137 = 6,302 cells, 143/143 transects shadowed, 37 open rays — see PROVIDER-MANUAL.md §14.15
and `MARINE-MODEL-RESTORATION-PLAN.md` §R3 for the full numbers). **A full SWAN test run against this design was
in progress at the time this amendment was written — a converged 4-level run and the reality-gate comparison are
not yet confirmed; do not read this amendment as claiming a passed test run.**

### Amendment 7 (2026-08-01): Per-hour handoff gains a break-suspect-seaward constraint (BD-1/BD-2); primary-break reporting criterion (BD-4)

**Status: Accepted.** Operator-signed 2026-08-01 in
`docs/planning/briefs/SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01.md` (APPROVED, every open parameter ruled in
chat same day). That spec is the design authority and the authorization trail for this amendment — the spec's
own §5 names the handoff-criterion change as architectural (trigger 1: a criterion inside a formula's
selection), so this amendment documents what the spec already authorized, not a new decision made here.

**What this amendment does NOT change.** Amendment 2 §2's breaking-margin target-depth FORMULA —
`handoff depth (this hour) = 1.3 × Hs(hour) / γ` (`breaking_margin_depth_m()`, `services/transect_handoff.py`) —
is **unchanged**. Also unchanged: the grid-frozen-at-setup rule, the L4→L3→L2 first-match-wins selection order
(Amendment 3), the true-grid-boundary no-boundary-cell rule (ADR-095 Amendment 2), and the L2 deep-water
reference (always L2 at 15 m, never the handoff). This amendment adds a CONSTRAINT on which station the
existing formula's nearest-to-target-depth search may select from — it does not touch the formula itself.

**BD-1 — full-band break-suspect scan.** Before selection, every transect's full station band (SWAN's own Hs,
depth, and QB at each station, seaward→shore) is scanned for the outermost suspected break zone:
`find_outermost_break_index()` (`services/transect_handoff.py`) returns the index of the first station (walking
shoreward) where EITHER the existing depth-limited criterion `Hs ≥ γ·depth` (the same `_GAMMA_BREAKING` this
ADR's own formula already uses) OR QB ≥ the existing `_DEFAULT_QB_THRESHOLD` (the same threshold
`refine_handoff_with_qb()` already uses) holds. Both criteria are reused unchanged — no new formula, no new
constant. A `None`/skipped station entry (dry cell, no row this hour) is skipped for the Hs/depth test, never
treated as breaking and never treated as clean. No suspected break anywhere on the band → `None` → the
constraint below does not bind, byte-identical to before this amendment.

**BD-2 — the selected station must be seaward of the outermost suspected break.** `select_hourly_handoff()`
gains `max_seaward_break_index` (both the L4 and L3 branches): when supplied, the nearest-to-target-depth
search is restricted to stations strictly seaward of that index, before applying the SAME formula and the SAME
QB refinement as before. The station immediately seaward of a break zone remains a valid interior candidate —
this is a separate concept from the TRUE grid-boundary exclusion (ADR-095 Amendment 2) and the two are never
conflated. `None` (the default, and every pre-2026-08-01 caller) reproduces the prior unconstrained search
byte-for-byte. This retires "first-crossing-of-target-depth" as a description of the OLD behavior (the search
was already nearest-to-target-depth, not literally first-crossing, by the time of Amendment 2 — the spec's own
defect statement §1.1 named the practical effect on a barred profile: the nearest-to-target search could still
land in the trough between two bars); the retirement is of the missing seaward-of-break guarantee, not of the
target-depth formula.

**Published `handoff_depth_m` follows the actual selection when the constraint binds (adversarial audit Finding
F1, `ea62e85`).** When `max_seaward_break_index` actually displaces the pick from what the unconstrained
nearest-target-depth argmin would have chosen, `HandoffSelection.handoff_depth_m` is now the SELECTED station's
own depth, not the untouched target-depth formula value — mirroring `refine_handoff_with_qb()`'s own T2.2
PART B rule ("the truncation depth must follow the advanced sample"). Without this, `_truncate_bathy_at_handoff()`
(`services/surf_1d_pipeline.py`) truncates the 1D profile at a depth shallower than every station on the
now-seaward-shifted profile and silently drops the transect — reproduced and fixed against the auditor's own
dry-neighbour fixture (`tests/test_break_aware_handoff_domain.py::test_a1_bd2_handoff_depth_survives_bathy_truncation`).
When the constraint does not bind, or is `None`, `handoff_depth_m` is exactly the formula's `target_depth_m` —
unchanged.

**T4B.1 band widening (mechanical prerequisite for BD-1's scan, not itself part of the selection criterion) —
see PROVIDER-MANUAL.md §14.15 for the full mechanism and the measured memory cost.**

**BD-4 — primary-break reporting criterion.** `PartitionBreakResult` gains `primary_break_index` (default 0):
the index into `break_points` (unchanged list, still ordered outermost-first) of the break with the LARGEST
face height — usually but not always the outermost. Every reporting consumer that reads "the reported break"
(`face_height_m`/`hs_at_break_m` on `PartitionBreakResult`, the peel-angle break-point choice,
`per_partition_breaks` summaries, the §11.3 combined-face depth cap, and both `endpoints/beach_profile.py` sites
— see PROVIDER-MANUAL.md and API-MANUAL.md for the endpoint-level semantics) now reads
`break_points[primary_break_index]`. **`INVARIANT_1` and the diagnostic `trace.emit()` sites intentionally keep
reading `break_points[0]` (outermost)** — they exist to observe the outermost/seaward-most break specifically,
not "the reported break," and BD-2's seaward-of-break constraint only strengthens what they observe, never
weakens it.

**Adversarial audit remediation (`ea62e85`, `b60ef92`) — process note.** The initial BD-1/BD-2/BD-4
implementation (`03b33e1`) shipped with a coordinator-run adversarial audit that found two issues before this
round closed: **F1** (BLOCKER, above — `handoff_depth_m` desync from the actual selected station, reproduced
with a dry-neighbour fixture that silently dropped a transect) and **F2** (MAJOR — `endpoints/beach_profile.py`
paired `break_points[0]`'s geometry with the PRIMARY break's face height, a mismatch on any double-break day
with a bigger inner break). Both were fixed and re-audited PASS (6 adversarial edge cases + a non-vacuity
simulation — see `MARINE-MODEL-RESTORATION-PLAN.md` decision log for the full round entry). F2's remediation
flagged, but did not fix as out of its authorized scope, a companion defect in the same file's non-primary
break-points loop (a positional `break_points[1:]` either duplicating the primary entry or omitting the true
outermost break whenever `primary_break_index != 0`); `b60ef92` fixed it as a same-day follow-up, with its own
dedicated test. **No wire/API field renamed by any of this** — `beach_profile.py`'s per-break-point payload has
no `role`/`isPrimary` key to begin with; see API-MANUAL.md §18 for what a consumer can and cannot infer from the
payload shape.

**Deferred, tracked, not part of this amendment's scope:** `_transect_band_depths()` and
`_TRANSECT_BAND_PAD_FRACTION` (the retired Hs-bracket band-sizing helper/constant) are NOT deleted —
`tests/test_swan_l4_intersection.py` still tests `_transect_band_depths()` directly and that test file is
outside this round's allowlist. Deletion is a follow-up round's task, not a defect in this one.

**Verification status as of this doc-sync pass (2026-08-01): live verification pending.** A full SWAN test run
against this design was in progress at the time this amendment was written. No run, convergence, or
reality-gate result is claimed here.

### Amendment 8 (2026-08-08): L1 boundary rebuild pointer — ADR-104

**Status: Accepted.** Operator rulings D1–D13, `docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md`
§8, recorded in full at **ADR-104** ("Island-aware L1 sizing and partition-reconstruction WW3 boundary").
This amendment is a pointer only — it does not restate ADR-104's decision content, per this project's
ADR-correction convention (the decision lives in one place).

**What this decision touches in ADR-093's scope, and its deployment status:**
- **L1's WW3 boundary changes from real per-station `.spec` spectra to gridded-WW3-partition
  reconstruction** — the "Level 1's WW3 boundary is a real, spatially varying multi-station spectrum"
  description above (Context/Consequences, and the SWAN model inputs paragraph of ARCHITECTURE.md) is
  superseded by ADR-104 **(ruled 2026-08-08; lands with Phase B of L1-BOUNDARY-REBUILD-PLAN)**. Until Phase
  B lands, the per-station `.spec` boundary described above stays live exactly as written.
- **L1's offshore extent** (Amendment 3's `shelf + 10 km` inheritance, and ADR-100's fetch-fan horizon this
  ADR consumes) becomes island-aware — decoupled horizon, far-edge enclosure, 100 km cap, near-lee clamp —
  **(ruled 2026-08-08; lands with Phase G of L1-BOUNDARY-REBUILD-PLAN)**. See ADR-100's own amendment note
  for the geometry-subsystem side of this same change.
- **Wind/current/water-level input hardening** (silent-fallback-to-abort conversions, RTOFS/STOFS adoption)
  is a SWAN-inputs change, not a boundary-mechanism change, but is recorded here because it is a
  co-requisite of extending L1 — **(ruled 2026-08-08; lands with Phases W/S of L1-BOUNDARY-REBUILD-PLAN)**.

No SWAN command syntax changes by this amendment beyond what ADR-104's own SWAN-syntax prescriptions
specify (the `BOUNDSPEC ... VARIABLE FILE` grammar itself is unchanged; only the file-generation source and
the domain the boundary sits on change). The handoff model, the 1-D surf model, and every physics formula
this ADR governs are unaffected.

### Amendment 9 (2026-08-27): HANDOFF-RESTART — the per-hour handoff is selected by restart, not by the formula alone

**Status: Proposed.**

**Context.** Amendment 2 §2 defined the per-hour handoff depth as `1.3 × Hs(hour) / gamma` — a single
formula lookup against the transect's own station set (Amendment 3's L4/L3/L2 first-match-wins rule for
*which* station set), trusted for the whole hour once computed. No feedback existed from the 1-D surf model
(SwellTrack) back to that choice. Measurement after the BREAK-REFORM round (2026-08-26,
`scratch/inv1/S11-FINDINGS.md`) found SwellTrack reported its main break AT its own starting line on
roughly a third of transect-hours — the formula's assumed ~30% margin and the margin actually realized
against SwellTrack's own 5% breaking-onset criterion is only ~3.5% in practice (`1.72 × Hs` vs `1.78 × Hs`
onset thresholds), close enough that ordinary shoaling variability between the formula's target depth and
SWAN's own discrete station grid regularly erases it.

**Operator's ruling (Q11, verbatim), quoted as this amendment's basis:**

> "the handoff point is never SET IN STONE, it needs to continuously change based upon the break
> locations. That means if it is unusually larger waves the handoff is going to move seaward ... that is
> the way it was supposed to work" / "No you cannot fucking set the next cycle based upon the previous
> cycle, you need to dynamically set the handoff, if 1d starts running and finds the break is wrong, then
> it restarts the run from the correct location."

**Decision.** The formula's station (Amendment 2 §2, unchanged) becomes the FIRST ATTEMPT only, not the
final answer. SwellTrack checks its own result against an acceptance test — (i) the wave at the profile's
own first node is not already breaking (below the 5% `Q_B_VISIBLE` onset criterion), AND (ii) any published
break marker sits at least `HANDOFF_BREAK_CLEARANCE_M` (10 m — one L4 cell, matching the SWAN band's own
10 m station spacing, RULED 2026-08-27: *"if that is the size of the L4 grid then that is fine"*) shoreward
of the handoff station used. Any failure re-truncates the SHARED per-transect-hour profile at the next
SWAN band station seaward (the existing T4B.1 10 m band, Amendment 2 §2's own station set — no new grid,
no new sizing) and re-runs every surfable partition, until every one passes or the band's deep end is
reached (the whole transect-hour is then refused — nothing published from a failed attempt, per
`rules/coding.md` §1). One handoff per transect-hour (not per partition — every partition of a transect
shares one walk and one re-truncated profile; a partition whose own SWAN component has no period match at
a candidate station is simply absent for that attempt, never blocking the others).

**What does NOT change.** The formula itself (`1.3 × Hs / gamma`, Amendment 2 §2) — it remains the FIRST
attempt. The Amendment 3 L4→L3→L2 first-match-wins rule for which station SET a transect reads from — the
restart walks stations WITHIN one already-selected set, never across levels. No SWAN grid geometry is
resized; the band this walks was already sized at setup (T4B.1). `select_hourly_handoff()`'s and
`refine_handoff_with_qb()`'s own logic bodies are unchanged.

**INVARIANT_1 redefined** (the alarm's own bug, Q11 finding A, closed the same round it created): compares
the break depth and the handoff depth on the same UNTIED (chart-datum) basis — the prior definition
compared a tide-adjusted break depth against an untied handoff depth — AND requires the same clearance
test the restart loop itself enforces. A post-amendment firing means the restart loop failed to hold its
own contract, not a tide-datum mismatch.

**Full design record:** `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"S12 — HANDOFF-RESTART" (Design
items 1–7, Lead mechanics M1–M9) and Q11. Implementation: PROVIDER-MANUAL §14.15 Amendment "HANDOFF-RESTART
— the handoff station is checked, not trusted", API-MANUAL §17 (`handoffDepthM`/`handoffSourceLevel`),
`services/transect_handoff.py` (`HANDOFF_BREAK_CLEARANCE_M`), `services/surf_1d_pipeline.py`
(`_run_pipeline_per_transect()`'s restart loop, both INVARIANT_1 sites), `services/surf_1d_analytical.py`
(`Analytical1DResult.onset_at_node0`), `services/swan_runner.py` (`band_stations` on the published handoff
entry), `state.py`/`endpoints/health.py` (`handoffRestart` counters).

## References

- Supersedes: ADR-084 (NWPS as primary nearshore source with supplementation)
- Related: ADR-094 (HRRR forecast wind source for surf scoring); ADR-100 (geography-aware study-area geometry — the OSM coastline + fetch-fan subsystem Amendment 5's AD-1/AD-3/AD-4/AD-5 consume); ADR-104 (island-aware L1 sizing and partition-reconstruction WW3 boundary — Amendment 8)
- Plan (Amendment 5): `docs/archive/MARINE-GEOMETRY-MODEL-PLAN.md` (architecture decisions AD-1..AD-8; approval of the plan IS the acceptance of Amendment 5 and ADR-100)
- Plan (Amendment 9): `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"S12 — HANDOFF-RESTART" and Q11
- Research: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md`, `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`, `docs/planning/briefs/1D-MODEL-BENCHMARK-BRIEF.md`
- Plan: `docs/archive/SWAN-TRUSHORE-PLAN.md`, `docs/archive/SURF-1D-IMPLEMENTATION-PLAN.md`, `docs/archive/SURF-MODEL-FIX-PLAN.md`
