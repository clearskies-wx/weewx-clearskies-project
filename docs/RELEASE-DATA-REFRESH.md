# Shipped data artifacts — refresh before a release

**Audience: the software owner, at release time.** These files ship *inside* the packages. They are
snapshots of external datasets, so they go stale silently — nothing in the product will tell you they are
old. Walk this table before cutting a build.

**This is a governing document.** Adding a new shipped data file to any repo requires adding a row here in
the same commit, per CLAUDE.md "Doc-code sync". A shipped artifact with no row is a defect.

Last surveyed: 2026-07-26.

---

## The table

| Artifact | Size | Repo / path | Source | Refresh when | If stale |
|---|---|---|---|---|---|
| `gsfm_shelf_boundary.json` | 2.0 MB | marine `weewx_clearskies_marine/data/` | Global Seafloor Geomorphic Features Map (Harris et al. 2014) | **Rarely.** A published research dataset, not an operational feed. Only on a new GSFM release. | SWAN L1 offshore extent sized from an outdated shelf edge. Low risk. |
| `ncei_regional_dem_index.json` | 63 KB | marine `weewx_clearskies_marine/data/` | NCEI regional coastal DEM catalogue (199 DEMs) | When NCEI publishes new coastal DEMs. Check **annually**. | New high-resolution bathymetry exists for an operator's coast and we never look for it — silently worse seabed data. |
| `ww3_station_catalogue.json` | ~290 KB | marine `weewx_clearskies_marine/data/` | NOAA NOMADS WW3 station output points (~4,036 ocean + ~96 Great Lakes) | When NOAA adds or retires WW3 output points. Check **annually**, or when a spot cannot find a boundary station it should have. | See the dedicated note below — this is the one with a real failure mode. |
| `species.yaml` | 44 KB | marine **and api** (both use it) | Curated fish species by biogeographic region | Rarely — editorial content. | Fishing suggestions omit or misname species. Cosmetic. |
| `gem_active_faults.geojson` | **12 MB** | api `weewx_clearskies_api/data/` | GEM Global Active Faults Database | On a GEM release. Check **annually**. | Fault map slightly out of date. Cosmetic. |
| `meteor_showers.json` | 11 KB | api `weewx_clearskies_api/data/` | Curated table of 26 major showers | **See the note below** — currently the peak dates are hardcoded calendar dates, so they drift. Radiant coordinates and rates are genuinely static. | Almanac names the wrong night for a peak in some years. Visible to anyone who goes outside to look. |
| `charts.conf.default` | 9 KB | api `weewx_clearskies_api/data/` | Ours — default chart definitions | When chart defaults change. | Not external; no staleness risk. |
| UI translation catalogues | ~36–60 KB each | stack `weewx_clearskies_config/translations/`, dashboard `public/locales/` | Ours | When UI strings change. Covered by the existing i18n sync rule, not by this table. | Missing strings fall back to English. |

---

## `ww3_station_catalogue.json` — read this one properly

**Why it is shipped rather than built.** Building it from scratch means one HTTP range request per station
against NOAA at a 2 requests/second courtesy limit. Measured 2026-07-26: **~0.6 stations/second in
practice, so roughly two hours** for the full ocean set — a cost every operator would otherwise pay before
they could configure their first surf spot, and one that fails outright if NOAA is unreachable at setup.
Shipping it makes setup fast and offline-capable. Same rationale and lifecycle as
`ncei_regional_dem_index.json`.

**What it contains.** Station id → latitude/longitude, nothing else. Roughly 70 bytes per station.

**How to regenerate.**

```bash
# On a host with the marine package installed. Resumable: re-running skips
# stations already resolved, so an interrupted build can simply be restarted.
python - <<'PY'
from weewx_clearskies_marine.services import ww3_station_catalogue as cat
print(cat.build_catalogue("ocean"))
print(cat.build_catalogue("great_lakes"))
PY
# then copy the result over the shipped copy:
#   weewx_clearskies_marine/data/ww3_station_catalogue.json
```

**How to tell it is stale.** A configured spot that should have a nearby deep-water station is refused at
setup, or a station in the catalogue starts returning 404 from NOMADS.

**The failure mode that matters — retired stations.** NOAA withdraws output points over time. A shipped
catalogue will therefore drift, and a spot may select a station that no longer publishes. **That must
degrade to "this candidate is unavailable, try the next", never to a failed forecast cycle.** Verify this
behaviour whenever the selection code changes — it is the difference between a stale index being harmless
and a stale index taking a forecast down.

**Coverage is uneven by design.** Station density is a regional fact, not a global guarantee. A sparse
coastline may have too few suitable deep-water stations, and the correct behaviour there is to refuse the
spot at configuration time with a message saying so — not to degrade to a coarser or uniform boundary.

---

## `meteor_showers.json` — this refresh item could be deleted rather than maintained

**Verified 2026-07-26 by reading the code, after an initial guess in the first draft of this document
turned out to be only half right.**

`compute_meteor_showers()` (`services/almanac.py:1430`) builds each peak as
`date(year, shower.peak_month, shower.peak_day)` — a **hardcoded calendar date**. The Quadrantids are
pinned to 3 January in every year, forever.

**But the data already carries the astronomically correct driver, and nothing reads it.** Every one of the
26 entries has a populated `solar_longitude_max` (283.16° for the Quadrantids). A shower peaks when Earth
reaches a given solar longitude in its orbit, not on a fixed calendar date; the calendar date of that
longitude shifts by roughly a day across the leap-year cycle. `grep` confirms `solar_longitude_max` has
**zero readers** in the codebase.

So the fixed dates are correct in most years and a day out in others — enough to name the wrong night.

**Recommendation (needs operator approval — changing which quantity determines the peak is a formula
change, not a refactor):** derive the peak from `solar_longitude_max` per year. That would **remove this
row's maintenance burden entirely** — the table becomes genuinely static reference data (radiant
coordinates, ZHR, parent bodies, descriptions) with the timing computed. Until then, the peak dates are a
standing annual-accuracy caveat rather than something a refresh can really fix, since re-curating fixed
dates each year is the same manual work.

---

## Known issue found during the 2026-07-26 survey

`repos/weewx-clearskies-api/weewx_clearskies_api/data/` still carries **`gsfm_shelf_boundary.json`
(2.0 MB)** and **`ncei_regional_dem_index.json` (62 KB)** with **zero code references anywhere in the API**
(both are live in the marine service). Phase 6 moved the wave-physics code out but left these behind, so
2 MB of dead payload ships in every API build and a maintainer reading the tree would reasonably think
both copies need refreshing.

`species.yaml` is a **genuine** shared dependency — 89 references in the API, 114 in marine. Do not delete
that one; if it is refreshed, **both copies must be updated together**.
