# Smart-L3 disposition — evidence report (READ-ONLY investigation, 2026-08-03)

> Produced by the read-only Explore agent dispatched 2026-08-03 (decision item 7,
> AUDIT-OPUS-WINDOW-2026-08-03.md). Saved verbatim by the coordinator. Evidence only — the
> vestige-vs-future ruling is the operator's.

**Scope:** evidence only. No ruling. No files modified, no git writes.
**Repo root:** `c:\CODE\weather-belchertown`; marine code at `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`.

---

## 1. HISTORICAL DECISION RECORD — where smart L3 came from

### 1.1 Era 1 (pre-1D): L3 *was* the fine-detail model — 10 m, 15 m contour → shore

The earliest recorded L3 role is in `docs\planning\briefs\L3-1D-BOUNDARY-DECISIONS-BRIEF.md:14-35`, which reconstructs it from `SWAN-NESTING-RESEARCH-BRIEF` (a document **no longer present in the repo** — see §5 "searched, empty"):

> `L3-1D-BOUNDARY-DECISIONS-BRIEF.md:16-22` — "Three nested grids, all running to shore: | L1 | 1 km | GSFM shelf edge → shore | … | L3 | 10 m | shore → 15 m depth |"

The 15 m seaward edge came from **depth of closure**, quoted verbatim at `:34-35`:

> *"We use 15m: safely beyond the depth of closure (8-9m), provides full beach profile context, and aligns with the mid-range of published practice."*

And the brief's own reading of that, `:37-40`: *"That criterion sizes a grid whose job is **to contain the entire active beach profile**."*

The 3-level design was recorded in the **ARCHITECTURE.md changelog for 2026-07-18** (`docs\ARCHITECTURE.md:7`):

> *"Previous: 2026-07-18 (Phase 17: 3-level SWAN nesting redesign — 1 km/100 m/10 m levels, GSFM-based domain sizing, spot clustering, per-level bathymetry, compute calculator endpoint)."*

Same date, ADR-095/096/097 landed (`docs\decisions\INDEX.md:125-127`, all dated 2026-07-18). **ADR-096 and ADR-097 contain zero L3 references** (verified: `grep -c "L3"` → 0 on both). ADR-095 references L3 only as a *consumer* of the then-existing fine grid — `ADR-095-swan-model-corrections.md:89` (CURVE retained "for L3-enabled spots as a diagnostic/validation output") and `:93-95` (deep-water SPECOUT from L2 at the "L2→L3 boundary"; handoff SPECOUT "For L3-enabled spots: from L3 grid at the structure-affected handoff depth"). **No ADR of 2026-07-18 created or scoped smart L3** — it predates them.

### 1.2 Era 2 (2026-07-20): the 1-D model arrives; L3 is explicitly left alone

`L3-1D-BOUNDARY-DECISIONS-BRIEF.md:42-54` records `SURF-ZONE-MODEL-BRIEF` (2026-07-20) keeping L3 unchanged:

> `:50` — *"SWAN L3 runs to shore (current architecture, no changes)."*
> `:51-52` — *"Keep L3 to shore + add 1D post-processing. Zero risk. **This is the v1 approach.**"*
> `:53-54` — *"Truncate L3 at handoff depth. Loses all nearshore structure interaction. **Not recommended** for structure-affected spots."*

### 1.3 Era 3 (2026-07-21): **"smart L3" is born** — ADR-093 Amendment 1

This is the origin of the term. `docs\decisions\ADR-093-swan-trushore-nearshore-model.md:77-83`:

> `:81` — *"**1. L3 grid is now optional per location.** L3 is enabled automatically when Overpass API discovers structures near the spot, disabled for open beaches. … Spots with no structures skip L3 entirely — SPECOUT extracted from L2 at ~15m depth."*
> `:83` — *"**2. When L3 is enabled, grid is smart-sized around structures.** L3 bbox is computed from structure positions + shadow zone extent (structure length + 2× structure length downstream in predominant wave direction) + 100m pad. **A single pier on a 1km beach produces a ~500m L3 grid, not a 1km+ grid.**"*

Critically, `L3-1D-BOUNDARY-DECISIONS-BRIEF.md:72-75` flags what Amendment 1 did *not* do:

> *"**Read that example carefully: 500 m is an ALONGSHORE number.** Amendment 1 shrank L3 *along the beach* and made it *conditional*. It says nothing about L3's cross-shore extent."*

