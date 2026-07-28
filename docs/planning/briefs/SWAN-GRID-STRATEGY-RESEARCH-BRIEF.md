# SWAN grid strategy — research brief

**Written:** 2026-07-27
**For:** independent research. The questions in §4 are the deliverable.
**Status:** the operator has rejected the current grid strategy as computationally wasteful. This
brief describes what exists, what it costs, and what needs answering before anything is redesigned.

**Read §5 before answering. It lists errors already made on this question, so they are not repeated.**

---

## 1. What the system is

A surf forecast for one spot: **Huntington City Beach Pier**, California. The model chain is:

```
WaveWatch III boundary spectra
      │
      ▼
SWAN L1   1 km    shelf edge → shore
      │
      ▼
SWAN L2   100 m   shore → 30 m depth
      │
      ▼
SWAN L3   10 m    optional fine grid  ─────┐
      │                                    │
      ▼                                    ▼
   1D model (SwellTrack)  ← handoff ← ─────┘
      │
      ▼
   surf forecast per transect
```

**SWAN** is the third-generation spectral wave model (Cycle III, v41.51AB). **SwellTrack** is a
proprietary analytical **1D cross-shore** wave transformation model — it runs along a single line
from its handoff depth to the shoreline, per transect, per swell partition. It is phase-averaged and
cannot represent 2D refraction or diffraction.

### Geometry, measured live 2026-07-27

| | value |
|---|---|
| Beach segment (operator-drawn) | **313.4 m** long, bearing 147.8° |
| Beach faces | **238°** |
| Transects | **32**, at 10 m spacing, perpendicular to the beach |
| Pier | 567 m long, 124 m offshore of the spot pin, bearing 221° |
| 15 m depth contour | **2574.19 m** from the coastline anchor, along bearing 238° |
| Today's swell | Hs 1.11 m, **Tp 15.27 s**, from **201.9°** |
| Swell angle off beach normal | **36°** |

### The two handoff depths — these are different and are easily confused

- **No L3 grid** (open beach, or L3 failed its viability test): SWAN L2 hands to the 1D model at
  **15.0 m depth**. This is a hard constant, `L2_REFERENCE_DEPTH_M = 15.0` in
  `services/transect_handoff.py:79`. The 1D model then runs 15 m → shore.
- **With an L3 grid**: L3 hands to the 1D model at a **per-hour, per-transect** depth of
  `1.3 × Hs(hour) / 0.73` — a 30% margin seaward of that hour's breaking depth. Measured live this
  is ≈ **1.75 m**. L3's shoreward edge is sized by the same criterion at a design-minimum swell,
  ≈ 1.78 m depth.

**So the L3 grid's entire job is to carry the model from 15 m in to ~1.75 m in 2D, instead of the
1D model covering that range.** L3 explicitly does **not** run to shore.

### What triggers L3

L3 turns on when a manmade structure is discovered **or** the operator classifies the spot as a
point break, headland, or bay break. A setup-time viability test then disables it if the grid cannot
reach the feature it exists for.

`DIFFRACTION` is enabled at **L3 only**. The pier is emitted as a SWAN `OBSTACLE` line with
`TRANSM 0.95` (`services/swan_formats.py:1489`) — i.e. **95% of wave energy is passed through**.

---

## 2. The problem

### Compute cost, measured

| | cells | cycle outcome |
|---|---|---|
| L1 | 27 × 21 = **567** | — |
| L2 | 79 × 70 = **5,530** | — |
| L3 as it ran this morning (defective, too small) | 87 × 73 = **6,351** | full cycle ≈ **7 min** |
| L3 after being restored to its specified extent | 245 × 171 = **41,895** | **>75 min, did not complete** |

SWAN's per-run timeout is **3600 s**. Full runs are scheduled 2–4× per day. The restored grid is
2445.5 × 1705.5 m at 10 m resolution.

### Why the restored grid is so large

The grid is an **axis-aligned lat/lon rectangle**. The beach runs at 238°, so the strip the model
actually cares about — roughly 2674 m out from shore and ~313 m wide — sits **diagonally** across
that rectangle. Holding a diagonal strip forces the box to span the diagonal's full east–west and
north–south reach:

```
E–W component:  2674 × |sin 238°| ≈ 2268 m
N–S component:  2674 × |cos 238°| ≈ 1417 m
```

### What the fine grid actually buys, measured

The pier's measured effect on the wave field: transects PT0–PT7 show **0.812–0.830 m** against a
far-field **0.872–0.890 m**. That is an **≈8% wave-height deficit**, confined to the first ~8
transects (~80 m of shoreline), at 8–9 m depth, with the breaking fraction Qb = 0 everywhere.

