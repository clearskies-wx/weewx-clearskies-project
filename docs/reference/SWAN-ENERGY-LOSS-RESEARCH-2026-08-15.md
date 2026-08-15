# SWAN Energy-Loss Research Brief — 2026-08-15

**Status:** Evidence set for operator ruling. **No recommendation is made or implied in this
document.** Every fix direction touched here (grid resolution, nest placement, deck physics
commands, architecture) is architectural-trigger territory under CLAUDE.md and is the
operator's decision alone.

**Provenance:** Three research agents (`research-depthstep`, `research-grids`,
`research-diffrac`), dispatched 2026-08-15 under operator order that all fix proposals be
grounded in (a) the SWAN User Manual and (b) independent publications/technical reports —
explicitly excluding coordinator/agent conjecture. Source reports:
`RESEARCH-R1R2R4-DEPTHSTEP.md`, `RESEARCH-R3-GRID-ARCHITECTURE.md`,
`RESEARCH-R5-DIFFRACTION.md` (session scratchpad; this brief is the durable compilation).

**Citation conventions:**
- **Manual N–M** = local `docs/reference/swan-user-manual.txt`, by line number. Every manual
  line range quoted in this brief was **independently re-read and verified verbatim by the
  coordinator** (see Verification record, §9).
- **SWAN STD** = official SWAN Scientific/Technical Documentation,
  swanmodel.sourceforge.io (web; theory companion, not committed locally), by node/section.
- Publication access levels: **[full text read]** / **[abstract only]** / **[secondary
  source]** (search-synthesis or third-party description; never treated as first-hand).
  Claims that could not be traced to a fetchable primary source were **dropped by the
  researchers, not cited** — the dropped items are listed in §8.

---

## 1. The evaluation frame — what the evidence is being weighed against

Measured by controlled experiment (2026-08-14/15, experiment record `/tmp/e1e2/` on
librewxr; project-internal, not literature): the production L1 non-stationary march loses
**58.4% of >11 s-band energy between the offshore boundary and the L1→L2 nest seam**,
decomposing as:

| Loss line | Points of the >11 s loss | Established by |
| --- | --- | --- |
| Island shadowing (real physics, but reality refills shadows more than the model does) | 20.3 | Experiment E1: replacing the islands with 800 m-deep water recovered exactly this much |
| Shelf-break "cliff" (depth steps from 400 m to 37–78 m within 1–2 cells, directly under the L1→L2 seam) | ~15 | Experiment E8d's spatial map located it; a 2-minute rerun with wind and every dissipation process switched off still showed it — a uniform 0.650 m swell fed in at the boundary arrives at the seam at only 0.578 m, with nothing physical left to cause the loss |
| Numerical smearing while crossing the deep corridor | ~6–12 | Experiment E8d; identical under all three propagation schemes, so not a scheme-choice problem |
| ST6 wind-physics package slowly eating swell | ~4.6 | Experiment e8b2: the no-wind rerun with physics off recovered this much |
| East side of the boundary not being fed with wave data (upper bound; to be re-derived at the correct hour) | ≤8–11 | Boundary-corner census |

Eliminated by experiment: the dissipation-physics bundle, refraction on/off, and the
numerics themselves — an upgraded run using the higher-order S&L propagation scheme, a
4-minute time step, and doubled directional resolution changed nothing at the seam — plus
how boundary spectra are imposed and how the boundary files are registered.

Model configuration this was measured on: outermost grid (L1) is a regular ~1 km grid of
142×169 cells covering the Southern California Bight. Wave directions resolved in 5° steps
(72 bins), frequencies 0.03–1.0 Hz in 34 bins. First-order BSBT propagation scheme,
10-minute time step, time-marching (non-stationary) run. Full physics on: ST6 wind
growth/dissipation, swell decay, depth-induced breaking, bottom friction, three-wave
interactions. **Not enabled: the refraction-rate limiter (NUMERIC CTHETA/CSIGMA) and
diffraction (DIFFRAC)** — both discussed below. The islands are ordinary dry land many
cells across. Nesting chain: L1 at 1 km hands off to L2 at 100 m, then L3 at 40 m, then
L4 at 10 m.

**No published study measures anything against a loss decomposition shaped like ours** —
the three-line split above is this project's own instrumented finding. Literature findings
below therefore map onto it only qualitatively, and the comparison-table cells that no
citation supports are left explicitly empty.

---

## 2. R1 — Is steep depth-transition loss location-independent, or does the nest seam add distinct error?

**Verdict: PARTIALLY SUBSTANTIATED — two real mechanisms, relative magnitudes unestablished.**

### Mechanism A: interior error at an under-resolved step, wherever it sits — SUBSTANTIATED

- Manual 349–357: refraction limiting "may be relevant when the depth varies considerably
  over one spatial grid step (e.g. at the edge of oceans or near oceanic islands with only
  one or two grid steps to go from oceanic depths to a shallow coast)… the inaccurately
  computed effects may radiate far into the computational area." Generic — any step,
  anywhere in the grid.
- Manual 599–604: "Special care is required in cases with sharp and shallow ridges… and
  extremely steep bottom slopes. Very inaccurate bathymetry can result in very inaccurate
  refraction computations the results of which can propagate into areas where refraction as
  such is not significant."
- Manual 850–854 names the exact feature: "cases with depth varies considerably over one
  spatial grid step, e.g. **at the edge of shelf break** or seamount at deep ocean. As the
  refraction becomes excessive… it is possible that the wave energy focus toward a single
  grid point, creating unrealistically large wave heights and long periods; see Dietrich et
  al. (2013)." (The manual itself cites Dietrich et al. 2013 here.)
