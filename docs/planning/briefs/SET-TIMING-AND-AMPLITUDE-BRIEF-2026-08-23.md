# Research brief — set timing and set amplitude inside the Consistency factor

**Date:** 2026-08-23 · **Author:** research agent (read-only; no repo file other than this brief was touched)
**Scope (operator rulings 2026-08-23, obeyed):** the score's structure (ADR-101 weighted geometric mean, five factors, Consistency weight 0.10, `0.6 × timing + 0.4 × amplitude` inside it) is fixed. No alternative architectures, no commercial survey. Three questions only: (1) how SET TIMING should be scored as a graded curve; (2) how SET AMPLITUDE is obtained from SwellTrack + the wave spectrum instead of SurfBeat's IG height; (3) what SurfBeat can honestly still contribute.
Companion: [RESEARCH-SET-CONSISTENCY-2026-08-23.md](RESEARCH-SET-CONSISTENCY-2026-08-23.md) (yesterday's physics, §2.2–2.4; reused, not repeated).

---

## 1. Summary

1. Surfers' evidence on timing is consistent: groundswell sets "every 5 to 10 minutes" is the comfortable norm; "every 5 minutes with 10 waves" is a great day; "every 15 minutes with one or two waves" is a poor one; waiting "15 or 20 minutes for a decent set wave" is the frustration threshold; "half an hour or more" is the bad tail. Sets hold 2–8 waves, typically 3–6. Recreational surfers ride ≈ 20 waves/hour and sit waiting ≈ 42 % of the time. (§3.1, all cited.)
2. Proposed timing curve (§3.2): piecewise-linear in set interval — 2–6 min = 1.0, tapering to 0.85 at 10 min, 0.6 at 15 min, 0.4 at 20 min, 0.25 beyond 30 min; under 1 min (no discernible sets) = 0.8. Waves-per-set curve: 3–6 = 1.0, 1–2 = 0.6, 7–10 = 0.9, >10 = 0.8. Every knot's source or "judgement" label is stated.
3. The set interval comes from OUR spectrum, not SurfBeat: the dominant partition's spectral width (Longuet-Higgins ν, or Kimura's successive-height correlation κ from Battjes & van Vledder) gives the expected repetition length in waves; × mean period = set interval; the run length above Hs = waves per set. A two-swell beat `1/|1/Tp₁ − 1/Tp₂|` overrides when two partitions are comparable. (§3.3.)
4. "Set amplitude" cannot be an absolute height — Size already scores face height, and under Rayleigh the set-wave/lull-wave height ratio of a single swell is a constant (≈ 2.3), so it carries no information. What varies between days is (a) how coherent the sets are (κ — do big waves follow big waves) and (b) how high the lull floor is (the filler from other partitions, which SwellTrack gives per partition at the break). §4 defines set-wave face height, between-set face height and a contrast index from these, with bands.
5. SurfBeat's bound-IG peak (25–200 s) is the dominant wave-GROUP period of the forcing spectrum — a legitimate cross-check on the group-scale part of §3.3, nothing more. It cannot be converted to a minutes-scale set interval without the fine spectral structure its 8-bin axis does not resolve. IG height stays display-only. (§5.)
6. Current code defects restated (§6): minutes bands vs seconds physics (timing sub-score stuck at 0.8), uncited metre bands, IG height size-confounded.
7. Recommendation (§7): keep `consistency = 0.6 × timing + 0.4 × amplitude`; timing = 0.7 × interval curve + 0.3 × waves-per-set curve from spectral group statistics; amplitude = set-contrast index from κ and SwellTrack per-partition break heights; SurfBeat demoted to a logged cross-check. New inputs and ADR-101 §7.2 inventory deltas are named. Three single-use overlaps are flagged for ruling.

---

## 2. What the original brief and ADR intended for Consistency