**So ~42,000 cells at 10 m resolution are being computed to capture an 8% effect over ~80 m of a
313 m beach.** Everywhere else, the 2D grid is resolving open water that the 1D model already
handles from 15 m inward on spots that have no L3 grid at all.

### The operator's position

> *"We are relying on the 1D models for the fine detail, not the L3 model. Originally the L3 model
> was the fine detail, but we learned it does not model what we need. We, for some reason, are still
> using this model when we should not be. The computational costs are too high and the benefits are
> too low for the size of the area. We really only need the L3 box for the purpose of modeling the
> issues around the obstacles — we do not need that level of FINE modeling all the way from 15 m at
> 10 m resolution. That is a lot of wasted computation for open water."*

Proposed direction, to be evaluated not assumed:

- Drop most of L3 to **30–40 m** resolution.
- Add a **10 m L4** grid only near the obstacle.
- Accept **non-uniform transect handoffs** — transects near the pier hand off from L4 at one depth,
  transects away from it hand off from L3 (or L2) at another. This is explicitly acceptable.
- L4 **need not be rectilinear**. SWAN supports curvilinear and unstructured (triangular mesh)
  grids; structured grids may be rectilinear-uniform or curvilinear. A quadrilateral shaped to the
  expected obstacle-affected area is on the table.

**The driver is reducing compute. Any recommendation must state its cell count.**

---

## 3. Constraints and facts that bound the answer

1. **Currents are not modelled.** No littoral transport, no sediment. The only pier effect in scope
   is its direct effect on the wave field. Arguments that depend on a pier's morphological influence
   (sandbar anchoring, shoreline change) are out of scope.
2. **A pier on pilings is porous.** It is not a breakwater and does not behave like one. The
   operator's position, which the measured 8% deficit supports: piers do not cast large wave
   shadows. Empirically, surf quality at Huntington is *best* either side of the pier.
3. **`TRANSM 0.95` is unsourced.** The operator believes the real figure may be nearer 0.80–0.85.
   This constant governs how much the pier does at all, so any grid sized around the pier's effect
   inherits its uncertainty. **Establishing a defensible value for a pile-supported recreational
   pier — not a pile breakwater — is part of the research.** Published values for pile *breakwaters*
   (dense, multi-row, purpose-built to attenuate) are 0.3–0.5 and do **not** transfer.
4. **Changing a physics constant, a grid's resolution/extent, or a model handoff point is an
   architectural change** in this project and requires explicit operator approval. This brief asks
   for analysis and recommendations, **not** code changes.
5. **The 1D model is the authority shoreward of its handoff.** Break points, breaker classification,
   surf-zone width and face heights all come from it. The question is never "should the 1D model do
   less" — it is "how far seaward does 2D need to reach, and at what resolution".

### Prior research already done (verify, do not assume correct)

- SWAN's phase-decoupled refraction–diffraction requires a **grid finer than ~1/10 of the
  wavelength**; the diffraction effect **disappears** as cells coarsen past that.
- At Tp = 15.27 s, wavelength is ≈ **132 m at 8 m depth**, ≈ **177 m at 15 m depth**. So 1/10 of the
  wavelength is ≈ 13 m and ≈ 18 m respectively. **This arithmetic should be independently checked.**
- Diffraction experiments behind structures typically measure within **~3 wavelengths of the tip**.
- **Directional spreading matters**: real short-crested seas put *more* energy into the lee than
  long-crested laboratory waves. Wave height along the shadow boundary is ≈70% of incident for
  irregular directional waves, versus ≈50% under idealised long-crested theory.
- SWAN nesting imposes no fixed parent:child ratio; a nested boundary file need not match the inner
  grid's resolution, but must not be coarser than the parent.

---

## 4. The questions — this is the deliverable

### Q1 — Is an intermediate grid between L2 and the 1D model worth having?

The operator's question, precisely: **does stepping L2's 100 m cells down to 30–40 m before handing
off to the 1D model produce a materially better handoff than handing off directly from 100 m?**

This is a question about **accuracy gained**, not about whether 100 m is tolerable.

- What does grid resolution actually control in the handoff values (Hs, Tp, direction, and the
  2D spectrum) at the handoff point? Where does refraction over unresolved bathymetry matter,
  and at what scales does nearshore bathymetry vary enough for 100 m cells to miss it?
- Is there published resolution-convergence work for nearshore SWAN — at what cell size do
  handoff-relevant quantities stop changing?