- Independent corroboration: Dietrich et al. (2013), *Ocean Modelling* 70:85–102
  [abstract only — ScienceDirect 403×2; sourced via the authors' CCHT lab pages, which were
  read in full]. Documented pathology on under-resolved meshes: spurious energy
  **growth/focusing** at bad vertices (an example reached ~75 m Hs) and spectral
  redistribution into the lowest frequency bin (spurious 30+ s periods).

**Critical sign caveat:** the published pathology is energy **growth**, not loss. The CCHT
material states explicitly that catastrophic energy *loss* is not the observed failure mode
in their cases. No source was found describing an energy-*deficit* outcome of an
under-resolved steep step in SWAN. Mechanism A is confirmed as a phenomenon class at our
exact feature type — it is **not** confirmed as the cause of our measured ~15-point cliff
deficit.

### Mechanism B: seam-specific amplification — PLAUSIBLE INFERENCE ONLY, no direct source

Built from two separately verified manual passages:
- Manual 856–861: with the Courant-type limiter, "the computation is still inaccurate, but
  **less so as you are farther from the location with poor resolution**" — interior error
  attenuates with distance.
- Manual 640–643: a coarse-resolution boundary condition's "coarseness of the boundary
  propagates into the computational grid" — a boundary's error is not locally contained; it
  forces the entire child edge.
- Manual 634–636: water boundaries "must… be chosen sufficiently far away from the area
  where reliable computations are needed," established empirically "by varying the location
  of these boundaries and inspect[ing] the effect on the results." **The manual gives no
  distance rule tied to bathymetry gradient** — only "far enough that it doesn't matter,"
  determined per-case.