This is the function that survives today as `smart_size_l3_grid()` (`swan_domain.py:1383`), whose docstring still cites Amendment 1 §2 verbatim (`swan_domain.py:1400-1403`).

### 1.4 Era 3b (2026-07-25): ADR-093 Amendment 2 — smart L3 gains the topographic trigger and the viability test

`ADR-093-…:93-194`. Two clauses matter for this investigation:

> `:162-166` — *"**3. L3 trigger — operator classification, not structure discovery alone.** L3 turns on when either a manmade structure is discovered **or** the operator has classified the spot as a point break, headland, or bay break. The pre-existing trigger looked only for manmade objects via Overpass API, which meant a point break — the case where 2D refraction matters most and where SwellTrack is structurally least able to help — could never turn L3 on."*
> `:185-188` — *"**4. L3 viability test at setup.** The trigger is necessary but not sufficient. Compute L3's extent, then test it: if the grid cannot reach the feature it was created for — structure or headland — L3 provides nothing and is **disabled** for that cluster."*

Rationale for using operator classification rather than derivation, `:168-174`: *"A point break is defined by **alongshore** geometry… A single cross-shore profile cannot see this by construction… **Decision: use it.**"*

The same day, `L3-1D-BOUNDARY-DECISIONS-BRIEF.md:288-292` already contemplated L3's eventual removal:

> *"**Future direction (noted, not scoped).** A ray-tracing add-on to SwellTrack would give 2D shadow geometry at 1D cost… That path removes L3 **permanently** rather than conditionally… Not in scope; recorded so the L3 work is not over-invested in."*

### 1.5 Era 4 (2026-07-27): **L4 is introduced and takes over structure resolution + handoff**

Research: `docs\planning\briefs\SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md` (written 2026-07-27). Operator rulings are §0A:

- **D1 naming** (`:81-91`): *"Old name 'coarse L3' → **L3** — same tier, different extent."*
- **D2** (`:92-117`) — *"**L3 is need-driven, not standing.** … **L3 exists for exactly two reasons, and never otherwise:** 1. **As the nesting step under a structure grid.** 100 m → 12.5 m in one jump is 8:1; L3 at 30–40 m makes it 2.5:1 then 3.2:1… 2. **As the working refraction grid** at an operator-classified point break, headland, or bay."*
  Operator's recorded reasoning, `:116-117`: *"There is no reason to run an L3 grid if we are not actually using it for anything and the D1 model is adequate."*
- **D3 handoff rule** (`:119-151`) — *"Hand off as deep as possible…"*, with the first-match list at `:142-151`: rule 1 = L4, rule 2 = L3 refraction feature, rule 3 = L2 at 15 m.
- The self-audit at `:877-883` explicitly considered whether deleting the coarse L3 loses anything: *"The strip's only unique product was 2D field values between 15 m and ~1.75 m away from the structure's influence. Those transects revert to the L2-at-15 m path…"*

Ratified into the ADR as **Amendment 3** (`ADR-093-…:239-288`):

> `:248-260` — *"Findings §0A ruling **D2** replaced that single-purpose L3 with a need-driven grid that exists for exactly two reasons and never otherwise: (a) as the coarse nesting step under a new, separate fine grid — the **structure grid, tier L4**…; or (b) as the working refraction grid at an operator-classified point break, headland, or bay break, unchanged from Amendment 2's cross-shore sizing."*
> `:273-274` — *"L3's resolution changes from the fixed 10 m Amendment 2 assumed to a fixed **40 m** (`_L3_RESOLUTION_M`)."*
> `:276-278` — *"`DIFFRACTION` moves from L3 … to **L4 only**… because at L3's now coarser 40 m … diffraction is sub-resolution."*
> `:281-283` — *"L4's resolution is a **fixed 10 m constant**, not derived from wavelength (operator ruling, verbatim: *'Just use a 10m grid for when L4 is needed, period'*)."*

**This is the moment L4 takes structure resolution and the structure handoff.** Amendment 3 `:262-270` confines the reversal to role (a) and states role (b) — the smart-L3 refraction grid — is **unchanged**: *"For a role-(b) cluster (classification, no structure) L3's cross-shore extent is **unchanged** — Amendment 2 §2's breaking-depth-criterion shoreward edge and the 15 m contour offshore edge both still apply exactly as written there."*

