# L3 / 1D Model Boundary Decisions — Decision Brief

**Created:** 2026-07-25
**Status:** DRAFT FOR USER DECISION — no code or governing-doc changes made
**Purpose:** Identify every boundary decision the 1D-model introduction implied but never
settled, and evaluate each against published coastal-engineering practice.
**Scope:** Architecture only. This brief does not audit what was implemented — that is
`MARINE-SERVICE-SEPARATION-PLAN.md` T4A.3.0.

---

## 1. Document lineage — how the boundaries got where they are

### Era 1 — SWAN-only (SWAN-NESTING-RESEARCH-BRIEF, original ADR-093)

Three nested grids, all running to shore:

| Level | Resolution | Cross-shore extent | Basis |
|---|---|---|---|
| L1 | 1 km | GSFM shelf edge → shore | Shelf wave propagation |
| L2 | 100 m | shore → 30 m depth | Bridge coarse→fine |
| L3 | 10 m | shore → 15 m depth | See below |

**Why 15 m was chosen for L3** (SWAN-NESTING-RESEARCH-BRIEF lines 212–224, "DECIDED"):

| Source | Finding |
|---|---|
| Hallermeier (1981) depth of closure, SoCal climate | h_in ≈ 8–9 m |
| Ludka et al. (2019), 16 yr San Diego surveys | Active morphological zone: shore → 8 m |
| Coastal Wiki, Egmond outer bar decay | Outer bar decays at 8 m |
| Standard SWAN surf-zone boundary practice | 10–30 m |
| XBeach Holland tutorial | 20 m |

Verbatim conclusion: *"We use 15m: safely beyond the depth of closure (8-9m), provides
full beach profile context, and aligns with the mid-range of published practice."*

**This is the critical fact.** The 15 m number was derived from *depth of closure* — the
depth beyond which the sand profile stops changing. That criterion sizes a grid whose job
is **to contain the entire active beach profile**. It is the right criterion for a grid
that models the profile all the way to shore.

### Era 2 — 1D model introduced as an enhancement (SURF-ZONE-MODEL-BRIEF, 2026-07-20)

SWAN was found to give wave *energy statistics*, not wave *shape* — no crest/trough, no
breaker type, no sub-grid break point. SwellTrack (analytical 1D cross-shore model) and
the SurfBeat strip were added to supply those.

But the brief's own v1 recommendation kept L3 unchanged:

- §4: *"SWAN L3 runs to shore (current architecture, no changes)."*
- §9 Option 1: *"Keep L3 to shore + add 1D post-processing. Zero risk. **This is the v1
  approach.**"*
- §9 Option 3: *"Truncate L3 at handoff depth. Loses all nearshore structure interaction.
  **Not recommended** for structure-affected spots."*

