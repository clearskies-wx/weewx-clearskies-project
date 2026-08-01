# SWAN grid strategy — research findings

**Written:** 2026-07-27
**Answers:** [SWAN-GRID-STRATEGY-RESEARCH-BRIEF.md](SWAN-GRID-STRATEGY-RESEARCH-BRIEF.md) §4 (Q1–Q3 + TRANSM)
**Status:** analysis and recommendation only. Every change proposed here trips the architectural
trigger list (formula constants, grid extents/resolutions, handoff points) and **requires operator
approval before any code changes**. Nothing has been implemented.

**Evidence tiers used throughout:**
- **[SOURCE]** — published literature or the SWAN manual, cited.
- **[MEASURED]** — measurements from this system (brief §1–2, code, or live values).
- **[ASSUMPTION]** — stated assumption; the "what still needs measuring" section lists each one.

**Scope note (operator, mid-review):** this design is for the whole structure taxonomy — piers,
jetties, groins, breakwaters, seawalls — and for operator-classified refraction features (point
breaks, headlands, bay breaks). It is parameterized by structure class, not written around the pier.

---

## 0. Summary of findings

1. **The binding constraint on fine resolution is diffraction, not bathymetry.** SWAN's manual
   requires mesh size of **1/5 to 1/10 of the dominant wavelength near the tip of the diffracting
   obstacle** [SOURCE]. At the HB pier tip (~6–8 m depth, Tp 15.27 s → L ≈ 118–130 m), that is
   **12–26 m**. 10 m was an assumption, and it is finer than required. Bathymetry only binds where
   the DEM actually carries sub-30-m structure — and a fine grid over coarse bathymetry computes
   nothing real (the 2026-07-19 CUDEM lesson).

2. **The fine grid should be a small rotated rectangle anchored on the structure, not a strip
   spanning the 15 m contour to shore.** The 15-m-contour offshore edge is a carryover from when
   L3 was the fine-detail model. The structure grid's job is the structure. Offshore edge =
   structure tip + one wavelength; shoreward edge = the existing breaking-depth criterion;
   alongshore = the swell-climate shadow envelope. At HB: **~1,000 × 800 m at 12.5 m ≈ 5,120
   cells** vs 41,895 today.

3. **No standing intermediate grid between L2 and the 1D model on open coasts** (Q1). On
   alongshore-quasi-uniform bathymetry, stepping 100 m down to 30–40 m before the 15 m handoff
   buys percent-level changes at best [ASSUMPTION — one cheap A/B run proposed]. An intermediate
   band is justified only where a *named* bathymetric anomaly (canyon head, ebb shoal, reef) sits
   in the handoff zone at scales a 100 m grid cannot resolve (<~400–500 m). That is a setup-time
   test on bathymetry the system already caches, not a per-run cost.

