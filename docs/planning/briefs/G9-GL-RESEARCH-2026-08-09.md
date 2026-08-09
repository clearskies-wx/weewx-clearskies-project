# G9-GL research record — L1 sizing for Great Lakes sites (2026-08-09, operator-ordered)

Research agent findings, verbatim, collected 2026-08-09 session 5. Options synthesized
from these findings live in the plan §G9-GL; the ruling is the operator's. The
coordinator verified the two central citations (SWAN manual :5715 stationary line;
ARCHITECTURE :108 vs :116 tension) before publishing options.

---

## A. Physics of the stationarity limit in a lake

Group-speed arithmetic (deep water, `cg = gT/4π = 0.781·T m/s`):

| T | cg | 50 km | 100 km | 200 km | 300 km |
|---|---|---|---|---|---|
| 3 s | 2.34 m/s | 5.9 h | 11.9 h | 23.7 h | 35.6 h |
| 5 s | 3.90 m/s | 3.6 h | 7.1 h | 14.2 h | 21.3 h |
| 8 s | 6.25 m/s | 2.2 h | 4.4 h | 8.9 h | 13.3 h |
| 15 s (ocean ref) | 11.71 m/s | 1.2 h | 2.4 h | 4.7 h | 7.1 h |

Lake seas cross a box 2–5× slower than the 15 s ocean swell that motivated the ocean
cap. A 5 s sea takes 7.1 h to cross a 100 km box — worse per crossing-time than the
3.1 h/131 km ocean case the operator rejected at Q6.

Crossing time is the wrong-in-isolation metric for wind sea: the stationary solve
converges the local generation balance to fetch-limited equilibrium under this hour's
wind. The relevant timescale is the duration needed to build the fetch-limited state
(CEM duration-fetch relation `t = 77.23·X^0.67/(U^0.34·g^0.33)`): at U=15 m/s — 5.7 h
for 50 km fetch, 9.0 h for 100 km, 14.3 h for 200 km. Real synoptic winds rarely hold
steady that long → a whole-lake stationary solve systematically assumes an equilibrium
the wind has not had time to build (over-prediction during growth, wrong decay
timing) — the same class of error as the ocean case, arriving via duration limitation
rather than swell transit.

SWAN's own guidance:
- `docs/reference/swan-user-manual.txt:5715-5716` (§4.7 COMPUTE): "For small domains,
  i.e. less than 100 km or 1 deg, a stationary computation is recommended. Otherwise,
  a nonstationary computation is advised." No lake exemption. Almost certainly the
  origin of the 100 km ocean cap number.
- `:771-772`: quasi-stationary = "stationary SWAN computations in a time-varying
  sequence" — exactly this project's scheme; the 100 km line governs it.
- Rogers et al. 2007 (SWAN team, Coastal Engineering;
  falk.ucsd.edu/seminar/Rogers2007CoastalEng.pdf) + SWAN scientific documentation
  (swanmodel.sourceforge.io/download/zip/swantech.pdf): stationary mode is for waves
  with "relatively short residence time in the computational area"; nonstationary
  performed better, with stationary error concentrated in "timing of swell arrivals
  and local sea growth/decay" — the growth/decay half is the lake wind-sea case.
- Great Lakes practice is uniformly nonstationary at lake scale: NOAA GLWU is
  nonstationary WAVEWATCH III (gmd.copernicus.org/articles/17/1023/2024;
  glerl.noaa.gov/emf/waves/WW3); a 20-year Lake Michigan SWAN hindcast at ~1 km ran
  time-stepping on HPC (frontiersin.org/articles/10.3389/fmars.2021.746916), not
  hourly stationary snapshots. Stationary SWAN lake validations in the literature are
  tens-of-km shallow basins (Lake George, Lake Neusiedl), not Superior-scale.

## B. What the GLWU boundary buys

GLWU is NOAA's own nonstationary whole-lake solution: unstructured WW3, ~2.5 km
offshore refining to ~250 m at the coast, hourly output (GMD 2024; BAMS 2023
journals.ametsoc.org/view/journals/bams/104/4/BAMS-D-22-0094.1.xml). The Phase-B
boundary path already consumes it for lakes (NOMADS `filter_glwu.pl`, gridded partition
fields, per-boundary-cell 2-D reconstruction — PROVIDER-MANUAL §14.3a/b).

The architecture already assigns the far field to GLWU: `docs/ARCHITECTURE.md:116`
"SWAN grows wind sea over the real domain fetch (ocean) and via the GLWU boundary +
SWAN growth (Great Lakes)." Yet `:108` and `swan_domain.py:1265-1266`
(`offshore_km = fetch_value_km + 10.0`) size L1 from lake fetch up to the 200 km
horizon — a whole-lake-scale box. **The two statements are in tension**: if GLWU
carries the lake-crossing field into the boundary, the fetch-sized box duplicates
(in stationary mode, badly — per A) work GLWU already did nonstationary.

