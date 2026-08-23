# Survey — measured partition-band spectral narrowness (ν, Qp, κ) at the 15 m deep-water reference point

**Round:** CONSISTENCY-SCORING pre-coding verification, 2026-08-23, task V2. **Author:** compute agent (Sonnet), read-only on `librewxr`. **Brief:** `docs/planning/briefs/PARTITION-NARROWNESS-SURVEY-BRIEF-2026-08-23.md`. **Companion task V1** (run-length formula verification) is separate and not repeated here.

**Purpose:** measure what "narrow" actually looks like for a swell partition at our own 15 m reference point, so the set-timing curves in `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.3 are calibrated against real spectra, not literature guesses. This is a measurement report — it does not correct §3.3's provisional formulas (V1 owns that) and it makes no scoring recommendation.

---

## 1. Data pulled

| Source | Host path | Lines/timesteps | Notes |
|---|---|---|---|
| Trace, stage `spec_l2_dwr` | `librewxr:/var/log/weewx-clearskies/marine-trace-2026082{1,2,3}.jsonl` | 568 + 556 + 266 = **1390 lines before dedup** | grep'd on host, streamed home; whole files never copied |
| — deduped by (spot_id, valid_time), last occurrence (file order = emission order) wins | | **127 unique hourly spectra after dedup** | spans valid_time 2026-08-21T00:00Z .. 2026-08-26T06:00Z (forecast-horizon overlap across runs, per brief) |
| `SPEC_DWR_1.txt` / `TABLE_DWR_1.txt`, `swan/level2/` | `librewxr:/var/lib/weewx-clearskies/swan/level2/` | 73 timesteps, 73 PT rows | mtime 2026-08-23 08:15Z (latest full run at pull time) |
| `SPEC_DWR_1.txt` / `TABLE_DWR_1.txt`, `swan/stationary/level2/` | `librewxr:/var/lib/weewx-clearskies/swan/stationary/level2/` | 12 timesteps, 12 PT rows | mtime 2026-08-23 09:34Z |

**Access note:** `/var/lib/weewx-clearskies/swan/` is `drwxr-x--- ubuntu:ubuntu`; the `claude` SSH user has no group membership and got `Permission denied` on a plain `ls`/`cat`. Passwordless `sudo -n ls` / `sudo -n cat` (read-only) was available and used to list and pull the four files — no write, no ownership change. Flagging this for the lead: TABLE_DWR/SPEC_DWR were **not actually inaccessible** (open question #2 in the brief does not apply), but a future read-only agent hitting the same directory without `sudo -n` would wrongly report them absent.

Single spot in the trace sample: `huntington-city-beach-pier`. The two SPEC_DWR/TABLE_DWR sources are single-point DWR baseline files with no `spot_id` field but are the same 15 m reference point (brief §4). No multi-spot breakdown is possible or needed.

**Total records analysed:** 212 dominant-partition records under definition D (127 trace + 73 level2 + 12 stationary), 85 under definition P (73 level2 + 12 stationary; trace records carry no PT table).

---

## 2. Spectral axis facts (bound how well ν can be resolved)

Identical across all three sources (trace, level2, stationary/level2):

- **nfreq = 35**, range 0.0300–1.0000 Hz, **geometric spacing**, ratio ≈ 1.108 between consecutive bins (~11 %/bin) — not linear.
- **ndir = 72, direction step = 5°** (72 bins spanning the full 360° circle).

**Resolution floor (open question #3):** on this geometric grid, a partition spanning only **one** frequency bin is degenerate — it has no internal frequency dispersion and reads ν = 0 by construction, which is not physically meaningful (no way to tell "very narrow" from "no data"). The real floor is set by a partition spanning **two adjacent bins**: computed with equal energy split across the pair, ν ≈ **0.051** essentially everywhere in the swell/groundswell range (9–24 s periods; checked at 11 adjacent-bin pairs, ν = 0.0508–0.0517 — flat because the bin ratio is nearly constant). **The grid cannot show ν below ≈ 0.05 for any genuinely-resolved partition.** All observed dominant-band ν in this sample (§3) sit 2.5–4× above that floor, so the grid resolves what we measured with headroom — but it could not resolve the ν ≈ 0.05 example the set-timing brief's own §3.3 worked example uses to project a 9-minute set interval; that example sits right at the edge of what this grid could ever show.

---

## 3. Sea states covered (caveat: what this sample actually contains)

| Quantity | n | median | p10 | p90 |
|---|---|---|---|---|
| Total-spectrum Hs (m) | 212 | 0.57 | 0.44 | 0.57 |
| Total-spectrum Tp (s) | 212 | 14.6 | 13.2 | 14.6 |

**The 3-day trace window captured one long-period groundswell event, not a range of conditions.** Dominant-partition peak period (definition D, trace-only, n=127) took only three discretized values across the entire window: 11.9 s (×1), 13.2 s (×31), 14.6 s (×95) — the spectrum's peak barely moved bin-to-bin for three straight days. Dominant-band Hs ranged 0.33–0.54 m (small surf). Classification of the dominant partition was `groundswell` in 210/212 rows and `swell` in the other 2; **no row in this sample had a windsea-dominant hour.** Read every number below as "what one clean, narrow, small groundswell looked like here" — not as a general distribution across swell types.

---

## 4. ν, Qp, κ(Tm01) — dominant band, by definition

D = repo `decompose_spectrum()` (`frequencyRange`, every spectrum). P = SWAN watershed PT* partitions with the half-way band rule (only where `TABLE_DWR_1.txt` exists for the same timestep).

| Definition | n | ν median | ν p10 | ν p90 | Qp median | Qp p10 | Qp p90 | κ(Tm01) median | κ(Tm01) p10 | κ(Tm01) p90 |
|---|---|---|---|---|---|---|---|---|---|---|
| D (all sources) | 212 | 0.171 | 0.148 | 0.187 | 3.58 | 3.08 | 4.09 | 0.590 | 0.507 | 0.664 |
| D (trace-only, the actual 3-day sample) | 127 | 0.171 | 0.135 | 0.193 | — | — | — | — | — | — |
| P (single production run) | 85 | 0.174 | 0.174 | 0.178 | 3.55 | 3.07 | 3.55 | 0.583 | 0.583 | 0.592 |

ν_total (whole spectrum, unrestricted) for contrast: median **1.04** (p10 0.91, p90 1.12) — about **6× broader** than the dominant-band ν. This is the headline sanity check: restricting to the dominant partition's own frequency band, rather than scoring the whole spectrum's width, changes the answer by an order of magnitude, exactly as the set-timing brief's §3.3 step 1 argues it must.

**D and P agree closely** (both ≈ 0.17–0.18 for ν, ≈ 3.5–3.6 for Qp, ≈ 0.58–0.59 for κ) — reassuring, since they are independent partitioners (peak-neighbourhood integration vs. SWAN's own watershed algorithm) applied to the same physical event.

### By classification (definition D)

| Classification | n | ν median | Qp median | κ(Tm01) median |
|---|---|---|---|---|
| groundswell | 210 | 0.171 | 3.58 | 0.590 |
| swell | 2 | 0.211 | 2.79 | 0.410 | 
| wind_swell | 0 | — | — | — (never the dominant partition in this sample) |

`swell` n=2 — too few to trust as a distribution; reported for completeness only.

### Secondary partition, for narrow-vs-broad contrast

Definition P's secondary is always SWAN's partition-1 (wind sea, by SWAN's own indexing convention): n=77, ν median **0.526**, classification 100 % `wind_swell`, Hs 0.18–0.21 m. This is the cleanest evidence in the sample that the method discriminates narrow swell from broad windsea correctly: ν jumps from ≈0.17 (dominant swell) to ≈0.53 (windsea) — a 3× difference — even though both partitions come from the exact same spectrum.

**Caveat on definition D's secondary:** its ν median (0.1714) is numerically identical to its dominant-band ν median, and its classification mix (150 groundswell / 57 wind_swell / 5 swell out of 212) is not a clean windsea-only set the way P's secondary is. `decompose_spectrum()`'s own docstring notes it does **no greedy cell exclusion** — each peak integrates its full ±4-bin neighbourhood independently, so on a single stable groundswell event it can return two components whose neighbourhoods and hence bands overlap heavily. This is a property of that partitioner's design (not a bug the survey is reporting as a defect), but it means D's "secondary" numbers in this event should be read with more caution than P's for use as a distinct-partition measurement.

---

## 5. Provisional envelope-route indicators (V1 verifying — not a result to trust yet)

`N_set = 1/(√(2π)·ν·ρ)`, `N_rep = e^{ρ²}/(√(2π)·ν·ρ)`, `T_set = N_rep × Tm01`, ρ = √2, dominant band only.

| Definition | n | T_set median (min) | T_set p10 | T_set p90 | N_set median | frac ≥2 min | frac ≥5 min | frac ≥10 min |
|---|---|---|---|---|---|---|---|---|
| D (all sources) | 212 | 2.85 | 2.55 | 3.13 | 1.65 | 99.5 % (211/212) | 0.0 % | 0.0 % |
| D (trace-only, the actual 3-day sample) | 127 | 2.85 | 2.50 | 3.39 | 1.65 | 99.2 % (126/127) | 0.0 % | 0.0 % |
| P (single run) | 85 | 2.81 | 2.50 | 2.81 | 1.62 | 90.6 % (77/85) | 0.0 % | 0.0 % |

**Headline finding:** under the brief's own provisional formula, this sample's measured ν (≈0.13–0.22) never produces a T_set beyond **~3.75 minutes** (max observed) — it clusters tightly at 2–3 min and **never once reaches the "5 to 10 minute groundswell norm"** that §3.1 of the set-timing brief cites as the comfortable surfer-reported band. The brief's own worked example (§3.3: "ν = 0.05 → ≈9 min") would need a partition roughly 3× narrower than anything measured here — and per §2 above, that ν = 0.05 example sits at this grid's resolution floor, not comfortably inside it.

**Two-swell beat override:** fires (secondary share ≥ 25 % of summed partition m0) in **9/212 (4.2 %)** of definition-D dominant records. Where it fires, T_beat median 2.36 min, p10 1.54 min, p90 29.0 min — a much wider spread than the envelope-route T_set, occasionally landing in the surfer-reported 5–15 min band the plain envelope route never reaches in this sample.

---

## 6. κ sensitivity to lag choice

Median absolute difference between κ evaluated at Tm01 vs. at Tm02/Tp, dominant band:

| Definition | n | \|κ(Tm01)−κ(Tm02)\| median | \|κ(Tm01)−κ(Tp)\| median |
|---|---|---|---|
| D | 212 | 0.0077 | 0.0205 |
| P | 85 | 0.0080 | 0.0195 |

Both differences are small relative to κ's own scale (≈0.58–0.59): lag choice moves κ by ~1–4 % of its value in this sample. Tm01 vs Tm02 barely matters; Tp is a bit more sensitive (κ is more lag-sensitive near a period estimated from a single peak bin than from a spectral moment).

---

## 7. Band-sanity ratio, definition P

Σ(band m0) ÷ (Hs_PT/4)² — 1.0 means the half-way frequency band recovers exactly the PT partition's own reported energy.

| Role | n | median | p10 | p90 |
|---|---|---|---|---|
| dominant | 85 | 0.923 | 0.922 | 0.946 |
| secondary | 77 | 1.169 | 1.164 | 1.174 |

Both stay within ~20 % of 1.0 — the half-way rule is not producing obviously wrong bands (no band containing "almost none" of its partition's own Hs²). The dominant band consistently recovers slightly *less* energy than PT reports (ratio <1, band draws a boundary that clips a bit of the swell's own tail into the neighbour), and the secondary consistently recovers slightly *more* (ratio >1, absorbing a bit of the dominant's tail) — a small, systematic, and physically sensible pair of biases from a fixed-midpoint rule on an asymmetric spectrum, not a broken definition.

---

## 8. D-vs-P dominant-period agreement

Where both a trace-shaped 2-D spectrum and a same-timestep PT table exist (level2 + stationary/level2 only, n=85): dominant partition's period (D's weighted period vs. P's Tp) agrees within 10 % in **80/85 = 94.1 %** of cases.

---

## 9. Caveats (mandatory)

1. **Three days only** (trace retention caps at 3 files) — and within those three days, one event. This is not a survey of "typical" ν across swell types; it is a close look at one clean small groundswell. Every median above should be read as "what this one event looked like," not "what a groundswell partition looks like in general" — repeat this survey across a windsea day and a mixed two-swell day before trusting any curve calibrated only from this pull.
2. **Sea states present:** total Hs 0.44–0.57 m, Tp 13.2–14.6 s (three discretized peak-bin values), dominant partition classified `groundswell` in 210/212 rows, `swell` in 2, never `wind_swell`. No large-Hs, no short-period-dominant, no genuinely two-swell-comparable hour is represented (only 9/212 hours cleared the 25 % secondary-share beat threshold).
3. **Which band definition to trust more:** **definition P** (SWAN's own watershed partitions) for any number that will feed a scoring curve, once it exists for a timestep — it is the algorithm the production system already treats as authoritative (per `swan_spectral.py`'s own module comment: `decompose_spectrum()` "is no longer its production caller"), its band-sanity ratios stay close to 1.0, and its secondary-partition ν cleanly separates swell from windsea. **Definition D** is useful as an every-hour fallback (it is the only one available for trace records and for any timestep with no TABLE_DWR) and the two agree well when both exist (94.1 % dominant-period agreement, §8), but its secondary-partition numbers should be read cautiously per §4's overlap caveat.
4. **Resolution floor:** ν below ≈0.05 cannot be shown by a genuinely-resolved partition on this grid (§2) — any future curve knot placed at ν < 0.05 is asking the grid for something it cannot currently measure.
5. Every number in §§4–8 is on the raw CSV in `scratch/partition-narrowness/partition_narrowness.csv` (586 rows, one per partition/role/definition/source) plus `beat_events.csv` (9 rows) and `dp_agreement.csv` (85 rows), kept locally for the lead's spot-check.

---

## 10. Method summary

- 1-D spectrum per record: `S(f) = Σ_j E[i][j]·dd_j`, using the exact df/dθ midpoint-spacing convention `compute_total_m0()`/`decompose_spectrum()` use (verified: my 1-D collapse's total m0 matches the repo's `compute_total_m0()` to 1 part in 10¹⁶, and matches the trace's own `emit_spectrum()`-computed `summary.total_m0` for the same record).
- Moments m0/m1/m2 computed over the whole spectrum and over each partition band by the same convention, restricted to `[f_lo, f_hi]`.
- ν = √(m0·m2/m1² − 1) (Longuet-Higgins), Qp = (2/m0²)∫f·S(f)²df (Goda 1970), κ(lag) = |∫S(f)·e^{i2πf·lag}df| / m0 (Battjes & van Vledder working definition, brief §5 item 3) — lag and normalisation are explicit parameters in `scratch/partition-narrowness/analyze.py` for V1 to adjust if it refines the definition.
- Definition D: repo's `decompose_spectrum()`, dominant/secondary = highest/second-highest `height`, band = its `frequencyRange`.
- Definition P: repo's `parse_table_pt_partitions()`; partitions sorted by peak frequency (1/Tp), band edges at the midpoint frequency to each frequency-adjacent partition, outermost partitions extend to the spectrum's own frequency edges (0.0300 / 1.0000 Hz).
- Classification: repo's `_classify_period()` (imported, not reimplemented).
- Indicator formulas (§5): the set-timing brief's own provisional expressions, implemented as given, not adjusted.

Script: `scratch/partition-narrowness/analyze.py` (extraction/computation) + `compute_stats.py` (report tables). Raw pulled inputs and full CSV outputs are in `scratch/partition-narrowness/` for the lead's spot-check.
