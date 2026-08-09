# L1 Boundary Relocation & Island Sheltering — Research Brief

**Created:** 2026-08-08
**Origin:** Operator finding (2026-08-08 chat): the WW3→SWAN transition is wrong at Huntington
Beach — the L1 offshore boundary, anchored to the GSFM continental-shelf edge, sits inside the
San Pedro Channel, *inshore* of Catalina Island. SWAN therefore never models the island
sheltering; it inherits WW3's rendering of it, which is inaccurate because WW3's 0.16° grid
cannot resolve the intricate bathymetry around the Channel Islands or the spacing between them.
Verified this session (code + live-deployment records + SWAN manual + literature). **This brief
is findings + options for ruling. No code has been changed. Every remedy below trips
architectural triggers 3 (model boundary/extent), 4 (data contract), and/or 7 (config keys) —
nothing proceeds without an explicit operator ruling per CLAUDE.md.**

---

## 1. The verified defect, in one paragraph

L1's offshore extent is `GSFM shelf distance + 10 km` (`services/swan_domain.py:1123-1132`).
GSFM returns **~9.7–10.3 km** at HB Pier (live re-run 2026-08-08; also
`docs/planning/briefs/SWAN-NESTING-RESEARCH-BRIEF.md:6`), so the boundary sits **~20 km out**
— mid-channel. Catalina (33.31–33.48 N, 118.30–118.60 W, ~49–59 km from the pier) lies entirely
outside the domain. The architecture already mandates the right behaviour — *"Islands are
MODELLED, not flagged… size L1 to enclose it and the deep water beyond… Mandatory for US (SoCal
Channel Islands)"* (`docs/planning/briefs/STUDY-AREA-GEOMETRY-BRIEF.md:367-370`, ADR-100) — but
the fetch-fan horizon that would detect the island is *itself* `shelf + 10 km`
(`services/geography.py:21-23,114-115,170-190`). Horizon ≈ 20 km < 49 km to Catalina, so every
ray toward the island terminates in open water, classifies `directly_open`, and the ADR-100
enclosure mechanism never fires. **The shelf-edge criterion is circularly self-blinding on any
borderland coast.** The SoCal mainland shelf genuinely is that narrow (~5 km average; 200-m
isobath as little as ~10 km out — SCCWRP, USGS PP1687), so this is not a mis-drawn GSFM line;
it is the wrong *criterion*: the premise "shelf edge = where WW3 stops being valid" fails where
WW3's real failure is island sheltering, seaward of the geomorphic shelf. Literature: offshore
**direction** errors dominate SoCal nearshore prediction error, and WW3-derived boundaries
underperform (Crosby et al. 2016); island sheltering must be modelled regionally with real
bathymetry (Rogers et al. 2007; CDIP does exactly this, buoy-initialized, islands internal).

## 2. As-deployed facts (all live-verified, citations per line)

| Fact | Value | Source |
|---|---|---|
| L1 box | lat 33.465–33.706, lon −118.179→−117.777 (≈37×27 km), 38×28 cells @ 1 km = 1,064 | `Y0-FACT-PIN-2026-08-05.md:127,165`; `MARINE-MODEL-RESTORATION-PLAN.md:2196,2246` |
| GSFM shelf distance | HB Pier 9.65 km; L1 centre 2.46 km (live re-run of shipped `data/gsfm_shelf_boundary.json`) | this session; `SWAN-NESTING-RESEARCH-BRIEF.md:6` ("verified at 10.3 km") |
| Boundary stations | 4: **46256, 46222, 46253 (W side), 46223 (S side, alone)** — all in-channel | `Y0-FACT-PIN-2026-08-05.md:42-44,144-145`; `SW-1A-SWELL-CHAIN-2026-08-06.md:70-73` |
| Selection rule | ≤ 1 native WW3 cell (18.5 km) from assigned side + depth/kd; **no spacing rule exists** — spacing is emergent from NOAA's station list | `ww3_station_selection.py:361-375`; ARCHITECTURE.md:122 |
| Boundary emission | `BOUNDSPEC SIDE … VARIABLE FILE`, one real 2-D `.spec` per station; SWAN interpolates spectra between the given points | `swan_formats.py` (`ww3_boundary_files_and_command`); SWAN manual §4 BOUNDSPEC → §2.6.3 (`docs/reference/swan-user-manual.txt:2480-2485`) |
| Spectral grid | `CIRCLE 72 0.03 1.0 34` — **5° directional bins**, 34 freqs | `swan_formats.py:1663-1664` |
| Full-cycle wall clock | 31m57s (2026-08-08, disk work tree) | `SESSION-HANDOFF-2026-08-08-SURF-REMEDIATION.md:19-20` |

Consequences as deployed: the up-swell **S side (37 km) is fed by one station → effectively a
constant spectrum along it**; the W side samples at ~9–14 km; and all four stations sit inside
the island shadow zone, so the boundary carries WW3's coarse version of the sheltering — the
exact error source the operator has observed against the ground and the literature predicts.

## 3. Q1 — Autosizing the island sheltering: can our ray tracing do it?

**Yes — the existing fetch fan is mechanically capable; it is blinded by the horizon and
over-eager in its enclosure arithmetic. Two specific changes would make it island-aware:**

1. **Decouple the ocean horizon from shelf distance** (`geography.py:170-190`). The fan already
   marches *through* land and tests for ≥5 km continuous open water beyond
   (`geography.py:267-345`) — precisely an island detector. With a horizon of, say, 100 km,
   rays toward Catalina hit its OSM coastline (islands are `natural=coastline` ways; the
   Overpass query bbox already scales with the horizon, `_bbox_from_horizon`,
   `geography.py:570-581`) and classify `wrap_candidate`. Config-time cost only — the fan never
   runs per-cycle (`geography.py:4-6`).