The handoff was a *sampling depth inside a full-depth L3 grid*, not a grid boundary
(§2.3.4): 10 m default, `shallowest_structure_depth − 1.5 m` for shadowed transects,
floor 5 m, ceiling 15 m. The ceiling's own code comment reads `# Never deeper than L3
offshore boundary` — it is a clamp anchored to L3's Era 1 extent, not an independent
physical criterion.

### Era 3 — L3 becomes optional and smart-sized (ADR-093 Amendment 1, 2026-07-21)

Two changes:

1. **L3 is optional per location.** Structures found → L3 on. No structures → L3 skipped
   entirely, handoff spectrum taken from L2 at ~15 m.
2. **When enabled, L3 is smart-sized around the structure cluster** — structure positions
   + shadow-zone extent (structure length + 2× length downstream) + 100 m pad. *"A single
   pier on a 1km beach produces a ~500m L3 grid, not a 1km+ grid."*

**Read that example carefully: 500 m is an ALONGSHORE number.** Amendment 1 shrank L3
*along the beach* and made it *conditional*. It says nothing about L3's cross-shore
extent. The seaward edge stayed at Era 1's 15 m contour, and the shoreward edge stayed at
the shoreline — because nobody changed them.

### Era 4 — operator's stated intent (2026-07-25)

> SWAN fell short as a real wave model — that is why the dual 1D models exist. The SWAN
> SurfBeat and the SwellTrack analytical models should be modelling **from the end of the
> L3 grid to shore**. There SHOULD still be an L3 grid — it is not just L1/L2 straight to
> the 1D models — but L3 may only be needed **when there are obstacles**.

And, expanded: where structures exist, size L3 to terminate just past the obstacles — up
to the point where obstacle influence yields to bottom influence and where SWAN's own
numbers become tenuous. Where no structures exist, no L3, and the 1D models start at L2's
15 m point where L3 would otherwise have begun.

---

## 2. The structural gap, in one sentence

**Era 3 changed L3's alongshore extent and its existence; it never changed L3's
cross-shore extent — so L3 still carries a seaward boundary derived from depth of closure
(a criterion that now belongs to SwellTrack) and a shoreward boundary at the shoreline
(which contradicts the reason the 1D models were built).**

Every downstream inconsistency traces to this. The documents were never wrong about
*what changed*; they were silent about *what should also have changed*.

---

## 3. Decisions required

Each decision states the question, the options, the science, and a recommendation.
None of these has been made. All are architectural (trigger 3: model domain, boundary,
extent, handoff point) and require explicit operator approval.

---

### D1 — L3's seaward (offshore) boundary: what criterion sets it?

**Question.** L3's offshore edge is currently the 15 m contour, inherited from depth of
closure. Under the Era 4 architecture, is that still the criterion?

**Options.**

| | Criterion | Consequence |
|---|---|---|
| A | Keep 15 m contour (status quo) | L3 spans from 15 m to wherever its shoreward edge lands. At HB Pier the 15 m contour is 2,350 m offshore — a very large fine grid for a pier that reaches 7 m. |
| B | Structure-derived: `deepest_structure_depth + seaward margin` | Grid sized to its actual job. At HB Pier: pier tip ~7 m → offshore edge ~9–10 m, a few hundred metres offshore instead of 2,350 m. |
| C | Whichever is shallower of A and B | Bounded both ways; adds no new information over B. |

**Science.** Depth of closure (Hallermeier 1981; Ludka et al. 2019) answers *"how far
offshore does the sand profile still change?"* That question sizes the domain of a model
that must reproduce the **profile**. Under Era 4, the profile is SwellTrack's job, at
CUDEM (bathymetric DEM) resolution of 3–10 m — finer than L3's 10 m grid. The
depth-of-closure criterion has migrated to a different model along with the
responsibility. Retaining it as L3's criterion is a leftover, not a physical requirement.

L3's job under Era 4 is one thing: produce a spatially-varying spectrum that carries the
structure's shadow. The domain requirement that follows is that the **incident wave field
must be correct where it meets the structure** — the grid's seaward edge must sit far
enough seaward of the deepest structure that the nested boundary condition has relaxed
into a physically-developed field before the waves reach the OBSTACLE line.

**Open sub-question (must be resolved before D1 is final):** how much seaward margin?
There is no published "distance for a nest boundary to relax" figure in the material
reviewed. Two candidate anchors, both needing a literature check:
- A wavelength-based margin (one or two dominant wavelengths; ~80–160 m for HB's typical
  swell) — the same scale SWAN's own diffraction-applicability note uses.
- A Fresnel-scale margin, `sqrt(distance × wavelength)` — the scale
  SURF-ZONE-MODEL-BRIEF §2.3.2 gives for shadow transition width (stated there without a
  citation; verify before adopting).

**Recommendation: B**, with the margin fixed once the sub-question is answered. It aligns
L3's extent with L3's job, and it is what makes "smart-sized around structures" mean
anything in the cross-shore direction — right now that phrase is alongshore-only.

**Cost of B:** the L2 nest boundary must be produced at whatever depth L3's seaward edge
lands. L2 runs shore→30 m, so any structure-derived depth is inside L2's domain. No L2
change needed. (Grid geometry is fixed at setup time per `rules/clearskies-process.md` —
NESTOUT targeting must be computed from the same numbers, in the same pass.)

---

### D2 — L3's shoreward boundary: where does SWAN stop?

**Question.** This is the decision that was never made in any document. L3 currently runs
to the shoreline. Under Era 4 it should not. Where does it stop?

**Options.**

| | Shoreward edge | Consequence |
|---|---|---|
| A | Shoreline (status quo, brief §9 Option 1) | SWAN computes the surf zone it was judged unfit for. SwellTrack's boundary condition comes from inside SWAN's breaking zone — the spectrum is already Battjes-Janssen–dissipated. |
| B | The handoff contour exactly | Clean in principle, but the handoff extraction then sits **on** the grid's own boundary — the failure mode the brief already flags at the seaward edge (§2.3.5). |
| C | Handoff contour + a shoreward margin; extract at the contour, never at the edge | SWAN computes a strip past the handoff that is used only to keep the extraction point interior. |

> ## ⚠ D2 AND D2b BELOW ARE SUPERSEDED — READ ADR-093 AMENDMENT 2 INSTEAD
>
> **ADR-093 Amendment 2 is authoritative.** Everything in D2/D2b from here down is the
> working-out that led to it, kept because several of its wrong turns are worth not
> repeating. Four things below are now wrong:
>
> 1. **The handoff is not a fixed setup-time depth.** The grid is frozen at setup; the
>    *sampled cell* moves per forecast hour with that hour's breaking depth
>    (`Hs(hour) / gamma`). Freezing it at `1.3 × max_hs_m / gamma` uses the *largest*
>    swell's breaking depth all year — far seaward of anything breaking on an ordinary
>    day, and it shrinks L3 below the size needed to reach its own structures.
> 2. **The buffer is not N wavelengths.** SwellTrack needs only enough room to see the
>    breaking crossing inside its domain and to have an approach value for jacking. It
>    does not need shoaling run-up — SWAN already shoaled the wave, and SwellTrack
>    crosses the nonlinear inner zone wherever it starts. Margin still open, but small.
> 3. **The trigger is not structures alone.** It is structures **or** the operator's
>    point-break / headland / bay classification. A point break is alongshore geometry
>    and no single cross-shore profile can detect it. Automatic detection would need
>    contour-curvature analysis — explicitly out of scope.
> 4. **HB Pier is not disabled.** That conclusion was an artefact of (1). With a
>    per-hour handoff the grid is sized to the shallow end of the breaking range, and a
>    grid reaching ~2 m depth spans the pier end to end. Status: undetermined.
>
> **Both formerly-open items are now closed (2026-07-25).** The margin is the 1.3 factor
> applied per hour — `handoff_depth(hour) = 1.3 × Hs(hour) / gamma` — with the grid sized
> to reach the smallest value that ever produces. And **D1 is closed too: L3's offshore
> edge stays at the 15 m contour.** D1 was only ever opened because a frozen 15 m handoff
> would collapse the grid to zero thickness; with a per-hour handoff that cannot happen.
>
> Also settled since: Supplement 4's topographic multipliers are removed (they
> double-count L2's refraction), and setup-time calculation is depth-based only —
> contour positions, slope, breaking depths, spans, extents, relief; no shape analysis.
>
> One further dead end recorded here and in the ADR: the Deltares `cg/c < 0.9` criterion
> was adopted and then withdrawn. It governs models that rebuild a water surface from a
> boundary spectrum. SwellTrack marches bulk parameters and rebuilds nothing, so it does
> not apply — and applying it would have pushed the handoff to ~15 m, handing almost the
> whole transformation to the weaker model.

**DECIDED 2026-07-25 (operator approval in chat), with one term still open.** *(Superseded — see box above.)*

L3's shoreward boundary is the SWAN→SwellTrack handoff surface. L3 stops there; SwellTrack
and the SurfBeat strip run from there to shore. L3's shoreward boundary and the handoff
depth are one quantity, not two.

It is built from a depth term and a distance term:

```
break_depth_m      = 1.3 × max_hs_m / gamma          (gamma = 0.73)   floor 5.0 m
handoff_position   = break_depth contour, moved SEAWARD along the
                     transect by  N × L  metres                       ← N OPEN
                     where L = local wavelength near the break
