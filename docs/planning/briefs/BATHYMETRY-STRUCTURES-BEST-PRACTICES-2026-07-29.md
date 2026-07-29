# Incorporating structures into wave-model bathymetry + how structures read in DEMs (2026-07-29)

**Provenance:** research agent, third-party literature only (SWAN manual NOT consulted — local; used
Delft3D/XBeach/FEMA/USGS/CUDEM analogues). Feeds Track B / T4.2a of `MARINE-WORKING-MODEL-PLAN.md`.
Confidence tags inline. Two primary sources (FEMA Coastal Structures PDF [1]; CUDEM paper [6]) read via
search layer only (hosts block fetch) — corroborated, flagged.

---

## A. Incorporating a structure into the bathymetry — best practice

### A1 — What elevation to assign (load-bearing)
Burn the structure in as a **real finite elevation, NOT the model's nodata/exception sentinel.** FEMA
keeps fixed coastal structures "intact" in the model terrain [1]. XBeach represents breakwaters/seawalls
as a non-erodible layer at a fixed structure-bottom elevation [21]; Delft3D separates **bathymetry
elevation** / **dry points** (emergent block) / **thin dams** (sub-grid barrier, no width — SWAN OBSTACLE
analogue) [22] — the same width-based split we use.

| Approach | Value | Physics | Use |
|---|---|---|---|
| **Hard dry block** *(default for solid emergent)* | fixed elevation **above the run's max still-water level** (max tide+surge+setup)+margin, e.g. +5 m | permanently dry → blocks, casts lee shadow, waves diffract around | solid breakwater/jetty/mole. **Risk:** "just dry" at MSL floods at high water — set above true max WL |
| **True crest elevation** | real crest height in DEM datum | block at low water; **overtopping/transmission** captured when WL > crest | low-crested/tidal-surf sites where overtopping matters |
| **Shallow shoal** | ~0.5–1 m below still water | dissipates by **depth-induced breaking**, transmits remainder (NOT a wall) | genuinely submerged/low-crested only. **Wrong for a solid barrier** — leaks into lee |

Block-vs-shoal is a **physics choice, not a tuning knob** (reflection/shadow vs breaking dissipation).
Even a correct dry block needs the model's **diffraction approximation ON** for a physical lee [30].

### A2 — Rasterization & edge handling (load-bearing)
- **Cell-center-in-polygon** (gdal/rasterio default): drops cells a narrow polygon covers but whose
  center it misses → **gappy, leaky** barrier. Not safe for narrow structures [10].
- **ALL_TOUCHED**: gap-free but **over-widens by up to 1 cell/edge**, order-dependent on boundaries →
  over-blocks + extra reflecting face [10][11].
