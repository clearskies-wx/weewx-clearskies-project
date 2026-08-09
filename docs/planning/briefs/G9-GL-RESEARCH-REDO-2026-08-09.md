# Great Lakes grid-start research (REDO) — evidence record (2026-08-09)

Operator-ordered redo after the first research was rejected for asking the wrong
question (box size/stationarity instead of depth-validity envelopes). The operator's
reframe governs: establish what depths GLWU operates correctly in (as the ocean
design once established WW3 needs deep water) and what depths OUR L1/L2/L3/L4 serve;
answer where our lake grid should START. Findings verbatim from the research agent;
the plain-English argument + the three decisions synthesized from them live in the
plan §G9-GL. No recommendations — the operator rules.

Terms: WW3 = WAVEWATCH III (NOAA spectral wave model; "spectrum" = wave-energy
distribution over frequency and direction). GLWU = Great Lakes Wave Unstructured,
NOAA's WW3 configuration for the lakes. SWAN = the nearshore model we run on nested
grids L1→L4. Boundary = the offshore grid edge where SWAN receives incoming spectra.

## Q1. WW3's deep-water limitation and where our design records it

- SWAN manual (`docs/reference/swan-user-manual.txt:427-435`): "the deep water
  boundary of the SWAN nest must be located in WAM or WAVEWATCH III where shallow
  water effects do not dominate (to avoid too large discontinuities between the two
  models). Also, the spatial and spectral resolutions should not differ more than a
  factor two or three."
- Our ocean "WW3 is trustworthy here" test (ADR-103 `docs/decisions/ADR-103-spectral-
  boundary.md:87-103`; PROVIDER-MANUAL `:1386`): deep water = `depth_m ≥ 0.78 ×
  T_max²` (linear theory: depth > half the deep-water wavelength, L0 = 1.56 T²; 15 s
  → ~176 m, 20 s → ~312 m); OR `tanh(kd)` agreement within ≈0.321 (C-104, never
  operator-signed); plus distance ≤ one native WW3 cell (~18.5 km ocean / 2.5 km
  GLWU).
- That depth criterion was RETIRED 2026-08-09 with the station path (ADR-104 D3/D4;
  PROVIDER-MANUAL §14.3a/b Amendment :1413-1489) — today no depth test is applied at
  the boundary; validity is implicit in where the L1 edge sits. Why the ocean L1 is
  big is recorded in ADR-104 Context (:11-22): 0.16° WW3 "smears" Catalina; L1
  encloses the island so our model computes the shadowing.

## Q2. GLWU's validity envelope

(a) Physics (GMD 2024, gmd.copernicus.org/articles/17/1023/2024): unstructured mesh
~2.5 km offshore → ~250 m coastal (~253k nodes). Active source terms: ST4 wind
input/dissipation, GMD/NL3 quadruplets, BT1 JONSWAP bottom friction, DB1
Battjes–Janssen depth-induced breaking, IC0 ice. NOT modeled: water-level and current
effects (named future work); triads not listed (TR switch setting could not be
established). Verification: 25 buoys; the paper concedes buoys are "distant from
coastlines" and notes "the lack of coastal observations, where the dominant waves
might interact with the bottom." BAMS 2023 (Alves et al., doi:10.1175/BAMS-D-22-
0094.1; AMS site 403'd, figures via secondary sources): GLWUv1 hindcast = 6
deep-water + 4 nearshore buoys; NDBC Great Lakes nearshore buoys sit ~19–23 m
(45161 Muskegon 22.5 m; 45170 Michigan City 19 m — ndbc.noaa.gov station pages).
**Quantitative validation floor ≈ 20 m depth; nothing shallower ever verified; surf
zone outside the observed envelope.**

(b) NOMADS gridded products (live enumeration of
`nomads.ncep.noaa.gov/pub/data/nccf/com/glwu/prod/glwu.20260809/` + gribfilter page):

