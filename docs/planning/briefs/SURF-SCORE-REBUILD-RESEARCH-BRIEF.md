# SURF SCORE REBUILD — RESEARCH BRIEF

Captured: 2026-08-04 via web research (sources §8) + local doc/code inventory (cites inline).
Status: research basis and design record for
[ADR-101](../../decisions/ADR-101-surf-score-geometric-mean.md) (Accepted 2026-08-04). Decisions
live in the ADR; §6 records the operator rulings that shaped it.
Companion: [EYEBALL-FIX-PLAN-2026-08-04.md](../EYEBALL-FIX-PLAN-2026-08-04.md) (D3, superseded by
this effort).

## 0. Why this brief exists

Operator directive (2026-08-04, eyeball session follow-up): *"Before we can move forward with this
plan, I think we need to, again, research what components make excellent surf (from a sport)
standpoint. Then we should compare that with what components we can currently measure based upon
our present model systems. Part of the research should also look at how our competition scores
things as well. What do surfers discuss when they discuss good waves? This may not just be
'physical sciences' based, but may have a 'psychological sciences' aspect."*

Context that triggered it:
- The current formula's only documented justification is one line in
  [MARINE-SURF-FISHING-RESEARCH-BRIEF.md §7.4](MARINE-SURF-FISHING-RESEARCH-BRIEF.md): "Port
  as-is; weights came from research and discussion" — the underlying research is lost (it lived in
  the pre-Clear-Skies "Phase II" extension era).
- The multiplicative adjustments (beach alignment ×0.1–1.0, exposure ×0.1/1.0, time-of-day
  ×0.9–1.1) were designed for **deep-water inputs**; §7.3 of that same brief flagged moving the
  scoring input to at-the-break values as "the fix that was missing in Phase II." That move
  happened (scoring now runs on SWAN/SwellTrack `breakingFaceHeight`), but the gates were never
  re-examined — a likely double-count (unverified; see §6 check).
- Operator judgment at eyeball review: the components/adjustments split is not explainable to a
  visitor; the score fails its only job (making the total understandable at a glance).

## 1. What the sport science says makes excellent surf

The academic surf-science literature (Scarfe, Elwany, Mead & Black's review "The Science of
Surfing Waves and Surfing Breaks"; Mead & Black's surfability work; the artificial-reef design
literature that operationalized it) converges on **four canonical surfability parameters**:

| Parameter | What it is | Why it matters |
|---|---|---|
| **Breaking wave height** | Face height at the break | The obvious one. "Generally the larger the breaker height, the better the surfing" (Scarfe) — but the *rideable* range is skill-dependent (§2). |
| **Peel angle** | Angle (0–90°) between the whitewater trail and the unbroken crest as the break travels along the wave | Called **the most important surfability parameter** in the reef-design literature. Governs ride speed: low angle = fast wave; angle → 0° = closeout (unrideable); practical band ≈ 30–70°. |
| **Breaker intensity** | Spilling / plunging / surging classification, controlled mainly by seabed gradient (Iribarren number) | Plunging = hollow/barreling (high value for advanced surfers); spilling = gentle (beginner-friendly); surging = generally unsurfable. |
| **Section length** | How far a rideable section runs before it shuts down | Longer makeable sections = longer rides. |

Beyond the canonical four, the literature and practitioner sources consistently add:

- **Consistency / set structure** — regular, predictable sets give more ride opportunities per
  session; wave period and swell organization drive it.
- **Surface texture (wind)** — offshore/light wind grooms the face; onshore wind degrades every
  other parameter's value. Every competitor treats wind as a *quality modifier on top of* swell,
  not as a peer component (§3).
- **Predictability** — "predictable, clean waves where the break point peels along the crest at a
  surfable speed" (Scarfe) — i.e., organization/cleanliness, which our DSPR/cross-swell factors
  already approximate.

## 1b. How much each factor matters to the surfer — the evidence, factor by factor

The apportionment principle (§6) requires weights grounded in surfer importance. This is the
honest state of the evidence per factor. Note the literature provides **ordinal** evidence (what
outranks what, and what is a precondition vs a modifier) — no published study assigns cardinal
percentage weights; the final numbers are operator judgment informed by this section.

