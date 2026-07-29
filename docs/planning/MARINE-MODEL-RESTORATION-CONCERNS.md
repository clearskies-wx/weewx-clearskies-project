# Marine Model Restoration — Concerns Register

**Opened:** 2026-07-28
**Owner:** Coordinator
**Purpose:** One place for every item the coordinator is concerned about while executing
`MARINE-MODEL-RESTORATION-PLAN.md` (Phase E deploy / Gate E and beyond). Non-blocking items
are logged and followed up later; blocking items carry a recorded decision, its evidence, and
the documents consulted. Per the operator's standing instruction: log the concern, do not
chase rabbit holes.

**Status key:** OPEN = follow up later, no impact on current work. DECIDED = was blocking,
decision recorded below and work proceeded. CLOSED = resolved, evidence recorded.

Companion register for the completed Separation work: [MARINE-SEP-CONCERNS.md](../archive/MARINE-SEP-CONCERNS.md).

---

## C-E01 — Bolsa Chica derived `beach_facing_degrees` points inland (OPEN)

**Severity:** Non-blocking now (Bolsa Chica is not in the current HB-only deploy) — but
**must be verified before Bolsa Chica goes live**, or its surf forecast could be computed
along the wrong axis.

**Finding.** Bolsa Chica State Beach is an open-beach surf spot the operator added on
2026-07-28. Its shoreline segment (segment_start 33.683225, -118.037567 → segment_end
33.723205, -118.079138) runs ~319° (NW–SE); the ocean is to the SW (~229°). `beach_facing_degrees`
is not stored in config — it is derived by `_perpendicular_bearing(_segment_bearing(...))` in
`weewx_clearskies_marine/config/marine_config.py`, which rotates **+90° clockwise**. For this
segment that yields **49.2° (NE, i.e. inland)**, not the ~229° seaward direction. The
`_perpendicular_bearing` docstring claims "either perpendicular direction gives a consistent
result" because the surf endpoint uses the value only for directional-exposure comparisons, and
asserts the transect march direction is resolved seaward downstream — but this has **not been
verified** for a spot whose derived facing lands on the inland side.

**What to check when Bolsa Chica is brought online (do NOT research now):** confirm the
per-transect profiles actually march **seaward** (depths decreasing away from shore, toward the
SW), not inland. A profile that marches inland would show increasing land elevation / no valid
seabed and is the tell. If it marches the wrong way, the fix is in the facing derivation or the
transect-direction resolution, not in config.

**Evidence gathered this session:** derived facing = 49.2° via the real
`_perpendicular_bearing`/`_segment_bearing`; segment bearing 319.2°; `compute_spot_transects`
produced ~589 transects without error at 10 m spacing.

---

## C-E02 — Admin/wizard drops structure coordinates on save (OPEN)

**Severity:** Non-blocking for the manual-config-push workflow, but a real data-loss bug in the
admin UI that will bite anyone who edits a structure spot through it.

**Finding.** After the operator edited config via the admin page on 2026-07-28, the live
`/etc/weewx-clearskies/marine/marine.conf` on librewxr had the HB pier structure present
(`"0"`, `type: pier`) but with **`coordinates: None`** — the real 35-point OSM pier polygon
(persisted through the E13 wizard→api→marine path) was gone. Grid sizing cannot build the pier
obstacle or the L4 structure grid without it, so deploying the live config as-is would leave HB
non-functional. The coordinator's hand-built payload (`C:/tmp/marine_payload.json`) still holds
the real polygon; the deploy restores it by pushing that geometry, not the admin-saved config.

**Consistent with the known state:** the resume brief already records "The wizard/admin UI is
currently BROKEN (operator: fix later; use manual config push for now)." This entry pins the
specific failure mode — **structure `coordinates` are silently dropped on admin save** — so the
admin-UI fix has a concrete symptom to target.

**Follow-up:** when the admin UI is repaired, add a round-trip guard that a structure spot saved
through the admin retains its `coordinates` (endpoints within ~10 m of the OSM base/tip), mirroring
the E13 wizard guard.