- **Coverage-fraction (recommended):** per-cell polygon-coverage 0–1 (exactextract), classify emergent at
  **area-majority ≥0.5**, then **enforce along-axis connectivity** (morphological closing) so no one-cell
  hole opens a spurious channel — and check the converse (don't seal a real gap/harbor mouth) [12].
- **Graded/tapered edge** (outer ring a shoal step, not a full vertical face) to cut grid-aligned
  **staircase over-reflection**: axis-aligned blocks reflect too strongly; stair-stepped diagonals alias
  to reflection "much higher than exact" [15][16]. Prefer finest source resolution.

### A3 — Crest / freeboard
True crest when WL can reach it (tidal overtopping, low-crested) [14]; "high enough to stay dry" only for
a decided permanent non-overtopped block. Matters most for tidal surf sites & low-crested structures.

### A4 — Datum (silent-error source)
**Convert the structure elevation into the DEM's own vertical datum, and express max WL in that datum**
[6]. DEM datum is **not uniform across tiles** — CONUS CUDEM generally NAVD88, but the Hawaii 1/9" tile
reads MSL/WGS84 [3]. MLLW↔NAVD88 offsets are often 0.3–1+ m (a big fraction of freeboard). Use NOAA
**VDatum**. Mixing tiles of different datum makes a seam step and corrupts the anomaly test in B5.

### A5 — Pitfalls
Single-cell channels/gaps (both directions — leak vs seal a real gap); staircase reflection [15][16];
ALL_TOUCHED over-blocking; hard block engages wet/dry+diffraction while a shoal engages breaking (wrong
one silently swaps the dissipation mechanism); **"emergent" is relative to the run's max WL, not MSL**;
phase-averaged models can't resolve sharp lee diffraction [30].

### A6 — Tools
`gdal_rasterize -burn` (ALL_TOUCHED) [10]; `rasterio.features.rasterize(all_touched=)` [13];
**exactextract** for coverage fraction [12]. XBeach/Delft3D generate non-erodible/dry-point/thin-dam files
as first-class inputs [21][22].

---

## B. How existing structures read in DEMs

### B1 — Which DEMs include structures
Emergent wide structures (rubble breakwaters, jetties, moles, seawalls) are **generally present** in
integrated topobathy DEMs (CUDEM, USGS CoNED) — above-water lidar reads them as elevated ground [8]. CUDEM
bare-earth processing strips **buildings & vegetation** [6], so **solid ground-connected wide structures
survive; thin/elevated/deck structures do not.** Merged bare-earth/seabed surface, not first-return.

### B2 — Resolution / minimum size (load-bearing)
- Source: CUDEM **1/9" ≈ 3 m** (coastal) and **1/3" ≈ 10 m** (offshore) [2]; underlying 3DEP lidar QL2
  ≤0.71 m spacing [5] — raw data sees a rock structure; the DEM cell size + smoothing is the limit.
- **10–30 m breakwater:** at ~3 m spans ~3–10 cells → **reliably resolved** (crest lowered, toe rounded ~1
  cell). At **~10 m: 10 m ≈ 1 cell (sub-grid, may wash out); 20 m ≈ 2; 30 m ≈ 3 (marginal).** Need **~2–3
  cells across** to behave as a resolved obstacle waves go around.
- **Our 10 m L4 grid ≈ 1/3" resolution** → structures **narrower than ~20–30 m are borderline** in both the
  DEM and our grid → those are the thin-OBSTACLE-line regime, not emergent footprint. For sub-20 m solids,
  source the 1/9" (~3 m) tile and resolve before down-sampling, or accept the obstacle line.

### B3 — Typical read-out crest elevations
| Structure | Crest (as quoted) | Metric | Src |
|---|---|---|---|
| Rubble breakwater, moderate-energy (S. FL) | +10–12 ft NAVD88 | +3.0–3.7 m | [24] |
| Rubble breakwater, high-energy (St. Paul, AK) | +30 ft MLLW | +9.1 m | [25] |
| Jetty/groin | +1–3 m local | ~+1–3 m | [14] |
| Seawall/revetment | +2–5 m local | +2–5 m | [14] |
Genuine emergent structure reads **+1 to +9 m** above surrounding seabed; DEM smoothing reads crest a bit
**lower** than as-built.

### B4 — Piers & scour
**Pile piers generally do NOT register**: deck = elevated first-return (filtered out like a building);
piles too thin/submerged for the cell size → little/no solid signature (synthesis, medium confidence).
**Scour trenches** CAN appear as bathymetric depressions IF surveyed by multibeam/green-lidar [29][30-B];
local scour ~1–2.5× pile width; **survey-dependent — a DEM may or may not show it; absence of scour ≠
absence of structure.**

### B5 — Detecting already-present structures (load-bearing — no standard method; use ≥2)
1. **Emergent-cell fraction** over the footprint (share of footprint cells above max WL / MHW). High
   (≳60–70%) → solid emergent structure present. Needs no external data.
2. **Elevation-anomaly vs structure-excluded background:** mask the footprint, IDW/spline-fill from
   surrounding cells, difference. Residual ridge **~+1 to +several m** (cf. B3) → structure baked in.
   Cleanest single discriminator (residual-DEM / burn-detection) [26].
3. Linear-ridge morphological / edge detection (Canny) [28]; 4. perpendicular transect "top-hat" profile.
**Gate the burn on (2)+(1):** positive anomaly AND high emergent fraction → **already present, do NOT
double-burn.** Flag "present but under-resolved" (low anomaly, narrow) separately from "absent."
**Recommend a small ground-truth calibration to set thresholds.**

### B6 — Data-quality caveats
Currency (a recently built/repaired/storm-modified structure may be missing/outdated); inconsistent capture
across merged sources (emergent body from topo-lidar, submerged toe from a bathy source that missed it →
floating ridge); **spline-interpolation smoothing** lowers crests & rounds edges (worst for 1–2-cell
features) [4]; datum heterogeneity across tiles [3]; green-lidar voids interpolated over.

---

## Sources (key)
[1] FEMA Coastal Structures Guidance (Nov 2024) [authoritative, via search]. [2] NOAA NCEI CUDEM product
page [authoritative]. [3] NCEI CUDEM 1/9" tile metadata (Hawaii = MSL/WGS84) [authoritative]. [4] NOAA,
Accuracy of Interpolated Bathymetry / CDEM Uncertainty [authoritative]. [5] USGS 3DEP QLs / Lidar Base Spec
[authoritative]. [6] Amante et al., CUDEMs, Remote Sensing 15(6):1702 (2023) [paper, via search]. [8] USGS
Topobathymetric Mapping [authoritative]. [10] GDAL gdal_rasterize (ALL_TOUCHED) [authoritative]. [11]
GDAL #8918 ALL_TOUCHED edge behavior [forum]. [12] exactextractr coverage-fraction [authoritative].
[13] rasterio.features.rasterize [authoritative]. [14] USACE CEM EM 1110-2-1100 & EM 1110-2-2904
[authoritative]. [15] Nasser et al. 2023 staircase coastlines, JAMES [paper]. [16] arXiv:1402.7201
staircase BCs [paper]. [17] Battjes–Janssen depth-breaking [paper]. [21] XBeach non-erodible layer
[paper]. [22] Delft3D-FLOW (thin dams, dry points) [authoritative]. [24] breakwater crest +10–12 ft NAVD88
[commercial]. [25] St. Paul Harbor +30 ft MLLW, ICCE [paper]. [26] US Patent 6,104,981 man-made-structure
detection in DEM [patent]. [28] Automated Coastline Extraction (edge/ML) [paper]. [29] Multibeam scour
assessment [industry]. [30] Wave-farm SWAN sub-grid-vs-supra-grid + phase-averaged diffraction limit
[paper]; [30-B] green-laser scour monitoring [paper].

## Open / contested
1. No standard "already-present" detector — B5 is a reasoned synthesis; calibrate thresholds on known
   sites. 2. ~2–3-cell minimum width is a rule-of-thumb, not a CUDEM/SWAN constant; the 20–30 m borderline
   is cell arithmetic. 3. Pier non-registration inferred, not single-sourced — spot-check a real pier tile.
4. FEMA/CUDEM quotes via search layer only. 5. Verify the datum of the specific CUDEM tiles under each surf
   site before burning crest elevations. 6. Hard-block reflection depends on SWAN diffraction/obstacle
   settings — needs a sensitivity test.