### 1.6 Later amendments — no decision to retire smart L3; one decision that *entrenches* the containment role

- **Amendment 5** (2026-07-31, `ADR-093-…:399-560`) and **Amendment 6** (2026-08-01, `:562-618`) rewrote **L4's** axis/extent. Neither touches smart L3.
- **MARINE-GEOMETRY-MODEL-PLAN AD-5** (`docs\archive\MARINE-GEOMETRY-MODEL-PLAN.md:415-423`) proposed *replacing* the smart-L3 trigger: *"Point-break / headland / bay classification is **derived** from the measured shoreline/isobath curvature … and becomes the **L3-enable trigger** (which currently reads `topographic_feature`). The operator `topographic_feature` field is **dropped as a required input**."* Note `:421-422` — the field survives as *"an optional override for a sub-grid feature bathymetry cannot see (e.g. a submerged reef)."*
- **AD-5 / Phase G5 was PINNED, not executed.** `docs\planning\MARINE-FORWARD-PLAN.md:1307-1317` — the **most recent recorded decision touching smart L3**:

> *"**G5 — break-type from shoreline curvature → L3 trigger** *(AD-5)* — **PINNED 2026-08-02 (operator, in chat):** the 72-ray fan + AD-1R facing likely solved most of what G5 was for… **Operator clarification (same day): L3 and L4 are inseparable — whenever L4 exists, L3 MUST exist as the L2→L3 step-down that keeps SWAN's nesting grid ratios; there is no standalone "should L3 exist" decision on a structure spot.** The trigger question G5 addressed therefore only applies to the STRUCTURELESS curved-shore case (a point break / headland / bay with no L4, where the fine nest would be wanted for the shore shape alone) — and that case still reads the operator-typed `topographic_feature` config field, which is acceptable for now. Revisit ONLY if a real structureless spot mis-grids on setup (that event un-pins it; then: evaluation first…, trigger-only change, L3 emitter untouched)."*

### 1.7 Answer to Q1, stated plainly

| Question | Record |
|---|---|
| Original role | Fine-detail nearshore model, 10 m, 15 m contour → shore, sized on depth of closure. `L3-1D-BOUNDARY-DECISIONS-BRIEF.md:16-40`; ARCHITECTURE changelog 2026-07-18 (`ARCHITECTURE.md:7`) |
| "Smart" sizing introduced | ADR-093 **Amendment 1, 2026-07-21**, §2 (`ADR-093-…:83`) — alongshore only |
| Topographic trigger added | ADR-093 **Amendment 2, 2026-07-25**, §3 (`ADR-093-…:162-166`) |
| Viability test added | ADR-093 **Amendment 2**, §4 (`ADR-093-…:185-194`) |
| L4 introduced; took structure resolution + handoff | Operator ruling 2026-07-27 (`SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:92-151`), ratified ADR-093 **Amendment 3** (`ADR-093-…:239-288`) |
| **Decision to keep smart L3?** | **Yes, implicitly and twice.** Amendment 3 `:262-270` explicitly preserves role (b) unchanged. MARINE-FORWARD-PLAN `:1307-1317` (2026-08-02) pins the trigger question: structureless case "still reads the operator-typed `topographic_feature` config field, which is acceptable for now." |
| **Decision to rewire smart L3?** | **No.** The handoff wiring is a documented open gap (§4). No document schedules it. |
| **Decision to retire smart L3?** | **No document records one.** The nearest is the non-binding note at `L3-1D-BOUNDARY-DECISIONS-BRIEF.md:288-292` (SwellTrack ray-tracing would remove L3 permanently — "Not in scope"). |

---

## 2. SCIENTIFIC BASIS — from the local SWAN manual only

Source: `docs\reference\swan-user-manual.txt` (Cycle III 41.51). No web search used.

### 2.1 Is there a nesting *ratio* rule? — Only one, and it does not govern SWAN-in-SWAN

The **only** ratio statement in the entire manual is at **`swan-user-manual.txt:433-435`**, inside §2.4 (SWAN vs WAM/WAVEWATCH III):

> *"Also, the spatial and spectral resolutions should not differ more than a factor two or three. **If a finer resolution is required, a second or third nesting may be needed.**"*

Its own governing context is `:427-433`: *"**When SWAN is nested in WAM or WAVEWATCH III**, it must be noted that the boundary conditions for SWAN provided by WAM or WAVEWATCH III may not be model consistent…"* — i.e. a **cross-model** boundary rule, motivated by *"differences in numerical techniques employed and implementation"* (`:429-431`). Verified by regex: `factor two|two or three` appears **exactly once** in the file.