- SURF-SCORE-REBUILD-RESEARCH-BRIEF §1 :47–48 — "Consistency / set structure — regular, predictable sets give more ride opportunities per session; wave period and swell organization drive it." This is the intent: regularity and predictability of sets, driven by period and organization.
- §1b :97–103 — evidence "moderate"; "in a day-quality context it modulates opportunity (rides per session), not the quality of the wave a surfer actually rides — surfers wait through lulls for good sets." Lowest weight (0.10) for that reason.
- §2 :128–130 — "Surfers experience quality as wave-count at a quality tier … Consistency is part of quality, not a side stat."
- §4 :160 — inventory row: "Consistency / sets — Set timing from SurfBeat infragravity spectral peak — `setTimingMinutes`, `setAmplitudeM`."
- §7.2 :308–313 — row 5: `setTimingMinutes` (SurfBeat IG spectral peak) "Set interval curve (regular, surfable intervals → 1.0)", weight 0.6; `setAmplitudeM` (IG height at shoreline) "Set definition/strength", weight 0.4; `swellDominance` fallback.
- ADR-101 :66 — "Consistency | 0.10 | SurfBeat set timing/amplitude | fallback: swell-dominance proxy"; :109–111 — "author new band curves for … set timing"; :97–98 — SurfBeat set data become scoring inputs for the first time.

So the intent was always "regular, surfable set intervals → 1.0; set definition/strength as the second term." Only the SENSOR was SurfBeat. The brief never wrote down what "surfable interval" or "set strength" meant numerically — that is what this brief supplies, and it moves the sensor to the spectrum + SwellTrack, keeping the two-term structure and its 0.6/0.4 weights.

---

## 3. Set timing

### 3.1 What surfers consider good, acceptable, bad — with sources