**Wave Size — co-primary. Evidence: strong (revealed + literature).** "How big is it?" is the
first question of every surf conversation and the headline number of every surf report and every
competitor product (Surfline leads with the height range; MSW's solid stars were size/power).
Scarfe: "generally the larger the breaker height, the better the surfing." Flat = nothing else
matters — size is a precondition. Caveat from the same literature: size is skill-capped and
size-without-makeability is worthless, which is why it cannot outrank Shape.

**Wave Shape (peel angle + breaker intensity) — co-primary. Evidence: strong (this is the factor
the science ranks #1).** The reef-design literature names peel angle *the most important
surfability parameter* outright; a closeout ("it's big but it's closing out") is the canonical
worthless day regardless of size. Breaker intensity carries the sport's most prized experience —
the barrel — and an entire artificial-reef industry exists to engineer exactly these two
parameters, which is revealed importance expressed in construction dollars. Shape is the other
precondition: no makeable wave, no ride, no score.

**Conditions (wind/surface texture + cleanliness) — third in importance. Evidence: strong
(revealed, unanimous across competitors).** Every scoring product independently built a wind
mechanism — MSW's entire faded-star dimension, surf-forecast.com's proportional onshore-wind
drop, Surfline's rating description leading with "wind and ocean surface smoothness quality" —
which is unanimous revealed evidence that surfers weight wind heavily. (That is an importance
argument only: competitors mechanize wind as a *subtraction* on top of a swell score; in OUR
proposal Conditions is a normal additive component earning 0–20 points, per §7 — we do not copy
their mechanism.) Surfer vocabulary runs on this axis daily ("clean," "glassy," "blown out"). It
ranks immediately below the two preconditions: it can ruin a good swell but cannot make a bad
one rideable.

**Swell Power (period / groundswell character) — important, partly instrumental. Evidence:
moderate-strong.** Long-period groundswell vs short-period windswell is the quality distinction
every learn-to-read-a-forecast source teaches, and Surfline leads its swell breakdown with the
groundswell partition by convention. Honest caveat: period's importance is partly *instrumental*
— it acts through size at the break and through shape, both already scored — so its standalone
pool reflects the wave-character residual (push/power a surfer feels in the wave), not the whole
of period's influence.

**Consistency (set structure) — real but lowest of the five for a day-quality score. Evidence:
moderate.** Surfline ships Wave Consistency as a forecast dimension and phrases its quality tiers
as "% of waves worth riding"; practitioner guides list consistency among the top spot-selection
criteria. But in a *day-quality* context it modulates opportunity (rides per session), not the
quality of the wave a surfer actually rides — surfers wait through lulls for good sets. The
destination-choice literature confirms consistency matters more to *where to surf* than to *how
good is today*.

**Crowding — excluded, stated honestly.** The strongest single factor in the destination-choice
research (72% of surfers prioritize uncrowded waves; crowding ranks among the top threats to the
surf experience in quantitative surveys) — and completely unmeasurable by our stack. The score
must not pretend to capture it.

**Validation note (cheap, unlike the cut items):** after implementation, the weights can be
sanity-checked by comparing a week of our scores against the operator's own eyeball and
Surfline's rating for the configured spot — no historical data accumulation required.

## 2. The human-preference (psychological) dimension

The operator's instinct is supported: "good surf" is not a single physical optimum.

- **Skill level changes the target, not just the tolerance.** The reef-design practice literature
  brackets peel angle by ability: ≈56–70° suits beginners, ≈46–55° intermediates, ≈20–45°
  advanced/expert (faster = harder). Same for height (beginners want small/slow/weak; advanced
  want size, speed, hollowness) and breaker type (spilling vs plunging). **A single 0–100 score
  necessarily encodes a target audience.** The current formula's height table (peak value at
  ~3.5–7 ft faces) implicitly targets an intermediate surfer without saying so anywhere.
- **Expectations are spot-relative.** Surfline explicitly rates each spot relative to *that
  spot's* potential — "a 'Fair' rating at Pipeline will not look the same as a 'Fair' rating at an
  average beachbreak." A score calibrated against world-class surf reads as permanently broken at
  a modest local beach break.
- **Surfers experience quality as wave-count at a quality tier.** Surfline's tier definitions are
  literally phrased as "% of rideable/GOOD/EPIC waves" — quality = how many of the waves you
  paddle for are worth riding. Consistency is part of quality, not a side stat.
- **Crowd factor** — research notes crowding has an inflection point where it degrades the
  experience regardless of wave quality. Real but unmeasurable by us; out of scope, noted for
  honesty.

## 3. How the competition scores

| Service | Score shape | Inputs / method | Breakdown shown? |
|---|---|---|---|
| **Surfline** | TWO separate numbers: surf height (ft range) + conditions rating (7 tiers, VERY POOR → EPIC, colored) | ML model trained on ~35 yrs of human forecaster observations; wind/texture, wave shape, tide effects, spot-relative calibration | No additive breakdown. Tiers defined as "% of waves worth riding." |
| **Magicseaweed** (historical; absorbed into Surfline 2023) | 1–5 stars, in two layers: solid stars = swell size/power; faded stars = potential lost to wind | Swell energy vs wind penalty | The solid/faded split IS the explanation — "what you could have had, and what the wind took." |
| **surf-forecast.com** | 1–10 stars + separate wave-energy (kJ) number | Swell size + period raise it; onshore wind lowers it proportionally | No breakdown; energy number alongside. |

**Pattern worth absorbing:** every major competitor separates **"how much swell"** from **"how
clean/usable is it,"** and none of them exposes an additive point-pool breakdown. The two-axis
presentation (size × quality) is apparently what the market has converged on as
visitor-comprehensible. MSW's faded-star device is the most elegant explanation mechanism found:
it shows the *penalty* visually without any arithmetic.

## 4. What our model system can measure TODAY

Inventory from [API-MANUAL.md](../../manuals/API-MANUAL.md) §17–18 (wire fields verified in the
manual; all computed by the SWAN 3-level + SwellTrack 1D + SurfBeat pipeline):

| Sport-science parameter (§1) | Our measurement | Wire field | Used by current score? |
|---|---|---|---|
| Breaking wave height | H1/10 face height at SwellTrack break point | `breakingFaceHeight` | **Yes** (height factor) |
| Peel angle | Break-line angle from break-point variation across transects | `peelAngle` | **No — display only** |
| Breaker intensity | Iribarren number → spilling/plunging/surging | profile `breakerType`/`iribarren`; wave shape classification | **No — display only** |
| Section length | Per-transect break points + zones across the spot | `breakPoints`, transect set | **No** (not aggregated into a section metric today) |
| Consistency / sets | Set timing from SurfBeat infragravity spectral peak | `setTimingMinutes`, `setAmplitudeM` | **No — display only** |
| Surface texture (wind) | HRRR wind speed/direction vs beach facing | wind fields; organization sub-factor | **Yes** (organization: wind 50%) |
| Swell cleanliness | Directional spread (DSPR), swell dominance, cross-swell | `organization*` sub-factors | **Yes** (organization) |
| Swell arrival/energy | Watershed partitions (height/period/direction/energy per swell train) | `multiSwell` | Partially (period row uses Tm01, a mean — D1 pending) |
| Tide state | CO-OPS series at forecast hour | `tideLevel` | **No — display only** |
| Wave-face steepness/jacking | Hs amplification over bars | `jackingFactors` | **No** (ADR-096 lists as future sub-factor) |

**Headline finding:** our model already computes the literature's most important parameters —
peel angle, breaker intensity, set consistency — and the score uses none of them, while spending
its adjustment machinery on beach alignment and exposure, which the nearshore physics plausibly
already prices into `breakingFaceHeight` (§6). The scoring formula is a deep-water-era design
bolted onto a nearshore-model-era data pipeline.

## 5. Historical provenance (what we know of the lost research)

Chain: pre-Clear-Skies "Phase II" extension → [MARINE-SURF-FISHING-RESEARCH-BRIEF.md
§7.3–7.4](MARINE-SURF-FISHING-RESEARCH-BRIEF.md) (ported 4-component weights, "research and
discussion" not preserved) → [MARINE-SURF-FISHING-PLAN.md T3.3](../../archive/MARINE-SURF-FISHING-PLAN.md)
(added the multiplicative gates: `× beach_alignment × directional_filter × time_adjustment`) →
[ADR-096](../../decisions/ADR-096-scoring-restructure.md) (2026-07-18: 3-factor restructure,
surfaced the hidden multipliers as signed integers — fixed their *visibility*, never re-examined
their *existence*). No ADR has ever governed the surf scoring formula itself (fishing has ADR-088;
surf has none).

## 6. Operator direction after brief review (2026-08-04, in chat)

- **Display is NOT being reinvented.** Combined 0–100 score + stars stays ("allows a quick visual
  search"), and the component breakdown stays visible — we are noncommercial; competitors hide
  their breakdowns for competitive reasons that do not apply to us.
- **Penalties/bonuses become INTERNAL to components.** Any modifier lives inside the calculation
  of the component it affects and is never displayed as its own row. The visible breakdown is
  components only, each "N out of M" with M fixed.
- Magicseaweed's faded-star device: noted, not compelling — not adopted.
- **Double-count live check: CUT** (not feasible in available time). Consequence: alignment and
  exposure are retained as *internal* modifiers rather than deleted on an unverified
  double-count theory (§7).
- **Spot-relative calibration: CUT** (requires observation history we do not have).
- **Section length: dropped as a concept.** Peel angle already expresses it (closeout = peel
  angle → 0), and we compute peel angle directly.
- **Apportionment principle:** component weights reflect **how much each factor matters to the
  surfer** — NEVER our data quality or measurement convenience. Data limitations (cadence,
  optional inputs, nulls) are handled by per-component fallback rules, not by shrinking a
  factor's pool.
- **Penalties are NOT banned — unclear computation is.** Operator clarification (2026-08-04):
  "there is nothing WRONG with penalties, but our current method of computing them is unclear and
  does not work with our scoring system." The defect in the old adjustments was
  percentage-of-a-running-subtotal arithmetic applied in a hidden order. A penalty with a fixed
  scale and absolute computation (severity → points, independent of the other factors) is
  acceptable.
- **Veto reality check (operator, 2026-08-04):** conditions can ruin surf entirely in real life,
  not by 20% — "blown out" is a 0-star state in every competitor scale regardless of swell
  quality. Any structure that bounds conditions' impact at one component pool understates reality
  and fails. (The same veto logic applies to closeouts: a closed-out day is not merely "Shape
  scored 0.")
- **FINAL STRUCTURAL RULING (operator, 2026-08-04): weighted geometric mean.** Components do not
  sum — each is out of 100 (internally 0–1.0), the score is their weighted geometric mean, and
  the explainer is simply "the score is a geometric mean." No penalties, no bonuses —
  "everything is just a component." This supersedes the additive design and the penalty
  machinery in earlier drafts of §7.
- **Weights operator-adjustable (operator, 2026-08-04):** because the weights are subjective
  (ordinal evidence, cardinal judgment), the proposed values ship as DEFAULTS and the admin
  config UI lets the operator adjust them — per system, NOT per spot. Factor definitions and
  curves stay fixed; only the weights are adjustable.

## 7. PROPOSAL — FINAL (operator-ruled 2026-08-04): weighted geometric mean, five components, no penalties

**How this structure was reached (decision record).** The proposal was first worked out as
additive pools plus a wind penalty. Working through it with the operator surfaced, in order: the
single-use rule (no measurement feeds two score elements); the veto reality (wind can ruin surf
entirely — a bounded pool can't express that); peel angle's classification (a band factor like
wave height, not a ruiner); and finally the root defect the operator identified — **additive
systems assume compensability** (strength in one factor offsets weakness in another), which is
false for surf at the extremes: a clean 6-ft closeout day still banked ~66/100 under every
additive variant. Three aggregation structures were compared on that closeout day: additive
(~66 — the defect), minimum logic (5 — perfect veto but only the weakest factor ever matters),
weighted geometric mean (~35, → 0 as Shape → 0 — averages when balanced, collapses when any
factor collapses; precedent: the UN Human Development Index switched arithmetic → geometric in
2010 precisely to limit substitutability). **The operator chose the geometric mean**, noting it
also dissolves the penalty concept — "everything is just a component" — and that per-factor
bars each being out of 100 is acceptable and simple ("it is easy to say the score is a
geometric mean and leave it at that").

### 7.1 The formula

```
score = 100 × (Size^0.25 × Shape^0.25 × Conditions^0.20 × Power^0.20 × Consistency^0.10)

each factor internally 0–1.0, displayed as 0–100; weight exponents sum to 1.0
```

- Stars = score/20 (existing mapping, unchanged).
- Any factor at 0 → score 0 (the veto property, inherent).
- Behavior: balanced factors ≈ a weighted average; one collapsed factor sinks the score
  regardless of the others.

### 7.2 THE FIVE COMPONENTS — complete variable inventory and internal weighting

Each component is rated 0–100 (internally 0–1.0), displayed as a bar; no penalties exist.

**Within-component aggregation rule:** inside a component, sub-inputs blend by **weighted
arithmetic mean** (compensatory — a mushy breaker with a good peel angle is still decent shape),
while components combine by **geometric mean** (non-compensatory — veto power lives at the
component level only). Internal weights follow the same surfer-importance principle as the top
level, but are FIXED implementation defaults — only the five top-level weights are
admin-adjustable (§6 ruling).

**Definition — "modifier" (vs weighted input):** a weighted input answers "how good is this
aspect?" and earns its share of the component's rating (it has an internal weight). A modifier
answers "given that quality, how much of it applies here?" — it scales or nudges the rating the
weighted inputs produced (a multiplier or bounded bonus INSIDE one component's 0–1.0 value) and
earns no points of its own. Modifiers are the operator's "penalties/bonuses internal to the
model" ruling in mechanism form: unlike the old top-level adjustments, a modifier acts inside
exactly one component, affects nothing outside it, and is never displayed — the component's bar
shows the net result.

Variables are named exactly as they exist in the system (wire field or marine-pipeline value —
the scorer runs marine-side and reads pipeline values pre-serialization). This inventory is the
complete scoring input set: **a variable not listed here is not a scoring input; a variable
listed here that the implementation ignores is a defect.**

**1. Wave Size — weight 0.25**
| Variable | Source | Role | Internal weight |
|---|---|---|---|
| `breakingFaceHeight` | SwellTrack break point (H1/10 face) | Band curve: flat → ~0; rideable band → 1.0; too big → reduced (reuse existing height table's shape) | 1.0 (sole rated input) |
| dominant partition direction (from `multiSwell`) | SWAN PT* partitions | Internal modifier: beach-alignment gate (angle vs `beach_facing_degrees`) | modifier, not weighted |
| `spot_config.beach_facing_degrees` | spot config | Alignment reference | — |
| `spot_config.directional_exposure` | fan-derived per-spot map (profile cache) | Internal modifier: exposure gate on the swell's 8-point compass direction | modifier, not weighted |

**2. Wave Shape — weight 0.25**
| Variable | Source | Role | Internal weight |
|---|---|---|---|
| `peelAngle` | break-point spatial variation across all successful transects (BD-8) | Band curve: closeout ~0° → ~0; sweet band ~45–70° → full; slow mush >~70° → reduced | 0.6 |
| breaker type / `iribarren` (per-transect break points, 1D pipeline; wire: profile `breakerType`) | Iribarren number ξ at break | Graded: plunging > spilling > surging | 0.4 |
| `jackingFactors` (per-bar `factor` = Hs at bar crest ÷ approach) | 1D pipeline | Internal sweetener when > 1.3 (small bounded bonus, capped at component 1.0) | modifier, not weighted |

**3. Conditions — weight 0.20**
| Variable | Source | Role | Internal weight |
|---|---|---|---|
| wind speed + direction (+ `windSource`) | HRRR for t > 0; station/forecast provider at t = 0 (ADR-094 precedence) | Texture brackets vs `beach_facing_degrees` (offshore/cross/onshore × speed). Ruin states rated HARSHLY (blown out → ≤ 0.05) — this is where the veto power the old wind-penalty idea wanted actually lives | 0.6 |
| DSPR directional spread (wire: `organizationDirectionalSpread` source) | SWAN TABLE DSPR | Cleanliness: narrow → 1.0, wide/messy → low | 0.25 |
| cross-swell interference (wire: `organizationCrossSwell` source) | `multiSwell` secondary-vs-primary energy ratio + angle | Interference detection → reduced | 0.15 |

**4. Swell Power — weight 0.20**
| Variable | Source | Role | Internal weight |
|---|---|---|---|
| dominant partition `period` (from `multiSwell`) | SWAN PT* partitions — dominant selection per D1 rule, NOT Tm01 | Period curve (groundswell long-period → 1.0; short wind swell → low; absorbs the old period multiplier) | 0.7 |
| dominant partition `energy` (+ `height`) (from `multiSwell`) | SWAN PT* partitions | Energy/push scaling of the period rating | 0.3 |

**5. Consistency — weight 0.10**
| Variable | Source | Role | Internal weight |
|---|---|---|---|
| `setTimingMinutes` | SurfBeat IG spectral peak | Set interval curve (regular, surfable intervals → 1.0) | 0.6 |
| `setAmplitudeM` | SurfBeat (IG height at shoreline) | Set definition/strength | 0.4 |
| `swellDominance` (continuous 0–1 ratio) | spectral components, period > 10 s energy share | FALLBACK ONLY: replaces the whole component when SurfBeat is disabled/unavailable (a fallback rule, not a weight cut — §6 apportionment principle) | 1.0 when in fallback |

Explicitly NOT scoring inputs (and why): `breakingHawaiianHeight` (derived display of face
height — double-count), Tm01 `wavePeriod` (repudiated by D1 — mean of the whole spectrum),
`tideLevel` (tide's MECHANICAL effect is already inside the scored variables — SWAN takes water
level as an input [WLEVEL, ADR-095] and break position/type shift with it [ADR-093 Am.4], so
`breakingFaceHeight`/`peelAngle`/`iribarren` already carry it; scoring `tideLevel` again would
double-count, violating single-use. What we lack is the PREFERENCE layer — per-spot tide
windows, i.e. which tide range each spot breaks best in, which is local knowledge we have no
data source for. PINNED by operator 2026-08-04 as a possible future addition: an
operator-entered per-spot tide-window config field feeding a tide preference input — out of
scope for this rebuild, revisit only on operator request), `igWaveHeightM` (redundant
with `setAmplitudeM`), `breakPoints`/zones geometry (feeds the profile display, not quality),
`waveShapes` surface samples (visualization of the same physics `iribarren` already scores),
sunrise/sunset (time-of-day removed per D4).

**Design rule — SINGLE USE (operator, 2026-08-04):** every measured quantity feeds exactly ONE
component (as its input or internal modifier) — never two. Structural guarantee against
double-counting. The table above is the complete assignment.

**Display:** score + stars unchanged; five bars, each 0–100 with a fixed denominator (per-category
fill, ADR-096 rule — trivially satisfied since every denominator is 100); the ADJUSTMENTS column
is deleted; no signed rows exist. Visitor-facing explainer (one sentence): "The score is a
weighted geometric mean of the five factors — they average together, but one very poor factor
sinks the whole score, because bad shape or bad wind can't be made up for with size."

### 7.3 Disposition of every element of the CURRENT system

| Current element | Fate in this proposal |
|---|---|
| Wave Height factor (35 pts) | → Size component (weight 0.25), band curve |
| Wave Period factor (35 pts, Tm01-based, could exceed 35) | → Power component (0.20), dominant partition, capped at 1.0 |
| Wave Organization composite (30 pts) | Split: wind sub-factor + DSPR + cross-swell → Conditions component; swell dominance → Consistency fallback proxy |
| Beach Alignment (multiplier ×0.1–1.0, shown as signed row) | → internal to Size; row deleted |
| Directional Exposure (multiplier ×0.1/1.0, shown as signed row) | → internal to Size; row deleted |
| Time of Day (multiplier ×0.9–1.1, dead since C-47) | **Removed entirely** (resolves D4) |
| ADJUSTMENTS display column | **Deleted** — nothing replaces it; all five components are ordinary bars |
| Additive total (sum of factors) | **Replaced by weighted geometric mean** (operator-ruled) |
| Peel angle, breaker type, jacking, set timing (computed, unscored) | Promoted into Shape / Consistency per §7.2 |

What this achieves against the operator's requirements:
- **Everything is a component** — no penalties, no bonuses, no signed rows (operator: penalties
  "were harder to explain anyway").
- **Every factor can ruin the day on its own** — the veto requirement additive could never meet,
  now inherent in the aggregation instead of bolted on.
- **One-sentence explanation** and five identical-denominator bars.
- **Single-use rule** makes double-counting structurally impossible.
- **Uses the science (§1/§1b):** peel angle and breaker intensity first-class; consistency scored
  for the first time; weights = surfer importance as exponents.
- **Kills every legacy defect:** percentage-of-subtotal arithmetic, hidden multiplier ordering,
  component overflow past stated maxima, Tm01 in the headline (D1), dead Time of Day (D4).

Open items the ADR must settle (not blocking this proposal's review):
1. Exact factor curves, including the harsh ruin-state mappings (blown out, closeout ends), with
   worked examples for: balanced good day, clean closeout, blown-out epic swell, small clean day.
2. Weight exponents: 0.25/0.25/0.20/0.20/0.10 ship as system DEFAULTS; operator-adjustable in
   admin (per system, not per spot; normalized by sum at computation; reset-to-defaults) — ruled
   2026-08-04, spec in ADR-101. §1b's validation note gives a cheap post-launch sanity check
   (compare a week of scores vs operator eyeball + Surfline).
3. Null handling per component (e.g., peel angle null → neutral 0.5 vs excluded-and-renormalized
   exponents — geometric mean supports both cleanly).
4. Wire contract: `SurfScoringBreakdown` field changes (five 0–100 factor fields replacing the
   3-factor + 3-adjustment shape) — a data-contract change (trigger 4), enumerated in the ADR.
5. Target skill level stays implicitly intermediate (status quo) — the §2 skill-lens idea is
   explicitly OUT of scope; revisit only if the operator wants it later.

## 8. Sources

Academic / primary:
- Scarfe, Elwany, Mead & Black — The Science of Surfing Waves and Surfing Breaks: A Review
  (Scripps Inst. of Oceanography): https://escholarship.org/uc/item/6h72j1fz
- Scarfe et al. — Research-Based Surfing Literature for Coastal Management and the Science of
  Surfing (J. Coastal Research 2009): https://bioone.org/journals/journal-of-coastal-research/volume-2009/issue-253/07-0958.1/Research-Based-Surfing-Literature-for-Coastal-Management-and-the-Science/10.2112/07-0958.1.full
- Mead et al. — Predicting the Breaking Intensity of Surfing Waves:
  https://www.researchgate.net/publication/228605528_Predicting_the_breaking_intensity_of_surfing_waves
- Artificial Surf Reefs (peel-angle/skill design practice):
  https://www.researchgate.net/publication/27351072_Artificial_Surf_Reefs
- Surf pool design patent US10207168 (operationalized peel-angle-by-skill brackets):
  https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10207168
- Surf tourism / experience research (crowding inflection):
  https://www.sciencedirect.com/science/article/pii/S0048969722012141
- Surf travel behavior and destination preferences (Serious Leisure Inventory — wave quality and
  variety drive destination choice): https://www.sciencedirect.com/science/article/abs/pii/S0261517712001185
- Surf as a Driver for Sustainable Coastal Preservation (contingent valuation — wave
  characteristics drive willingness-to-pay): https://link.springer.com/article/10.1007/s10745-019-00106-7
- Place attachment and surf destination communities (crowding among top-ranked threats):
  https://www.frontiersin.org/journals/sustainable-tourism/articles/10.3389/frsut.2024.1387081/full
- Surfline — Wave Consistency as a forecast dimension:
  https://support.surfline.com/hc/en-us/articles/20350539606683-Wave-Consistency

Competitor methodology:
- Surfline rating of surf heights and quality: https://www.surfline.com/surf-science/rating-of-surf-heights-and-quality_31942/
- Surfline ratings & colors (ML methodology, spot-relative): https://support.surfline.com/hc/en-us/articles/36277684017819-Surf-Ratings-Colors
- Magicseaweed star rating (solid/faded stars): http://surfforecasting.magicseaweed.com/?p=41
- surf-forecast.com FAQ (rating + wave energy): https://www.surf-forecast.com/pages/faq

Practitioner/secondary (used for surfer-language cross-check only):
- https://surfing-waves.com/waves.htm
- https://www.balisurfingcamp.com/blog/surfers-guide-to-wave-consistency