---

## C-E03 — Bolsa Chica at 10 m transect spacing = ~589 transects (OPEN)

**Severity:** Non-blocking now (excluded from the HB-only deploy, pending operator decision on
spacing) — but a cadence risk if brought online at 10 m.

**Finding.** Bolsa Chica's segment is **~5.88 km** long. At the configured `transect_spacing_m`
= 10 m that is **~589 transects** — roughly 18× the HB pier spot's 32 — each requiring its own
per-transect seabed profile and 1-D surf-chain run every cycle. Gate E's cadence row targets
~7 min at ~12,600 cells for HB alone; a 589-transect open-beach spot in the same cycle would
likely blow that budget and confound Gate E.

**Coordinator recommendation (not yet decided by operator):** for a long, straight, structure-free
beach where alongshore surf varies slowly, ~200 m spacing (~30 transects) captures the real
variation at a fraction of the cost. Operator to choose the value before Bolsa Chica is included
in a deploy.

**Related:** C-E01 (same spot, orientation) and the F1 open-beach bbox remediation (marine
`bb01e96`), which is a prerequisite for any open-beach spot to sample native-resolution
bathymetry at all.

---

## C-E04 — The nearshore SWAN grids re-fetch bathymetry we already have on disk (OPEN)

**Severity:** Non-blocking (efficiency + architecture cleanliness), but flagged because the
immediate apply-time-download fix (the E4→E2b gap, tracked separately) leaves this redundancy in
place.

**Reference fact — record and do not re-derive:** **Huntington Beach's best available native
bathymetry is 10 m** (NCEI/CUDEM). `_PROFILE_MIN_RESOLUTION_M = 3.0` is only the *requested floor*;
the download path only ever downsamples, so at HB requesting 3 m returns the native **10 m**
(coarsen factor 1). 3 m only takes effect where a location's DEM is finer than HB's. This is why the
HB profile came back at ~10.3 m spacing. (Consistent with D7 and the operator ruling of 2026-07-28.)

**Distinction to keep straight:** grid resolution (SWAN computational cell spacing: L1 1 km / L2 100 m /
L3 40 m / L4 10 m) ≠ bathymetry (DEM source) resolution (10 m native at HB). BUT — checked against
`docs/reference/swan-user-manual.pdf` §2.6.2 — this does NOT mean "one native seabed for all grids."
SWAN obtains bottom values by **tri-linear (pointwise) interpolation** from the input grid onto the
computational grid; it does **not** average sub-grid cells, and the manual explicitly warns a feature
"may be 'lost' in the interpolation … otherwise the ridge may be 'lost'," recommending the input grid
be **≈ identical to the computational grid**. So handing native 10 m to a 40 m computational grid is
the *worse* option (aliasing / lost features), not the better one.

**Conclusion after the manual check: the current per-grid coarsening is CORRECT and manual-aligned,
NOT a bug.** `download_bathymetry_for_level(cluster.grid, level=N)` averaging the DEM to each grid's
resolution produces input≈computational, which is what SWAN wants. The finest breaking-relevant
features (sandbars) are captured at **L4** (10 m grid fed 10 m seabed = zero interpolation loss); L3/L2
are coarser nests that cannot resolve sub-grid features by design. The **D1 1-D profile keeps its own
native 10 m PROFILE cache** (separate from every SWAN grid) — that is the native resolution that must
never be coarsened, and the profile fix keeps it decoupled. (L1 is a different dataset — ETOPO ~460 m.
L2 extends past the ~15 m contour, beyond fine-DEM coverage, so it is legitimately sourced coarser via
the download source-order fallback; `_covers()` prevents SWAN's silent lateral-shift extrapolation
outside the input grid — the C-90 fabrication guard.)

**So this is NOT an architectural concern — downgraded to network efficiency only.** The only real
defect is separate and narrow: the L3-nest and L4 compute caches are not *written* at apply (the
E4→E2b gap, being fixed by writing them at apply at each grid's resolution via the shared
`download_all_bathymetry`, so runtime keys match). The remaining efficiency nit: the same source
region is fetched more than once at different resolutions; could fetch nearshore once at native and
coarsen LOCALLY per grid instead of re-fetching from NCEI. Optimization only — revisit if fetch cost
matters. Do NOT turn this into a single-native-bathymetry-for-all-grids refactor; the manual says that
is wrong.

