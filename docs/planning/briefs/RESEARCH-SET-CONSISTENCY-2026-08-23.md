# Research brief — what the surf score's "Consistency" factor should be

**Date:** 2026-08-23 · **Author:** research agent (read-only) · **Trigger:** operator ruling 2026-08-23 — the consistency factor "seems completely wrong and poorly researched. It needs researched properly."
**Scope:** define the physics, survey what commercial forecasts do, inventory what our system can observe, state the current code's defects, and propose 2–3 computable candidate definitions for the operator to choose between. No repo files were modified.

---

## 1. Summary

1. Surfers' "sets" are wave groups: the beat pattern produced when wave trains of slightly different frequency superpose. The beat (group) period is `1/Δf`, where Δf is the frequency separation of the interfering trains; how pronounced the groups are ("groupiness") rises as the spectrum gets narrower. This is textbook (Longuet-Higgins; Goda; Funke & Mansard) and is also exactly what the SWAN SurfBeat module is forced by.
2. Two time scales get called "sets": (a) the wave-group scale — tens of seconds to ~3 min, a few waves per group — which is the infragravity (IG) band (25–250 s); (b) the surfer's "set interval" — typically "a few minutes to fifteen or more", 5–10 min for groundswell, up to half an hour — which sits at the lowest IG frequencies and the very-low-frequency (VLF, 4–30 min) band. The second is the low-frequency envelope of the first (several groups per "set"), and is driven by the finest frequency separations present — the bandwidth of a single far-travelled swell, or the beat between two swells of nearly equal period.
3. Our SurfBeat computes only the bound-IG spectrum on 8 uniform bins 0.005–0.040 Hz (periods 200, 100, 67, 50, 40, 33, 29, 25 s). Its peak period is therefore always between 25 s and 200 s — i.e. **always under 3.33 minutes** — and today reads 33 s.
4. The current code scores `setTimingMinutes` on bands at 3 / 10 / 20 **minutes**. With the physics delivering 0.4–3.3 min, the timing sub-score is pinned at 0.8 forever; the 1.0 band (3–10 min) is unreachable; the 0.7 and 0.5 bands are unreachable. The factor therefore cannot discriminate between days at all on timing.
5. The amplitude bands (0.05 / 0.15 / 0.30 m absolute IG height) have no cited source anywhere in the ADR, the research brief, S-SPEC-1, or the code, and are size-confounded: IG height scales with offshore wave height (free IG ∝ Hs, bound IG ∝ Hs²), so a big day scores "consistent" for being big — double-counting Size.
6. The literature and SWAN's own authors say the bound-IG spectrum is **not** a set-interval sensor: it is the wave-group-forced response, dominated by the energetic short-wave pairs, and field studies in 10–15 m find bound IG is <30% of total IG in moderate seas — most IG is free, from remote sources, which our strip does not contain.
7. Commercial forecasts do not use IG at all. Surfline's Wave Consistency (0–100) is "how many waves will exceed a certain wave height threshold" per hour from their wave model; it explicitly says windswell scores higher than groundswell and it is "not a measure of surf quality". Surf-forecast.com's "Reliability: inconsistent / fairly consistent / consistent / very consistent" is a fixed spot-guide attribute (climatology). Swellnet describes consistency qualitatively: "The longer the wave period the further apart the individual waves and the sets are" and distant swells with no secondary swell give the fewest filler waves.
8. What we can actually compute per hour: the DWR 2-D spectrum at the 15 m point (so spectral bandwidth ν, peakedness Qp, partition count/periods/energies), Tp, and the SurfBeat bound-IG peak period + shoreline IG height. Spectral bandwidth + partition structure is the physically grounded input for "how grouped/setty is this swell"; SurfBeat IG is a secondary, model-conditional input.
9. Three candidates are proposed (§6): **A** — groupiness from spectral bandwidth (Longuet-Higgins run-length theory → expected set interval and waves per set); **B** — SurfBeat IG used correctly (seconds, not minutes; IG/Hs ratio, not absolute m; finer `[df]` to reach 200–600 s); **C** — a Surfline-style "rideable-wave rate" (fraction of waves above a threshold), which is transparent but collides with the single-use rule because it is a function of the same face height Size already scores.
10. **Recommendation:** adopt **A** as the primary definition (it is computable from data we already have every hour, follows a 50-year-old statistical theory, and does not depend on a model with known gaps), keep **B's** IG height ratio only as a capped secondary "set strength" term if SurfBeat ran, drop absolute-metre bands, and fix the units defect immediately regardless of which definition is chosen. Validation needs observations we do not yet have; the cheapest path is webcam time-lapse set counting at the configured spot (§6.5).

