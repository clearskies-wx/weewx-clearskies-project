# WW3 Spectral Boundary — Data Brief

**Status:** research complete, awaiting operator decision. No code changed.
**Date measured:** 2026-07-26. Every number below was fetched live, not recalled.
**Concerns:** C-86 (root cause), C-87 (this design). Supersedes C-81's and C-86's recommendations.

---

## 1. The finding in one paragraph

We are not using WaveWatch III. `providers/marine/wavewatch.py` fetches
`pae-paha.pacioos.hawaii.edu/erddap/griddap/ww3_global` — a **PacIOOS** (Pacific Islands Ocean Observing
System) republication of the legacy `NWW3_Global_Best` product at **0.5°**, carrying **one averaged swell
triple**. NOAA's operational WaveWatch III publishes **full 2-D directional spectra** in the exact file
format SWAN's `BOUNDNEST3` command reads. We take a spectrum WW3 already computed, throw away its
structure, and synthesise a single JONSWAP peak from the leftovers.

---

## 2. What the ocean actually had, and what we said it had

Same point (33.5 N, 118.5 W — the SWAN L1 boundary), same day.

| Source | What it reports |
|---|---|
| **PacIOOS `ww3_global`** (what we use) | one swell: `shgt` 0.93 m, `sper` **12.73 s**, `sdir` 192°; `Tper` 12.66 s |
| **Real WW3** via THREDDS NCSS | 2 partitions; 0.40 m @ **19.05 s** @ 214.6°; primary period 19.06 s |
| **Real WW3** `gfswave.global.0p25` GRIB2 | 3 partitions: 0.61 m @ 6.39 s @ 272.6°; 0.38 m @ **19.11 s** @ 216.9°; 0.23 m @ 11.70 s @ 199.0°; `perpw` **19.10 s** |
| **Surfline** (the spot) | 1.5 ft **19 s** SSW 197° / 1.4 ft 12 s S 187° / 1.5 ft 9 s S 181°; surf **4–6 ft** |
| **What we published** | 3.83–4.24 ft, flat for 14 h; one swell component in 65 of 67 timesteps |

`sper` **12.73 s** is a weighted average of the 19.11 s groundswell and the 6.39 s wind swell — **a number
corresponding to no wave in the water.** Peak period governs shoaling and breaking height far more than
offshore height does, which is why Surfline forecasts *bigger* surf (4–6 ft) from a *smaller* combined
swell (2.54 ft) than our boundary carried (3.05 ft).

This single substitution accounts for all three published symptoms: surf height low, surf height flat, no
long-period sets.

**Why every automated check passed anyway:** the average roughly conserves energy (0.93 m vs a 0.80 m
combined), so energy closure, convergence and plausibility screens are all satisfied. The **distribution**
is wrong. No conservation test can detect that — see C-83.

---

## 3. What the SWAN manual specifies

Not a coordinator judgement. SWAN User Manual, *Boundary and initial conditions*:

| Command | Parent model | Expects |
|---|---|---|
| `BOUNDSPEC ... PAR` / TPAR | none | parametric bulk parameters — **what we use** |
| `BOUNDSPEC ... FILE` | none | 1-D or 2-D spectra |
| `BOUNDNEST1` | coarser SWAN run | full 2-D spectra |
| `BOUNDNEST2` | WAM Cycle 4.5 | full spectra (manual: *"not fully tested"*) |
| **`BOUNDNEST3`** | **WAVEWATCH III** | **full 2-D spectra** |

> *"The output files of WAVEWATCH III have to be created with the post-processor of WAVEWATCH III as
> output transfer files (formatted or unformatted) with WW_3 OUTP (output type 1 sub type 3) at the
> locations along the nest boundary."*

There is a purpose-built command for our exact situation. We use the parametric path the manual lists for
measurements and *other* models.

---

## 4. The data source to use — measured

### 4.1 Ocean

```
/pub/data/nccf/com/gfs/prod/gfs.YYYYMMDD/CC/wave/station/bulls.tCCz/gfswave.<STATION>.spec
```

