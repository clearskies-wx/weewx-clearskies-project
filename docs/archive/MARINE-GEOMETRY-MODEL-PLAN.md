# Marine Geometry-Model Plan — geography-aware study-area geometry (2026-07-30)

> ## ⛔ ARCHIVED 2026-08-02 — executed through G4, remainder EXTRACTED
>
> Approved + executed 2026-07-31 (Phase D, G0, G1→G1R, G2, G3, most of G4); suspended same day by
> the publish regression (Phase R); **suspension lifted and plan closed 2026-08-02** — see the
> Execution-status section for the full closing record. **AD-4 (OMBB L4 axis) and G4.2 (primary-
> structure clustering) are SUPERSEDED** by the 2026-08-01 L4 transect-shadow-envelope rewrite
> (marine `4e79d21`, ADR-093 Amendments 6/7). Open remainder (G1R.3, G5, G6, G7, Gate GR) lives in
> **`docs/planning/MARINE-FORWARD-PLAN.md`**. This file stays as the AD-1R..AD-8 architecture and
> history record; execute nothing from it.

**Status:** ARCHIVED (see banner). Previously: DRAFT — COMPLETE for operator review. Architecture decisions (AD-1..AD-8), OFF-LIMITS fence (incl. the
SWAN-syntax rule), phases G0–G7 + per-phase gates + Gate GR, the verbatim SWAN-syntax appendix, and the full
carry-forward audit are all written. **Approving this plan approves the architecture.**
**Created:** 2026-07-30
**Origin:** `docs/planning/briefs/STUDY-AREA-GEOMETRY-BRIEF.md` (Fable-reviewed twice, 24 findings incorporated;
coordinator-verified against live code) + operator design directions in chat 2026-07-30.
**Supersedes:** `MARINE-WORKING-MODEL-PLAN.md` — Track A's *content* is done or carried forward here (§Carry-forward
audit); Track B is **reshaped** into this plan's geometry-integrated structure track; Phase 5's open items are
carried. `MARINE-WORKING-MODEL-PLAN.md` is retired to reference once this plan is approved.

**⚠ APPROVING THIS PLAN APPROVES THE ARCHITECTURE.** Every design decision is stated in
§"Architecture decisions" below, each with its rationale and which architectural trigger it hits. There is **no
separate blocking sign-off gate** — operator approval of this plan authorizes the whole architecture. The granular
tasks then reference those decisions as **settled**; agents implement them, they do not design.

**NOTE TO ALL IMPLEMENTING AGENTS:** This plan tells you the file, the line, the current code, and the exact
change. **You are here to CODE and QC, not to design.** Do not restructure, do not "improve," do not choose an
approach — the approach is written below and in §"Architecture decisions." **Read §"OFF LIMITS" before touching
anything** — it names the working code you must not modify. If a change you are told to make trips the
architectural block in a way not already covered by an Architecture decision here, STOP and surface to the
coordinator; do not proceed under an assumption. If the code does not match the line/quote given here, STOP and
report the drift — do not hunt for "what was probably meant."

---

## Prime directive

The single-cross-shore-facing model — one beach-normal per spot, offshore = the beach's perpendicular — is
**inadequate for the US settings this system must serve** (curved shores, point breaks, bays, island-sheltered
coasts, the Great Lakes). This plan replaces the *derivation* of where and which way the model looks — beach
facing, transect bearing, L1 aim, the WaveWatch III boundary sides, exposure, and the study-area basis — with a
**geography-aware** determination grounded in bathymetry isobaths and the actual open-water geometry, and it
**automates** those parameters instead of asking the operator to type them.

**It does NOT re-open the working model.** The 2D→1D handoff, the sizing formulas, the convergence gate, the
hotstart mechanism, the HAT landward boundary, the deep-water reference, and L1/L2/L3 axis-alignment are all
**off limits** (§"OFF LIMITS"). This plan changes *what bearing/exposure/open-water-direction is passed into the
existing, working sizing and handoff code* — not the math that consumes it, and not the parts of the pipeline
that already validate against reality.

**Non-negotiable check:** because the per-transect bearing flows into the shadow classification and thus the
headline aggregate, **the served headline must be re-validated against the contemporaneous cam** (the Phase-3
pinned tolerance) after the geometry change lands — see Gate GR.

---

## Implementation discipline — MINIMAL DELTA, NO REFACTORING, SHIP IT

**This is an implementation plan, not a refactor. Make the prescribed change and STOP.** Recent plans dragged for
days by turning a scoped change into a cleanup. That is banned here — speed is a first-class goal.

- **Change only what the task names.** Do not rename, restructure, extract helpers, re-order, re-format, or "tidy"
  adjacent code — even if it looks improvable. If you open a file, touch only the lines the task cites.
- **Smallest change that passes the accept criteria.** Prefer adding a parameter or a branch over rewriting a
  function. The OFF-LIMITS fence says what you may not touch; **this rule says don't touch *anything* beyond the
  task even where touching it would be allowed.**
- **No opportunistic cleanup.** A defect you notice that your task does not name → **log it to the concerns file,
  do not fix it inline** — unless it BLOCKS your task, in which case make the smallest fix that unblocks and log it.
- **If a task tempts you toward a large rewrite, you have mis-read it.** Re-read the AD and OFF-LIMITS, take the
  minimal path, or STOP and surface.

**Coordinator enforcement:** at every acceptance gate, a diff that touches files/lines the task did not name is a
**FAIL** — send it back to minimal delta (scope-block discipline, `rules/agents.md`). A phase that is ballooning
is a signal to re-scope to the minimal delta, not to keep going.

---

## Autonomy & escalation — run this plan WITHOUT babysitting

**The architecture is approved (this plan). Within it, RESOLVE — do not escalate.** The coordinator runs
Phase D → G0 → … → Gate GR autonomously through the gates.