Failure modes:
- Small L1 + GLWU boundary: total dependence on GLWU (already exists — required
  boundary input, C-77 abort on failure); parametric reconstruction error enters
  closer to the site; local growth inside a small box adds little fetch, so timing
  leans on GLWU — the nonstationary (better) answer; GLWU's 250 m nearshore mesh is
  finer than our 1 km L1, so boundary quality near shore is not obviously degraded.
- Whole-lake L1 (current design): violates the stationarity limit worse than the
  rejected 131 km ocean box; duplicates GLWU with inferior snapshot physics;
  compute/memory infeasible (D).

## C. The five lakes vs "fetch + 10"

Max length/breadth (EPA/NOAA physical features): Superior 563×257 km; Michigan
494×190 km; Huron 332×245 km; Erie 388×92 km; Ontario 311×85 km. The fetch fan
saturates at `_GREAT_LAKES_HORIZON_KM = 200` (`geography.py:114`) → offshore extent
caps at 210 km.

| Lake | Real along-axis fetch | fetch+10 extent | >100 km? | >200 km? |
|---|---|---|---|---|
| Superior | ~560 (capped 200) | 210 | yes | yes (at cap) |
| Michigan | ~490 (capped 200) | 210 | yes | yes (at cap) |
| Huron | ~330 (capped 200) | 210 | yes | yes (at cap) |
| Erie | ~388 along / ~92 across | 210 along; ~100 across | yes (along) | along only |
| Ontario | ~311 along / ~85 across | 210 along; ~95 across | yes (along) | along only |

Every lake exceeds a 100 km box for an along-axis-facing spot; the three upper lakes
hit the 210 km box from almost any exposed shore. Only cross-axis Erie/Ontario
placements come in near/under 100 km. (The box's other axis follows the fan's angular
span — the HB precedent produced 131 km N-S from span alone.)

## D. Compute cost (linear scaling from measured ocean L1: 9,393 cells → ~16 min /
335 MB; linear is a stated assumption and a FLOOR — SWAN iteration counts typically
grow with domain)

| Box @1 km | Cells | L1 runtime | Memory |
|---|---|---|---|
| 93×101 (current ocean, measured) | 9,393 | ~16 min | 335 MB |
| 210×210 (upper-lake fetch+10) | 44,100 | ~75 min | ~1.5 GB |
| Whole Superior 560×257 | 143,920 | ~4.1 h | ~5.0 GB |
| Whole Michigan 494×190 | 93,860 | ~2.7 h | ~3.3 GB |
| Whole Erie 388×92 | 35,696 | ~61 min | ~1.2 GB |
| Whole Ontario 311×85 | 26,435 | ~45 min | ~0.9 GB |

Budget break points: 45-min cycle with ~22 min non-L1 → L1 headroom ~23 min ≈ 13,500
cells ≈ ~116×116 km. Memory 400 MB → ~11,200 cells ≈ ~106×106 km. Host free RAM
(~1.7 GB) → ~47,600 cells. Every fetch-sized upper-lake box fails all three.

## E. Comparable operational systems

- NOAA NWPS: coastal-WFO SWAN on regional nearshore domains, boundaries from the
  basin-scale model; on the Great Lakes the boundary source is GLWU
  (polar.ncep.noaa.gov/waves; BAMS 2023). NOAA's pattern = "small nearshore SWAN fed
  by the whole-lake nonstationary model."
- GLWU itself abandoned nested multi-grid downscaling for one unstructured
  nonstationary mesh 2.5 km→250 m (GMD 2024) — NOAA's nearshore lake answer at 250 m
  already exists and is what our boundary consumes.
- Lake Michigan whole-lake SWAN ~1 km exists as nonstationary HPC hindcast research
  (Frontiers 2021), not hourly stationary snapshots on an operational budget.
- No operational system running whole-lake stationary SWAN was found.

## Could not establish
- Exact per-spot fetch values (no Great Lakes site configured; figures are
  lake-geometry bounds).
- GLWU gridded-partition quality specifically in the 0–2 km nearshore strip (250 m
  mesh implies good resolution; no published nearshore-strip verification of the
  partition product found).
- Superlinear SWAN scaling coefficients (D is linear = lower bound).

Key file references: `docs/reference/swan-user-manual.txt:5715`;
`docs/ARCHITECTURE.md:108,116,119`; `docs/manuals/PROVIDER-MANUAL.md:1361,1387,
1420-1455`; `services/geography.py:114,133,194-208`; `services/swan_domain.py:
1261-1272,1417-1425`; plan `:1270-1297` (G9-GL), `:1304-1311` (Q6 closure).