**Interim (chosen to unblock, pending operator confirmation):** let the existing per-grid path fetch
the two small missing grids (L3-nest, L4 — seconds of network; L1/L2 stay disk cache hits) so HB runs
and Gate E can be walked. Revisit single-source resampling here.

---

## C-E05 — Multi-swell partition breakdown collapses 3 trains → 1 (BIG DEFECT, fix required) (OPEN)

**Severity:** HIGH — a real correctness defect in the *published* forecast, confirmed against an
external observation. **Operator ruling 2026-07-28: this must be fixed, but AFTER the rest of the
Marine Model Restoration Plan — log here, focus on finishing the plan first.** Not a Phase E grid
blocker (Phase E was grid strategy; this is the spectral-partition subsystem). Belongs to the
C-81/C-83 spectral-partition class and is **Phase-F-adjacent** — take the fix up under Phase F.

**Finding.** On 2026-07-28 the first full HB run published a forecast whose **aggregate is correct**
but whose **swell-train breakdown is empty**:

- **Reality (Surfline LOTUS + Smart Cam, same timestamp):** THREE swell trains — 18 s SSW 195°
  (1.9 ft), 16 s SSE 168° (1.9 ft, near-equal to primary), 10 s S 184° (1.1 ft). Observed surf
  **4–5 ft** face, rating 1–2/10.
- **Ours:** primary height/period/direction MATCH reality (**4.6–5.0 ft face, 17.5 s, SSW 200°** —
  validated ✓), but `multiSwell` = `[{one real partition}, null]` → published as **(0,0,0) zeros**;
  `spectralComponents = []` empty. Internal trace `per_transect[0].per_partition =
  [{partition 0: face 1.33 m, spilling…}, null]` — exactly ONE real partition resolved.

**Root-cause locus (diagnosed, not yet fixed).** The full 2-D spectrum IS captured and stored
(`spot.spectral` / `spectral_dwr`, `freqs_hz` present) — so the SWAN side is fine. The **watershed
partitioning of that spectrum collapses all trains into one**. Runtime tell: `SWAN watershed: … no
PT* partitions available for the L2 DWR baseline; components empty for this timestep (T4B.2
no-silent-fallback rule)`. (The L4 per-transect `TABLE_PT_*` are all SWAN-exception −9/−99, but that
is expected — the 15 m handoff points sit outside the shallow L4 structure grid; the handoff spectrum
comes from the L2 DWR SPEC2D, not L4 PT.)

**Why it matters (not cosmetic).** The missing SSE 168° secondary is near-equal to the primary and
27° off it — the swell-dominance / cross-swell / peel-angle scoring cannot see it, which likely also
drives the uniform `peel=closeout` result. "Total right, distribution wrong" is the hard failure mode
(rules/verification.md); aggregate agreement did NOT license skipping the spectral comparison, and the
spectral comparison fails 1-vs-3.

**Follow-up (Phase F or a dedicated task):** fix the DWR-baseline spectral watershed so it resolves
the multiple trains present in the stored 2-D spectrum; add a known-answer/guard test that a spectrum
carrying ≥2 separated peaks partitions to ≥2 non-zero components; re-validate against a real
multi-train Surfline/NDBC read. Relentless check: a run that publishes 1 partition where the buoy
spectrum resolves several is C-81/C-83 recurring — do not accept a single-partition publish as a pass.
Related: [[C-81]] [[C-83]]; Phase F (`swan_spectral.py` `watershed_partitions_to_component_format`).

---

## C-E06 — Invariant 3 fires (health=degraded) on 0/32 shadowed at HB — is that right? (OPEN, low)

**Severity:** Low — does not affect the published surf numbers (validated ✓ under [[C-E05]]); it keeps
`/health` at `degraded`. Defer with C-E05 (revisit under quality/Phase-F). This is the live resolution
of **E11 item 2 / Gate E row 19**.

