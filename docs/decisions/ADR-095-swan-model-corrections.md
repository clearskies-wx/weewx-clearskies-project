---
status: Proposed
date: 2026-07-18
deciders: shane
supersedes:
superseded-by:
---

# ADR-095: SWAN model corrections — cross-shore transect, WLEVEL, CURRENT, OBSTACLE

## Context

Production testing of the SWAN+TruShore implementation (ADR-093) revealed four physics-level issues:

1. **Output point at wrong depth.** SWAN output points are placed at the operator's pin-drop coordinates (~4.3m depth at Huntington Beach). At this depth, Battjes-Janssen breaking dissipation has already reduced wave height — Hsig is post-breaking. K-G/Caldwell then applies minimal amplification because the depth correction recognizes SWAN already handled shoaling. Result: `swellHeight ≈ breakingFaceHeight` — two nearly identical numbers. The WAVE-BREAKING-CONVERSION-BRIEF §4 recommended output at ~10m depth, where SWAN has handled refraction but not breaking.

2. **No water level input.** SWAN runs at static mean sea level for all 72 hours. Tidal water level variation affects depth-dependent physics (breaking threshold, shoaling, refraction) across the tidal cycle. CO-OPS tidal predictions are already fetched for the surf endpoint's tide chart but never passed to SWAN.

3. **No current input.** OFS ocean/tidal currents affect wave height and breaking at inlets, piers, and tidal channels. OFS data is already fetched for water temperature but surface currents are not passed to SWAN.