**Operator touchpoint is ONE: this approval.** Gates G2/G3/G4/GR each require a **live SWAN run on librewxr** (SWAN
exists only there), reached via `scripts/deploy-marine.sh` (which pushes to GitHub + pulls to librewxr). **RESOLVED
(operator, 2026-07-31, chat): the coordinator has standing permission to push/deploy as necessary for testing** —
so the coordinator runs the gate-validation deploys autonomously, and the plan runs from approval through every
gate with no further push touchpoint. (This is the operator's explicit in-chat authorization that `rules/agents.md`
requires; it is scoped to **testing / gate-validation**, not a public production cutover — which is out of this
plan's scope anyway.) The only other stop is a genuine blocker *outside* the approved architecture (rare).

**AD-1..AD-8 are pre-approved architecture — implementing them does NOT trip the architectural-change
block.** The block still binds for anything genuinely OUTSIDE the ADs and this plan.

**Question-resolution order (every agent AND the coordinator):**
1. **Answer it from the governing docs** — ARCHITECTURE.md, the manuals, the ADRs, the briefs. Updated in Phase D
   to the approved architecture, they answer the large majority of implementation questions. Read them first.
2. **Answer it from this plan** — the AD designs, the OFF-LIMITS fence, the SWAN appendix.
3. **NON-BLOCKING and the docs genuinely cannot answer it** → log one entry to
   `docs/planning/MARINE-GEOMETRY-MODEL-CONCERNS.md` (what · where · why non-blocking · the assumption made) and
   **keep going** on a reasonable, documented assumption. Do **not** stop the run or ping the operator.
4. **STOP and surface to the operator ONLY IF** the issue is (a) genuinely BLOCKING (cannot proceed at all) **AND**
   (b) outside the approved architecture (a trigger not covered by any AD). Because the architecture is approved,
   this should be rare.

**The concerns file is triaged later** (at a phase boundary or after the plan lands), never mid-task. A
non-blocking gap never justifies stalling.

---

## Execution status — LIVE (keep this updated)

**Legend:** ✅ done+verified · 🔄 in progress · ⛔ blocked · ⬜ not started

- **Plan authored** — ✅ (architecture decisions, off-limits, phases G0–G7 + gates, SWAN appendix, carry-forward audit).
- **Operator review/approval** — ✅ granted; autonomous execution 2026-07-31.

### Phase completion (2026-07-31)

- **Phase D** (governing-doc updates) — ✅ committed (meta `34d2db0`).
- **G0** (foundations: `region.py`, OMBB `structure_geometry.py`, `geography.py` + KATs) — ✅ committed (`200c657`, `311f74a`, `efbff4d`, `3360ddb`, `c10ba7d`).
- **G1** (isobath-normal facing + per-transect bearings + runtime wiring + self-check + KATs) — ⛔ **implemented, but the beach-facing METHOD is WRONG — see Critical finding 1.** Commits `53ba649`, `1787b6a`, `5524e1f`, `c1cc889`, `08fb5d1`. Everything downstream that consumes `beach_facing_degrees`/per-transect bearings inherits the bad angle. **Replacement approved 2026-07-31: AD-1R / PHASE G1R** (⬜ not started).
- **G2** (L1 aim + WW3 sides from open water) — ✅ implemented + deployed (`38f93ac`, `8f76af8`; deployed librewxr `4828d99`). Gate G2 (real SWAN L1 converged; D6c ≥2 stations) passed.
- **G3** (exposure from fan → L4 sizing + surf-scorer + optional override + D6b L4 cold-start) — ✅ implemented + deployed (`edf831f`, `829d634`, `f788611`, `ab97929`). Gate G3 (sizing chain + D6b no-op) passed — **but did NOT re-validate a converged 4-level run** (see Critical finding 2).
- **G4** (L4 axis from OMBB + obstacle route/coeffs + invariant-3 rescope + proximity clustering) — 🔄 code implemented + deployed (`37acb0c`, `418f1f5`, `5dbce94`, `6a8c18e`, `2597011`; clustering `02ef999` local-only). The obstacle emission (`OBSTACLE TRANSM 0.74` 2-vertex OMBB centerline) and the invariant-3 rescope validated live. **⛔ Gate G4 FAILED — see Critical finding 2.**
- **G5 / G6 / G7 / Gate GR** — ⬜ not started → **EXTRACTED 2026-08-02 to `MARINE-FORWARD-PLAN.md`**
  (G1R.3 likewise). Execute them from there, not from this file.
- **⛔ PLAN SUSPENDED 2026-07-31 (operator direction):** the 11:13 deploy of `4828d99` (G2 + the
  G1 facing wiring) broke publishing entirely — see the corrected TC-21/TC-23 and
  `MARINE-MODEL-RESTORATION-PLAN.md` **PHASE R**, which now owns recovery, the test audit, the
  brief→plan reconciliation, and the QC hardening. **No further G-phase work until Gate R passes.**
- **✅ SUSPENSION LIFTED + PLAN CLOSED/ARCHIVED 2026-08-02:** Gate R substantively passed (final
  record in `MARINE-MODEL-RESTORATION-PLAN.md`). **Gate G1R's failure is retroactively RESOLVED**:
  the root cause (L4-grid-coverage vs transect-handoff envelope, TC-23) was fixed by Phase R (R7
  handoff containment, `2087fc1`) and then properly by the **L4 transect-shadow-envelope rewrite**
  (marine `4e79d21`, 2026-08-01 — supersedes AD-4's OMBB L4 sizing and G4.2's primary-structure
  clustering; operator-approved architectural delta, recorded in ADR-093 Amendments 6/7). Verified
  live 2026-08-01: facing 217.0° (AD-1R), **L4 valid_fraction 100%**, 143 transects × 67/67
  timesteps on their own bands, publish + reality gate PASS. Still-open content of this plan
  (G1R.3, G5, G6, G7, Gate GR) lives in **`docs/planning/MARINE-FORWARD-PLAN.md`** — G6 is
  REWRITTEN there in plain terms (operator found this plan's AD-6/G6 wording impenetrable);
  G5 carries an evaluate-benefit-first gate. This file remains the architecture/history record
  for AD-1R..AD-8 (AD-4 superseded) — execute nothing from it.

### Critical findings — BLOCKING (surfaced to operator 2026-07-31; logged as TC-21 in `MARINE-GEOMETRY-MODEL-CONCERNS.md`)

1. **Beach-facing method (AD-1 / G1) is fundamentally wrong — must be replaced.** `isobath_normal_bearing` ray-casts to the **2 m and 5 m depth contours** and line-fits them. That measures *offshore*, where sandbars, channels, and the pier's own scour bend the contours away from the actual beach line. For Huntington it returns **202°**; the true beach-facing (perpendicular to the straight beach = the pier direction) is **~220°**.
   - **Correct method (operator-approved 2026-07-31): AD-1R — the DSAS/CliffMetrics smoothed-shoreline normal.** Trace the **0 m shoreline** from the finest bathymetry as an ordered polyline, smooth its coordinates over an alongshore window swept **500 → 2500 m until the heading stabilizes**, take the **seaward perpendicular** of the smoothed line's local tangent. Computed **at spot SETUP time, persisted on the spot** — NOT during model runs — and **operator-overridable** (wizard pre-fills the computed value). The operator-drawn segment is for the **study area only, never the facing** (the facing was originally an operator-given bearing, removed at T2.1, that G1 was meant to automate — with this method, not the ray-fit). **Full pinned design + equations in §AD-1R; implementation tasks in §PHASE G1R.**
   - **Additional defect found 2026-07-31 (code archaeology):** the production call site (`grid_sizing_chain.py:1142`) hands the ray-fit the **1 km L1 grid** — its 300 m search radius is smaller than a single grid cell, so the "contour fit" was bilinear-interpolation noise independent of the method's own conceptual flaw.
   - **Validated:** a smoothed-0 m-shoreline heading on the native profile bathymetry near HB → **~214°, tightening toward ~220° as the smoothing window widens** (the AD-1R Option-B sweep converging), vs the broken 202°.
2. **Gate G4 FAILED — the L4 grid lands on land.** The 10 m surf-zone grid is **35% dry land**; **25 of 32 transect handoff points fall on dry cells**; L4 convergence = **27.3%** valid (gate requires ≥80%). SWAN itself converged (99.82% of wet points); our quality gate correctly rejected the result. Cause: the wrong beach-facing (transects aimed ~18° off, walking onto the sand) compounded by the G3 (exposure-driven width) and G4 (OMBB axis) grid changes. **Process gap:** neither Gate G2 (L1-only) nor Gate G3 (sizing + D6b) re-ran a converged 4-level nest, so this went undetected until the G4 gate. The last verified 4-level convergence was the pre-G4 baseline (`4828d99`, L4 at 80.3%).
   - **⛔ CORRECTED 2026-07-31 (measured; see TC-21/TC-23 corrections in `MARINE-GEOMETRY-MODEL-CONCERNS.md`):** the "lands on land / 35% dry" framing is disproven by the preserved run artifacts — the L4 grid is **100% wet** and all 96 handoff stations are **wet but OUTSIDE the grid** (4–56 m shoreward of its frozen shoreward edge). The regression window is **not G3∪G4** (L4 geometry byte-identical across those deploys): the 95%-valid era ran `beach_facing=238.0°`, and the break coincides with the live facing flipping to 201.9° at the `4828d99` deploy + 11:16 config push. The "80.3% baseline" was itself already degraded (95.0–95.4% every run before that push).
3. **Serve-on-failure bug (operator priority).** When a run fails the convergence gate, the service **still caches and serves** a forecast off the coarser grid (silent "degrade to L3"). **A failed run must serve nothing.** Not yet fixed. Site: `providers/nearshore/swan.py` caches each spot (`spots_cached += 1`, ~line 3122) with no convergence check.

### Next actions (agreed with operator, in order)

1. **Serve-nothing-on-failure guard** — a run that fails convergence publishes nothing. → **G1R.0**.
2. **Replace G1 beach-facing with AD-1R** — the DSAS/CliffMetrics smoothed-shoreline normal (pinned equations), computed at spot setup, persisted per spot, operator-overridable. → **G1R.1–G1R.4**.
3. **Re-validate the L4 grid lands in the water** — operator-directed order (2026-07-31): facing fix first, then ONE full 4-level re-run at **QC Gate G1R** (which re-tests Gate G4's criteria); the TC-21 bisect only if still failing.

> **Scope note:** AD-1's design paragraph and PHASE G1's task specs below still describe the superseded isobath ray-fit — kept for the record. **Do NOT implement the ray-fit; implement AD-1R (which carries the operator-required pinned equations) via PHASE G1R.**

### PHASE G1R execution (2026-07-31) — facing fix DONE; Gate G1R FAILED (architectural, surfaced)

- **G1R.0** serve-nothing-on-failure guard — ✅ done + accepted (marine `8cce0a5`; librewxr 9/9; frozen convergence gate untouched). A convergence-failed run now publishes nothing.
- **G1R.1** `shoreline_normal_bearing` + strip fetch + KATs — ✅ done + accepted (marine `7f07075`; librewxr 13/13; all pinned AD-1R equations/constants coordinator-verified verbatim; genuine known-answer tests).
- **G1R.2** rewire chain/`compute_spot_transects` to AD-1R; restore `beach_facing_degrees`/`beach_facing_source` config keys; delete `isobath_normal_bearing` — ✅ done + accepted (marine `73df829`; librewxr 63/63; 0 isobath hits).
- **G1R.4** (partial) doc-sync — ✅ ADR-093 Amdt 5 AD-1R subsection + PROVIDER-MANUAL §14.15 rewrite (meta `0fb110c`). Operator-Manual wizard narrative deferred to land with G1R.3.
- **G1R.3** definition-time wizard flow (`/geometry/facing` + API pass-through + apply models + wizard pre-fill) — ⬜ NOT started (held; not required for the gate nest — the chain recomputes the facing at config-push).
- **QC Gate G1R** — ⛔ **FAILED. Facing known-answer PASS (HB resolved to 217.0°; 202° did not reproduce), but the clean full 4-level re-run's L4 `valid_fraction` = 7.1% (needs ≥80%) — worse than TC-21's 27.3%.** The facing fix is confirmed working and is DISPROVEN as the root cause; the root cause is the L4-grid-coverage-vs-transect-handoff-envelope (architectural triggers 2/3). **Surfaced to the operator (TC-23).** *(Mechanism corrected 2026-07-31: grid 100% wet; all stations wet but outside the frozen shoreward edge; operator ruled L4 need not cover the fan — the defect is in handoff routing + the L4 valid_fraction gate's fan⊂L4 assumption. See TC-23 correction.)* The TC-21 bisect (pre-G4/pre-G3 isolation) is the operator-pre-authorized next diagnostic step but was NOT auto-run — surfaced because the result is worse than decision-6's premise and the fix is architectural. Marine service stopped on librewxr to halt the failing retry loop.

---

## Architecture decisions (APPROVED BY APPROVING THIS PLAN)

Each decision is the **completed design**. The rationale and the exact trigger are stated so approval is informed.
Producers/consumers and file anchors are pinned from live code (verified 2026-07-30). **Operator directions from
the 2026-07-30 chat are recorded here (Fable flagged they had no paper trail otherwise):** AD-3 (L1 aim from open
water), the L2 coverage-driven framing (AD-1 note), and the supersede-not-amend structure.

### AD-1 — Shore-facing is the isobath-normal, derived per-transect (replaces segment-perpendicular)

> **⛔ METHOD SUPERSEDED 2026-07-31 by AD-1R (below).** The isobath ray-fit produced a wrong facing (Critical
> finding 1: 202° vs true ~220° at HB). AD-1's *intent* stands — a derived, per-transect, geography-aware facing;
> coverage-driven L2/L3 sizing — but its *method* (the 2 m/5 m contour ray-fit in the Design paragraph below) is
> dead. **Do not implement the Design paragraph below; implement AD-1R.** The sizing-aggregation paragraph
> (coverage-driven) remains in force unchanged.

**Trigger 1** (changes how the bearing is derived — a method/criterion). Implements the documented-but-unbuilt
SURF-ZONE §2.6 design; **reopens ADR-093 Amendment 2 §3** (contour-orientation derivation, previously deferred).

**Design.** `beach_facing_degrees` and each transect bearing are derived from the **local shallow-isobath heading**
(the 2 m / 5 m depth-contour trend from the setup-time bathymetry), **smoothed** over a scale ≈ surf-zone width to
a few hundred metres (the ~300 m study segment is the natural alongshore extent), taken **perpendicular** (seaward
sense) as the shore-normal. It is **per-transect** where the shore curves and collapses to a single value on a
straight beach. Isobath heading is **datum-robust** (a datum shift slides a contour, barely rotates it), sidestepping
the DEM-0 m datum sensitivity. **Producers:** `marine_config.py:506-510` (the property), `swan_formats.py:752-753`
(the `[transect_bearing]*n` list; advances the existing `v2 future` comment at `:750`). **Consumers are unchanged**
— they already take a bearing: `find_shoreline_from_grid` (`bathymetry.py:1368`), `find_depth_contour_distance`
(`bathymetry.py:1413`), `compute_transect_shadows` (`swan_formats.py:769`).

**Sizing aggregation (operator framing 2026-07-30):** L2/L3 size is **coverage-driven** — L2 is a stepping-down of
L1 and must enclose the L3/L4 grids and every transect across all spots. With per-transect bearings, the offshore
contour is measured **per-transect** and L2 **encloses the union** (the covering envelope it already computes),
not a single representative bearing. The bearing's only role in sizing is the direction the contour distance is
measured along.

### AD-1R — Beach facing = smoothed-0 m-shoreline normal (DSAS/CliffMetrics), at setup, operator-overridable — REPLACES AD-1's ray-fit
**Approved by the operator in chat 2026-07-31** (ledger). **Trigger 1** (replaces the facing-derivation method
inside AD-1) **+ Trigger 7** (re-introduces `beach_facing_degrees` as a stored config key with a source tag; one
new cached shoreline-strip bathymetry file per spot; one new marine geometry endpoint + API pass-through for the
definition-time computation; wizard help-content doc-sync).

**⛔ Scope constraints (operator corrections, 2026-07-31, chat):** (1) the computation runs at
**spot-DEFINITION time** and depends on **NOTHING but the drawn segment** — no SWAN grid, domain, or sizing
exists yet (L1–L4 are sized AFTER, *from* this facing), and none may be assumed anywhere in the implementation;
(2) it is defined for **every** spot, including open beaches with **no structures — no L4 (and possibly no L3)
grid ever exists there**; zero dependency on obstacle discovery or grid levels.

**Why AD-1's method failed:** the ray-fit measured the **2 m/5 m offshore contours** — bent by sandbars, channels,
and the pier's own scour — within a **300 m** radius, and the production call site (`grid_sizing_chain.py:1142`)
handed it the **1 km L1 grid**, so the 300 m search sampled bilinear noise inside a single cell. HB: 202° vs ~220°.

**Method basis (researched 2026-07-31):** USGS **DSAS** (Digital Shoreline Analysis System) smoothed-baseline
transect casting — transects cast perpendicular to a baseline smoothed over a "smoothing distance" (recommended
500 m, max 2500 m; analyst widens until transects sit perpendicular — AD-1R automates that loop as the Option-B
sweep) — and **CliffMetrics v1.0** (Payo et al. 2018, GMD 11:4317): trace the shoreline from the DEM, smooth the
polyline coordinates with a moving-average window scaled to physical length, cast each normal perpendicular to the
smoothed line's local before/after tangent.

**Design — ALL equations pinned (operator directive 2026-07-31: implementing agents implement EXACTLY this math;
do NOT re-derive, substitute, or "improve" it).**

Work per spot in a local east/north meter frame about the segment midpoint `M = (lat0, lon0)`:

```
x_e(lat, lon) = (lon − lon0) · cos(lat0 · π/180) · M_LAT          # meters east
y_n(lat, lon) = (lat − lat0) · M_LAT                              # meters north
bearing(Δx_e, Δy_n) = (atan2(Δx_e, Δy_n) · 180/π + 360) mod 360   # compass deg, 0 = N, clockwise
```

`M_LAT` = the existing `_M_PER_DEG_LAT` constant. **Pinned constants:** `W_MIN = 500.0 m`, `W_MAX = 2500.0 m`,
`W_STEP = 500.0 m`, `STABILITY_TOL_DEG = 5.0`, `TRACE_DEPTH_M = 0.0`, `MAX_CROSS_SEARCH_M = 1000.0`.

- **Step 0 — shoreline-strip bathymetry (⛔ NO SWAN-GRID DEPENDENCY — operator correction 2026-07-31).** This
  runs when the surf spot is **being DEFINED in the wizard** — NO SWAN domain, no L1/L2/L3/L4 sizing, no grid
  caches exist yet (they are sized AFTER, *from* this facing). **Every input derives from the drawn segment
  alone:** bbox = segment midpoint ±(W_MAX + 250 m) along the segment bearing × ±1000 m along the provisional
  perpendicular (~5.5 km × 2 km). Fetch through the **existing bathymetry downloader mechanics**
  (`download_bathymetry_for_level(..., margin_resolution_m=…)` / the `swan_bathymetry_PROFILE_*` bbox-keyed
  cache pattern, `providers/nearshore/swan.py:285-304`) with a cache key derived from the **segment bbox** — an
  implementation that requires a `GridDomain`/sized SWAN domain as input is WRONG; construct the coverage box
  directly from the segment. Request the **FINE tier (~10 m — the heading gains nothing from 3 m)**; degrade to
  MEDIUM (100 m) + WARN (operator decision 4, 2026-07-31); neither covers → raise (no silent fallback — the
  wizard then pre-fills the segment-perpendicular tagged `fallback`, below).
- **Step 1 — trace the 0 m shoreline (ordered polyline).** Seed stations `s_i = M + i·Δ·û`, `i = −N..N`, `û` =
  unit vector along the drawn segment's bearing, `Δ` = the strip grid's native resolution (m), `N = ceil(W_MAX/Δ)`.
  At each station find the `TRACE_DEPTH_M` crossing along the provisional facing (the segment-perpendicular,
  searched both senses, ≤ `MAX_CROSS_SEARCH_M`) by the existing signed-depth zero-crossing (linear interpolation
  between consecutive samples of opposite sign: signed depths `s1, s2`, positive = underwater → crossing at
  fraction `t = s1 / (s1 − s2)` from sample 1). Stations with no crossing are dropped. The surviving points `p_i`,
  ordered by `i`, ARE the polyline — the alongshore seeding provides the ordering (no wall-follower needed).
  **Degenerate flags (CliffMetrics-style):** a consecutive-point gap > `5·Δ` → WARN, split at the gap, keep the
  contiguous run containing the anchor; fewer than `max(7, round(W_MIN/Δ))` points in that run → the whole call
  falls back to the segment-perpendicular + WARNING (the existing fallback contract).
- **Step 2 — smooth (per window W).** Point spacing `Δs = median(|p_{i+1} − p_i|)`. Half-width in points
  `k(W) = max(1, round(W / (2·Δs)))`. Moving average of the coordinates:
  `p̂_i(W) = (1/(2k+1)) · Σ_{j=i−k..i+k} p_j`, defined only where full ±k support exists; an anchor lacking full
  support uses the largest symmetric window available (log the actual meters used).
- **Step 3 — tangent + seaward normal at an anchor.** Anchor index `a = argmin_i |p_i − q|` where `q` = the
  segment midpoint's shoreline crossing (spot facing) or the transect's own coastline anchor (per-transect).
  Tangent by CliffMetrics' before/after rule on the SMOOTHED line: `v = p̂_{a+1}(W) − p̂_{a−1}(W)`; line heading
  `θ_line = bearing(v) mod 180`; normal candidates `θ_line + 90` and `θ_line + 270` (mod 360). **Seaward sense:**
  the existing signed-depth probe from G1.1's implementation, UNCHANGED — probe both candidates, keep the deeper
  (more positive signed depth); unresolvable → the fallback contract.
- **Step 4 — stability sweep (operator "Option B", 2026-07-31).** For `W_j ∈ {500, 1000, 1500, 2000, 2500}` m
  (capped at the largest window the surviving run supports; cap < `W_MIN` → fallback + WARN), compute `θ_j` via
  steps 2–3. Circular difference `δ(a,b) = min(|a−b| mod 360, 360 − |a−b| mod 360)`. **Answer = the first `θ_j`
  (j ≥ 2) with `δ(θ_j, θ_{j−1}) ≤ STABILITY_TOL_DEG`.** No pair stabilizes → the largest-window `θ` + WARNING
  listing every `(W_j, θ_j)`. Log per anchor: the window cap, each `(W_j, θ_j)`, the settled window. (Smooth once
  per `W` for the whole polyline; every anchor then reads its own tangent — the sweep is O(points × 5).)
- **Step 5 — per-transect bearings.** Steps 2–4 with `q` = each transect's own coastline anchor. Collapses to one
  value on a straight beach (KAT); fans with real curvature exactly as AD-1 intended.
- **Step 6 — invocation sites, storage, consumers (operator-corrected 2026-07-31: definition-time, chicken-and-egg
  resolved).** TWO invocation sites, one algorithm:
  1. **Spot-DEFINITION time (the authoritative facing).** When the operator draws the segment, the wizard calls a
     **new marine-service geometry endpoint via the API** (marine is reached only through the API — INVARIANT;
     suggested routes `POST /geometry/facing` on marine, passed through the wizard's existing `/setup/*` channel —
     exact names aligned to API-MANUAL conventions at G1R.4). Request carries ONLY the segment endpoints; the
     service fetches the strip (step 0), runs steps 1–4, and returns the computed facing + the per-window sweep
     log. The wizard **pre-fills** the facing field with it; the operator may adjust; the confirmed value is
     **STORED IN CONFIG** (`beach_facing_degrees` returns as a stored key — T2.1 removed it; this restores it)
     with a source tag `beach_facing_source ∈ {operator, computed, fallback_segment_perp}` (`operator` = the
     operator adjusted the pre-fill; `computed` = untouched AD-1R result; `fallback_segment_perp` = the strip
     fetch/trace failed at wizard time and the segment-perpendicular was pre-filled + flagged in the UI).
  2. **Config-push time (`run_grid_sizing_chain()`) — per-transect bearings + fallback retry.** The chain reads
     the stored facing (it does NOT recompute a `computed`/`operator` facing) and runs the SAME helper over the
     cached strip for the **per-transect bearings** (step 5) — replacing BOTH production call sites of
     `isobath_normal_bearing` (`grid_sizing_chain.py:1142` — which today hands the ray-fit the 1 km L1 grid —
     and `swan_formats.py:803`) — **before the 30 m contour search**, so the facing feeds the contour-measurement
     directions and the existing G1.6 profile-cache persistence + G1.6/TC-15 write-backs (unchanged in shape).
     A `fallback_segment_perp`-tagged facing IS recomputed here (deterministic retry now that the fetch may
     succeed); on success the resolved value is persisted and logged — the config tag stays `fallback` until the
     operator re-visits the wizard (config is operator-owned; the chain never rewrites it).
  Never computed during model runs. Consumers of the bearing value untouched; sizing formulas untouched
  (OFF-LIMITS). **`isobath_normal_bearing` and its KATs are DELETED in the same commit** — added by this plan's
  own G1, superseded before ever being right; do not leave dead code.

**Operator override semantics (approved 2026-07-31).** `beach_facing_source = "operator"` wins at every consumer;
the derived value is still computed and logged for comparison (parity with `directional_exposure`, G3.3). With an
operator override, **per-transect bearings are UNIFORM = the override** (an operator asserting a facing asserts
one facing; curved-shore spots should not override). Help-content doc-sync per process rules. **Apply-contract
sync (the 2026-07-11/07-15 lesson):** the wizard sends `beach_facing_degrees` + `beach_facing_source` in the
apply payload → the API's `ApplyRequest`/marine apply models MUST accept both (models are `extra="forbid"`), and
the config writer persists them — verified end-to-end at the gate.

**Datum robustness:** carried over from AD-1 — a vertical-datum shift slides the 0 m line but barely rotates its
heading over ≥ 500 m; grids are per-cell LMSL-converted anyway (T8.11b).

**AD-5 note:** the traced smoothed shoreline polyline (steps 1–2 output) is the natural curvature input for G5's
break-type classification — G5.1 should read this polyline instead of the "G1.1 isobath analysis" it cites.

**References:** USGS DSAS v5 User Guide (smoothing distance 500 m rec., 2500 m max); Payo et al. 2018,
*CliffMetrics v1.0*, Geosci. Model Dev. 11, 4317 (wall-follower trace, coordinate moving-average, before/after
tangent normals, window-scales-with-resolution finding); DSAS v5.1 data releases (500 m in practice).

### AD-2 — Fetch/openness fan + water-body classification-first + derived exposure (new subsystem)
**Trigger 2** (classification drives regime — a responsibility) **+ Trigger 7** (new OSM-coastline data source +
new module; removes the `directional_exposure` wizard field → wizard help-content doc-sync).

**Design.** A new module (`services/geography.py`) run **first** at config time, per study area:
1. **Water-body classification** — open ocean / semi-enclosed / enclosed basin / Great Lakes — via the **existing
   coarse regional** `classify_region` (`bathymetry.py`, reused/extended per AD-7) plus coastline geometry.
   Selects the physics regime and its parameters.
2. **OSM coastline layer** — fetched at config time by **Overpass query** for `natural=coastline` within the
   study-area download footprint (the same Overpass mechanism the wizard already uses for structure discovery),
   cached like bathymetry (bbox-keyed). No global land-polygon file is shipped. **On Overpass unavailable →
   error, no silent fallback** (rules/coding.md §1) — OSM is the one layer that must be reachable. **Verified
   2026-07-30:** a live Overpass `natural=coastline` query for the HB bbox returned usable inline geometry
   (HTTP 200, 46 KB, ~2 s; multiple coastline `way`s with lat/lon point arrays via `out geom`).
3. **Fetch/openness fan (WRAP-AWARE — the fan sizes the domain; SWAN computes the wave).** Cast rays at 5°
   increments (72 rays) from the study-area centroid out to the regime horizon (ocean: the shelf-edge scale L1
   reaches; Great Lakes: the lake fetch). **A ray that hits land does NOT stop** — it continues and tests whether
   **open ocean resumes beyond** the land within the horizon. Classify each direction:
   - **directly-open** — open ocean in the direct line;
   - **wrap-candidate** — land in the direct line but **open ocean beyond it** (a peninsula/headland/island with
     open water on the far side): **the point-break case**, where the swell refracts/diffracts around the land;
   - **truly-blocked** — land to the horizon with no open ocean beyond (the back of a bay, a deep cove).

   Yields (a) **exposure** — directly-open **and wrap-candidate** count as EXPOSED, truly-blocked as sheltered
   (replaces the typed 8-sector `directional_exposure`); and (b) the **open-water bearing** for AD-3.
   **CRITICAL — the fan does NOT decide how much energy arrives; SWAN does.** For every directly-open and
   wrap-candidate direction, L1 is sized to **enclose the open water AND any intervening land**
   (peninsula/headland/island) and the WW3 boundary is placed on the open-water side; SWAN then computes the
   actual refraction/diffraction wrap-around at the spot. This is the **"islands are MODELLED, not flagged"** rule
   (§6.4) extended to headlands and peninsulas. The fan is a **domain-sizing + boundary-side-selection aid and a
   coarse openness descriptor — never the final exposure verdict** (the modeled wave field is). The fan's
   look-past-land horizon is the L1 scale: open water reachable only far beyond it (a spot deep inside a bay) is
   left out, and SWAN correctly returns near-zero there.
   **What the fan's fetch VALUE feeds:** water-body classification, exposure, the open-water bearing (AD-3), and
   **sizing L1 in the Great Lakes** (no shelf edge, AD-3). It does **NOT** feed a 1-D wind-sea growth term —
   wind-sea *generation* is SWAN's job (GEN3 physics from the wind field; the GLWU boundary for the Great Lakes).
   The Young & Verhagen 1-D term (working-model Phase F) is **dropped from scope** (Carry-forward audit).
4. **"Boxed-in" spots** are a natural limit, not a special case: if no direction has sufficient open water/fetch,
   the exposure computation says so directly (no surfable waves).

**Consumers:** L4 sizing (`compute_structure_grid_domain(directional_exposure=…)`, `swan_domain.py:1803`,
`:1998-2003`) and surf-scoring (`enrichment/surf_scorer.py`) now read the derived exposure; L1 aim + WW3 sides
read the open-water bearing (AD-3).

### AD-3 — L1 offshore aim and WW3 boundary sides come from open water, not the beach bearing
**Trigger 3** (a model extent/boundary input moves). **Operator direction, 2026-07-30.** Resolves Phase-5 D6c
(as a validation gate, not a pre-marked fix — AD note).

**Design.** `_compute_level1` aims its offshore extension along the **open-water bearing** (AD-2), not
`mean_offshore_bearing_deg` (`swan_domain.py:980-988`); `ww3_station_selection`'s offshore-side selection uses the
same open-water bearing (`swan_domain.py:31-41` docstring confirms it is the single shared source, C-94). L1 and
L2 **remain axis-aligned** — this changes the *aim/extent*, not rotation. **Islands, headlands, and peninsulas in
a swell corridor (AD-2 wrap-candidate):** L1 is enlarged to **enclose the intervening land and the open water
beyond** so SWAN computes the wrap-around (§6.4; the point-break case — model the geometry, do not flag it).
**Great Lakes:** L1 is sized by lake-geometry/fetch (no shelf edge; `find_shelf_distance` has no lake branch today
— `shelf_boundary.py:60-67` returns the nearest *ocean* shelf, oversizing L1). The GLWU WW3 product routing already
exists (`ww3_station_selection.py` `product_for_extent`).

**D6c note.** D6c (enlarged-L1 Bolsa → 0 qualifying WW3 stations) is **not** pre-resolved: its root cause was never
diagnosed (the two-spot lateral-union enlargement and catalogue density near the boundary are candidates alongside
the aim). Root-cause it, then validate with the real 2-spot Bolsa station-selection run (Gate G2).

### AD-4 — One oriented-bounding-box primitive; L4 axis from it; multi-obstacle proximity clustering

> **⛔ SUPERSEDED/REVERSED 2026-08-01 (operator-approved, ADR-093 Amendment 6).** This design (below) was
> implemented (G0.1/G4, `37acb0c`/`418f1f5`/`5dbce94`/`02ef999`) but never reached a converged deployment — Gate
> G4 failed and the AD-1R facing fix (PHASE G1R) did not resolve it either (see Critical finding 2 / QC Gate G1R
> above: an OMBB axis rotates independently of the cross-shore transects the grid must supply a handoff to, so
> co-registration was coincidental). Replaced by a beach-frame transect-shadow-envelope design (marine `4e79d21`,
> R3 residual "L4-transect co-registration") that also drops the primary-structure/proximity-group narrowing
> (G4.2 below) entirely — see ADR-093 Amendment 6 and `docs/manuals/PROVIDER-MANUAL.md` §14.15 for the current
> design. Text below is the historical record of what was approved and attempted — **do not implement.**

**Trigger 2** (L4 axis method + sizing). **Sequence D6b (L4-only cold-start guard) BEFORE any L4 resize.**

**Design.** A new `services/structure_geometry.py` provides an **OMBB helper** (shapely `minimum_rotated_rectangle`
— already a dep; no OMBB helper exists in the repo today). It is built **once** and consumed by **both**:
(a) the obstacle router (Track B T4.0/T4.1 — centerline+width of the *structure polygon alone*); and (b) the L4
axis in `compute_structure_grid_domain`, replacing the `_most_distant_pair` two-point axis (`swan_domain.py:1904-1911`)
with the OMBB of the *obstacle-plus-shadow* (single) or *merged-cluster* footprint. **Same helper, different call
geometry.** Re-deriving the axis from the OMBB **must re-anchor tip/base selection** (`_most_distant_pair` also
feeds tip-depth + the 1-wavelength along-axis margin, `swan_domain.py:1904-1939`; tip = farther-from-anchor).
**Multi-obstacle clustering:** obstacle boxes **merge when < 500 m apart** (`cluster_distance_m = 500.0`,
`swan_domain.py:567`); **minimum box size = 200 m × 200 m (20 × 20 cells at 10 m)** so each box resolves its
obstacle + shadow. **Separate-box multiple-L4-grids is DEFERRED** (G4.2) — far-apart obstacles give L4 to the
primary structure, the rest logged to concerns; this plan ships **merged-single-grid** clustering only.

### AD-5 — Break-type derived from curvature drives the L3 trigger; drop the operator classification field
**Trigger 1/2/7.** **Amends ADR-093 Amendment 2 §3** (which chose operator classification precisely because
contour-shape derivation "is specified nowhere and built nowhere" — this plan builds it).

**Design.** Point-break / headland / bay classification is **derived** from the measured shoreline/isobath
curvature (the same isobath analysis AD-1 builds), and becomes the **L3-enable trigger** (which currently reads
`topographic_feature`, ARCHITECTURE.md:105). The operator `topographic_feature` field is **dropped as a required
input**; classification is retained only as an **optional override** for a sub-grid feature bathymetry cannot see
(e.g. a submerged reef). Wizard field removal → help-content doc-sync.

### AD-6 — OSM is the study-area basis; two-stage (OSM bootstrap → bathymetry refine)
**Trigger 2/7.** Closes the current trace-on-OSM / size-from-DEM inconsistency (brief §1 defect 4).

**Design.** **Stage 1 (OSM, global, coarse):** coastline, water-body classification, the fetch fan, and the
bathymetry download footprint; **L1** (super-sized, axis-aligned) is frozen after this stage. **Stage 2 (local
bathymetry):** the precise per-transect facing (AD-1) and the inner nests (L3/L4) + transects. **Self-check:**
stage-1 OSM coastline heading vs stage-2 isobath heading — agreement ⇒ trust both; sharp divergence ⇒ auto-flag
(bad OSM coastline *or* anomalous bathymetry). No separate flagger. **Bathymetry availability gates region
expansion** (US-only today for that reason); OSM is the only layer that must be truly global.

### AD-7 — Reuse the existing coarse regional classifier for the geometry regime; do NOT add a third, do NOT merge
**Trigger 2** (a responsibility placement). **Design — corrected after reading both functions (they are NOT
duplicates).** The two same-named `classify_region` functions serve **different taxonomies**:
- `enrichment/bathymetry.py:341` → the **coarse 5-region coastal** set (`REGION_PACIFIC/ATLANTIC/GULF/HAWAII/
  GREAT_LAKES`) that already drives bathymetry source order, vertical datum, the WW3 product, and tide.
- `enrichment/fishing_species.py:248` → a **finer 11-region biogeographic** set (`BIOGEOGRAPHIC_REGIONS`, e.g.
  `atlantic_se`) for species zones.

They answer different questions — **merging them is a bug.** The geometry **water-body regime** (open ocean /
semi-enclosed / enclosed basin / Great Lakes) is the coarse-coastal question, so it **reuses/extends
`bathymetry.py`'s `classify_region`** (which already has `REGION_GREAT_LAKES`) — promoted to a shared
`services/region.py` only if a clean import boundary is wanted, **NOT a third classifier**. The fishing
biogeographic classifier is **left as-is**; the only optional cleanup is renaming one to stop the same-name
collision. **Agents must NOT collapse the two into one function.**

### AD-8 — Obstacle representation (Track B, folded in): bathymetry-injection fork + static cited coefficients
**Trigger 1 (coefficient constants) + Trigger 7 (new data path: structure → BOTTOM). Approved by this plan** — this
folds the working-model Track B architectural sign-off items into the geometry plan so they need **no separate
mid-run sign-off** (autonomy). Sources agents read directly: `SWAN-OBSTACLE-BEST-PRACTICES-2026-07-29.md`,
`BATHYMETRY-STRUCTURES-BEST-PRACTICES-2026-07-29.md`, working-model plan T4.1–T4.3.

**Design.**
- **Line-vs-footprint fork** (a SWAN OBSTACLE line carries no width; real width lives only in the bathymetry): a
  structure **≥ 3 L4 cells (~30 m) wide AND solid** (`breakwater|jetty|groin|seawall|mole`) → **burn its footprint
  into the L4 BOTTOM** as emergent cells, no OBSTACLE line; everything else (all piers; any solid structure < 3
  cells) → **OBSTACLE line** on the simplified OMBB centerline. **`shapely` only — no `rasterio`** (deps unchanged).
- **Static, cited per-type coefficients** (values from the research brief / T4.3; `Kt` is a wave-HEIGHT ratio):
  pier `TRANSM 0.74` (Elgar 2001, ~45 % energy blocking); seawall `REFL 0.9 RSPEC` (smooth vertical / sheet-pile,
  JMSE 2021); breakwater/jetty/groin keep their current static `DAM …` forms. **Dynamic per-segment crest `Rc` and
  Seelig–Ahrens reflection are DEFERRED** (need data no config carries) — a Phase-5 design task, not this plan.
- **Presence check (no double-count):** a structure already emergent in the DEM → **skip injection** (gate on
  emergent-cell fraction ≥ 0.65 AND an elevation-anomaly ridge), logged.

**SWAN-emission note:** touches OBSTACLE `TRANSM`/`REFL` and `BOTTOM.txt` **values** only — the OBSTACLE and
INPGRID/READINP BOTTOM **syntax is unchanged** (verbatim appendix). Implemented in G4.3/G4.4/G4.5.

---

## OFF LIMITS — what agents must NOT touch

**These are working, validated, or deliberately-frozen. Do not modify, refactor, "clean up," or "improve" them.
A change here is architectural and out of this plan's scope — STOP and surface.**

**⛔ SWAN INPUT SYNTAX IS VERBOTEN TO TOUCH unless a task explicitly requires it (operator directive, 2026-07-30).**
A single wrong token fails the entire run. The geometry work changes the **values** fed into the existing, working
SWAN emission — grid coordinates/extents, the L4 rotation `alpc`, which `SIDE` gets the WW3 boundary — it does
**NOT** rewrite the code that formats `CGRID` / `NGRID` / `INPGRID` / `READINP` / `BOUNDSPEC` / `OBSTACLE` /
`NESTOUT` / `BOUNDNEST1`. Rule:
- **(a) Default — do NOT touch SWAN command emission.** Change only the computed values that flow into it. Every
  such task states **"VALUE change only — SWAN emission unchanged."**
- **(b) In this plan, NO task requires new SWAN command emission.** The one candidate — multi-obstacle → multiple
  L4 grids — is **DEFERRED** (G4.2, merge-only). Every task is value-changes into the existing emitter. The
  verbatim-syntax appendix is **reference-only** (to confirm a "value-only" claim, and for a future multi-L4
  follow-up); if a future task ever needs emission, it must be explicitly flagged and **copy the appendix exactly,
  never invent.**
- **(c) If an agent finds a change cannot be made value-only** and would require touching emission that the task
  did not flag — **STOP and surface.** Do not improvise SWAN syntax.

1. **The 2D→1D handoff surface and control flow** — `services/transect_handoff.py` `select_hourly_handoff()`, the
   first-match L4→L3→L2 logic, the per-transect handoff decoupling (working since T1.2b `d803d9c`), the
   interior-station clamp (TA-C23). This plan does **not** change where or how the handoff is selected.
2. **The sizing FORMULAS and constants** — handoff depth `1.3 × Hs / γ`, **γ = 0.73**, `_MIN_DESIGN_HS_M = 1.0`
   (→ 1.78 m), the 30 m / 15 m contour criteria, tier resolutions (L1 1 km / L2 100 m / L3 40 m / L4 10 m fixed),
   the nesting ratios, the shadow-union + 2λ formula, the smnum smoothing formula. **You change WHICH bearing/
   exposure/open-water-direction is passed in — never the formula that consumes it.**
3. **The convergence gate** — `swan_runner.py` `_check_convergence` (T0.1 hardening) and its thresholds.
4. **The hotstart mechanism** — the split-COMPUTE + timestamp fix (T0.3) and the stale-hotfile guard.
5. **The all-stationary COMPUTE sequence** and directional resolution (`CIRCLE 72`).
6. **The HAT landward boundary** (ADR-093 Amdt 4) and the SwellTrack profile truncation.
7. **The deep-water reference = always L2 @ the spot's own 15 m contour** (never L3/L4) and INVARIANT_7.
8. **The WW3 boundary station *qualification* criterion** (`deep water OR tanh(kd)`, the depth/agreement test) and
   the `BOUNDSPEC SIDE VARIABLE FILE` emission mechanics. **Only the aim/side *input* changes (AD-3), never the
   qualification math or the emission format.**
9. **L1/L2/L3 axis-alignment** — only L4 rotates. This plan changes L1's *aim/extent*, not its rotation.
10. **`decompose_spectrum`** (`swan_spectral.py`) — unused in production, kept for `compare_partitioning.py`. Do
    not delete or wire it in.
11. **Any Track A working path not named in the Carry-forward audit** — the spectrum/handoff/reality machinery
    that already matches the cam for current conditions.

**If a task seems to require touching any of the above, it is either mis-scoped or architectural — STOP and
surface to the coordinator. Do not work around it.**

---

## Orientation — execution context

| Thing | Value |
|---|---|
| Marine service | `librewxr` (192.168.7.22), unit `weewx-clearskies-marine.service`, port **8780** (TLS) |
| Marine repo (local) | `repos/weewx-clearskies-marine/` (host: `/home/ubuntu/repos/weewx-clearskies-marine/`) |
| SWAN binary | `/usr/local/bin/swan` (41.51AB, OpenMP, `omp_num_threads=6` — do not change) |
| SSH | `ssh -F .local/ssh/config librewxr "<cmd>"` (repo cmds `sudo -u ubuntu`; containers read-only) |
| Deploy | `scripts/deploy-marine.sh` (restarts + verifies /health, /manifest, auth) |
| Tests | on librewxr: `sudo -u ubuntu .../.venv/bin/python -m pytest <targeted file> -q` |
| Local docs | `docs/reference/swan-user-manual.txt` + `swan-commands-extract.md` — **NEVER download SWAN docs** |

**Agent assignments:** Coordinator (Opus) — orchestration, QC gates, reality validation, deploy (operator types
"push"). `clearskies-api-dev` (Sonnet) — marine-service Python. `clearskies-test-author` (Sonnet) — guards +
known-answer tests. `clearskies-auditor` (Sonnet) — adversarial, blind to impl work product. **Every agent prompt
carries the git-restrictions block and the architectural-change block verbatim (`rules/agents.md`).**

**Governing-document updates (ADRs, ARCHITECTURE.md, the manuals) are Coordinator/Opus-owned and are NOT delegated
to Sonnet agents** — they *encode the architecture the coding agents then read as source of truth*, so getting them
right is judgment work, not mechanical editing. **Phase D is entirely Opus-owned and must land before any code
phase.** Per-phase doc-code sync still applies afterward for implementation specifics (help-content strings, exact
field lists), but the target-architecture docs are set up-front in Phase D.

---

## Phase overview

| Phase | Goal | Architecture decisions | Key net-new vs modify |
|---|---|---|---|
| **D (docs)** | **Governing-document updates — Opus/Coordinator-owned; MUST land before ANY G-phase** | AD-1..AD-8 recorded | ADR-093 Amdt 5 + new geography ADR; ARCHITECTURE.md; PROVIDER-MANUAL; OPERATIONS/Operator Manual; API-MANUAL |
| **G0** | Foundations: the shared primitives everything depends on | AD-7, AD-4 (helper), AD-2 (OSM+fan module skeleton) | NET-NEW: `structure_geometry.py` (OMBB), `services/geography.py` (OSM coastline + fetch fan), `region.py` (consolidated classify_region) |
| **G1** | Isobath-normal facing + per-transect bearings | AD-1 | MODIFY producers `marine_config.py:506`, `swan_formats.py:752`; sizing aggregation |
| **G2** | Geography-aware L1 aim + WW3 sides + D6c gate + Great Lakes L1 + islands | AD-3 | MODIFY `_compute_level1`, `ww3_station_selection` side-select, `shelf_boundary` lake branch |
| **G3** | Exposure from the fan + L4 across-axis re-size (**after D6b**) + surf-scorer wiring | AD-2 | MODIFY `compute_structure_grid_domain` exposure input, `surf_scorer`; **D6b first** |
| **G4** | L4 axis from OMBB + multi-obstacle clustering + Track-B obstacle mechanics | AD-4 | MODIFY L4 axis; NEW clustering; fold Track B T4.1/T4.2/T4.3 |
| **G5** | Break-type from curvature → L3 trigger; drop `topographic_feature` | AD-5 | MODIFY L3-enable trigger; wizard field removal (stack repo) |
| **G6** | OSM study-area basis + two-stage + self-check; draw-tool polygon (T4.6) | AD-6 | Wire stage-1/stage-2; T4.6 (stack repo) |
| **G7** | Carry-forward: Track A remainder + Phase-5 items | — | See Carry-forward audit |
| **Gate GR** | **Reality re-validation** — served headline vs contemporaneous cam after geometry (Phase-3 pinned tolerance) | — | The non-negotiable check |

Ordering constraint: **Phase D (docs) before ANY G-phase** — agents read the governing docs to code, so those docs
must already describe the approved architecture (agents-read-source-docs rule, `rules/agents.md`). **G0 before all
G-code** (shared primitives). **D6b (in G3.0) before any L4 resize (G3/G4).** Stage-1 (G6) freezes L1 before
Stage-2 facing (G1) in execution, but G1's producer change can land first behind the existing pipeline; the
two-stage wiring (G6) sequences them at runtime.

---

## Carry-forward audit (from `MARINE-WORKING-MODEL-PLAN.md` — full task-by-task, NOT its summary)

**Do NOT trust the source plan's execution-status summary — it conflicts with its own task detail** (it lists
T2.3 as remaining while T2.3 is DONE + Gate-2 audited, `plan:1165-1186`). Verified state, 2026-07-30:

**Track A — genuinely open, carried into G7:**
- **T1.3** re-verify C-E07 + curve-clip on live code — 🔄 unblocked, not started.
- **T2.2 PART B** — the half-applied handoff-advancement fix (LATENT/low priority; guard never moves a station at
  HB today) — carry as a residual.
- **T2.3 residuals ONLY** — operator **push/deploy**; the deferred **first-genuine-multi-swell-day** reality
  validation; the auditor **CLAIM-2** dominant-by-energy divergence check. **Do NOT re-implement T2.3** (done
  `6f525b2`, KAT `7d52e68`, Gate-2 audited, deploy-hold lifted).
- **T3.1** reality validation vs Surfline (pinned tolerance) — carry; folds into Gate GR.
- **Phase F (Young & Verhagen 1-D wind-sea term) — DROPPED from scope (operator, 2026-07-30).** SWAN already grows
  wind sea over the **real domain fetch**, and the Great Lakes get their wind sea via the **GLWU** boundary + SWAN
  growth — the same architecture as the ocean, not a 1-D term. The 1-D handoff-to-shore strip is too short for
  meaningful fetch-limited growth, and **no small inland lakes are in scope** (only large surface areas: ocean +
  Great Lakes). The `services/wind_sea_growth.py` kernel stays in the repo, **unwired**. If a real wind-sea gap
  ever surfaces at a reality check, it is a **SWAN wind-forcing/physics** investigation, not a 1-D addition.
- **M1 closure items:** TA-C16 (66 h vs 72 h window), the **formal blind audit** of the full served forecast, and
  **larger/multi-swell-sea revalidation** (validated at ~1 m only).
- **Cadence/performance lever** — approved + gate-cleared ("hourly 0–24 then ~6-hourly to 72"); ready once magnitude
  is confirmed. Carry.
- **TA-C21** invariant-3 rescope (OPEN operator decision, now geometry-coupled — G4/T4.4).
- **TA-C22 fixes (a)/(b)** — modelStatus grading (trigger 4) + transect-31 PT* gap root-cause.

**Phase 5 (Track C) — carried:**
- **D6a** `grid_sizing_chain.py:1270` StructureConfig-vs-dict type bug — **fix before/with the geometry chain edits**
  (it lives in the exact chain G1/G2 touch).
- **D6b** extend the geometry cold-start guard to L4-only changes — **PREREQUISITE for G3/G4 L4 resizing.**
- **D6c** enlarged-L1 Bolsa → 0 WW3 stations — **validation gate in G2** (root-cause, then validate; not pre-resolved).
- Deferred **T4.3 dynamic coefficients** (per-segment DAM crest Rc, Seelig–Ahrens) — separate signed-off design task.
- **C-E10/C-E11** (marine API URL / OFS 404), **C-E01/C-E03** (Bolsa adjacency), **C-E04** (bathymetry re-fetch),
  **C-E08** (L4 INPGRID WIND), **C-E12** (boundary train/period), **D7** (publish policy), **doc drift** — STAND.

**Track B mechanics folded into G4/G6 (still-valid, reshaped):** T4.0 (OMBB — now AD-4/G0), T4.1 (route by kind),
T4.2 (bathymetry injection — sign-off gate stands), T4.3 (coefficients — sign-off each), **T4.5 (coord round-trip
guard — proceed as-written, independent of geometry)**, T4.6 (draw-tool polygon — merge with G6 OSM UX).

---

## Operator decisions ledger

- **2026-07-30 — Approving this plan approves the architecture** (operator, chat). No separate blocking sign-off.
- **2026-07-30 — L1 offshore aim + WW3 boundary sides move from the beach bearing to the geography-aware open-water
  determination** (operator, chat). Recorded per Fable (no other paper trail). → AD-3.
- **2026-07-30 — L2 size is coverage-driven** (must enclose L3/L4 + transects across all spots; stepping-down of
  L1), not bearing-driven (operator, chat). → AD-1 sizing note.
- **2026-07-30 — Supersede `MARINE-WORKING-MODEL-PLAN`, do not amend in place** (operator, chat).
- **US + Great Lakes now** (operator, brief §6). Non-US intricate coasts out of near-term scope; architecture must
  not preclude them.
- **2026-07-30 — SWAN input syntax is VERBOTEN to touch unless a task specifically requires it** (operator). Default
  is value-changes into the existing emission; any genuinely-required emission change is flagged and carries the
  verbatim manual syntax (see "SWAN input syntax — verbatim reference" appendix). Agents copy exactly, never invent.
  See OFF-LIMITS.
- **2026-07-30 — Phase F (Young & Verhagen 1-D wind-sea term) DROPPED from scope** (operator). SWAN + GLWU already
  model wind-sea *generation* for every in-scope large water body (ocean + Great Lakes); the 1-D term is redundant
  and stays unwired (see Carry-forward audit). **No re-record required.**
- **2026-07-31 — `topographic_feature` retained as an optional L3-trigger override** (operator, chat). Auto-derived
  break-type is the default (AD-5); the field stays for sub-grid features bathymetry can't see (e.g. submerged reefs).
- **2026-07-31 — TA-C21 (invariant-3 shadow rescope, trigger 1) resolved via this plan** — G4.6 rescopes it after
  the per-transect bearing change; no separate mid-run sign-off.
- **2026-07-31 — T4.6 draw-tool polygon mode approved** (was "only if operator approves" in the working-model plan)
  — via this plan, G6.3.
- **2026-07-31 — Track B separate-box multiple-L4-grids DEFERRED to a follow-up** (Fable review): a 6-point runner
  rewiring touching frozen machinery; this plan ships merged-single-grid clustering only (G4.2).
- **2026-07-31 — Coordinator has standing permission to push/deploy as necessary for testing** (operator, chat).
  The gate-validation SWAN runs on librewxr deploy autonomously; the plan runs from approval through every gate with
  no per-gate push touchpoint. Scoped to testing/gate-validation, not a public production cutover.
- **2026-07-31 — AD-1's facing METHOD replaced by AD-1R** (operator, chat): the DSAS/CliffMetrics
  smoothed-0 m-shoreline normal, equations pinned verbatim in §AD-1R — the operator explicitly required the
  equations in the plan; implementing agents must not derive their own math. The isobath 2 m/5 m ray-fit is dead;
  `isobath_normal_bearing` is deleted with the replacement.
- **2026-07-31 — `beach_facing_degrees` optional override key approved** (operator, chat): the system computes
  and pre-fills the facing in the wizard; an operator adjustment round-trips as the override and wins (trigger 7).
- **2026-07-31 — Smoothing "Option B" stability sweep approved** (operator, chat): windows 500 → 2500 m in 500 m
  steps; settle at successive-heading change ≤ 5° (`STABILITY_TOL_DEG = 5.0`, pinned); never-stable → largest
  window + WARN. (DSAS itself does not self-tune — this automates the analyst loop its user guide prescribes.)
- **2026-07-31 — Trace at 0 m** (operator, chat), not CliffMetrics' +1 m infrastructure offset; the heading is
  threshold-insensitive; revisit only if the HB known-answer test shows structure contamination.
- **2026-07-31 — MEDIUM (100 m) strip fallback accepted** (operator, chat) when the FINE tier cannot cover the
  window (decision 4).
- **2026-07-31 — Gate-G4 recovery order** (operator, chat): land the facing fix, run ONE full 4-level nest at
  QC Gate G1R (re-tests Gate G4's criteria), and bisect per TC-21 only if L4 coverage still fails.
- **2026-07-31 — Shoreline-strip fetch CONFIRMED, with two operator corrections** (operator, chat): a new
  ~5.5 km × 2 km bbox per spot through the existing bathymetry-downloader mechanics (one new cached file per
  spot, trigger 7) — needed because NO existing grid spans the 500–2500 m alongshore window. Corrections:
  (1) **chicken-and-egg** — the facing is computed when the surf spot is being DEFINED; nothing may depend on
  SWAN grids/domains existing (they are sized AFTER, from this facing) — the strip bbox and cache key derive from
  the drawn segment alone; (2) **no-L4 reminder** — a spot with no obstacles never has an L4 (and possibly no L3):
  the facing + per-transect bearings are defined for every spot with zero dependency on structures or grid
  levels. The definition-time flow's new marine geometry endpoint + API pass-through is approved as part of this
  (trigger 7). `beach_facing_degrees` is stored in config with `beach_facing_source ∈ {operator, computed,
  fallback_segment_perp}`; only `operator` is an override.

---

## Granular tasks

**Every task below carries: owner · files+lines · current code (when modifying) · exact change/spec · off-limits
reminder · verification command · accept criteria · the AD it implements.** Agents read the AD and the cited
source lines directly; the coordinator does not paraphrase them. **Current-code quotes are content-normalized —
match on CONTENT, not exact whitespace/line-wrapping; a formatting-only difference is NOT drift (do not STOP). A
*semantic* mismatch (genuinely different code) IS drift → STOP and report.** **Every agent prompt carries the git-restrictions
and architectural-change blocks verbatim (`rules/agents.md`).** *(Phase D + G0–G7 + all gates written.)*

---

### PHASE D — Governing-document updates (Opus/Coordinator-owned; precedes EVERY G-phase)

**Owner: Coordinator (Opus) for ALL tasks in this phase — NOT delegated to Sonnet agents.** These docs *encode the
approved architecture (AD-1..AD-8)*, and the coding agents read them as source of truth. They must describe the
target **before** any agent codes. Use the **"(target — MARINE-GEOMETRY-MODEL-PLAN Phase GX)" annotation pattern
already in ARCHITECTURE.md** so a doc that describes the target while the code is still migrating is honest, not a
false claim of current state.

**Gate to start:** operator approval of this plan (= architecture approval). **Gate to finish:** Gate D below.

#### D.1 — ADR-093 Amendment 5 (+ new geography ADR)
- **ADR-093 Amendment 5** (`docs/decisions/ADR-093-swan-trushore-nearshore-model.md`): record isobath-normal
  per-transect facing (AD-1); open-water L1 aim + WW3 sides (AD-3); OMBB L4 axis + multi-obstacle clustering
  (AD-4); curvature-derived break-type as the L3 trigger, operator classification demoted to optional override
  (AD-5); **obstacle representation — bathymetry-injection fork + static cited coefficients (AD-8)**, folding the
  working-model Track B items (into Amdt 5 or an ADR-095 amendment — coordinator's stated call). **Explicitly REOPEN
  Amendment 2 §3** (contour-orientation derivation — previously deferred as "specified nowhere, built nowhere"; now
  in scope and specified). Note Phase F (Young & Verhagen 1-D wind sea) dropped.
- **New ADR** for AD-2/AD-6 (OSM coastline + wrap-aware fetch fan + classification-first + two-stage study area) if
  the coordinator judges it a distinct decision; else fold into Amdt 5 (coordinator's call, stated).
- Status **Accepted** — the plan approval IS the acceptance (operator ruling). Then extract prescriptive rules into
  the manuals (D.3–D.5) per the ADR lifecycle.

#### D.2 — ARCHITECTURE.md (marine handoff model + SWAN-nearshore paragraphs)
- Update the "⚓ MARINE HANDOFF MODEL" callout and the SWAN-nearshore / multi-transect paragraphs: transect bearing =
  per-transect isobath-normal (not uniform segment-perpendicular); L1 aim + WW3 sides = open-water fan (not
  `mean_offshore_bearing_deg`); `directional_exposure` = fan-derived; L4 axis = OMBB + clustering; L3 trigger =
  derived curvature (override = `topographic_feature`); the two `classify_region` taxonomies (do-not-merge); OSM
  two-stage basis; F1 guard extended to L4 (D6b); wind-sea generation is SWAN's job (Phase F dropped). **Annotate
  "(target — Phase GX)"** on items whose code has not migrated yet.

#### D.3 — PROVIDER-MANUAL.md §14.15 (SWAN nearshore, prescriptive)
- Facing derivation, L1 aim/WW3 sides, exposure source, L4 axis + clustering, L3 trigger, classify_region reuse,
  **obstacle representation (AD-8: bathymetry-injection fork + the pier/seawall coefficients)**.
  **Sizing formulas/constants stay unchanged (off-limits).**

#### D.4 — OPERATIONS-MANUAL.md + Operator Manual (wizard/admin)
- `topographic_feature` → optional override; `directional_exposure` → fan-derived optional override; draw-tool
  polygon; geometry now automated (operator draws the surf area, the rest is derived). The wizard help-content keys
  land per-phase with the wizard change (G3.3/G5.3/G6.3); the Operator-Manual narrative is set here.

#### D.5 — API-MANUAL.md (contracts touched)
- Note served-contract effects: `modelStatus` grading (TA-C22/G7.5, trigger 4) and the `beach_facing_degrees + 180°`
  CURVE-direction note (reconcile with the isobath-normal). If an area's served fields don't change, say so — do
  not invent fields (scope the API to the dashboard).

#### GATE D — docs describe the approved architecture (Coordinator self-review)
- Three-layer review (`rules/verification.md`): every AD-1..AD-8 reflected; **grep the docs for stale assertions of
  the old design** (segment-perpendicular as final; `mean_offshore_bearing_deg` L1 aim as the rule; typed
  `directional_exposure` as required; `_most_distant_pair` L4 axis; operator classification as the sole L3 trigger)
  and update or transitional-annotate each; ADRs Accepted; manuals consistent with ARCHITECTURE.md. **No G-phase
  agent is dispatched until Gate D passes.**

---

### PHASE G0 — Foundations (the shared primitives; everything depends on these)

**Gate to start:** plan approved. **These are prerequisites** — no other phase starts until G0 lands. Mostly
NET-NEW modules, so few current-code quotes; the spec IS the design (AD-2, AD-4, AD-7).

#### G0.1 — OMBB helper (new `services/structure_geometry.py`) · AD-4
- Owner: `clearskies-api-dev` (impl) + `clearskies-test-author` (KAT).
- File: **NEW** `weewx_clearskies_marine/services/structure_geometry.py`. Dep: **`shapely` only** (already a
  runtime import, `shelf_boundary.py`). Do **NOT** add `rasterio`/`exactextract`.
- Architectural: covered by **AD-4** (settled). Off-limits: do not touch `compute_structure_grid_domain` in this
  task — G4 consumes the helper; G0.1 only *builds* it.
- **Spec:** `oriented_bounding_box(geom_or_points) -> OMBB` where `OMBB` is a small dataclass carrying
  `{rectangle: shapely.Polygon, long_axis_bearing_deg: float, short_side_m: float, long_side_m: float,
  corners_lonlat: list, centroid_lonlat: tuple}`. Build via shapely `.minimum_rotated_rectangle`. Bearing is the
  long-axis heading in compass degrees (0=N, CW). Accept both a shapely polygon/linestring and a raw
  `[(lon,lat),…]` list. Pure geometry — no I/O, no logging beyond a `ValueError` on <2 distinct points.
- **Why one helper (AD-4):** consumed by BOTH the obstacle router (T4.0/T4.1, structure polygon alone) and the L4
  axis (G4, obstacle-plus-shadow / merged-cluster footprint). Different call geometry, one helper.
- Verify: `pytest tests/services/test_structure_geometry.py -q`.
- **Accept (KAT):** a 40 m × 8 m rectangle ring → `long_side_m≈40`, `short_side_m≈8`, bearing ≈ the ring's long
  axis; a straight pier ring → 2-ish-point degenerate rectangle with the pier bearing; a 45°-rotated square →
  bearing ≈ 45°; <2 points → `ValueError`.

#### G0.2 — Region classifier reuse (no merge, no third copy) · AD-7
- Owner: `clearskies-api-dev`.
- Files: `enrichment/bathymetry.py:341` (the coarse coastal `classify_region`); `enrichment/fishing_species.py:248`
  (the biogeographic one, renamed here).
- Architectural: **AD-7** (settled). **OFF-LIMITS: do NOT merge the two classifiers** — they are different
  taxonomies (5 coastal vs 11 biogeographic). Do not change either function's *logic*.
- **Do (both, unconditional):** (1) create `services/region.py`, move `bathymetry.py`'s `classify_region` + its
  `REGION_*` constants there, and have `bathymetry.py` (and the geometry regime, G0.3c) import from it — a **pure
  move, identical logic**; (2) rename `fishing_species.py`'s same-named function to `classify_biogeographic_region`
  and update its callers (`endpoints/fishing.py`, `enrichment/fishing_species.py` internal). No behaviour change.
- Verify: `pytest tests/enrichment/test_fishing_species.py tests/enrichment/test_bathymetry.py -q`.
- **Accept:** both classifiers return exactly what they returned before (KAT: same inputs → same region strings);
  no call site imports the wrong one; grep shows one `classify_region` (coastal) and one
  `classify_biogeographic_region`.

#### G0.3 — Geography module: OSM coastline + wrap-aware fetch fan + regime + exposure (new `services/geography.py`) · AD-2, AD-6
- Owner: `clearskies-api-dev` (impl) + `clearskies-test-author` (KAT) + `clearskies-auditor` (blind).
- File: **NEW** `weewx_clearskies_marine/services/geography.py`. Deps: `shapely` (present); for Overpass HTTP use the
  marine repo's **existing shared client `providers/_common/http.py`** (urllib-based; already used by
  `bathymetry_resolver.py`, `api_client.py`) — **do NOT add `requests`** (the wizard's Overpass client lives in the
  STACK repo and is not importable here; the marine repo has no Overpass code today).
- Architectural: **AD-2 + AD-6** (settled). This is the largest net-new subsystem; split into sub-tasks. Runs at
  **config time only** (with the grid-sizing chain), never per-forecast-cycle.
- **G0.3a — OSM coastline fetch + cache.** Overpass query `way["natural"="coastline"](<bbox>);out geom;` with
  **bbox = centroid ± horizon** (G0.3b — the coastline must reach the horizon, NOT just the bathymetry footprint);
  parse the `way` geometries into shapely lines; cache bbox-keyed like bathymetry. **Overpass unreachable → raise
  (no silent fallback);** OSM is the one layer that must be reachable (rules/coding.md §1). *(Verified viable
  2026-07-30: live query returned 46 KB of coastline geometry in ~2 s.)*
- **G0.3b — wrap-aware fetch/openness fan.** 72 rays (5°) from the study-area centroid to the **regime horizon**.
  **Pinned parameters (methodology numbers — implement, do not re-derive):**
  - **Ocean horizon** = `find_shelf_distance(centroid) + 10 km` (existing L1 constant, `swan_domain.py:965`;
    computed from the centroid → no circular dependency on L1's final size); **fallback 40 km** if it returns `None`.
  - **Great Lakes horizon** = the far-shore distance along the ray, **capped at 200 km** (Lake Superior scale).
  - **Ray march step** = **1 km**. **Min open-water run for `wrap-candidate`** = **≥5 km** continuous water beyond
    the land (a small gap between islets is NOT a wrap-candidate).
  - **Land/water determination** = the **OSM coastline orientation convention (land on the LEFT, water on the RIGHT
    of the way's node order)** — NOT crossing-parity (OSM `natural=coastline` ways are unclosed lines clipped at the
    bbox, so parity is unreliable).

  Per ray: march at the step; on a coastline crossing, **continue** and test for ≥5 km open water beyond within the
  horizon. Classify `directly-open | wrap-candidate | truly-blocked` per AD-2. Return per-ray {bearing,
  classification, first-land-distance, open-water-beyond?}.
- **G0.3c — regime + exposure + open-water bearing.** Water-body regime from the reused coarse `classify_region`
  (G0.2) + coastline enclosure geometry. **Exposure:** directly-open & wrap-candidate = EXPOSED, truly-blocked =
  sheltered (this object replaces the typed `directional_exposure`; same dict-of-sectors shape the L4 sizer and
  surf-scorer already consume — see G3). **Open-water bearing:** openness-weighted seaward direction (feeds AD-3).
  **Fetch value** (for Great Lakes L1 sizing, G2) = the open-water fetch along the dominant open direction.
- Verify: `pytest tests/services/test_geography.py -q`.
- **Accept (KAT, synthetic coastlines — no live Overpass in tests):** a straight open coast → all seaward rays
  directly-open, one broad exposed sector; a **peninsula** with ocean on the far side → those rays
  **wrap-candidate (EXPOSED)**, not blocked; a **tight cove** → truly-blocked all around → "no surfable waves";
  a Great-Lakes-shaped basin → regime `GREAT_LAKES`, finite fetch value. Auditor: prove no ray silently stops at
  first land; prove Overpass-failure raises.

---

### PHASE G1 — Isobath-normal facing + per-transect bearings · AD-1

**Gate to start:** G0 landed. Implements the documented-but-unbuilt SURF-ZONE §2.6 design.

#### G1.1 — Smoothed shallow-isobath heading, per transect (new helper) · AD-1
- Owner: `clearskies-api-dev` (impl) + `clearskies-test-author` (KAT).
- File: new helper in `enrichment/bathymetry.py` (beside `find_shoreline_from_grid`/`find_depth_contour_distance`,
  which already walk the grid along a bearing) — keep it with the other grid-walk helpers.
- Architectural: **AD-1** (settled). Off-limits: do **not** change `find_shoreline_from_grid` or
  `find_depth_contour_distance` — you *add* a heading helper; those consumers are unchanged (they take a bearing).
- **Spec:** `isobath_normal_bearing(grid, origin_lat, origin_lon, *, contour_depths_m=(2.0, 5.0), smooth_scale_m≈300) -> float`
  — sample the 2 m and 5 m depth contours near the origin, fit their **local heading** (smoothed over ~surf-zone
  width / the ~300 m study segment), return the **seaward perpendicular** in compass degrees. Datum-robust
  (heading, not the 0 m line). Degenerate/flat bathymetry → fall back to the segment-perpendicular value + WARN.
- Verify: `pytest tests/enrichment/test_bathymetry.py -q -k isobath`.
- **Accept (KAT):** a synthetic planar shelf with contours running exactly N–S → normal = due-E (90°); a shelf
  rotated 20° → normal rotates 20°; a curved-contour patch → per-origin normals fan with the curvature; flat/no
  contour → segment-perpendicular fallback + WARN.

#### G1.2 — `beach_facing_degrees` derivation → isobath-normal · AD-1
- Owner: `clearskies-api-dev`.
- File: `config/marine_config.py:505-510` (the derivation) + `:569-576` (the property docstring).
- **Current code (`:505-510`):**
  ```python
  # --- Derive computed fields from segment geometry ---
  bearing = _segment_bearing(self.segment_start_lat, self.segment_start_lon,
                             self.segment_end_lat, self.segment_end_lon)
  self._beach_facing_degrees = _perpendicular_bearing(bearing)
  ```
- **Change:** `beach_facing_degrees` becomes the **isobath-normal** (G1.1) at the segment midpoint, computed at
  grid-sizing time when the bathymetry grid exists — **not** in `__init__` (no grid there). Design: keep the
  segment-perpendicular as the **v1 fallback** used only until the isobath-normal is resolved by the grid-sizing
  chain (which then sets the derived value on the spot's profile). Update the docstring to say isobath-normal,
  segment-perpendicular fallback. **Off-limits:** the consumers of `beach_facing_degrees` are unchanged; do not
  touch the sizing formulas.
- Verify: `pytest tests/config/test_marine_config.py -q`; `pytest tests/services/test_grid_sizing_chain.py -q`.
- **Accept:** on a spot with real bathymetry, `beach_facing_degrees` reflects the isobath-normal (≠ the raw
  segment-perpendicular where contours differ from the drawn segment); with no grid yet, the segment-perpendicular
  fallback is returned + the source is logged.

#### G1.3 — Per-transect isobath-normal bearings · AD-1
- Owner: `clearskies-api-dev`.
- File: `services/swan_formats.py:746-753` (the `transect_bearing`/`transect_bearings` block; the `v2 future`
  comment at `:750`).
- **Current code (`:752-753`):**
  ```python
  transect_bearing = beach_facing_degrees
  transect_bearings = [transect_bearing] * n_transects
  ```
- **Change:** emit the **per-transect** isobath-normal (G1.1) at each transect origin instead of the shared scalar;
  advance/remove the `v2 future` comment. Collapses to a single value on a straight beach. **Off-limits:**
  `compute_transect_shadows` (immediately below) is unchanged — it already takes `transect_bearings`.
- Verify: `pytest tests/services/test_swan_formats.py -q -k transect`.
- **Accept:** on a curved-shore fixture, `transect_bearings` vary along the segment (match the per-origin isobath
  normals); on a straight fixture, all equal (≈ the old value).

#### G1.4 — Per-spot sizing aggregation (coverage envelope) · AD-1
- Owner: `clearskies-api-dev`.
- Files: `services/grid_sizing_chain.py` (where `find_depth_contour_distance` is called per spot) + the L2/L3
  sizing calls in `services/swan_domain.py` (`_compute_level2` averages `beach_facing_degrees`).
- Architectural: **AD-1 sizing note** (settled — coverage-driven, operator framing). **Off-limits: do NOT change
  the sizing formulas** (30 m/15 m criteria, +500 m margin). Only *which/how-many* bearings feed them.
- **Change:** measure the offshore contour **per transect** (per-transect isobath-normal) and size L2/L3 to
  **enclose the union** (the covering envelope L2 already computes over spots+children), rather than one averaged
  bearing. The bearing's only sizing role is the contour-measurement direction.
- Verify: `pytest tests/services/test_swan_domain.py tests/services/test_grid_sizing_chain.py -q`.
- **Accept:** on a curved-shore multi-transect fixture, L2 encloses every transect's own 30 m-contour reach (no
  transect's offshore contour falls outside L2); on a straight fixture, sizing is unchanged from today.

#### G1.5 — Self-check + guard (OSM-heading vs isobath-heading) · AD-6
- Owner: `clearskies-test-author`.
- **Do:** at config time, compare the stage-1 OSM coastline heading with the stage-2 isobath heading (AD-6
  self-check); agreement → trust; sharp divergence → WARN + flag (bad OSM coastline or anomalous bathymetry).
  Known-answer test the divergence flag.
- **Accept:** aligned synthetic inputs → no flag; a 40°-divergent pair → flag + WARN.

---

### PHASE G1R — Beach-facing replacement (AD-1R) + serve-nothing guard (operator-approved 2026-07-31)

**Gate to start:** operator approval 2026-07-31 (granted in chat; all decisions in the ledger, including the
strip fetch and the definition-time / no-L4 corrections). **Order: G1R.0 first (independent, operator priority
1), then G1R.1 → G1R.4, then QC Gate G1R.** Every agent prompt carries the git-restrictions +
architectural-change blocks.

#### G1R.0 — Serve-nothing-on-failure guard (operator priority 1) · Critical finding 3
- Owner: `clearskies-api-dev` (impl) + `clearskies-test-author` (guard KAT).
- File: `providers/nearshore/swan.py` — the per-spot cache write (`spots_cached += 1`, ~line 3122) has **no
  convergence check**; a run failing the convergence gate still caches + serves a coarser-grid forecast (silent
  degrade-to-L3).
- **Change:** a run that fails the convergence gate **publishes nothing** — no forecast-cache write, no served
  update for that cycle; the previous good cache (if any) keeps serving until it expires; loud ERROR naming the
  failed level + valid_fraction. **No SWAN emission change.** Off-limits: the convergence gate itself
  (`_check_convergence`) is frozen — this task changes what happens AFTER it fails, not the gate.
- **Accept (KAT):** failed-gate run → forecast cache byte-untouched + ERROR logged; passed-gate run → caches
  exactly as today.

#### G1R.1 — Shoreline-strip fetch + `shoreline_normal_bearing` helper (AD-1R steps 0–4) · AD-1R
- Owner: `clearskies-api-dev` (impl) + `clearskies-test-author` (KAT).
- Files: **NEW** helper `shoreline_normal_bearing(...)` in `enrichment/bathymetry.py` (beside
  `find_shoreline_from_grid`, whose zero-crossing walk it reuses); strip fetch via the existing
  profile-bathymetry mechanism (`providers/nearshore/swan.py:285-304`).
- **Implement AD-1R steps 0–4 EXACTLY as pinned — the equations are in the AD; do not re-derive them.** Reuse
  the existing seaward-sense probe from G1.1's implementation. **Delete `isobath_normal_bearing` + its KATs in
  the same commit** (AD-1R step 6). The helper + strip fetch take ONLY the segment endpoints (+ a grid handle) —
  **no `GridDomain`/SWAN-sizing parameter in any signature** (AD-1R scope constraint 1); works identically for a
  spot with no structures (scope constraint 2).
- Verify: `pytest tests/enrichment/test_bathymetry.py -q -k shoreline_normal` (path per TC-1 convention).
- **Accept (KAT, synthetic grids):** N–S straight shoreline, water east → 90.0° ± 0.5° at every window, stable
  at W=1000; the same rotated 20° → 110.0° ± 0.5°; sinusoidal shoreline (amplitude 50 m, wavelength 400 m) →
  settled facing within ±3° of the underlying trend's normal; shoreline run shorter than `W_MIN` →
  segment-perpendicular fallback + WARN; a > 5·Δ gap → split-and-keep-contiguous-run behavior.

#### G1R.2 — Rewire both call sites: chain READS the stored facing + derives per-transect bearings · AD-1R step 6.2
- Owner: `clearskies-api-dev`.
- Files: `services/grid_sizing_chain.py:1142` (currently hands the ray-fit the **1 km L1 grid**; now **reads the
  stored config facing** — no recompute unless `beach_facing_source == "fallback_segment_perp"`, which retries the
  full derivation — and derives the **per-transect bearings** from the cached strip via the G1R.1 helper,
  **before the 30 m contour search** so the facing feeds the contour-measurement directions);
  `services/swan_formats.py:803` (per-transect call site). The G1.6 profile-cache persistence and the G1.6/TC-15
  runtime + endpoint write-backs are **UNCHANGED in shape** (same fields, new values).
- **Off-limits:** sizing formulas; every consumer of the bearing; SWAN emission (VALUE change only). No
  dependency on L3/L4 existing — an open-beach spot (no structures, no L3/L4) resolves identically.
- Verify: `pytest tests/services/test_grid_sizing_chain.py tests/services/test_swan_formats.py -q`.
- **Accept (known answer):** on the real HB config, `beach_facing_degrees` ≈ **220° ± 5°** (the pier/L4-rotation
  heading; the broken 202° MUST NOT reproduce); per-transect bearings ≈ uniform on HB's straight shore; an
  open-beach fixture (no structures) resolves per-transect bearings identically; the persisted profile carries
  the new values; no consumer signature changes.

#### G1R.3 — Definition-time flow: marine geometry endpoint + API pass-through + wizard pre-fill + stored key · AD-1R step 6.1
- Owner: `clearskies-api-dev` (marine endpoint + API pass-through + apply models) + `clearskies-dashboard-dev`
  (stack wizard).
- Files: marine service — **NEW** `POST /geometry/facing` (Bearer, same auth as `/config`; request = segment
  endpoints ONLY; response = computed facing + the per-window sweep log + source tag; route naming aligned to
  API-MANUAL conventions at G1R.4); API — pass-through on the wizard's existing `/setup/*` channel (ADR-038),
  AND `ApplyRequest`/marine apply models accept `beach_facing_degrees` + `beach_facing_source` (models are
  `extra="forbid"` — the 2026-07-11/07-15 apply-contract lesson; miss this and every apply 422s); marine
  `config/marine_config.py` (parse the stored key + source tag; property/setter at :611-636); stack wizard marine
  step (call the endpoint when the segment is drawn → pre-fill; operator adjustment → `source=operator`;
  fetch/trace failure → pre-fill the segment-perpendicular + `source=fallback_segment_perp` + a visible UI flag);
  **help-content doc-sync**.
- **Off-limits:** no SWAN emission; the endpoint must work on a bare segment with **no prior config, no grids, no
  sizing** (AD-1R scope constraint 1).
- **Accept:** wizard draw → field pre-fills with the computed facing (HB: ≈ 220°); an adjustment round-trips as
  `source=operator` and wins at every consumer (per-transect uniform; derived value still logged); an untouched
  pre-fill round-trips as `source=computed`; strip failure → segment-perp pre-fill, flagged, tagged
  `fallback_segment_perp`; the full wizard apply flow persists both keys end-to-end with **no 422**; help keys
  updated.

#### G1R.4 — Doc-sync (Opus/Coordinator-owned, NOT delegated)
- ADR-093 Amendment 5: correct the facing method to AD-1R (DSAS/CliffMetrics; equations by reference to this
  plan). ARCHITECTURE.md geometry bullet (updated 2026-07-31 with this plan revision — verify at the gate).
  PROVIDER-MANUAL §14.15 facing derivation. Operator-Manual/wizard narrative (the override field).

#### QC Gate G1R — the operator-directed re-run (decision 6, 2026-07-31)
- Adversarial audit + the KATs above; then **deploy and run ONE full 4-level nest on the real HB config**
  (facing fix first, then re-run — the operator-directed order). **This gate re-tests Gate G4's criteria:** L4
  `valid_fraction ≥ 80%`, transect handoff points wet (TC-21's 25/32-dry must clear), full-nest convergence.
  - **Pass →** Gate G4 unblocks; G5+ proceeds (Gate GR still re-validates against the cam later).
  - **Still failing →** only THEN the TC-21 bisect (redeploy pre-G4 `f788611` / pre-G3 `4828d99`, same-cycle
    isolation runs) — not before.

---

### PHASE G2 — Geography-aware L1 aim + WW3 sides + D6c gate + Great Lakes L1 + islands · AD-3

**Gate to start:** G0 landed (the open-water bearing + fetch value are available). **L1/L2 stay axis-aligned —
this changes aim/extent VALUES, never rotation, never emission.**

#### G2.1 — L1 offshore aim from the open-water bearing
- Owner: `clearskies-api-dev`. File: `services/swan_domain.py:980-988` (`_compute_level1`).
- **Current:** `avg_bearing = mean_offshore_bearing_deg(spot_locations)` → offshore projection.
- **Change:** use the **open-water bearing** (G0.3c) for the offshore projection instead of `mean_offshore_bearing_deg`.
  **VALUE change only — CGRID/INPGRID emission unchanged** (only the computed L1 bbox coords move). Off-limits: L1
  stays axis-aligned; do not touch the emitter or `mean_offshore_bearing_deg`'s definition (WW3 side-select still
  reads it until G2.2 — do G2.1 and G2.2 together).
- Verify: `pytest tests/services/test_swan_domain.py -q -k level1`. **Accept:** where open water ≠ beach normal, L1's
  offshore extent aims at open water; on a straight open coast, unchanged.

#### G2.2 — WW3 boundary SIDE selection from the open-water bearing
- Owner: `clearskies-api-dev`. File: `services/ww3_station_selection.py` (offshore-side selection, the caller of
  `mean_offshore_bearing_deg` ~lines 55-67 / :177 / :419).
- **Change:** choose the boundary side(s) from the **open-water bearing**. **VALUE change only.** The selection
  pipeline is **cardinal-only (N/E/S/W) by design end-to-end** — `_offshore_sides()` (`ww3_station_selection.py`
  ~:392-412), `_SIDE_ORDER`, and the emitter loop `sides = [s for s in ("N","E","S","W") if s in selection.by_side]`
  (`swan_formats.py:2347`). **Confirm your new bearing input still flows into `_offshore_sides()` unchanged; do NOT
  extend the side set to diagonals** (a diagonal key would be silently dropped at :2347 — do not "fix" that tuple).
  Off-limits: the station **qualification** criterion (`deep water OR tanh(kd)`), the emitter grammar, and the side
  set. **No SWAN emission change** (the appendix `BOUNDSPEC SIDE` is reference only — the manual supports 8 tokens,
  our selection produces only the 4 cardinals).
- Verify: `pytest tests/services/test_ww3_station_selection.py -q`. **Accept:** sides face open water (a spot facing
  E selects `SIDE E`); qualification criterion unchanged; the side set stays cardinal-only.

#### G2.3 — D6c validation gate (Bolsa) — root-cause, then validate; NOT pre-resolved
- Owner: Coordinator + `clearskies-api-dev`. Carried from Phase 5 D6c.
- **Do:** on the enlarged 2-spot Bolsa config, determine WHY 0 WW3 stations qualified (candidates: two-spot
  lateral-union enlargement past the ~18.5 km distance criterion; catalogue density; the old mean-of-two-facings
  aim). Fix the diagnosed cause; the open-water aim (G2.1/2.2) addresses the aim component only.
- **Accept:** the real 2-spot Bolsa station-selection run returns ≥2 qualifying stations (or an honest, correct
  refusal with the reason), reproduced on a live run. **Do not close until validated on the real config.**

#### G2.4 — Great Lakes L1 sizing (no shelf edge)
- Owner: `clearskies-api-dev`. Files: `services/swan_domain.py:956-965` (`_compute_level1`, `find_shelf_distance`);
  `services/shelf_boundary.py:50-67`.
- **Current:** `shelf_dist_km = find_shelf_distance(center)` — returns the nearest **ocean** shelf distance even for
  a lake centre (`shelf_boundary.py:60-67`), so a Great-Lakes L1 is absurdly oversized.
- **Change:** when the reused coarse `classify_region` (AD-7) returns `REGION_GREAT_LAKES`, size L1's offshore
  extent from **lake-geometry/fetch** (the fan's fetch value, G0.3c) instead of `find_shelf_distance`. **VALUE
  change only.** Off-limits: don't alter `find_shelf_distance` for the ocean path.
- Verify: `pytest tests/services/test_swan_domain.py -q -k great_lakes`. **Accept:** a Great-Lakes spot sizes L1 by
  lake fetch, not an ocean-shelf distance; an ocean spot is unchanged.

#### G2.5 — Islands / headlands / peninsulas enclosure (AD-2 wrap-candidate)
- Owner: `clearskies-api-dev`. File: `services/swan_domain.py` `_compute_level1`.
- **Change:** for each directly-open **and wrap-candidate** direction (G0.3b), enlarge L1 to **enclose the
  intervening land + the open water beyond**, so SWAN computes the wrap-around. **VALUE change only** (bigger L1
  bbox; emission unchanged). Off-limits: L1 stays axis-aligned.
- Verify: `pytest tests/services/test_swan_domain.py -q -k enclose`. **Accept:** a point-break/island fixture → L1
  encloses the intervening land and the open water beyond; a straight open coast → unchanged.

#### QC Gate G2
- Adversarial audit; a **real SWAN L1 run** on a re-aimed config **parses and runs** (proves the SIDE token and L1
  geometry are valid — a wrong token fails here, not in production); D6c validated on the real Bolsa config.

---

### PHASE G3 — Exposure from the fan → L4 sizing + surf-scorer · AD-2

**Gate to start:** G0 landed **AND D6b landed (G3.0) — the L4-only cold-start guard is a hard prerequisite before
any L4 resize** (§OFF-LIMITS SWAN note; brief §3.5).

#### G3.0 — D6b: extend the geometry cold-start guard to L4-only changes (PREREQUISITE) · carried Phase 5
- Owner: `clearskies-api-dev`. File: `services/grid_sizing_chain.py` (`_cold_start_swan_if_geometry_changed()` /
  `run_grid_sizing_chain()` geometry compare) + `ARCHITECTURE.md` doc-sync (the F1 guard scope).
- **Current:** the compare covers L1/L2 bbox+resolution and L3 clusters — **not L4**.
- **Change:** add each L4 grid's bbox+resolution+rotation to the geometry compare, so an L4-only change trips the
  cold-start + forced full run. **VALUE/logic change; no SWAN emission.**
- Verify: `pytest tests/services/test_grid_sizing_chain.py -q -k cold_start`. **Accept:** an L4-only geometry change
  triggers cold-start (was silent before); a no-op push does not.

#### G3.1 — Feed fan-derived exposure into L4 sizing
- Owner: `clearskies-api-dev`. File: `services/grid_sizing_chain.py:1704-1705` (passes
  `parsed.surf_spots[...].directional_exposure` into `compute_structure_grid_domain`).
- **Change:** pass the **fan-derived exposure** (G0.3c, **same dict-of-8-compass-sectors→bool shape**) instead of the
  config `directional_exposure`. **VALUE change only — `compute_structure_grid_domain` (`swan_domain.py:1998-2039`)
  is UNCHANGED** (same dict shape; the across-axis margin recomputes). Off-limits: do not touch the L4 sizing math
  or emission.
- Verify: `pytest tests/services/test_swan_domain.py tests/services/test_grid_sizing_chain.py -q`. **Accept:** L4
  across-axis sized from the fan exposure; a straight-open spot → unchanged margins.

#### G3.2 — Feed fan-derived exposure into surf-scorer
- Owner: `clearskies-api-dev`. File: `enrichment/surf_scorer.py:448` (`spot_config.directional_exposure.get(...)`).
- **Change:** read the fan-derived exposure. **VALUE change only.** Verify: `pytest tests/enrichment/test_surf_scorer.py -q`.
- **Accept:** scoring uses the geometry-derived exposure; unchanged on a straight-open spot.

#### G3.3 — `directional_exposure` becomes fan-derived; config field kept as optional override
- Owner: `clearskies-api-dev` (marine) + `clearskies-dashboard-dev` (stack wizard/admin).
- Files: `config/marine_config.py:157-158` (`_parse_directional_exposure`), `:528`; wizard/admin marine step.
- **Change:** the fan is the default source; keep the config `directional_exposure` as an **optional override**
  (parity with `topographic_feature`, AD-5). Remove it as a **required** wizard field; **help-content doc-sync.**
  No SWAN emission. **Accept:** wizard no longer requires it; an override still applies if present.

#### QC Gate G3
- Adversarial audit; KAT on the fan→exposure mapping; a real L4 run **after D6b** confirms the resize cold-starts.

---

### PHASE G4 — L4 axis from OMBB + multi-obstacle clustering + Track-B obstacle mechanics · AD-4

**Gate to start:** G0.1 (OMBB helper) + G3.0 (D6b) landed. T4.2 injection + T4.3 coefficients are **approved via
AD-8 (this plan)** — no separate mid-run sign-off; implement per AD-8.

#### G4.1 — L4 axis from the OMBB (single structure)
- Owner: `clearskies-api-dev`. File: `services/swan_domain.py:1904-1911` (`_most_distant_pair` axis) + `:1904-1939`
  (tip/base + tip-depth + 1λ margin).
- **Change:** derive `rotation_deg` from the **OMBB** (G0.1) long-axis of the **obstacle-plus-shadow** footprint
  instead of `_most_distant_pair`; **re-anchor tip/base** (tip = farther-from-anchor) so the tip-depth lookup and the
  1-wavelength along-axis margin still work. **VALUE change only — the `CGRID … alpc` / `NGRID … alpn` emission is
  UNCHANGED; only the `alpc` value changes.** Off-limits: the CGRID/NGRID emitter; the sizing formulas.
- Verify: `pytest tests/services/test_swan_domain.py -q -k structure_grid`. **Accept:** a simple pier → `alpc` ≈ the
  old two-point axis (within tolerance) with tip/base unchanged; a bent jetty → OMBB long-axis, not the tip-to-tip line.

#### G4.2 — Multi-obstacle proximity clustering — MERGE only; separate-box multi-L4 is DEFERRED

> **⛔ SUPERSEDED/REVERSED 2026-08-01 (operator-approved, ADR-093 Amendment 6).** The "PRIMARY structure gets the
> single L4, others logged to concerns" rule below no longer exists. Every operator-identified eligible structure
> in a cluster now participates in the one sized L4 grid (`_cluster_structures_by_proximity()`/
> `_select_primary_group()` deleted, marine `4e79d21`) — "a beach may have no dominant structure" (operator
> ruling 2026-08-01: two equal breakwaters, or a jetty with adjoining breakwaters, must not have one arbitrarily
> designated primary). Text below is the historical record — **do not implement.**

- Owner: `clearskies-api-dev`. File: `services/swan_domain.py` (clustering + L4 sizing). **VALUE change only — NO
  new SWAN emission.** *(The runner/emitter are single-L4-child by construction: scalar child params + one `NGRID`
  `swan_formats.py:1814-1819`; class-constant nest filenames `swan_runner.py:2646-2647`; first-matching-L4-only
  `:4004-4007`; L4 is the cluster's sole spot-output `:4175-4178`. Emitting N nested L4 grids would be a 6-point
  rewiring touching the frozen convergence/hotstart/COMPUTE functions — out of scope.)*
- **Change:** cluster obstacle boxes — **merge when <500 m apart** (AD-4; `cluster_distance_m=500.0`,
  `swan_domain.py:567`) into **ONE** L4 grid = the **OMBB of the merged footprint** (G4.1), each box ≥ the AD-4
  minimum size.
- **Separate boxes (obstacles ≥500 m apart):** the **PRIMARY** structure (the one covering the served transects /
  nearest the spot pin) gets the single L4; **any other structure is logged to `MARINE-GEOMETRY-MODEL-CONCERNS.md`
  as a deferred follow-up** and gets no L4 this round. Still a strict improvement over today's degenerate
  cross-structure axis (§1 defect 3). **Do NOT attempt multiple nested L4 grids** — separate-box multi-L4 is
  explicitly DEFERRED (a follow-up plan); if a config seems to need it, log it and move on (non-blocking).
- Verify: `pytest tests/services/test_swan_domain.py -q -k cluster`. **Accept:** two obstacles <500 m → one merged
  L4 (OMBB of both); two obstacles ≥500 m → one L4 on the primary + a concerns entry for the other; single-obstacle
  identical to G4.1; **no multi-grid emission anywhere.**

#### G4.3 — Track B T4.1: route structures by kind in the OBSTACLE emitter
- Owner: `clearskies-api-dev`. File: `services/swan_formats.py:1750-1770` (`_OBSTACLE_PARAMS` dict + emit loop). Reads Track B
  brief `SWAN-OBSTACLE-BEST-PRACTICES-2026-07-29.md` + working-model plan **T4.1** directly.
- **Change:** call `normalize_structure` (G0.1 OMBB) → `line`|`footprint`; `line` → emit `OBSTACLE … LINE` for the
  **simplified centerline** (≤180-char `&` wrap, T1.1); `footprint` → no OBSTACLE line, hand to G4.4. **Touches the
  OBSTACLE LINE coordinate list — the `OBSTACLE … LINE` FORMAT is unchanged (appendix); only the vertex list is
  simplified.** Off-limits: the OBSTACLE command grammar; the ≤180-char wrapper.
- **Accept:** HB pier emits a ≤6-vertex OBSTACLE line (not 35); a wide breakwater emits no OBSTACLE line.

#### G4.4 — Track B T4.2: structure → bathymetry injection (footprint into L4 BOTTOM) · **approved via AD-8**
- Owner: `clearskies-api-dev`. Files: `services/swan_formats.py` `cudem_to_swan_bottom` (line 402); `services/swan_runner.py`.
  Reads Track B brief `BATHYMETRY-STRUCTURES-BEST-PRACTICES-2026-07-29.md` + working-model plan **T4.2** directly.
- **Change:** materialize→burn→serialize; presence check (skip if already in DEM). **Touches the VALUES in
  `BOTTOM.txt` — the `INPGRID/READINP BOTTOM` syntax is UNCHANGED (appendix, stationary-only, `idla=3`).** Dep:
  **shapely only** (no `rasterio`). Off-limits: the INPGRID/READINP grammar.
- **Accept:** a burned breakwater → emergent ridge in `BOTTOM.txt` + lee shadow in the L4 TABLE; already-emergent
  structure → 0 injected (logged); no one-cell channel; KAT on the rasterizer + presence check.

#### G4.5 — Track B T4.3: per-type OBSTACLE coefficients (FORMULA — approved via AD-8) · trigger 1
- Owner: `clearskies-api-dev`. File: `services/swan_formats.py:1750-1770` (`_OBSTACLE_PARAMS` dict at :1750, loop to :1770). Working-model **T4.3**.
- **Change:** the **AD-8 static cited** constants (pier `TRANSM 0.74` Elgar 2001; seawall `REFL 0.9 RSPEC` JMSE 2021;
  breakwater/jetty/groin keep current `DAM …`). **Touches OBSTACLE `TRANSM`/`REFL` VALUES — syntax unchanged
  (appendix).** Dynamic Rc/Seelig–Ahrens are DEFERRED to Phase 5 (AD-8).
- **Accept:** each changed constant cites its source in a comment; a coefficient-sensitivity run at the gate.

#### G4.6 — TA-C21: rescope invariant 3 (geometry-coupled) · carried
- Owner: `clearskies-api-dev` + `clearskies-test-author`. File: `services/invariants.py:68`.
- **Change:** after per-transect bearings land (G1), re-run shadow classification; rescope invariant 3 so it does
  **not** over-fire on a correct 0/N-shadowed result. No SWAN emission. **Accept:** invariant 3 fires only on a real
  misclassification, not a correct zero.

#### QC Gate G4
- **A real 4-level SWAN run converges** on the OMBB-axis L4 (+ merged cluster). Adversarial audit; KAT on OMBB axis,
  clustering, rasterizer; coefficient-sensitivity sweep; shadow re-classification checked.

---

### PHASE G5 — Break-type from curvature → L3 trigger; `topographic_feature` optional · AD-5

**Gate to start:** G1 (isobath curvature available).

#### G5.1 — Derive break-type (point/headland/bay) from measured curvature
- Owner: `clearskies-api-dev` (impl) + `clearskies-test-author` (KAT). File: helper in `services/geography.py` (reuses
  the G1.1 isobath analysis).
- **Change:** classify point-break / headland / bay from the measured shoreline/isobath **curvature**. No SWAN
  emission. **Accept (KAT):** a curved-shore fixture → point/headland; a straight fixture → none/straight_beach.

#### G5.2 — L3 trigger reads the derived classification (config field = optional override)
- Owner: `clearskies-api-dev`. Files: `services/swan_domain.py:305-334` (the L3-trigger decision; the trigger set
  `_TOPOGRAPHIC_L3_TRIGGERS` at **:262**); `services/grid_sizing_chain.py:940-943` (passes `spot_topographic_features`).
- **Change:** pass the **derived** classification (G5.1) as the L3 trigger; keep config `topographic_feature` as an
  **optional override** (operator-confirmed 2026-07-31 — e.g. a submerged reef). **VALUE/trigger change — L3's
  CGRID/NGRID emission is UNCHANGED; this only decides whether L3 emits.** Off-limits: the L3 emitter; the viability test.
- Verify: `pytest tests/services/test_swan_domain.py -q -k l3_trigger`. **Accept:** a derived point-break → L3 on; a
  config override still forces/suppresses; a straight open beach → no L3 (byte-identical to today).

#### G5.3 — `topographic_feature` made optional (config + wizard)
- Owner: `clearskies-api-dev` (marine) + `clearskies-dashboard-dev` (stack). Files: `config/marine_config.py:527`,
  `:636-639` (validation → optional/override); wizard marine step; **help-content doc-sync** (AD-5 amends ADR-093 Amdt 2 §3).
- **Change:** the field is no longer required; honored as an override when present. **Accept:** a config without
  `topographic_feature` validates; an override is honored; docs updated.

#### QC Gate G5
- Adversarial audit; KAT on curvature→break-type; L3 on/off matches the derived classification and the override.

---

### PHASE G6 — OSM study-area basis + two-stage + self-check + draw-tool · AD-6

**Gate to start:** G0.3 (OSM layer) landed.

#### G6.1 — Two-stage wiring (Stage 1 OSM → Stage 2 bathymetry)
- Owner: `clearskies-api-dev`. File: `services/grid_sizing_chain.py` (chain order).
- **Change:** run **Stage 1** first (geography: OSM coastline, water-body classification, fetch fan, download
  footprint; freeze **L1**), then **Stage 2** (bathymetry: per-transect isobath facing, L3/L4, transects). No SWAN
  emission. **Accept:** stage order enforced; L1 frozen after Stage 1; Stage 2 uses the Stage-1 footprint.

#### G6.2 — Self-check: OSM-heading vs isobath-heading (see G1.5)
- Owner: `clearskies-test-author`. Cross-ref G1.5. **Accept:** agreement → trust; ≥ threshold divergence → WARN+flag.

#### G6.3 — Track B T4.6: draw-tool polygon mode (merge with OSM tracing UX)
- Owner: `clearskies-dashboard-dev` (stack). File: `templates/wizard/step_marine.html` (`polygon:false` at :1287,
  `L.Draw.Polyline` at :1456). Working-model **T4.6**.
- **Change:** enable `L.Draw.Polygon` alongside the polyline; capture the ring into the existing `_coordinates`
  hidden field (same `[lon,lat]` contract). Merge with the AD-6 OSM tracing UX. **Accept:** operator can draw a
  polygon; it round-trips through apply (guarded by T4.5's test).

#### QC Gate G6
- Two-stage order verified; self-check flags a divergent synthetic pair; draw-tool round-trips.

---

### PHASE G7 — Carry-forward: Track A remainder + Phase-5 items

**These are carried tasks — agents read the ORIGINAL task detail in `MARINE-WORKING-MODEL-PLAN.md` / the concerns
log directly; the coordinator does not paraphrase them here.**

#### G7.1 — D6a: grid_sizing_chain StructureConfig-vs-dict type bug — **RE-VERIFY FIRST, then fix or close**
- Owner: `clearskies-api-dev`. **The old cite `grid_sizing_chain.py:1270` is STALE** — `StructureConfig` no longer
  appears in that file (verified 2026-07-31). **First re-locate the bug** (grep the chain for a `StructureConfig`
  vs `dict` handling split); if it no longer exists, **confirm fixed and CLOSE** (do not carry a done item as
  to-do); else re-cite and fix before/with G1–G2. **Accept:** a guard test that fails on the pre-fix code, OR a
  documented confirmation the bug is already gone.

#### G7.2 — Track A open items (verbatim from source): T1.3; T2.2 PART B; **T2.3 residuals ONLY** (operator push/deploy
+ the deferred first-multi-swell-day reality validation + the auditor CLAIM-2 divergence check — **do NOT
re-implement T2.3**, it is DONE + Gate-2 audited, `MARINE-WORKING-MODEL-PLAN.md:1165-1186`); T3.1.

#### G7.3 — M1 closure items: TA-C16 (66 h vs 72 h window); the formal blind audit of the full served forecast;
larger/multi-swell-sea revalidation.

#### G7.4 — Cadence/performance lever (approved, gate-cleared: hourly 0–24 then ~6-hourly to 72). Producer-only
(`swan_formats.py` compute-list + TABLE schedule). **VALUE/schedule change — no SWAN command-grammar change**;
confirm the timestamp-driven chain still holds.

#### G7.5 — TA-C22 fixes: (a) grade `modelStatus` by fraction degraded (**data-contract change, trigger 4 —
approved via this plan**; reads `endpoints/surf.py:400`, `services/surf_1d_pipeline.py`). **Pinned rule:**
`ok` = 0 transects fall back; `partial` = ≥1 but **< 25 %** of transects fall back **and not** the best-peak
transect; `degraded_bulk` = **≥ 25 %** of transects **OR** the best-peak transect falls back. (b) root-cause
transect-31's PT* gap.

#### G7.6 — C-E10/C-E11, C-E01/C-E03, C-E04, C-E08, C-E12; **D7 publish policy — carry-as-parked, NO action this
plan** (parked to cutover); **T4.4 Part B** (wire a real tip-depth lookup so the shadow log stops showing 0.0 m —
cosmetic, non-blocking; do it only if it falls out of G4.6, else leave deferred); doc drift
(`reference/clearskies-dev.md` services table). Read the concerns log entries directly.

#### QC Gate G7
- Each carried item verified against its own source acceptance criteria; no Track-A regression.
- **Weather-dependent items are non-gate-blocking:** T2.3's "first genuine multi-swell day" reality check and
  G7.3's larger/multi-swell-sea revalidation **cannot be produced on demand** — they are logged **open** at this
  gate and **closed at the first qualifying sea state** (same posture as Gate GR's "≥1 real sea state, ideally
  multi-swell"). They do NOT block the gate.

---

### GATE GR — Reality re-validation (NON-NEGOTIABLE, runs after the geometry lands)

Because the per-transect bearing flows into the shadow classification and the headline aggregate, **re-run the
served headline vs the contemporaneous cam/Surfline** against the **Phase-3 pinned tolerance** (T3.1) — at matched
time, comparison quantity chosen before looking (`rules/verification.md`). Also re-assert: L4→D1 ≥ L2→D1; no flat
output; the NESTOUT-covers-every-child guard holds on the re-aimed/re-sized grids; a real full 4-level run (incl.
any multi-grid L4) converges. **M2 for the geometry model is this gate passing at ≥1 real sea state, ideally a
multi-swell day.**

---

## SWAN input syntax — verbatim reference (ONLY for tasks explicitly flagged as requiring emission changes)

**Copy these EXACTLY. Do not paraphrase, reorder tokens, or invent options.** Verbatim from the local SWAN User
Manual (`docs/reference/swan-user-manual.txt`) and our own `docs/reference/swan-commands-extract.md`. Cited by
task. **If a command you need is not here, STOP and surface — do not guess; the manual is local, the coordinator
adds it verbatim.**

**CGRID (computational grid, incl. rotation)** — manual §4.5.1 (line 1434):
```
CGRID REGular [xpc] [ypc] [alpc] [xlenc] [ylenc] [mxc] [myc] CIRcle [mdc] [flow] [fhigh] [msc]
```
`[alpc]` = direction of the positive x-axis (degrees, **Cartesian** convention; default 0.0) — this is the L4
rotation angle. `[mxc] [myc]` = number of **meshes** (points = meshes+1). Our spectral tail is `CIRCLE 72 0.03 1.0 34`
(directional 72 = 5°) — **do not change the spectral block**; only `alpc`/extent values change, and only in the
flagged multi-grid task.

**NGRID (nested-grid output boundary)** — extract §NGRID (manual line 1160):
```
NGRID 'sname' [xpn] [ypn] [alpn] [xlenn] [ylenn] [mxn] [myn]
```
The NGRID rectangle MUST match the child CGRID boundaries. `[alpn]` = child rotation (Cartesian degrees).

**NESTOUT / BOUNDNEST1 (nesting I/O)** — extract §NESTOUT/§BOUNDNEST1:
```
NESTOUT 'sname' 'fname' OUTPUT [tbegnst] [deltnst] SEC|MIN|HR|DAY
BOUNDNEST1 NEST 'fname' CLOSED
```
**CRITICAL:** BOUNDNEST1's read file and NESTOUT's write file MUST have different names in one workdir (else the
child reads corrupt data — the 2026-07-19 zero-energy bug). Runner copies parent `nest_out.dat` → child
`nest_in.dat` between levels.

**BOUNDSPEC SIDE (WW3 boundary side)** — manual §BOUNDSPEC (line 2380):
```
BOUNDSPEC SIDE North|NW|West|SW|South|SE|East|NE  CCW|CLOCKWise  VARIABLE FILE <[len] 'fname' [seq]>
```
The manual supports all 8 tokens; `CCW` is the default. In **Cartesian** mode, side is relative to the grid frame
and `SET [north]` defines North (positive x-axis defaults to East). **`VARIABLE PAR` is forbidden here** (collapses
swell partitions); one real 2-D spectrum file per station. **Our selection pipeline is cardinal-only (N/E/S/W)** —
`swan_formats.py:2347` iterates only `("N","E","S","W")`; a diagonal key is silently dropped. Choosing a different
**cardinal** side is a **value change**; the **side set is off-limits to extend** (do not add diagonals).

**OBSTACLE (structure line/footprint)** — extract §SURFBEAT/OBSTACLE + PROVIDER-MANUAL:
```
OBSTACLE TRANSm [trcoef] LINE < [x] [y] >
OBSTACLE DAM < GODA [hgt] [alpha] [beta] | DANGremond [hgt] [slope] [Bk] > LINE < [x] [y] >
OBSTACLE ... REFLec [reflc] RSPEC|RDIFF [pown] LINE < [x] [y] >
```
(DAM has two sub-forms; live code emits `DAM GODA 3.0 0.4 0.8` and `DAM DANGremond 2.0 0.5 10.0` — note DANGremond's
params are `[hgt] [slope] [Bk]`, not `[hgt] [alpha] [beta]`. G4.5 keeps the existing DAM forms; do not alter them.)
Lines wrap at ≤180 chars with `&` continuation (T1.1). `LINE` takes the (simplified centerline) vertex list.

**INPGRID/READINP BOTTOM (bathymetry injection)** — extract §INPGRID (manual line 1106):
```
INPGRID BOTTOM REG [xpinp] [ypinp] [alpinp] [mxinp] [myinp] [dxinp] [dyinp]
READINP BOTTOM [fac] 'fname' [idla] [nhedf] FREE
```
`INPGRID BOTTOM` is **stationary only** (no `NONSTAT`). We use `[idla]=3` (south-to-north, west-to-east). Burning
footprints (T4.2) changes the **values in `BOTTOM.txt`**, not this syntax.

**Per-level physics / spectral blocks are OFF-LIMITS** (extract §"Per-level physics summary"): `GEN3 WESTHUYSEN`,
`BREAKING CONSTANT 1.0 0.73`, `FRICTION JON`, `TRIAD`, `DIFFRACTION 1 0.2 27` (L4 only), `NUMERIC ... alfa=0.01`,
`CIRCLE 72 …`. This plan changes none of them.

---

## Decision log
- **2026-07-30** — Plan created from STUDY-AREA-GEOMETRY-BRIEF (Fable-reviewed x2, 24 findings incorporated) +
  operator directions. Supersedes MARINE-WORKING-MODEL-PLAN. Architecture decisions AD-1..AD-8 stated for
  approval-via-plan. Off-limits fence and full carry-forward audit recorded.
- **2026-07-31** — G1's facing method found wrong (Critical finding 1; plus the 1 km-grid call-site defect found
  in review). Researched USGS DSAS (smoothed-baseline transect casting, 500–2500 m smoothing distance) and
  CliffMetrics v1.0 (DEM shoreline trace → coordinate moving-average → before/after tangent normals). **AD-1R**
  written with operator-required pinned equations; **PHASE G1R** added (serve-nothing guard G1R.0, method
  replacement G1R.1–.2, override key G1R.3, doc-sync G1R.4, Gate G1R = the one-full-run Gate-G4 retest). Operator
  approved all decisions in chat except the shoreline-strip fetch (pending — see ledger). ARCHITECTURE.md
  geometry bullet updated to AD-1R the same day.
