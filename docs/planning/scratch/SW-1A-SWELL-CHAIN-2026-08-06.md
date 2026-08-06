# SW-1a — Swell-fidelity chain investigation (read-only)

**Task:** SW-1a, SURF-PHYSICS-REMODEL-PLAN-2026-08-05, operator order 2026-08-06.
**Question:** Surfline / surf-forecast.com resolve THREE swell trains for Huntington
(≈2026-08-06T03:00–06:00Z); we publish TWO. Find where the ~9 s S train is lost, or show it
never existed in our input.

**Verdict up front:** it never existed in our input. The ~9 s energy is not a separate
spectral peak anywhere in the raw WW3 boundary spectra our L1 boundary ingested for this
window, at any of the four candidate stations, at any of the four target hours — it is only
the smooth monotonic tail of the single ~12.7 s peak. The real NDBC buoy at one of those same
stations (46253), same hour, DOES show a genuine separate local peak near 9.1 s in its own
hardware-measured spectrum. The loss site is upstream of our system: NOAA's operational
`gfswave.global.0p16` WW3 model output at these points does not resolve the same three-way
partition the buoy hardware (and, evidently, Surfline/surf-forecast.com's own products) do.
Neither SWAN's L1→L2→L3 nesting nor its watershed partitioning at the DWR point can be "the"
loss site — there was nothing in the input for either stage to lose.

---

## 1. Our published swells (`spectral_dwr`, DWR/multiSwell channel)

**Command:**
```
ssh -F .local/ssh/config librewxr "sudo -u ubuntu python3 -c \"
import json
data = json.load(open('/var/run/weewx-clearskies/swan/forecast_cache.json'))
hb = data['spots']['huntington-city-beach-pier']
for e in hb['spectral_dwr']:
    if e['time'].startswith('2026-08-06T0[3-6]'): print(e)
\""
```
Cache provenance: `saved_at=2026-08-06T03:19:01Z`, spot `run_time=2026-08-06T02:51:43Z`,
`hrrr_cycle_time=2026-08-06T00:00:00Z`.

| Hour (Z) | Component | H (m) | T (s) | dir (°) | classification |
|---|---|---|---|---|---|
| 03:00 | 1 | 0.566 | 3.84 | 271.9 | wind_swell (is_wind_sea) |
| 03:00 | 2 | 0.350 | 13.07 | 200.6 | groundswell |
| 03:00 | 3 | 0.050 | 20.17 | 206.1 | groundswell (noise-floor) |
| 04:00 | 1 | 0.559 | 3.79 | 271.9 | wind_swell |
| 04:00 | 2 | 0.350 | 13.06 | 200.6 | groundswell |
| 05:00 | 1 | 0.551 | 3.76 | 271.8 | wind_swell |
| 05:00 | 2 | 0.350 | 13.05 | 200.6 | groundswell |
| 05:00 | 3 | 0.051 | 20.15 | 207.0 | groundswell (noise-floor) |
| 06:00 | 1 | 0.545 | 3.74 | 271.7 | wind_swell |
| 06:00 | 2 | 0.349 | 13.04 | 200.5 | groundswell |
| 06:00 | 3 | 0.052 | 20.13 | 207.1 | groundswell (noise-floor) |

**No ~9 s partition at any of the four hours.** The tiny ~20 s "groundswell" entries at 03/05/06Z
are a noise-floor artifact (see §2 — matches the low-frequency bump SWAN's watershed algorithm
also isolates at k=5, T≈20.4 s, in the raw input), not a real swell train.

**Handoff channel (`spectral`) contrast, transects 48/55, same hours** — same structure,
confirming the two-partition result is not a DWR-channel-specific artifact:
```
ssh -F .local/ssh/config librewxr "sudo -u ubuntu python3 -c \"...hb['spectral']...handoff_by_transect['48']/['55']...\""
```
| Hour | Transect | groundswell H/T/dir | wind_swell H/T/dir | noise H/T/dir |
|---|---|---|---|---|
| 03:00 | 48 | 0.484/13.20/207.1 | 0.421/3.89/252.9 | 0.070/20.32/209.4 |
| 03:00 | 55 | 0.472/13.21/206.8 | 0.421/3.88/253.1 | 0.068/20.32/208.8 |
| 05:00 | 48 | 0.484/13.19/207.1 | 0.421/3.79/253.3 | 0.084/20.05/210.1 |
| 05:00 | 55 | 0.473/13.19/206.8 | 0.421/3.79/253.5 | 0.076/20.18/208.8 |

## 2. Our raw INPUT — L1 WW3 boundary station spectra

**BOUNDSPEC lines (`level1/INPUT`):**
```
BOUNDSPEC SIDE S CCW VARIABLE FILE 37975.3391 'BOUND_S_46223.txt' 1
BOUNDSPEC SIDE W CCW VARIABLE FILE 645.9054 'BOUND_W_46256.txt' 1 9516.9632 'BOUND_W_46222.txt' 1 13952.4499 'BOUND_W_46253.txt' 1
```
Four stations selected: **46222, 46253, 46256** (W side), **46223** (S side) — matches the
task's candidate list. Each file: SWAN standard 2-D spectral format, 50 frequency bins
(0.035–0.964 Hz), 36 direction bins (10° steps), hourly timesteps. Run: `level1/INPUT` mtime
`2026-08-06 03:25:53Z`, `level1/norm_end` = "Normal end of run" (~03:26Z) — this is the
persisted **latest** full run (level1/ is overwritten each full run; the earlier 02:51:43Z
cycle's own boundary files no longer exist to compare byte-for-byte — see caveat below).

**Method:** for each station × each target hour, summed variance density over all 36
directions per frequency row (`E(f) = Σ_θ VaDens(f,θ) · FACTOR · Δθ`) and scanned for local
maxima. Parser: `scratchpad/parse_bound.py` (local, ad hoc — no repo reader existed for this
exact form; `services/swan_spectral.py` operates on SWAN's own PTHSIGN table output, not raw
BOUNDSPEC files).

**Result — station 46253, 2026-08-06T03:00:00Z** (retrieved via
`ssh librewxr "sudo -u ubuntu cat /var/run/weewx-clearskies/swan/level1/BOUND_W_46253.txt"`,
block at file line 580):

| k | f (Hz) | T (s) | E(f) | dom. dir (°) |
|---|---|---|---|---|
| 10 | 0.0689 | 14.51 | 0.106 | 224.98 |
| 11 | 0.0737 | 13.57 | 0.135 | 224.98 |
| **12** | **0.0788** | **12.69** | **0.188 ← PEAK** | 185.0 |
| 13 | 0.0843 | 11.86 | 0.118 | 185.0 |
| 14 | 0.0902 | 11.09 | 0.071 | 185.0 |
| 15 | 0.0966 | 10.35 | 0.054 | 185.0 |
| 16 | 0.1030 | 9.71 | 0.039 | 185.0 |
| **17** | **0.1110** | **9.01** | **0.034** | 185.0 |
| 18 | 0.1180 | 8.47 | 0.025 | 175.2 |
| 19 | 0.1270 | 7.87 | 0.019 | 164.9 |

**Monotonic decay from the 12.69 s peak straight through the 9.01 s bin — no local minimum,
no re-rise, direction pinned at 185° the whole way down to 9.7 s.** Full local-maxima scan
across **all four stations (46222/46253/46256/46223) × all four hours (03/04/05/06Z)** found
exactly the same shape every time: one tiny low-frequency noise bump (T≈20.4 s, E≈0.01–0.02,
negligible), the single swell peak at T=12.69 s, and the windsea peak at T≈2.9–3.8 s. **Zero
local maxima anywhere in the 7–11 s band, any station, any hour.**

Sample (station/hour → local maxima list, k/T/E/dir):
```
46253 03:00Z: [(5,20.37,0.008,215), (12,12.69,0.188,185), (27,4.61,0.017,265), (34,2.87,0.050,265)]
46253 06:00Z: [(5,20.37,0.011,195), (12,12.69,0.193,185), (31,3.51,0.047,275)]
46222 03:00Z: [(5,20.37,0.008,225), (12,12.69,0.208,185), (33,3.07,0.056,265)]
46256 03:00Z: [(5,20.37,0.007,215), (12,12.69,0.156,225), (34,2.87,0.043,265)]
46223 03:00Z: [(5,20.37,0.014,205), (12,12.69,0.323,195), (27,4.61,0.012,265), (36,2.50,0.016,265)]
```
**Answer to the binary test: NO — the raw INPUT does not carry a distinct energy peak near
0.11 Hz separate from the 12–14 s peak, at any station, any hour checked.**

## 3. Ground truth — NDBC realtime buoy spectra (hardware measurement, not WW3 model)

**Commands (data pulled live, NDBC/NOAA only, per access rules):**
```
curl -s https://www.ndbc.noaa.gov/data/realtime2/46253.data_spec
curl -s https://www.ndbc.noaa.gov/data/realtime2/46222.data_spec
```
Realtime2 files only extend to "now" (2026-08-06 ~03:26Z at fetch time) — only the 03:00Z row
falls inside the target window; 04/05/06Z have not occurred yet.

**46253, 2026-08-06 03:00Z** (raw row, freq bins in parentheses, units m²/Hz):
```
... 0.088 (0.090) 0.078 (0.095) 0.035 (0.101) 0.057 (0.110) 0.046 (0.120) 0.050 (0.130) ...
```
Local-maxima scan: peak at **f=0.080 Hz (T=12.5 s), E=0.354** → falls to a **local minimum at
f=0.101 Hz (T=9.9 s), E=0.035** → **rises to a distinct local maximum at f=0.110 Hz (T=9.09 s),
E=0.057** (63% above the adjacent minimum) → falls again to E=0.046 at f=0.120 Hz. **This is a
genuine, separately-resolvable ~9 s peak in the buoy's own measured spectrum, absent from our
WW3 input at the same station and (near-enough) the same hour (§2).**

**46222, 2026-08-06 03:00Z:** peak at f=0.075 Hz (T=13.33 s), E=0.488, falling to E=0.054 at
f=0.095 Hz (T=10.5 s), then a broader, less cleanly separated shoulder up to E=0.073 at
f=0.120 Hz (T=8.33 s) before falling again — a real non-monotonic secondary bump in the 8–10 s
band, though less sharply split than 46253's.

**NDBC 2-parameter `.spec` summary** (`https://www.ndbc.noaa.gov/data/realtime2/46253.spec`,
row `2026 08 06 03 26`): `SwH=0.3m SwP=12.5s SwD=SSE`, `WWH=0.7m WWP=3.2s WWD=WNW`. The
2-parameter product only ever names two systems (it splits at one fixed frequency) — it cannot
surface the 9 s shoulder; only the raw `.data_spec` frequency array does. This matches why the
finding required parsing the full spectrum rather than the summary product.

## 4. Loss localization

Per the task's own conditional: *"if yes [energy in input], find where it dies … if no, the
loss is upstream."* **Answer: no — §2 shows the energy is not in the raw WW3 boundary input.**
Therefore:

- **SWAN's watershed partitioning at the DWR point is not the loss site.** It correctly
  reports what the input contains: one groundswell partition (13.0–13.1 s) + one windsea
  partition (3.7–3.9 s) + a negligible noise-floor partition (~20 s), matching the input
  spectrum's own shape (§2) component-for-component. There is no unresolved third peak for
  the partitioner to have merged.
- **L1→L2→L3 nesting is also not implicated for this specific loss** — the same reasoning
  applies: nesting cannot lose energy that was never present in the L1 spectrum it started
  from. (This does not reopen YQ-1 §Q3(b)'s broader, still-uninstrumented question about
  whether nesting loses *magnitude* on the partitions that DO exist — that is a separate
  question this task did not re-examine.)
- **The loss is upstream of our system**, at or before the WW3→BOUNDSPEC ingest: NOAA's
  operational `gfswave.global.0p16` global model (confirmed as the pinned ocean product in
  `services/ww3_station_selection.py:363-364`) does not resolve, at these four station points,
  the same three-way swell partition that (a) the buoy's own hardware measurement resolves at
  46253, and (b) Surfline/surf-forecast.com's products report. This is not a code defect in
  this repo — it is a real gap between the coarse (~18.5 km) global WW3 product this system is
  architected to ingest and what higher-fidelity products (buoy assimilation, Surfline's LOTUS)
  see. **Per the mandatory architectural-change block: changing which WW3 product is ingested
  would change a model input/data source — that is a trigger-list item (adds/changes a data
  source) and is NOT decided here; it returns to the operator as a finding, not a fix.**

**Provenance caveat (stated plainly, not glossed over):** the raw-input check (§2) reads the
*currently persisted* `level1/` boundary files, from the full run that completed
`norm_end` ≈03:26Z. The published-output check (§1) reads `spectral_dwr`/`spectral` from an
**earlier** cycle, `run_time=2026-08-06T02:51:43Z` (cache `saved_at=03:19:01Z`) — `level1/` is
overwritten each full run, so that earlier cycle's own boundary files no longer exist to
compare byte-for-byte. Both cycles share `hrrr_cycle_time=2026-08-06T00:00:00Z`, and
ARCHITECTURE.md states the WW3 boundary is "reused from the last full run rather than
re-fetched" across consecutive full runs on the same HRRR cycle, so the underlying WW3
spectral content is very likely identical between the two — but this was not independently
confirmed byte-for-byte, because the earlier cycle's file is gone. **What would close this
gap:** a snapshot of `level1/BOUND_*.txt` taken immediately after a run whose `norm_end`
precedes the cache's own `run_time`, so both come from the exact same cycle. This gap does
not change the verdict: YQ-1 independently measured a **third**, still-earlier cycle
(`2026-08-05T22:00:00Z`) and found the same two-partition groundswell+wind_swell structure at
nearly identical Hs/Tp (groundswell 0.48 m/13.4 s + wind_swell 0.22 m/5.8 s, vs. this
investigation's 0.35 m/13.1 s + 0.55 m/3.8 s) — the missing 9 s train is consistently absent
across at least three consecutive cycles spanning ~5.5 hours, not a single-cycle fluke.

## 5. Direction

Our dominant (highest-energy, non-windsea) partition direction, `spectral_dwr` groundswell,
03:00–06:00Z: **200.5–200.6°**. Pinned externals: Surfline **S 185°** (LOTUS), Surfline **9 s
train 178°**, surf-forecast.com Swell2 (11–12 s) **SSW ≈ 202.5°**.

**Delta vs. Surfline's 12 s/185° pin: +15.5° to +15.6°** (rotated clockwise, toward SW).
**Delta vs. surf-forecast.com's 11–12 s/SSW (202.5°) pin: −1.9° to −2.0°** (close match).
Our direction sits almost exactly on surf-forecast.com's SSW reading and diverges from
Surfline's S reading by ~15–16°. This is a separate question from the missing-9 s-train
finding above (flagged in the plan as EYEBALL-FIX-PLAN S-5 territory / SW-1b's adjacency
note) and is not further investigated here per SW-1a's scope.

## Files/commands referenced

- `docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md:124-167` (Task SW-1)
- `docs/planning/scratch/YQ-1-ENERGY-DEFICIT-2026-08-05.md:200-315` (§Q3, cross-cycle
  corroboration)
- `docs/ARCHITECTURE.md` "SWAN model outputs" paragraph (two SPECOUT channels) and "SWAN model
  inputs" paragraph (WW3 boundary selection, `gfswave.global.0p16`)
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/ww3_station_selection.py:363-364`
  (product pin)
- Remote: `/var/run/weewx-clearskies/swan/forecast_cache.json`,
  `/var/run/weewx-clearskies/swan/level1/{INPUT,BOUND_W_46253.txt,BOUND_W_46222.txt,BOUND_W_46256.txt,BOUND_S_46223.txt,norm_end}`
- External: `https://www.ndbc.noaa.gov/data/realtime2/{46253,46222}.{data_spec,spec}`
- Local scratch (not committed): `scratchpad/parse_bound.py`,
  `scratchpad/{BOUND_*.txt,BOUND_*_0306.out,ndbc_*_data_spec.txt,ndbc_*_spec.txt}`

## Disposition

Read-only per task scope. No code changes. No fix proposed beyond naming the defect site
(there isn't one in-repo for this specific finding — see §4). Returns to the coordinator:
Round X's premise set is unaffected (X concerns breaking-energy dissipation, not swell
partitioning). SW-1a's finding narrows SW-1b's scope: SW-1b should not expect to find a
selection-logic bug that "drops" a 9 s partition, because SWAN never had one to select from —
SW-1b's job (the text-forecast swell-selection defect, and the regressed current-conditions
display) is independent of this finding and proceeds on its own evidence.