| Grid token | Resolution | Cycles | Forecast length (live .idx count) | Partition fields |
|---|---|---|---|---|
| `grlc_2p5km` | 2.5 km | 4/day (t01/07/13/19z) | 0–149 h hourly | Yes (HTSGW, WVHGT/WVPER/WVDIR, SWELL/SWPER/SWDIR ×3, wind) |
| `grlc_2p5km_sr` | 2.5 km | hourly | 0–48 h | Yes |
| `grlr_500m` | 0.005°×0.0035° ≈ 400 m (live-parsed GRIB2 grid def) | hourly | **0–48 h only** | Yes (same set) |
| `glwu.glwu.tCCz.nc` | native mesh NetCDF (249 MB) | — | — | not inspected |
| + `_lc` land-cut variants, station .spec bulls, spec/ts tarballs | | | | |

`grlr_500m` is subsettable through the SAME `filter_glwu.pl` CGI our fetcher uses
(live-verified for Lake Michigan east shore, Lake Erie north shore, Lake Superior
bboxes — effectively whole-domain) and carries every partition field
`boundary_reconstruction.py` needs. BUT it reaches only 48 h; our fetcher requires 72
hourly steps (`_GLWU_FORECAST_HOURS = 72`, `ww3_partition_fields.py:393`); current
code consumes `grlc_2p5km` only (`ww3_partition_fields.py:402`).

(c) Bottom line (evidence): GLWU physics is valid into intermediate/shallow water;
demonstrated validity stops at ~20 m; native floor 250 m but the products available
to us are 2.5 km (72 h+) or ~400–500 m (48 h); no water-level/current modulation and
(apparently) no triads. Defensible reading: trustworthy boundary source seaward of
roughly the 20 m contour, degrading coastward; never a surf-zone source.

## Q3. Our nest levels' operating envelopes

| Level | Resolution | Outer edge | Inner edge / handoff | Physics it adds |
|---|---|---|---|---|
| L1 | 1 km (`swan_domain.py:648`) | Ocean: fetch-fan/island-aware, box ≤100 km/axis (`geography.py:133`, clamp `swan_domain.py:1405-1459`). **Lakes: fetch+10 km uncapped, 200 km horizon** (`swan_domain.py:1265-1266`, `geography.py:114`, GL cap-exempt `:1417-1425`) | shore | Island shadowing/wrap, wind-sea growth over real fetch, currents+water-level forcing; boundary = reconstructed spectra per 1 km cell; hourly stationary solves (ADR-104 D2) |
| L2 | 100 m, margin 2 km | measured **30 m contour**, max across spots/transects (`swan_domain.py:883-886`, `grid_sizing_chain.py:1457-1538`) | shore; open-beach handoff read at fixed 15 m; 15 m deep-water reference SPECOUT always L2 (INVARIANT_7) | Nearshore refraction/shoaling; NESTOUT→L3; TRIAD on |
| L3 | 40 m (`swan_domain.py:357`) | (a) structure-nest: L4 + ≥200 m clearance; (b) refraction grid: 15 m contour (`:934`) | (b) per-hour breaking-depth contour | Refraction at classified breaks; diffraction OFF (ADR-093 Am.3) |
| L4 | 10 m | beach-frame envelope of structure footprint ∪ shadowed-transect handoff points (ADR-093 Am.6) | min-shadowed-transect handoff point | Structure transmission/reflection, DIFFRACTION (only level), obstacle burn-in |
| 1-D SwellTrack | per-transect | handoff: fine-grid 1.3×Hs/0.73 (~30% seaward of breaking), open-beach 15 m | HAT up the beach face | Breaking + surf transformation; SWAN never models the break zone (`ARCHITECTURE.md:98-103`) |

## Q4. The match-up — what skipping L1 on lakes touches

GLWU's validated envelope (≥ ~20 m) overlaps L2's outer edge (30 m); an L2-class
boundary at 30 m sits inside water GLWU's physics covers and at/seaward of its
verified depth class. A lake L1 (fetch+10 @1 km) recomputes the lake coarser than
GLWU's own 250 m coastal mesh and recreates the ocean stationarity violation.

Dependency points (file:line):
1. Reconstruction targets L1 explicitly: `boundary_reconstruction.py:1-21` (contract);
   `providers/nearshore/swan.py:2956-2971` (runtime passes `domains.level1`);
   `grid_sizing_chain.py:678-758` (smoke test); corridor bbox = L1 + 1 native cell
   (`ww3_partition_fields.py:156-171`); product routing classifies the L1 centre
   (`ww3_partition_fields.py:141`).