---

## 2. What "consistency" physically is

### 2.1 Sets are wave groups (beats)

Waves of slightly different period travelling together add and cancel alternately, so the sea surface shows a slow envelope — a run of high waves followed by a run of low waves. Surfers call the high run a "set" and the low run a "lull". The envelope period — the "beat" — is the reciprocal of the frequency difference of the interfering trains, `T_group = 1/(f₁ − f₂)`. [Science of Surfing; NC Sea Grant Coastwatch; Coastal Wiki "Infragravity waves"]

Because the envelope travels at the group velocity (half the phase speed in deep water), individual crests "appear at the back of the group, travel forward through it, and disappear off the front" — the familiar sight of the first wave of a set not being the biggest. [Science of Surfing]

### 2.2 Groupiness rises as the spectrum narrows

- "Wave groups appear more pronounced as the spectrum becomes narrow." [Saulnier et al. 2011, Ocean Eng.]
- Longuet-Higgins (1984) derived the mean number of waves in a run of high waves in terms of a single parameter, the spectral width ν = √(m₀m₂/m₁² − 1) (spectral moments mₙ = ∫fⁿS(f)df). Kimura (1980) formulated the same statistics as a one-step Markov chain on successive wave heights with correlation parameter κ; Battjes & van Vledder (1984) showed κ can be computed from the spectrum; Longuet-Higgins (1984) showed the two agree for narrow spectra. [Masson & Chandler 1993 (abstract); Mansard & Sand, ICCE 1994 ch.61, pp. 832–834]
- Goda's Groupiness Factor GF = standard deviation of the SIWEH (squared surface elevation, low-pass filtered over 2·Tp) normalised by its mean (Funke & Mansard 1979). Prototype values 0.46 ≤ GF ≤ 0.94 over six months; typhoon seas 0.44–0.96. [Mansard & Sand 1994; ASCE JWPCOE 1989 "Groupiness factor and wave height distribution"]
- Narrow-band envelope (Rice/Longuet-Higgins) result, standard textbook form (not independently verified against the 1984 paper this session — flagged): with ρ = H*/H_rms the threshold defining a "set wave", mean run length above the threshold ≈ `1/(√(2π)·ν·ρ)` waves, and mean repetition length (start of one run to the start of the next) ≈ `e^{ρ²}/(√(2π)·ν·ρ)` waves. Example: swell with ν = 0.20, Tm02 = 13 s, set wave = H > Hs (ρ = √2): run ≈ 1.4 waves above Hs, repetition ≈ 10 waves ≈ 130 s. For ν = 0.35 (mixed windsea) repetition ≈ 6 waves ≈ 50 s at Tm02 = 8 s. This matches the surfers' picture qualitatively — narrow swell = fewer, better-defined, more widely spaced sets — and is the quantitative hook for Candidate A.

### 2.3 Reconciling "tens of seconds" with "minutes"

- Surfer/forecaster reports: sets "every 15 minutes with 1–2 waves" vs "every 5 minutes with ~10 waves per set" [Surfline, "Why do waves come in sets?"]; "the interval between sets varies from a few minutes to fifteen or more"; groundswell "intervals of 5 to 10 minutes" [Surfertoday; Rapture; Mundo Surf]; "normally a few minutes … but could take half an hour or more" [Surfertoday].
- Physics: a 5-minute set interval is a 0.0033 Hz beat — i.e. two interfering components 0.0033 Hz apart. Examples: swells of 14 s and 15 s peak period beat at 1/(1/14 − 1/15) = 210 s = 3.5 min; 12 s and 16 s beat at 48 s. A single, far-travelled narrow swell has its energy within a few thousandths of a Hz and so produces long, slow envelopes; a local windsea is broad and produces short, blurred groups ("sets blur together"). [Science of Surfing; Surfertoday "how swells propagate, disperse and group"]
- Scale naming in the coastal-engineering literature: rip-current and surf-zone flow studies partition motions into the IG band (25–250 s) and a **very-low-frequency (VLF) band of 4–30 min** [Bertin et al. 2018, Earth-Sci. Rev., §on rip currents]. The surfer's "set interval" of minutes therefore lives in the lowest IG decade and the VLF band — not at the IG spectral peak (25–50 s), which is the within-set group scale.
- Conclusion: a "set" as surfers use the word is usually several wave groups, i.e. the envelope of the group envelope. A bound-IG peak of 33 s describes the **within-set group period** (≈3–4 waves per group at Tp ≈ 9 s), not the minutes-scale set interval.