**Finding.** With the real HB config deployed, invariant 3
(`structures_configured_implies_shadowed`) **evaluates the pier** — so E11 item 2's structural
question ("does the structure reach every shadow call site?") is **answered YES**: the machinery
reaches the call site, `count: 1` structure. Its **result**, however, is **0 of 32 transects
`is_structure_affected`**, so the invariant fires every cycle and health reads `degraded`.

Two unresolved possibilities, not yet distinguished (not chased per operator's focus-the-plan steer):
(a) 0-shadowed is **geometrically correct** — the pier is `semi_permeable` (TRANSM 0.82, transmits
82%), the swell is SSW ~200°, and the spot's 315 m transect fan may sit off the pier's shadow axis;
in that case invariant 3 **over-fires** for legitimately-unshadowed semi-permeable geometries and
should be rescoped (a structure with high transmission and an off-axis fan shadowing nothing is not
an error). (b) A **shadow-classification threshold/geometry defect** suppresses affected transects.

**Follow-up:** SUPERSEDED by [[C-E07]] — the blind adversarial pass (2026-07-28) + coordinator
re-verification established this is possibility **(b), a defect**, not grazing geometry. See C-E07.

---

## C-E07 — Phase E's L4 structure grid is computed every cycle but NEVER consumed (HIGH, blocks Gate E row 9) (OPEN)

**Severity:** HIGH. This is a **Phase E acceptance failure** — the whole deliverable (a rotated L4
structure grid feeding per-transect handoff at breaking depth) is built and run but its output is
discarded; the surf forecast silently uses the pre-Phase-E `L1→L2→1D@15m` production path. **Blocks
Gate E row 9 (and is the true cause of row 19 / [[C-E06]]).** Found by the blind adversarial auditor
2026-07-28, then **independently re-verified by the coordinator** (findings below are the
coordinator's own confirmation, not the agent's report taken on faith).

**Evidence (live, 2026-07-28 run):**
- E5 defines rule 1 = read per-transect POINTS from **L4 at the per-hour 1.3·Hs/0.73 depth** when a
  transect's cross-shore line enters the structure-grid footprint; rule 3 = **L2 at fixed 15.0 m**
  (`transect_handoff.py:79 L2_REFERENCE_DEPTH_M`). E5's own live check: *"at HB the structure grid
  covers all 32 transects, so every transect must resolve to rule 1. If any resolves to rule 3 …
  report, do not adjust."*
- Live trace: **all 32** transects, every forecast hour (2304 `profile_to_1d` records),
  `handoff_depth_m = 15.0`, `handoff_source_level = L2` → **100% rule 3.** (Coordinator confirmed the
  same 15.0/L2 in `forecast_cache.json` `swelltrack.per_transect`.)
- Root cause locus: `journalctl` every cycle logs `Structure pier(0m): seaward tip depth = 0.0 m`
  then `Transect N … shadowed=False, structures=[]` for all 32. The structure reaches
  `compute_transect_shadows` **degraded** — the label `pier(0m)` means `length_m` rounds to 0
  (config has 566.8), and `_structure_seaward_tip_depth()` returns 0.0, so the structure is
  **excluded** at `transect_handoff.py:462-466` (`"no usable coordinates — excluded"`) before the
  touch/shadow geometry is ever evaluated. `structures=[]` (not `[pier], shadowed=False`) is the tell:
  dropped, not "evaluated and found not to shadow."
- Consequence: L4's per-transect POINTS output (5136 cells) is computed each cycle and never read for
  handoff. The 2026-07-28 reality match (4.6–5.0 ft face vs Surfline 4–5 ft) therefore validates the
  **L2→15 m→1D path**, NOT Phase E's structure pathway — "right, but by the fallback firing silently."

**CORRECTED ROOT CAUSE (2026-07-28, impl-agent diagnosis + coordinator independent re-verification —
supersedes the structure-drop hypothesis below, which was a red herring):**

The real blocker is **L4 SWAN convergence FAILURE**, not a handoff-selection/structure-drop bug.
Journal (23:10:24Z): `SWAN convergence level4_0: … valid_fraction=0.0%` → `convergence FAILED
level=level4_0` → `SWAN L4[0]: … no L4 result this cycle … falling back to the L2 DWR reference`.
That fallback is why all 32 transects land on rule 3 / L2. L1/L2/L3 all converge 100%; only L4 fails.

**Mechanism (coordinator-verified, decisive):** L4's emitted `INPGRID BOTTOM` is written at the
**rotated CGRID's own footprint** — `INPGRID BOTTOM REG 406523.63 3724752.94 0. 48 107 10.07 10.01`,
i.e. **rotation `0.`, origin = CGRID origin, dims = CGRID dims (48×107)** — while the CGRID itself is
**`CGRID REG … 228.50 …`** (rotated 228.5°) from that *same* origin. An axis-aligned input grid and a
228.5°-rotated computational grid sharing one origin sweep into opposite directions, so ~all
computational cells fall OUTSIDE the input-grid footprint → SWAN sets them dry → 0% valid. Verified:
`level4_0/BOTTOM.txt` holds **5232 real depths, 0 exception cells** (the bathymetry is fine); `level4_0/
TABLE_1.txt` POINTS all report `Depth=-99.0` (dry). L3 uses the identical BOTTOM format and converges
because it is unrotated (INPGRID 0. matches CGRID 0.).

The **resample already built the correct enclosing grid** — the L4 bathymetry cache is `328×322` (the
rotated rectangle + `l4_coverage_domain`'s full-span margin, axis-aligned). The defect is that the
**BOTTOM/INPGRID emitter uses the CGRID's 48×107 footprint instead of that enclosing coverage box.**
So the fix keeps INPGRID rotation `0.` (consistent with Gate E row 5) but corrects the BOTTOM
**extent + origin** to the enclosing axis-aligned coverage box the cache already spans — a
bathymetry-emission geometry fix, NOT a grid/domain change. Fix locus: the L4 BOTTOM/INPGRID emission
in `swan_runner.py` / `swan_formats.py` (to be traced to the exact line by the fix agent). Check the
SWAN manual's rotated-CGRID + axis-aligned INPGRID coverage requirement.

**Coordinator corrections owed to the record:** (i) the earlier "all 4 levels converged" report was
WRONG — L4 failed (0% valid); (ii) Gate E **row 5 ("INPGRID emits 0.") was passed by both the
coordinator walk and the blind auditor as "matches expected string" — but emitting 0. at the CGRID's
own footprint (rather than an enclosing box) for a rotated grid is precisely the defect**; the string
matched while the geometry was wrong. Row 5 must be re-verified after the fix (INPGRID 0. AND
enclosing extent).

**Secondary real-but-cosmetic defect (do not lose):** `swan_runner.py:4607-4614` reconstructs
`StructureConfig` from the `build_obstacle_structures` dict copying only `type`+`coordinates`,
dropping `length_m` (hence the `pier(0m)` label); and `compute_spot_transects()` is called at the
runtime path (`swan_runner.py:4621`) without a `bathymetry_profile_fn`, so tip depth logs 0.0. Neither
affects rule selection (shadow classification is geometric and the L4/rule-1 path doesn't read it),
but both should be cleaned up so the logs stop lying. Land separately from the convergence fix.

**Superseded hypothesis (kept for history):** the `StructureConfig`/coordinates degradation reaching
`compute_transect_shadows` — traced and found NOT to hit the "no usable coordinates — excluded" branch
and NOT to drive rule selection. Not the cause. **Diagnose before editing — do not paper over.**

**Fix ownership:** implementation agent (`clearskies-api-dev`) to diagnose + fix, separate
`clearskies-test-author` guard (a real `StructureConfig` with coordinates must reach
`compute_transect_shadows` intact and at least the touching transects must resolve to rule 1), blind
`clearskies-auditor` — per the adversarial-QC rule. Related: [[C-E06]] (its 0-shadowed symptom),
[[C-E02]] (admin drops coordinates — a related structure-data-loss path, but this one occurs even
with a correct pushed config).

**NOTE — blind-audit finding F2 (pin-projection `111320` "still live in the API repo") was REJECTED
by coordinator re-verification.** The API's `providers/nearshore/` was pruned to an empty package
(only `__pycache__`) during the marine separation (C-49/C-60, commit `7b18108`); live source has no
`swan.py`, no `111320`, no `build_obstacle_structures` call (the auditor's cited call site
`setup.py:1982` is a skin-conf units dict). The auditor read **stale `.pyc` bytecode**. Gate E row 26
PASSES. Trivial hygiene only: sweep the orphan `.pyc` in the API `nearshore/__pycache__/` (inert —
Python won't import a `.pyc` without its `.py`).

---

## C-E08 — L4 `INPGRID WIND` has the same non-coverage as BOTTOM did (LOW, likely negligible) (OPEN)

**Severity:** LOW. Does NOT break convergence (that is bathymetry/depth only — see [[C-E07]]) and its
physics impact is expected to be negligible. Logged for completeness while fixing C-E07; **do not fix
in the C-E07 cycle** (operator decision 2026-07-28). Reconsider when the wind work is touched.

**Finding.** Same geometry defect as C-E07 but for the wind input grid: L4's emitted `INPGRID WIND` is
axis-aligned (rotation `0.`) at the rotated CGRID's own footprint, so it does not enclose the 228.5°-
rotated computational grid. Per SWAN User Manual §2.6.2, for points outside the wind input grid **SWAN
uses 0 m/s** (unlike bottom, which lateral-shifts). So SWAN currently runs L4 with ~zero local wind
over most of the grid. The C-E07 fix deliberately touches BOTTOM only and leaves WIND on the CGRID
footprint (agent scoped to BOTTOM/INPGRID; WIND left exactly as today).

**Why it's almost certainly negligible (the reason it is LOW, not HIGH):** L4 is a ~0.5–1 km²
nearshore structure grid at 10 m, boundary-forced from L3 (`BOUNDNEST1`). The wave field in L4 is
inherited swell advected across its boundary, not locally wind-generated — there is essentially no
fetch inside L4 for wind to grow new sea. Zero wind over that patch changes the L4 wave field
negligibly; the swell energy (what HB's forecast is made of) is unaffected. Zero wind is also a valid
calm input — it breaks nothing numerically.

**NOT Phase F.** Phase F is the **1-D analytical surf model's** wind source term (a different model,
downstream of SWAN's 15 m handoff) — it adds wind-sea *growth* to the 1-D model and samples
`blended_wind` for it. C-E08 is **SWAN's own L4 grid wind forcing** (upstream, a different input file).
They are parallel consumers of the same `blended_wind` field, not the same thing. Phase-F-*adjacent*
(both "wind"), so a natural time to reconsider C-E08 is when Phase F is in flight — but it is not a
Phase F task and Phase F does not fix it.

**Follow-up:** if ever fixed, apply the identical enclosing-coverage-box treatment C-E07 uses for
BOTTOM to the L4 `INPGRID WIND` emission (WIND.txt sampled on the coverage box, INPGRID WIND declared
at the coverage-box geometry, rotation stays `0.`). First confirm the impact is worth it with a
with/without comparison on a real run — do not fix on principle if the delta is in the noise.

---

## C-E09 — SWAN L3/L4 → D1 handoff plumbing is broken; spectrum has no 3 swell components (HIGH — the big one, fix after the rest of the plan) (OPEN)

**Severity:** HIGH. Operator ruling 2026-07-29: **log now, address after the rest of the plan is
done** (Phases F & D). This is the largest outstanding correctness problem in the marine forecast.

**FRAME THIS CORRECTLY (operator correction 2026-07-29):** The **D1 (1-D analytical surf) model works
well.** When SWAN L4 was failing and the handoff fell back to L2 at 15 m, the D1 model took that L2/15 m
handoff and propagated it to shore correctly — producing surf that **matches reality**: face
**4.6–5.0 ft** vs Surfline OBSERVED **4–6 ft**, period **17.5 s** vs reality **16–18 s**. That is the
D1 model doing its job on a correct handoff — **purposeful, not "accidentally right."** Do NOT
characterize the L2→D1 path as a lucky fallback; it is the currently-correct path. (Coordinator erred
earlier by calling it accidental and by comparing our surf-FACE height to surf-forecast's SWELL
heights — surf-forecast reports swell height only; Surfline reports surf/face 4–6 ft. Reality: swell
~1.9 ft@18s SSW + 1.9 ft@16s SSE + 1.1 ft@10s S; surf/face 4–6 ft.)

**Problem 1 — spectrum is wrong; the three swell components are missing (see [[C-E05]]).** Reality has
3 trains (18 s SSW, 16 s SSE, 10 s S). We publish 1 / empty (`spectralComponents=[]`, `multiSwell`
zeros). New symptom to add to C-E05: on the 2026-07-29 run the swell was also **flat/static across all
67 forecast hours** (`swellHeight` 2.9 ft, `period` 8.1 s, `direction` 207° all constant) — a 3-day
forecast must vary; the time-varying multi-train swell is not being resolved or fed through.

**Problem 2 — SWAN L3/L4 → D1 handoff plumbing is broken (distinct from the C-E07 coverage fix).**
After [[C-E07]] the L4 grid now **converges** (valid_fraction 100%) and all 32 transects select **rule
1 (L4 breaking depth)** — the `truncated_at_m` trace shows all 32 at ~1.5–1.7 m, not 15 m. BUT the
resulting D1 output is **worse than the L2→D1 path**:
- **Period collapses to 8.1 s (uniform)** vs 17.5 s on the L2 path and 16–18 s reality.
- **Surf face under-forecasts**: ~3.4 ft peak vs 4–6 ft observed.
- **Transects zero out**: at a sample hour, of 32 transects ~12 give a real ~1 m face, ~9 are present
  but zero, 11 are absent from `swelltrack.per_transect` entirely.
- Runtime log (T4B.3) states the mechanism candidly: the per-transect handoff **depth** is selected
  per transect at 10 m, but the **spectrum** (and its watershed components) is read from **ONE shared
  diagnostic CURVE at ~50 m**, nearest-station — not each transect's own L4 `TABLE PT*` columns
  (which ARE emitted per T4B.1 but not consumed). So the L4→D1 spectral handoff is coarse/shared and
  is mis-feeding period/energy to D1.
Net: switching the handoff from rule 3 (L2, which the good D1 model turns into a correct forecast) to
rule 1 (L4) currently **degrades** the forecast, because the L4→D1 per-transect spectral plumbing is
broken. The C-E07 coverage fix is architecturally correct and stays (L4 *should* converge); the
plumbing that extracts per-transect spectrum/period from the now-converging L4 and hands it to D1 is
what needs fixing.

**Current live state (operator aware):** the deployed forecast uses rule 1 (L4) → currently worse
period/height than the L2→D1 path. Left as-is per operator (log + move on); a stopgap of forcing the
L2→D1 handoff until the L4→D1 plumbing is fixed is available if desired.

**Fix (after the plan — Gate D / Phase F territory):** (1) read each transect's OWN L4 `TABLE PT*`
stations for the handoff spectrum instead of the shared CURVE; (2) fix the surfaced period quantity
(8.1 s looks like a mean/TM01 or mis-read value, not the swell peak the previous path reported);
(3) stop transects zeroing when L4 is the source (they must not come out worse than the L2 path would
have); (4) resolve the 3 swell components (C-E05). **Known-answer gate:** the L4-path output must match
or beat the L2-path output against Surfline/NDBC (face 4–6 ft, period 16–18 s, 3 trains) before rule 1
is trusted. Entangled with [[C-E05]]; both feed D1's input — fix together. Related: [[C-E07]] (coverage,
done), [[C-E08]] (L4 wind), [[C-E06]]/[[C-E02]] (shadow/structure data).

---