2. L2's boundary is BOUNDNEST1←L1: chain "L1 → NESTOUT → L2 (BOUNDNEST1+NESTOUT) →
   L3" (`swan_runner.py:9`); L2 is built grid_level="outer" (which already writes
   BOUNDSPEC into L2's INPUT) then patched to BOUNDNEST1 reading L1's NESTOUT
   (`swan_runner.py:3326-3414`; log `:3719`). Mechanically: reconstruct on L2's
   extent + don't patch.
3. SWAN manual: BOUNDNEST1 optional (`:2568-2590`); BOUNDSPEC VARIABLE FILE valid on
   any structured grid (`:2380-2470`); resolution-jump advice ≤2–3× (`:433-435`) —
   GLWU 2.5 km→100 m = 25× (500 m product: 5×); ocean already runs 16×, mitigated by
   D4 parameter-space interpolation (our code interpolates partition parameters
   before reconstruction; SWAN never interpolates between distant spectra). D4 pins
   boundary spacing = grid dx → at 100 m, 10× the boundary points/files per km vs L1.
4. Code that assumes L1 exists: `DomainSizing.level1` required (`swan_domain.py:291`);
   chain sizes L1 first + freezes (`grid_sizing_chain.py:1186`, `:902`); wind bbox
   from `domains.level1` (`swan.py:2957-2961`, `:3693-3699`, `:4529-4535`);
   current-source selection = "OFS contains the L1 bbox" (ADR-104 D9); L1 bathy cache
   + ETOPO pin (`swan.py:1001,1087`); F1 geometry signature includes level1
   (`grid_sizing_chain.py:333`); hotstart/run-dir lifecycle (`:415-420,471`);
   discovery reports L1 cells (`endpoints/discovery.py:269-271`);
   `marine_config.py:1093-1107` reads `domains.level1`; `build_swan_input` demands
   boundary lines + inner_dims per "outer" call (`swan_formats.py:1566-1571`).
   Handoff selection (L4→L3→L2) and the 15 m reference never touch L1.
5. Lake wind sea: ARCHITECTURE.md:116 "GLWU boundary + SWAN growth" — reconstruction
   partition 0 IS GLWU's wind sea, so incoming wind sea arrives through the boundary
   at any grid size; a small grid loses only locally-grown fetch beyond its span —
   the computation GLWU already did.

## Q5. Lake depth reality (live NCEI DEM transect probes, gis.ngdc.noaa.gov)

- Lake Michigan east shore (Muskegon 43.23N): 15 m @ ~1.8 km, 26 m @ ~4.9 km,
  **30 m @ ~6.1 km**, 63 m @ ~13 km, ~110–117 m mid-lake. Comparable to HB (30 m @
  ~4.5–5 km).
- Lake Erie north shore central basin (Port Stanley −81.22): 10 m @ ~2 km, then flat
  at 20–22 m for ~50 km — **no 30 m contour on the transect** (central basin max
  ~25 m); eastern transect (−79.25) never passes 24 m; only the small eastern trench
  (max 64 m) reaches 30 m. Basin stats: Erie mean 19 m; western 7.4/19, central
  18.3/25, eastern 24/64 (ohiodnr.gov; ngdc.noaa.gov).
- Consequence in our code: `find_depth_contour_distance(..., 30.0)` raises if not
  reached within 60 km (`enrichment/bathymetry.py:1383-1427`, LC-10 "an ERROR, not a
  fallback") → sizing chain aborts, no cache (`grid_sizing_chain.py:1532-1537`).
  As coded, most of Lake Erie cannot be configured at all.

## Could not establish
- Whether GLWU compiles a triad (TR) switch (GMD 2024 physics list omits it).
- The declared geographic extent of `grlr_500m` (probes indicate whole-domain;
  per-message GRIB parsing confirmed 0.005°×0.0035° spacing).
- Full BAMS 2023 text (AMS 403) — nearshore-buoy identities/depths inferred from the
  v1 hindcast description + NDBC pages.
- Any GLWU skill statistic shallower than ~19 m depth — none appears to exist.