```
'WAVEWATCH III SPECTRA'     50    36     1 'spectral resolution for points'
 0.350E-01 0.375E-01 ... 0.964E+00          <- 50 frequencies (28.6 s .. 1.04 s)
 0.148E+01 0.131E+01 ... 0.166E+01          <- 36 directions
20260726 060000
'46222     '  33.62-118.32     487.9   2.20 143.8   0.03 285.6
 ...50 x 36 = 1800 energy-density values...
```

Per-timestep header: **station id, lat, lon, depth (m), wind speed/dir, current speed/dir.**
Station **46222** = 33.62 N, 118.32 W, **depth 487.9 m**, ~20 km off Huntington — a textbook deep-water L1
boundary point.

### 4.2 Great Lakes

```
/pub/data/nccf/com/glwu/prod/glwu.YYYYMMDD/bulls.tCCz/glwu.<STATION>.spec
```

```
'WAVEWATCH III SPECTRA'     32    36     1 'Great Lakes WAVEWATCH III Unst'
```

**Identical, self-describing format** — the header declares `nfreq`/`ndir`, so **one parser serves both
products with no format branching.** GLWU *is* a WAVEWATCH III implementation on an unstructured grid.
`glwu.45002.bull` → `Location : 45002   (45.34N  86.41W)`.

### 4.3 Great Lakes genuinely need GLWU — measured, not assumed

At Lake Michigan (43.0 N, 87.0 W):

| Source | Result |
|---|---|
| `gfswave.global.0p25` | **9999** (missing) for `swh` and all three partitions |
| PacIOOS `ww3_global` | **null** |

Global ocean wave models mask inland water. **Great Lakes spots have never had a WW3 boundary.** Now that
C-76 makes a missing boundary raise instead of substituting calm, such a spot fails loudly — correct, but
it means Great Lakes support is currently theoretical and should be stated as such.

---

## 5. Sizes — and the trap

| Object | Size | Verdict |
|---|---|---|
| `gfswave.tCCz.spec_tar.gz` (all stations) | **1.72 GB** | do not fetch |
| `gfswave.tCCz.ibp_tar` (all boundary points) | **11.37 GB** | do not fetch |
| **`gfswave.<STATION>.spec`** | **7.75 MB** | **use this** |
| **`glwu.<STATION>.spec`** | **1.94 MB** | **use this** |
| `gfswave.<STATION>.bull` | 52 KB | station discovery |
| `gfswave.<STATION>.cbull` | 27 KB | — |

Per-station files are individually addressable, so the tarballs are a trap rather than a requirement.
7.75 MB per cycle is less than the 21 MB / 60 s this system moved before SURF-PUBLISH-RESULTS-ONLY.

An **`ibp`** (Interpolated Boundary Points) family exists — WW3 output produced specifically for
downstream nesting — but only as the 11 GB tarball. Per-station `.spec` is the practical equivalent.

---

## 6. Station discovery — the operator-location problem

~**4,036** ocean stations (12,108 files ÷ 3) and ~**115** Great Lakes stations (579 ÷ 5). We must not probe
7.75 MB files to learn where they are.

1. **One directory listing per product** → the full station-ID list.
2. **HTTP range request, bytes 0–120 of `<station>.bull`** → `Location : 46222      (33.62N 118.32W)`.
   ~100 bytes per station instead of 7.75 MB.
3. **Build the catalogue once, cache it long-term.** The pattern already exists:
   `/discovery/buoy-stations` and `/discovery/tide-stations` cache at `86400 s`, and NDBC lat/lon
   metadata is already implemented (§14.1). Many `gfswave` IDs *are* NDBC IDs (46222, 45002); the
   range-request path covers the rest (`3FYT`, `0Y2W3`).
4. At the existing 2 req/s limit a cold catalogue build is ~35 min — **once**, at
   configuration/discovery time, never in the forecast cycle.

**Selection per spot** needs only what the data already supplies:

| Criterion | Source |
|---|---|
| water body (ocean vs Great Lakes) | picks the catalogue; precedent exists — the bathymetry chain already distinguishes USGS Great Lakes topobathy from NCEI/CUDEM |
| deep-water suitability | **depth in the `.spec` per-timestep header** (487.9 m at 46222) — checkable, not assumed |
| proximity | distance + bearing, station must be seaward, within a maximum distance |

