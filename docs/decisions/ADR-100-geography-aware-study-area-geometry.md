---
status: Accepted
date: 2026-07-31
deciders: shane
supersedes:
superseded-by:
---

# ADR-100: Geography-aware study-area geometry — OSM coastline, wrap-aware fetch fan, classification-first, two-stage basis

## Context

The SWAN nearshore model (ADR-093) derives *where and which way it looks* — beach facing, transect bearing, L1
offshore aim, the WaveWatch III boundary sides, and directional exposure — from the operator-drawn shoreline
segment and a set of **typed wizard fields** (`directional_exposure`, `topographic_feature`). That derivation
assumes a straight, open, singly-facing beach. It is inadequate for the US coasts this system must serve:
curved shores, point breaks, bays, island- and headland-sheltered coasts, and the Great Lakes (operator scope:
US + Great Lakes now; non-US intricate coasts must not be *precluded* by the architecture but are out of
near-term scope).

Three specific defects motivated this decision (STUDY-AREA-GEOMETRY-BRIEF, Fable-reviewed twice, 24 findings):

1. **Exposure is typed by the operator, not measured.** An 8-sector `directional_exposure` boolean dict is
   error-prone and cannot represent a point break where swell *wraps* around a headland — the case where the
   operator is least able to reason about which directions arrive.
2. **The study-area basis is inconsistent** — the shoreline is traced on OSM in the wizard but the domain is
   sized from the DEM, with no reconciliation between the two (brief §1 defect 4).
3. **Two same-named `classify_region` functions exist** (`enrichment/bathymetry.py` coarse-coastal;
   `enrichment/fishing_species.py` biogeographic), inviting a future agent to merge them — which would be a
   bug, because they answer different questions.

ADR-093 Amendment 5 records the changes to how the SWAN model *consumes* geography (isobath-normal facing,
open-water L1 aim, L4 axis/extent [originally the OMBB structure axis per AD-4; reversed to a beach-frame
transect-shadow envelope by ADR-093 Amendment 6, 2026-08-01], curvature break-type, obstacle representation —
AD-1/AD-3/AD-4/AD-5/AD-8).
**This ADR records the net-new geography-*determination* subsystem those changes read from** — AD-2 (fetch fan
+ classification-first + derived exposure), AD-6 (OSM two-stage study-area basis), AD-7 (classifier reuse). It
is a distinct decision because it introduces a **new external data source** (OSM/Overpass `natural=coastline`)
and a **new module** (`services/geography.py`), run at config time only.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Keep typed `directional_exposure`/`topographic_feature` (current) | No new code, no new data source | Operator must reason about wrap-around exposure they cannot see; error-prone; cannot serve point breaks or the Great Lakes correctly |
| Ship a global land-polygon file for the openness fan | No live dependency at config time | Large shipped asset; stale; still needs bathymetry for facing anyway |
| **OSM coastline via Overpass + wrap-aware fetch fan + two-stage basis (chosen)** | Measures exposure and open-water direction from real geometry; models wrap-around instead of flagging it; reuses the Overpass mechanism the wizard already uses; OSM is the one truly-global layer; bathymetry (US-only) gates region expansion, not OSM | New external dependency at config time (Overpass); new module; requires a coastline-orientation land/water convention |

## Decision

A new module, **`weewx_clearskies_marine/services/geography.py`**, runs **first** at config time (with the
grid-sizing chain, never per-forecast-cycle), per study area. It has three responsibilities.

### 1. Water-body classification (AD-2, AD-7)

Classify the study area as **open ocean / semi-enclosed / enclosed basin / Great Lakes**, selecting the physics
regime and its parameters. This reuses the **existing coarse regional** `classify_region` (which already
carries `REGION_GREAT_LAKES` and drives bathymetry source order, vertical datum, the WW3 product, and tide)
plus coastline-enclosure geometry — **NOT a new third classifier.**