2. **Enclose to the island's far edge, not the full horizon.** Today each wrap-candidate ray
   adds an enclosure point at the FULL `horizon_km` (`swan_domain.py:1168-1187`) — harmless
   when the horizon was ~20 km, but with a 100 km horizon it would balloon L1 to 100 km in
   every wrap direction. The ray march already computes where the qualifying open-water run
   begins (the ≥5 km run completion in `_classify_ray`) but discards it — `RayResult`
   (`geography.py:135-150`) records only `first_land_distance_km`. Extending `RayResult` with
   an `open_water_resume_km` field and setting the enclosure point at `resume + margin`
   implements ADR-100's own words ("the island and the deep water beyond") at minimum size.

**Operator override:** a config key (e.g. `[swan] l1_offshore_extent_km`) that replaces the
autosized offshore extent. Trigger 7 (new config key). Cheap, deterministic, deployment-local.

**Recommendation (for ruling, not action): BOTH.** Autosize via the island-aware fan as the
default — it generalizes (Hawaii inter-island wrap is already named mandatory in ADR-100) — with
the override as the escape hatch for cases the fan mis-reads, plus a **hard extent cap** (§4)
that *refuses loudly* (names the island left un-enclosed) rather than silently clipping.

**Which islands matter at HB, and what stays broken:** Catalina shadows the W–NW window
(`SURF-FIXIT-LIST.md:149`, `MARINE-SEP-CONCERNS.md:3441-3443`). Enclosing it needs ~60–70 km
offshore reach — inside a 100 km cap. **San Clemente Island (~88 km, shadows far-S/SSW
groundswell) needs ~100–110 km — at/over the cap.** A Catalina-only enclosure fixes the dominant
window and moves the boundary into open water, but the S-window shadow stays WW3-inherited
(San Clemente ≈ 2 cells long at 0.16°). That residual must be recorded, not claimed fixed.

## 4. Compute cost of changing L1

Cost model: the code's own estimator, `cells × 0.05 s` at 6 cores
(`swan_domain.py:111-113`); memory anchor: L2 = 5,530 cells measured **87 MB RSS** at
`omp_num_threads=6` (`reference/clearskies-dev.md`, librewxr budget section — 1.7 GB headroom).

| Scenario | Box (approx) | Cells @ 1 km | Est. L1 runtime | Δ vs today | RSS est. |
|---|---|---|---|---|---|
| S0 — today | 37 × 27 km | 1,064 | ~53 s | — | small |
| S1 — enclose Catalina + 10 km beyond | ~90 × 57 km (lon →−118.75, lat →33.20) | ~5,100 | ~4.3 min | **+~3.5 min/cycle** | ~90 MB |
| S2 — + San Clemente (S window) | ~99 × 107 km | ~10,600 | ~8.8 min | +~8 min/cycle | ~180 MB |

Secondary scaling (all minor at S1): ETOPO `getSamples` batches 1,000 pts → ~6 batches;
hotstart file size ∝ cells × 72 dirs × 34 freqs; more/different `.spec` fetches (7.75 MB each,
`PROVIDER-MANUAL.md:1351`).

**Practical limits, confirming the operator's instinct toward a hard ~100 km cap:**

- **Flat-earth grid arithmetic**: `_compute_swan_grid_dims()` is documented "appropriate for
  coastal domains of ≤100 km extent" (`swan_formats.py:252-253`). S2's 107 km N–S breaches it.
- **UTM frame**: locked zone 11 spans 120°W–114°W — Catalina/San Clemente fine; only the far NW
  Channel Islands (~120.4°W) would cross a zone boundary. Not a constraint for HB.
- **Wind fetch bbox**: spot ±1.0° ≈ ±93 km E–W here (`marine_config.py:1036`) — S1 already
  grazes it, and it must be re-derived from the L1 domain regardless (§6).
- **Resolution floor**: L1 must NOT be coarsened to buy extent. SWAN's coastal recommendation
  is 50–1000 m (manual §2.6.3, `swan-user-manual.txt:822-828`); Bight studies report **>2×
  nearshore energy errors at 1–2 km in island-sheltered zones** (ray-tracing comparison,
  eScholarship; Rogers et al. 2007); CDIP runs the Bight at ~1 km + 100 m nearshore. 1 km is
  the ceiling, already marginal in shadow zones.
- **Steep insular bathymetry inside L1** triggers the manual's refraction-focusing warning
  (§2.6.3, Dietrich et al. 2013) at 1 km — expect to inspect for focusing artifacts at accept.
- **Directional resolution**: shadow edges are directional features. At `CIRCLE 72` (5°), a
  shadow edge smears ~4.4 km at 50 km range; the manual suggests ≤2° for narrow swell
  (§2.6.3, `swan-user-manual.txt:807-813`). Runtime scales ~linearly with bins (72→180 ≈
  2.5×). A knob to consider *after* the boundary move is proven, not with it.