| Statement | Source |
|---|---|
| Groundswell: "wave sets … are generally larger, with intervals of 5 to 10 minutes between them, allowing enough time to rest or position yourself better." Windswell: "wave sets tend to break in quick succession." | Padang Padang Surf Camp, "Surfer's guide to wave period" (practitioner) |
| "Some sets arrive every 15 minutes with only one or two waves, and other sets arrive every 5 minutes with 10 waves in each set." (the poor-vs-good contrast) | Surfline, "Why do waves come in sets?" (fetched via proxy) |
| "The interval between sets varies from a few minutes to fifteen or more"; "normally a few minutes … but could take half an hour or more." | Surfertoday, "Why do waves come in sets?" (quoted in yesterday's brief §2.3; direct fetch 403 today) |
| Frustration threshold: "waiting for 15 or 20 minutes for a decent set wave that never comes." | Surfertoday, "Breaking the surfing lull" (via proxy) |
| Waves per set: "Sets usually consist of three to six waves, although the number can vary … it can't be scientifically proven that the number is three, five or seven. Some sets have two waves, others have eight." | Surfertoday (via search snippet); Science of Surfing, "Why do waves come in sets?" ("Some sets have two waves, others have eight") |
| "Long-travelled swell … is often less consistent than short-period wind swells." | Surfline forecasting tutorial on wave period (search snippet) |
| Recreational surfers: 20.6 ± 11.4 rides per hour; 41.6–41.8 % of session time waiting (≈ 25 min per hour), 47 % paddling, 8 % riding. 39 surfers, 60 sessions, GPS. | Barlow et al. 2014, J. Strength Cond. Res. (via PMC systematic review PMC11174645 and search abstracts) |
| Amateur surfers, 2-h training session: ≈ 30 rides/hour, 52.8 ± 12.4 % stationary. | Secomb et al. 2015 (via PMC11174645) |
| Competitive heats (20 min): 2.2–7.7 waves per heat; 42 % (23–72 %) stationary; 5 rides per heat on average. | Farley et al. 2018; Mendez-Villanueva et al. 2006 (via PMC11174645 / search abstracts) |
| Southern-California recreational surfers: ≈ 55 % stationary, ≈ 32 % paddling — more waiting than earlier literature (~38 %). | LaLanne et al. 2017, J. Aging Phys. Act. (PDF text-extracted locally) |

What this means in plain terms: a surfer is "waiting" roughly 25–33 minutes of every hour already, and rides about 20 waves/hour on an ordinary day. A set every 2–6 minutes delivering 3–6 waves (one or two of which are yours in a crowd) sustains that rate with rest in between; sets every 10 minutes roughly halve the opportunity; beyond 15 minutes the wait itself becomes the complaint; beyond 30 minutes the session is "lully" by every source. Under about a minute there are no discernible sets — waves keep coming (fine for opportunity, no rest or positioning rhythm; still rideable, which Size/Shape/Power judge, not this term).

### 3.2 Proposed graded timing curve (judgement anchored on §3.1)

**Interval curve `f_int(T_set)`** — T_set in minutes, piecewise-LINEAR between knots (no steps):

| T_set (min) | f_int | Why (plain English) | Basis |
|---|---|---|---|
| ≤ 1 | 0.80 | No discernible sets — continuous train. Plenty of waves, no rhythm, no rest. Not penalised hard because rideability is scored elsewhere (operator ruling). | Judgement; Padang Padang "break in quick succession" |
| 2 | 1.00 | Frequent, still grouped. | Judgement (lower edge of "a few minutes") |
| 6 | 1.00 | Top of the comfortable band — "5 to 10 minutes … time to rest or position"; "every 5 minutes with 10 waves" is the good example. | Padang Padang; Surfline |
| 10 | 0.85 | Still the groundswell norm, but half the opportunity of 5 min. | Padang Padang upper bound |
| 15 | 0.60 | "Fifteen or more" is where sources stop calling it normal; "every 15 minutes with one or two waves" is the poor example. | Surfertoday; Surfline |
| 20 | 0.40 | "15 or 20 minutes for a decent set wave that never comes" — the frustration quote. | Surfertoday lull article |
| ≥ 30 | 0.25 | "Half an hour or more" — the bad tail. Not zero: a set does still come, and the factor's weight (0.10) already caps its damage. | Surfertoday |

**Waves-per-set curve `f_wps(N_set)`** — N_set = expected waves above Hs per set, piecewise-linear:

| N_set | f_wps | Why | Basis |
|---|---|---|---|
| 1 | 0.60 | "One or two waves" per set is the poor example. | Surfline |
| 2 | 0.75 | | interpolation |
| 3–6 | 1.00 | "Usually three to six." | Surfertoday; Science of Surfing 2–8 |
| 8 | 0.95 | "Others have eight" — still good. | Science of Surfing |
| 10 | 0.90 | "10 waves in each set" is the good example but a big set is a long paddle-out/clean-up. | Surfline |
| ≥ 14 | 0.80 | Sets this long are the continuous regime again. | Judgement |

**Timing sub-score** `timing = 0.7 × f_int + 0.3 × f_wps` (judgement: the interval is what every source talks about first; waves-per-set is the secondary qualifier).

### 3.3 How the interval and waves-per-set are obtained from OUR data

All inputs exist every forecast hour (yesterday's brief §4): the 2-D sea-swell spectrum at the 15 m point (`swan_runner._compute_15m_point` SPECOUT — the same array that forces SurfBeat), the partition list (`multiSwell` / SWAN PT*), and per-partition SwellTrack break results. Nothing new has to be run.

**Step 1 — pick the swell whose sets are being scored.** The dominant partition (same D1 dominant-selection rule Power uses; reading the same partition index is not a second use of a measurement). Restrict the spectrum to that partition's frequency band: `S_dom(f)`. Reason: the surfer's "set" is the set of the swell being ridden; the other partitions are the filler between sets (§4), and mixing them into one bandwidth number destroys exactly the structure we want (a narrow 15 s swell plus a 7 s windsea has a broad TOTAL spectrum but still arrives in well-defined sets).

**Step 2 — group statistics of the dominant partition.** Two equivalent routes; both are 40-year-old theory, both computable from `S_dom(f)`:

- *Envelope route (Longuet-Higgins 1984, spectral width ν).* `ν = sqrt(m0·m2/m1² − 1)` over the partition band, `Tm = m0/m1` (Tm01) . With threshold ρ = H*/H_rms and "set wave" = H > Hs (ρ = √2): expected waves per set `N_set ≈ 1/(√(2π)·ν·ρ)`, expected repetition (start of one set to start of the next) `N_rep ≈ e^{ρ²}/(√(2π)·ν·ρ)` waves. Set interval `T_set = N_rep × Tm`. Examples: ν = 0.10, Tm = 13 s → N_rep ≈ 21 waves ≈ 4.5 min, N_set ≈ 2.8; ν = 0.20 → ≈ 10 waves ≈ 2.3 min; ν = 0.05 (very clean long-travelled swell) → ≈ 42 waves ≈ 9 min. **Caveat carried from yesterday's brief §8: the exact textbook form of these two expressions was not re-verified against the 1984 paper this session — verify (Holthuijsen 2007 / Royal Society paper) before coding.**
- *Markov route (Kimura 1980 ICCE ch. 178, verified from the paper text this session).* Successive wave heights form a Markov chain whose transition matrix comes from the bivariate Rayleigh distribution with correlation parameter κ (Kimura eqs. 4–6, 12). Mean run of high waves `N_set = 1/(1 − p22)` (eq. 16); mean total run (set + lull) `N_rep = 1/(1 − p11) + 1/(1 − p22)` (eq. 19). p11, p22 are 2-D integrals of the bivariate Rayleigh (Bessel I₀) — trivial numerically. Kimura's own check against 5000-wave simulations at threshold Hs: N_set 1.28–1.53 waves and N_rep 9.3–10.7 waves as the successive-height correlation γ_h rises 0.19 → 0.38 (Tables 1–2), i.e. the theory reproduces data to within a few percent. κ itself is obtained from the spectrum as the modulus of the spectrum's autocorrelation at one mean-period lag (Battjes & van Vledder 1984, "Verification of Kimura's theory"; Longuet-Higgins 1984 showed the two routes agree for narrow spectra — yesterday's brief §2.2). Kimura also shows γ_h is set by Goda's peakedness Qp (his Fig. 15) — so Qp is an acceptable substitute for ν.

Either route turns the dominant partition's spectrum into (T_set, N_set). Kimura's numbers make one thing plain: at threshold Hs a broad-ish spectrum gives sets every ≈ 10 waves (≈ 1–2 min) — that is the wave-GROUP scale, and it is where SurfBeat's peak also sits (§5). Minutes-scale set intervals need a NARROW partition (ν ≲ 0.1) or the two-swell beat below. That is not a defect of the method; it is the physics — sets 5–10 min apart are what a clean, far-travelled swell produces, and the curve in §3.2 rewards exactly that.

**Step 3 — two-swell beat override.** If the second partition holds ≥ 25 % of total partition energy (judgement threshold) and the two peak periods are close, `T_beat = 1/|1/Tp₁ − 1/Tp₂|` (14 s + 15 s → 210 s; 12 s + 16 s → 48 s — yesterday's brief §2.3). If 60 s ≤ T_beat ≤ 1800 s, `T_set = max(T_set, T_beat)` and N_set = T_beat / (2·Tm) rounded (half the beat is the "high" half). Physics source: Science of Surfing; Coastal Wiki "Infragravity waves" (group period = 1/Δf).

**Step 4 — SurfBeat cross-check (optional, logged only).** T_ig (seconds) should be of the order of the group-scale `N_rep × Tm` from step 2 when the spectrum is broad; log the ratio. See §5.

**Step 5 — score.** `timing = 0.7 × f_int(T_set/60) + 0.3 × f_wps(N_set)`.

Fallback when no spectrum: keep the existing `swellDominance` rule for the WHOLE factor (unchanged; yesterday's D7 note stands — its numbers are uncited but it is not in scope today).

---

## 4. Set amplitude ("set strength") from SwellTrack + the spectrum

### 4.1 What SwellTrack and the spectrum actually give us per hour (inventory)

From `surf_1d_pipeline.py` / `surf_1d_analytical.py` docstrings:

| Quantity | Where | Meaning |
|---|---|---|
| `PartitionBreakResult.hs_at_break_m` (per partition × transect) | pipeline :163–165 | Hs of THAT swell partition at its primary break point, after the 1-D transformation (shoaling, refraction, Battjes-Janssen breaking, DDD decay). |
| `PartitionBreakResult.face_height_m` = 1.27 × Hs_break | :157–161; `breaker_height.hsig_to_face_height` :160–171 | H1/10 face — "the set waves surfers observe at the break" (the code's own words). This IS Size's input. |
| `TransectResult.hs_total_profile` | :197–198 | RSS-combined, depth-limited Hs at every profile point — the combined sea. |
| `PartitionBreakInfo.mean_face_height_m`, `peak_face_height_m`, `height_m` (handoff Hs), `classification` | :285–302 | Per-partition aggregates across transects. |
| `PipelineResult.main_zone_face_height_m`, `spot_average_face_height_m`, `peel_angle_deg` | :371–378, :433–441 | Headline numbers (Size / Shape inputs). |
| 2-D spectrum at the 15 m point | `swan_runner._compute_15m_point` | m0, m1, m2, ν, Qp, κ per partition band. |

Not produced: any time series, any envelope, any per-wave height. So "set-wave height vs between-set height" has to be STATISTICAL — built from Hs values and the spectrum's group statistics.

### 4.2 The constraint the physics imposes (why "set amplitude" cannot be a height)

Individual wave heights in a sea state follow the Rayleigh distribution: H1/3 = Hs = 1.414 H_rms, H1/10 = 1.80 H_rms = 1.27 Hs, mean H = 0.886 H_rms (USNA EN330 note; Coastal Wiki; the 1.27 already in `breaker_height.py`). For a single swell, the mean height of the waves ABOVE H_rms (the "set" waves) is 1.38 H_rms ≈ 0.98 Hs and the mean height of the waves BELOW H_rms (the "lull" waves) is 0.60 H_rms ≈ 0.42 Hs — both constants (computed from the Rayleigh conditional means; arithmetic in this brief, not a cited number). So the ratio set-wave/lull-wave for one swell is ≈ 2.3 on EVERY day — it carries no information about set definition, and scaling it by Hs just re-scores Size (yesterday's D3, and the single-use rule).

What DOES vary from day to day, and is what a surfer means by "strong, well-defined sets":

1. **Coherence — do big waves come together?** Kimura's Fig. 2: the expected height of the wave FOLLOWING a wave of height h₁ depends on the successive-height correlation; with zero correlation the next wave is always the same average height (√2/2 · H_rms) regardless of h₁, with high correlation it approaches h₁ — i.e. the set holds its size. That correlation is κ (§3.3), computable from the spectrum. A narrow swell has high κ (sets arrive as coherent blocks); a broad windsea has low κ (big waves scattered singly — "sets blur").
2. **The lull floor — what is breaking BETWEEN the sets?** With one swell the floor is that swell's own low run (≈ 0.42 Hs). With a second partition in the water, its waves fill the lull ("filler waves" — Swellnet, yesterday's brief §3). SwellTrack gives each partition's Hs AT THE BREAK, so the filler's contribution is an output we already compute, transformed through the same bathymetry as the dominant swell.

### 4.3 Definitions and formula

Per forecast hour, on the main break zone (use the same transects that build `main_zone_face_height_m`):

- **Set-wave face height** `H_set = 1.27 × Hs_total,break` — the H1/10 face of the combined sea at the break. This is literally SwellTrack's `face_height` (Size's input). Consistency uses it ONLY in a ratio (below); the absolute value is never scored here.
- **Between-set face height** `H_lull = sqrt( (0.42 × Hs_dom,break)² + (0.63 × Hs_rest,break)² )` — the dominant swell in its low run (Rayleigh conditional mean below H_rms = 0.42 Hs) combined in energy with the MEAN wave of the remaining partitions (0.886 H_rms = 0.63 Hs), which are not grouped in step with the dominant swell and so fill the lull at their typical height. `Hs_rest,break = sqrt(Hs_total,break² − Hs_dom,break²)`. The two Rayleigh factors are exact for their conditional means; the energy combination is an approximation (judgement, labelled).
- **Contrast** `C = 1 − H_lull/H_set`. Pure single swell: H_lull/H_set = 0.42/1.27 = 0.33 → C = 0.67 (the maximum). All filler, no dominant swell (Hs_dom → 0): H_lull = 0.63 Hs_total → C = 0.50 (the minimum). Equal-energy two-swell day (Hs_dom = Hs_rest = 0.71 Hs_total): H_lull = 0.535 Hs_total → C = 0.58. Dominant swell 30 % of break energy: C = 0.55. The physical range is narrow (0.50–0.67) because the filler's typical wave is not far above the dominant swell's own lull floor — so normalise: `C' = (C − 0.50)/0.17`, in 0–1 (pure swell 1.0; equal two-swell 0.47; 30 % dominant 0.29).
- **Set-strength index** `S = 0.4 × C' + 0.6 × κ_dom` (weighted arithmetic blend, per the within-component rule; weights are judgement — coherence is weighted higher because a single broad windsea has C' = 1 by construction (no filler) yet its sets are incoherent, and κ is what separates it from a clean swell). Examples: clean swell, κ 0.8, no filler → S = 0.88; equal two-swell, κ 0.5 → 0.49; single windsea, κ 0.2 → 0.52; broad swell plus windsea, κ 0.3, C' 0.3 → 0.30.

**Amplitude sub-score `f_amp(S)`** (judgement; the literature gives direction and the Rayleigh anchors, not a surf-quality mapping — say so in the explainer):

| S | f_amp | Plain English |
|---|---|---|
| ≥ 0.85 | 1.00 | Clean single swell, coherent sets, flat lulls — the classic "sets stand up out of nothing" day. |
| 0.65 | 0.90 | Well-defined sets with some filler. |
| 0.45 | 0.75 | Two-swell day or broad swell: sets visible, lulls busy. |
| 0.25 | 0.60 | Sets barely distinguishable from the background. |
| ≤ 0.10 | 0.50 | No set structure (continuous windsea or scattered singles). Floor 0.5, not 0: a continuous train is still surf, and rideability is scored elsewhere (operator ruling). |

Piecewise-linear between knots.

### 4.4 Why not the IG height

- It is size-confounded: bound-IG height ∝ Hs², free IG ∝ Hs (Lange et al. 2024; Frontiers 2025; yesterday's brief §2.4) — the 0.05/0.15/0.30 m bands reward a big day for being big (double-counts Size).
- It is a model quantity that omits most of the real IG field (bound fraction < 30 % in moderate seas — Lange 2024; Herbers et al. 1994; SWAN's own authors on the missing free IG — Reniers et al. ICCE).
- It measures the surf-zone long-wave energy (swash, rip forcing), not how much bigger the set waves are than the lull waves. Our own 1-D model gives the per-partition break heights that question actually needs.

### 4.5 Single-use flags (operator ruling required — not resolved here)

1. `Hs_dom,break / Hs_total,break` (at-the-break partition share) is a DIFFERENT measured quantity from Power's deep-water `multiSwell` energy share (`_ENERGY_SHARE_*`, `surf_scorer.py:340–348`) — it is SwellTrack output after refraction/breaking — but it is strongly correlated with it. Conditions' cross-swell term (secondary-vs-primary energy ratio + angle) also reads the deep-water partitions. If the operator rules this too close to a second use, drop the filler term and let `S = κ_dom` alone carry amplitude (spectrum-shape only, touches nothing else).
2. `H_set` is Size's face height. It enters only as the denominator of a ratio; the recommendation is that the ratio form is acceptable under single-use (the absolute is not scored twice), but this is a ruling, not a given.
3. `swellDominance` (energy share of > 10 s components, fallback) overlaps conceptually with κ/ν. Keep it as the no-spectrum fallback only.

---

## 5. What SurfBeat can honestly still contribute

- **What T_ig is:** the SurfBeat IEM is forced by "bichromatic wave groups related to all pairs in the sea-swell spectrum with a frequency difference ≤ fig" (SWAN manual :3968–3973, yesterday's brief §2.4). The bound-IG peak is therefore the beat period of the most energetic pair of sea-swell components within 0.005–0.040 Hz — the dominant wave-GROUP period of the forcing spectrum, 25–200 s on our 8-bin axis (`_SURFBEAT_DF_HZ = 0.005`), live 33 s (≈ 3–4 waves per group at Tp ≈ 9 s).
- **Legitimate use:** a cross-check of the group-scale number in §3.3 step 2 — for a broad spectrum `N_rep × Tm` should land in the same tens-of-seconds-to-2-minutes range as T_ig; log both and their ratio every hour. "Groups per set" `= T_set / T_ig` can be reported as a diagnostic. That is all.
- **Why it cannot give the set interval:** the minutes-scale interval is set by frequency separations of ~0.001–0.003 Hz (5–15 min beats), i.e. the fine structure WITHIN the dominant partition or between two near-equal swells. SurfBeat's axis resolves 0.005 Hz steps — anything slower than 200 s is outside the computed band, and inside it the 8 bins quantise to 200/100/67/50/40/33/29/25 s (yesterday's D5). Converting T_ig to a set interval would require assuming a number of groups per set, which is exactly the unknown. Extending `[df]` toward 0.001 Hz is an architectural change (trigger 3) and would still only give the group-forced part of the answer; §3.3 gets the same information directly from the spectrum with no extra SWAN run.
- **IG height:** display only (it is a real surf-zone quantity — swash/rip forcing), never a scoring input (§4.4).
- **Relabel:** `setTimingMinutes` → a seconds quantity named for what it is ("dominant wave-group period"), API-MANUAL :2599 text updated accordingly (yesterday's D4). A data-contract change — part of the same approved round, not a research conclusion.

---

## 6. Defects in the current code (restated from yesterday's brief §5, briefly)

| # | Defect | Where |
|---|---|---|
| D1 | Timing bands in MINUTES (3/10/20) vs a sensor that emits 25–200 SECONDS → `timing_score` = 0.8 on every day; the 1.0/0.7/0.5 bands are unreachable. | `surf_scorer.py:366–373`; `surfbeat_runner.py:1374–1432` |
| D2 | Amplitude bands 0.05/0.15/0.30 m have no cited provenance (ADR-101 :66, brief :312, S-SPEC-1). | `surf_scorer.py:376–383` |
| D3 | Absolute IG height is size-confounded (∝ Hs to Hs²) — a hidden Size bonus. | same |
| D4 | The IG peak is the within-set GROUP period, mislabelled "minutes between sets". | `SurfBeatResult` :315–324; API-MANUAL :2599 |
| D5 | 8-bin quantisation; nothing slower than 200 s is resolved. | `surfbeat_runner.py:118–123` |

Net effect today: factor ≈ 0.72 for essentially every SurfBeat hour; the factor discriminates nothing.

---

## 7. Recommendation — minimal change to the existing Consistency factor

Structure unchanged: `consistency = 0.6 × timing + 0.4 × amplitude`; weight 0.10; `swellDominance` fallback unchanged when no spectrum exists.

**New inputs (replace `setTimingMinutes`, `setAmplitudeM` as scoring inputs):**

| Input | Source | Feeds |
|---|---|---|
| `S_dom(f)` — dominant-partition band of the 15 m-point spectrum → ν (or Qp) and κ, Tm | `swan_runner._compute_15m_point` SPECOUT + partition bounds | timing (T_set, N_set), amplitude (κ_dom) |
| Tp₁, Tp₂ and energies of the top two partitions | `multiSwell` (same dominant-selection rule as Power; the second partition's period is a new read) | two-swell beat override |
| `Hs_dom,break`, `Hs_total,break` on main-zone transects | SwellTrack `PartitionBreakResult.hs_at_break_m` / `TransectResult.hs_total_profile` at the primary break | amplitude contrast C (subject to §4.5 ruling) |
| `T_ig` (s) | SurfBeat | logged cross-check only — NOT a scoring input |

**Curves:** §3.2 (`f_int`, `f_wps`, timing = 0.7/0.3 blend) and §4.3 (`f_amp` of S). All piecewise-linear; every knot carries its source or "judgement" label; the visitor explainer says the bands are operator judgement pending observation (webcam set counting — yesterday's §6.5 — remains the only direct validation).

**Doc/ADR impact (same round, doc-code sync):** ADR-101 row 5 and brief §7.2 variable inventory (new inputs above; retire the two SurfBeat fields as inputs; record the §4.5 single-use rulings); API-MANUAL §17 field rows (`setTimingMinutes` relabel); S-SPEC-1; `surf_scorer.py` consistency block + known-answer tests (fixed synthetic spectra → exact T_set, N_set, C, S, factor value). Changing which quantities feed a factor is an ADR-level change — operator approval in chat before any code moves.

**Before coding, verify:** the exact Longuet-Higgins envelope run-length expressions (or implement the Kimura route, whose equations are quoted from the paper in §3.3 and need only the Battjes–van Vledder κ-from-spectrum relation confirmed); and typical ν/κ values for a SWAN PT partition at our 15 m point (compute from a week of cached spectra — no literature value was found for partition-band ν).

---

## 8. Sources (accessed 2026-08-23)

Local:
- `docs/planning/briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md` :47–48, :97–103, :128–130, :160, :308–313.
- `docs/decisions/ADR-101-surf-score-geometric-mean.md` :66, :97–98, :109–111.
- `docs/planning/briefs/RESEARCH-SET-CONSISTENCY-2026-08-23.md` §2.2–2.4, §4, §5, §6.5, §8 (physics, IG literature, defects — reused).
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/surf_scorer.py` :340–400, :856–900.
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surf_1d_analytical.py` :1–8 (module docstring), :238–297 (`BreakPoint`, `Analytical1DResult`).
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surf_1d_pipeline.py` :1–33, :137–310, :363–509 (`PartitionBreakResult`, `TransectResult`, `PartitionBreakInfo`, `PipelineResult`).
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/breaker_height.py` :108–171 (1.27 Rayleigh H1/10 factor).
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surfbeat_runner.py` :268–369 (`SurfBeatStripConfig`, `SurfBeatResult`), :1374–1432 (`_compute_ig_set_timing`).

Web — surfer experience / sport science:
- Padang Padang Surf Camp, "Surfer's guide to wave period": https://www.balisurfingcamp.com/blog/wave-period (5–10 min groundswell set intervals)
- Surfline, "Why do waves come in sets?": https://www.surfline.com/surf-news/why-do-waves-come-in-sets/1156 (via r.jina.ai proxy; "every 15 minutes with one or two waves … every 5 minutes with 10 waves")
- Surfertoday, "Why do waves come in sets?": https://www.surfertoday.com/surfing/why-do-waves-come-in-sets (3–6 waves per set; "a few minutes to fifteen or more"; "half an hour or more" — direct fetch 403 today, quotes via search snippet and yesterday's brief)
- Surfertoday, "Breaking the surfing lull": https://www.surfertoday.com/surfing/techniques-to-minimize-waveless-periods-in-surfing (via proxy; "15 or 20 minutes for a decent set wave")
- Science of Surfing, "Why do waves come in sets?": https://www.scienceofsurfing.com/p/sets (2–8 waves per set; narrow far-travelled swell → well-defined sets)
- Surfline, "Forecasting tutorial: wave period explained": https://www.surfline.com/surf-news/forecasting-tutorial-wave-period-explained/96751 (long-travelled swell less consistent than windswell)
- Barlow et al. 2014, "The effect of wave conditions and surfer ability on performance and the physiological response of recreational surfers", J. Strength Cond. Res.: https://pubmed.ncbi.nlm.nih.gov/24736778/ (20.6 ± 11.4 rides/h; 41.6 % waiting)
- "Surfing time–motion characteristics possible to gain using GNSS: a systematic review", Sensors 2024: https://pmc.ncbi.nlm.nih.gov/articles/PMC11174645/ (table of rides/h and stationary % across Barlow 2014/2018, Secomb 2015, Farley 2018, Fernandez-Gamboa 2018)
- Mendez-Villanueva, Bishop & Hamer 2006, "Activity profile of world-class professional surfers during competition": https://pubmed.ncbi.nlm.nih.gov/16937958/
- LaLanne et al. 2017, "Characterization of activity and cardiovascular responses during surfing in recreational male surfers", J. Aging Phys. Act.: https://www.csusm.edu/surfresearch/documents/lalanne-2017.pdf (text-extracted locally)

Web — wave-group statistics:
- Kimura, A. 1980, "Statistical properties of random wave groups", ICCE ch. 178: https://icce-ojs-tamu.tdl.org/icce/article/download/3604/3286/15301 (text-extracted locally; eqs. 4–6, 12, 16, 19; Tables 1–2; Fig. 2, Fig. 15)
- Longuet-Higgins, M.S. 1984, "Statistical properties of wave groups in a random sea state", Phil. Trans. R. Soc. A 312:219–250: https://royalsocietypublishing.org/doi/10.1098/rsta.1984.0061 (abstract; envelope-theory run/repetition lengths in ν — exact form to be verified before coding)
- Masson & Chandler 1993, "Wave groups: a closer look at spectral methods", Coastal Eng.: https://www.sciencedirect.com/science/article/abs/pii/037838399390004R (abstract; Kimura-as-modified-by-Battjes; IFREMER PDF 403)
- Elgar, Guza & Seymour 1984, "Groups of waves in shallow water", JGR 89(C3):3623–3634: https://agupubs.onlinelibrary.wiley.com/doi/10.1029/JC089iC03p03623 (validity ranges of linear group theory in shallow water — citation only)
- Battjes & van Vledder 1984, "Verification of Kimura's theory for wave group statistics", ICCE — κ from the spectrum's autocorrelation at one mean-period lag (cited via Masson & Chandler and yesterday's brief; not fetched)
- USNA EN330, "Rayleigh probability distribution applied to random wave heights": https://www.usna.edu/NAOE/_files/documents/Courses/EN330/Rayleigh-Probability-Distribution-Applied-to-Random-Wave-Heights.pdf (H1/3 = 1.414 H_rms, H1/10 = 1.80 H_rms)
- Coastal Monitoring Programme wave parameter handbook (ν definition, narrow = swell / broad = windsea): https://coastalmonitoring.org/ccoresources/waveparameterhandbook/
- Coastal Wiki, "Infragravity waves" (group period = 1/Δf): https://www.coastalwiki.org/wiki/Infragravity_waves

IG literature (not re-fetched; cited as in yesterday's brief §8): Lange et al. 2024 JGR Oceans; Herbers, Elgar & Guza 1994 JPO; Reniers et al. ICCE "Modeling infragravity waves with SWAN"; Frontiers Mar. Sci. 2025; Bertin et al. 2018 Earth-Sci. Rev.

Fetch failures for the record: PubMed (cookie wall), Surfertoday ×2 direct (403; proxy succeeded for one), IFREMER Masson–Chandler PDF (403), ScienceDirect (not attempted after yesterday's 403s).
