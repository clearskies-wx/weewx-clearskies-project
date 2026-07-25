# Future Enhancements — backlog

Ideas accepted as worth doing but deliberately **not** scheduled. Each entry records what the
idea is, why it was raised, and what it would unblock. Nothing here is committed work.

---

## Satellite-derived bathymetry (SDB) for the surf zone

**Raised:** 2026-07-25 by the operator, during Phase 4A T4A.5.

**The problem it solves.** The NCEI CUDEM tiles we use (`orange_county_13_navd88_2015.nc`,
1/3 arc-second ≈ 10 m) contain **no sandbar field** in the surf zone. Measured at HB: at 8.57 m
native sampling — where a 30–50 m bar would span 4–6 samples — the profile has exactly one local
depth minimum, with 7 cm of relief, at 6.9 m depth, outside the surf zone. The surf zone is a
smooth monotonic ramp at ~1:50.

This is inherent to how CUDEM is built: surf-zone cells are interpolated between topographic
LiDAR (dry beach) and offshore bathymetry, and the bar field falls in that seam. The tile is also
a 2015 composite, and bars migrate seasonally, so multi-year averaging flattens them even where
they were surveyed.

**What it costs us today** (all one cause, see the T4A.5 block in
[MARINE-SERVICE-SEPARATION-PLAN.md](MARINE-SERVICE-SEPARATION-PLAN.md)):

- Zero jacking factors — `_compute_jacking()` needs a local depth minimum, so T4A.6 item (b)'s
  jacking annotations never render.
- Every breaker classifies `spilling`; no plunging at any swell 1–4 m, because a plane 1:50 slope
  keeps the Iribarren number low everywhere.
- Break points smear across a dissipation ramp instead of concentrating at a bar crest.
- Peak face heights are probably under-predicted (inference from the physics, not measured).

**The idea.** Derive 10 m bathymetry from optical satellite imagery — Landsat 8/9 and
Sentinel-2, both free and available through Google Earth Engine. The operator notes that
NASA/NOAA already publish a product covering part of the derivation work, so this is not a
from-scratch research effort.

**Why it is plausible.** SDB in clear shallow water is a well-established technique — depth is
recovered from the ratio of blue/green reflectance, calibrated against known soundings. Its
useful range (roughly 0–10 m in clear water) is *exactly* the surf-zone band CUDEM handles worst,
and satellite revisit cadence means bars could be tracked as they migrate rather than frozen in a
2015 composite.

**Known risks, not yet assessed.** Southern California surf-zone water is frequently turbid,
especially where waves are breaking — the same energy that builds the bars suspends the sediment
that defeats optical depth retrieval. Accuracy, revisit usability, and whether breaking-zone
turbidity makes the bar crest specifically unrecoverable all need real evaluation before this is
scheduled.

**Would be architectural** — a new bathymetry source is trigger 7 (adds a dependency and a data
source) and would change what feeds the profile. Needs its own ADR.

---

## ~~Which host owns the spot profile cache~~ — ALREADY SCOPED, not an open question

**Raised then withdrawn 2026-07-25.** Recorded so a future session does not re-open it.

Observed during T4A.5: `/etc/weewx-clearskies/spot_profiles/` exists on **both** weewx and
librewxr and the two have diverged — librewxr holds the regenerated 629-point NAVD88 profile,
weewx still holds a 50-point Jul-22 profile with no datum. The beach-profile endpoint runs on
weewx, gets transect data from the compute service on librewxr, but reads the datum from its own
stale local copy, so `metadata.verticalDatum` returns **null**. T4A.6 item (f)'s datum-qualified
Y-axis label therefore does not render in production. The F3 code fix is correct; the data behind
it is stale.

**This needs no decision and no fix — the existing plan resolves it by deletion:**

- **T6.5** deletes `endpoints/beach_profile.py` from the API repo entirely (with `surf.py`,
  `marine.py`, `fishing.py`, `beach_safety.py`). The endpoint that reads weewx's stale cache
  stops existing on weewx.
- **T8.5 step 4** removes `/etc/weewx-clearskies/spot_profiles/` from weewx, along with the SWAN
  binary, `/var/run/weewx-clearskies/swan/`, and the bathymetry JSONs.

Syncing the profile to weewx would be building something Phase 6 deletes. **Do not do it.**
