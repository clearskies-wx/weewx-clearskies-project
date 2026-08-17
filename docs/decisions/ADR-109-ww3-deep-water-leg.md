---
status: Accepted
date: 2026-08-17 (drafted 2026-08-16)
deciders: shane
supersedes:
superseded-by:
---

# ADR-109: WW3 deep-water leg — always-on deep-ocean wave model, handoff to SWAN at L2

## How to read this document

This is the one-time design-governance decision for the WW3 deep-water leg (Marine Model
Evolution Plan, Phase DOC-W, task DOC-W.1). You are reading it cold — every term is
defined at first use, every number cites the Phase F measurement that produced it, and
every place the evidence did not decide something is marked **[OPERATOR ACCEPTANCE
ROW]** rather than silently defaulted. Accepting this ADR is a one-time act — per PRIME
DIRECTIVE 11 of the governing plan, nothing here becomes a product-facing control; an
installing operator still just picks a surf location. This ADR fixes how the code decides
model setup on that operator's behalf.

**Terms used throughout, defined once:**
- **WW3** — WaveWatch III, NOAA's own deep-ocean spectral wave model (the model this ADR
  adds as our own process for the offshore/deep-water leg).
- **SWAN** — Simulating WAves Nearshore, the nearshore wave model already in production
  (L1–L4 levels); unaffected in its own physics by this ADR.
- **Deep-water leg** — the new WW3-modeled offshore domain that replaces WW3-as-someone-
  else's-model (today we consume NOAA's own WW3 output at our L1 boundary) with WW3 as
  OUR process, feeding SWAN starting at L2.
- **L1/L2/L3/L4** — SWAN's four nested compute levels, coarsest (L1) to finest (L4);
  today L1 is the big-domain non-stationary leg (ADR-108). Under this ADR, WW3 replaces
  L1's deep-water job; SWAN's chain begins at L2.
- **Hs** — significant wave height, the standard measure of sea-surface wave energy.
- **Shadow mode** — the WW3 leg runs and stores artifacts but does not serve; the live
  SWAN-L1 path keeps serving until a later operator ruling (Phase V4).
- **Switch file** — WW3's build-time selection of physics packages (compiled in, not a
  runtime config); analogous to choosing which SWAN command set to compile against.
- **Deck** — a model input file (`ww3_grid.inp`, `ww3_shel.inp`, etc.), WW3's counterpart
  to SWAN's `INPUT` file.
- **F0–F5** — the Phase F feasibility tasks (build, configure, benchmark, measure,
  catalog) whose reports this ADR cites throughout. All reports live in `scratch/` at
  the project root.

## Context

The research brief (`docs/reference/SWAN-ENERGY-LOSS-RESEARCH-2026-08-15.md`) proved our
current architecture loses too much wave energy crossing the deep-water gap between
NOAA's own WW3 output and our nearshore SWAN domain — the same island-attenuation defect
class that motivated ADR-108's big-L1 domain. §4 (Option E) and §7 of that brief
established that running our own WW3, then handing off to SWAN at L2, is NOAA's own
production architecture (their Nearshore Wave Prediction System, "NWPS," runs WW3 then
hands off to SWAN at coastal scale — precedent graded STRONG in the brief).

The operator ruled 2026-08-15 (Q1, recorded in full in the plan): our WW3 leg runs
**ALWAYS**, at every install, with no per-site or per-install conditionality — not because
every site needs it, but because a setup-time classifier can only route around failure
classes someone has already found, and this project only found SWAN's island-attenuation
defect through months of buoy-checking that no other install's operator would replicate.
The operator also ordered (PRIME DIRECTIVE 11, "no generic model setup"): every WW3
configuration input must trace to a derivation rule, not a hand-picked default — the F5
catalog (embedded in full below) is that rule set.

Phase F (`scratch/F1-BUILD-REPORT.md` through `scratch/F5-CATALOG.md`, Gate F PASS
2026-08-16) built WW3 from source, configured it for our domain in scratch, ran benchmark
marches against the same archived cycle the SWAN baseline uses, and measured cost,
physics, and handoff fidelity. This ADR freezes what that evidence decided and marks,
explicitly, what it did not.

