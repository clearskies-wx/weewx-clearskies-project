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
open-water L1 aim, OMBB L4 axis, curvature break-type, obstacle representation — AD-1/AD-3/AD-4/AD-5/AD-8).
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

## References

- Related: ADR-093 (SWAN nearshore model) Amendment 5 (the model-derivation changes that consume this
  subsystem — AD-1/AD-3/AD-4/AD-5/AD-8); ADR-098 (datum match-at-source, which the Stage-2 bathymetry relies on)
- Plan: `docs/planning/MARINE-GEOMETRY-MODEL-PLAN.md` (architecture decisions AD-2/AD-6/AD-7; Phases G0/G6;
  approval of the plan IS the acceptance of this ADR)
- Brief: `docs/planning/briefs/STUDY-AREA-GEOMETRY-BRIEF.md` (Fable-reviewed x2, 24 findings incorporated)