**The SWAN-in-SWAN nesting sections impose no ratio at all:**
- §2.1 (`:246-257`): *"first compute the waves on a coarse grid for a larger region and then on a finer grid for a smaller region… Nesting can be repeated on ever decreasing scales."* No ratio.
- `BOUNDNEST1` (`:2568-2594`): requires only geometric coincidence (`:2577-2580`), and `:2585-2587`: *"use the command CGRID with identical geographical information **except the number of meshes (which will be much higher for the nested run)**."* "Much higher" is a lower bound, not a cap.
- `NGRID`/`NESTOUT` carry no ratio either (confirmed against `docs\reference\swan-commands-extract.md:224-293`).

**⚠ Discrepancy found in a project reference doc.** `docs\reference\swan-nesting-reference.md:47` states: *"**Nesting ratio guidance (§3.5):** The SWAN manual recommends nesting ratios of 2-3x (e.g., 300m parent → 100m child)."* — and `:48-49` then grades L1→L2 and L2→L3 as *"**10:1 ratio** — exceeds recommendation."* **The local manual contains no such §3.5 rule.** The only 2–3× text is the WAM/WW3 statement at `:433-435`. Unverified secondary claim, not SWAN guidance.

**On the manual alone:** a direct 100 m → 10 m nest is **not** prohibited, and no manual passage makes an intermediate grid *scientifically required*. Conversely `:434-435` ("a second or third nesting may be needed") is the closest warrant for one — written about a different (cross-model) situation.

### 2.2 What the manual *does* say about resolution sufficiency

1. **`:703-706`** — *"The spatial resolution of the computational grid should be sufficient to resolve relevant details of the wave field. **Usually a good choice is to take the resolution of the computational grid approximately equal to that of the bottom or current grid.**"* → resolution pinned to the **DEM**, not the parent grid. (HB DEM is 10 m — `SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:213-215` — so 40 m is coarser than data; 10 m matches it.)
2. **`:599-616`** — bathymetric-feature resolution: *"Special care is required in cases with sharp and shallow ridges (sand bars, shoals)… **Very inaccurate bathymetry can result in very inaccurate refraction computations the results of which can propagate into areas where refraction as such is not significant**… waves skirting an island that is poorly resolved may propagate beyond the island with entirely wrong directions."* The manual's strongest statement on **topographic-feature resolution** — a warning about *refraction error propagation*, the exact physics smart L3 exists to compute.
3. **`:3892-3893` (DIFFRACTION)** — *"The spatial resolution near (the tip of) the diffraction obstacle should be **1/5 to 1/10 of the dominant wave length**."* Obstacle-specific — it sized **L4**, not L3 (12–26 m at the HB pier tip, `SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:396-408`). Consistent with Amendment 3's move of DIFFRACTION off L3: at 40 m, a 118–132 m wavelength gives ≈ L/3, coarser than the manual's L/5 floor.
4. **`:3657-3665` (OBSTACLE)** — *"the resolution of the obstacle is therefore equal to the computational grid spacing… an obstacle to be effective must be located such that it crosses at least one grid line."* → a 40 m grid can only represent features spanning ≥ 40 m.

**No passage states a "4–5 cells across a feature" rule.** That figure appears only in `SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:415-418` tagged `[MEASURED + SOURCE]` without a manual cite. Natural basis for a size-aware criterion (40 m grid ⇒ features ≳ 160–200 m), but **not manual-sourced**.

### 2.3 Where the "intermediate grid" warrant actually comes from

Not the manual. **Operator ruling D2 item 1** (`SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:100-101`): *"100 m → 12.5 m in one jump is 8:1; L3 at 30–40 m makes it 2.5:1 then 3.2:1."* The targets satisfy the *"factor two or three"* figure — the WAM/WW3 rule applied by analogy to SWAN-in-SWAN. The research doc was honest the risk is unquantified — `:498-504`: *"**The SWAN manual imposes no fixed parent:child ratio** … adequate **provided the boundary sits in smooth water** … **Flagged for verification on first run**."*