**Evidence correction (2026-08-17) — read before the D-rows.** The original F4c
"energy-ledger" verdict measurements were INVALIDATED: they measured an internal
boundary-to-seam energy proxy on synthetic boundaries, not agreement with the real
ocean (coordinator failure report, plan §"⛔ COORDINATOR FAILURE REPORT — 2026-08-17").
They are REPLACED by a real buoy validation
(`scratch/F4-BUOY-VALIDATION-REPORT.md`, 2026-08-17): two G1×P1 marches with the
corrected frequency-fastest boundary axis order (the D5 caveat's fix) —
(a) a restart-chained run driven by real NOAA gfswave boundary spectra and wind
matches NDBC buoys 46253/46222 within 5–15% on Hs (model/buoy ratio 0.93–0.94 over
the equilibrated hours), direction within ±10–15°, period within ±3 s, and correctly
captures an arriving SSW swell pulse (1.19–1.20 m at window close, matching the
operator's Aug 16 buoy observations of 1.0–1.2 m); (b) its cold-start companion is
34–38% low at h=24 with Hs still rising — a startup artifact eliminated by
restart-chaining, direct evidence for D10. Every D-row below that leaned on F4b/F4c
amplitude evidence carries a dated correction note; cost and mechanics evidence
(F1–F3, F4.1, F4.3) stands per trap 21's carve-out.

## Acceptance record (2026-08-17)

**Accepted by the operator in chat, 2026-08-17** ("approved"), after the evidence-citation
correction of the same date (buoy validation replacing the invalidated proxy KATs). All
nine open rows accepted AS RECOMMENDED: **D3a** no intermediate grid (NOAA output → G1
direct); **D3b** acknowledged (G2 has no general sizing formula; unused at this install);
**D4** P1 (ST6/FLX4); **D5** `ww3_bound` (ASCII); **D6** BOUNDNEST3 (candidate A);
**D7** `ww3_prep` (ASCII); **D9** wind-only forcings split; **D10** restart-file
chaining; **D11** `WW3_RESTART_MAX_AGE_H = 9`. D12's layout/cadence/budget design is
accepted with the ADR. These values are now FROZEN for Phase W (plan PRIME DIRECTIVE
12: W DESIGN v1 implements them as-frozen).

## Decision at a glance — what evidence decided vs. what you are ruling on

| # | Item | Status |
|---|---|---|
| D1 | Always-WW3 assignment | Ruled already (Q1, 2026-08-15) — recorded here for completeness |
| D2 | WW3 version 6.07.1, manual authority 6.07 | Ruled already (Q5, 2026-08-16) — recorded here |
| D3 | Grid variant COUNT (is an intermediate grid needed?) | **[OPERATOR ACCEPTANCE ROW]** — evidence favors NO, see D3 |
| D3b | G2's exact resolution | **[OPERATOR ACCEPTANCE ROW]** — no general formula exists yet, see D3 |
| D4 | Physics package: P1 (ST6/FLX4) vs P2 (ST4/FLX0) | **[OPERATOR ACCEPTANCE ROW]** — lead recommends P1, see D4 |
| D5 | Boundary-assembly program: `ww3_bound` vs `ww3_bounc` | **[OPERATOR ACCEPTANCE ROW]** — lead recommends `ww3_bound`, see D5 |
| D6 | SWAN-ingestion mechanism: BOUNDNEST3 (A) vs Appendix-D writer (B) | **[OPERATOR ACCEPTANCE ROW]** — lead recommends A, see D6 |
| D7 | Wind preprocessor: `ww3_prep` vs `ww3_prnc` | **[OPERATOR ACCEPTANCE ROW]** — lead recommends `ww3_prep`, see D7 |
| D8 | Spectral grid + deck time steps | Evidence-confirmed exact values, see D8 |
| D9 | Forcings split (wind-only) | **[OPERATOR ACCEPTANCE ROW]** — lead recommends accepting the split, see D9 |
| D10 | Initial-state mechanism: restart-chaining vs cold-start-with-lead | **[OPERATOR ACCEPTANCE ROW]** — lead recommends restart-chaining, numeric staleness gate NOT yet measured, see D10 |
| D11 | WW3 nest-age refuse-gate value | **[OPERATOR-SET]** — lead proposes a value by analogy to `L1_NEST_MAX_AGE_H`, see D11 |
| D12 | File/dir layout, scheduling cadence, shadow-mode key, compute budget | Design fixed here, see D12 |
| D13 | F5 parameterization catalog | Embedded in full below (D13) |
| D14 | Known defects registered | See D14 |
| D15 | ADR-108 scope note | See D15 |

---

## D1 — Always-WW3 assignment (Q1 ruled 2026-08-15)

**Decision:** the WW3 deep-water leg runs as OUR process, for the deep-water domain, at
**every** install — no per-site or per-install conditionality, no mixing within one
install. SWAN's chain begins at L2 everywhere. Until a Phase V4 verdict-1 (cutover)
ruling — which may never be given — the WW3 leg runs in **shadow mode only**: it
computes and stores its own artifacts, but the live SWAN-L1 path keeps serving. This is a
transition state, not a permanent site classification.

**Evidence/authority:** operator ruling in chat, 2026-08-15 ("Yup it is option 2 for
sure now"), full reasoning recorded in the plan's Q1 entry: a setup-time classifier only
routes around failure classes already found; the WW3 decision variable is regional (the
offshore water a whole install's sites share), not per-spot; a misclassified install
fails silently (plausible-but-wrong forecasts) with no mechanism to catch it. Research
brief §4 Option E + §7 (NOAA's own NWPS precedent, graded STRONG).

## D2 — Version and manual authority (Q5 ruled 2026-08-16)

**Decision:** WW3 **6.07.1**, commit `b582f8cbc82aec6f13a66a58c661fba4ae24e4ee` (the
only buildable release tag; 5.16 predates NOAA's move to GitHub and cannot be checked
out — F1-BUILD-REPORT.md §1). The WW3 **6.07** manual
(`docs/reference/ww3-user-manual-v6.07.txt`, committed at DOC-W.4) is the sole authority
for WW3 behavior henceforth — never 5.16 text, never web-fetched WW3 docs once
committed (PRIME DIRECTIVE 10, same rule as the local SWAN manual).

**Evidence:** operator ruling in chat, 2026-08-16 ("if 6.07 is the current model, then
you should pull the manual for it"). `scratch/SYNTAX-607-VERIFICATION.md` re-verified
every WW3-side SYNTAX PRESCRIPTIONS row against the 6.07 text; one substantive delta
found and absorbed: 6.07 ships a distinct ST6 default calibration column from 5.16
(SDSP1 a1 3.74E-7→4.75E-6; SINA0 a0 5.24E-6→7.00E-5; β/CSTB1 28.0-hardcoded→32.0-
namelist; text at 6.07:3070/3139) — our 6.07.1 build compiles these in automatically
under the "manual defaults untouched" rule (F1b); any earlier document quoting 5.16-era
ST6 numbers is stale for this build.

## D3 — Grid, resolution, obstruction

**Domain extent** (WD1): reuses the live L1 sizing box exactly — SW
32.55495495495496°N/-119.30411432995714°W, NE 34.080643083237035°N/-117.77247421400396°W
— pulled read-only from `/etc/weewx-clearskies/swan_grid_sizing.json`'s `level1` block
(F2-CONFIG-REPORT.md §2, not the plan's rounded prose). This is a **regional** input
(PW2's containment-lesson rule): the offshore domain reads the region's own geometry,
never a spot's local features.

**Two grid variants were built and run, both to `rc=0` under both physics candidates**
(F2-CONFIG-REPORT.md §6):

| Variant | Resolution | Cells | Sea points | Boundary points | Obstruction handling |
|---|---|---|---|---|---|
| G1 | ~1.0 km (143×171 mesh) | 24,453 total | 20,887 (85.4%) | 313 | Islands resolved as dry cells, `FLAGTR=0` |
| G2 | ~3.96–4.04 km (37×43 mesh) | 1,591 total | 1,329 (83.5%) | 79 | Generated obstruction/transparency field, `FLAGTR=2` |

Depth-sign convention KAT-confirmed exact: ETOPO 2022 15s (LMSL datum, same source/datum
as L1, ADR-098 discipline) already stores water as negative elevations — WW3's own
native `ZBIN` convention — so the deck's scale factor is **1.0**, not the manual's
worked-example `-10` (F2-CONFIG-REPORT.md §3, exact match at the G1 SW-corner cell,
-96.760536194 m both source and grid).

**[OPERATOR ACCEPTANCE ROW] — D3a: is an intermediate grid needed between NOAA's ~16 km
output and our target resolution?**

NOAA's own documented practice steps grid resolution 2:1–3:1 per hop (research brief
§1b/§1c). Our measured hops both sit outside that band: G2/NOAA ≈ 4.0–4.1:1, G1/G2 ≈
3.9–4.0:1 (F2-CONFIG-REPORT.md §4). Competing evidence (F5-CATALOG.md, Group 3, Open row
O3):
- **For adding an intermediate ~8 km grid:** brings both hops inside the 2:1–3:1 band.
- **Against:** NOAA's own most-relevant precedent (NWPS) does not keep nesting WW3-in-
  WW3 down to 1 km — it hands off WW3→SWAN once WW3 reaches regional/coastal
  (tens-of-km) scale, architecturally closer to what this plan already does (WW3 always,
  then SWAN at L2) than "add more WW3 grids." G2 is measured **~64× cheaper than G1**
  (29.05 s vs 1877.92/1850.61 s, F3-MARCH-REPORT.md §2.1), and G1×P1 is already ~1.7×
  faster than SWAN-L1 (D4 below) — cost does not obviously argue FOR adding a grid. An
  intermediate grid would need its own FLAGTR/timestep/switch-token(`O1`) derivation
  rows, a bounded but real amount of new catalog work (F5-CATALOG.md Group 1's `O1`
  row).

**Lead recommendation: NO intermediate grid — go straight from NOAA's output to G1
(with G2 as a documented but currently-unused fallback variant).** Rationale: the NWPS
precedent is the stronger analogy (we are already doing what NOAA does — hand off
early, not nest deeper), and no F-phase cost or fidelity evidence argues for the added
grid. **This is not evidence-decided; it is a recommendation for your acceptance.**

**[OPERATOR ACCEPTANCE ROW] — D3b: G2's exact resolution has no general per-install
derivation formula.** F2 built G2 at ~3.96–4.04 km as "a lead-chosen test point inside
NOAA's 2:1–3:1 hop band" (F2-CONFIG-REPORT.md §4/§WD1 prose) — not itself derived from a
site input. If G2 is ever used in production (D3a above recommends it is not, at this
install), a real per-install formula must be written before W4 derives it mechanically;
this ADR does not invent one.

## D4 — Physics package [OPERATOR ACCEPTANCE ROW]

**Candidates (both built, switch strings verbatim in F1-BUILD-REPORT.md §2):**
- **P1 — ST6 (Babanin/Young/Donelan/Rogers/Zieger), paired FLX4.** Same physics family
  as our existing SWAN deck (`GEN3 ST6 … AGROW`); carries the negative-input term our
  `NEGATINP` maps to; own published calibration table (F1b, plan §WW3 MODEL DESIGN v1).
- **P2 — ST4 (Ardhuin et al. 2010), paired FLX0.** NOAA's own operational pairing —
  confirmed against NOAA's own `README.NCEP` shipped inside the WW3 repo: `multi_1`
  (global operational, GFS-driven) and the Great Lakes model both run
  `switch_NCEP_st4sbs`/`switch_NCEP_st4` (ST4/FLX0/STAB0), cross-checked against an
  independent NOAA web source with no contradiction (F1-BUILD-REPORT.md §4).

**Cost (F3-MARCH-REPORT.md §2.1/§2.2, F4b §F4b.3):**

| | Solo/cheap-shaped (12h, F3) | Production-shaped (24h, real time-varying boundary, F4b) |
|---|---|---|
| G1×P1 | 1877.92 s / 1850.61 s (twice-reproduced) ≈ 31 min → 156.5 s/sim-hr | 4706.82 s ≈ 78.4 min → 196.1 s/sim-hr (1.25×) |
| G1×P2 | 2828.27 s ≈ 47.1 min → 235.7 s/sim-hr | 9269.60 s ≈ 154.5 min → 386.2 s/sim-hr (1.64×) |

P2 costs ~1.5–2× P1 at every measured shape. `mod_def.ww3` (build artifact) size: P1
876 KB (G1) vs P2 51.8 MB (G1) — ST4's compiled-in nonlinear-interaction lookup tables
(F3-MARCH-REPORT.md §2.2; decks are byte-identical between P1/P2, so the size delta is
purely the physics package).

**Convergence/quasi-steady behavior (F4b.4, the corrected time-varying-boundary
marches — supersedes the original F3/F4 single-snapshot-boundary verdict, F4-REPORT.md
§F4b.1):**

| | Points reaching sustained quasi-steady within 24h | First-completion hour range |
|---|---|---|
| G1×P1 | 10 of 11 (BUOY46256 never sustains ≤5%) | h=12 to h=17 |
| G1×P2 | 11 of 11 | h=12 to h=14 |

**Seam Hs (F4b.5) — VOIDED (2026-08-17):** the F4b seam figures (P1 0.676–0.720 m,
P2 0.766–0.780 m) were produced by marches fed through the direction-fastest
(scrambled) boundary emitters — trap 21 voids their amplitude fidelity, and they carry
no evidentiary weight in this row. The earlier statement "no ground-truth check exists"
is superseded: **G1×P1 now has a real buoy validation**
(`scratch/F4-BUOY-VALIDATION-REPORT.md`): restart-chained, corrected axis order, real
NOAA gfswave boundary+wind — Hs within 5–15% of NDBC 46253/46222 (model/buoy ratio
0.93–0.94 over the equilibrated hours h06–h20), direction within ±10–15°, period within
±3 s, arriving SSW swell pulse captured. **P2 has no buoy validation — the buoy round
ran P1 only.** (The convergence-timing table above derives from the same scramble-fed
F4b marches; its timing is retained as mechanics-class evidence under trap 21's
cost/mechanics carve-out, but the cold-vs-warm-start question is now answered directly
by the buoy round — see D10.)

**Lead recommendation: P1 (ST6/FLX4).** Rationale: (1) cost — P1 is cheaper at both
measured shapes (1.5–2× cheaper than P2); (2) physics-family consistency across the
WW3→SWAN handoff (same growth/decay family as the existing SWAN deck, carrying forward
this project's own measured ST6 behavior as prior knowledge); (3) the one convergence
gap (BUOY46256 not sustaining quasi-steady within 24h under P1) is a single holdout
point, not a systemic failure, and the plan's own shadow-mode design (D12) gives weeks
of further observation before any cutover decision; (4) **P1 is the only candidate
with real-ocean validation evidence** — the 2026-08-17 buoy round (above) shows G1×P1
matching real buoys within 5–15% under production-like restart-chained conditions.
**This is not fully evidence-decided — P2's NOAA-operational pedigree is a real,
competing consideration, and P2 was never buoy-validated (choosing it would require
its own validation round). Accept P1, or direct otherwise.**

## D5 — Boundary-assembly program [OPERATOR ACCEPTANCE ROW]

**Candidates:** `ww3_bound` (ASCII) vs `ww3_bounc` (NetCDF). Both built under both
switch files; **neither has the `NC4` token in its switch string** (F2-CONFIG-REPORT.md
§1) — `ww3_bounc`'s NetCDF read path is unlikely to be functional without it, and adding
`NC4` is itself a switch-content decision this ADR would need to make (SYNTAX row 7).

**Evidence:** `ww3_bound` has a **full end-to-end proof**: a self-generated transfer-
format specimen (from our own `ww3_outp`), validated by `ww3_bound` reading it (including
a real, expected `ILLEGAL XFR` rejection confirming the single-spectral-grid constraint
is source-enforced, F2c.2), then our real reconstructed archived-cycle spectra assembled
into a real `nest.ww3` (22,710 B, F2c.3) and a corrected 22-file one-per-position rebuild
(234,558 B, F4b.1). `ww3_bounc` was never smoke-tested in F-phase — zero F-phase evidence
(F5-CATALOG.md Group 4, Open row O4/Gap G4).

**Lead recommendation: `ww3_bound` (ASCII).** It is the only candidate with any F-phase
proof. `ww3_bounc` would need a fresh switch-file decision (adding `NC4`) plus a full
smoke-test round before it could be considered — not attempted this phase.

**⚠ MATERIAL CAVEAT (added 2026-08-17; ATTRIBUTION CORRECTED same day after operator
challenge and external verification — read before accepting this row).**
The transfer-file spectrum block is **frequency-fastest**, and `ww3_bound` reads it
correctly. Verified against NOAA's own source (fetched live from NOAA-EMC/WW3, not
recalled): the official writer `ww3_outp.ftn` at tag 6.07.1 (lines 1816/1822/2072/2096)
emits `WRITE (...) ((E(IK,ITH),IK=1,NK),ITH=1,NTH)` — frequency index varies fastest —
and `ww3_bound`'s `SPEC2D(NK1,NTH1)` whole-array list-directed READ fills column-major,
also frequency-fastest. Writer and reader agree; NOAA's issue tracker shows no such
defect; **there is no WW3 bug** (an earlier F4c.7 claim to the contrary misread
`w3iobcmd.ftn` — the binary nest writer — as the ASCII writer). **The defect was OURS:**
the project's F4b/F4c transfer-file emitters wrote the spectrum block direction-fastest,
so `ww3_bound` — reading per the official convention — assembled silently SCRAMBLED
spectra: energy sum preserved (sum-level checks pass), spectral shape and Hs corrupted
by a shape-dependent factor (measured 1.98× Hs on the uniform KAT spectrum, 1.62× on a
real F4b spectrum; confirmed by float32-exact reproduction, F4-REPORT §F4c.7/§F4c.7c).
**Consequence for this row:** `ww3_bound` is exonerated and the recommendation stands
WITHOUT any compensating measure — but PW4's boundary emitter MUST write the spectrum
block frequency-fastest (the corrected-order files passed every known-answer gate
exactly: boundary 0.6500 m, real-spectrum control 0.9604 vs 0.9607). The scramble VOIDS
the amplitude-fidelity (not cost/mechanics) evidence of every F4b `ww3_bound`-fed march.
**The corrected emitter is since proven in production-like use (2026-08-17):** the buoy
validation round's frequency-fastest generator (`gen_boundary_buoy_val.py`, on librewxr
under `/tmp/ww3-feas/`) fed real NOAA gfswave spectra through `ww3_bound` into marches
that match real buoys within 5–15% (`scratch/F4-BUOY-VALIDATION-REPORT.md`) — the
end-to-end amplitude proof the scramble had voided now exists with the corrected order.

## D6 — SWAN-ingestion mechanism [OPERATOR ACCEPTANCE ROW]

**Candidates:** A — `BOUNDNEST3` (WW3-native SWAN command reading WW3's own transfer
format) vs B — an Appendix-D spectra writer (our own existing per-cell reconstruction
format, retargeted to read WW3 output).

**Evidence:** F4.3's mandatory compatibility check (row 10) **PASSED**: a real
`ww3_outp`-written transfer file (`ww3.26081400.spc`, 367,301 B, header format matching
SYNTAX row 10 exactly) was read by real production SWAN 41.51AB's `BOUNDNEST3` with
**zero boundary-read errors**, after isolating and satisfying SWAN's own ≥2-boundary-
point floor (a real SWAN design constraint, not a format mismatch — a 1-point file was
correctly rejected with an explicit SWAN error, a 2-point file initialized cleanly,
F4-REPORT.md §4.1). Candidate B was never smoke-tested end-to-end in F-phase (F5-CATALOG
Group 4, Open row O5/Gap G5).

**Lead recommendation: Candidate A (`BOUNDNEST3`).** It is proven end-to-end,
WW3-native (no format-translation code to build or maintain), and directly reuses the
D5 recommendation's own emitter format (row 10 is the same transfer format `ww3_bound`
consumes).

## D7 — Wind preprocessor path [OPERATOR ACCEPTANCE ROW]

**Candidates:** `ww3_prep` (ASCII) vs `ww3_prnc` (NetCDF, same `NC4`-absent constraint as
D5). **Evidence:** `ww3_prep` is fully proven — the real shipped worked example
(`regtests/ww3_ts4/input_rg_multi/ww3_prep_wind.inp`) was found and used to produce a
real `wind.ww3` (195,704 B, rc=0, F2b.1a), after four failed structural guesses (missing
the two-format-string requirement and the external-file convention, F2-CONFIG-REPORT.md
§8/F2b.1a — recorded as a measured trap, Group 5 in D13 below). `ww3_prnc` was built but
never smoke-tested (Gap G6).

**Lead recommendation: `ww3_prep` (ASCII).** Same reasoning as D5 — the only proven path.

## D8 — Spectral grid and deck time steps (evidence-confirmed, not open)

**Spectral grid (WD3): exact match to the reconstruction axes** —
`1.1086 0.030 35 72 0.` (increment factor, first frequency 0.03 Hz, 35 frequencies, 72
directions/5°, 0° relative offset). Confirmed via `ww3_grid`'s own program echo for all
4 grid×physics combinations (F2-CONFIG-REPORT.md §5): "Number of directions: 72,
Directional increment (deg.): 5.0, Number of frequencies: 35, Frequency range (Hz):
0.0300-0.9988, Increment factor: 1.109." One spectral grid end-to-end (reconstruction →
`ww3_bound`'s single-grid constraint → WW3 → handoff → SWAN CGRID axes) eliminates
spectral interpolation at both seams.

**Time steps (WD4), derivation formula confirmed exact against `ww3_grid`'s own echo**
(F2-CONFIG-REPORT.md §5): `critical_xy = 33.4 s × (grid_min_cell_km / 1 km)`;
`global = 3 × critical`; `k-theta = global / 2`; `source-floor = 10 s` (fixed, 5–15 s
band, resolution-independent).

| Grid | Min cell | Global | Max x-y CFL | k-theta | Source floor |
|---|---|---|---|---|---|
| G1 | 0.99906 km | **100** | **33** | **50** | **10** |
| G2 | 3.95772 km | **396** | **132** | **198** | **10** |

## D9 — Forcings split (wind-only) [OPERATOR ACCEPTANCE ROW]

**Decision candidate:** the deep leg is forced by **wind only** (WD6). Water level and
currents stay SWAN-side (L2 down): tide-scale depth modulation is negligible over the
leg's ≥hundreds-of-metres depths, and currents remain the separate
L1-BOUNDARY-REBUILD-PLAN's own queued program. This is explicitly **not a silent
omission** — the plan requires it be an explicit acceptance row, not a default (PRIME
DIRECTIVE 11).

**Evidence the mechanism works:** the wind-regridding and re-emission path is proven
end-to-end for the F0-pinned archived-cycle wind file (`wind.ww3`, 195,704 B, F2b.1a).
A real constraint measured: WW3's forcing-field reader requires the wind file's grid
dimensions to match the model grid EXACTLY — no automatic cross-resolution
interpolation (`INCOMPATIBLE GRID DATA` error, F3-MARCH-REPORT.md §2.3) — so each grid
variant needs its own re-prepped wind file (a disclosed nearest-neighbor resample
simplification, not bilinear/area-weighted). **What is NOT yet built:** the production
wind-store→WW3-grid regrid/re-emit step — F-phase only proved the mechanism on a static
pinned archive, not the live wind-gatherer store, which deletes past hours by design and
cannot itself hold an archived cycle (F5-CATALOG Group 5, Gap G7).

**Lead recommendation: accept the wind-only split as designed.** No F-phase evidence
argues for including currents/water-level at this leg; the rationale (depth scale,
existing queued program) stands independent of any measurement this phase could make.

## D10 — Initial state per cycle [OPERATOR ACCEPTANCE ROW]

**Candidates:** (i) restart-file chaining (`restart.ww3`, WW3's native hotstart) with a
staleness gate, or (ii) cold start with a spin-up lead (6–12 h before the served window).

**Evidence:**
- **(i) is mechanism-proven:** F3's marches showed `Restart file read; full restart.`
  (unambiguous log evidence, F3-MARCH-REPORT.md §1.4) — but **no measured staleness-gate
  criterion exists yet** (F5-CATALOG Group 6, Gap G11/Open row O7).
- **(ii) has real convergence numbers** under the corrected time-varying boundary: 10/11
  to 11/11 points reach quasi-steady state within 24 h (D4's table above), first-
  completion hours ranging 12–17. This measurement REVERSED the original F3/F4 verdict
  ("not complete within 12h") once a boundary-assembly defect was fixed (F4b.1, the
  one-file-per-position trap, D13 Group 4/trap #15) — the original negative result was
  an artifact of a broken single-snapshot boundary, not a real spin-up failure.
- **A real, disclosed computational characteristic:** a calm-start march under
  immediate full-strength wind shows a sharp per-step cost increase within the first
  ~40 minutes to ~2 h of simulated time (source-term numerical stiffness during rapid
  initial energy growth, F2c.4) — exactly the transient a spin-up lead exists to absorb
  before the served window opens.
- **The buoy round answers cold-vs-warm directly (2026-08-17,
  `scratch/F4-BUOY-VALIDATION-REPORT.md`):** an identical G1×P1 march pair with the
  corrected boundary order shows the flat-ocean cold start 34–38% LOW against the buoys
  after a full 24 h (Hs still rising +10–16% over the last 12 h — not equilibrated),
  while the restart-chained warm start matches the buoys within 5–15%. Note the F4b
  convergence numbers in the row above came from scramble-fed marches (mechanics-class
  only, per trap 21); this buoy-round measurement is the corrected-order, real-data
  answer — restart-chaining is the measured difference between failing and passing the
  buoy comparison inside a 24 h window.
- **A real restart constraint (measured, 2026-08-17):** WW3 refuses a restart file
  whose timestamp does not exactly match the run's start time (`w3iorsmd.ftn:468–473`,
  `EXTCDE(20)`, no fallback) — the chaining design must produce a restart stamped at
  each cycle's exact start time (trap 23).

**Lead recommendation: restart-file chaining (candidate i), with a staleness gate set by
analogy to the live SWAN-L1 mechanism (D11 below).** Rationale: it is the more efficient
steady-state mechanism once a trusted restart exists; the calm-start transient
measured above (D10 evidence) shows cold starts pay a real, non-trivial cost every
cycle; and the 2026-08-17 buoy round shows a 24 h cold start is not merely costly but
INSUFFICIENT — it fails the buoy comparison that restart-chaining passes.
**The exact staleness-gate hour count is NOT measured — this ADR proposes a value in D11
by analogy, not by WW3-specific evidence; the operator may set a different number.**

## D11 — WW3 nest-age refuse-gate value [OPERATOR-SET]

**Precedent:** the live SWAN-L1 path's `L1_NEST_MAX_AGE_H = 9` (ADR-108) — refuse-loudly
semantics operator-confirmed 2026-08-15 (plan's C14 entry, "yes a"): when the archived
nest exceeds 9 h, the hourly cycle stops publishing, the site serves the last good
forecast, health goes red with the named reason.

**Proposed value: `WW3_RESTART_MAX_AGE_H = 9`** — the same numeric value as the live
path's analog, applied to the WW3 leg's restart-chaining staleness gate (D10). This is a
**proposal by analogy, not a WW3-specific measurement** — Phase F did not measure a WW3
restart-staleness failure threshold. Refuse semantics copy C14's pattern exactly: when
the WW3 leg's most recent restart exceeds this age, the WW3-leg cycle refuses to publish
its artifacts (never falls back to a fabricated or stale-but-unflagged state), and health
reports the named reason. **Accept 9 h, or set a different value.**

## D12 — File/dir layout, scheduling cadence, shadow-mode key, compute budget

**File/dir layout (design, PW1's "new persisted files" trigger):**
- `level0/` (new top-level directory alongside the existing `level1/`–`level4/`
  directories) holding: `mod_def.ww3` (versioned, rebuilt only on geometry/config
  change per WD10), per-cycle `nest_out_<cycle>.ww3` (the boundary product handed to
  L2, retention ≥24 h — mirroring ADR-108 D5's existing `nest_out_<cycle>.dat`
  retention pattern), per-cycle `restart_<cycle>.ww3` (chained per D10), per-cycle
  field/point output for the ledger instruments and validation.
- Build artifacts (`mod_def.ww3` per grid variant) are versioned like any other
  compiled/derived artifact — rebuilt whenever the geometry-change detection fires
  (WD10; production hook NOT yet built, F5-CATALOG Gap G10).

**Scheduling cadence:** the WW3 leg runs on the same full-run cadence as the live
SWAN-L1 path runs today (6-hourly FULL cycles, per the plan's PRIME DIRECTIVE 2/PW1
"new schedule entries" trigger) — it does NOT run on the hourly fast-cycle cadence,
matching D10's restart-chaining design (a fresh restart every full-run cycle, chained
forward). This mirrors ADR-108 D5's own full-vs-hourly split.

**Per-site shadow-mode key (PW5):** a single boolean config key,
`ww3_shadow_mode_enabled` (transition-only — dies with the transition at cutover or
retirement, per PW5), gates whether the WW3 leg runs at all for a given site. When true:
the WW3 leg computes and stores every artifact above; it does **not** feed L2 — the live
SWAN-L1 path's own per-wet-cell boundary mechanism keeps serving unchanged. There is
**no enable/disable knob for WW3 itself** (Q1 ruled always-on); the shadow-mode key is
the sole write-capable surface, and only for the duration of the transition.

**Shadow compute budget, from measured pace data — stated honestly, cheap- vs
production-shaped (F4b.3):**

| | Cheap-shaped (F3: 12h, solo, constant boundary, 2-point mean-param output) | Production-shaped (F4b: 24h, time-varying boundary, 11-point full-spectrum output) |
|---|---|---|
| G1×P1 | 156.5 s/sim-hr | **196.1 s/sim-hr (1.25× the cheap-shaped figure)** |
| G1×P2 | 235.7 s/sim-hr | **386.2 s/sim-hr (1.64× the cheap-shaped figure)** |

The production-shaped ratio is the one to budget compute against, not the cheap-shaped
F3 solo figures — F4b's own analysis could not fully isolate the cause (three plausible,
non-exclusive contributors: boundary re-read bookkeeping on each of 8 archived
timesteps, richer 11-point full-spectrum I/O, and a genuinely more populated spectral
field once the sea state develops), but the ratio itself is real and measured, not
assumed. **Thread split:** F-phase measured WW3 at `OMP_NUM_THREADS ≤ 4`, nice 15,
never starting a march while a production FULL run is in flight (the same E1/E2
contention protocol the SWAN benchmark baseline used) — this is the recommended
production thread budget for the shadow leg, running serial-not-concurrent with the
SWAN cycle to avoid contention, consistent with F-phase's own measurement conditions.
**Per-cycle wall-clock ceiling:** using G1×P1's production-shaped rate over a
representative served window, the leg is measured in the tens-of-minutes class per
cycle (F4b's real 24 h march: 4706.82 s ≈ 78.4 min for G1×P1; 9269.60 s ≈ 154.5 min for
G1×P2) — well inside the plan's contention-budget wall-clock ceiling used throughout
Phase F (never approached). **Corroborated with the corrected boundary order
(2026-08-17):** the buoy-validation 24 h G1×P1 marches ran 4183.58 s (cold) and
4509.74 s (restart-chained, real live-fetched NOAA gfswave GRIB2) ≈ 174–188 s/sim-hr —
inside the production-shaped budget above (`scratch/F4-BUOY-VALIDATION-REPORT.md`;
cost evidence was never voided by trap 21, this is confirmation, not replacement).

## D13 — F5 Parameterization catalog (embedded in full — PRIME DIRECTIVE 11, never product-facing)

*(Reproduced verbatim from `scratch/F5-CATALOG.md`, task F5, Phase F. Pure document
synthesis — no new measurements, no design decisions made here that were not already
made above. Every row states its governing rule, the site information that determines
it, the derivation formula, and the supplying setup analysis or a named GAP. Cite
convention: `SYNTAX-row-N` = plan `## SYNTAX PRESCRIPTIONS`; `WD-N` = plan `## WW3
MODEL DESIGN v1`; `6.07:NNNN` = `docs/reference/ww3-user-manual-v6.07.txt` line;
`S607#N` = `scratch/SYNTAX-607-VERIFICATION.md` finding number; `F1/F2/F2b/F2c/F3/
F4/F4b-§N` = the corresponding Phase F report section. These are universal,
install-independent selections (PRIME DIRECTIVE 11: fixed once here, never a
product-facing setting) except where a row is explicitly marked per-install-derived.)*

### Group 1 — Switch file: every category token (universal, install-independent)

| Category | Token(s) (P1 / P2 where they differ) | Governing rule | Derivation |
|---|---|---|---|
| Build/machine | `F90 NOGRB LRB4 NOPA SHRD OMPG OMPX` | `SYNTAX-row-7`; manual §5.9.1 pure-OpenMP combination 6.07:10279–10282 | Fixed; honors `OMP_NUM_THREADS≤4` F3 budget |
| Propagation scheme | `PR3 UQ` | F1b (third-order ULTIMATE-QUICKEST, "default operational scheme," `w3pro3md.F90` source read) | Fixed, universal |
| Flux | `FLX4` (P1) / `FLX0` (P2) | F1b: FLX4 pairs with ST6 (Hwang 2011, ST6's own calibration table binds CDFAC as an FLX4 param, 6.07 Table 2.8); FLX0 pairs with ST4 (WAM4-family stress computed inside source terms, 6.07:13739/10052) | Fixed pairing per candidate, no per-site choice |
| Linear input | `LN1` (both) | manual §5.9.1 mandatory group, 6.07:10061–10066 | Fixed, universal, both candidates |
| Source-term package | `ST6` (P1) / `ST4` (P2) | F1b candidate design; decided by D4 above | **See D4 — [OPERATOR ACCEPTANCE ROW]** |
| Stability | none (P1); none in Phase F (P2, no STAB3) | F1b defaults-untouched rule; `stab3` compatible with ST3/ST4 per 6.07 (widened from 5.16's "ST4 only") | P1: no stab switch exists for ST6. P2: STAB3 withheld in Phase F — a future addition is a physics change requiring its own operator ruling |
| Nonlinear | `NL1` (both) | F1b: DIA, not the exact-interaction NL2/WRT (prices out at ~40 freq/1.07, 6.07:1432–1440) | Fixed |
| Bottom friction | `BT1` (both) | F1b: JONSWAP friction, stated-not-silent shallow term | Fixed, near-irrelevant on deep leg but stated (PRIME DIRECTIVE 11) |
| Breaking | `DB1` (both) | F1b: Battjes-Janssen, stated-not-silent | Fixed |
| Triads/bottom scattering/supplemental/reflection | `TR0 BS0 XX0 REF0` (both) | F1b: none on a SoCal deep leg | Fixed off |
| Ice/ice source | `IC0 IS0` (both) | F1b: SoCal, no-ice, consistent with FLAGTR's no-ice values | Fixed off |
| Wind/current interpolation | `WNT1 WNX1 CRT1 CRX1` (both) | F1b: linear, confirmed against shipped center-example switch files 6.07:14046–14050 | Fixed |
| Nested-boundary marking | `O1` (mandatory when a child grid marks input-boundary points) | `SYNTAX-row-6`/`row-8`; App B.1 step 3, 6.07:13735–13738 | Only relevant if D3a adds an intermediate grid — not yet exercised |
| NetCDF (`NC4`) | absent from both P1/P2 strings | F2 §1 finding: `w3_make` warns NC4 configured but not in switch | Needed only if D5/D7 pick a NetCDF path — this ADR does not, so `NC4` stays absent |
| Propagation-scheme namelist tuning (`&PRO2/&PRO3/&PRO4`) | not set in any F-phase deck | F-phase decks set only `&MISC FLAGTR=n` | **GAP** — W4 must confirm whether PR3/UQ needs explicit namelist tuning or whether "manual default, deliberately untouched" is a considered choice (as for ST6/ST4) or an oversight |
| `MLIM` (NOAA's own operational modifier) | absent from both P1/P2 | Not a mandatory-group token; F1 built/smoke-tested clean without it | Not a gap — recorded for completeness since NOAA's own operational string carries it |

## D4 (embedded row, for cross-reference): OPEN — ADR decides
ST6-vs-ST4 physics-package choice: resolved above at **D4**.

### Group 2 — `ww3_grid.inp`: spectral, flags, timesteps, namelist, grid definition, bottom/mask/obstruction reads

| Input | Governing rule | Derivation |
|---|---|---|
| Spectral definition line | `WD-3`; `SYNTAX-row-6` 6.07:14548–14562 | Resolved above at **D8** |
| Model flags line (`FLDRY FLCX FLCY FLCTH FLCK FLSOU`) | `SYNTAX-row-6` 6.07:14566–14578; **S607 addendum #1** (must be space-separated — the manual's own printed `FTTTFT` is a page-compaction artifact) | Production: `F T T T F T`. Diagnostic-only (source-terms-off): `FLSOU=F` |
| Time-steps line | `WD-4`; Named Constants 2–4× CFL rule | Resolved above at **D8** |
| `&MISC FLAGTR = n` | `SYNTAX-row-6/12`; 6.07:15349–15361; **S607 addendum #2** (an empty namelist section breaks the reader — always state ≥1 entry) | G1: `FLAGTR=0`. G2: `FLAGTR=2` |
| ST6/ST4 physics namelist tunings | F1b "defaults untouched" rule; **6.07 Table 2.8 delta from 5.16** (see D2) | No explicit deck value; the 6.07.1 build compiles the 6.07 defaults in automatically |
| Grid-definition lines (`'RECT' T 'NONE'`; NX NY; increments; SW-corner) | `SYNTAX-row-6a` worked example 6.07:15716–15721 | Resolved above at **D3** (WD1's live corners) |
| Bottom-depth read line | `SYNTAX-row-6a` 6.07:15665–15696; depth-sign TRAP 6.07:15725 | Resolved above at **D3** (scale factor 1.0). **GAP**: the numeric limiting-depth / minimum-water-depth values themselves are not stated in any F-phase report — W4 must state these explicitly from the actual deck files, never a silent default |
| Obstruction read (G2 only) | `SYNTAX-row-6a` 6.07:15920–16019 | Transparency = fraction of G1 dry-cell area open within the coarser cell's footprint; mean 0.854, min 0.000, max 1.000. **GAP**: isotropic simplification disclosed (no directional x≠y obstacle-orientation data) |
| Status-map/boundary-point block | `SYNTAX-row-6a` 6.07:16050–16112; **S607 addendum #4** (outer-ring "land only" text resolved: land/inactive/active-boundary are all valid) | Mark status=2 on wet **South-row and West-column** perimeter cells ONLY, mirroring the F0-preserved baseline's own `B_S_*`/`B_W_*`-only pattern (Q4 ruling: east side is land) |
| Output boundary points section | **S607 addendum #3** (a separate, easy-to-miss mandatory section; PREMATURE-END error without it) | Always emit `0. 0. 0. 0.  0` (zero output-boundary points requested) |

### Group 3 — Grid architecture: extent, resolution, COUNT

| Input | Governing rule | Derivation |
|---|---|---|
| Domain extent (SW/NE box) | `WD-1`; PW2 (region geometry, never spot-local) | Resolved above at **D3** |
| G1 resolution (~1 km) | `WD-1` | Direct reuse of L1's existing `resolution_m` field |
| G2 resolution (~3–5 km) | `WD-1`; NOAA's 2:1–3:1 hop practice | **[OPERATOR ACCEPTANCE ROW]** — see D3b, no general per-install formula exists |
| Grid COUNT (intermediate grid?) | `WD-1`; NOAA 2:1–3:1 hop practice; F2 §4 measured hop ratios | **[OPERATOR ACCEPTANCE ROW]** — see D3a |

### Group 4 — Boundary: placement, point spacing, assembly program, one-file-per-position, spectral-grid identity

| Input | Governing rule | Derivation |
|---|---|---|
| Placement rule | `WD-7`; PW2 (NOAA-trusted open-water line) | S/W wet perimeter cells only marked status=2; N/E left natural (Q4: east is land) |
| Point spacing | `SYNTAX-row-2`; WW3-side implicit in status-map marking | One active boundary point per wet perimeter cell at the grid's own resolution |
| Assembly program (`ww3_bound` vs `ww3_bounc`) | `SYNTAX-row-9` | Resolved above at **D5** |
| SWAN-ingestion mechanism (A vs B) | `SYNTAX-row-4` | Resolved above at **D6** |
| One-file-per-position semantics | `ww3_bound.ftn` source (F4b's measured trap — see D13's trap list, item 15) | Emit exactly one transfer-format file per geographic boundary position, each carrying its own multi-timestep series — NEVER encode multiple positions as successive entries inside one file (silently misassembles the nest) |
| Spectral-grid identity | `SYNTAX-row-9` hard constraint; XFR consistency check, `model/ftn/ww3_bound.ftn:361` (source-enforced) | Every boundary input file MUST share the target grid's exact XFR/freq/dir axes (frequencies copied directly, already on-axis; directions converted nautical-FROM-degrees → oceanographic-TO-radians, count-only validated) |

### Group 5 — Wind: regridding + prep/prnc path

| Input | Governing rule | Derivation |
|---|---|---|
| Wind source | `WD-6` | Resolved above at **D9**. **GAP**: the production wind-store→WW3-grid regrid/re-emit step is unbuilt |
| Cross-grid wind regridding | F3 §2.3 (measured: WW3 requires EXACT grid-dimension match — no automatic interpolation) | Nearest-neighbor resample of the same wind source onto each grid variant's own NX×NY (disclosed simplification) |
| Wind preprocessor path (`ww3_prep` vs `ww3_prnc`) | `SYNTAX-row-6c` | Resolved above at **D7** |
| Wind field-data record framing | **S607 addendum #5** (measured trap — two format strings, external file `FROM='NAME'` unit≠10, no separate dimension/reclen line) | `'NAME' IDLA IDFM 'header_fmt' 'data_fmt'`, time-in-file=T, one header line then field values, external file |

### Group 6 — Run sequence: strt/shel/outp conventions, restart chaining, output types

| Input | Governing rule | Derivation |
|---|---|---|
| Initial state (restart-chaining vs cold-start-with-lead) | `WD-8` | Resolved above at **D10** |
| `ww3_strt` calm-start option | **S607 addendum #10** (ITYPE=5 "no additional data," not ITYPE=1) | `ww3_strt.inp`: ITYPE=5 |
| `ww3_shel.inp` forcing-flags block | `WD-6`; `SYNTAX-row-6b`; **S607 addendum #9** (space-separated `T`/`F`, not packed) | `F F F F T F F F F F` (water levels/currents off, winds on/non-homogeneous, ice off, no assimilation) |
| Output server mode (`IOSTYP`) | `SYNTAX-row-6b`; manual §4.4.9, 6.07:18542–18544 | `IOSTYP = 1` (our build is `SHRD` shared-memory, single-image — the only applicable mode) |
| Output Type 1 (field) | `WD-9`; `SYNTAX-row-6b` | F-phase: HS-only scalar field. **GAP**: the full production field-output symbol set (needed for the Named-Constants band ledger at field, not just point, resolution) is a W-phase refinement |
| Output Type 2 (point) | `WD-9`; `SYNTAX-row-6b`; **S607 addendum #11** (use the `N`/namelist-symbol method, not positional group flags — our 6.07.1 build's field count is version-sensitive) | **GAP — feeds W4**: the real L2 boundary/seam/lee/corridor point list does not exist yet anywhere in F-phase artifacts; F-phase used placeholder buoy/seam points |
| Output Type 4 (restart cadence) | `WD-10`; `SYNTAX-row-6b` | `begin=end` at the window's close |
| Output Type 5 (boundary/nest cadence) | `WD-10`; `SYNTAX-row-6b/8` | begin/increment/end must match the boundary emitter's real cadence exactly (F4b's real 3h cadence, 8 archived timesteps, confirmed working — not F2c's 999999s single-snapshot workaround) |
| Output Types 6/7 | `SYNTAX-row-6b` | Type 6: dummy line. Type 7: fully commented (no coupling compiled) |
| `'STOPSTRING'`/`'STP'` literals | `SYNTAX-row-6b/8` | Exact literal strings, mandatory closes |
| `ww3_grid` execution trigger | `WD-10` — "runs ONLY on geometry/config change" | **GAP**: hook to the existing geometry-change detection is production mechanism, not F-phase built |
| `ww3_outp` invocation convention | F4-§1.1 (measured trap — does NOT read stdin; opens a file literally named `ww3_outp.inp` in the CWD) | Deck must be named exactly `ww3_outp.inp`; never invoke with a stdin redirect |
| Per-cycle run sequence | `WD-10` | wind prep → boundary assembly → `ww3_shel` march → handoff extraction |

### Group 7 — Operational shape: timestep lines per grid, budget/pace data

| Input | Governing rule | Derivation |
|---|---|---|
| Per-grid timestep formula | `WD-4`; Named Constants | Resolved above at **D8** (reusable for any future grid variant, including a possible intermediate grid) |
| Compute budget/pace | F3 §2, F4.1, F4b §F4b.3 | Resolved above at **D12** |
| `mod_def.ww3` size | Measured fact, F3 §2.2 | P1: 876 KB (G1)/158.7 KB (G2). P2: 51.8 MB (G1)/51.1 MB (G2) |
| `restart*.ww3` size | Measured fact, F3 §2.2 | G1: 212,839,200 B. G2: 13,920,480 B (scales with grid cell count only, not physics package) |
| Wall-clock stop rule | Named Constants (E1/E2 protocol) | Fixed budget; the production scheduling cadence itself is D12's item, not this catalog's scope |

### Measured traps (23 items — hands-on F-phase findings; 21–22 added post-draft from F4c; 23 added 2026-08-17 from the buoy-validation round)

1. `ww3_grid.inp` model-flags line must be space-separated (F2-CONFIG-REPORT.md §7#1; S607#1).
2. An empty namelist section breaks the `ww3_grid` reader — always state ≥1 entry (F2#7-2; S607#2).
3. "Output boundary points" is a separate, easy-to-miss mandatory section, required even at zero points (F2#7-3; S607#3).
4. Apparent land-only outer-ring contradiction, resolved: land/inactive/active-boundary are all valid outer-ring states (F2#7-4; S607#4).
5. `ww3_prep`'s `'WND' 'LL'` data-file-definition line needs TWO format strings, external file via `FROM='NAME'` (unit≠10), no separate dimension line for this field type (F2b.1a; S607 addendum #5).
6. `ww3_bound.inp`'s spectra-file list is closed by the literal `'STOPSTRING'` (undocumented by the manual's template, source-enforced) (F2b.1b; S607#6).
7. The `ww3_outp`↔`ww3_bound` transfer-file format is fully proven — the format authority for the boundary emitter (F2c.1; S607#7).
8. The `XFR` consistency check is the source-level enforcement of the single-spectral-grid constraint (F2c.2; S607#8).
9. `ww3_shel.inp`'s forcing-flags block also needs space-separated `T`/`F` pairs (F2c.4; S607#9).
10. `ww3_strt.inp`'s calm-start option is ITYPE=5, not ITYPE=1 (F2c.4; S607#10).
11. Our 6.07.1 build's Type-1 Group-2 output field count is version-sensitive — use the `N`/namelist-symbol method (F2c.4; S607#11).
12. `ww3_outp` does not read stdin — opens `ww3_outp.inp` literally in the CWD (F4-REPORT.md §1.1).
13. Binary hygiene: never invoke ANY `ww3_*` binary in a directory whose outputs you want to keep — probe in an empty throwaway directory (F3-REPORT §4.1).
14. Depth-sign/scale trap: our scale factor is 1.0, not the manual's worked-example -10 (F2-CONFIG-REPORT.md §3).
15. `ww3_bound.ftn` reads successive file entries as TIME frames of the SAME position, not separate geographic positions — one file per geographic position is mandatory (F4-REPORT.md §F4b.1/§F4b.4).
16. Wind file grid dimensions must match the model grid EXACTLY — no automatic cross-resolution regridding (F3-REPORT §2.3).
17. Direction-convention transform: `rad = radians((deg_from + 180) mod 360)`; only direction COUNT is validated on read, no re-sorting needed (F2-CONFIG-REPORT.md §F2c.3/§F2b.1b).
18. 6.07 manual reorganization is cite-location-only except one high-impact substantive delta: the ST6 default calibration column (D2 above) (SYNTAX-607-VERIFICATION.md).
19. Cliff-KAT wetted-depth-substitution crash — see D14 below (F4-REPORT §3.1).
20. Production-shaped WW3 marches run 1.25×–1.64× slower per simulated hour than F3's cheap-shaped configuration — see D12 (F4-REPORT §F4b.3).
21. **Transfer-file spectrum order is FREQUENCY-FASTEST — a direction-fastest emitter silently scrambles every assembled spectrum.** Official order verified in NOAA's own source at tag 6.07.1: `ww3_outp.ftn` writes `((E(IK,ITH),IK=1,NK),ITH=1,NTH)`; `ww3_bound`'s column-major `SPEC2D(NK1,NTH1)` READ matches it. Our F4b/F4c emitters wrote direction-fastest → scrambled spectra (energy-sum preserved so sum-checks pass; shape/Hs corrupted by a shape-dependent factor). NOT a WW3 bug (earlier attribution corrected after operator challenge + external verification). PW4's emitter must write frequency-fastest. Voids F4b amplitude-fidelity evidence; see the D5 caveat (F4-REPORT §F4c.7/§F4c.7c).
22. **A single-time-record `nest.ww3` self-disarms boundary forcing: `W3IOBC`'s second read hits EOF and sets `FLBPI=.FALSE.`, permanently disabling boundary updates after one application — it does NOT hold the last record steady. Any steady/KAT-style boundary needs ≥2 time records bracketing the run (F4-REPORT §F4c.1 item 5, source-cited `w3iobcmd.ftn` label 810 / `w3wavemd.ftn:1072`).**
23. **A restart file initializes ONLY a run starting at its exact timestamp** — WW3 enforces the match in source (`w3iorsmd.ftn:468–473`, `EXTCDE(20)` "CONFLICTING TIMES", no fallback). The chaining design must emit each cycle's restart stamped at the NEXT cycle's exact start time (F4-BUOY-VALIDATION-REPORT.md finding 4).

### GAP SUMMARY (feeds W4's scope — a gap is a finding, not a failure)

| # | Gap |
|---|---|
| G1 | Propagation-scheme namelist tuning (`&PRO2/&PRO3/&PRO4`) not confirmed deliberate-vs-oversight |
| G2 | Bottom-depth line's numeric limiting-depth/minimum-water-depth values not stated in any F-phase text |
| G3 | G2 obstruction field is isotropic (no directional x≠y transparency data) |
| G4 | `ww3_bounc` has zero F-phase evidence |
| G5 | SWAN-ingestion candidate B (Appendix-D writer) has zero F-phase evidence |
| G6 | `ww3_prnc` has zero F-phase evidence |
| G7 | The production wind-store→WW3-grid regrid/re-emit step is unbuilt |
| G8 | The real L2 boundary/seam/lee/corridor point list does not exist yet in F-phase artifacts |
| G9 | Production Type-1 (field) output symbol set for the full band ledger is undetermined |
| G10 | `ww3_grid`'s production execution trigger (geometry-change hook) was never exercised |
| G11 | Restart-chaining's staleness-gate criterion has no measured number (see D11) |

## D14 — Known defects registered

**1. WW3 wetted-grid init crash (cliff-KAT transplant, BLOCKED, full trail).** Attempting
to reproduce SWAN's cliff-KAT (a source-terms-off, uniform-boundary sensitivity test) on
WW3 by wetting a synthetic -800 m depth substitution at the same island cells produces a
reproducible `SIGABRT`/`malloc(): invalid next size (unsorted)` crash at init, bottoming
out in `w3iopomd_MOD_w3iopp` → `w3grmp_r4/r8` → `w3gfcl_r8` → `w3ckcl_r8` (WW3's
point/field-output grid-cell-mapping init). A full bisection (F4-REPORT.md §3.1) ruled
out point count, point location, and `FLSOU=F` as causes (a differential test on the
real, un-substituted G1 grid runs clean, 130.76 s, rc=0). Leading hypothesis, not
confirmed: the abrupt -800 m synthetic step next to real shallow shelf cells may violate
an assumption in WW3's nearest-cell search. **No cliff-KAT number exists for WW3.**
Flag before any future wetted-substitution KAT attempt.

**2. Seam AGG forcing-comparability caveat — premise VOIDED, question stands
(corrected 2026-08-17).** F4b's marches showed seam-aggregate Hs 0.68–0.78 m — 15–39%
higher than SWAN's real production seam number (0.561 m, e8/e8d1). Those F4b figures
were scramble-fed (trap 21 — the direction-fastest emitter inflates Hs by a
shape-dependent factor), so the apparent high bias carries no amplitude weight. What
real ground truth now shows instead: the corrected, restart-chained G1×P1 march runs
6–7% LOW against the buoys (model/buoy ratio 0.93–0.94,
`scratch/F4-BUOY-VALIDATION-REPORT.md`) — no evidence of a WW3 high bias survives the
correction. The underlying question (WW3-leg vs live-SWAN-path served quality under
matched forcing) remains open and is Phase V's to answer with the shadow campaign;
carried forward for that purpose.

**3. ADR-098 datum-match discipline binds this ADR's bathymetry (D3).** WW3's
bathymetry/mask (ETOPO 2022 15s, LMSL) is the SAME source and datum as the live L1 path
— ADR-098's match-at-source discipline (BOTTOM and WLEVEL on the same vertical datum,
since the models do not detect mismatches themselves) applies to the WW3 leg in full,
by direct citation, not by re-derivation.

## D15 — ADR-108 scope note

ADR-108 (big-L1 true-non-stationary domain) **remains the LIVE serving path** — its
domain, compute mode, hourly-cycle rewire, and refuse-gate mechanics are unchanged by
this ADR and continue to serve production traffic until a Phase V4 verdict-1 (cutover)
ruling, if one is ever given. Under a verdict-2 (hold shadow, open Phase L) or
verdict-3 (extend) ruling, ADR-108's path keeps serving indefinitely. **ADR-108 is NOT
superseded by this ADR.** Any supersession of ADR-108 belongs exclusively to Phase V5's
disposition ruling, never before.

---

## Acceptance criteria checklist

*(Verifiable rows; these become DOC-W-FINAL/W-Accept evidence rows once Phase W lands.)*

- [x] D1: operator confirms the always-WW3 assignment (already ruled 2026-08-15, Q1 —
  restated here for the record this ADR carries forward). ✅ Carried into acceptance
  2026-08-17.
- [x] D2: operator confirms WW3 6.07.1 / 6.07-manual authority (already ruled
  2026-08-16, Q5 — restated here). ✅ Carried into acceptance 2026-08-17.
- [x] D3a: operator rules on the intermediate-grid question (lead recommends NO).
  ✅ RULED 2026-08-17: NO intermediate grid.
- [x] D3b: operator accepts G2's resolution remains an undecided general formula (not
  used at this install per D3a's recommendation). ✅ ACCEPTED 2026-08-17.
- [x] D4: operator accepts P1 (ST6/FLX4) or directs P2 (ST4/FLX0) or a different
  candidate. ✅ ACCEPTED 2026-08-17: P1.
- [x] D5: operator accepts `ww3_bound` (ASCII) or directs `ww3_bounc`.
  ✅ ACCEPTED 2026-08-17: `ww3_bound`.
- [x] D6: operator accepts BOUNDNEST3 (candidate A) or directs the Appendix-D writer
  (candidate B). ✅ ACCEPTED 2026-08-17: BOUNDNEST3.
- [x] D7: operator accepts `ww3_prep` (ASCII) or directs `ww3_prnc`.
  ✅ ACCEPTED 2026-08-17: `ww3_prep`.
- [x] D8: spectral grid and time-step values are evidence-confirmed exact — no
  operator action needed, listed for completeness.
- [x] D9: operator accepts the wind-only forcings split. ✅ ACCEPTED 2026-08-17.
- [x] D10: operator accepts restart-file chaining (candidate i) as the initial-state
  mechanism, understanding the numeric staleness-gate value is not yet measured.
  ✅ ACCEPTED 2026-08-17.
- [x] D11: operator accepts `WW3_RESTART_MAX_AGE_H = 9` or sets a different value.
  ✅ ACCEPTED 2026-08-17: 9 h.
- [x] D12: operator accepts the file/dir layout, full-run-only cadence, shadow-mode
  key design, and thread/budget numbers as stated. ✅ ACCEPTED 2026-08-17 (with the
  ADR).
- [ ] D13: F5 catalog embedded in full — auditor (Gate DOC-W) confirms no deck line in
  any future Phase W artifact lacks a traceable catalog row (PRIME DIRECTIVE 11).
- [ ] D14: the three known defects are carried into Phase V's validation plan (cliff-KAT
  crash flagged before reattempt; seam AGG caveat resolved by buoy ground truth, not
  assumed; ADR-098 discipline verified for the WW3 bathymetry cut specifically).
- [ ] D15: ADR-108 unchanged and unsuperseded — confirmed no Phase W task touches its
  named frozen-core files.
- [ ] PRIME DIRECTIVE 11 verified: zero product-facing model-setup controls introduced
  by this ADR (the sole write-capable surface is the transition-only shadow-mode key,
  D12).
- [ ] Plain-language standard: every term used in this document is defined at first use
  (see "How to read this document").

## References

- Plan: `docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md` — §WW3 MODEL DESIGN
  v1 (WD1–WD10), §PRE-APPROVAL REGISTER (PW1–PW5), §NAMED CONSTANTS, PRIME DIRECTIVE
  11/12, §OPEN OPERATOR QUESTIONS (Q1/Q4/Q5/Q6), §TASK CHECKLIST (F0–F5, Gate F).
- Research brief: `docs/reference/SWAN-ENERGY-LOSS-RESEARCH-2026-08-15.md` §4 (Option
  E) + §7 (NWPS precedent).
- Phase F reports: `scratch/F1-BUILD-REPORT.md`, `scratch/F2-CONFIG-REPORT.md` (+F2b/
  F2c addenda), `scratch/F3-MARCH-REPORT.md`, `scratch/F4-REPORT.md` (+F4b addendum —
  amplitude-fidelity sections superseded, see next line), `scratch/F5-CATALOG.md`,
  `scratch/SYNTAX-607-VERIFICATION.md`.
- **Buoy validation (2026-08-17): `scratch/F4-BUOY-VALIDATION-REPORT.md`** — the
  corrected-axis-order G1×P1 validation against NDBC 46253/46222; supersedes every
  F4c proxy-KAT number and all F4b amplitude-fidelity evidence (Context "Evidence
  correction" note; corrections in D4, D5, D10, D12, D14 item 2; trap 23).
- ADR-108: big-L1 true-non-stationary domain — the live serving path this ADR does not
  supersede (D15); its `L1_NEST_MAX_AGE_H = 9` is D11's analog precedent.
- ADR-098: bathymetry datum discipline — binds the WW3 leg's own ETOPO cut (D14 item 3).
- ADR-106: per-wet-cell WW3-boundary reconstruction mechanism — unchanged, reused as the
  input to this ADR's boundary-assembly path (D5/D6).
- WW3 manual: `docs/reference/ww3-user-manual-v6.07.txt` (committed at DOC-W.4) — line
  cites throughout D13's catalog, authoritative per D2.