### 2.4 Infragravity waves and the bound long wave

- IG waves: surface gravity waves of period 25–250/300 s (0.003/0.004–0.04 Hz). [Coastal Wiki; Bertin 2018; Lange 2024 uses 0.004–0.04 Hz]
- The bound long wave exists because larger waves in a group carry more momentum (radiation stress): water level is depressed under the big waves and raised under the small ones; this oscillation is locked to the group, travels at the group velocity, is 180° out of phase with the envelope, and **its period equals the group period 1/(f₁ − f₂)**. [Coastal Wiki; Biésel 1952; Longuet-Higgins & Stewart 1962; Hasselmann 1962 — via Coastal Wiki and Bertin]
- In the surf zone the short waves break, the group structure disappears, and the bound waves are released as free IG waves that propagate shoreward, reflect at the shoreline and form (partially) standing patterns. [Coastal Wiki; Reniers et al. ICCE]
- Regimes: mild-slope regime (normalised bed slope β_b = (h_x/ω)√(g/h) ≲ 0.3) — bound-wave shoaling dominates; steep-slope (β_b ≳ 1) — breakpoint forcing dominates. Reflection: β_H = (h_x/ω)√(g/H); large reflection for β_H > 1. [Bertin 2018 Eqs. 2 and 6; Battjes et al. 2004]
- Field scaling (two Southern California beaches, 10 and 15 m depth, 2019–2022): IG band 0.004–0.04 Hz; bound-wave fraction of IG energy <30% for moderate/low sea-swell, only 5% of records have bound fraction >50%; bound energy ∝ E_SS², free energy ∝ E_SS with free-IG parameterisation E_free = 0.00067·σ̃·∫_SS E(f)f⁻¹df (R² = 0.90). [Lange et al. 2024, JGR Oceans]
- Herbers, Elgar & Guza (1994): forced (bound) IG is <0.1% to ~30% of total IG on the shelf, largest when IG is largest. [Scripps abstract]
- A six-month AWAC deployment (23.7 m and 12.2 m): bound-IG height ∝ H_swell^2.0; total IG height ∝ swell height^1.0; IG correlates >0.8 with swell, less with windsea. [Frontiers Mar. Sci. 2025]
- SWAN's own authors: the SurfBeat (IEM) module predicts the wave-group-forced IG only; in their Sand Engine comparison "the total observed incident IG wave height is underestimated by the SWAN-SB predictions … explained by the missing contribution of the incident FIG [free IG] waves due to remote sources and local refractive trapping." [Reniers et al., ICCE abstract "Modeling infragravity waves with SWAN"]

**Take-away for us:** the bound-IG spectral peak is a legitimate proxy for the *dominant group period* of the incoming sea-swell spectrum (that is literally what the IEM is forced by — "bichromatic wave groups related to all pairs in the sea-swell spectrum with a frequency difference less or equal to fig", SWAN manual :3968–3973). It is **not** a measurement of minutes-scale set intervals, and its shoreline height is a model quantity that omits most of the real IG field.

---

## 3. What commercial forecasts do

| Product | What "consistency" is | Inputs | Scale | Source |
|---|---|---|---|---|
| **Surfline "Wave Consistency"** (Labs graph, paid tiers) | "A metric to help you determine when it will be pumping or lully … how regular the set waves are at a specific spot … how 'setty' the surf will be and how many waves there will be in a set." Mechanically: the LOTUS wave model "predicts how many waves will exceed a certain wave height threshold for that spot. The higher the score, the more often that threshold has been exceeded (more sets)." | Modelled wave-height distribution per hour vs a spot threshold. No IG, no set timing. | 0–100; 20 = "slow or lully", 80 = "consistent — more waves, but a trickier paddle out". Caveats in their own words: "not a measure of surf quality"; poor windswell days score higher than groundswell; flat days can score high because the threshold adjusts. | support.surfline.com article 20350539606683 (fetched via proxy 2026-08-23) |
| **Surf-forecast.com** | Star rating (1–10) is swell size + period, cut by onshore wind — no consistency term (FAQ). Break guide shows **"Reliability: inconsistent / fairly consistent / consistent / very consistent"** — a fixed climatological spot attribute, not hourly. | Spot guide | categorical | surf-forecast.com FAQ; break page "Magics" |
| **Magicseaweed** (now folded into Surfline) | Historic spot-guide "consistency" was the same climatological idea; no hourly consistency forecast documented. | — | — | search only; no primary page found |
| **Swellnet** | No numeric consistency product found. Editorial: "The longer the wave period the further apart the individual waves and the sets are" — long-period groundswell is well-formed but inconsistent; swell generated nearer the coast is "more consistent, less waits between sets and … a lot more filler waves in between"; "the further away the swell is generated, the less consistent and with no other swells in the water, the less filler waves." | Swell period, source distance, presence of secondary swells | qualitative | Swellnet "Know your product: wave period"; Swellnet forum thread 550786 (search snippet) |