**Q2 answer:** From the installed manual alone, a 100 m → 10 m direct nest is **not** ruled out and an intermediate grid is **not** required; the manual's own criteria are DEM-matching (`:703-706`), feature-resolution/refraction-error (`:599-616`), and the L/5–L/10 diffraction rule (`:3892-3893`). The L3-as-step-down rationale applies `:433-435` (a WAM/WW3 rule) by analogy — defensible engineering, not manual mandate.

---

## 3. THE ACTUAL RESOLUTIONS — the discrepancy resolved

### 3.1 The single constant

```
swan_domain.py:333    _L3_RESOLUTION_M = 40.0
```
Provenance comment `swan_domain.py:325-332`: *"Plan task E4 (findings §0A D2/D8, D6 item 5): L3's resolution under the need-driven redesign, **used uniformly for both trigger roles** … Replaces the old default of 10 m … **there is no reading of the post-D2 findings that keeps a 10 m L3 for either surviving role.**"*

### 3.2 (a) Coarse containment L3 — **40 m**

- `swan_domain.py:2380-2386` — `size_l3_coarse_nest(..., resolution_m: float = _L3_RESOLUTION_M)`
- Call site takes the default: `grid_sizing_chain.py:2385-2388` — `resolution_m` not passed → 40.0.
- Emitted grid uses it: `swan_runner.py:4028` — `override_resolution_m=cluster.grid.resolution_m`.

### 3.3 (b) Smart L3 — **also 40 m**

- `swan_domain.py:626` — `compute_domains(..., level3_resolution_m: float = _L3_RESOLUTION_M)`
- `swan_domain.py:902` — `_compute_level3_grid(..., resolution_m: float = _L3_RESOLUTION_M)`
- `swan_domain.py:764-768` — `_size_l3_cluster(..., resolution_m=level3_resolution_m, ...)`
- `swan_domain.py:1751-1755` — `smart_size_l3_grid(..., resolution_m=resolution_m, ...)` — caller **always overrides**.

**Two stale 10 m artifacts, dead:** `swan_domain.py:1388` (signature default 10.0, never reached) and `:1427` (docstring "default 10 m").

### 3.4 The "10 m" in the journal is a **hardcoded log literal, not a value**

```
swan_runner.py:3967    override_resolution_m=cluster.grid.resolution_m,     ← real value (40.0)
swan_runner.py:3974        "SWAN L3[%d]: %d×%d cells at 10 m (%d spots) in %s"   ← literal "10 m"

swan_runner.py:4028    override_resolution_m=cluster.grid.resolution_m,     ← real value (40.0)
swan_runner.py:4062        "SWAN L3[%d]: %d×%d cells at 10 m (middle grid, nests "
swan_runner.py:4063        "L4) in %s", idx, l3_grid["mxc"], l3_grid["myc"], l3_dir,
```

No `%` placeholder for resolution at all — unlike the L4 line which does it correctly (`swan_runner.py:4182-4186`, `"at %.0f m"`).

**Geometry sanity check:** journal reports 51×46 cells. At 40 m ≈ 2040 × 1840 m — consistent with the containment-nest bbox 33.6413–33.6577 (≈1820 m; `AUDIT-OPUS-WINDOW-2026-08-03.md:555-556`). At 10 m it would be ≈510 × 460 m — does **not** match. Bbox confirms 40 m.

### 3.5 Related stale 10 m references (documentation only)

- `providers/nearshore/swan.py:481` — "(10 m grid)"; `:676` — "10 m at L3"
- `docs\ARCHITECTURE.md:119` — "(10 m spacing…)" — contradicts `:117` which correctly says 40 m.

### 3.6 Answer to Q3

| Grid | Designed resolution | Citation |
|---|---|---|
| L1 | 1 km | `swan_domain.py:624`, `:807` |
| L2 | 100 m | `swan_domain.py:625`, `:853` |
| **(a) L3 coarse containment nest** | **40 m** | `swan_domain.py:333` + `:2386`, defaulted at `grid_sizing_chain.py:2385-2388` |
| **(b) smart L3** | **40 m** | `swan_domain.py:333` + `:626`/`:902`, overriding `:1388` at `:1755` |
| L4 structure grid | **10 m fixed** | `ADR-093-…:281-283`; `swan_domain.py:150`, `:1905`, `:2117` |

**The operator's "40 m" belief is correct — for *both* L3 roles.** The journal's "10 m" is a log-string literal left behind by Amendment 3's 10 m → 40 m change. The only thing genuinely running at 10 m is **L4**.

---

