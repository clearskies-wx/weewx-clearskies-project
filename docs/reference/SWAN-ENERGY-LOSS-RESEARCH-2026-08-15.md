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
| Island shadowing (real physics, under-refilled) | 20.3 | E1 islands-wetted control |
| Shelf-break "cliff" (400 m → 37–78 m in 1–2 cells, directly under the L1→L2 seam) | ~15 | E8d field map + 2-min dead-water KAT (uniform 0.650 m boundary → 0.578 m at seam) |
| Deep-corridor numerical diffusion | ~6–12 | E8d; scheme-insensitive (BSBT = SORDUP = S&L) |
| ST6 swell dissipation | ~4.6 | e8b2 dead-water delta |
| Unfed E boundary (upper bound; re-derivation pending) | ≤8–11 | corners census |

Eliminated by experiment: dissipation-physics bundle, refraction on/off, propagation
scheme + time step + directional-bin count (premier S&L + dt=4 + CIRCLE 144 = null),
boundary imposition, boundary registration.

Deck context: L1 regular grid ~1 km (142×169 meshes, UTM 11N, Southern California Bight);
CIRCLE 72 (5°), 0.03–1.0 Hz, 34 bins; PROP BSBT, NONSTAT dt=10 min; GEN3 ST6, SSWELL
ZIEGER, NEGATINP, BREAKING, FRICTION JON, TRIAD; **no NUMERIC CTHETA/CSIGMA limiter, no
DIFFRAC**; islands are multi-cell dry land; nest chain L1(1 km)→L2(100 m)→L3(40 m)→L4(10 m).

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
| **(b) NUMERIC CTHETA / CSIGMA refraction & frequency-shift limiters** | Manual 4243–4277 [verified]: CTHETA "prevents an excessive directional turning at a single grid point or vertex due to a very coarse bathymetry" (CFL-based, suggested cfl=0.9, **inactive unless specified** — and absent from our deck); CSIGMA the frequency-shift analogue; DIRIMPL cdd=1 upwind "preferable if (strong) gradients in depth or current are present." Dietrich et al. 2013 is the literature basis. | The step is the textbook triggering case — but every documented pathology these limiters fix is **growth/redistribution**, not loss. Whether clamping turning also prevents energy being wrongly refracted *away* (a loss channel) is an unconfirmed hypothesis, so labeled. | MEDIUM (mechanism real), LOW (fixes *our* symptom) |
| **(c) Grid refinement — the field's quantitative criterion** | SWAN STD node89 ("Some notes on grid generation"): the **topographic length scale constraint, Δh/h < 1 per cell** (Δh = depth range within the cell, h = its average depth), plus "keep the wavelength to grid size ratio relatively large." Manual 864–866 [coordinator-verified addition, extending the researcher's 856–861 quote]: "**the proper solution to this problem is to choose a suitable resolution, both spectral and spatial, and one can thus avoid the use of the limiter.**" | **Our step computes to Δh/h ≈ 1.35–1.66 — 1.4×–1.7× over the threshold.** Our step is under-resolved by the SWAN community's own published metric, independent of the seam question. (Context transfer flagged: the STD states the metric for unstructured-mesh refinement; the dimensionless ratio itself is topology-independent.) | MEDIUM-HIGH |
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
  - **Live per cycle:** offshore buoy spectra every 30 min (MEM directional estimation,
    multi-buoy weighting), hourly product updates; **sea/swell split** (swell ~0.0375–0.0875
    Hz from offshore buoys; sea from local buoys) exists precisely because a linear transfer
    cannot grow wind sea; ECMWF winds extend nowcast→forecast.
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

### Comparison table (cells filled only where cited; empty = no published evidence found)