**AD-7 — the two `classify_region` functions are NOT merged.** They serve different taxonomies:
`enrichment/bathymetry.py`'s is the **coarse 5-region coastal** set (`REGION_PACIFIC/ATLANTIC/GULF/HAWAII/
GREAT_LAKES`); `enrichment/fishing_species.py`'s is the **finer 11-region biogeographic** set
(`BIOGEOGRAPHIC_REGIONS`, e.g. `atlantic_se`) for species zones. Merging them is a bug. The geometry
water-body regime is the coarse-coastal question, so it reuses/extends the `bathymetry.py` classifier — moved
to a shared `services/region.py` (a pure move, identical logic) so both bathymetry and geography import it. The
fishing classifier is renamed `classify_biogeographic_region` to end the same-name collision and is otherwise
left as-is.

### 2. OSM coastline layer (AD-2, AD-6)

The coastline is fetched at config time by an Overpass query `way["natural"="coastline"](<bbox>);out geom;`
with **bbox = study-area centroid ± the regime horizon** (the coastline must reach the horizon the fan casts
to, not merely the bathymetry footprint), parsed into shapely lines, and cached bbox-keyed like bathymetry.
HTTP goes through the marine repo's existing shared urllib client (`providers/_common/http.py`) — **no
`requests` dependency added.** **On Overpass unavailable → raise (no silent fallback)** (rules/coding.md §1):
OSM is the one layer that must be reachable. No global land-polygon file is shipped. *(Verified viable
2026-07-30: a live `natural=coastline` query for the Huntington Beach bbox returned 46 KB of usable inline
coastline geometry, HTTP 200, ~2 s.)*

### 3. Wrap-aware fetch/openness fan + regime + exposure + open-water bearing (AD-2)

Cast **72 rays at 5° increments** from the study-area centroid to the **regime horizon**. **A ray that hits
land does NOT stop** — it continues and tests whether **open ocean resumes beyond** the land within the
horizon. Each direction is classified:

- **directly-open** — open ocean in the direct line;
- **wrap-candidate** — land in the direct line but ≥ 5 km of continuous open water **beyond** it within the
  horizon (a peninsula / headland / island with open water on the far side — the **point-break case**);
- **truly-blocked** — land to the horizon with no open water beyond (the back of a bay, a deep cove).

**Pinned parameters (methodology numbers — implement, do not re-derive):**
- **Ocean horizon** = `find_shelf_distance(centroid) + 10 km` (fallback 40 km if it returns `None`).
- **Great Lakes horizon** = the far-shore distance along the ray, capped at 200 km (Lake Superior scale).
- **Ray-march step** = 1 km; **min open-water run for wrap-candidate** = ≥ 5 km continuous water beyond land.
- **Land/water determination** = the **OSM coastline orientation convention** (land on the LEFT, water on the
  RIGHT of the way's node order), **not** crossing-parity (OSM `natural=coastline` ways are unclosed lines
  clipped at the bbox, so parity is unreliable).

The fan yields **(a) exposure** — directly-open **and** wrap-candidate count as EXPOSED, truly-blocked as
sheltered (this object replaces the typed 8-sector `directional_exposure`, in the same dict-of-sectors shape
the L4 sizer and surf-scorer already consume) — and **(b) the open-water bearing** (the openness-weighted
seaward direction, feeding ADR-093 Amendment 5 AD-3), and **(c) a fetch value** (the open-water fetch along the
dominant open direction, used to size L1 in the Great Lakes where there is no shelf edge).

**Consumers note added 2026-08-01 (ADR-093 Amendment 6).** The fan's individual **rays** (`RayResult`, not just
the aggregate exposure/bearing/fetch outputs above) gained a fourth consumer: `compute_structure_grid_domain()`
now takes the fan's rays directly (`open_rays`, every ray whose classification is not `truly_blocked` —
`wrap_candidate` counts as open) to classify which surf-area transects a structure shadows, which decides the
**L4 structure grid's own extent** (shoreward/seaward/lateral edges — see ADR-093 Amendment 6 for the sizing
rule). This is additive: the fan's ray-casting, classification, and its three existing outputs (exposure,
open-water bearing, fetch value) are unchanged; L4 sizing is a new reader of the same `rays` list, not a new
computation inside `services/geography.py`.

**CRITICAL — the fan does NOT decide how much energy arrives; SWAN does.** For every directly-open and
wrap-candidate direction, L1 is sized to **enclose the open water AND any intervening land**
(peninsula/headland/island) and the WW3 boundary is placed on the open-water side; SWAN then computes the
actual refraction/diffraction wrap-around at the spot ("islands are MODELLED, not flagged," extended to
headlands and peninsulas). The fan is a **domain-sizing + boundary-side-selection aid and a coarse openness
descriptor — never the final exposure verdict** (the modeled wave field is). What the fan's fetch VALUE feeds:
water-body classification, exposure, the open-water bearing, and **Great Lakes L1 sizing** — it does **NOT**
feed a 1-D wind-sea growth term (wind-sea generation is SWAN's job; the Young & Verhagen 1-D term is dropped —
ADR-093 Amendment 5). A **"boxed-in" spot** (no direction with sufficient open water/fetch) is a natural limit,
not a special case: the exposure computation says so directly (no surfable waves), and SWAN correctly returns
near-zero there.

### Two-stage study-area basis (AD-6)

- **Stage 1 (OSM, global, coarse):** coastline, water-body classification, the fetch fan, and the bathymetry
  download footprint; **L1** (super-sized, axis-aligned) is frozen after this stage.
- **Stage 2 (local bathymetry):** the precise per-transect isobath facing (ADR-093 Amendment 5 AD-1) and the
  inner nests (L3/L4) + transects.
- **Self-check:** compare the Stage-1 OSM coastline heading with the Stage-2 isobath heading — agreement ⇒
  trust both; sharp divergence ⇒ auto-flag with a WARNING (bad OSM coastline *or* anomalous bathymetry). No
  separate flagger module.
- **Bathymetry availability gates region expansion** (US-only today for that reason); OSM is the only layer
  that must be truly global.

## Consequences

- **New external data source at config time:** Overpass `natural=coastline`. Cached bbox-keyed. Unreachable →
  raise (no silent fallback). Reuses the existing shared urllib HTTP client — no new pip dependency.
- **New module:** `services/geography.py` (OSM coastline fetch + cache, wrap-aware fetch fan, regime +
  exposure + open-water bearing + fetch value). Runs at config time only, in the grid-sizing chain.
- **New shared module:** `services/region.py` (the coarse-coastal `classify_region` + `REGION_*` constants,
  moved out of `enrichment/bathymetry.py` unchanged; both bathymetry and geography import it).
- **Rename:** `enrichment/fishing_species.py`'s `classify_region` → `classify_biogeographic_region` (callers
  in `endpoints/fishing.py` and internally updated). No behaviour change.
- **Wizard field removals:** `directional_exposure` and `topographic_feature` are no longer *required* inputs —
  each is now fan-derived / curvature-derived by default, retained as an **optional override** (ADR-093
  Amendment 5 AD-5 for `topographic_feature`; AD-2 for `directional_exposure`). Help-content doc-sync lands
  per-phase with the wizard change.
- **Draw-tool polygon mode** is enabled alongside the polyline in the wizard (operator draws the surf area; the
  rest is derived), merged with the OSM tracing UX.
- **Consumers unchanged in shape:** L4 sizing (`compute_structure_grid_domain(directional_exposure=…)`) and the
  surf-scorer read the derived exposure via the same dict-of-sectors contract; L1 aim + WW3 side-select read
  the open-water bearing. No data contract shape changes — only the *source* of the values.

## Acceptance criteria

- [ ] `services/geography.py` exists; runs at config time only; never in the per-forecast-cycle path.
- [ ] A live Overpass `natural=coastline` query for the study bbox returns and caches coastline geometry;
  Overpass unreachable raises (no silent fallback) — proven by an auditor.
- [ ] The fetch fan casts 72 rays; a ray hitting land continues and detects ≥ 5 km open water beyond within the
  horizon (no ray silently stops at first land — proven by an auditor).
- [ ] Synthetic KATs: a straight open coast → all seaward rays directly-open, one broad exposed sector; a
  peninsula with ocean beyond → those rays wrap-candidate (EXPOSED), not blocked; a tight cove → truly-blocked
  all around → "no surfable waves"; a Great-Lakes-shaped basin → regime `GREAT_LAKES`, finite fetch value.
- [ ] `services/region.py` holds one coastal `classify_region`; `fishing_species.py` holds one
  `classify_biogeographic_region`; both return exactly what they returned before (KAT: same inputs → same
  strings); the two are never collapsed into one function.
- [ ] Stage 1 freezes L1 before Stage 2 facing; the OSM-heading vs isobath-heading self-check flags a divergent
  synthetic pair and passes an aligned one.

## Amendment (2026-08-08): L1 boundary rebuild pointer — ADR-104

**Status: Accepted.** Operator rulings D1–D13,
`docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` §8, recorded in full at **ADR-104**
("Island-aware L1 sizing and partition-reconstruction WW3 boundary"). Pointer only — decision content is not
restated here.

**What this decision touches in ADR-100's scope, and its deployment status:** the fetch fan's **ocean
horizon** (pinned here as `find_shelf_distance(centroid) + 10 km`, fallback 40 km) is decoupled from shelf
distance entirely — a ray that used to terminate at ~20 km at a shelf-narrow coast now marches to a fixed
100 km cap, so a ray toward a genuinely offshore island (Catalina at HB) can reach and classify it
`wrap_candidate` instead of `directly_open` **(ruled 2026-08-08; lands with Phase G of
L1-BOUNDARY-REBUILD-PLAN)**. The **enclosure distance** for a wrap-candidate ray (consumed downstream by
`swan_domain.py`, not computed in this module) also changes — from the full horizon to
`open_water_resume_km + 10 km`, capped, with a near-lee clamp for un-enclosable islands — the same tag
applies; see ADR-104 for the full mechanism (D1/D2/D11) and ADR-093 Amendment 8 for the ADR-093-side pointer.
The fan's **ray-casting mechanism itself** (72 rays, wrap-candidate/truly-blocked/directly-open
classification, the `open_water_resume_km` measurement `RayResult` already needs to make this work) is
unchanged — only the pinned horizon and enclosure-distance VALUES move. **Phase G code LANDED 2026-08-09**
(marine `036a2ec`..`e207d79`, KATs `eecfabc`): `L1_MAX_EXTENT_KM = 100.0` in `services/geography.py`
(single source), ocean horizon returns it unconditionally, `RayResult.open_water_resume_km` recorded at
wrap qualification, enclosure at `resume + 10 km` (capped; > cap ⇒ no enclosure point, near-lee clamp),
`[swan] l1_offshore_extent_km` operator override, UTM-zone ±3.5° span guard. One formula gap lead-ruled
2026-08-09 (operator may override pre-G-Accept): a near-lee cluster's `angular_extent_rad` =
(outermost-bearing span + one 5° ray step) — each ray represents its own sector; a single blocked ray is
never zero-width. Deployment happens at G-Accept; until that deploy the RUNNING service still uses the
pre-G sizing.

## Amendment (2026-08-17): WW3 setup derivation gains this subsystem as a consumer — ADR-109

**Status: Accepted.** Recorded by the DOC-W.5 full-index ADR impact sweep
(`docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md`, Phase DOC-W, task DOC-W.5), following
acceptance of **ADR-109** ("WW3 deep-water leg — always-on deep-ocean wave model, handoff to SWAN at
L2"). Pointer + scope note only — this ADR's own decision content (the geography module, the fetch
fan, water-body classification, the two-stage study-area basis) is unchanged.

**What changes.** ADR-109's W4 task ("WW3 setup derivation in grid-sizing," Phase W) reads this
ADR's geography subsystem as a new consumer, alongside the existing L1-aim/WW3-boundary-side-select
consumers this ADR already documents. Specifically: the fetch fan's **open-water bearing** and
**regime classification** (this ADR's §3, "Wrap-aware fetch/openness fan + regime + exposure +
open-water bearing") — already read by ADR-093 Amendment 5 for L1 aim and WW3 boundary-side
selection — are also read by ADR-109's W4 derivation to place the WW3 deep-water leg's own grid
extent, boundary placement, and time steps mechanically at config time (ADR-109 D3, D8; PW2's
"regional input, never spot-local" rule this ADR's own domain-extent language already states). This
ADR's own "WaveWatch III boundary sides" language (§3, "the open-water bearing... feeding ADR-093
Amendment 5 AD-3") now also feeds OUR own WW3 domain (ADR-109) at target state, not only the
existing WW3-as-NOAA's-own-output boundary-side read this ADR was originally written against.

**No data-contract or module change.** `services/geography.py`'s outputs (exposure, open-water
bearing, fetch value, the `RayResult` list) are read-only-consumed by ADR-109's W4 task in their
existing shape — this amendment adds a reader, not a new output or a new computation inside this
module.

## References

- Related: ADR-093 (SWAN nearshore model) Amendment 5 (the model-derivation changes that consume this
  subsystem — AD-1/AD-3/AD-4/AD-5/AD-8); ADR-098 (datum match-at-source, which the Stage-2 bathymetry relies on);
  ADR-104 (island-aware L1 sizing and partition-reconstruction WW3 boundary — Amendment above); ADR-109
  (WW3 deep-water leg — Amendment above, DOC-W.5)
- Plan: `docs/archive/MARINE-GEOMETRY-MODEL-PLAN.md` (architecture decisions AD-2/AD-6/AD-7; Phases G0/G6;
  approval of the plan IS the acceptance of this ADR)
- Brief: `docs/planning/briefs/STUDY-AREA-GEOMETRY-BRIEF.md` (Fable-reviewed x2, 24 findings incorporated)