4. **Post-processing structure effects.** `wave_transform.py` Supplement 2 applies transmission coefficients as a post-processing step. SWAN natively supports structure modeling via the OBSTACLE command with physics-based formulations (Goda, d'Angremond, transmission/reflection coefficients). Native SWAN modeling is more accurate than post-processing because it accounts for diffraction and wave field reorganization behind structures.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Keep current architecture | No code changes | swellHeight ≈ breakingFaceHeight (useless differentiation), missing tidal/current physics, post-processing structures less accurate |
| Cross-shore transect + inputs (chosen) | Correct output depth, tidal physics, current interaction, native structure modeling | ~10 additional output points per spot (minimal compute), requires parsing transect data |

## Decision

Four corrections to the SWAN integration:

**Decision 1: Cross-shore CURVE transect output.** Replace single-point OUTPUT POINTS with a CURVE transect per surf spot. Transect runs perpendicular to beach from ~15m depth to ~1m depth at ~50m spacing (10–20 output points). K-G/Caldwell applied at the ~10m depth point. HSWELL read at ~10m. Break points detected from QB peaks along the transect.

**Decision 2: Time-varying WLEVEL and CURRENT inputs.** SWAN receives CO-OPS tidal predictions as WLEVEL (one water level per timestep, uniform across domain — tides vary slowly over ~30km). OFS surface currents as CURRENT (U/V components per grid point per timestep) when available. SWAN runs without currents when OFS data is unavailable (safe default).

**Decision 3: Native OBSTACLE replaces Supplement 2.** Coastal structures modeled via SWAN's OBSTACLE command: pier → TRANSM, breakwater → DAM DANGremond, jetty → DAM GODA, seawall → REFL. Structure coordinates from the wizard's Overpass API discovery. Supplement 2 removed from `wave_transform.apply_supplements()`. Supplements 1, 3, 4 retained.

**Decision 4: TRIAD and SETUP enabled.** TRIAD (Eldeberky 1996 defaults) for shallow-water triad interactions. SETUP for wave-induced water level computation. SETUP values stored for future beach safety use. **Amendment (2026-07-19):** SETUP subsequently removed in SWAN-L3-STABILITY-PLAN — unsupported in parallel OpenMP runs (finding A1) and nest boundary condition structurally wrong (finding A2). Setup effect now delivered via WLEVEL input. See PROVIDER-MANUAL §14.15.

## Consequences

- Cross-shore transect adds ~10 output points per spot — minimal compute cost (SWAN already computes the full grid; output points just sample it).
- `swellHeight` and `breakingFaceHeight` become meaningfully different values (~1.1–1.3× ratio for groundswell).
- Wave heights vary with tidal state (high tide vs. low tide produce different Hs values).
- Structure attenuation handled by SWAN physics, not post-processing approximation.
- CO-OPS data already fetched; OFS data already fetched — no new external dependencies.
- Supplement 2 code removed; supplements 1, 3, 4 unchanged.
- TRIAD adds negligible compute cost. SETUP values stored but not yet used in beach safety (deferred — Q4 in plan).
- New TABLE output quantities: HSWELL, QB, DISSURF, DEPTH, DSPR (see ADR-096 for scoring use of DSPR).
- SPECOUT added at ~10m point per spot for spectral decomposition (replaces NDBC for multiSwell).

## Acceptance criteria

- [ ] SWAN INPUT file contains CURVE command per spot with 10+ output points along cross-shore transect
- [ ] SWAN INPUT file contains INPGRID WLEVEL and READINP WLEV commands
- [ ] SWAN INPUT file contains INPGRID CURRENT and READINP CURRENT commands (when OFS data available)
- [ ] SWAN INPUT file contains OBSTACLE commands for each configured structure
- [ ] SWAN INPUT file contains TRIAD and SETUP commands
- [ ] TABLE output contains HSIGN, HSWELL, DIR, TM01, DEPTH, QB, DISSURF, SETUP, DSPR columns
- [ ] Wave height differs between high-tide and low-tide timesteps at same output point
- [ ] Structure attenuation visible (Hs lower behind structure vs. unobstructed point)
- [ ] HSWELL ≤ HSIGN at every transect point
- [ ] QB = 0 in deep water, 0–1 in surf zone
- [ ] SETUP values non-zero at nearshore output points
- [ ] wave_transform.apply_supplements() no longer applies Supplement 2
- [ ] Supplements 1, 3, 4 still fire
- [ ] SPECOUT file written at ~10m point per spot
- [ ] swellHeight (HSWELL at ~10m) and breakingFaceHeight (K-G at ~10m HSIGN) differ by ~1.1–1.3× for typical groundswell

## Implementation guidance

- **CURVE command:** `CURVE 'spot_id' xstart ystart npts dx dy` — perpendicular to beach (`beach_facing_degrees + 180°`), from ~15m depth contour to ~1m depth contour, ~50m spacing. Depth contours derived from the CUDEM bathymetric profile.
- **WLEVEL:** `INPGRID WLEVEL` + `READINP WLEV` — one grid matching outer grid, uniform water level per timestep (hourly, from CO-OPS tide predictions already fetched in surf.py). NONSTATIONARY time window matching wind input.
- **CURRENT:** `INPGRID CURRENT` + `READINP CURRENT` — U and V components at grid points per timestep from OFS. Graceful fallback: if OFS unavailable, omit CURRENT commands entirely (SWAN defaults to no current).
- **OBSTACLE:** Map wizard structure types to SWAN commands. Coordinates from `marine_config.structures[]`. See SWAN user manual §4.5.4 for command syntax.
- **TRIAD:** `TRIAD` with defaults (Eldeberky 1996). **SETUP:** `SETUP` command (enables wave-induced setup computation). Add SETUP to TABLE quantity list.
- **TABLE output:** Expand to `TABLE ... HSIGN HSWELL DIR TM01 DEPTH QB DISSURF SETUP DSPR XP YP`.
- **SPECOUT:** At ~10m depth point only (one per spot, not entire transect). 2D directional-frequency spectrum for spectral decomposition.
- **Files affected:** `services/swan_runner.py`, `services/swan_formats.py`, `enrichment/wave_transform.py` (remove Supplement 2), `endpoints/surf.py` (pass tide data to runner), `config/marine_config.py` (structure → OBSTACLE mapping).

## Amendments

### Amendment 1 (2026-07-21): Multi-transect + 1D model corrections

Per SURF-ZONE-MODEL-BRIEF and SURF-1D-IMPLEMENTATION-PLAN:

**Decision 1 (CURVE transect) — amended.** CURVE is retained for L3-enabled spots as a diagnostic/validation output. The 1D model replaces CURVE as the primary cross-shore data source for the surf endpoint. CURVE spacing change from 50m to 10m (SURF-19) still applies for L3 validation.

**SPECOUT extraction — amended.** Changes from "at ~10m depth point per spot" to two distinct SPECOUT purposes:

1. **Deep-water reference SPECOUT (for swell display card):** One per spot, extracted from L2 at ~15m depth (L2→L3 boundary). This is the truest pre-nearshore spectrum available — before L3's structure interaction, before significant shoaling. The swell card decomposes THIS spectrum and shows the partitions as "incoming swell." At 15m, a 16s swell has shoaled only ~5%, so values are close to true deep-water and comparable to NDBC buoy readings.

2. **Handoff SPECOUT (for 1D model boundary condition):** One per unique grid cell at each transect's handoff depth. For L3-enabled spots: from L3 grid at the structure-affected handoff depth. For L3-disabled spots: same as the deep-water reference (L2 at 15m). This spectrum feeds the 1D model — it includes structure effects when applicable.

Multiple SPECOUT points per spot (one per unique handoff cell). Deduplicated — transects sharing the same grid cell share one SPECOUT.

**K-G/Caldwell — amended.** Applied at the break point from the 1D model output, NOT at the ~10m reference point. Specifically: at `source="break_point"`, only the Rayleigh H1/10 factor (1.27× Hs) is applied for face height — NOT the full K-G deepwater formula — because the 1D model's break-point Hs is already fully shoaled. Full K-G retained as fallback for `source="deep_water"` (legacy path). The ad-hoc depth correction (`SHALLOW_DEPTH_THRESHOLD_M` and lerp logic) is eliminated.

**Swell decomposition reference — amended.** multiSwell components come from SPECOUT decomposition at the deep-water reference point (L2 at ~15m), not from a nearshore ~10m point. The swell card shows what's arriving, comparable to NDBC buoy partitions.

**Break point authority — amended.** 1D model's H/d = gamma crossing is the primary break point. SWAN's QB retained as diagnostic only.

**Acceptance criteria updated** to reflect multi-transect output shape: SPECOUT per unique handoff cell (not one per spot), 1D model break points as primary authority, face height from H1/10 at break point.

## References

- Related: ADR-093 (SWAN replaces NWPS), ADR-094 (HRRR wind source)
- Research: `docs/planning/briefs/WAVE-BREAKING-CONVERSION-BRIEF.md` §4, `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`
- SWAN user manual: §4.5.2 (INPGRID WLEVEL/CURRENT), §4.5.4 (OBSTACLE), §4.6.1 (CURVE), §4.6.2 (TABLE/SPECOUT)
- SWAN technical manual: Battjes-Janssen breaking, triad interactions, obstacle formulas
- Plan: `docs/planning/SWAN-CORRECTIONS-PLAN.md` Phases 2–3, `docs/planning/SURF-1D-IMPLEMENTATION-PLAN.md`