```

**The depth term (settled).** `1.3 × max_hs_m / gamma` is where depth-induced breaking
begins. Seaward of it SWAN's Hs is undissipated; shoreward, Battjes-Janssen dissipation
has corrupted it. The same crossing is the outer edge of the surf zone
(SURF-ZONE-MODEL-BRIEF §5.5: impact zone starts at "first Hs/d > gamma"), so SWAN
breakdown and surf-zone onset are the *same line*. There is no separate "also capture the
surf zone" constraint to satisfy.

**The distance term (OPEN — N is undecided).** The 1.3 factor is a *shoaling correction*,
not slack: it converts deep-water Hs into the depth at which the grown wave breaks.
`1.3 × Hs/gamma` = 1.3× the break depth, which places the handoff essentially **at** the
break. That fails two ways:

1. The break point may fall on or outside the boundary and be missed entirely.
2. SwellTrack gets no shoaling run-up — no wave-shape development (Stokes→cnoidal, §5.3),
   no approach value for the jacking factor (§5.6, `Hs_bar_crest / Hs_approach`).

So the handoff must sit a **horizontal distance** seaward of the break, not at a deeper
contour. The natural scale is the **wavelength** — the only length scale in the problem
seaward of breaking, and what shoaling and shape transition evolve over.

Expressing the buffer as distance is also correctly slope-adaptive: a gentle shelf needs
more distance and pays little depth for it; a steep reef pays more depth but needs less
distance. A depth-based buffer would get this backwards.

Worked at HB Pier (slope ≈ 1:157; 14 s swell near the break at ~7 m → L ≈ 120 m):

| Buffer | Distance | Depth cost | Resulting handoff depth |
|---|---|---|---|
| 2 L | ~240 m | ~1.5 m | 8.6 m |
| 3 L | ~350 m | ~2.2 m | 9.3 m |

**To decide:** the value of N, and the period L is evaluated at (peak period varies 8–16 s
and L scales with T — a fixed N at 8 s is a much shorter buffer than at 16 s).

**Rejected alternative — a deeper depth criterion.** The published 1D-boundary rules
(Deltares ≥ 3×Hs = 2.19× break depth; XBeach max(10 m, 2×Hs)) are buffered break-depth
criteria and would supply the buffer implicitly. They were rejected because they express
the buffer in depth: at HB they put the handoff at 10–12 m, which is not what the physical
requirement (run-up length for shoaling) actually asks for, and they scale wrongly across
beach slopes.

---

### D2b — L3 viability test at setup (DECIDED 2026-07-25)

**Structures present is a necessary condition for L3, not a sufficient one.**

L3's extent is computed and then **tested**. If the resulting grid — bounded shoreward by
the handoff surface above — does not reach the structures it was created for, L3 provides
nothing and is disabled for that cluster. The spot then runs L1 → L2 → SwellTrack from
L2's ~15 m reference, identical to an open beach.

**At HB Pier this test fails.** The pier's deepest point is ~7 m; the breakdown depth is
~7.1 m. They coincide, so no buffer of any size fits between them — L3's shoreward
boundary lands seaward of the entire structure. **L3 is disabled at HB Pier.**

**Consequence, stated plainly.** With L3 off, the pier shadow is not *modelled* — it is
*excluded*. The multi-transect obstacle filter (SURF-ZONE-MODEL-BRIEF §2.2.3) already
flags transects crossing an OBSTACLE, drops them from headline metrics (best peak, spot
average), and renders them distinctly on the heat map. The product answer becomes "don't
paddle out here" rather than a modelled shadow height. This is coherent and honest, but it
is less than the L3 design promised, and it must be recorded as a known capability
limitation rather than left implicit.

**Future direction (noted, not scoped).** A ray-tracing add-on to SwellTrack would give 2D
shadow geometry at 1D cost, restoring modelled structure shadows without a 2D grid. That
path removes L3 **permanently** rather than conditionally, and supersedes this entire
decision set for structure-affected spots. Not in scope; recorded so the L3 work is not
over-invested in.

**Why this is the right criterion.** Depth-induced breaking begins where Hs > gamma·d,
i.e. at depth Hs/gamma. Seaward of that, SWAN's wave height is undissipated and
trustworthy; shoreward of it, SWAN's Hs has been through the Battjes-Janssen breaking
parameterisation — the exact physics SwellTrack exists to replace. The 1.3 factor is the
shoaling margin: waves amplify before they break, so a 4 m offshore swell breaks nearer
7 m depth than 5.5 m, and without the margin the break point lands in the zone SWAN has
already corrupted. The 5 m floor comes from §2.3.3 (below 5 m, QB > 0 for moderate-plus
waves regardless of climate).

Worked values at gamma = 0.73:

| Spot `max_hs_m` | `1.3 × Hs / 0.73` | L3 shoreward boundary |
|---|---|---|
| 1.5 m | 2.7 m | 5.0 m (floor) |
| 2.5 m | 4.5 m | 5.0 m (floor) |
| 4.0 m (HB Pier) | 7.1 m | **7.1 m** |
| 6.0 m | 10.7 m | 10.7 m |

**This formula is already in the architecture** — it is `fine_zone_max_depth` from
SURF-ZONE-MODEL-BRIEF §6.1, which sets where SwellTrack's 1–2 m fine grid begins. Adopting
it as L3's shoreward boundary makes the two coincide by construction: **SwellTrack's fine
zone starts exactly where SWAN stops.** No gap, no overlap, one number.

**Structure extent does not enter this decision.** Whether a structure exists determines
whether L3 exists at all, and structure geometry sets L3's alongshore and seaward extent —
but a structure cannot push L3's shoreward boundary past the depth where SWAN stops being
reliable. A pier that runs to the beach does not make SWAN accurate at the beach. The
breakdown depth is a hard ceiling regardless of what is in the water.

**Note on `structure_zone_depth`.** §6.1's fine-zone formula takes
`max(1.3 × max_hs_m / gamma, structure_zone_depth)`. Under this decision the second term
can only ever *deepen* SwellTrack's fine zone beyond the handoff — it can never move the
handoff. If a structure is deeper than the breakdown depth, SwellTrack's fine grid starts
deeper than L3's shoreward edge, which is correct: SwellTrack then runs at fine resolution
through water L3 also covered, using L3's spectrum as its boundary. No conflict.

---

**Superseded analysis (retained for the record).** The draft of this brief framed the
decision as two criteria pulling in opposite directions. That framing was wrong on two
counts, corrected by the operator 2026-07-25:

- It conflated **model resolution** with **bathymetry resolution**. SwellTrack does not
  have finer depth data than SWAN — both read the same DEM (10 m at HB Pier; there is
  nothing finer on that coast). SwellTrack varies its *computational grid*; its *data* is
  the same. Any argument resting on "SwellTrack sees the profile more finely" is void.
- It treated structure influence and SWAN breakdown as competing. They are not. L3 does
  not exist at all in the majority case (no structures). Where it does exist, the
  breakdown depth is a ceiling that structure geometry cannot raise.

Original text follows.

**Science.** Two criteria compete, and they pull in opposite directions:

1. **Structure influence wants L3 to run further shoreward.** A structure's shadow does
   not end at the structure. Diffraction fills the shadow progressively, and the shadow's
   transition width grows with distance from the tip. Truncating L3 at the structure tip
   captures a geometric shadow that the real wave field would have partly filled in.
2. **SWAN fidelity wants L3 to stop further seaward.** Once depth-induced breaking
   activates (QB > 0, where QB is SWAN's breaking fraction), SWAN's Hs is
   Battjes-Janssen–dissipated — which is precisely the physics SwellTrack exists to
   replace. SURF-ZONE-MODEL-BRIEF §2.3.3 puts the risk boundary at 5 m
   (*"QB very likely > 0 for moderate+ waves"*) and confirms QB = 0 down to 3.7 m at HB
   on 2026-07-20. It also warns that this margin shrinks as swell grows — the S2 winter
   case (2.5 m Hs at 16 s) was specifically written to *"stress the QB=0 handoff
   assumption."*

Criterion 2 is the binding one, and it is the only one of the two that is **measurable
from SWAN's own output**. Criterion 1 has no published depth threshold — "where obstacle
influence yields to bottom influence" is a real physical intuition but not a quantity any
source reviewed here puts a number on.

Criterion 2 is also *already* what the handoff-depth algorithm computes. So:

> **L3's shoreward boundary and the handoff depth are not two independent quantities.
> The handoff surface IS L3's shoreward boundary.**

That collapses two unknowns into one and removes a whole class of future inconsistency —
no configuration can put the handoff outside the grid, or the grid short of the handoff.

There is one complication. The handoff is a **depth contour** and varies per transect
(10 m open, ~5.5 m in the pier shadow at HB). A SWAN grid is a **rectangle**. The grid's
shoreward edge must therefore reach the landward-most excursion of the handoff contour
across all the grid's transects — at HB, the 5.5 m contour, not the 10 m one.

**Verification required before D2 is final (blocking).** What does SWAN do at a nested
grid's boundary segment that has neither a nest boundary condition nor a shoreline? If an
unspecified open boundary acts as an energy sink, option B is unsafe and the margin in
option C is mandatory, not stylistic. This must be read out of the installed SWAN 41.51
manual under the existing T7.GATE process (extract to `swan-commands-extract.md` before
any code) — not assumed. This brief does not assert an answer.

**Recommendation: C**, conditional on that verification. It applies the same principle the
brief already accepts at the seaward edge — *"L3 has not added independent computation at
its own edge"* (§2.3.5) — to the shoreward edge, where it matters more, because the
shoreward edge is where the production spectrum is actually extracted.

**Accepted cost, must be stated in the ADR:** shadow evolution shoreward of the handoff is
lost. SwellTrack is 1D per-transect and cannot diffract; whatever alongshore structure the
shadow has at the handoff is frozen and carried to shore. Moving the handoff seaward
increases this loss. This is the strongest argument for putting the handoff as far
shoreward as the QB = 0 constraint permits, rather than at a conservative round number.

---

### D3 — Open-beach handoff: 15 m from L2, or 10 m?

**Question.** Two documented rules disagree for the same physical situation.

- ADR-093 Amendment 1 §1, and SURF-1D-IMPLEMENTATION-PLAN T3.3: no structures → no L3 →
  handoff from L2 at **~15 m**.
- SURF-ZONE-MODEL-BRIEF §2.3.4: a transect with no shadowing structures →
  handoff at **10 m**.

Consequence today: an open, unshadowed transect at a spot that happens to have a pier
300 m away hands off at 10 m; a physically identical transect at a spot with no pier
anywhere hands off at 15 m.

**Science.** Both depths are inside published practice for a 1D cross-shore model's
offshore boundary:

| Source | Criterion | Value |
|---|---|---|
| XBeach manual (Deltares) | max(10 m, 2×Hs) | 10–16 m |
| Deltares BC guidelines (2020) | ≥ 3×Hs; cg/c < 0.9 | 9–15 m for Hs 3–5 m |
| CoSMoS (USGS) | Fixed −15 m isobath | 15 m |
| Fiedler et al. (2019) | Fixed 11 m; notes 10–30 m typical | 10–30 m |

15 m is exactly CoSMoS's operational choice and is the conservative end. 10 m is XBeach's
floor. Neither is wrong.

The tie-breakers are practical:

- **L2 resolution.** L2 is 100 m. Between 15 m and 10 m depth it resolves nothing L3 would
  have resolved. Handing off at 10 m from L2 buys no extra physics over handing off at
  15 m from L2 — it only shortens SwellTrack's run.
- **One extraction serves two consumers.** The swell display card already needs an L2
  SPECOUT at ~15 m as its deep-water reference (ADR-095 amended; ARCHITECTURE.md line
  102). Using the same point as the open-beach handoff means one extraction, one
  spectrum, no risk of the card and the model disagreeing.
- **Against 15 m:** the longer SwellTrack leg accumulates more of SwellTrack's missing
  physics. Round 2 measured SwellTrack ~26% above the SWAN strip at 500 m from shore
  (whitecapping, triad interactions, and directional spreading are absent from
  SwellTrack). Over 2,350 m from the 15 m contour at HB, that bias has a long distance to
  build. This is real and it is the one substantive argument for a shallower handoff.

**Recommendation:** keep **15 m** for the no-L3 case and **explicitly reconcile** the two
rules — state in the ADR that 10 m applies only to unshadowed transects *within an
L3-enabled cluster* (where L3 has genuinely computed down to 10 m) and 15 m applies when
the spectrum comes from L2. That makes the difference principled — the handoff depth
follows *which model produced the spectrum* — rather than accidental.

Then treat the accumulated-bias problem as its own item (D6), because moving the handoff
5 m shallower does not fix it.

---

### D4 — The `min(handoff, 15.0)` ceiling becomes a computed value

**Question.** The handoff algorithm clamps `handoff_depth = min(handoff_depth, 15.0)`,
commented *"Never deeper than L3 offshore boundary."* If D1 makes L3's offshore boundary
structure-derived, 15 is no longer that boundary.

**Recommendation.** The ceiling becomes `min(handoff_depth, L3_offshore_depth)` — the
computed seaward edge from D1, per cluster — for transects handing off from L3; and
`L2_reference_depth` (D3's 15 m) for transects handing off from L2. The literal 15 stops
appearing as a threshold anywhere in the handoff logic.

This is the specific defect that makes "15 m" read as a requirement rather than a bound.
Fixing it removes the trap.

---

### D5 — SurfBeat strip domain: does it still run 15 m → shore?

**Question.** The SurfBeat strip (1D-MODEL-BENCHMARK-BRIEF §7.3) is a SWAN run in an
idealised alongshore-uniform frame that produces infragravity energy — the long-period
set/lull rhythm SwellTrack cannot compute. Its specification is: ~2,500 m at dx = 5 m,
boundary = *"the L2 SPECOUT spectrum at the 15m handoff"*, shoreline reflection OBSTACLE
at the landward end.

So the strip **already runs SWAN from 15 m all the way to shore** — the exact thing D2
proposes L3 should stop doing. Is that a contradiction?

**Science.** No, and the reason should be written down rather than left implicit: IG
energy is *generated by* the shoaling and breaking of wave groups. A strip that stops at
the handoff would not produce the quantity it exists to produce. The strip must span the
surf zone; L3 must not. The two SWAN runs have different jobs and therefore different
domains.

**But there is a real coupling to settle.** ARCHITECTURE.md line 108 defines a **blended
Hs profile**: SurfBeat strip Hs for the approach zone (seaward of the break point),
SwellTrack Hs for the surf zone, 50 m taper — introduced specifically to correct
SwellTrack's ~24% approach-zone overestimate. The strip runs every 3rd forecast hour, with
carry-forward (not interpolation) in between.

If D2 shortens L3, the strip becomes the **only** SWAN-quality wave height in the approach
zone at open-beach spots — and it is available for 1 hour in 3. For the other 2 hours the
approach zone is SwellTrack alone, carrying its known bias.

**Recommendation.** Confirm the strip's domain as-is (15 m → shore) and decide separately
whether the blended profile's carry-forward behaviour is acceptable, or whether the strip
cadence needs revisiting now that it carries more architectural weight than when the
3-hour cadence was chosen. Flag: the 3-hour cadence was set on the basis that *set/lull
timing evolves slowly* — a statement about IG, not about approach-zone Hs. The cadence
decision was made for one purpose and is now load-bearing for a second.

---

### D6 — SwellTrack's missing physics over a long approach leg

**Question.** Not a boundary decision, but it is what makes the boundary decisions
consequential, and it is currently unowned.

SwellTrack has shoaling, refraction, Battjes-Janssen breaking, a roller, and bottom
friction. It does not have whitecapping, triad interactions, or directional spreading.
Measured gap vs the SWAN strip on the same input: ~26% at 500 m from shore
(1D-MODEL-BENCHMARK-BRIEF §8.1). The further seaward the handoff, the longer that gap has
to accumulate.

Round 2 explicitly declined to gate on this (*"R3 consistency is informational, not a
gate"*), on the grounds that the end product — face height at breaking — validated well
against Surfline (4.7 ft modelled vs 4–5 ft reported, §8.2). That is a defensible position
for the **break-point** number. It is not a position on the **approach-zone profile**,
which the beach-profile chart displays directly and which the blend (D5) exists to patch.

**Recommendation.** State explicitly which quantity is validated (face height at break)
and which is not (approach-zone Hs from SwellTrack alone), so the blend's role is a
documented correction rather than an undocumented dependency. No physics change proposed.

---

### D7 — L3 alongshore extent: already decided, keep it consistent

ADR-093 Amendment 1 §2 settles this: structure positions + shadow-zone extent (structure
length + 2× length downstream in the predominant wave direction) + 100 m pad. No decision
needed — it just must not be contradicted by the surviving Era 1 text ("250 m each side of
the pin cluster") in ARCHITECTURE.md line 98.

---

## 4. Downstream dependency the decisions must respect

`SURF-ZONE-MODEL-BRIEF` §6.1 defines SwellTrack's variable-resolution grid:

```
fine_zone_max_depth = max(1.3 * max_hs_m / gamma, structure_zone_depth)
```

where `structure_zone_depth` is defined as *"maximum depth at the L3 SWAN grid boundary
for this spot's cluster."* **SwellTrack's own grid resolution depends on L3's extent.**
Changing L3's boundaries (D1, D2) changes which part of the 1D profile gets 1–2 m
resolution versus 3–5 m. Whatever is decided must flow through to profile generation, and
a change to L3 sizing must re-trigger profile regeneration — the brief already says
structure changes do, for exactly this reason.

---

## 5. Governing documents that must change once decided

Not exhaustive — the full inventory is T4A.3.0's deliverable. These are the statements
already located that encode a superseded boundary.

| Document | Location | Statement | Status |
|---|---|---|---|
| `ARCHITECTURE.md` | 98 | L3 "extending 250 m each side of the pin cluster from shore to 15 m depth" | Stale on both axes (Era 1) |
| `ARCHITECTURE.md` | 114 | "L3 optional per location… smart-sized around structure clusters (not entire beach)" | Correct — contradicts line 98 |
| `SURF-ZONE-MODEL-BRIEF` | §4, §9 Opt 1 | "SWAN L3 runs to shore (current architecture, no changes)" | Stale (Era 2 v1) |
| `SURF-ZONE-MODEL-BRIEF` | §9 Opt 3 | "Truncate L3 at handoff depth… not recommended" | Stale — this is now the proposed architecture |
| `SURF-ZONE-MODEL-BRIEF` | §2.3.4 | `min(handoff_depth, 15.0)` / "Never deeper than L3 offshore boundary" | Superseded by D4 |
| `SURF-ZONE-MODEL-BRIEF` | §2.3.5 | "Always extract SPECOUT from L3 regardless" | Needs re-statement under conditional L3 |
| `SWAN-NESTING-RESEARCH-BRIEF` | 190–237 | L3 "shore to 15m depth", depth-of-closure derivation | Era 1 — historically correct, must be marked superseded not deleted |
| `MARINE-SERVICE-SEPARATION-PLAN` | T4A.3 | "L3: per-cluster, shore → max(15 m contour, deepest structure + margin)" | Already flagged STALE in the plan |
| `ADR-093` | Amendment 1 | Alongshore-only smart sizing | Needs a cross-shore amendment |
| `ADR-095` | Decisions 1, 4 | CURVE from ~15 m to ~1 m; SPECOUT placement | Needs re-derivation from D1/D2 |

---

## 6. Blocking verifications before any decision is final

1. **SWAN open-boundary behaviour at a nested grid's unspecified shoreward edge.** From
   the installed 41.51 manual, via T7.GATE. Determines whether D2 option B is viable or
   the margin in option C is mandatory.
2. **Seaward relaxation margin for a nest boundary approaching an OBSTACLE (D1).** No
   published figure found in the material reviewed. Needs a literature check before the
   margin is fixed.
3. **The `sqrt(distance × wavelength)` shadow-transition scaling** cited in
   SURF-ZONE-MODEL-BRIEF §2.3.2 is stated without a source. Verify before it is used to
   size anything.

---

## 7. What this brief does NOT do

- It does not change any governing document.
- It does not audit implementation against intent — that is T4A.3.0.
- It does not make any of the D1–D7 decisions. All seven are architectural under the
  CLAUDE.md trigger list (item 3: model domain, grid, boundary, extent, handoff point) and
  require explicit operator approval in chat.
