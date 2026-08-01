# SWAN OBSTACLE Representation of Coastal Structures — Third-Party Best-Practice Findings (2026-07-29)

**Provenance:** research agent, third-party literature only (SWAN's own command mechanics taken as given
from the local manual, not re-cited). Synthesizes peer-reviewed papers, government technical reports,
community references, and forums. Items not grounded in a source are labeled **[synthesis]**; contested
items flagged. Feeds Track B (Phase 4) of `docs/planning/MARINE-WORKING-MODEL-PLAN.md`.

**One subtlety that governs everything — read first.** SWAN's transmission coefficient `Kt` is a
**wave-HEIGHT ratio** (`Kt = H_lee / H_incident`), per the Sandia SNL-SWAN manual Eq. 2 [2]. Most lab/field
"blocking / absorption" numbers are **ENERGY (power) ratios** (`Kt² = P_lee/P_incident`). **Square-root an
energy-blocking figure before entering it as a SWAN `Kt`.** E.g. "45% energy blocking" → `Kt² = 0.55` →
**`Kt = 0.74`**, not 0.55.

---

## Decision rule: sub-grid line vs bathymetry footprint

**Mechanism:** SWAN applies `Kt` to the action-density flux from one grid vertex to a neighbour **iff** the
connecting grid link is crossed by the obstacle line [2]. Consequences:
1. **A line carries no width.** SNL-SWAN Fig. 6: two obstacles of *very different widths* crossing the
   *same* grid link produce **identical** model effect. Width is invisible to a line obstacle [2].
2. **Too-short obstacles vanish/alias.** A line crossing *no* grid link has **no effect at all**, even if
   physically larger than a short one that does cross [2]. Must span multiple links.
3. **Appropriate use = grid much finer than obstacle length.**