4. **TRANSM 0.95 is too transparent; the operator's 0.80–0.85 hunch is empirically supported.**
   The best available field study — the 561 m pile-supported research pier at Duck, NC (Elgar,
   Guza, O'Reilly, Raubenheimer & Herbers 2001, J. Waterway Port Coastal Ocean Eng. 127(1):2–6)
   — required **30–50% energy blocking** by the pilings to reproduce observed wave heights
   downwave, equivalent to a **height transmission Kt ≈ 0.71–0.84** [SOURCE]. SWAN's TRANSM is a
   wave-height ratio [SOURCE], so `TRANSM 0.80–0.85` is the defensible range for a pile pier under
   obliquely-crossing swell. Same study: much of the far-field pattern was *refraction over the
   scour trench* under the pier — a bathymetry effect SWAN captures only if the DEM contains the
   trench and the grid resolves it (~20–30 m).

5. **Recommended architecture (per-spot, chosen at setup):**
   - Open beach → L1 → L2 → 1D at 15 m (unchanged).
   - Refraction feature (point/headland/bay, no structure) → coarse L3, **30–40 m**, no
     diffraction (it is sub-resolution there and refraction is the physics wanted).
   - Structure → one **rotated fine wedge ("L4")** at ~L/8–L/10 of the tip wavelength (12.5 m at
     HB), stabilized DIFFRACTION on, OBSTACLE with class-appropriate transmission, nested directly
     in L2. Transects covered by the wedge hand off from it at the existing per-hour breaking-depth
     criterion; transects outside it hand off from L2 at 15 m — the non-uniform handoff the
     operator already accepted.
   - Both features present → both grids; the wedge nests in the coarse L3.

6. **Cost at HB pier: ~11,200 total cells ≈ 6–7 min full cycle** (vs 47,992 cells → >75 min DNF
   for the restored spec). Detailed table in §6.

7. **The normative logic flow — which grids a spot gets, what nests in what, which physics run in
   which grid, and where each transect's handoff reads from — is §5.1.** It is written to be
   followed mechanically. If any other prose in this document seems to disagree with §5.1, §5.1
   wins.

---

## 0A. Operator decisions — review session, 2026-07-27

**These are rulings, not proposals.** Where a ruling conflicts with §1–§8 below, **the ruling wins**
and the superseded text is marked. §1–§8 are preserved as the research record that produced them.
The implementable form of every ruling here lives in
[MARINE-MODEL-RESTORATION-PLAN.md](../MARINE-MODEL-RESTORATION-PLAN.md) Phases E and F.

### D1 — Terminology: "wedge" is struck

The fine structure grid is a **rotated rectangle**, per §3.1. Calling it a "wedge" describes a shape
this document explicitly ruled out and will mislead every future reader. Names are now:

| Old name in §1–§8 | Name from here on |
|---|---|
| "wedge", "L4 wedge" | **structure grid** (tier L4) |
| "conditional band", "BAND" | **L3** — there is only one intermediate tier |
| "coarse L3" | **L3** — same tier, different extent |

### D2 — L3 is need-driven, not standing. **Supersedes §0.3, §2.2, §2.3, §5, §5.1.1 STEP 3.**

The document proposed a *conditional* band gated on a bathymetric-variance test. The operator first
directed that the band be standing, then — after the handoff rule below was worked out — that L3
exist only where it does work. Final ruling:

**L3 exists for exactly two reasons, and never otherwise:**

1. **As the nesting step under a structure grid.** 100 m → 12.5 m in one jump is 8:1; L3 at 30–40 m
   makes it 2.5:1 then 3.2:1. This retires §2.3's flagged 8:1 nest-quality risk **and its pre-sized
   L2-collar fallback** — the collar is no longer needed and is struck.
2. **As the working refraction grid** at an operator-classified point break, headland, or bay
   (§5.1.1 STEP 2, unchanged).

**Consequences:**
- The **variance test and its threshold are struck entirely** (§2.2, §5.1.1 STEP 3, §5 approval
  item 6, §7 item 4's role as a gate). No survey of anomalous-vs-plain spots is needed.
- **The open-beach path is untouched** — `L1 → L2 → 1D at 15 m`, byte-identical to what runs in
  production today. This redesign cannot regress a spot that has neither a structure nor a
  classified refraction feature.
- Under a structure, **L3 supplies no handoff at all** (see D3). Its extent is driven solely by
  containing L4 with clearance plus the spot's alongshore span — *not* by the 30 m contour, which
  §2.2 used and which no longer has a rationale.

**Operator's reasoning, recorded:** *"There is no reason to run an L3 grid if we are not actually
using it for anything and the D1 model is adequate."*

### D3 — Handoff rule: as deep as possible. **Supersedes §5.1.3 entirely.**

§5.1.3 read "hand off from the finest grid that covers the transect." That is **wrong** and is
replaced by:

> **Hand off as deep as possible. Go shallower only where 2D physics still matters, and only as far
> as the grid modelling that physics reaches.**

**Operator's reasoning, recorded:** *"The D1 model, in my mind, is MORE ACCURATE than the L3 grid
overall as it is using fine bathymetry and a fine resolution. Where it breaks down is dealing with
refraction, etc., hence the L4 grid/handoff in that situation… Waiting to handoff until just before
the break throws out a level of specificity we get in D1 that we do not get in the SWAN model."*

**The physics backing it.** The 1D model runs a **3–5 m** cross-shore profile against L3's 30–40 m —
6–10× finer, and finest exactly where the depth gradient is steepest. At Huntington the source
bathymetry is **10 m** (operator-confirmed), so the 1D profile interpolates only 2–3× — not the 9×
that caused the 2026-07-19 defect, and *finer than any SWAN grid we would build*. Where 3 m data
exists it is finer still. What the 1D model cannot do is anything 2D; its refraction is Snell's law
over contours assumed straight and parallel, which is **exact** where they are — true on open sandy
coast between 15 m and the break, false near a structure or headland. That is precisely the carve-out.

**Resulting selection, first match wins:**

```
1. Transect touches the structure grid (L4)
      → hand off from L4 at the per-hour 1.3·Hs/0.73 breaking-depth criterion.
        (Sheltering and diffraction matter into the surf zone here.)
2. Transect lies in a classified refraction feature's influence, covered by L3
      → hand off from L3 at the per-hour breaking-depth criterion. Same reason.
3. Otherwise
      → hand off from L2 at fixed 15.0 m (L2_REFERENCE_DEPTH_M). The 1D model runs
        the full remaining distance (~2 450 m at HB) on its own fine profile.
```

**"Touches" is defined as: the transect's cross-shore line enters the structure grid's footprint.**
Operator-accepted. Because L4's edge sits **2 wavelengths beyond the geometric shadow boundary**
(§3.2), boundary transects are in essentially undisturbed water, so the two paths should agree
closely there — making cross-boundary transect agreement a **consistency check**, not a defect.
Neighbouring transects resolving to different rules remains accepted and expected.

**Side effect — a hole this closes.** §5.1.3's rule created an "inside L3 but outside L4" handoff
path that would have been written and, at Huntington, never executed (L4 covers all 32 transects).
Under D3 those transects take the L2-at-15 m path — the same code that runs in production today.
The untestable branch is gone.

### D4 — The deep-water reference stays on L2, always. **Confirms §5.1.3's bullet; rejects the
alternative raised in review.**

Two numbers are read near the 15 m contour: the **handoff** (the 1D model's starting condition) and
the **deep-water reference** (a *reported* "what the swell is doing offshore" value). Under D2+D3
they can never collide at the same depth from different grids, because a transect handing off at
15 m reads from L2 — the same grid the reference reads from.

The coordinator proposed moving the reference to L3 where L3 exists. **Rejected, for a better
reason than the one it was proposed under:** keeping the reference on L2 gives it *the same meaning
at every spot regardless of that spot's grid configuration*. Sourcing it from "whichever finest grid
covers 15 m" would make a structure spot report its offshore reference on a different basis from a
plain spot.

**Mandatory documentation obligation (doc-code sync):** it must be written down that the reference
is **L2-sourced and is not the 1D model's starting point**, so nobody later "fixes" a discrepancy
that is by design. Plan task E5.

### D5 — Hourly quick updates run every grid that supplies a handoff

**Supersedes §5.1.2's "quick updates run the finest grid only, as today."** Under D2/D3 the finest
grid may cover only part of a spot, so "finest grid only" would silently leave some transects with
no hourly refresh.

**Operator ruling:** *"there is nothing wrong with doing the hourly update of all grids that would
hand off to D1 (not just the L4 grid)."*

**Mode is stationary** — operator-confirmed and already what the code does. Stationary solves for the
wave field that settles out under fixed inputs; over a domain waves cross in minutes that is both
correct and far cheaper than time-stepping. Non-stationary earns its cost only on L1, where travel
times are hours.

**Honest note, so nobody later assumes the L3 hourly run is load-bearing:** L3 sits in 15–30 m of
water, where a metre of tide is a few percent depth change and there is negligible fetch. Its hourly
refresh carries almost no new information. The structure grid spans roughly 2–6 m, where the same
metre of tide is a 15–50% change — that is where hourly genuinely matters.

### D6 — Approval status of §5's seven items, after these rulings

| # | Item | Status |
|---|---|---|
| 1 | Retire the 15 m-contour offshore edge; adopt the structure grid | **Approved** |
| 2 | Resolution `min(L_tip/8, 15 m)`, floor 10 m, instead of constant 10 m | **Approved** — and see D7 |
| 3 | Rotated CGRID/NGRID (`alpc`/`alpn` ≠ 0) | **Approved**; severable (§7 self-audit) |
| 4 | Pier `TRANSM 0.95 → 0.82` | **Approved** |
| 5 | L3 at 30–40 m for refraction spots, diffraction off there | **Approved** |
| 6 | Conditional band + variance threshold | **STRUCK** — superseded by D2 |
| 7 | Structure-grid bathymetry cache replaces the L3 fine cache | **Approved** (bookkeeping) |

### D7 — Resolution is safe against the source data

Operator-confirmed: Huntington bathymetry is **10 m**. The rule `min(L_tip/8, 15 m)` yields **12.5 m**
there — *just coarser than the source*, so the structure grid does not outrun its data. This is the
2026-07-19 lesson (a "10 m" grid running on ~90 m data) checked and cleared, not assumed. It also
means §7 item 3 — does the DEM contain the pier scour trench — is **answerable**: 10 m data can
resolve a 50–100 m trench.

### D8 — Revised cell counts under D2+D3

Replaces §6's option table for the recommended design. Anchors unchanged: 12 448 cells → ~7 min
[MEASURED]; 47 992 cells → >75 min, did not complete [MEASURED].

| Grid | HB cells | Note |
|---|---|---|
| L1 (1 km) | 567 | unchanged |
| L2 (100 m) | 5 530 | unchanged |
| L3 (40 m) | **~1 400** | contains L4 + clearance; *not* the 30 m contour |
| L4 (12.5 m, rotated) | **~5 120** | structure grid |
| **Total** | **~12 600** | **≈ 7 min — on the measured anchor** |

A spot with neither a structure nor a refraction feature: **6 097 cells** (L1+L2 only) — unchanged
from production. Hourly quick update under D5: L3 + L4 ≈ **6 520 cells**.

---

## 0B. Wind and tide in the 1D model — investigation and ruling, 2026-07-27

Raised by the operator while reviewing D3: handing off deeper gives the 1D model a longer run, so
what does it do about wind and tide over that run?

### 0B.1 Tide — fully handled. No gap. [MEASURED, code-read]

`tide_level` is added to every profile depth at
[`surf_1d_analytical.py:638`](../../../repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surf_1d_analytical.py),
fed from real predictions (`swan.py:3054`, `:1798`), not a default. Three call sites **refuse to
compute rather than substitute a zero tide** when the prediction is missing
(`surf_pipeline_timestep.py:110`, `endpoints/surf.py:954`, `endpoints/beach_profile.py:1001`).

A deliberate split is documented at `surf_1d_pipeline.py:304`: the **handoff point** is chosen on the
**raw chart-datum depth**, so the boundary does not migrate seaward and shoreward twice a day while
SWAN sampled a fixed location; the tide is then applied to the profile the 1D model runs on. That is
the correct split and it was reasoned about.

### 0B.2 Wind — the quality effect is modelled; wave generation is not [MEASURED, code-read]

Two different things travel under "wind," and they are in different places.

**Modelled:** [`enrichment/surf_scorer.py`](../../../repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/surf_scorer.py)
carries wind at **15% of the total surf score** (50% of the 30-point organization component) —
offshore wind holds the wave face up, onshore blows it down — with full angle bands (glassy /
offshore / cross-offshore / cross / cross-onshore / onshore) and multipliers 1.2 → 0.3.

**Not modelled:** the 1D model has **no wind input term at all**. `run_1d_analytical()`
(`surf_1d_analytical.py:607`) takes `hs, tp, direction, bathy_profile, tide_level, gamma,
beach_facing, cfjon` — the only "wind" in the file is the *bottom-friction* coefficient label
(0.067 for wind seas vs 0.038 for swell, Zijlema et al. 2012). It propagates, shoals, refracts,
dissipates and breaks, but never grows waves.

### 0B.3 Magnitude [ASSUMPTION — standard fetch-limited arithmetic, not measured on this system]

Handing off at 15 m gives the 1D model ~2 450 m of fetch it does not use. Deep-water fetch-limited
growth over that distance:

| Onshore wind | Wind sea Hs | Peak period | Effect on a 1.0 m swell (RSS) |
|---|---|---|---|
| 15 kt (7.5 m/s) | ~0.19 m | ~2 s | 1.02 m → **+2%** |
| 20 kt (10 m/s) | ~0.26 m | ~2 s | 1.03 m → **+3%** |

**The coordinator recommended against implementing on these numbers. The operator overruled.**

### 0B.4 Ruling: implement it. Operator decision, and the coordinator's recommendation was wrong-headed

*"I understand it may not add/or subtract much, but it is important. We need to enhance the 1D model
to include the wind input."*

The coordinator evaluated the change on **height impact alone**, which is the wrong yardstick. The
surf scorer has two sub-factors — **swell dominance** (*"clean single dominant swell scores higher
than confused wind-chop"*) and **cross-swell** — that both depend on whether a competing
short-period component exists. The 1D model structurally cannot produce one locally, so those
factors run on whatever arrives in the handoff and nothing else. Adding locally-generated wind sea
makes them physically grounded. That is worth more than 2–3% of height.

**This trips architectural trigger 1. Operator approval is recorded here and in the plan's Phase F.**

### 0B.5 The double-count hazard is real, concrete, and dictates the design [MEASURED, code-read]

SWAN applies wind on every grid, and its **watershed partitioning** (Hanson & Phillips 2001) already
separates a wind-sea partition. Tracing it:

1. `parse_table_pt_partitions()` (`swan_spectral.py:1129-1143`) reads SWAN's `PT*` TABLE output and
   sets **`is_wind_sea: k == 1`** — SWAN's convention is partition 1 = wind sea, 2–10 = swells.
2. `watershed_partitions_to_component_format()` (`swan_spectral.py:1194-1208`) converts them — and
   **explicitly discards `is_wind_sea`**, re-sorting by descending Hs. Its own docstring says so:
   *"the wind-sea/swell distinction watershed partitioning carries is discarded here because the
   existing consumers have no concept of it. Consuming that distinction is a separate,
   not-yet-approved change."*
3. The production path is `partition_source="neighbourhood"` (the default,
   `surf_1d_pipeline.py:886`), which reads `specout_data["components"]` — and per that parameter's
   own docstring (`:962-968`), `components` is *"SWAN's own watershed partitioning, read from PT\*
   TABLE output at both the L3 CURVE call sites AND the L2 deep-water-reference baseline."*

**Therefore: SWAN's wind-sea partition already reaches the 1D model in production — anonymously.**
It arrives as one partition among several, sorted by height, with nothing marking it as the wind sea.

**`classification` is not a substitute.** It is a period-based proxy (`_classify_period`: >12.5 s
groundswell, 10–12.5 s swell, <10 s wind_swell, `swan_spectral.py:26-29`). A decayed 9 s swell is
labelled `wind_swell` and is not a wind sea; a wind sea under strong forcing can exceed 10 s. Using
the proxy would be sloppy in exactly the way this project keeps getting burned by.

### 0B.6 Design ruling — grow the existing partition, do not add a second one

Three options were considered:

| Option | Verdict |
|---|---|
| **A.** Add a wind growth term inside `run_1d_analytical()`'s march, applied to every partition | **Rejected — physically wrong.** 15 kt does not feed a 15 s groundswell. It would inflate swell height while keeping swell period, manufacturing a swell that does not exist. |
| **B.** Synthesize a *new* wind-sea partition and run it through the same machinery | **Rejected as the primary path — double-counts.** SWAN already handed one over (0B.5). |
| **C.** **Carry `is_wind_sea` through, and grow *that* partition over the 1D run** | **ADOPTED.** No double-count by construction: SWAN grows the wind sea to the handoff, the 1D model continues it over the remaining fetch. |

Option B survives **only as a fallback**: when SWAN handed over no wind-sea partition (calm offshore,
or the bulk-parameter degradation path) *and* there is an onshore wind component, synthesize one.
That case cannot double-count because there is nothing to double.

**Why C is also the least invasive.** It does not change what `run_1d_analytical()` is responsible
for — the growth term is applied to one partition by the caller. And
[`_combine_partition_hs()`](../../../repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surf_1d_pipeline.py)
(`surf_1d_pipeline.py:407`) already root-sum-square combines partitions **and enforces depth-limited
saturation on the total** — so even a crude growth estimate is capped correctly by machinery that
already exists. The swell path is untouched and cannot regress.

### 0B.7 Fetch geometry — the rule that prevents the double-count returning by the side door

Only the **onshore component** of wind generates new sea inside the 1D domain, with fetch measured
from the handoff point shoreward.

- **Alongshore wind** builds sea over a long alongshore fetch — but that fetch lies inside SWAN's 2D
  domain, so it is already in the handoff spectrum. Do not regenerate it.
- **Offshore wind** does generate waves over the nearshore, but they travel seaward, away from the
  break, and contribute nothing to surf. Its real effect on the wave face is already the scorer's job.

### 0B.8 Growth relation — family fixed, coefficients deliberately NOT written here

The run goes 15 m → 0 m, so **deep-water fetch-limited growth (plain JONSWAP) is the wrong
relation** — growth in shallow water is capped by depth well before it is capped by fetch. The
correct family is finite-depth fetch-limited growth:

- **Young, I.R. & Verhagen, L.A. (1996).** *The growth of fetch limited waves in water of finite
  depth. Part 1: Total energy and peak frequency.* Coastal Engineering **29**, 47–78. The standard
  reference, from Lake George (Australia); a family of growth curves, one per non-dimensional depth,
  in which both energy growth and peak-frequency migration cease at large fetch as conditions become
  depth-limited. This is what SWAN's own shallow-water growth is validated against.
- **Breugem, W.A. & Holthuijsen, L.H. (2007).** *Generalized shallow water wave growth from Lake
  George.* The later revision.

**Two web searches did not surface the explicit coefficients.** They are therefore **not written into
this document or the plan**, and "verify every coefficient against the primary source before
implementing" is a **gated acceptance criterion** on plan task F3 — not a note. Writing a
plausible-looking constant from memory is exactly how `TRANSM 0.95` entered this system.

**Unusually, this change is properly testable.** Young & Verhagen publish growth curves — measured
height and period against known fetch, wind speed and depth. That yields a genuine
**known-answer test** (`rules/verification.md` mandate) rather than a rearrangement of the
implementation. Plan task F3 is gated on it.

### 0B.9 Wind source — one wind, not two

Wind exists in the marine service as a **spatial field**: `blended_wind = self._stitch_wind(
hrrr_wind_field, gfs_wind_field)` (`providers/nearshore/swan.py:1299`), used to force SWAN.

**Ruling:** the 1D model's wind must be sampled from **that same field**, at the spot, for the same
forecast hour. Introducing a second wind source (station observation, a different forecast product)
would drive SWAN and its own 1D continuation with different winds across the handoff — an
inconsistency that would produce plausible, wrong, and very hard-to-diagnose output.

---

## 1. Q2 first, because it gates everything: what actually requires fine resolution

### 1.1 The diffraction criterion is the binding constraint [SOURCE]

The SWAN user manual (41.51, DIFFRACTION command): the phase-decoupled refraction-diffraction
approximation requires that *"the spatial resolution near (the tip of) the diffraction obstacle
should be 1/5 to 1/10 of the dominant wave length,"* and warns that diffraction computations
*"often converge poorly or not at all"* without under-relaxation or smoothing. Two consequences:

- The criterion is anchored at the **tip** of the obstacle — the place the diffracted field is
  generated — not everywhere in the grid.
- The wavelength that matters is the local one at the tip. Brief §3's arithmetic was
  independently re-verified: with Tp = 15.27 s (deep-water L₀ = 1.56·T² ≈ 364 m), the dispersion
  relation gives **L ≈ 132 m at 8 m depth and L ≈ 177 m at 15 m depth** [MEASURED arithmetic,
  SOURCE relation]. At the pier tip (≈6.3 m by linear interpolation between the measured 1.78 m
  and 15 m contours — [ASSUMPTION], see §7): L ≈ 118 m.

So the resolution requirement at the HB pier tip is **12 m (L/10, conservative) to 24 m (L/5,
manual's floor)**. A 12.5 m grid sits at ≈ L/9.4. **10 m is not required; it was an assumption.**
Near the wedge's shoreward edge (L ≈ 66 m at ~2 m depth) 12.5 m is only ≈ L/5.3, but the
diffracting tip is not there, breaking dominates there, and the 1D model takes over at ~1.75 m.

### 1.2 Bathymetry binds only where the data has structure [MEASURED + SOURCE]

Two facts cap what fine grids can extract from bathymetry:

- A grid resolves bathymetric features no smaller than ~4–5 cells across. 100 m cells see
  features ≥ ~400–500 m; 30 m cells see ≥ ~120–150 m.
- A grid finer than its DEM computes interpolation, not physics. This project already paid for
  that lesson (2026-07-19: the "10 m" L3 ran on ~90 m CRM data).

The one sub-100-m bathymetric feature likely to matter at a pier is the **scour depression under
it**. At Duck the depression is up to 1.5 m deeper than the flanking bed and refraction over it —
not the pilings — explains the wave field far downwave [SOURCE: Elgar et al. 2001]. A ~50–100 m
wide trench needs ~20–30 m cells. **Action item: check whether the HB DEM actually contains the
pier trench** (one query against the cached FINE bathymetry; §7).

### 1.3 Answer to Q2

- **Governing requirement:** the manual's diffraction criterion, evaluated at the structure tip's
  local wavelength — *per spot, at setup, from data the sizing chain already has* (tip depth from
  the cached profile, Tp from the design swell). Not a fixed 10 m constant.
- **Is 10 m required?** No. At HB, 12–15 m satisfies the criterion; even 20 m satisfies the
  manual's L/5 floor. Recommend **Δx = min(L_tip/8, 15 m)** with a floor of 10 m for short-period
  wind-swell coasts, giving 12.5 m at HB.
- **Extent of the obstacle grid:** §3 (Q3).
- **Can one grid serve both purposes (carrier + fine)?** At HB scale, yes — one 12.5 m wedge of
  ~5,100 cells replaces both jobs, and no coarse L3 is needed at all for a structure-only spot
  (§2.3). Rule of thumb: if the wedge at fine resolution exceeds ~15–20k cells (structures
  spanning multiple km, e.g. a long harbor breakwater), split into a 30–40 m carrier plus a fine
  tip grid; below that, one grid is simpler and cheap enough.

---

## 2. Q1 — is an intermediate grid between L2 and the 1D model worth having?

### 2.1 What resolution controls at the handoff

The handoff hands the 1D model a spectrum (Hs, Tp, direction, 2-D spectrum) read at a point. Grid
resolution affects that spectrum through exactly two channels:

1. **Refraction/shoaling over bathymetry the coarse grid cannot see** — features smaller than
   ~4–5 cells (§1.2). Between the 30 m and 15 m contours on an open sandy coast, contours are
   quasi-straight and alongshore variation lives at scales ≫ 500 m, so a 100 m grid resolves the
   physics that is actually there. Refining to 30 m changes the handoff values only if sub-400-m
   bathymetric structure exists in that zone.
2. **Alongshore sampling density across the spot** — 100 m cells give ~3 distinct cells across a
   313 m spot; 30 m cells give ~10. This matters only if the true field varies alongshore at
   those scales, which (absent structures — handled by the wedge — and absent bathymetric
   anomalies) it does not on an open coast.

Supporting evidence [SOURCE]: at Duck, a *linear spectral refraction model* over measured
bathymetry reproduced observed nearshore wave heights 400 m from the pier — on an open sandy
beach, handoff-depth accuracy is controlled by the bathymetry representation and the offshore
spectrum, not by model resolution beyond the point where the bathymetry is resolved (Elgar et al.
2001). I did not find a published SWAN convergence study isolating 100 m vs 30 m at a 15 m-depth
handoff on an open coast; the claim "percent-level difference" is therefore **[ASSUMPTION]**, with
a cheap kill-shot test proposed in §7.

### 2.2 Answer to Q1

**No standing intermediate grid.** It is not the right strategy as a *general* resolution
step-down: on open coasts it buys percent-level accuracy for thousands of cells per spot, and
shoreward of 15 m all fine detail is the 1D model's job by design (brief §3.5).

**A conditional band is the right strategy for the exceptional spots.** Justified only when a
bathymetric anomaly with scales < ~400–500 m (canyon head, reef, ebb shoal off a jettied inlet)
lies between the 30 m contour and the handoff. Trigger it with a **setup-time alongshore-variance
test** on the already-cached MEDIUM bathymetry: along the 15 m contour within ± ~1 km of the spot,
compute depth variance after removing the alongshore mean profile; band on only above a threshold
(threshold to be set from a survey of known-anomalous vs plain spots — [ASSUMPTION]). If
triggered: a thin band, offshore edge at the 30 m contour, shoreward edge at the 15 m contour
(where the 1D model takes over), 30–40 m resolution, alongshore extent = anomaly + 2–3 anomaly
lengths. Nominal size ~1.7 km × 2 km at 40 m ≈ **2,100 cells** [example count; per-spot].

This keeps the answer aligned with brief §5 error 5: the question was "is refining *better*", and
the answer is "materially better only where sub-grid bathymetric structure exists; measurably
not, otherwise — and here is the measurement to run."

### 2.3 Corollary: a structure-only spot needs no coarse L3 at all

Today's L3 exists to carry the field from 15 m to ~1.75 m in 2D. Under this proposal that job
splits: the wedge does it where the structure's influence lives; everywhere else the open-beach
path (L2 → 1D at 15 m) — which is already the production path for every no-L3 spot — does it.
The operator has explicitly accepted non-uniform handoffs. At HB the wedge's ~±350–400 m
alongshore envelope covers the entire 313 m operator-drawn segment anyway, so every transect
would hand off from the wedge; nothing reverts.

**Nesting ratio note [SOURCE + ASSUMPTION]:** the wedge nests in L2 at 100 m → 12.5 m (8:1). The
SWAN manual imposes no fixed parent:child ratio (brief §3 confirmed; BOUNDNEST1 requires only
that the child boundary coincide with the NGRID rectangle). NESTOUT samples the boundary at the
parent's own resolution — ~6–10 L2 points per wedge side — which is adequate **provided the
boundary sits in smooth water**, which §3's margins guarantee (≥1 wavelength clear of the
structure). Flagged for verification on first run; the fallback (a 30 m collar grid around the
wedge, ~1,100 cells) is cheap and only added if boundary artifacts appear.

---

## 3. Q3 — shape and extent of the fine obstacle grid

### 3.1 Shape: a rotated rectangle, and why that is allowed here

SWAN grid options, from the manual [SOURCE]:

| Option | Supported for this use? | Why |
|---|---|---|
| Regular grid, rotated (`CGRID REG ... [alpc]`, `NGRID ... [alpn]`) | **Yes — recommended** | Full support for OBSTACLE, stabilized DIFFRACTION, nesting. |
| Curvilinear quadrilateral | Technically yes, not worth it | Child boundary must still *"conform to the rectangular coarse grid nest boundaries"* for BOUNDNEST1, or switch to POINTS/SPECOUT boundary plumbing. Extra machinery for marginal area savings over a rotated rectangle. |
| Unstructured (triangular) | **No** | The manual: diffraction's smoothing *"can not be applied in case of unstructured meshes"* — and this project's own hard rule (2026-07-19) forbids bare unsmoothed DIFFRACTION. Also loses the obstacle-through-gridpoint auto-nudge. |

**On brief §5 error 1 (rotation):** that ruling stands for what it ruled on — rotating the *L3
strip* to the beach bearing as an area fix, when the real inefficiency was resolution over open
water (§5 error 3). The wedge is a different case: it is a *nested* grid, and a nested grid
receives parent boundary spectra around its entire perimeter (NESTOUT/BOUNDNEST1), so swell
obliquity relative to the box orientation is immaterial — energy enters correctly through
whichever sides face the swell, every run, for any swell direction. Rotation here is purely an
area optimization around a fixed physical object (the structure), not an attempt to align with a
variable swell. For the HB wedge, rotation to the pier axis halves the cell count (§6:
16,128 → 5,120 at 12.5 m). The code currently hardcodes `alpc/alpn = 0` — enabling rotation is
one of the approval items.

### 3.2 Extent: structure + swell-climate shadow envelope + margins

Sizing rule (all quantities available at setup):

- **Along-structure axis:** from the breaking-depth contour (the existing ADR-093 Amendment 2 §2
  criterion — unchanged) to the structure's seaward tip **+ 1 peak wavelength** (L_tip ≈ 120 m at
  HB). The up-wave/offshore margin exists so the boundary is clear of the obstacle's near field.
  **Not the 15 m contour.** This is the single biggest cut: the 15 m offshore edge made sense
  when L3 was the general fine-detail model; the wedge's job is the structure.
- **Across-structure axis:** the union over the spot's swell-direction climate window of the
  geometric shadow cast on the shoreward edge, **+ 2 wavelengths** beyond the shadow boundary on
  each side. Basis [SOURCE]: for directional random seas the diffraction coefficient is ≈ 0.7
  along the geometric shadow boundary (Goda's diagrams; ≈ 1.4× the monochromatic value — brief §3
  verified) and recovers to within a few percent of 1 within ~2 wavelengths outside it; the
  strongly-modified zone in lab and diagram studies sits within **~2–4 wavelengths of the tip**.
  The operator's recalled "3–5 wavelengths in a wedge shape" is the right order: 3–5 L is a safe
  envelope; 2–4 L is where the action is. (Directional spreading is why the zone is small: real
  seas fill shadows — brief §3 confirmed.)
- Both sides are included when the climate window crosses the structure axis (at HB: S swells
  shadow the NW side, W/NW windswell shadows the SE side).

**Worked example, HB pier [MEASURED geometry, ASSUMPTION on pier-base position — §7]:** rotated
to the pier axis (221°): along-pier ≈ 1,000 m (anchor+30 m to tip+~120 m), across-pier ≈ 800 m
(±~400 m envelope). At 12.5 m: **80 × 64 = 5,120 cells.** At 10 m: 100 × 80 = 8,000. Same box
axis-aligned at 10 m: ~16,100 — rotation + tip-scaled resolution together are the 3–8× win.

### 3.3 Envelope at setup, not per-run reshaping

Size the wedge once, at config-push, for the spot's swell climate window. Reasons:

1. **"All SWAN grid geometry is fixed at setup time — no runtime overrides"** is a standing
   project rule earned on 2026-07-23 (runtime resize left the grid outside the NESTOUT and
   silently zeroed the swell). Per-run reshaping would repeal it.
2. Per-run reshaping re-runs bathymetry extraction per cycle and invalidates every per-bbox cache
   (`swan_bathymetry_L3_{hash}.json`, hotstarts — hotstart files are grid-shaped, so a moving
   grid can never warm-start).
3. The saving is small: the envelope wedge is already ~5k cells; a per-run directional wedge
   might halve that (~2.5k), saving ~1–2 min/day against real complexity and a repealed safety
   rule.

### 3.4 Structure-class taxonomy (operator's generalization requirement)

The wedge mechanics are identical for every class; what varies is the obstacle physics and
whether diffraction pays for itself:

| Class | SWAN obstacle treatment | Diffraction | Why |
|---|---|---|---|
| Pier (pile-supported) | `TRANSM 0.80–0.85` (§4, **pending approval**; today 0.95) | On, in the wedge | With Kt_h ≈ 0.8 the lee deficit is ~20% of height — shadow-edge shape now matters enough to justify the wedge it was already getting. |
| Jetty / groin (rubble, emergent) | existing `DAM GODA` | **On — this is where diffraction genuinely earns the wedge** | Near-total blocking → real shadows; Goda Kd ≈ 0.7/0.5 structure. |
| Breakwater (detached/harbor) | existing `DAM DANGremond` | On | Same as jetty; if span makes the wedge > ~15–20k cells, split carrier + tip grid (§1.3). |
| Seawall | existing `REFL 0.5` | Off | Shore-parallel at the grid's shoreward edge; no tip, no shadow to resolve. No wedge — represent in whatever grid covers the spot. |
| Natural refraction features (point/headland/bay) | none | Off | Not an obstacle; 2D **refraction** is the physics → coarse L3 at 30–40 m, extent per feature. Diffraction at 30–40 m is sub-resolution and would be dishonest anyway (it "disappears" as cells coarsen past L/10 — brief §3, consistent with the manual criterion). |

Multiple structures cluster exactly as spots do today: one wedge per cluster, oriented to the
cluster's principal axis. Jettied inlets typically also trip the Q1 variance band (ebb shoal).

---

## 4. TRANSM for a pile-supported pier

### 4.1 What the number means in SWAN [SOURCE]

Manual: the OBSTACLE transmission coefficient is *"formulated in terms of wave height, i.e. ratio
of transmitted significant wave height over incoming significant wave height."* So `TRANSM 0.95`
passes 95% of height = 90% of energy; the measured PT0–PT7 deficit (0.83 vs 0.87 ≈ 0.95) is the
model faithfully echoing its own input constant back — it is not evidence about the pier.

### 4.2 What the field evidence says [SOURCE]

Elgar, Guza, O'Reilly, Raubenheimer & Herbers (2001), *Wave energy and direction observed near a
pier*, JWPCOE 127(1):2–6 — the Duck, NC research pier: 561 m long, two rows of 47 steel piles,
1 m diameter, rows 5 m apart alongshore, bents 12.2 m apart cross-shore. Directly comparable
scale to HB pier (567 m, concrete piles). Findings:

- For obliquely incident waves, energy near the shoreline 200 m downwave was **up to 50% lower**
  than 400 m downwave.
- A refraction model over the measured bathymetry (including the ≤1.5 m scour depression under
  the pier) reproduced the far field, but near the pier required **"45% energy blocking by the
  pier pilings"** to match; the paper concludes 30–50% blocking, i.e. **Kt_height ≈ 0.71–0.84**.
- That is *"higher than implied by theories… for energy dissipation by the relatively widely
  spaced piles"* — the shortfall attributed to rough barnacle-encrusted piles, reflection and
  scattering. This is why the pile-*breakwater* formulas (gap ≤ 1 diameter) were rightly ruled
  non-transferable in brief §3 — but the field number replaces them, it does not soften them.
- The blocking is **strongest for obliquely-crossing components** (long ray path under the pier)
  and weak at near-normal crossing — at HB, swell from 201.9° crosses the 221° pier at ~19°,
  i.e. grazing, the high-attenuation geometry.

### 4.3 Recommendation

- **Adopt `TRANSM 0.82` (range 0.80–0.85) for the pier class** — the operator's hunch, now with a
  peer-reviewed field anchor of directly comparable scale. [Architectural change, trigger 1 —
  approval required.]
- Cheap honesty upgrade available later: SWAN's `TRANS2D` accepts direction-dependent
  transmission, which is the physically right shape (per-crossing loss grows as the crossing goes
  grazing). Not recommended now — one constant first, calibrate, then decide.
- **Calibrate against reality, not the model** (rules/verification.md): the observable is the
  alongshore Hs gradient across PT0–PT31 vs an independent reference (nearest CDIP/NDBC nearshore
  buoy, Surfline's per-peak reading, or operator observation) on an oblique-swell day.
- **Do not launder the trench through Kt.** If the HB DEM shows the scour depression, refraction
  over it is a separate, resolvable mechanism (§1.2); inflating Kt to cover a missing bathymetric
  feature would bake a site-specific bathymetry error into a physics constant.

---

## 5. Recommended target architecture (for approval)

Per-spot, decided once at config-push by the existing sizing chain:

```
open beach              L1 (1 km) → L2 (100 m) → 1D at 15 m           [unchanged]
refraction feature      + coarse L3: 30–40 m, no diffraction,
(point/headland/bay)      extent sized to the feature                  [replaces 10 m L3]
structure               + fine wedge "L4": Δx = min(L_tip/8, 15 m),
                          rotated to structure axis, stabilized
                          DIFFRACTION, class-appropriate OBSTACLE,
                          nested in L2 (or L3 if present)              [replaces 10 m L3]
bathymetric anomaly     + conditional 30–40 m band (variance test)     [new, conditional]
```

Handoffs (unchanged criterion, non-uniform locations — already accepted): transects covered by
the wedge hand off from it at the per-hour `1.3·Hs/0.73` depth; others from L2 at 15 m. The
deep-water reference SPECOUT stays on L2's 15 m contour (already the case). Hourly quick updates
(stationary, finest grid only) get ~8× cheaper along with everything else.

Diffraction stabilization scales with Δx (existing project formula εx = ½·√(3n)·Δx, target
εx ≈ 45 m): at 12.5 m, `smnum ≈ 17` (today `DIFFRACTION 1 0.2 27` at 10 m).

**Approval items (each names its trigger):**

1. Retire the 15 m-contour → breaking-contour 10 m L3 strip for structure spots; adopt the wedge
   (triggers 2, 3).
2. Wedge resolution rule Δx = min(L_tip/8, 15 m) instead of constant 10 m (trigger 3).
3. Rotated CGRID/NGRID emission (`alpc`/`alpn` ≠ 0) for wedge grids (trigger 3 + code change).
4. Pier `TRANSM 0.95 → 0.82` (trigger 1).
5. Coarse L3 at 30–40 m for refraction-classified spots, diffraction off there (triggers 1/3 —
   diffraction currently on at L3).
6. ~~Conditional bathymetric-anomaly band + its variance-test threshold (triggers 3, 6, 7 — new
   setup-time computation and cached artifact).~~ **⛔ STRUCK by §0A D2/D6** — no band, no variance
   test, no threshold, no survey. L3 is need-driven per D2.
7. Wedge bathymetry cache replaces the L3 fine cache (trigger 7 — persisted file keying).

---

## 5.1 Normative logic flow — follow this mechanically

This section is the single authoritative statement of the proposed control flow. It exists because
the same information is otherwise spread across §1–§5 and a future session hunting for it will get
it wrong. **If anything elsewhere in this document appears to conflict with this section, this
section wins.** (Approval status is unchanged: none of this is implemented; every step marked
[NEW] or [CHANGED] is an approval item from §5.)

### 5.1.1 Setup-time flow (config-push, once per spot cluster)

Runs inside the existing `run_grid_sizing_chain()` after L1 and L2 are sized (both unchanged:
L1 = shelf edge → shore at 1 km; L2 = shore → 30 m contour at 100 m).

```
INPUTS (all already available at this point in the chain):
  operator classification        (open | point/headland/bay)
  structures[]                   (Overpass/wizard; each has class + coordinates)
  cached FINE profile            (per spot; gives depth at any distance from anchor)
  contour distances from anchor  (breaking-depth contour, 15 m, 30 m)
  swell climate window           (spot's configured swell direction range)
  design Tp                      (spot's design swell period)

STEP 1 — wedge decision (structures):
  eligible = structures whose class ∈ {pier, jetty, groin, breakwater}
             AND which have usable coordinates
  # seawall is NEVER wedge-eligible — it is represented only as a REFL
  # OBSTACLE line in whatever grid covers it. Structures with no usable
  # coordinates: log WARNING, no wedge (silent-skip rule).
  FOR each cluster of eligible structures (cluster = existing <500 m grouping,
                                           principal axis = cluster's long axis):
      d_tip   = depth from FINE profile at the cluster's most-seaward point
      L_tip   = wavelength from the dispersion relation at (design Tp, d_tip)
      dx      = min(L_tip / 8, 15 m), never below 10 m            [CHANGED: was constant 10 m]
      build WEDGE:                                                 [NEW grid kind]
        orientation : rotated to cluster principal axis (CGRID/NGRID alpc ≠ 0)
        along-axis  : breaking-depth contour  →  tip + 1·L_tip
                      # NOT the 15 m contour. The old 15 m offshore edge is retired.
        across-axis : union of geometric shadows cast on the shoreward edge
                      over the swell climate window, + 2·L_tip each side
        physics     : DIFFRACTION 1 0.2 smnum   (smnum from εx ≈ 45 m: ½·√(3n)·dx)
                      OBSTACLE per class table (§5.1.2)
                      wind forcing ALWAYS (standing rule)
      run the existing viability test (grid must reach its feature — near-auto-pass)

STEP 2 — coarse-L3 decision (2D refraction):
  IF classification ∈ {point, headland, bay}:
      build COARSE L3: 30–40 m, extent per the existing feature-sizing logic,
      cross-shore span = 15 m contour → breaking-depth contour,
      DIFFRACTION OFF (sub-resolution at 30–40 m — emitting it would be dishonest),
      OBSTACLE lines included for any structure crossing the domain.  [CHANGED: was 10 m + diffraction]

STEP 3 — ⛔ STRUCK ENTIRELY BY §0A D2. There is no variance test, no
  threshold, and no conditional band. L3 is built only (a) as the nesting
  step under a structure grid, or (b) as the refraction grid at a classified
  point/headland/bay. Everything below in this step is dead text.
  approach-zone band decision (bathymetric anomaly):        [NEW, conditional]
  variance test: along the 15 m contour, ± ~1 km alongshore of the spot,
  depth variance after removing the mean cross-shore profile, on cached
  MEDIUM bathymetry. Threshold: operator-approved constant (§7 item 4).
  IF above threshold AND no coarse L3 was built:
      build BAND: 30–40 m, 30 m contour → 15 m contour, no diffraction,
      obstacles only if one crosses it.
  IF above threshold AND a coarse L3 exists:
      DO NOT build a separate band. Extend the L3's offshore edge from the
      15 m contour to the 30 m contour instead. One grid, never two grids
      stacked edge-to-edge (edge-on-edge nesting is degenerate).

STEP 4 — nesting chain assembly:
  order grids coarse → fine: L1 → L2 → (BAND | extended L3) → (L3) → (WEDGE)
  each grid nests (NGRID/NESTOUT → BOUNDNEST1) in the finest grid that fully
  contains its boundary with ≥ 2 parent cells of clearance on every side —
  in practice the WEDGE parent is L2 unless a band/L3 contains it.
  A spot may legitimately end up with: nothing (open beach), WEDGE only,
  L3 only, BAND only, or WEDGE + (L3 or BAND). Multiple wedges are allowed
  (one per structure cluster).

STEP 5 — cache exactly as today: DomainSizing → swan_grid_sizing.json,
  per-grid bathymetry at that grid's resolution, per-spot/per-transect
  profiles unchanged. Geometry is FROZEN from here — no runtime resizing,
  no per-run reshaping (standing rule, §3.3).
```

### 5.1.2 Per-grid physics table (runtime, every cycle)

| Grid | Resolution | DIFFRACTION | OBSTACLE | Wind | Runs |
|---|---|---|---|---|---|
| L1 | 1 km | off | no | yes | every full cycle |
| L2 | 100 m | off | yes, if a structure crosses it | yes | every full cycle |
| BAND / extended L3 | 30–40 m | **off** | yes, if crossing | yes | full cycles |
| Coarse L3 | 30–40 m | **off** | yes, if crossing | yes | full cycles |
| WEDGE | min(L_tip/8, 15 m) | **on, stabilized** (only grid with it) | yes — the class row below | yes | full cycles + hourly stationary quick updates (quick updates run the finest grid only, as today) |

Obstacle class table (the only physics rows; seawall included for completeness):

| Class | OBSTACLE params | Note |
|---|---|---|
| pier | `TRANSM 0.82` | [CHANGED from 0.95 — approval item 4; §4] |
| jetty | `DAM GODA 3.0 0.4 0.8` | unchanged |
| groin | `DAM GODA 2.0 0.4 0.8` | unchanged |
| breakwater | `DAM DANGremond 2.0 0.5 10.0` | unchanged |
| seawall | `REFL 0.5` | unchanged; never triggers a wedge |

### 5.1.3 Handoff selection (per transect, per forecast hour) — ⛔ SUPERSEDED BY §0A D3

> **DO NOT IMPLEMENT THIS SECTION.** The rule below — "read from the finest grid that covers the
> transect" — was ruled **wrong** by the operator on 2026-07-27. The governing rule is now
> **§0A D3: hand off as deep as possible; go shallower only where 2D physics still matters.**
> Retained only to show what was replaced.

The handoff **depth criterion is unchanged everywhere**: `1.3 × Hs(hour) / 0.73` when a fine/coarse
grid covers the transect; fixed 15.0 m (`L2_REFERENCE_DEPTH_M`) otherwise. **Only the source grid
varies.** Walk this list top-down, first match wins:

```
1. WEDGE exists AND the transect's per-hour handoff point lies inside it
       → read per-transect POINTS from the WEDGE at the per-hour depth.
2. Coarse L3 exists AND the handoff point lies inside it
       → read per-transect POINTS from the L3 at the per-hour depth.
3. Otherwise → hand off at fixed 15.0 m depth:
       from the BAND if one exists (finer alongshore sampling),
       else from L2.  (This is the unchanged open-beach path.)
```

- Neighbouring transects of one spot MAY resolve to different rules — that is the non-uniform
  handoff the operator explicitly accepted, not a bug.
- The deep-water reference SPECOUT stays on **L2** at the spot's own 15 m contour in every case
  (unchanged; the wedge never reaches it, so it can never supply it).
- The 1D model then runs from whichever handoff to shore on its own per-transect 3–5 m profile —
  shoreward of the handoff, cross-shore bathymetric fidelity is the 1D model's job at every spot,
  under every rule above.

### 5.1.4 Misreadings to guard against (each of these is wrong)

1. *"The wedge spans the 15 m contour to shore."* No — breaking contour to structure tip + 1
   wavelength. The 15 m offshore edge died with the old L3.
2. *"Resolution is 12.5 m."* No — 12.5 m is the HB *result* of `min(L_tip/8, 15 m)`. Derive it
   per spot; never hardcode.
3. *"Diffraction goes wherever there's a structure."* No — diffraction runs in the wedge only.
   At 30–100 m it is sub-resolution; emitting it there is both useless and destabilizing.
4. *"The band improves the surf zone."* No — the band ends at the 15 m contour. Shoreward of the
   handoff is 1D-model territory except inside a wedge/L3.
5. *"If both L3 and the band trigger, build both."* No — extend the L3 to the 30 m contour; one
   grid.
6. *"The wedge failed viability / swell moved, resize at runtime."* Never — geometry is frozen at
   setup (2026-07-23 rule). A wedge that can't reach its feature is disabled at setup, exactly
   like today's L3.
7. *"Seawall → wedge."* Never. REFL line only.
8. *"The wedge supplies the deep-water reference."* Never — that stays on L2's 15 m contour.

---

## 6. Cell counts and compute estimates (cross-cutting requirement)

Anchors [MEASURED]: 12,448 total cells (L1 567 + L2 5,530 + defective L3 6,351) → ~7 min full
cycle; 47,992 total (restored L3 41,895) → >75 min, did not complete (timeout 3600 s). Estimates
below scale wall-clock linearly with total cells from the 7-min anchor [ASSUMPTION — the measured
DNF at 48k shows the true curve is *worse* than linear at large sizes (diffraction convergence,
memory pressure at `omp_num_threads=6` on the ~1.7 GB box), which only strengthens the case for
small grids; small-grid estimates are the trustworthy end of the extrapolation].

| Design | Fine/coarse grid cells | Total cells | Est. full cycle |
|---|---|---|---|
| A. Restored spec (10 m strip, 15 m contour → shore) | 41,895 | 47,992 | **>75 min, DNF [MEASURED]** |
| (reference) this morning's defective small L3 | 6,351 | 12,448 | **~7 min [MEASURED]** |
| B. Operator sketch, literal: 30 m L3 strip + 10 m L4, axis-aligned | 4,674 + 16,128 | 26,899 | ~15 min |
| B′. 40 m L3 strip + 12.5 m rotated wedge | 2,623 + 5,120 | 13,840 | ~8 min |
| **C. Recommended: rotated 12.5 m wedge only (no coarse L3)** | **5,120** | **11,217** | **~6.3 min** |
| C10. Same wedge at 10 m (if L/10 strictness is wanted) | 8,000 | 14,097 | ~8 min |
| D. Cheapest defensible: 30 m strip, OBSTACLE only, no diffraction, no wedge | 4,674 | 10,771 | ~6 min |
| Q1 conditional band, when triggered (per spot) | +~2,100 | +~2,100 | +~1.2 min |

Option D is listed because it is the honest floor for the *pier* class specifically (transmission
deficit dominates at high Kt); it stops being defensible the moment Kt drops to jetty/breakwater
levels or the operator wants shadow-edge fidelity — C covers all classes with one mechanism for
~0.3 min more. B (the literal two-grid sketch) pays ~4 min/cycle for a 30 m open-water strip
whose only remaining job C reassigns to L2, which already does it for every no-L3 spot in
production.

---

## 7. What still needs measuring, and the self-audit

**Assumptions that need a measurement (each is cheap):**

1. **Pier-base position from the anchor** — §1's "124 m offshore of the spot pin" was read as the
   gap from pin to the pier's shoreward end (pier ≈ anchor+334 m to anchor+901 m). Verify against
   the Overpass way geometry before sizing anything.
2. **Tip depth ≈ 6.3 m** — linear interpolation between two measured contours; read it from the
   cached FINE profile instead.
3. **Does the HB DEM contain the pier scour trench?** One look at the cached FINE bathymetry
   under the pier line. Decides whether the trench-refraction mechanism (dominant at Duck) is in
   or out of our model, and whether 20–30 m bathymetric resolution near the pier carries real
   information.
4. **Q1 percent-level claim** — one A/B run at HB: L2-only handoff spectra at 15 m vs the same
   with a 30 m band, compare Hs/Tp/direction per transect. If the delta is ≥ a few percent,
   §2.2's conditional-band threshold needs lowering.
5. **8:1 nest boundary quality** — inspect the wedge's first live run for boundary artifacts
   (the L2-collar fallback is pre-sized: ~1,100 cells).
6. **Kt calibration day** — one oblique-swell day, modeled vs observed alongshore gradient (§4.3).
7. **Linear wall-clock scaling** — the first wedge cycle timestamps it for free.

**Self-audit — strongest objections I could raise against my own recommendation:**

- *"C deletes the coarse L3 that B kept — is anything lost?"* The strip's only unique product was
  2D field values between 15 m and ~1.75 m *away* from the structure's influence. Those transects
  revert to the L2-at-15 m path — the standard production path for every open-beach spot, and at
  HB specifically the wedge covers all 32 transects anyway, so nothing reverts. The loss is real
  only if Q1's variance test would have flagged the spot — in which case the conditional band
  fires and covers exactly the anomaly. This is a responsibility *reassignment to existing
  owners*, which is why it needs approval (trigger 2/3), not a silent simplification.
- *"Kt 0.82 rests on one paper."* True, and the paper itself says a detailed piling study was not
  possible (currents unmeasured, trench survey uncertainty fold into the 30–50%). That is why
  §4.3 pairs the change with a calibration observable rather than declaring it settled. It is
  still a far better basis than 0.95, which traces to nothing.
- *"The wedge's shoreward zone under-resolves diffraction (L/5.3)."* Acknowledged in §1.1; the
  tip criterion is met, the shoreward zone is breaking-dominated, and the 1D model owns the last
  word there. If shadow structure at the shoreward edge ever matters, dropping to 10 m (option
  C10) costs ~1.7 min.
- *"Rotation contradicts §5 error 1."* Addressed head-on in §3.1 — the ruling's physics reasoning
  binds boundary-forced strips, not fully-nested grids; and rotation here optimizes around a
  fixed structure, not a variable swell. If the operator prefers to keep everything axis-aligned,
  option C still works at 10 m axis-aligned (~16k wedge cells, ~15 min cycles) — the architecture
  survives, the factor-of-2 optimization is severable.
- *"Envelope wedge vs per-run wedge"* — §3.3; per-run reshaping repeals a safety rule for
  ~1–2 min/day.

---

## 8. Sources

- SWAN User Manual, Cycle III 41.51 — [DIFFRACTION and OBSTACLE (Physics)](https://swanmodel.sourceforge.io/online_doc/swanuse/node28.html);
  [CGRID](https://swanmodel.sourceforge.io/online_doc/swanuse/node25.html);
  [boundary/nesting incl. BOUNDNEST1](https://swanmodel.sourceforge.io/online_doc/swanuse/node27.html);
  [PDF](https://swanmodel.sourceforge.io/download/zip/swanuse.pdf).
- Elgar, S., Guza, R.T., O'Reilly, W.C., Raubenheimer, B., Herbers, T.H.C. (2001). *Wave Energy
  and Direction Observed near a Pier.* J. Waterway, Port, Coastal, Ocean Eng. 127(1):2–6.
  [PDF (WHOI)](https://www.whoi.edu/science/AOPE/dept/Publications/066_2.pdf).
- Goda, Y., Takayama, T., Suzuki, Y. (1978). *Diffraction diagrams for directional random waves.*
  Proc. 16th ICCE — [paper](https://icce-ojs-tamu.tdl.org/icce/article/download/3297/2965/14059);
  as consolidated in [CEM Part II-7, Fig. II-7-13](https://coastalengineeringmanual.tpub.com/Part-II-Chap7/Part-II-Chap70020.htm).
- Pile-breakwater literature (confirms non-transferability to widely-spaced pier piles):
  [Hayashi & Kano lineage; double-row pile studies (ICCE)](https://icce-ojs-tamu.tdl.org/icce/article/download/4372/4053/18375);
  [single-row pile breakwater hydrodynamics](https://www.sciencedirect.com/science/article/abs/pii/S0378383911000044).
- Project-internal: brief §1–2 live measurements; `services/swan_domain.py`
  (`smart_size_l3_grid`), `services/swan_formats.py` (`_OBSTACLE_PARAMS`, CGRID/NGRID emission,
  `DIFFRACTION 1 0.2 27`); ARCHITECTURE.md SWAN section; rules/clearskies-process.md 2026-07-19 /
  2026-07-23 incident rules.

---

## ADDENDUM (2026-08-01, Phase R doc-sync pass) — §3.1/§3.2's "rotated to the pier axis" design superseded

**§3.1's rotation and §3.2's extent rule (above) describe the ORIGINAL illustrative design (AD-4, "L4 axis from
the OMBB"), which never reached a converged deployment** — Gate G4 failed (the sized grid landed on land) and
was replaced 2026-08-01 by a beach-frame transect-shadow-envelope design (marine `4e79d21`, ADR-093 Amendment 6).
Kept above for the record — **do not implement §3.1/§3.2 as written.** Current design:

- **Rotation** — the resolved **beach facing** (the AD-1R shoreline-strip-derived bearing), never the structure's
  own axis. §3.1's "rotation here is purely an area optimization around a fixed physical object" framing no
  longer applies; rotation now serves alignment with the transects, not a cell-count optimization around the
  structure.
- **Extent** — the beach-frame bounding rectangle of every eligible structure's footprint UNION the handoff
  points of every surf-area transect any one of them shadows (per-structure shadow test against the ADR-100
  fetch-fan's open rays), not §3.2's swell-direction-climate-window shadow + fixed wavelength margins. The
  shoreward edge is the minimum-`u` shadowed-transect handoff point (the ADR-093 `l3_shoreward_edge_depth_m()`
  ≈1.78 m contour on each transect's own profile), not the structure's breaking-depth-contour-to-tip axis.
- **No primary-structure selection** (same-day amendment): every eligible structure in a cluster participates in
  the one L4 grid.

The shadow-decay research this brief's §3.2 cites (Goda diffraction diagrams, the ~2–4 wavelength strongly-
modified zone) remains valid physics background — see the parallel addendum in
`SWAN-OBSTACLE-BEST-PRACTICES-2026-07-29.md` for the fuller citation list (SWAN manual 1–2λ, CEM ~20λ, Duck FRF
pier 200–400 m). It informed the ORIGINAL across-structure-axis margin, not the current per-transect handoff-
based extent. See PROVIDER-MANUAL.md §14.15 and ADR-093 Amendment 6 for the adopted design.