The synthesis — a seam sitting on the step promotes the step's corrupted spectra into a
boundary condition that never relaxes — is the researcher's labeled inference. **No source
(manual, STD, or literature) isolates nest-seam placement against bathymetry as a
variable.** Two trade-press-level placement claims ("100 m isobath" convention; "1:2 to
3:5" gradient rules) could not be traced to fetchable primary sources and were dropped.

### What R1 does NOT establish
- Whether relocating the L1→L2 seam off the shelf break would reduce the ~15-point cliff
  loss, or by how much.
- Whether the literature's growth-shaped pathology and our loss-shaped measurement share a
  root cause, are different-signed symptoms of the same under-resolution, or are unrelated.
- Any quantitative seam-distance-from-step vs error relationship.

**Bearing on the operator's prior** ("it's an issue wherever the step sits; moving handoffs
may not really matter"): **supported as far as the evidence goes** — the location-independent
mechanism is the documented one; the seam-specific mechanism remains an unproven
plausibility. Neither substantiates nor refutes seam relocation as a fix.

---

## 3. R2 — Established mitigations for under-resolved steep bathymetry

| Mitigation | What the sources say | Applicability to our 400→37–78 m step in 1–2 cells | Confidence |
| --- | --- | --- | --- |
| **(a) Bathymetry smoothing / pre-filtering** | The manual argues the **opposite** for physically real features: ridges/steps are "vitally important," must be represented, best handled by **aligning grid lines with the feature** — "otherwise the ridge may be 'lost' in the interpolation" (Manual 599–616). The smoothing precedent found is from sigma-coordinate *circulation* models (pressure-gradient error control), a different physics problem [abstract-level only]. | LOW — smoothing a real shelf break changes real shoaling/refraction; the manual's prescription is resolve-or-align, not filter. | LOW |
| **(b) The refraction-rate limiters (NUMERIC CTHETA / CSIGMA)** | These are the "special adjustments" the literature actually offers for steep steps. CTHETA caps how fast the model is allowed to turn wave direction within a single grid cell, so one badly-resolved cell can't swing waves wildly; CSIGMA is the same cap applied to frequency shifting. Manual 4243–4277 [verified]: CTHETA "prevents an excessive directional turning at a single grid point or vertex due to a very coarse bathymetry"; **off unless explicitly switched on — and our deck does not use them.** A related knob (DIRIMPL) selects a more numerically-cautious refraction treatment "preferable if (strong) gradients in depth or current are present." Literature basis: Dietrich et al. 2013. | Our step is the textbook case these limiters were built for — but every documented problem they fix is spurious energy **growth**, not loss. Could capping the turning rate also stop energy being wrongly steered *away* from our corridor (which would look like our loss)? Possibly — but no source says so; that idea is an unconfirmed hypothesis and is labeled as one. | MEDIUM (mechanism real), LOW (fixes *our* symptom) |
| **(c) Grid refinement — the field's quantitative criterion** | The SWAN technical documentation (STD node89, "Some notes on grid generation") gives a pass/fail test for whether a grid cell is too coarse for the seabed under it: **take how much the depth changes within one cell, divide by that cell's average depth — the result must stay below 1.** It also advises keeping cells small compared to the local wavelength. The manual's own bottom line for steep-step trouble (864–866, verified): "**the proper solution to this problem is to choose a suitable resolution, both spectral and spatial, and one can thus avoid the use of the limiter**" — SWAN's authors say the real fix is a finer grid; the limiter is damage control. | **Our shelf break fails that test.** The depth drops from ~400 m to 37–78 m inside 1–2 cells. Depth change ≈ 322–363 m, average depth in those cells ≈ 218–239 m, so the ratio is ≈ 1.35–1.66 — the rule says stay below 1. In plain terms: by SWAN's own published rule, our 1 km grid is too coarse at the shelf break, and that is true whether or not the nest handoff sits there. One caveat: the documentation states this rule in its chapter on triangular computational meshes, and our grid is regular/rectangular — the ratio itself doesn't depend on cell shape, but the borrowing is noted. | MEDIUM-HIGH |
| **(d) Propagation-scheme choice** | Manual 4158–4161: with sharp grid transitions "it is safer to use the BSBT scheme." SWAN STD node38: the higher-order schemes' accuracy case assumes wave-action gradients "often small in coastal areas" — an assumption a grid-scale discontinuity violates for every scheme. | Manual + STD + our own null experiment (BSBT = SORDUP = S&L identical at the seam) triangulate: **scheme choice is not an available mitigation for this loss.** Confirms the deck's BSBT as the "safer" pick. | HIGH (that it doesn't help) |
| **(e) Action-flux conservation theory across abrupt celerity change** | **GAP — not found** as an explicit STD/manual passage or in literature within budget. Closest: the STD's smoothness assumption in (d). | — | Not established |
| **(f) Cross-model corroboration (WW3/MIKE21)** | WW3 nest-transition claims surfaced only as unverifiable search summaries — **dropped, not cited**. MIKE21 not searched (budget). | — | Not established |

**Bearing on the operator's prior** ("there were other adjustments that needed to be made"):
**partially confirmed** — the established adjustments exist (limiters, refinement criterion,
scheme guidance) and were absent from the coordinator's earlier fix list; but none of them is
documented to fix a *loss*-shaped symptom, and the manual's own bottom line for this problem
class is resolution (864–866), with the limiter as containment.

---

## 4. R3 — Grid architecture: compared option set (no choice made)

Five options. A–D vary the grids while keeping SWAN as the outer model; Option E — added
the same day after the operator's WW3 question (full research in §7) — changes which
*model* owns the outer domain. All five are on equal footing for the operator's ruling.

### Option A — Whole-domain finer L1 (1 km → 500/250 m regular)
- **Precedent: STRONG for this basin.** CDIP operational Bight products: ~1000 m regional,
  ~100 m in depths <60 m [full text read, cdip.ucsd.edu]. USGS CoSMoS Tier I (curvilinear
  SWAN, Point Conception→Mexico): 0.5 km offshore → 0.2 km nearshore [secondary source].
  Rogers et al. 2007 (NRL): Bight-scale SWAN outer nest; skill "high in north San Diego
  County and low in the Santa Barbara Channel"; **its exact resolution was not recoverable**
  (PDF unparseable; abstract pages 403) [secondary source].
- **Cost (arithmetic only, no published figure found):** 500 m ≈ 4× cells → ~3.3–4.7 h L1
  march at today's per-cell cost; 250 m ≈ 16× → ~13–19 h. Both far over the current
  operational budget.
- **Cited risks:** O'Reilly & Guza 1993 — finer/diffraction-capable modeling is *more*
  sensitive to bathymetry data error [abstract only]; Manual 267–273 — SWAN is ~an order of
  magnitude less efficient than WAM/WW3 at large scales.
- Notable: none of the three published systems runs 500 m or finer basin-wide across open
  water; their fine tiers are nearshore/targeted (inference from what they did, not a stated
  critique of whole-domain refinement).

### Option B — Distributed L2-class sibling nests around islands/features
- **Precedent: WEAK.** No publication documents island-wake-scoped sibling nests off one
  shared coastal parent. Closest analogues: CoSMoS Tier II (multiple siblings off shared
  Tier I, scoped by littoral cell, not island) [secondary source]; NWPS (36 independent
  per-WFO chains off shared WW3 — siblings by geography, not co-located around one island
  set) [EMC/VLab pages]. A "1 nmi → 10 m focus-area" 3-level NWPS chain claim is
  single-source, low-confidence (3 NWPS PDFs failed extraction).
- **Manual bearing:** NGRID/NESTOUT (4522–4580) states **no limit on pair count but shows no
  multi-nest worked example** — multiplicity is genuinely undetermined ("absence of a stated
  limit is not confirmation of support"). Nest-ratio guidance "spatial and spectral
  resolutions should not differ more than a factor two or three" (Manual 424–435) is stated
  for WAM/WW3→SWAN handoffs — **flagged: our L1→L2 jump is 10× (1 km→100 m)**, though the
  guidance's applicability to SWAN-in-SWAN nesting is not confirmed by the manual.
- **Cost:** L1 unchanged; each sibling adds its own spin-up + march (extent-dependent —
  a design question, out of scope). No published multi-sibling cost figure found.

### Option C — Single unstructured grid, locally refined
- **The manual's own preference language** (259–265, verbatim): unstructured grids "offer a
  good alternative to nested models… the modest effort needed to generate grids about
  complicated geometries, **e.g. islands and irregular shorelines**… highest resolution where
  it is most needed… much fewer grid points than with regular grids."
- **Precedent: WEAK at our scale.** NWPS runs unstructured at 22/36 WFOs including
  SGX/San Diego (since 2018), at WFO/nearshore scale (~5 km→200 m) — **no
  Bight-scale-with-islands-inside-domain unstructured SWAN implementation was found**
  (gap, not a negative finding). The one located structured-vs-unstructured comparison
  (*J. Operational Oceanography* 2016, western Mediterranean) returned 403 — **existence
  known, findings unknown.**
- **Hard constraint for our pipeline:** SETUP "cannot be used in case of unstructured
  grids"; **SURFBEAT "cannot be used for curvilinear or unstructured grids"**
  (commands-extract, manual p.79/81) — and SurfBeat is in active production
  (ARCHITECTURE.md, `services/surfbeat_runner.py`, 3-hourly strip runs). A manual-stated
  incompatibility, not a judgment. (SurfBeat runs on its own 1D-strip grids, not on L1 —
  whether the incompatibility binds depends on which grids would go unstructured; flagged
  as a design-stage question, not resolved here.)
- Mesh-quality constraints: triangles only, 4–10 cells/vertex, angles ≤143° (Manual
  1438–1487, 1612–1661).

### Option D — Precomputed spectral transfer / lookup (the CDIP/MOP precedent)
- **Precedent: STRONG — decades-run, exact-region, closest published analogue to the
  operator's LUT concept.** From CDIP's own documentation [full text read]:
  - **Precomputed once per bathymetry:** a linear spectral-refraction transfer from deep
    water to each nearshore node, built against fixed ~100 m bathymetry — linear physics ⇒
    per-frequency/direction components superpose ⇒ the transformation is computed once and
    reused; it "accounts for island blocking, refraction and shoaling."
  - **Live per cycle:** offshore buoy spectra ingested every 30 min (wave directions
    estimated statistically from the buoy data, several buoys blended), products updated
    hourly; long-period swell is driven by the offshore buoys while shorter local wind
    waves come from nearshore buoys — that split exists precisely because a precomputed
    linear transfer cannot grow wind sea; ECMWF winds extend the nowcast into a forecast.
  - Live cost is a re-weighting of the fixed transfer — structurally cheap per cycle (no
    published CPU figure).
- **Documented failure mode — same mechanism as our islands line, opposite bias:** CDIP's
  docs state the model "assumes almost complete blocking of seas from the south by the
  Channel Islands," underpredicting local seas in the islands' lee. Our measured problem is
  under-attenuation/under-refill; CDIP's is over-blocking.
- Method basis: O'Reilly & Guza 1991 (pure-refraction models "not quantitatively accurate"
  for narrow directional spectra over complex bathymetry; agreement with
  refraction-diffraction models improves as incident directional width increases) and 1993
  (Bight-scale: the diffraction-capable model is *more* bathymetry-error-sensitive;
  refraction solutions "more stable… although not necessarily more accurate") [both
  abstract only — PDFs undecodable]. O'Reilly et al. 2016 (the MOP paper) was not readable
  [403]; the decomposition above is from CDIP's current pages and **may describe a
  later-evolved system than the 2016 paper** (flagged).

### Option E — Replace the outer model: run WAVEWATCH III ourselves, SWAN from L2 down

Full research and verification in §7; summarized here so the option set is complete.

- **What it is:** our own WW3 run takes over today's L1 job (offshore boundary to the
  nearshore handoff); SWAN starts at L2, whose 100 m cells sit comfortably inside SWAN's
  own recommended coastal range of 50–1000 m (Manual 822–832).
- **Precedent: STRONG — this is NOAA's own production architecture.** NWPS runs WW3 for the
  deep/regional water and hands off to SWAN for the 1.8 km–500 m nearshore at every coastal
  forecast office. NOAA's documented WW3 chains never carry WW3 itself to kilometer scale;
  the handoff to SWAN *is* their answer to that scale (§7).
- **What it buys that no grid rearrangement can:** native spherical coordinates (the
  flat-map-projection strain on our large Cartesian L1 disappears — WW3 is built for
  curved-earth domains), and WW3's built-in island obstruction scheme — the field's
  validated treatment for island blocking on coarse grids (Tolman 2003, §6), which no
  SWAN option provides. Neither is evidence it fixes our measured loss lines; both are
  documented capabilities our current outer model lacks.
- **Cost:** genuinely open — the ocean-scale "10× more efficient" claim does not survive at
  1 km; the honest range is parity-to-modest-advantage either way, decidable only by a
  scratch benchmark (§7). The full build toolchain is already on the production host.
- **Cited risks / open plumbing:** boundary spectra must be reconstructed from NOAA's
  public output (the same problem our pipeline already solves for SWAN L1, in a different
  file format); NOAA practice steps resolution 2:1–3:1 per hop, implying our WW3 leg may
  want an intermediate grid rather than one jump from NOAA's tens-of-km output; no
  verified measured runtime for kilometer-scale regional WW3 exists in the literature;
  WW3's stability-unconstrained implicit mode exists only for triangular meshes, not
  regular grids like ours.

### Comparison table (cells filled only where cited; empty = no published evidence found)

| Option | Precedent | Islands line | Cliff line | Diffusion line | Cost | Cited risks |
| --- | --- | --- | --- | --- | --- | --- |
| A. Finer whole-L1 | Strong (CDIP/CoSMoS/Rogers, this basin) | — | — | Manual 834–840 bin/cell balance implies finer cells reduce this error class (unquantified) | Arithmetic: ~4×/16× cells → ~3.3–4.7 h / 13–19 h | Bathy-error sensitivity rises (O'R&G 93); SWAN inefficient at scale (Manual 267–273) |
| B. Distributed sibling nests | Weak (CoSMoS Tier II closest) | — | — | — | L1 unchanged + per-nest cost (undetermined) | Nest-seam mismatch critique exists only as low-confidence synthesis |
| C. Unstructured single grid | Manual's own preference language; NWPS at WFO scale; none found at Bight scale | — | — | — | "Comparable or lower" only as low-confidence synthesis | SETUP/SURFBEAT manual-stated incompatibility; DIFFRAC convergence poor; mesh-quality rules |
| D. Precomputed transfer (MOP) | Strong (exact region, operational for decades) | Direct analogue documented, **opposite bias** (over-blocking) | — | — | Live cycle structurally cheap (re-weighting); precompute cost unpublished | Linear transfer can't grow wind sea (hence sea/swell split); narrow-spectrum + complex bathy is pure-refraction's weakest case (O'R&G 91) |
| E. WW3 outer model, SWAN from L2 (§7) | Strong — NOAA's NWPS production pattern (WW3 deep water → SWAN 1.8 km–500 m nearshore) | WW3's native island obstruction scheme is the field's validated coarse-grid treatment (Tolman 2003) — a capability, not tested against our 20.3-pt line | — | — | Benchmark required: parity-to-modest-advantage band at 1 km (§7); build toolchain already on host | Boundary rebuild from NOAA public output (solved once for SWAN L1, new format); NOAA practice implies an intermediate grid; no measured km-scale WW3 runtime found; WW3's implicit mode is triangular-mesh-only |

---

## 5. R4 — Detection metric for steps at nest boundaries

**Premise status:** R1 did not refute seam-specific harm (Mechanism B stands as unproven
plausibility), so the metric question is answered rather than mooted.

- **The only detection rule the field actually publishes is the depth-change test from
  §3(c):** within one grid cell, the change in depth divided by the average depth must stay
  below 1 (SWAN STD node89). Nothing else quantitative was found in the manual, the
  technical documentation, or the searched literature. Qualitative companion: cells should
  get smaller where the waves get shorter.
- **Nobody publishes a rule about where nest boundaries may sit relative to bathymetry.**
  There is no "keep the seam N cells away from a failing zone" guidance anywhere. If our
  grid-sizing code used the depth-change test to vet handoff placement, that would be our
  own repurposing of a general grid-quality check — reasonable-looking, but not something
  any source actually does.
- The other candidate metrics named in the research brief — ones built on seabed slope, on
  depth relative to wavelength, or on how much the wave speed changes from one cell to the
  next — appear in no source as a named detection practice. Any of those would have to be
  derived from scratch, not adopted from the literature.
- For the record: our seam cells fail the depth-change test (ratio ≈ 1.35–1.66, computed in
  §3c) whether or not a seam sits on them — consistent with the R1 finding that the error
  belongs to the step itself, not to the seam.

---

## 6. R5 — Island-shadow refill and DIFFRAC applicability

### DIFFRAC verdict at our scale: NOT APPLICABLE (three independent, convergent lines)

| Test | Our value | Threshold (source) | Result |
| --- | --- | --- | --- |
| Island-to-seam distance, measured in wavelengths (a 14–18 s swell is 306–505 m long; the islands are 36–90 km away) | ≈70–290 wavelengths | Diffraction matters where wave height changes "within a horizontal scale of **a few wave lengths**" (Manual 308–314) | We are 70–290 where the rule says "a few" |
| Grid at obstacle tip | 1000 m | "1/5 to 1/10 of the dominant wave length" ⇒ 31–101 m (Manual 3893) | 10–30× too coarse |
| Documented scope | open-ocean islands 36–90 km upstream | "near… coastlines… with an occasional obstacle… but not in harbours" (SWAN STD §2.6) | Geometry mismatch — coastal-fringe tool |
| Published precedent at O(1 km) cells / O(100 km) domains | — | — | **None found** (absence after honest multi-angle search, not proof of impossibility) |

Supporting: Manual 3895–3900 — diffraction computations "often converge poorly or not at
all" without under-relaxation (alpha≈0.01, "very limited experience"). Breakwater-scale
validation literature (Enet et al. [summary]; Lin et al. [abstract only]) reports the
diffraction signal itself vanishing as cells coarsen toward the 1/10-wavelength threshold —
at domain scales already 4–5 orders of magnitude smaller than ours.

### What the field says refills island shadows at range

**No literature-stated quantitative refill-distance vs spreading-width relationship was
found** (explicit gap; none was derived, per the round's rules). The closest quantitative
statement: at the shadow-boundary ray itself, wave height is ~50% of incident for
unidirectional regular waves vs "of order 70%" for directionally-spread irregular waves
(Bosboom & Stive, *Coastal Dynamics*, TU Delft open textbook §5.2.4 [full text read]) —
near-field textbook theory, not a range formula.

SoCal-specific precedents (concrete, all flagged with access level):
- **Arthur 1951** (SIO Bulletin, reporting Munk/Burke/Traylor 1944) [secondary — scanned PDF
  not OCR-able]: for westerly waves, San Clemente and Catalina "do not produce a pronounced
  shadow" — penetration into the lee attributed to refraction + diffraction + directional
  variability **jointly**. The earliest on-point precedent already frames refill as
  multi-mechanism.
- **Pawka 1983** (JGR 88(C4):2579–2591) [abstract only, 402-paywalled]: measured at Torrey
  Pines (~100+ km from San Clemente I.): a **deep, persistent directional gap** from the
  island at 0.082–0.114 Hz (T≈8.8–12.2 s) — the shadow is real and **not fully refilled** at
  that range/band. Not in tension with our buoys-see-more-than-model finding (a persistent
  directional gap and partial energy refill coexist); reconciling magnitudes is a model-run
  question.
- **Hsiao, Shemdin & Vesecky 1980** (ICCE Sydney; NASA NTRS) [abstract only]: San Clemente
  field study at T≈7 s: shadow shows "unexpected recovery"; reflection ruled out; attributed
  to **nonlinear energy transfer** from waves traveling parallel to the island. Flagged:
  short-period band, not our 14–18 s.
- **O'Reilly & Guza 1998** [secondary]: island shadowing produces **sharp, persistent**
  alongshore swell-height gradients (varying over <a few km) at Bight scale — the modeling
  lineage for this exact domain treats shadows as persistent features, not smoothed away.
- **Rogers et al. 2007** [secondary — PDF unparseable ×2]: the closest same-region SWAN
  precedent explicitly names "**poor resolution of islands in the Bight** — which have a
  strong impact on nearshore wave climate" as a top named error source, with low skill in
  the Santa Barbara Channel (a lee region). Whether that system used DIFFRAC or OBSTACLE
  for the Channel Islands could not be confirmed (buried in the unreadable Model-setup
  section) — an acknowledged gap.
- **Ponce de León & Guedes Soares 2005** (JGR 110 C09020; Azores — different region,
  flagged) [secondary]: unresolved-island error has "noticeable effects at long distances";
  their fix was **resolution** (a fine nest fully resolving the islands), not diffraction.
- **Björkqvist et al. 2019** (Ocean Science 15) [partial full text]: Baltic archipelago —
  local wind regeneration dominates sheltered-zone energy. Flagged as a different regime,
  and inconsistent with our weak-wind test window (ST6 wind input was active and did not
  close the gap).

### The OBSTACLE alternative

- Manual 3655–3658 [verified verbatim]: the obstacle "is **sub-grid** in the sense that it
  is **narrow compared to the spatial meshes**" — designed for features the grid cannot
  resolve (jetties, breakwaters, narrow reefs). SWAN STD §3.13 (node58): obstacles are line
  features reducing transmitted action between adjacent grid points; no edge diffraction is
  computed by OBSTACLE itself.
- **Our islands are the opposite case** — 20–30 km across, already resolved as multi-cell
  dry land. No published example was found of OBSTACLE representing an already-resolved
  landmass.
- The field's actual coarse-resolution island answer is WW3's **sub-grid obstruction grid**
  (Tolman 2003; Chawla & Tolman, NCEP Tech Note 255) [abstract/secondary] — a gridded
  transmission-coefficient field, validated operationally for *unresolved* islands;
  conceptually parallel to OBSTACLE TRANS but **never found ported to SWAN** — though if
  the outer model *were* WW3 rather than SWAN (§4 Option E, §7), this mechanism comes
  native rather than needing a port.

---

## 7. R6 (added later on 2026-08-15) — Could we run WAVEWATCH III ourselves as the outer model?

Operator question raised after reading §4 and the manual's efficiency statement. Researched
from WW3's own manual, NOAA's own documentation, and the WW3 source code — never inferred
from the SWAN manual (operator correction of an earlier coordinator overreach, applied).
Source report: `RESEARCH-WW3-FEASIBILITY.md` (session scratchpad).

**Availability:** WW3 is free software (LGPL v3), openly distributed on GitHub
(NOAA-EMC/WW3) since v6.07 — buildable on ordinary Linux. A read-only reference clone and
the extracted v5.16 manual text were retained in the session scratchpad. The complete build
toolchain (Fortran compiler, MPI, NetCDF, CMake) is **already installed on librewxr** —
verified by read-only queries; a standard regular-grid build needs nothing installed.

**Nesting practice (WW3's own):** the WW3 manual states *no* numeric resolution-ratio rule
for nesting — boundary spectra are linearly interpolated in space and time at every global
step, "arbitrary resolutions" allowed, up to 9 child nests per run, telescoping unlimited
(manual v5.16 §3.14, App. C). What actual practice shows: NOAA's documented 2007
operational chain stepped 30′ → 10′ → 4′ (roughly 55 → 18.5 → 7.4 km), i.e. **2:1–3:1 per
hop, never a single jump to kilometer scale**. Most decision-relevant: **NOAA's own path
to ~1 km nearshore is not deeper WW3 nesting — it is NWPS, which hands WW3 off to SWAN**
for the 1.8 km–500 m nearshore legs. The architecture the operator is weighing (WW3 outer,
SWAN from L2 down) is NOAA's own production pattern, running today.

**Cost at our scale (the honest answer):** the SWAN manual's "~10× more efficient" claim
is explicitly an *ocean-scale* statement, and it **does not survive at 1 km**. WW3's
explicit schemes are stability-limited: at 1 km cells, our lowest frequency bin (0.03 Hz,
energy moving ~30 m/s) caps its propagation step at ~33 s, vs SWAN's unconditional
10-minute implicit steps. Two facts verified in both the WW3 manual's own words (§3.2,
p.102) and the source code (`model/src/w3pro3md.F90` line 923, coordinator-verified in the
clone): the limit applies **per frequency bin**, so only the ~10 slowest of our 34 bins
need sub-stepping (average multiplier ~1.4–1.5×, not the ~33× a worst-case reading
suggests). Net: over a 72 h march WW3 would perform roughly **1.6–3.3× more
propagation-sweep events** than SWAN's 1,728 implicit sweep-solves — more events, each far
cheaper (an explicit flux update vs an iterative linear solve). The final wall-clock
verdict lands somewhere between rough parity and a modest advantage for either model; the
one term documentation and code cannot supply is the real per-sweep cost ratio on our
hardware. **A scratch benchmark is the named blocker — nothing short of running it decides
this.** (One measured-looking figure from an AI search summary was checked against its own
cited source, found absent, and dropped.) Side finding: WW3 does have an implicit solver
with no stability limit, but only for unstructured triangular meshes, not regular grids.

**What this changes and doesn't:** the *efficiency* argument for a WW3 swap at 1 km is
weak-to-neutral pending benchmark. The arguments independent of cost stand as researched
facts: spherical coordinates natively (removing the flat-projection strain on the large
outer domain), WW3's native sub-grid island obstruction scheme (the field's standard
answer for island blocking, §6), deep-water swell physics as its design center, and NOAA's
own validation of the exact architectural split. Where the WW3-to-SWAN handoff would sit,
and at what resolutions each side runs, are design questions the operator rules on —
NOAA's own practice (WW3 at coarser regional scale, SWAN owning the fine nearshore) is the
published precedent for that layout.

## 8. Cross-cutting observations (coordinator synthesis — labeled, not literature claims)

1. **Resolution is the through-line of the evidence.** Independently: the manual's own
   bottom line for steep-step error is "choose a suitable resolution" (864–866); the STD's
   Δh/h<1 criterion flags our step at 1.35–1.66; DIFFRAC's own applicability demands 31–101 m
   cells near obstacles; Ponce de León & Soares fixed island sheltering by resolving the
   islands; Rogers et al. name island resolution as their leading error source; every
   published fine tier in this basin (CDIP 100 m, CoSMoS 200 m) is targeted/nearshore rather
   than basin-wide. The evidence repeatedly points at *where resolution is spent*, which is
   exactly the operator's R3 question — and the option set in §4 is the operator's to rule on.
2. **The sign gap is real and unresolved.** The entire published steep-step pathology
   literature describes energy growth/misdirection; our cliff is a deficit. No published
   account matches our loss-shaped symptom. Any fix premised on the published mechanism
   (e.g. limiters) rests on an unverified mapping to our symptom.
3. **The strongest-precedent options (A at nearshore tiers, D, and E) are the ones the
   region's own operational systems actually run.** CDIP runs both a ~1 km regional grid
   and a precomputed 100 m linear transfer (their documented island failure is
   over-blocking — the mirror image of ours), and NOAA's NWPS runs the Option-E split
   (WW3 deep water, SWAN nearshore) at every coastal forecast office. Nobody found in the
   published record does what our current architecture does — carry SWAN alone from the
   open ocean boundary down to the surf zone at this domain size.
4. **Constraint discovered in passing:** the manual's nest-ratio guidance (factor 2–3,
   stated for WAM/WW3→SWAN) sits against our 10× L1→L2 jump — applicability to SWAN-in-SWAN
   unconfirmed, recorded here so it isn't lost.

## 9. What the evidence does not establish (consolidated)

- Whether seam relocation off the shelf break helps at all, or how much (R1 — the central
  open question going in remains open; no study isolates the variable).
- The cause-of-loss identity between published growth-pathology and our measured deficit (R1/R2).
- Any action-flux-conservation error theory for a 1–2-cell celerity step (R2e — gap).
- WW3/MIKE21 corroboration (R2f — unverifiable summaries dropped; MIKE21 unsearched).
- Rogers et al. 2007's exact grid resolutions and island-handling method (PDF unreadable —
  a human with OCR could recover this; the single most valuable unread source).
- Quantitative accuracy statistics from O'Reilly & Guza 1991/1993; the 2016 MOP paper's own
  text (all paywalled/undecodable; CDIP institutional pages used instead, possible version
  mismatch flagged).
- Whether SWAN supports multiple NGRID/NESTOUT pairs per run in practice (no prohibition,
  no worked example) (R3-B).
- Any Bight-scale unstructured SWAN precedent; the Mediterranean nested-vs-unstructured
  comparison's findings (403) (R3-C).
- A refill-distance-vs-spreading formula (R5 — the field treats shadow recovery as
  case-specific/model-derived).
- Dropped as untraceable: "100 m isobath" seam-placement convention; "1:2–3:5" gradient
  rules; WW3 nest-transition claims; NWPS "1 nmi→10 m" 3-level chain (single-source,
  low-confidence, retained only as a lead).

Added with §7 (WW3 round): the real per-sweep cost ratio (WW3 explicit update vs SWAN
implicit solve) on our hardware — benchmark required; the resolution table of NOAA's
2013–2019 nine-grid mosaic (paywalled); NWPS's exact WW3-side handoff resolution; any
measured kilometer-scale regional WW3 runtime (none found that survived source-checking).

## 10. Verification record (coordinator)

- **Manual line cites:** all quoted ranges independently re-read verbatim by the coordinator
  against the local manual — 227–241, 243–246, 259–265, 267–273, 305–314, 349–357, 599–616,
  634–643, 822–840, 850–866, 3655–3658, 3887–3900, 4243–4277, plus 4158–4169 (previously
  verified during A1 gate F2). No misquote found in any report.
- **Arithmetic re-derived:** deep-water wavelengths (L=1.56T²: 306/505 m at 14/18 s), range
  in wavelengths (70–290), DIFFRAC cell requirement (31–101 m), Δh/h (1.35–1.66), option-A
  cost multipliers (4×/16× → 3.3–4.7 h / 13–19 h from the measured 50–70 min march).
- **Production claims:** SurfBeat active production use confirmed (ARCHITECTURE.md SurfBeat
  strip section; `services/surfbeat_runner.py`); SETUP/SURFBEAT unstructured-grid
  restrictions confirmed in the frozen commands extract.
- **Web sources:** verified to the researchers' declared access levels; the coordinator did
  not independently re-fetch web sources. The manual's own citation of "Dietrich et al.
  (2013)" at line 854 independently corroborates that publication's identity.

For §7 (WW3 round) the coordinator additionally verified: the `NTLOC` sub-stepping formula
at `model/src/w3pro3md.F90` line 923 in the scratchpad clone (matches the report exactly,
inside a per-spectral-component routine); the SWAN SIP-solver defaults (max 20 iterations,
1e-4 tolerance) at local manual lines 4278–4294; and re-derived the full cost arithmetic
(group velocity 26.0 m/s at 0.03 Hz, 33.4 s critical step, 1,933–3,870 global steps,
1.6–3.3× sweep-event ratio).

## 11. Consolidated bibliography

**Official SWAN documentation**
1. SWAN User Manual — local, `docs/reference/swan-user-manual.txt` (authoritative for all
   command behavior; cited by line throughout). [full text, committed]
2. SWAN commands extract — local, `docs/reference/swan-commands-extract.md` (frozen syntax
   extract). [full text, committed]
3. SWAN Scientific/Technical Documentation, swanmodel.sourceforge.io — §2.6 Diffraction
   (node29), geographic discretization (node38), §3.13 obstacles (node58), grid-generation
   notes incl. Δh/h<1 (node89). [full text via WebFetch]

**Peer-reviewed**
4. Dietrich J.C. et al. (2013). Limiters for spectral propagation velocities in SWAN.
   *Ocean Modelling* 70:85–102. doi:10.1016/j.ocemod.2012.11.005. [abstract only;
   supplemented by the authors' CCHT pages, full text read]
5. Rogers W.E., Kaihatu J.M., Hsu L., Jensen R.E., Dykes J.D., Holland K.T. (2007).
   Forecasting and hindcasting waves with the SWAN model in the Southern California Bight.
   *Coastal Engineering* 54(1):1–15. [secondary source — PDF located but unparseable ×2;
   abstract pages 403]
6. O'Reilly W.C., Guza R.T. (1991). Comparison of spectral refraction and
   refraction-diffraction wave models. *J. Waterway, Port, Coastal, Ocean Eng.*
   117(3):199–215. [abstract only]
7. O'Reilly W.C., Guza R.T. (1993). A comparison of two spectral wave models in the
   Southern California Bight. *Coastal Engineering* 19:263–282. [abstract only]
8. O'Reilly W.C., Guza R.T. (1998). Bight-scale spectral refraction + refraction-diffraction
   swell modeling (operational precursor to MOP). [secondary source]
9. O'Reilly W.C. et al. (2016). The California coastal wave monitoring and prediction
   system. *Coastal Engineering* 116:118–132. [existence/abstract only — 403; system detail
   taken from CDIP institutional pages instead]
10. Pawka S.S. (1983). Island shadows in wave directional spectra. *JGR Oceans*
    88(C4):2579–2591. [abstract only — 402]
11. Hsiao S.V., Shemdin O.H., Vesecky J.F. (1980). An investigation of wave sheltering by
    islands. ICCE Sydney; NASA NTRS 19820043045. [abstract only]
12. Arthur R.S. (1951). The effect of islands on surface waves. SIO Bulletin, UCSD
    (reporting Munk, Burke & Traylor 1944 observations). [secondary — scanned PDF, no OCR]
13. Ponce de León S., Guedes Soares C. (2005). On the sheltering effect of islands in ocean
    wave models. *JGR* 110:C09020. [abstract/secondary]
14. Björkqvist J.-V. et al. (2019). The wave spectrum in archipelagos. *Ocean Science*
    15:1469–1483. [partial full text]
15. Björkqvist J.-V. et al. (2019). WAM/SWAN/WW3 comparison, Finnish archipelago.
    *J. Operational Oceanography*. [abstract only — 403]
16. Barnard P.L. et al. (2014). CoSMoS (Coastal Storm Modeling System). *Natural Hazards*
    74(2):1095–1125, plus CoSMoS 3.0 Southern California documentation. [secondary — login
    wall / PDF undecodable]
17. Tolman H.L. (2003). Treatment of unresolved islands and ice in wind wave models
    (WW3 sub-grid obstruction); with Chawla A. & Tolman H.L., NCEP MMAB Tech Note 255.
    [abstract/secondary]
18. Enet F. et al. SWAN diffraction validation, 9th Intl. Workshop on Wave Hindcasting &
    Forecasting (waveworkshop.org). [summary via search synthesis]
19. Lin et al. An improvement of wave refraction-diffraction effect in SWAN. [abstract only]
20. Holthuijsen L.H., Herman A., Booij N. (2003). Phase-decoupled refraction-diffraction
    for spectral wave models. *Coastal Engineering* 49:291–305. [NOT read this round —
    listed because it is DIFFRAC's origin paper, named in the SWAN docs; its claims are
    represented here only through the manual/STD, not first-hand]
21. Bosboom J., Stive M.J.F. *Coastal Dynamics* (TU Delft Open) §5.2.4 Diffraction.
    [full text read]
22. Anonymous/unread: Comparison between nested grids and unstructured grids for a
    high-resolution wave forecasting system in the western Mediterranean sea.
    *J. Operational Oceanography* (2016). [title/existence only — 403; findings unknown]

**WW3 round (§7)**
27. WAVEWATCH III User Manual v5.16 — NOAA-hosted PDF
    (polar.ncep.noaa.gov/waves/wavewatch/manual.v5.16.pdf), §3.2, §3.14, App. B–C.
    [full text read via pdftotext extraction; text copy retained in session scratchpad]
28. WW3 source code — github.com/NOAA-EMC/WW3 (LGPL v3), read-only clone;
    `model/src/w3pro3md.F90` (explicit propagation, per-bin sub-stepping),
    `model/src/w3profsmd_pdlib.F90` (unstructured-only implicit), `model/src/w3srcemd.F90`
    (source-term integrator). [full text read; line-cited]
29. NCEP Technical Implementation Notice 07-51 — the 2007 operational WW3 grid chain
    (30′/10′/4′), polar.ncep.noaa.gov/waves/implementations.shtml. [full text read]
30. Tolman H.L. et al. (2013). A multigrid wave forecasting model. *Weather and
    Forecasting* 28(4). doi:10.1175/WAF-D-12-00007.1. [abstract only — paywalled]
31. NOAA NWPS announcements/abstracts — weather.gov/news/212901-nwps; AMS 93rd Annual
    Meeting Paper 222877 (Van der Westhuysen et al.). [secondary/summary level]
32. Coastal application of unstructured WAVEWATCH III in swell-dominated waters.
    *Frontiers in Marine Science* (2026), doi:10.3389/fmars.2026.1877867 — real-world
    explicit-vs-implicit WW3 time-step choices (12/4/6 s explicit vs 150 s implicit).
    [full text read]

**Institutional**
23. CDIP model documentation: cdip.ucsd.edu/m/documents/models.html and MOP intro pages.
    [full text read]
24. CCHT (Coastal & Computational Hydraulics Team, NC State) technical posts on wave
    refraction on coarse meshes (parts 1–2). [full text read]
25. NOAA EMC / VLab Nearshore Wave Prediction System (NWPS) pages — 36 WFO domains;
    regular-grid 1.8 km→500 m; unstructured ~5 km→200 m at 22 WFOs incl. SGX (2018).
    [mixed full text / search synthesis]
26. USGS CoSMoS project documentation. [secondary synthesis]