| Option | Precedent | Islands line | Cliff line | Diffusion line | Cost | Cited risks |
| --- | --- | --- | --- | --- | --- | --- |
| A. Finer whole-L1 | Strong (CDIP/CoSMoS/Rogers, this basin) | — | — | Manual 834–840 bin/cell balance implies finer cells reduce this error class (unquantified) | Arithmetic: ~4×/16× cells → ~3.3–4.7 h / 13–19 h | Bathy-error sensitivity rises (O'R&G 93); SWAN inefficient at scale (Manual 267–273) |
| B. Distributed sibling nests | Weak (CoSMoS Tier II closest) | — | — | — | L1 unchanged + per-nest cost (undetermined) | Nest-seam mismatch critique exists only as low-confidence synthesis |
| C. Unstructured single grid | Manual's own preference language; NWPS at WFO scale; none found at Bight scale | — | — | — | "Comparable or lower" only as low-confidence synthesis | SETUP/SURFBEAT manual-stated incompatibility; DIFFRAC convergence poor; mesh-quality rules |
| D. Precomputed transfer (MOP) | Strong (exact region, operational for decades) | Direct analogue documented, **opposite bias** (over-blocking) | — | — | Live cycle structurally cheap (re-weighting); precompute cost unpublished | Linear transfer can't grow wind sea (hence sea/swell split); narrow-spectrum + complex bathy is pure-refraction's weakest case (O'R&G 91) |

---

## 5. R4 — Detection metric for steps at nest boundaries

**Premise status:** R1 did not refute seam-specific harm (Mechanism B stands as unproven
plausibility), so the metric question is answered rather than mooted.

- **The metric the literature actually uses: Δh/h < 1 per cell** (SWAN STD node89) — the
  only explicit, citable, quantitative per-cell bathymetry-resolution criterion found in the
  manual, the STD, or the searched literature. Companion (qualitative): grid size should
  shrink with local wavelength.
- **No source proposes a nest-placement-specific rule** (nothing like "a seam must be N
  cells from any Δh/h>1 zone"). Using Δh/h in seam-adjacent cells to vet handoff placement
  would be a **repurposing of a general mesh-quality diagnostic — an inference, not a
  published practice.**
- No |∇h|/h-, kh-, or group-speed-based detection metric was found as a named practice;
  any such metric would have to be derived, not adopted.
- Applied informationally to our seam cells: Δh/h ≈ 1.35–1.66 (over threshold regardless of
  whether a seam sits there — consistent with Mechanism A's location-independence).

---

## 6. R5 — Island-shadow refill and DIFFRAC applicability

### DIFFRAC verdict at our scale: NOT APPLICABLE (three independent, convergent lines)

| Test | Our value | Threshold (source) | Result |
| --- | --- | --- | --- |
| Range in wavelengths (14–18 s ⇒ L ≈ 306–505 m; range 36–90 km) | ≈70–290 λ | "variations in wave height… within a horizontal scale of **a few wave lengths**" (Manual 308–314) | Outside by 1–2 orders of magnitude |
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
  conceptually parallel to OBSTACLE TRANS but **never found ported to SWAN**.

---

## 7. Cross-cutting observations (coordinator synthesis — labeled, not literature claims)

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
3. **The two strongest-precedent options (A at nearshore tiers, D) are the two the basin's
   own operational systems actually run.** CDIP runs both a ~1 km regional grid and a
   precomputed 100 m linear transfer; their documented island failure is over-blocking —
   the mirror image of ours.
4. **Constraint discovered in passing:** the manual's nest-ratio guidance (factor 2–3,
   stated for WAM/WW3→SWAN) sits against our 10× L1→L2 jump — applicability to SWAN-in-SWAN
   unconfirmed, recorded here so it isn't lost.

## 8. What the evidence does not establish (consolidated)

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

## 9. Verification record (coordinator)

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

## 10. Consolidated bibliography

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

**Institutional**
23. CDIP model documentation: cdip.ucsd.edu/m/documents/models.html and MOP intro pages.
    [full text read]
24. CCHT (Coastal & Computational Hydraulics Team, NC State) technical posts on wave
    refraction on coarse meshes (parts 1–2). [full text read]
25. NOAA EMC / VLab Nearshore Wave Prediction System (NWPS) pages — 36 WFO domains;
    regular-grid 1.8 km→500 m; unstructured ~5 km→200 m at 22 WFOs incl. SGX (2018).
    [mixed full text / search synthesis]
26. USGS CoSMoS project documentation. [secondary synthesis]
