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

### Update 2026-07-26 — SDB as the global L3 fallback, and the research it needs

Raised again by the operator while resolving the C-90 datum work: *"we default to using our own
SDB for that when we cannot easily get our hands on datasets."* This widens the idea from a
sandbar fix at one spot to **the L3 bathymetry source of last resort worldwide**, and turns up a
consequence nobody had noticed.

**It would dissolve the L3 vertical-datum problem, not just the data gap.** ADR-098's worldwide
path needs a per-jurisdiction tidal separation model for every market. SDB calibrated against
**ICESat-2 ATL03** does not: ATL03 reports photon elevations **relative to the WGS 84 ellipsoid**,
so SDB output is ellipsoid-referenced, and ellipsoid → MSL is a **geoid model** (EGM2008) — global
and free, not a tidal separation grid. L3 could therefore be produced natively in MSL anywhere on
Earth with no jurisdiction-specific anything. That makes the VDatum/VORF/BATHYELLI machinery a
US-and-existing-DEM concern rather than the global architecture.

**The calibration blocker is solved in the literature.** Classic SDB (Stumpf blue/green log-ratio)
needs 15–20 in-situ soundings — which you do not have precisely where you lack a DEM. Combined
active+passive approaches use ICESat-2 for the vertical control instead, "using only satellite
data," with reported vertical RMSE of **0.43–1.5 m** (ICESat-2 + Sentinel-2); Stumpf's own 2020
turbid-water work reports **median error 0.5 m over 0–13 m**.

**Depth range fits L3 almost exactly** — SDB is useful roughly 0–15 m; L3 runs from the 15 m
contour to ~1.78 m.

**Turbidity is addressed by temporal filtering, not by luck** (operator, 2026-07-26: *"google
earth has time lapse to deal with turbidity"*, *"you can filter for those types of things over a
time range"*). The ~6 m turbid-water depth limit in the literature is a **per-scene** limit.
Sentinel-2's 5-day revisit over a multi-year archive gives hundreds of observations per spot;
filtering on cloud, sun glint and turbidity proxies and keeping the clearest few percent recovers
clear-water conditions anywhere that is *ever* clear.

**Open research questions — this is why it is filed as research, not work:**

1. **The clarity/currency tension, which is specific to surf.** A long compositing window buys
   clarity; a short one keeps the morphology current. Bars migrate seasonally, and the bar
   position *is* the wave — a five-year clear-pixel composite can be a pristine grid of a sandbar
   that no longer exists. The selection window is probably a parameter with a seasonal default,
   not a constant. A hydrographic user would not care; we must.
2. **Permanently turbid coasts.** River mouths and high-sediment shelves are never clear, and no
   filter fixes that. The correct output there is "no SDB available", not a bad grid.
3. **Accuracy is comparable to the error we are eliminating.** SDB at 0.5–1.5 m RMSE sits in the
   same range as the 0.8 m datum error that C-90 showed becomes ~0.6 m of breaking height. SDB
   belongs at the **bottom** of the L3 priority chain — the answer when no real 10 m DEM exists,
   never a replacement for one that does.
4. Whether breaking-zone turbidity specifically defeats the bar crest (carried over from the
   original entry). **Partly answered 2026-07-26 — and it splits SDB into two families.**

**Two SDB families, and the surf-relevant one is not the optical one.**

- **Optical** (Stumpf/Lyzenga blue-green ratio) recovers depth from **seabed reflectance**. Needs
  clear water; fails precisely where waves break. Everything above about turbidity filtering
  applies to this family.
- **Wave-inversion** (cBathy and satellite equivalents) recovers depth from **surface wave
  celerity** via the dispersion relation, never looking at the bottom. cBathy "was developed to
  overcome issues faced where the bottom can't be visualized due to turbidity or bubbles in the
  surf zone", and wave-based methods work "in optically turbid waters and over seafloor with low
  reflectance". The literature calls the two approaches **complementary**, not competing.

So open question 4 is likely "yes" for optical and "no" for wave-inversion — which makes
wave-inversion the better fit for a *surf* product, since the breaking zone is the whole point.

**But resolution is the catch.** Satellite wave-inversion (e.g. the S2hores Sentinel-2 toolbox)
currently produces **100 m – 1 km** grids — fine for L2, useless for L3's 10 m. The 10 m-class
wave-inversion methods need **shore cameras** (cBathy/Argus), UAV video, or X-band marine radar,
i.e. an instrument at the spot rather than an orbit. cBathy skill also "deteriorates during
storms", which is when the forecast matters most.

**Competitive note, stated as inference not fact.** Surfline's public material mentions "satellite
assimilation" and "high-resolution bathymetry mapping" as *separate* items and never says
satellite-derived *bathymetry*; in wave forecasting "satellite assimilation" normally means
altimeter significant-wave-height. What they do disclose is **20 years of camera stream data** —
which is exactly cBathy's input. Whether they run wave-inversion on it is unknown and should not
be recorded as fact, but it identifies the capability gap worth thinking about: a camera network
is a bathymetry sensor, not just a viewing product.

The operator notes the same reticence at surf-forecast.com (2026-07-26): the industry does not
disclose bathymetry provenance. Two consequences. We cannot benchmark our seabed against theirs,
so competitive comparison has to be on **output** (predicted surf versus observed) rather than on
inputs. And provenance is available as a differentiator — we already record the DEM source and
vertical datum per level, which nobody else appears to publish.

**Data supply vs software supply — the strategic question the operator raised.** Doing this
centrally would put us **in the data business**: hosting, refreshing and standing behind a global
derived bathymetry product, with the licensing and liability that implies. That is
[RELEASE-DATA-REFRESH.md](../RELEASE-DATA-REFRESH.md)'s maintenance burden at planetary scale.
The alternative is to **ship the pipeline and have the operator generate their own** — which is
consistent with how the marine service already behaves, since operators already pull NCEI DEMs,
ETOPO, WW3 and HRRR at setup rather than receiving them from us. Cost of that route: the operator
needs the compute and the imagery access, and SDB is far heavier than a DEM download. This choice
should be made **before** any implementation, because it determines whether the deliverable is a
dataset or a package.

**Imagery access does not require Google Earth Engine.** GEE is free for research and nonprofit
use but **paid for commercial use** — which matters if operators are commercial. Sentinel-2 is
free and open via the Copernicus Data Space and Landsat is US public domain, both mirrored on AWS
Open Data. GEE is a convenience for the compositing step, not a dependency, and keeping it
optional avoids inheriting its licence terms.

**Related:** [ADR-098](../decisions/ADR-098-swan-datum-consistency.md) (vertical datum
consistency; SDB would change its worldwide section), C-90 in
[MARINE-SEP-CONCERNS.md](MARINE-SEP-CONCERNS.md).

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