## 4. WIRING GAP + TRIGGER LIST

### 4.1 (a) The KNOWN GAP text — **line drift confirmed**

**Reported:** `transect_handoff.py:888-902`. **Actual at HEAD: `transect_handoff.py:924-937`** (+36 lines; stale citation also in `AUDIT-OPUS-WINDOW-2026-08-03.md:554-555`). Verbatim (`:923-937`):

```
    # ---- Rule 2 (E5 D3, "today's path", pre-existing code, unmodified). ----
    # KNOWN GAP (plan E5, coordinator ruling 2026-07-27): this branch (L3 as
    # a classified-refraction grid, for transects the L4 structure grid does
    # NOT cover) is pure selection logic only. It is NOT wired in the run
    # path today: swan_runner.py runs L3 with grid_level="outer" whenever it
    # nests an L4 structure grid, and "outer" writes no per-transect
    # POINTS/CURVE/TABLE output at all — so there is currently no per-
    # transect L3 station data for this branch to ever receive at HB or any
    # other spot with both a structure and a classified feature. An
    # L4-uncovered transect at such a spot falls to L2 today via E2b's
    # orphaned-spot fallback, NOT to L3. Wiring rule 2 requires changing the
    # outer/inner grid-role dispatch (E4/E7 territory) and is out of E5's
    # scope — tracked as a known gap, not attempted here. This code path is
    # UNTESTED against real L3 station data and must not be claimed
    # verified.
```

Also: `tests\test_e5_three_way_handoff.py:143-144` (synthetic-only note) and `docs\ARCHITECTURE.md:101`, `:117` (governing-doc statements of the gap).

### 4.2 What an L3 handoff would concretely require — vs the wired L4 path

| Step | L4 (wired) | L3 role-A (not wired) |
|---|---|---|
| Grid role to writer | `swan_runner.py:4164` — `"inner"` | `swan_runner.py:4021` — `"outer"` |
| Per-transect POINTS/TABLE emitted? | **Yes** — gated `grid_level == "inner"`: `swan_formats.py:1514`, emission `swan_formats.py:2134-2166` | **No** — `"outer"` emits NGRID/NESTOUT only |
| Output parsed back | `swan_runner.py:4195-4196` | **Skipped**, `swan_runner.py:4071-4074` |
| Station depths reach `select_hourly_handoff()` | Yes → `l4_station_depths_m` (rule 1) | No data → rule 2 unreachable |
| Partition source | TABLE_PT PT* via `swan_spectral.py:1129-1143` | n/a |

**Wiring requires:** (1) a dual outer+inner L3 role (the middle-grid BOUNDNEST1 patch trick at `swan_runner.py:4000-4059` restores the parent *read*, not per-transect *output* — "changing the outer/inner grid-role dispatch (E4/E7 territory)"); (2) re-enabling `_parse_output` for L3 without letting L3 overwrite L4's transects (first-match ordering assumes rule 1 wins); (3) populating `station_depths_m` for L3 at the caller (mechanism exists, data doesn't — `ARCHITECTURE.md:117`); (4) real-data tests (existing test is synthetic, self-declared); (5) a structureless test spot — at HB, L4 covers all transects so rule 2 would never execute (`SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:159-163`).

**Scope note:** the gap is **role-A** (structure spot, L3 runs `"outer"`). For **role-B** (classification, no structure ⇒ no L4), `swan_runner.py:3956-3998` writes `"inner"` (`:3960`) and **does** call `_parse_output` (`:3987`) — the pre-L4 code path preserved byte-identical (E2b). On a pure topographic-feature spot the L3 handoff would in principle already produce data. **Never exercised; treat as untested, not working.**

### 4.3 (b) The `l3_enabled=auto` trigger list

- `marine_config.py:101` — `{"point_break", "bay_break", "headland", "straight_beach"}`; `:586` — default `"auto"`; `:776-779` — validation.
- `swan_domain.py:318-323`:

```python
#: topographic_feature values that trigger L3 on their own (marine_config.py
#: _VALID_TOPOGRAPHIC_FEATURES minus "straight_beach" — a straight beach has
#: no 2D refraction feature for L3 to add over L2).
_TOPOGRAPHIC_L3_TRIGGERS: frozenset[str] = frozenset(
    {"point_break", "headland", "bay_break"}
)
```

