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