- **Lateral widening** (operator's point 3): confirmed by the manual — unfed lateral boundaries
  propagate error cones ~30–45° inward from the corners (§2.6.3 + Fig 2.1,
  `swan-user-manual.txt:648-692`); pushing the offshore edge out requires proportionally wider
  flanks to keep the cones off the surf spots. The S1 box above includes this allowance.

## 5. Q2 — Feeding the relocated boundary: stations vs. reconstructed grid spectra

**Decisive interaction found this session: the two decisions are COUPLED.** A Catalina-enclosing
boundary likely selects **zero** qualifying stations under the current rule: the in-channel four
become interior points, and the nearest outer catalogue stations miss the 18.5-km distance rule
(e.g., W edge at −118.75: 46262 is ~23 km outside; 46025 ~30 km; S side at ~33.20: nothing
within reach — nearest S candidates are 46086 at ~78 km, 46219 far west). Result:
`BoundaryNotViableError` every cycle (`ww3_station_selection.py:559-583`) — the relocation
cannot ship on the current data contract unless the boundary is deliberately drawn through
station positions (e.g., W edge pushed to ~−119.05 to pick up 46025/46262 — which further grows
L1 and still leaves the S side empty). **Ruling on the boundary location therefore forces a
ruling on the boundary data source.**

**What NOAA publishes (verified):**

- Full 2-D spectra: **only** at fixed point-output stations
  (`…/wave/station/bulls.tCCz/gfswave.<ID>.spec`, `PROVIDER-MANUAL.md:1347-1351`). Arbitrary
  spacing along our boundary is impossible from this product.
- On the 0.16° grid, at **every cell**: per-partition bulk parameters — wind sea
  (WVHGT/WVPER/WVDIR) + **three swell trains** (SWELL/SWPER/SWDIR ×3) + combined
  (HTSGW/PERPW/DIRPW) ([gfswave 0p16 GRIB2 inventory](https://www.nco.ncep.noaa.gov/pmb/products/wave/gfswave.t12z.global.0p16.f003.grib2.shtml)).
  **Not published per partition: directional spread, spectral width/γ, anything beyond 3 swells.**
- **Great Lakes: same contract, already documented in-repo (2026-08-08 correction — this fact
  was live-verified in our own docs; it did not need a web search):** GLWU's gridded
  `glwu.grlc_2p5km` carries **full `SWELL/SWPER/SWDIR 1,2,3`** at ~2.5 km
  (`docs/planning/briefs/WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md:157`). So D3's reconstruction
  works for both products.
- **The partition fetch machinery already exists in production**: `providers/marine/wavewatch.py`
  (§14.3) fetches the gridded GRIB2 with "all 3 swell-partition levels" per point via the
  NOMADS grib-filter with bbox subsetting (`PROVIDER-MANUAL.md:1325`) — the reconstruction
  module extends a live-verified fetch path, it does not create a new one.

**Reconstruction (operator's question: "do we lose too much?")** — build, at each chosen
boundary point, one 2-D spectrum = Σ over partitions of a parametric train (JONSWAP/Gaussian in
frequency × cos^2s in direction), written as SWAN Appendix-D 2-D spectrum files → the existing
`BOUNDSPEC … VARIABLE FILE` path unchanged. This is established practice for nested wave
modeling (e.g. [Nature Sci. Data 2026 — wave spectrum reconstruction parameters for nested
modeling](https://www.nature.com/articles/s41597-026-07017-5); parametric-form reconstruction
reviewed in [Ifremer/Archimer partitioning literature](https://archimer.ifremer.fr/doc/00134/24563/22688.pdf)).
What is genuinely lost, honestly stated:

| Lost | Severity seaward of the islands | Why |
|---|---|---|
| Per-partition directional spread (must assume, e.g. swell σθ ≈ 10–20°) | **Moderate** — the one that matters | Spread sets shadow-edge softness; but SWAN now does the sheltering *internally* with real bathymetry, so the boundary spread is second-order vs. today (where WW3's sheltering IS the boundary) |
| Spectral shape/width per partition (assume JONSWAP γ or Gaussian) | Low | Refraction/shoaling are direction/period-driven; shape refines, doesn't steer |
| Partitions beyond 3 swells | Low | WW3 itself merged them; rare in practice |
| SWPER is a *mean* period, not peak | Low–moderate | Needs a documented Tp conversion assumption per train |

**Corroborating industry observation (operator, 2026-08-08 chat):** surf-forecast.com only
ever reports 4 swell components (3 + wind sea) and Surfline reports 3 — matching the published
gridded structure (WVHGT/WVPER/WVDIR + SWELL/SWPER/SWDIR ×3) exactly. The likely inference:
commercial surf forecasting is built on the partitioned grid fields, not full point spectra —
i.e. the reconstruction path's input is the same data the industry's forecasts already run on.
(Inference, not verified against Surfline's internal LOTUS design docs.)

Crucially, the quantity the Bight literature identifies as dominant — **per-partition
direction** — is published at every cell. And this path genuinely satisfies the standing
2026-07-26 mandate ("YOU ARE MANDATED TO USE THE WWIII GRID") more literally than the station
workaround did. It does brush the standing `VARIABLE PAR` rejection — but that rejection's core
was *one* parametric train collapsing multi-swell seas; per-partition reconstruction summed into
a true 2-D file preserves the multimodality that ruling protected. Needs an explicit ruling that
this distinction holds.

**Hybrid worth considering:** reconstructed points at regular spacing along the boundary,
*anchored* by real `.spec` stations wherever one qualifies (real spectra beat reconstructed ones
where available; reconstruction fills the geometric gaps).
**(SUPERSEDED — operator ruling D3, 2026-08-08, §8: partition reconstruction ONLY, no hybrid —
"keep it simple and follow what our competition does." Do not implement the hybrid.)**

**On "2–5 km recommended spacing" (operator's point 2):** no primary source found — not in the
SWAN manual, NCEP/NWPS practice, or the papers searched. The defensible rule from sources:
boundary-point spacing **no coarser than the outer model's native cell** (~18.5 km for 0p16;
[COMET nearshore wave modeling](http://stream1.cmatc.cn/pub/comet/MarineMeteorologyOceans/NearshoreWaveModeling/comet/oceans/nearshore_wave_models/print.htm))
and fine enough for along-boundary gradients — which are small in open water seaward of the
islands (the operator's own point 2 concession) and sharp only across shadow edges, which the
relocation removes from the boundary. **If the operator has a source for 2–5 km, it should be
filed here before any spacing constant is chosen.** Practical default if reconstruction is
ruled in: one point per WW3 cell along the boundary (~18.5 km), densified only if live accept
shows along-boundary structure. For internal L1→L2 nesting the project's own reference already
holds: ~5–10 boundary points per child side (`docs/reference/swan-nesting-reference.md:45`).

## 6. Q4 — Silent fallback inventory (operator directive: these are dangerous; stop)

Found this session, all producing plausible-looking output from fabricated input, all violating
the C-77 spirit ("a model runs on all its inputs or it does not run"):

| # | Silent fallback | Where | Proposed disposition (for ruling) |
|---|---|---|---|
| 1 | **Wind cells outside the fetched bbox written as calm 0 m/s** — no warning, no assertion anywhere | `swan_formats.py:386-388` (NaN→`0.0000`) | Raise. A wind grid that does not cover the CGRID aborts the cycle, like bathymetry already does (`swan.py:762-780,913-921`) |
| 2 | **Wind fetch bbox is spot ±1.0°, not derived from the L1 domain** — the root enabler of #1 | `marine_config.py:1036`, `service.py:335-341`, `wind_gatherer.py:468-480` | Derive from L1 bbox + margin; assert coverage at fetch time |
| 3 | **Current timesteps with no OFS match within 2 h → zero-current blocks**; rows/cols the OFS grid doesn't span → `0.0000` padding | `swan_runner.py:2431-2458` | Raise or single loud WARNING per cycle naming the count — ruling needed (zero current is physically mild, but the pattern is the disease) |
| 4 | **No coverage check that the OFS domain contains the SWAN grid** (explicitly noted unresolved in code) | `swan.py:3100-3108` | Add the check. WCOFS coded domain 24–54 N / −134→−115 (`providers/ocean/ofs.py:59`) comfortably covers an extended SoCal L1, so it will pass here — the point is it must be *checked*, not assumed |
| 5 | **Water level: one CO-OPS station's predicted tide stamped uniformly**, justified in-code by "~30 km domain, gradient negligible" | `swan.py:3021-3050`, `swan_runner.py:2296-2301` | Keep mechanism (SoCal tide differences over 100 km are a few cm / minutes — acceptable), but the in-code justification must be rewritten for the actual domain size, and ideally checked once at config time against a second station |

No coverage assertion exists for wind/wlevel/current because their INPGRIDs are declared at the
CGRID's own geometry (`swan_formats.py:1708-1738`) — SWAN structurally cannot detect these gaps
itself; only our code can, upstream. `PROVIDER-MANUAL.md:1893` already concedes the wind blend's
continuity is "asserted by construction, not verified."

## 7. Decisions requested (RULED 2026-08-08 — see §8 for the rulings; this section kept as the
## question record)

1. **Boundary criterion** (trigger 3): adopt island-aware autosizing (fan horizon decoupled from
   shelf + far-edge enclosure) — with or without the operator-override config key (trigger 7)?
   Recommendation: both, plus hard cap.
2. **Hard extent cap** (trigger 3/1): fix `l1_max_extent_km = 100` (flat-earth validity, wind
   bbox, compute) with loud refusal naming what was left un-enclosed? Accepts the San Clemente
   S-window residual at HB for now.
3. **Boundary data contract** (trigger 4): station `.spec` only (requires drawing the boundary
   through station positions and still fails the S side), per-partition reconstruction from the
   gridded fields at chosen spacing, or hybrid (reconstructed + station-anchored)?
   Recommendation: hybrid. Requires ruling that per-partition reconstruction does not violate
   the standing `VARIABLE PAR` rejection (its multimodality concern is preserved).
4. **Boundary point spacing**: default one point per WW3 native cell (~18.5 km) absent a
   source for the 2–5 km figure — operator to supply that source if it exists.
5. **Silent fallbacks** (§6 rows 1–5): confirm loud-failure conversions, and the disposition
   for the mild cases (#3, #5).
6. **Sequencing**: the wind bbox/coverage fixes (§6 #1–2) are prerequisites for ANY L1
   extension — an extended grid today would silently run on calm wind at its offshore edge.

## 8. RULINGS — operator, 2026-08-08 chat

**D1 — Island-aware autosizing: RULED YES.** ("Yes island aware autosizing.") With an added
requirement the operator stated explicitly: **when an island is detected at/beyond the edge of
the 100 km cap (San Clemente is the named case — "it is too far to include"), the sizing must
detect it and fall back so the boundary does NOT sample "right behind it"** — i.e. boundary
edges must not sit in the near-lee of an un-enclosed island, where WW3's smeared shadow is at
its worst. Design guidance for the plan (mechanism sketch, exact form to be settled at design
time): a shadow behind an island fills in by directional spreading over a length ≈
`cross-swell island width / (2·tan σθ)` — for San Clemente blocking S/SSW swell
(cross-swell width up to ~30 km, σθ ≈ 15°) that is **~50+ km of poisoned water down-wave**.
**This bites immediately:** the S1 Catalina-enclosure box's southern edge (lat ≈ 33.20) passes
only ~19–30 km down-wave of San Clemente's north end for S-window bearings (segment near lon
−118.4 … −118.6) — inside the near-lee. The autosizer must therefore check every un-enclosed
island (truly-blocked rays AND wrap-candidates whose far edge + margin exceeds the cap) against
the proposed boundary and pull the affected edge in/aside, loudly reporting what it did and why.
*Override: RULED YES (operator, 2026-08-08 follow-up — "we need the autosize override in
admin"): the offshore-extent override is exposed in the ADMIN UI, not just a config-file key.
Doc-sync consequence when implemented: admin help content keys + Operator Manual per CLAUDE.md.*

**D2 — 100 km hard cap: RULED YES.** ("Yes, the 100km cap needs to stand.") Loud refusal
naming what was left un-enclosed, per §3/§4. San Clemente's S-window shadow stays WW3-inherited
at HB and is recorded as a known residual (mitigated by D1's near-lee avoidance).

**D3 — Boundary data contract: RULED — per-partition reconstruction from the gridded WW3
fields, NOT the hybrid.** ("The partition construction is the best, not a hybrid. Let's keep it
simple and follow what our competition does here.") The station-`.spec` boundary path is
superseded for L1. This ruling supersedes, for this specific summed-per-partition-2-D-file
form, the 2026-07-26 `VARIABLE PAR` rejection — that rejection's multimodality concern is
preserved by construction (each partition is its own train; the emitted file is a true 2-D
spectrum). Corroboration noted in §5: surf-forecast (3 swells + wind) and Surfline (3) match
the gridded partition structure exactly.

**D4 — Boundary point spacing: RULED — match L1's own cell spacing (1 km).** ("Boundary point
spacing should match with our L1 cells, that way SWAN interpolates correctly regardless of WW3
cell size.") Interpretation for the plan: emit one reconstructed 2-D spectrum at every L1
boundary cell; interpolation of the partition parameters between WW3's 0.16° cells happens in
OUR code, in parameter space per partition (directions interpolated as angles), *before*
reconstruction — SWAN is never asked to interpolate between two distant spectra (which smears
bimodal seas). Implementation consideration to size in the plan, stated factually: an S1-scale
boundary has ~150 offshore-edge points × ~72 hourly timesteps of 34×72-bin spectra ≈ roughly
150–300 MB of locally generated boundary text per cycle — generation is cheap, but file I/O and
SWAN read time must be measured at accept; if infeasible, STOP and surface (do not silently
thin the spacing).

**D5 — Setup-time availability reporting + pull-to-the-grids: RULED.** Data-source viability is
decided at setup; **setup must tell the operator when data is not available for the configured
location, and why** — runtime keeps its loud aborts but structural absences must be caught at
setup, not discovered as an eternal abort loop. All input fetches must be derived from the
actual model grids ("we need to make sure that we PULL THE DATA THOUGH, wind needs to be to the
grids") — wind bbox from the L1 domain, coverage asserted for wind/wlevel/currents like
bathymetry already does. **Answer to the operator's East-Coast question recorded here:** the
OFS catalogue (`providers/ocean/ofs.py:40-74`) has NO open-Atlantic-coast model — East Coast
entries are bay/estuary-scale only (GOMOFS Gulf of Maine, CBOFS Chesapeake, DBOFS Delaware,
NYOFS NY Harbor, TBOFS Tampa, SJROFS St. Johns, NGOFS2 northern Gulf). An open-coast Atlantic
deployment (e.g. Outer Banks, Jersey Shore, FL east coast) matches no domain →
`find_ofs_model` returns None → empty fetch → C-77 aborts **every** cycle
(`providers/nearshore/swan.py:3096-3122` — the in-code "known open question"). The standard
gap-filler is RTOFS-Global (what NWPS uses for currents); adding it is a new data source
(trigger 7) requiring its own ruling — surfaced, not decided.
**Operator addendum (2026-08-08 chat): STOFS.** NOAA's STOFS-2D-Global (Surge and Tide
Operational Forecast System, the renamed ESTOFS) is global, runs 4×/day to 180 h, and publishes
**water level AND water velocity** ([AWS open-data registry](https://registry.opendata.aws/noaa-gestofs/),
[product README](https://noaa-gestofs-pds.s3.amazonaws.com/README.html)). Distinction that
matters before adopting it for the currents gap: STOFS-2D is a *barotropic* (2-D, depth-averaged)
surge+tide model — its velocity is the tide+surge current only, with NO wind-driven/geostrophic
ocean circulation (no Gulf Stream — which is exactly the current that matters on the FL east
coast). RTOFS-Global is the full 3-D ocean model with those currents. NWPS's own split is
instructive: **STOFS/ESTOFS for water levels, RTOFS for currents**
([NWPS overview](https://www.emc.ncep.noaa.gov/emc/pages/numerical_forecast_systems/nwps.php)).
STOFS is therefore ALSO the natural candidate for spatially-varying WLEVEL on large domains
(the thing our single-station CO-OPS tide approximates — §6 row 5). Candidate pairing for a
future ruling: STOFS→WLEVEL, RTOFS→CURRENT, each trigger 7, neither decided here. A
STOFS-3D-Atlantic variant (higher-res, Atlantic basin) also exists.

**D6 — Wind coverage fix: RULED YES.** ("That is a DUH that needs fixed.") §6 rows 1–2: wind
bbox derived from the L1 domain + margin, coverage asserted at fetch time, NaN→calm fill
replaced with a hard abort. **Sequencing stands: this lands before or with any L1 extension.**

**D7 — Service area is the ENTIRE UNITED STATES, including the Great Lakes: RULED.** ("This is
a major architectural violation, at NO POINT do we just build out for our TEST CASE! We need to
build out FOR THE ENTIRE SERVICE AREA, which is the united states, including the great lakes.")
Every input chain must either serve every US region or refuse **at setup, with the reason**
(D5) — no region may discover its gap as a runtime abort loop. Coverage matrix as verified
2026-08-08 (✔ = source exists and is wired; GAP = no source in the catalogue; each GAP is a
setup-time refusal until a source ruling lands):

| Input | West CONUS | East CONUS (open coast) | Gulf CONUS (open coast) | Great Lakes | Alaska | Hawaii | PR/USVI |
|---|---|---|---|---|---|---|---|
| Wave boundary (D3 partitions) | ✔ gfswave 0p16 | ✔ gfswave | ✔ gfswave | ✔ **GLWU full partitions** (`WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md:157`) | ✔ gfswave (≤77.5°N) | ✔ gfswave | ✔ gfswave |
| Wind | ✔ HRRR+GFS | ✔ | ✔ | ✔ | **GAP** — HRRR is hardcoded CONUS (`hrrr.py:598`); HRRR-AK exists but is not implemented | **GAP** — no HRRR product exists; needs a GFS-only (or regional) wind mode | **GAP** — same as Hawaii |
| Currents | ✔ WCOFS | **GAP** (bays only: GOMOFS/CBOFS/DBOFS/NYOFS) | **GAP** (NGOFS2/TBOFS/SJROFS bays only) | ✔ LSOFS/LMHOFS/LEOFS/LOOFS (all five lakes) | **GAP** (CIOFS = Cook Inlet only) | **GAP** (nothing) | **GAP** (nothing) |
| Water level | ✔ CO-OPS | ✔ | ✔ | ✔ (LWD/IGLD85 datum branch exists) | ✔ (station density thin) | ✔ | ✔ |
| Bathymetry L1 | ✔ ETOPO global | ✔ | ✔ | ✔ USGS lakes DEMs | ✔ | ✔ | ✔ |
| Bathymetry L2/L3 fine | ✔ NCEI DEMs (index: 199 entries; availability varies — chain already refuses loudly) | ✔/varies | ✔/varies | ✔ | varies | varies | **USVI has a DEM in our index (`usvi_1_mhw_2014.nc`); Puerto Rico, Guam, and American Samoa have NONE** — NCEI publishes PR DEMs, so this is an index-file gap, not a NOAA gap; refresh the index in the plan |
| Datum conversion | ✔ VDatum | ✔ | ✔ | ✔ | **partial** (VDatum AK incomplete) | **GAP** — VDatum does not cover Hawaii (listed "future development" with AK and the Pacific territories) | PR/USVI ✔; **Guam/AS GAP** ([VDatum current events](https://vdatum.noaa.gov/about/currentevents.html)) — severity depends on which DEM serves L2/L3 there (ETOPO is already MSL-referenced); sweep item for the plan |
| Geometry/sizing | ✔ | ✔ | ✔ | ✔ lake-fetch sizing (G2.4) | ✔ | **D1 rework required** — no continental shelf exists; the shelf-anchored horizon is meaningless here, a second independent reason the horizon must be decoupled from shelf distance (ADR-100 already names Hawaii inter-island wrap mandatory) | ✔ |
| C-77 behaviour at a GAP today | — | **eternal abort loop** (`swan.py:3096-3122`) | eternal abort loop | — | eternal abort loop (wind) | eternal abort loop (wind+currents) | eternal abort loop |

Candidate sources for the GAP cells: see D8 (wind — RULED) and the currents subsection below
(RTOFS — explained, awaiting ruling); water level spatial variation → STOFS-2D-Global (see D5
addendum, candidate, not ruled).

**D8 — Region-aware wind sourcing: RULED** (operator, 2026-08-08 follow-up: "HRRR AK for
alaska, GFS where we do not have HRRR"). Wind source is selected per region at setup: HRRR
CONUS product for CONUS; **HRRR-AK** for Alaska; **GFS alone** wherever no HRRR product exists
(Hawaii, PR/USVI, other territories). Implementation notes for the plan: the HRRR provider
hardcodes `dir=/hrrr.{date}/conus` (`providers/wind/hrrr.py:598`) — the AK product lives under
`/alaska` with its own cycle cadence; the 0–48 h HRRR + 48–72 h GFS blend
(`swan_runner.py:2690-2807`) needs a GFS-only mode for the no-HRRR regions (0–72 h GFS,
3-hourly→hourly interpolation already exists for the 48–72 h leg). C-77 stays intact: in a
GFS-only region, GFS is the required wind input; nothing is silently dropped.

**Currents — what RTOFS is (operator asked, 2026-08-08), answered from our own manuals first:**
RTOFS (Real-Time Ocean Forecast System) is NOAA's operational **global** ocean model (HYCOM
family): ~8 km resolution, 3-D (41 depth levels), daily cycles, 8-day forecasts, publishing
temperature, salinity, and **currents** — and **it is already one of our providers**:
`providers/ocean/erddap_ocean.py` serves `rtofs_3d` = "Temp column + currents + salinity (8km,
global, 41 levels, 8-day forecast)" (`PROVIDER-MANUAL.md:1713`), used today as the deep
fallback in the water-temperature chain (sensor → OFS → regional ERDDAP → RTOFS/MUR,
`ARCHITECTURE.md:712`, §14.12). Why it is the currents gap-filler candidate: it is the only
NOAA operational source with real ocean-circulation currents (wind-driven + Gulf Stream +
eddies) **everywhere in the service area**, and NWPS drives its own SWAN wave–current
interaction with RTOFS-Global surface currents. Trade-offs, stated plainly: 8 km is coarse
nearshore and resolves no bays — so the natural selection rule is **"OFS model where one
covers the domain, RTOFS everywhere else"** (mirroring the display-side resolver's existing
tier order); and RTOFS-Global is **non-tidal** (no tidal currents — the complement of STOFS,
which is tide/surge-only; verify against NOAA's RTOFS docs at plan time before relying on
this). Adopting RTOFS as a SWAN current-forcing source = trigger 7 (new role for an existing
provider + a new gridded-U/V fetch path distinct from today's point/column ERDDAP queries) —
**awaiting operator ruling now that the explanation is on record.**

**D9 — Currents: RULED — RTOFS adopted, OFS-first** (operator, 2026-08-08 follow-up: "Yes
RTOFS with OFS first"). SWAN current forcing source selection at setup: an OFS model whose
domain covers the L1 grid wins; RTOFS-Global everywhere else. Fills every currents GAP cell in
the D7 matrix. Non-tidal caveat from the D5 addendum carries into the plan as a verify item.

**D10 — Water level: RULED — STOFS adopted** (operator: "Yes on STOFS"). STOFS-2D-Global
becomes the spatially-varying WLEVEL source, replacing the single-CO-OPS-station uniform stamp
(§6 row 5) — global coverage, so it also serves every region in the D7 matrix. Plan must
settle: datum reconciliation (STOFS water levels vs. the DEM datum the bathymetry chain
locks), and whether CO-OPS predictions remain as cross-check or fallback (setup-time loud
refusal rules apply either way, D5).

**D11 — Near-lee fallback criterion (design pass done; two constants await operator
ratification).** Operator direction: "as physically correct as possible but knowing there are
limits in terms of what we can and cannot do." The physics: a swell field of directional
spread σθ passing an island of cross-swell width W leaves a shadow whose un-refilled core
closes where the spreading cones from the island's two edges meet, at
**L_fill ≈ W / (2·tan σθ)** down-wave; the height deficit then decays, healing substantially
by ~2·L_fill (sheltering geometry as used in the Bight island-shadow literature, O'Reilly-type
analyses). Proposed rule, mirroring that direction exactly:

- For every blocking island NOT enclosed (truly-blocked rays, or wrap-candidates whose
  enclosure would exceed the D2 cap): compute per affected bearing sector W (island width
  projected normal to the swell bearing) and L_fill.
- Where the rectangle can place its boundary ≥ **k·L_fill** down-wave of the island along
  those bearings without violating the cap or another island's enclosure, it MUST.
- Where it cannot (constraint conflict), it takes the **maximum achievable** down-wave
  distance and that IS the behavior — **RULED, operator 2026-08-08: "there is no FLAGGING,
  flagging does nothing. WE DO THE BEST WE DO AND THAT IS IT."** No admin-report ceremony, no
  residual-surfacing apparatus; the sizing trace keeps its ordinary engineering record
  (bearings, achieved km) for debugging, nothing more. This does NOT touch D5's setup-time
  refusal-with-reason for genuinely missing data sources — that is a different case (cannot
  run at all) and stays as ruled. The distinction, recorded so no future agent conflates
  them: **missing data → refuse and say why (D5); constrained geometry → best physical
  answer, silently (D11).**
- Constants **RATIFIED with the same ruling: σθ_ref = 15°, k = 1** (10° would roughly double
  L_fill; k=2 would make most island-fringed coasts unsatisfiable).

Worked HB case: San Clemente Island, S swell ~190°: W ≈ 26 km → L_fill ≈ 49 km (σθ=15°) or
~74 km (σθ=10°). The Catalina-enclosure box's S edge sits ~24 km down-wave of SCI's north end
— about half of L_fill(15°), and no compliant position exists (moving the S edge to the healed
zone would forbid enclosing Catalina). So at HB the rule resolves to: maximum-achievable +
loud residual + **empirical validation at accept** — buoys 46253/46222 sit in exactly that
water and can score WW3's partially-healed shadow against observations on an S-swell event.
**Constants ratified 2026-08-08 (see rule bullets above) — D11 is CLOSED.**

**D12 — Service area amended: CONUS + Great Lakes + HAWAII; Alaska and the territories
DESCOPED** (operator, 2026-08-08 follow-up: "we HAVE to cover Hawaii, that is a surf haven. I
can see dropping territories, and dropping alaska… but cannot drop hawaii"). Amends D7. The
descope is reversible — the D7 matrix keeps the AK/PR-USVI/Guam-AS columns as a record, and
any future re-entry re-opens exactly those GAP cells. What the descope dissolves now: D8's
HRRR-AK clause (dormant, not deleted), the CIOFS/open-AK currents gap, VDatum's AK-partial and
Guam/AS gaps, and the PR DEM index gap (kept as a low-priority note). What it leaves as the
one hard problem: **Hawaii datums (D13)** — Hawaii wind (GFS-only) is D8, Hawaii currents are
D9 (RTOFS), Hawaii wave boundary is gfswave, Hawaii geometry already requires D1's
horizon-decoupling (no continental shelf exists there).

**D13 — Hawaii datum strategy (design answer to "we need to figure out what to do about
datums"; approach awaits operator sign-off).** The gap looks worse than it is. VDatum's job in
our chain is converting *geodetic*-referenced sources (NAVD88) to tidal LMSL. **Hawaii has no
NAVD88 at all** — the datum simply does not extend there — and every relevant Hawaii source is
already tidally referenced: ETOPO (L1) is MSL-referenced, and all three Hawaii DEMs in our own
index are MHW-referenced (`hilo_13_mhw_2011.nc`, `kauai_13_mhw_2012.nc`, `oahu_13_mhw_2011.nc`
— `data/ncei_regional_dem_index.json:821,898,1316`). The only conversion Hawaii ever needs is
**MHW→LMSL, which is plain tidal-datum arithmetic available per station from the CO-OPS
`datums` product — the same keyless CO-OPS API the tide chain already uses.** Proposed
mechanism: a tidal-datum-offset conversion path for regions VDatum does not cover — offset
taken from the nearest CO-OPS station's published datums (or interpolated between an island's
stations), applied across the L2/L3 domain; **loud refusal if a geodetic-referenced source
(NAVD88 etc.) ever appears in a no-VDatum region** (cannot be converted there — refuse, never
approximate). Architectural precedent already in the code: the Great Lakes LWD/IGLD85 datum
branch — region-dependent datum strategy is an existing pattern, not a new invention. Error
bound: the MHW−MSL offset varies slowly; a nearest-station constant across a ~10–30 km L2/L3
domain contributes centimeter-scale error, versus the ~1 m bias class the datum machinery
exists to prevent. Plan-time verify items: offset spread across each island's stations
(quantifies the constant-offset error), Maui/Big Island DEM index refresh, and D10's STOFS
datum reconciliation (global item, not Hawaii-specific).
**RULED 2026-08-08 under the operator's closing directive ("WE DO THE BEST WE DO AND THAT IS
IT"): the tidal-offset mechanism above IS the best available answer for Hawaii and is adopted.
D13 is CLOSED.**

---

**BRIEF COMPLETE — 2026-08-08.** All rulings D1–D13 recorded; checklist items closed or
assigned to the plan. Per the operator's gate, the implementation plan may now be drafted.

**Brief-completion checklist (operator gate: "No implementation plan until brief is
complete"):**
1. ~~Currents ruling~~ — **RULED D9**.
2. ~~STOFS→WLEVEL~~ — **RULED D10**.
3. ~~Near-lee criterion~~ — **RULED CLOSED (D11)**: best-achievable placement is the
   behavior, constants σθ_ref=15° / k=1 ratified, no flagging apparatus.
4. D4 boundary-file volume: measurement method at accept (SWAN read-time budget) — recorded;
   plan-time item.
5. ~~Territories verification sweep~~ — **DONE 2026-08-08**, then largely mooted by D12's
   descope (AK + territories out; matrix columns retained as the re-entry record). The one
   surviving finding is Hawaii's VDatum gap → resolved by the D13 strategy (awaiting
   sign-off). Hawaii DEM index: Hilo/Kauai/Oahu present (all MHW); **Maui + most of Big
   Island missing — index refresh plan item.**
6. Doc-sync inventory for implementation: ARCHITECTURE.md §SWAN inputs/L1, PROVIDER-MANUAL
   §14.3a/14.15 + §14.12 (RTOFS new role) + STOFS section (new), OPERATIONS-MANUAL (admin
   override), admin help keys + Operator Manual (D1 override), reference/clearskies-dev.md if
   deploy behaviour changes. *Territories: RULED IN (operator, 2026-08-08 follow-up — "the territories should be included
unless we have a compelling reason to not include them"). PR/USVI, Guam, American Samoa are in
scope; any exclusion must be argued to the operator with a specific compelling reason, never
assumed.*

## 9. Sources

**Local (authoritative for SWAN behaviour — per project rule, the manual is in-repo):**
SWAN User Manual v41.51, `docs/reference/swan-user-manual.txt` — §2.6.3 (boundary placement
:628-659; error cones :648-692; resolution recommendation :822-828; refraction warning
:850-854; directional resolution :807-813), BOUNDSPEC :2412-2517. Project files as cited
inline (marine repo at `repos/weewx-clearskies-marine/`, planning docs at `docs/planning/`).

**External:**
- [Crosby, O'Reilly & Guza 2016 — Modeling Long-Period Swell in Southern California, J. Atmos. Oceanic Technol. 33(8)](https://journals.ametsoc.org/view/journals/atot/33/8/jtech-d-16-0038_1.xml) — offshore directional error dominates; WW3-derived boundaries underperform buoy-derived.
- [Rogers et al. 2007 — Forecasting and hindcasting waves with SWAN in the Southern California Bight, Coastal Eng. 54](https://www.sciencedirect.com/science/article/abs/pii/S0378383906000937) — island sheltering essential; resolution sensitivity.
- [Regional swell transformation by backward ray tracing (UCSD eScholarship)](https://escholarship.org/content/qt8tv4w9g3/qt8tv4w9g3.pdf?t=q26zhn) — >2× energy spread at 1–2 km SWAN resolution in sheltered zones; ~90 m converges.
- [CDIP California wave models](https://cdip.ucsd.edu/m/documents/models.html) — operational precedent: boundary in deep water, islands modelled internally, ~1 km Bight grid + 100 m nearshore.
- [SCCWRP — Southern California Bight overview](https://ftp.sccwrp.org/pub/download/DOCUMENTS/JournalArticles/1051_WorldSeas_SouthernCaliforniaBight_Abstract.pdf); [USGS PP1687 — San Pedro shelf](https://pubs.usgs.gov/pp/pp1687/pp1687_book.pdf) — shelf ~5 km avg; 200-m isobath ~10 km out.
- [gfswave.global.0p16 GRIB2 inventory (NCO)](https://www.nco.ncep.noaa.gov/pmb/products/wave/gfswave.t12z.global.0p16.f003.grib2.shtml) — per-partition gridded fields.
- [Wave spectrum reconstruction parameters for nested wave modeling, Nature Scientific Data (2026)](https://www.nature.com/articles/s41597-026-07017-5); [Ifremer — dynamical partitioning of directional spectra](https://archimer.ifremer.fr/doc/00134/24563/22688.pdf) — reconstruction practice and its parametric losses.
- [COMET — Nearshore wave modeling](http://stream1.cmatc.cn/pub/comet/MarineMeteorologyOceans/NearshoreWaveModeling/comet/oceans/nearshore_wave_models/print.htm) — boundary file spacing no coarser than outer-model resolution.
- [NWPS overview (NCEP/EMC)](https://www.emc.ncep.noaa.gov/emc/pages/numerical_forecast_systems/nwps.php) — operational WW3→SWAN nesting reference.
- Harris & Macmillan-Lawler et al. 2014 — Geomorphology of the oceans (GSFM), Marine Geology 352 (the shipped `data/gsfm_shelf_boundary.json` source).