**Provenance:** mechanically derived (enum minus null case, `swan_domain.py:319-320`); substantive physics rationale is ADR-093 Amendment 2 §3 (`:162-174`) — argues *that* refraction features need 2D, never *which sizes*. Taxonomy row: `SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:582`. Trigger evaluation: `swan_domain.py:359-404` (`_l3_trigger_reason`). **No size threshold exists anywhere in the record** — the operator's size-aware bar (`AUDIT-OPUS-WINDOW-2026-08-03.md:626-630`) is the question, not an answer.

### 4.4 (c) The L3 viability check — what it tests, against which grid

**Function:** `swan_domain.py:435-470`. Pure axis-aligned **bbox containment** of feature points (`:450-457`) + haversine shortfall on failure (`:454-456`). Not a depth/coverage/physics test. Log string `:463-469` matches the live 06:12:31 journal line.

**It tests the SMART L3** (call site `swan_domain.py:613-615`; grid from `smart_size_l3_grid` at `:600-611`) — **not the containment nest**. Per `swan_domain.py:592-599`, for a role-A cluster that smart grid is *"NOT the final L3 grid"* — `grid_sizing_chain.py` overwrites `cluster.grid` with the 40 m coarse nest after L4 is sized.

**Why /health still reports failure — the stale-by-one-step sequence:**

| Order | Line | Effect |
|---|---|---|
| 1 | `grid_sizing_chain.py:1103` | `state.reset_l3_viability_state()` |
| 2 | `swan_domain.py:614-615` | smart L3 fails viability → `cluster.grid = None` |
| 3 | **`grid_sizing_chain.py:1725`** | **`_record_l3_viability_failures(...)` → persists to /health** |
| 4 | `grid_sizing_chain.py:2357` | L4 sized independently |
| 5 | **`grid_sizing_chain.py:2385-2397`** | **`cluster.grid = nest` — 40 m containment L3 assigned anyway** |
| 6 | `grid_sizing_chain.py:2516` | `n_l3_enabled_final` recomputed post-overwrite |

Persistence (3) precedes the overwrite (5) and is never revisited → `/health` reports `l3_viability_failed` for a cluster whose L3 is alive as a containment nest. The count-side of the same hazard was already fixed (`grid_sizing_chain.py:2509-2515`); the health reason was not. `_record_l3_viability_failures` (`:960-1017`) is detection-only, inference `grid is None AND triggered` (`:982-983`) — correct when written, now stale by one step. Health render: `endpoints\health.py:170-173`.

Cross-check: independently confirms the prior DIAG-FETCH diagnosis (`AUDIT-OPUS-WINDOW-2026-08-03.md:553-557`) from source.

---

## 5. DOCUMENTS AND CODE SEARCHED

**Yielded evidence:** ADR-093 (Amendments 1–7), ADR-095, INDEX.md, L3-1D-BOUNDARY-DECISIONS-BRIEF.md, SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md, MARINE-FORWARD-PLAN.md (G5 pin), AUDIT-OPUS-WINDOW-2026-08-03.md, ARCHITECTURE.md, MARINE-GEOMETRY-MODEL-PLAN.md (AD-5), swan-user-manual.txt, swan-commands-extract.md, swan-nesting-reference.md (**mis-attributed §3.5 claim flagged**), rules/coordinator.md, and marine source: swan_domain.py, grid_sizing_chain.py, swan_runner.py, transect_handoff.py, swan_formats.py, swan_spectral.py, marine_config.py, endpoints/health.py, state.py, tests/test_e5_three_way_handoff.py, MARINE-WORKING-MODEL-PLAN.md.

**Searched, empty or non-contributory:** ADR-096 (0 L3 refs), ADR-097 (0 L3 refs), ADR-100 (passing mention only), ADR-098 (datum only), CLEAR-SKIES-PLAN.md (pre-marine), SWAN-L3-STABILITY-PLAN.md (Era-1 numerics, superseded), MARINE-SERVICE-SEPARATION-PLAN.md (archived, self-flagged stale), `SWAN-NESTING-RESEARCH-BRIEF` (**file no longer exists in repo** — survives only as quotations), SURF-ZONE-MODEL-BRIEF.md (marked stale), all four archived CONCERNS files (no disposition decision). Manual searches: SWAN-in-SWAN parent:child ratio rule — **none exists**; "4–5 cells per feature" rule — **not in the manual**.

---

## 6. EVIDENCE SUMMARY FOR THE VESTIGE-VS-FUTURE RULING