---

## 7. No silent degradation — this is a requirement, not a preference

Global station coverage is **uneven**. Where no station is near enough, this must **not** fall back to the
gridded bulk product: that reintroduces the averaged-away groundswell with different provenance.

Per `rules/coding.md` §1 and the C-76/C-77 rulings, the correct shape is a **configuration-time viability
check** — a spot is supportable only if a suitable spectral boundary exists, and the operator is told at
setup which station was chosen, how far away it is, and how deep it is. Same pattern as the existing L3
cluster viability test.

---

## 8. Code impact — smaller than expected

`swan_formats.py` already emits file-based boundary commands
(`BOUNDSPEC SIDE W CCW CONSTANT FILE 'BOUND_W.txt' 1`) and uses `BOUNDNEST1` for L2/L3. The L1 change is to
make the boundary file a **2-D spectrum** rather than a TPAR table.

**`ww3_to_swan_boundary()`'s synthesised JONSWAP peak and its fixed 30° `DSPR` both disappear.** Nothing is
synthesised any more.

**Resolution consequence to decide:** incoming ocean spectra are **50 freq × 36 dir out to 28.6 s**; our
SWAN `CGRID` is **32 × 36 out to 23.9 s**. SWAN interpolates frequencies (documented for `BOUNDNEST1`), but
truncating at 23.9 s would discard exactly the long-period energy this work exists to recover.

---

## 9. Why this was not implemented

Architectural on four triggers:

- **7** — new endpoints/products, spectral-file fetching, a new cached catalogue
- **4** — `wavewatch.fetch()` must return 2-D spectra, not a bulk `MarineForecastPoint` triple
- **1** — the boundary specification changes; the fixed 30° `DSPR` is removed
- **3** — `CGRID` frequency range may need to widen to accept 28.6 s energy

PROVIDER-MANUAL §14.3 must be rewritten with whatever is approved. It currently documents a PacIOOS 0.5°
bulk republication as "WaveWatch III forecasts" — which is how this survived. The manual also records how
it happened: the originally documented NOAA base *"was never live-verified"* and was *"found completely
unreachable,"* so the republication was substituted.

---

## 10. Open questions for the operator

1. **One station, or several points along the L1 boundary?** `BOUNDNEST3` is designed for multiple
   locations; a single station implies `BOUNDSPEC ... FILE`. Several is more faithful, 7.75 MB each.
2. **Are IBP files individually addressable anywhere?** They are the purpose-built nesting product; only
   the 11 GB tarball was found. Worth asking NCEP.
3. **`CGRID` frequency range** — widen to 28.6 s, or accept truncation?
4. **Maximum acceptable station distance**, and what the wizard tells an operator whose spot has none.
5. **GLWU cadence differs** — hourly `bulls.tCCz` (00–14z observed) versus the ocean product's
   00/06/12/18z. The runner's cycle logic assumes 6-hourly.

---

## 11. Acceptance criteria — validate against reality, not against the model

Per the rule added to `rules/clearskies-process.md` after this investigation:

1. The published swell list contains a **19 s ± 1 s train from the SSW** on a day WW3 shows one, height
   within ~30% of the WW3 partition.
2. Published surf height **overlaps Surfline's stated range** and **varies** across the forecast.
3. Published component count **tracks WW3's**, not fixed at 1 and not fabricated as 3.
4. Component periods are **distinct** — the T4B.2 failure signature was Tp 10.2 / 10.2 / 10.1 s.
5. C-83's fixes land first, so the closure test can no longer report PASS on a degenerate sample.
6. A **Great Lakes** spot produces a real boundary from GLWU, where today it gets nothing.

---

## 12. Reproducibility

- `scripts/compare_ww3_sources.py` — the three-source comparison, committed so these numbers are
  reproducible rather than a chat log.
- Concern entries: **C-86** (root cause), **C-87** (this design), **C-83** (why the closure test could not
  see it), **C-81/C-82** (superseded first reads, kept for the audit trail).