Observations: (1) the only quantified commercial metric (Surfline) is a **wave-count rate above a threshold**, i.e. "rides per hour", and is deliberately decoupled from quality; (2) every qualitative source ties consistency to **swell period, bandwidth/source distance, and number of swells** — the same three things that set spectral bandwidth; (3) nobody uses IG waves.

---

## 4. What our model can observe, per forecast hour

| Quantity | Where it comes from | Status |
|---|---|---|
| DWR 2-D spectrum E(f,θ) at the 15 m-contour point (the strip's own west boundary) | `swan_runner._compute_15m_point` SPECOUT; handed to SurfBeat as `boundary_freqs_hz/dirs/energy` | Available every hour (this is what forces SurfBeat). From it: m₀, m₁, m₂ → Longuet-Higgins ν; Goda Qp = (2/m₀²)∫fS²df; Tp, Tm01, Tm02; DSPR. **Not currently reduced to ν/Qp anywhere** (grep: no spectral-width computation in `swan_spectral.py`). |
| Partition list `multiSwell` (count, period, direction, energy, height) | SWAN TABLE PT* watershed partitions (`parse_table_pt_partitions`) | Available; already feeds Power and the Consistency fallback (`swellDominance` = energy share of components with period > 10 s). |
| `setTimingMinutes` = 1/f_peak of the bound-IG spectrum at the shore station | SurfBeat SPECOUT L, first COMPUTE block, 8 uniform bins 0.005–0.040 Hz (`_SURFBEAT_DF_HZ = 0.005`, `_IG_SPLIT_HZ = 0.04`) | Available when SurfBeat ran. **Quantised** to 200/100/66.7/50/40/33.3/28.6/25 s; always 0.42–3.33 min. Live 2026-08-23: 33 s. |
| `igWaveHeightM` / `setAmplitudeM` = √(Hbig² + Hsig_free²) at the shore station | SurfBeat TABLE | Available when SurfBeat ran. Live: 0.125 m against boundary Hs 0.55 m (ratio 0.23). Bound-only forcing, alongshore-uniform strip, REFL 0.5 — no remote free IG. |
| `breakingFaceHeight`, Hs_total at break | SwellTrack 1-D | Available; already the Size input (single-use constraint). |
| Boundary Hs, mean direction | SurfBeat diagnostics (`boundaryHsM`, `boundaryDirDeg`) | Available. |

Not observable: actual set arrivals, waves per set, or any IG/VLF measurement at the spot — no nearshore pressure sensor, and standard wave buoys (NDBC/CDIP Datawell) report spectra only down to ~0.02–0.025 Hz (40–50 s), which does not cover the IG band, let alone VLF (to confirm per station).

---

## 5. Current implementation and its defects

Source: `surf_scorer.py` :340–400 and :856–900; spec provenance S-SPEC-1 (`EYEBALL-FIX-PLAN-2026-08-04.md` :69) and ADR-101 row 5; research basis `SURF-SCORE-REBUILD-RESEARCH-BRIEF.md` §1/§7.2 (:97–103, :308–313).

`consistency = 0.6 × timing_score + 0.4 × amplitude_score` when SurfBeat produced either value; else `swellDominance` fallback (≥0.8→0.9, 0.5–0.8→0.7, <0.5→0.4, null→0.5).

| # | Defect | Evidence | Effect |
|---|---|---|---|
| D1 | **Units mismatch — timing bands in minutes, physics in seconds.** `_score_set_timing`: <3 min→0.8; 3–10→1.0; 10–20→0.7; >20→0.5. SurfBeat can only emit 25–200 s (0.42–3.33 min) because the bound-IG axis is 0.005–0.040 Hz. | `surf_scorer.py:366–373`; `surfbeat_runner.py:104,123,1374–1432`; live 33 s | timing_score = 0.8 **always** (3.33 min exactly would hit 1.0 only at the 200 s bin). The sub-score carries zero information; the factor is capped at 0.6×0.8+0.4×1.0 = 0.88; the 1.0/0.7/0.5 bands are dead code. |
| D2 | **Amplitude bands (0.05/0.15/0.30 m) have no cited provenance.** ADR-101 row 5 says only "SurfBeat set timing/amplitude"; the research brief §7.2 says "Set definition/strength"; S-SPEC-1 :69 states the numbers with no source; the code comment says "S-SPEC-1 gives its own exact bands here". No literature, no field value, no worked example. | ADR-101 :66; brief :312; EYEBALL-FIX-PLAN :69; `surf_scorer.py:364–383` | Arbitrary. |
| D3 | **Absolute IG height is size-confounded.** Field scaling: free IG energy ∝ sea-swell energy, bound ∝ energy² (Lange 2024; Frontiers 2025). So a 2 m day scores "consistent" simply for being big — **double-counts Size**, against ADR-101's single-use/non-compensability intent. | §2.4 cites | Factor rewards size, not set structure. |
| D4 | **What the IG peak measures is mis-labelled.** Docstrings/API-MANUAL call it "minutes between sets"; physically it is the dominant wave-group period (within-set), and the IEM's authors state SurfBeat captures wave-group-forced IG only. | API-MANUAL :2599; `surfbeat_runner.py:315`; ICCE abstract | Conceptual error, not just a unit error — even with seconds, a 33 s peak ≠ a set interval. |
| D5 | **Quantisation.** With `[df] = 0.005` uniform, only 8 possible timing values; the lowest resolvable period is 200 s. The minutes-scale set band (200–1800 s) is outside the computed axis entirely. | `surfbeat_runner.py:118–123`; SWAN manual :3986–3999 | Coarse, and blind exactly where surfers' "set interval" lives. |
| D6 | **Partial-data neutral 0.5** for timing-or-amplitude-missing is "by convention" (code comment), not justified. | `surf_scorer.py:359–362` | Minor. |
| D7 | **Fallback is a different concept.** `swellDominance` (energy share of >10 s components) is a swell-vs-windsea purity ratio; it is a reasonable crude proxy for bandwidth (purer swell → narrower → groupier) but the three thresholds (0.8/0.5) and scores (0.9/0.7/0.4) are uncited and, as the ADR notes, carried from an older "organization" composite. | `surf_scorer.py:386–391, 856–868` | Works only as long as SurfBeat is off; is arguably a *better* signal than the live path today. |
| D8 | **Semantic ambiguity never settled.** "Consistent" can mean (i) many rideable waves per hour (Surfline; windswell scores high) or (ii) well-defined, regularly spaced sets (surfer usage; groundswell scores high). The two are close to opposites on the bandwidth axis. Neither ADR-101 nor S-SPEC-1 states which is intended. | brief :97–103; Surfline page | Cannot author a correct curve without this ruling. |

Net: today the factor returns 0.6×0.8 + 0.4×0.6 = **0.72** for 33 s / 0.125 m, and would return 0.72 for almost any day with SurfBeat running and IG under 0.15 m; 0.80 at 0.15–0.30 m; 0.88 at ≥0.30 m — a thinly disguised size bonus.

---

## 6. Candidate definitions

All three keep the factor in 0–1, feed the geometric mean with weight 0.10 (unchanged), and state what they need. Bands marked *(judgement)* are proposals for operator calibration, not literature values — the literature gives the *direction* and the *scale* but no surf-quality mapping exists anywhere.

### Candidate A — Groupiness from the DWR spectrum (recommended)

**Idea:** consistency = how regular and well-defined the set structure is, computed from the sea-swell spectrum we already have at the 15 m point, using the Longuet-Higgins/Kimura narrow-band group statistics (§2.2).

**Inputs (all available hourly):** omnidirectional sea-swell spectrum S(f) (0.04–1.0 Hz, same cut as SurfBeat's `fig`), Tm02, spectral width ν = √(m₀m₂/m₁² − 1), partition list.

**Computation:**
1. `nu = sqrt(m0*m2/m1**2 - 1)` over the sea-swell band (or Goda's Qp; either is fine — ν is the one the group-statistics theory is written in).
2. Expected set repetition, in waves, with "set wave" = H > Hs (ρ = √2): `N_rep = exp(2) / (sqrt(2*pi) * nu * sqrt(2)) ≈ 2.08 / nu`; expected waves per set above Hs `N_run ≈ 0.28 / nu`.
3. Expected set interval `T_set = N_rep × Tm02` seconds; expected set rate = 3600 / T_set per hour.
4. Two-swell override: if the top two partitions each hold ≥ 25 % of total energy *(judgement)*, compute the beat `T_beat = 1 / |1/Tp₁ − 1/Tp₂|`; if 60 s ≤ T_beat ≤ 1800 s use `T_set = max(T_set, T_beat)` — two near-equal swells produce long, slow sets.
5. Score = `0.6 × regularity_score(T_set) + 0.4 × definition_score(nu)`:
   - `regularity_score` *(judgement, anchored on §2.3 reports: 5–10 min "groundswell" sets, 15 min+ "long lulls")*: T_set ≤ 120 s → 0.9 (continuous, little definition); 120–300 s → 1.0; 300–600 s → 0.8; 600–900 s → 0.6; > 900 s → 0.4.
   - `definition_score` (narrowness): ν ≤ 0.25 → 1.0; 0.25–0.35 → 0.8; 0.35–0.5 → 0.6; > 0.5 → 0.4 *(judgement; ν ≈ 0.2 typical clean swell, ≈ 0.4–0.5 fully developed windsea — cite for these typical values still needed)*.
   - If the operator rules for the Surfline semantic (D8-i, "more rideable waves = more consistent"), invert `regularity_score` so short T_set scores highest and drop `definition_score` weight to 0.2.

**Why:** uses the quantity the physics and every qualitative forecaster name (bandwidth, number of swells, period), needs no SurfBeat, is monotone and explainable ("a narrow 15 s swell arrives in well-spaced sets; a broad windsea arrives continuously"), and does not touch Size.
**Single-use check:** ν, Tm02 and partition energies would be new scoring inputs; `swellDominance` (energy share > 10 s) overlaps conceptually with ν — retire the fallback or make ν the only bandwidth proxy.
**Cannot be validated without observations:** the N_rep formula is narrow-band theory; real set statistics at a given beach also depend on refraction focusing and bathymetry (Surfline article). Validate per §6.5.

### Candidate B — SurfBeat IG, used correctly

**Idea:** keep the IEM output as the sensor, but score the physics it actually provides.

**Inputs:** bound-IG spectrum peak period T_ig (s), Tp (s), `igWaveHeightM`, `boundaryHsM`.

**Computation:**
1. Fix units: work in seconds. Waves per group `n_g = T_ig / Tp` (33 s / 9 s ≈ 3.7 today).
2. Extend the IG axis so the 200–600 s envelope band is resolved: `SURFBEAT [df]` 0.005 → 0.0017 Hz (or LOGARITHMIC) — **architectural (trigger 1/3: changes the model's spectral extent) — operator approval required**; without it the range stays 25–200 s.
3. `group_score(n_g)` *(judgement)*: n_g 3–6 → 1.0 (classic "3–6 waves per set"), 2–3 → 0.8, 6–10 → 0.8, < 2 or > 10 → 0.5.
4. `strength_score(r)` with `r = igWaveHeightM / boundaryHsM` (ratio, not metres — removes the size confound): r < 0.10 → 0.6; 0.10–0.25 → 0.8; 0.25–0.40 → 1.0; > 0.40 → 0.8 (IG-dominated surf zone — "surfbeat" swash, not clean sets) *(judgement; live 0.23)*.
5. Score = 0.6 × group_score + 0.4 × strength_score.

**Why:** physically honest about what the IEM gives (dominant group period and group-forced IG energy).
**Against:** still not a set-interval sensor; omits free IG (most of the real IG field per Lange 2024/Herbers 1994); quantised; depends on strip assumptions (alongshore uniform, REFL 0.5); costs a SWAN run per hour. Literature gives no mapping from IG ratio to surf quality — the strength bands are pure judgement.

### Candidate C — Surfline-style rideable-wave rate

**Idea:** consistency = fraction (or count per hour) of waves whose face exceeds a rideable threshold, from the Rayleigh distribution around the modelled face height: `P(H > H_thr) = exp(−(H_thr/H_rms)²)`, waves/hour = 3600/Tm02 × P.

**Why:** exactly what the one quantified commercial metric does; trivially explainable.
**Against:** it is a function of `breakingFaceHeight` and Tm02 only — **violates the single-use rule** (Size already scores face height) and, as Surfline itself says, is "not a measure of surf quality" and scores windswell above groundswell. Listed for completeness; not recommended.

### 6.5 Validation plan (applies to A and B)

- **Webcam time-lapse set counting** at the configured spot (the project already has a webcam bind-mount on weather-dev): count set arrivals and waves per set per hour for ~2 weeks spanning a groundswell and a windsea; compare with predicted T_set / N_run (A) and with T_ig, n_g (B). This is the only direct test of the thing being scored.
- **Buoy cross-check of bandwidth:** CDIP/NDBC spectral products give ν/Qp offshore; confirm our 15 m-point ν tracks the buoy's ν (validates the input to A, not the set statistic).
- **IG cross-check (B only):** requires a nearshore pressure sensor/ADCP (Lange 2024 used 10 and 15 m deployments). No public real-time IG product exists at the spot; standard buoys stop at ~0.02–0.025 Hz. Without this, B's height term cannot be validated.
- **Operator eyeball gate:** ADR-101's worked-examples gate applies — publish factor values for a narrow 15 s swell, a two-swell day, a windsea day, and today's live hour before merging.

---

## 7. Recommendation

1. **Immediately (any definition):** stop scoring `setTimingMinutes` on a minutes scale — the sub-score is constant. Either convert to seconds with bands in the 25–200 s range or (better) stop using the IG peak as "set interval" at all (D1, D4). Retire absolute-metre amplitude bands (D2, D3).
2. **Rule the semantic (D8) first:** "well-defined, regularly spaced sets" (surfer usage, groundswell high) vs "many rideable waves per hour" (Surfline, windswell high). Recommendation: the former — it is what the ADR's own rationale ("regular, predictable sets give more ride opportunities", brief :47) describes and what the DSPR/cleanliness logic in Conditions already leans toward.
3. **Adopt Candidate A** as the definition: bandwidth-derived set regularity + definition, with the two-swell beat override. It is computable now, from data we already have every hour, on a theory base older than the ADR, with no new SWAN runs.
4. **Keep SurfBeat for display** (IG height, group period in seconds — correctly labelled) and, optionally, as a small capped secondary term in A only after the `[df]` extension is approved and a worked-example gate passes. Do not let it set the factor alone.
5. **Record the open validation debt** in the ADR: no set-interval observation exists; webcam set counting is the cheapest path; until done, the bands in A are operator judgement and must be labelled as such in the explainer.

Doc/ADR impact if A is adopted: ADR-101 row 5 + §7.2 variable inventory (new inputs ν, Tm02, partition energies; retire `setTimingMinutes`/`setAmplitudeM` as scoring inputs), API-MANUAL §17 field-row text for `setTimingMinutes` (rename/relabel to seconds and "dominant group period"), S-SPEC-1, `surf_scorer.py` consistency block, known-answer tests. Changing which quantities feed a factor is an ADR-level change — operator approval in chat required before any code moves.

---

## 8. Sources (accessed 2026-08-23)

Local (read first):
- `docs/decisions/ADR-101-surf-score-geometric-mean.md` — factor table :57–66, guidance :106–127.
- `docs/planning/briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md` — :47, :97–103, :160, :308–313.
- `docs/planning/EYEBALL-FIX-PLAN-2026-08-04.md` :69 (S-SPEC-1 consistency bands).
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/surf_scorer.py` :340–400, :856–900.
- `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surfbeat_runner.py` :1–70 (module docstring), :98–125 (`_IG_SPLIT_HZ`, `_SURFBEAT_DF_HZ`), :305–364 (`SurfBeatResult`), :1374–1432 (`_compute_ig_set_timing`).
- `docs/reference/swan-user-manual.txt` :3942–3999 (§SURFBEAT, IEM description).
- `docs/manuals/API-MANUAL.md` :2468–2493 (SurfBeat block), :2599–2601 (`setTimingMinutes`, `setAmplitudeM`, `igWaveHeightM`).

Web:
- Surfline Support — "Wave Consistency": https://support.surfline.com/hc/en-us/articles/20350539606683-Wave-Consistency (fetched via r.jina.ai proxy; direct fetch 403)
- Surfline — "Wave Consistency" feature page: https://www.surfline.com/lp/whatsnew/features/wave-consistency (search snippet; direct fetch 403)
- Surfline — "Why Do Waves Come in Sets?": https://www.surfline.com/surf-news/why-do-waves-come-in-sets/1156 (via proxy)
- Science of Surfing — "Why do waves come in sets?": https://www.scienceofsurfing.com/p/sets
- NC Sea Grant Coastwatch — "Why do waves come in groups?": https://ncseagrant.ncsu.edu/coastwatch/sea-science-ask-a-scientist-why-do-waves-come-in-groups/
- Surfertoday — "Why do waves come in sets?": https://www.surfertoday.com/surfing/why-do-waves-come-in-sets ; "How ocean swells propagate, disperse, and group": https://www.surfertoday.com/surfing/how-ocean-swells-propagate-disperse-and-group
- Surf-forecast.com FAQ: https://www.surf-forecast.com/pages/faq ; break guide "Reliability" field: https://www.surf-forecast.com/breaks/Magics_1
- Swellnet — "Know Your Product: Wave Period": https://www.swellnet.com/news/swellnet-analysis/2016/08/17/know-your-product-wave-period (via proxy); forum "Why do waves come in sets": https://www.swellnet.com/forums/wax/550786 (search snippet only)
- Coastal Wiki — "Infragravity waves": https://www.coastalwiki.org/wiki/Infragravity_waves
- Bertin et al. 2018, "Infragravity waves: from driving mechanisms to impacts", Earth-Science Reviews — PDF: https://www.ipgp.fr/~stutz/2018_bertin_al_IG.pdf (text extracted locally; IG 25–250 s / VLF 4–30 min; Eqs. 2, 6)
- Lange et al. 2024, "Free Infragravity Waves on the Inner Shelf: Observations and Parameterizations at Two Southern California Beaches", JGR Oceans: https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2023JC020378
- Herbers, Elgar & Guza 1994, "Infragravity-frequency (0.005–0.05 Hz) motions on the shelf. Part I: Forced waves", JPO 24:917–927 — abstract: http://scrippsscholars.ucsd.edu/rguza/content/infragravity-frequency-0005-005-hz-motions-shelf-1-forced-waves
- Battjes, Bakkenes, Janssen & van Dongeren 2004, "Shoaling of subharmonic gravity waves", JGR 109 C02009: https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2003JC001863 (PDF: https://falk.ucsd.edu/reading/battjes_et_al_jgr_2004.pdf)
- Frontiers in Marine Science 2025, "Analysis of infragravity waves characteristics and energy evaluation based on field observations": https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2025.1627163/full
- Reniers & Zijlema 2022, "SWAN SurfBeat-1D", Coastal Engineering 172:104068 — https://www.sciencedirect.com/science/article/pii/S0378383921002040 (403; cited via ICCE abstract below)
- Reniers, Akrish, Rijnsdorp, Zijlema, Rutten, de Wit, Tissier — "Modeling infragravity waves with SWAN", ICCE Proceedings: https://icce-ojs-tamu.tdl.org/icce/article/download/14691/13963/40935 (text extracted locally)
- Mansard & Sand 1994, "A comparative evaluation of wave grouping measures", ICCE ch. 61: https://icce-ojs-tamu.tdl.org/icce/article/download/5001/4681/0 (text extracted locally; SIWEH/GF, run lengths, Kimura κ, Longuet-Higgins 1975 ν)
- Masson & Chandler 1993, "Wave groups: a closer look at spectral methods", Coastal Eng. — abstract: https://www.sciencedirect.com/science/article/abs/pii/037838399390004R (PDF at https://data-ww3.ifremer.fr/BIB/Masson_Chandler_CE1993.pdf returned 403)
- Saulnier et al. 2011, "Wave groupiness and spectral bandwidth as relevant parameters for the performance assessment of wave energy converters", Ocean Eng. — https://www.sciencedirect.com/science/article/abs/pii/S0029801810002179
- "Groupiness factor and wave height distribution", J. Waterway Port Coastal Ocean Eng. 115(1), 1989: https://ascelibrary.org/doi/10.1061/(ASCE)0733-950X(1989)115:1(105)
- Longuet-Higgins 1984 run-length/repetition formulas are quoted from standard textbook treatment (Holthuijsen 2007, "Waves in Oceanic and Coastal Waters", wave-group statistics) — **not re-verified against an accessible copy this session; verify before coding Candidate A step 2.**

Fetch failures (for the record): Surfline ×2 direct, ScienceDirect ×3, IFREMER PDF, Swellnet forum — all HTTP 403; PDFs were text-extracted locally with PyMuPDF where a proxy was unavailable.