*No ruling is made here.*

**Facts established:**

1. **Smart L3 predates L4 by six days** and was, at birth, the fine-detail nearshore model (Amendment 1, 2026-07-21). Amendment 3 (2026-07-27) transferred structure resolution *and* the structure handoff to L4.
2. **The transfer was scoped to role (a) only.** Amendment 3 `:262-270` affirmatively preserves role (b) — the classified-refraction smart L3 — unchanged. **The record contains an affirmative decision to keep it.**
3. **The most recent decision (2026-08-02, G5 pin) also keeps it**, with a stated revisit condition: *"Revisit ONLY if a real structureless spot mis-grids on setup."*
4. **No document records a decision to retire smart L3.** Nearest: non-binding SwellTrack-ray-tracing note ("Not in scope", `L3-1D-BOUNDARY-DECISIONS-BRIEF.md:288-292`).
5. **The role-A containment nest is out of scope for any disposition** — operator 2026-08-02: "L3 and L4 are inseparable." Any ruling concerns the *smart-sizing path and its trigger*, not the L3 tier.
6. **Two roles share one constant, one viability function, one `cluster.grid` slot** — not independently disposable at the constant level; they diverge only at the sizing call.
7. **40 m is correct for BOTH L3 roles; the journal's "10 m" is a stale log literal** (`swan_runner.py:3974`, `:4062` — no format placeholder; bbox math confirms 40 m).
8. **The handoff gap is real and larger than a flag flip** (dual grid-role, `_parse_output`, station-depth population, real-data tests, structureless test spot — §4.2).
9. **Role-B nuance the prior diagnosis missed:** a classification-only cluster (no L4) already takes the `"inner"`+parse path (`swan_runner.py:3956-3998`) — smart L3 *would* produce per-transect data on such a spot today. Never exercised; untested, not working. Narrows but does not eliminate the wiring work.
10. **The trigger list has weak provenance** — mechanically the config enum minus `straight_beach`; the physics rationale argues *that* refraction features need 2D, never *which sizes*. **No size threshold exists anywhere in the record.**
11. **The SWAN manual does not require an intermediate grid** — its only ratio text (`:433-435`) is WAM/WW3 cross-model; `swan-nesting-reference.md:47`'s "§3.5 2-3x" claim is **not supported by the installed manual**. The step-down rationale applies the figure by analogy (flagged unverified at `SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md:498-504`).
12. **The manual supplies a qualitative physics warrant for *some* fine grid at refraction features** (`:599-616`, refraction-error propagation) — the strongest support for role (b). No length scale named.
13. **The manual's only numeric resolution rule (L/5–L/10) is diffraction-specific and sized L4, not L3.** Applicable L3 rules: match the DEM (`:703-706` — 40 m is 4× coarser than HB's 10 m DEM) and OBSTACLE grid-crossing (`:3657-3665` — 40 m grid represents only ≥40 m features).
14. **Live reporting defect, disposition-independent:** `/health`'s `l3_viability_failed` is persisted (`grid_sizing_chain.py:1725`) *before* the containment-nest overwrite (`:2397`) and never re-evaluated → reports failure on a cluster whose L3 is running. Count-side already fixed (`:2509-2515`); reason-side not.

**What the record does NOT establish (material to the ruling):**

- **No feature-size threshold** for which point breaks / headlands / bays warrant a 40 m grid — named by the operator as prerequisite; nothing in the record answers it.
- **No spot has ever exercised smart L3 as a handoff source** — zero empirical evidence either way about its value.
- **The viability test's suitability for role-B is untested** (bbox containment against structure coords; degrades to spot pins for classification-only; "forward-looking safety net", `swan_domain.py:421-423`).
- **Whether the two-role split should be re-expressed in code** (shared constant/viability/slot produced both the stale /health reason and the stale count) — no document evaluates separation vs disposal.

**Corrections to carry forward regardless of ruling:** the two `10 m` log literals (`swan_runner.py:3974`, `:4062`); stale text `swan_domain.py:1388`/`:1427`, `providers/nearshore/swan.py:481`/`:676`, `docs\ARCHITECTURE.md:119`; the mis-attributed manual citation `docs\reference\swan-nesting-reference.md:47`; stale line citation for the KNOWN GAP (drifted to `transect_handoff.py:924-937`).

**The vestige-vs-future disposition is the operator's.**