- If such a grid is worth having: **how large, and where should it terminate?** Should it be a thin
  band that exists only to step the resolution down before handing to the 1D model, or does it need
  meaningful extent? What should its offshore and shoreward edges be sized by?
- **Is this the right strategy at all between L2 and the 1D model**, or is there a better one?

### Q2 — Sizing when an obstacle is present, and is 10 m genuinely required?

- Given an obstacle, what is the proper extent of the grid that contains it?
- **Is 10 m resolution really required, or is that an assumption?** The operator assumed it was
  needed for bathymetric detail; prior research suggests the binding constraint is instead the
  1/10-wavelength diffraction criterion. **Which is it, and what is the actual governing
  requirement?** If bathymetry does bind, at what scale?
- At what point should a coarser obstacle-containing grid hand off to a 10 m grid, if at all — or
  can one grid serve both purposes?

### Q3 — Shape and extent of the fine obstacle grid

Assuming a 10 m grid is needed around the pier:

- **How should it be shaped?** Is it needed seaward of the obstacle, only at it, or past it — and
  how far in each direction?
- **How far to each side?** The operator recalls a figure of roughly **3–5 wavelengths in a wedge
  shape** — verify or correct this, with sources.
- The affected area is **not rectilinear** and depends on swell direction, so it is more triangular
  or wedge-shaped than square. **Can a quadrilateral or unstructured boundary be drawn tightly
  around just that area** — and still terminate before the surf zone, as the current design does?
- Swell direction varies. Should the shape be sized for a **directional envelope** covering the
  spot's swell climate, or recomputed per run? What does that cost?

### Cross-cutting requirement

**Every recommendation must state its cell count and the resulting compute estimate**, against these
baselines: 41,895 cells → >75 min (did not complete); 6,351 cells → ~7 min full cycle.

State clearly which conclusions rest on published sources, which on the measurements in §1–2, and
which remain assumptions needing measurement.

---

## 5. Errors already made on this question — do not repeat them

Recorded so the same ground is not re-covered wrongly.

1. **"Rotate the grid to the beach bearing."** Proposed as an efficiency win. **Wrong**: swell
   arrives at 201.9° while the beach faces 238° — 36° off. A narrow strip aligned to the beach
   normal would have obliquely-arriving swell entering through its long side. Swell direction also
   varies run to run, while a grid orientation is fixed.
2. **"The pier's shadow is pushed far down the coast."** **Wrong**, and contradicted by two facts
   already in the system: `TRANSM 0.95` means the pier passes 95% of energy, and the measured
   deficit is 8% over ~8 transects. Generic breakwater intuition does not apply to a porous pier.
3. **"Five times more computation than needed."** Derived by treating all alongshore extent as
   waste. The alongshore extent is partly sized for the obstacle-affected zone; the real
   inefficiency is **resolution over open water**, not box shape.
4. **"The handoff happens at ~1.7 m depth."** Stated while discussing the *no-L3* path. **Wrong**:
   without L3 the handoff is at **15.0 m** (`L2_REFERENCE_DEPTH_M`). The 1.75 m figure applies only
   when L3 exists. Confusing the two inverts the difficulty of Q1.
5. **Answering "is L2 → 1D acceptable?" when the question was "is L2 → intermediate → 1D
   *better*?"** These are different questions. Q1 asks about accuracy gained by refining, not about
   the adequacy of the status quo.

---

## 6. Source files, if code inspection helps

Repository: `weewx-clearskies-marine`.

| Path | What is in it |
|---|---|
| `services/swan_domain.py` | Grid sizing for all three levels; `smart_size_l3_grid()` |
| `services/transect_handoff.py` | `L2_REFERENCE_DEPTH_M = 15.0` (line 79); handoff selection; shadow classification |
| `services/swan_formats.py` | SWAN command emission — `CGRID`, `NGRID`, `INPGRID`, `OBSTACLE`, `TRANSM 0.95` (line 1489) |
| `services/surf_1d_analytical.py` | The 1D model |
| `services/surf_1d_pipeline.py` | Per-partition, per-transect 1D orchestration; profile truncation at handoff |
| `services/grid_sizing_chain.py` | Config-time sizing chain; bathymetry download; profile extraction |
| `docs/ARCHITECTURE.md` | The SWAN nesting note — authoritative on current design |

Grid geometry is computed at **config-push time**, not per cycle, and cached to
`/etc/weewx-clearskies/swan_grid_sizing.json`. A forced model cycle does **not** resize grids.