**Threshold (width ÷ Δx):** no single published numeric constant — guidance is qualitative ("narrow vs
grid"). Practical dividing line **width/Δx ≈ 1** [synthesis, grounded in 2]:
- **width < ~1 cell → sub-grid OBSTACLE line.** Normal nearshore case at 10 m (L4) for seawalls,
  sheet-pile walls, groins, thin jetties, pile rows, narrow breakwaters. The line is the along-structure
  trace; thickness handled by `Kt`/`Kr`, not geometry.
- **footprint spans ≥2–3 cells → resolve in the BATHYMETRY** (dry/shallow-emergent cells) so waves
  refract/diffract *around* it. Preferred when the lee wave field (shadow, gap diffraction) is the target.

| Approach | Strengths | Pitfalls |
|---|---|---|
| Sub-grid line | cheap; direct `Kt`/`Kr`; supports DAM; only option for sub-cell structures | no width [2]; silently no-ops if too short/misaligned [2]; reflection needs wet-both-sides + CIRCLE; tip diffraction imperfect [5] |
| Bathymetry footprint | correct diffraction/refraction around body + gaps; handles width & taper; captures scour/shoal | needs footprint resolved by several cells → grid cost; still needs diffraction on; no partial transmission |

OSM parallel: *"Groynes are very thin → single line; breakwaters are pretty thick → area"* [8].

---

## Coefficients by structure type (Kt = HEIGHT ratio, SWAN convention)

| Structure | `Kt` (height) | `Kr` | Source / notes |
|---|---|---|---|
| **Pile-supported pier** (Duck FRF: 1 m dia, ~12.2 m spacing, 500 m) | **≈0.71–0.84**, best-fit **0.74** (45% energy blocking); strongly **directional** — only oblique rays under the deck attenuate | small, often neglected | Elgar et al. 2001 [1]. Blocking higher than pile theory predicts (rough/barnacled piles). **CONTESTED** vs [10]. |
| Closely-spaced pile / slotted breakwater | ~0.3–0.9, more blocking as porosity ↓ | rises as porosity ↓ | Truitt & Herbich 1986 [12] |
| **Rubble-mound breakwater — emergent** (`Rc≫Hi`) | **≈0** | **0.2–0.3** | [7],[9] |
| Rubble-mound — low-crested/submerged | 0.075–0.8 via DAM DANGREMOND | ~0.1–0.4 | d'Angremond 1996 [3]; van der Meer 2005 [4] |
| **Vertical/impermeable seawall, sheet-pile — emergent** | **≈0** | **0.7–1.0, ~0.9** (smooth vertical, use RSPEC) | [9]; Seelig-Ahrens smooth-imperm A=1.0,B=5.5 [7] |
| Jetty — impermeable emergent | ≈0 | 0.7–1.0 (rubble-armored: 0.2–0.4) | [10-ctx] |
| Groin — impermeable emergent | ≈0 | rubble 0.2–0.4 (RDIFF); vertical 0.7–1.0 (RSPEC) | [Bodge] |

**Reflection formula (default when no measurement):** Seelig & Ahrens (1981) [7]:
`Kr = A·ξ²/(ξ²+B)`, ξ = tanα/√(H/L); smooth-impermeable **A=1.0, B=5.5**; rough-permeable **A=0.6, B=6.6**.

**CONTESTED — pier shadow mechanism:** Elgar [1] needed ~45% pile blocking (`Kt≈0.74`) to match the
observed alongshore Hs gradient; a SWAN-vs-CGWAVE Duck study [10] attributes the shadow mainly to the
**scour trench**, piles minor. Likely: trench dominates far-field refraction; piles dominate the near
shadow under oblique incidence. **Design read: model the scour/shoal in bathymetry if available, treat the
pile row as a modest directional `Kt≈0.75` line — the deck itself blocks little.**

---

## DAM / height-dependent transmission

- **d'Angremond / Van der Meer (1996)** = `DAM DANGREMOND`, for impermeable-rough low-crested rubble mounds:
  `Kt = -0.4·(Rc/Hi) + c2·(Gc/Hi)^-0.31·[1 - exp(-0.5·ξ)]`, c2=0.80 impermeable / 0.64 permeable; valid
  `0.075 < Kt < 0.8`. Wide-crest correction (Briganti 2004) for `Gc/Hi>10`. Lowest RMSE; best general
  choice for rubble LCS [3][4].
- **GODA/Seelig (1979)** = `DAM GODA`, smoother sharp-crested overtopped dams, slopes gentler than ~55°.
- **When DAM beats a constant:** freeboard varies with **tide/surge** over a **low-crested/submerged**
  crest (`Kt` swings emergent≈0 → awash 0.6–0.8). For **tall always-emergent** structures, constant
  `Kt≈0` is fine and DAM adds nothing.
- Both are **frequency- and direction-blind** (scale energy, preserve shape; obliquity is an assumption).

---

## Geometry best-practices checklist
- Fewest corner points (extra vertices under-reflect — the coefficient acts per crossed link [2]).
- Line must span multiple grid links (else no-op [2]) — verify intersection.
- Avoid sharp angles / self-near-crossings (double-counted reflection).
- Wet points both sides (a line on the land boundary won't reflect [16]).
- Reflection needs `CGRID CIRCLE` (360°) and `REFL` set (default 0). RSPEC smooth, RDIFF rubble.
- Broken-obstacle symptom: uniform/unphysical downwave field → suspect geometry/placement [17].

---

## Width / thickness (incl. tapered)
- **Bathymetry footprint = the only true-width method** (rasterize planform → dry/shallow cells) [2][3][15].
- **Two parallel lines** (up/down-wave faces, spaced by real width) — **[synthesis, untested]**; only helps
  if spacing exceeds ~1 cell.
- **Closed ring** for a detached/isolated structure.
- **Tapered / variable-width [synthesis]:** (a) **vary `Kt`/`Kr` per segment** — several consecutive
  OBSTACLE commands, higher `Kt` at the narrow/low end; (b) **DAM with per-segment crest height `Rc`** so
  `Kt` rises naturally along the taper; (c) **bathymetry footprint** when the plan shape steers refraction.
  SNL-SWAN precedent: coefficient carries the structure, geometry does not [2].

---

## Diffraction
- SWAN reproduces semi-infinite-breakwater diffraction reasonably (matches Sommerfeld) via its
  phase-decoupled approximation [5].
- **Matters most for narrow directional spectra (spreading ≲15°)** — long-period narrow-spread swell in a
  lee is exactly the case that needs it; broad wind-sea fills the shadow by spreading alone [5].
- Weakest right behind a tip (unhandled head singularity) [5]. Rigorous diffraction wants grid < λ/10
  (~5 pts/λ practical); at 10 m this resolves λ ≳ 50–100 m [11].
- **Pier:** alongshore gradient dominated by refraction over scour + directional pile blocking, not tip
  diffraction (trench diffraction/reflection <5%) [1].

---

## GIS/OSM → SWAN obstacle conversion
No turnkey pipeline; assembled from GIS primitives [8]:
1. OSM by tag: `man_made=breakwater` (way/area), `man_made=groyne` (line), `man_made=pier` (way/area;
   `man_made=jetty` deprecated). The tags encode line-vs-area.
2. Reduce areas to a line: centerline/skeleton (Voronoi; `label_centerlines`, `centerline` pkg) or oriented
   min-bounding-box long axis (Shapely/GeoPandas); `geom.boundary` for polygon→line.
3. Simplify (Douglas–Peucker / `shapely.simplify`) to fewest corners.
4. Line vs footprint by width/Δx: thin → OBSTACLE polyline; wide → rasterize polygon to bathymetry
   (`rasterio.features.rasterize`).
5. Assign coefficients by OSM class; emit `OBSTACLE … LINE …` or `DAM …`.
6. Glue: `swantools`, MHKiT-SWAN. Coefficient assignment + line-vs-footprint remain engineering calls.

---

## Validation
- **Alongshore Hs gradient in the shadow** = highest-value diagnostic: modeled vs observed energy ratio
  between a near-structure station and a same-depth control ~200 m away, binned by incident direction [1].
- **Coefficient sensitivity sweep** (Elgar ran 0/30/45/60% blocking → 45% best fit) — report sensitivity,
  not just best fit [1].
- **Direction, not just height** — blocking shifts mean direction toward normal in the shadow [1].
- Buoy/pressure pairs straddling the structure; Sommerfeld analytical check [5]; cross-model vs CGWAVE [10].

---

## Tips & pitfalls
1. Square-root energy numbers before using as `Kt` [2]. 2. A line has no width — if width matters, go to
bathymetry [2]. 3. Obstacles can silently no-op (bad alignment/too short) [2]. 4. Reflection needs
wet-both-sides + CIRCLE + REFL set; RSPEC smooth, RDIFF rubble [16]. 5. Broken-obstacle symptom = uniform
downwave field [17]. 6. Fewest corners. 7. Don't over-refine (violates ≤1-bin-per-cell guidance [15]).
8. Diffraction is spread-gated; weakest behind a tip [5][11]. 9. Transmission is direction/shape-blind.
10. For piers, the scour trench often matters as much as the piles — trench in bathymetry, pile row
`Kt≈0.75` [1]. 11. Out-of-range interpolated inputs → `Kt=1.0` (no blocking), a quiet way to lose a
structure [2].

---

## Sources
1. Elgar et al. (2001), *Wave Energy and Direction Observed Near a Pier*, J. Waterway Port Coastal Ocean Eng. 127(1):2–6. https://www.whoi.edu/science/AOPE/dept/Publications/066_2.pdf — [authoritative, full text].
2. Ruehl, Chartrand, Porter (2014), *SNL-SWAN User's Manual v1.0*, SAND2014-20185R, Sandia. https://www.osti.gov/servlets/purl/1173189 — [authoritative, full text] (Kt=height ratio; Fig.6 width-invariance).
3. Coastal Wiki, *Wave transmission by low-crested breakwaters*. https://www.coastalwiki.org/wiki/Wave_set-up_and_wave_transmission_by_low-crested_breakwaters — [reference] (d'Angremond coefficients).
4. van der Meer et al. (2005), Coastal Engineering 52:915–929. https://data-ww3.ifremer.fr/BIB/vanderMeer_etal_CE2005.pdf — [authoritative] (DELOS).
5. Enet et al. (2006), *Diffraction Behind a Semi-Infinite Breakwater in SWAN*. http://www.waveworkshop.org/9thWaves/Papers/Enet.pdf — [paper].
6. Booij, Holthuijsen, Bénit — phase-decoupled refraction–diffraction. https://www.researchgate.net/publication/202038696 — [paper].
7. Seelig & Ahrens (1981), *Estimation of Wave Reflection and Energy Dissipation Coefficients*, CERC — [authoritative] (Kr formula).
8. OSM Wiki tag pages breakwater/groyne/pier/jetty — [community] (thin→line, thick→area).
9. *Reflection Coefficient for Seawalls Protected by a Rubble Mound*, JMSE 9(9):937 (2021). https://doi.org/10.3390/jmse9090937 — [peer-reviewed] (vertical wall Kr≈0.9).
10. *Simulation of Waves at Duck (NC) Using Two Numerical Models*, Coastal Eng. J. 45(3) (2003). https://www.tandfonline.com/doi/abs/10.1142/S0578563403000853 — [peer-reviewed; CONTESTED vs 1].
11. *Improving SWAN Modelling to Simulate Diffraction Behind Structures*, J. Coastal Res. SI79 (2017). https://bioone.org/journals/journal-of-coastal-research/volume-79/issue-sp1/SI79-071.1/ — [peer-reviewed].
12. Truitt & Herbich (1986), pile-breakwater transmission/reflection, ICCE. https://icce-ojs-tamu.tdl.org/icce/article/view/4170 — [peer-reviewed conf].
13. Coastal Wiki, *Detached breakwaters*. https://www.coastalwiki.org/wiki/Detached_breakwaters — [reference].
14. *Wave energy transmission through/over low crested breakwaters* (ResearchGate 275041924) — [paper].
15. *Review of hydrodynamic investigations into arrays of WECs*, arXiv:1508.00866 — [paper].
16. myROMS — *WET&DRY in SWAN?* https://www.myroms.org/forum/viewtopic.php?t=2900 — [forum].
17. SWAN users list — *Trouble applying an obstacle*. https://sourceforge.net/p/swanmodel/mailman/message/36729514/ — [forum].

## Open / contested
- Pier shadow: pile dissipation [1] vs scour trench [10] — resolve with site data if a pier is in scope.
- No published numeric width/Δx threshold — the ≈1 line is synthesis.
- "Two parallel lines" for width — untested approximation.
- Oblique-attack transmission — stock DAM assumes direction independence.
- Tapered-structure best practice — synthesis, no dedicated study located.

---

## ADDENDUM (2026-08-01, Phase R doc-sync pass) — L4 sizing design adopted; shadow-decay research

**Adopted: the L4 grid sizing rewrite (marine `4e79d21`, ADR-093 Amendment 6).** `compute_structure_grid_domain()`
now sizes L4 from a beach-frame transect-shadow envelope (rotation = resolved beach facing; extent = every
eligible structure's footprint UNION the handoff points of every transect it shadows) instead of an
obstacle-OMBB axis. This brief's own obstacle-representation content above (TRANSM/REFL coefficients, line-vs-
footprint fork, the tips/pitfalls list, the sources) is **unaffected** — this addendum concerns L4's *extent and
orientation*, not how a structure is represented once it is inside the grid. See PROVIDER-MANUAL.md §14.15 and
ADR-093 Amendment 6 for the full sizing design.

**Sourced findings on structure-shadow decay distance (from the prior research session, relevant to how far
downwave a shadow — and therefore a shadow-derived grid envelope — should extend):**
- SWAN's own diffraction is only meaningful within about 1–2 wavelengths of an obstacle tip (SWAN technical
  documentation, obstacles chapter).
- Classical coastal-engineering practice terminates diffraction-shadow diagrams at roughly 20 wavelengths (CEM /
  ICCE diffraction diagrams).
- At the Duck, NC FRF pier, the measured shadow is strong to about 200 m downwave and largely healed by about
  400 m (Elgar et al. 2001 — already source [1] above).
- Depth-limited breaking and bottom friction both act to dissipate a structure's shadow through the shallows,
  independent of the diffraction mechanism itself.

These findings inform how far downwave a shadow-derived grid extent is physically justified; they are cited here
as research inputs, not as a new pinned constant — the actual L4 shoreward/seaward edges are computed per
ADR-093 Amendment 6's formula, not from a fixed wavelength multiple.
