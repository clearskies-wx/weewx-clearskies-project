# Wave-group run-length formulas — verified for coding (CONSISTENCY-SCORING pre-work, task V1)

**Date:** 2026-08-23 · **Author:** research agent (read-only; only this file was created) · **Verifies:** `SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.3, §7 item 1.

Every expression below carries one of two labels: **[PRIMARY p.N eq.M]** (read directly from the cited paper/manual, page and equation number given) or **[NOT verified against primary — secondary: source]**. No unlabelled formula appears in this document.

---

## G. Implement-this summary (read this first)

**Recommendation: code the Kimura/Markov route (§C), not the Longuet-Higgins envelope closed form (§B).** Reason: every equation in the Markov route — the bivariate-Rayleigh transition probabilities, the run-length formulas, and the κ-from-spectrum relation — was read verbatim from primary sources this session, with exact equation numbers, and cross-validated numerically against the original authors' own published simulation results (see §C, §F). The envelope-route closed form the earlier brief quoted could **not** be confirmed against Longuet-Higgins (1984) or any accessible secondary source despite a genuine search effort (§B). Use §C for the shipped code; keep §B only as a documented, flagged approximation if a future session reaches the paywalled primary.

**Order of evaluation, S(f) → (T_set, N_set, κ):**

1. From the dominant partition's 1-D spectrum S(f): compute `m0 = ∫S(f)df`, `m1 = ∫f·S(f)df`, `m2 = ∫f²·S(f)df`.
2. `Tm01 = m0/m1`; `Tm02 = √(m0/m2)` — **use Tm02**, the mean zero-up-crossing period, to convert wave counts to seconds (§A explains why; the earlier brief's step 2 said Tm01 — that is corrected here).
3. `κ = |∫S(f)·e^{i2πf·Tm02}df| / m0` (Battjes & van Vledder 1984) — **our own SWAN model already computes exactly this as output quantity `FSPR`, with τ = Tm02** [PRIMARY — `docs/reference/swan-user-manual.txt`:5908–5911]. Check whether `FSPR` is already in the SPECOUT/TABLE output being parsed before writing a new κ computation — this may already be free.
4. Kimura's own bivariate-Rayleigh correlation parameter `ρ_K = κ/2` [PRIMARY, Battjes & van Vledder 1984 p.643].
5. Numerically integrate eqs. (5),(6),(12) [Kimura 1980] with `ρ_K` and threshold `h* = ρ·h_rms` (ρ = √2 for "set wave" = H > Hs) to get `p11`, `p22`.
6. `N_set = 1/(1−p22)` [PRIMARY, Kimura 1980 eq.16]; `N_rep = 1/(1−p11) + 1/(1−p22)` [PRIMARY, Kimura 1980 eq.19].
7. `T_set = N_rep × Tm02` seconds.
8. Score per `SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.2 (unchanged — out of this task's scope).

**Constants and their provenance:**

| Constant / choice | Value | Source |
|---|---|---|
| Threshold for "set wave" | ρ = H*/H_rms = √2 (i.e. H* = Hs) | Brief's own choice, carried forward unchanged (operator-approved scope, §5 lead call) |
| κ↔ρ_K relation | ρ_K = κ/2 | Battjes & van Vledder 1984, p.643 [PRIMARY] |
| Lag for κ | T = Tm02 = √(m0/m2) | Battjes & van Vledder 1984 eq.4 [PRIMARY]; independently confirmed by SWAN manual FSPR definition and Holthuijsen 2007 Note 4C [PRIMARY, see §D] |
| Numerical integration domain | 0 to ~8–12×h_rms treated as ∞ | This session's numerical choice (§F); not from a paper — state tolerance in the KAT |
| Bessel evaluation | `scipy.special.i0e` (exponentially-scaled I₀) with the exponent folded in, to avoid overflow at low (1−4ρ_K²) | This session's numerical method note, not a physics choice — methodology only |

---

## A. Spectral moments and width parameters

**m_n = ∫ f^n S(f) df** for n = 0, 1, 2, ... — S(f) is the 1-D (frequency-integrated) variance density spectrum, units m²/Hz, over the dominant-partition frequency band. f in Hz. m0 has units m² (= Hs²/16 by definition of Hs = 4√m0). [PRIMARY — Holthuijsen 2007, Note 4A, p.57: "mn = ∫f^n E(f)df"]

**Tm01 = m0/m1** — "mean absolute wave period," inverse of the mean frequency. [PRIMARY — Holthuijsen 2007 eq.4.2.6, p.62: "Tm01 = f_mean⁻¹ = (m1/m0)⁻¹ = m0/m1"; independently confirmed, same formula, SWAN User Manual :5844–5849 `TM01`]

**Tm02 = √(m0/m2)** — mean absolute zero-up-crossing period. [PRIMARY — SWAN User Manual :5852–5857 `TM02`, defined as `2π·(∫∫σ²E dσdθ/∫∫E dσdθ)^(−1/2)`, which in frequency terms (σ=2πf) reduces to √(m0/m2)]

**Longuet-Higgins ν = √(m0·m2/m1² − 1)** — spectral width/bandwidth parameter. [PRIMARY — Holthuijsen 2007, Note 4C, p.67, quoting Longuet-Higgins (1975): "ν = (m0m2/m1² − 1)^(1/2)"]

> **Finding — flag, not resolved by me (brief §6 applies).** Holthuijsen's printed equation continues "`= (T²m02/T²m01 − 1)^(1/2)`" — i.e. as scanned, the ratio is Tm02²/Tm01². I checked this against (a) Holthuijsen's own eq.4.2.6 (Tm01=m0/m1), (b) the SWAN-manual-confirmed Tm02=√(m0/m2), and (c) a hand numerical check with a two-frequency toy spectrum (E=1 at f=0.08 Hz and f=0.12 Hz): m0=2, m1=0.2, m2=0.0208 → Tm01=10.0 s, Tm02=9.807 s, m0m2/m1²=1.04, ν=0.2, and (Tm01/Tm02)²=1.040 (matches) while (Tm02/Tm01)²=0.962 (does not). **The algebraically consistent identity is ν² + 1 = (Tm01/Tm02)², not (Tm02/Tm01)².** I believe the scanned Holthuijsen text has the ratio inverted (a reproduction/OCR-adjacent error in that specific PDF, not a live edit by me — I did not alter the printed formula, only flag the ratio direction). Use `ν = √(m0·m2/m1² − 1)` directly from the moments; do not compute it via a Tm01/Tm02 ratio in code, to sidestep the discrepancy entirely.

**Goda's peakedness Qp = (2/m0²) ∫ f·S(f)² df.** [NOT verified against primary — Goda (1970) original not fetched this session; formula confirmed identical across multiple independent secondary summaries (coastal-engineering references synthesised via search), standard and uncontested in the literature]

**Which Tm each formula wants:**

| Formula | Wants | Why |
|---|---|---|
| ν (Longuet-Higgins width) | Uses m0,m1,m2 directly — no Tm needed for ν itself | — |
| κ (Battjes & van Vledder) | **Tm02** | Both primary sources (BvV 1984 eq.4: "T = Tz = (m0/m2)^(1/2)"; SWAN manual FSPR: "τ = Tm02") agree explicitly |
| Converting N_set/N_rep (wave counts) to seconds | **Tm02** | Kimura's and Battjes & van Vledder's wave counts are from **zero-up-crossing** analysis [PRIMARY, Kimura 1980 p.2955 abstract: "determined by the zero-up-cross method"] — the physically matching period is the mean zero-crossing period, Tm02, not Tm01. **This corrects `SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.3 step 2, which used Tm01.** |

---

## B. Envelope route (Longuet-Higgins 1984)

**Fetch attempts and their outcomes (all failed to reach the primary text):**
- Royal Society (`royalsocietypublishing.org/doi/10.1098/rsta.1984.0061` and the abstract-page variant) — HTTP 403 (paywalled), both direct fetch attempts.
- Springer chapter "Wave Group Statistics" — redirected to an IdP login wall, not fetched.
- Multiple ScienceDirect pages citing/reviewing the paper — HTTP 403.
- Two arXiv papers that cite Longuet-Higgins (1984) (`2108.03636`, `2309.02134`) — fetched and text-searched in full; neither restates the closed-form run-length expressions, only the qualitative claim that the envelope and Markov routes agree for narrow spectra (used in §E).
- Holthuijsen (2007) full text (405-page PDF, obtained and searched exhaustively for "wave group", "run", "groupiness") — **does not contain the ν,ρ closed-form envelope expressions at all.** Its §4.2.3 "Wave groups" presents only the Markov/Kimura route (R_H = p22 in Kimura's notation), and cites κ (not ν directly) as the parameter controlling groupiness, via Note 4C.
- Mansard & Sand (1994), ICCE ch.61 — fetched and searched in full (this is the paper the RESEARCH-SET-CONSISTENCY brief listed as covering "run lengths, Kimura κ, Longuet-Higgins 1975 ν"). It reviews Kimura's Markov route and the κ-from-spectrum relation (matching §D below) but likewise does **not** state the ν,ρ envelope closed form.

**Conclusion: [NOT verified against primary — no accessible secondary source restates this formula either].** The brief's quoted expressions —

`N_set ≈ 1/(√(2π)·ν·ρ)` (mean waves per "high run")
`N_rep ≈ e^{ρ²}/(√(2π)·ν·ρ)` (mean repetition/total-run length)

— are **not contradicted** by anything found (the Royal Society abstract, readable via search-engine synthesis, confirms the paper does define run/repetition lengths "in terms of a single parameter that defines the spectral width" via the envelope approach, consistent in shape with these expressions), but I could not read the actual equation to confirm the constant `√(2π)` or the exponent `e^{ρ²}` against the primary text. **Do not code this route without independent re-derivation or a successful fetch of Longuet-Higgins (1984) pp.219–250 (or a library/ILL copy).**

The brief's own worked examples (ν=0.10, Tm=13s → N_rep≈21 waves≈4.5 min) are **self-consistent with the quoted formula** (I recomputed them independently — see §F) but that only proves internal arithmetic consistency, not that the formula is the one Longuet-Higgins (1984) actually derived.

**Expected "waves per group" statement:** the brief's N_set (mean high-run length) already is Longuet-Higgins' group-length statistic in the envelope route — there is no separate "group length" formula distinct from the high-run length in this framework; group and high-run are the same quantity here. [Same not-verified status as above.]

**"Set" = "high run above Hs (ρ=√2)":** this is a modelling choice stated by the brief and treated as operator-approved score structure (out of scope per §5 lead call), not a physics fact to verify. I note only that it is a defensible, common convention (H > Hs ≈ H1/3 is the standard "significant"/energetic threshold) but no paper was found asserting "Hs is *the* set-wave threshold" as a physical law — it is a modelling decision.

---

## C. Markov route (Kimura 1980)

Source: Kimura, A. (1980), "Statistical Properties of Random Wave Groups," Proc. 17th Int. Conf. Coastal Engineering (ICCE), Sydney, Chapter 178, pp.2955–2973. Fetched directly (`icce-ojs-tamu.tdl.org/icce/article/download/3604/3286/15301`), OCR text extracted and cross-checked against page images. All equation numbers below are Kimura's own.

**Symbols:** h1, h2 = successive zero-up-crossing wave heights (m). h_r = RMS wave height (m). h* = threshold height (m). ρ_K = Kimura's bivariate-Rayleigh correlation parameter (dimensionless, his own symbol is "ρ" in the paper — **renamed ρ_K here to avoid clashing with the threshold ratio ρ=H*/Hrms used elsewhere in this document**; note this is unrelated to the ρ symbol in §B). I₀ = modified Bessel function of the 0th order.

**Bivariate Rayleigh pdf of successive heights** [PRIMARY, Kimura 1980 eq.5, p.2956]:

```
p(h1,h2) = [4·h1·h2 / ((1−4ρ_K²)·h_r⁴)] · exp[ −(h1²+h2²) / ((1−4ρ_K²)·h_r²) ] · I₀[ 4·h1·h2·ρ_K / ((1−4ρ_K²)·h_r²) ]
```

**Marginal Rayleigh pdf** [PRIMARY, eq.6]: `Q(h1) = (2h1/h_r²)·exp(−h1²/h_r²)`

**Correlation coefficient of successive heights γ_h vs ρ_K** [PRIMARY, eq.7]:

```
γ_h = [ E(2ρ_K) − ½(1−4ρ_K²)·K(2ρ_K) − π/4 ] / (1 − π/4)
```
K, E = complete elliptic integrals of the first and second kind.

**Transition probabilities as integrals over threshold h\*** [PRIMARY, eqs.4 and 12, p.2956–2959; state 1 = below h\*, state 2 = at/above h\*]:

```
p11 = ∫₀^h* ∫₀^h* p(h1,h2) dh1 dh2  /  ∫₀^h* Q(h1) dh1
p12 = ∫h*^∞ ∫₀^h* p(h1,h2) dh1 dh2  /  ∫₀^h* Q(h1) dh1     (= 1 − p11)
p21 = ∫₀^h* ∫h*^∞ p(h1,h2) dh1 dh2  /  ∫h*^∞ Q(h1) dh1     (= 1 − p22)
p22 = ∫h*^∞ ∫h*^∞ p(h1,h2) dh1 dh2  /  ∫h*^∞ Q(h1) dh1
```

**Run-length distributions and means** [PRIMARY, eqs.15,16 (high-run), 17 (low-run), 18,19 (total run), p.2960]:

```
P(run of high waves = ℓ) = p22^(ℓ−1)·(1 − p22)                     (eq.15)
Mean run of high waves:   N_set = 1/(1 − p22)                       (eq.16)

P(run of low waves = ℓ') = p11^(ℓ'−1)·(1 − p11)                    (eq.17)
Mean run of low waves:    N_low = 1/(1 − p11)

P(total run = ℓ0) = [(1−p11)(1−p22)/(p11−p22)]·(p11^(ℓ0−1) − p22^(ℓ0−1))   (eq.18)
Mean total run:    N_rep = 1/(1 − p11) + 1/(1 − p22)                 (eq.19)
```

This matches the earlier brief's quoted `N_rep = 1/(1−p11) + 1/(1−p22)` exactly.

**Kimura's own κ-from-spectrum statement:** the 1980 paper does **not** give a closed-form κ(spectrum) relation — it only shows (Fig.15, from numerical simulation data, no equation) that γ_h correlates with Goda's Qp, i.e. "statistical properties of the run of wave height can be estimated from Qp" as an empirical/graphical relationship [PRIMARY, Kimura 1980, "ESTIMATION OF PARAMETERS," p.2973]. The closed-form κ(spectrum) relation used in this document is from Battjes & van Vledder (1984) — see §D. Kimura's paper is the source for the run-length machinery only.

---

## D. κ from the spectrum (Battjes & van Vledder 1984) — the single most important line

Source: Battjes, J.A. and van Vledder, G.Ph. (1984), "Verification of Kimura's Theory for Wave Group Statistics," Proc. 19th ICCE, Houston, Chapter 43, pp.642–648. **Fetched directly and read in full** (`icce-ojs-tamu.tdl.org/icce/article/download/3824/3507/16184`), not the abstract only.

**The relation, verbatim from primary [PRIMARY, p.643, eqs.4–5]:**

```
κ = k(T)   for   T = Tz = (m0/m2)^(1/2)            ...eq.4
k(T) = | ∫ E(f)·e^{i2πfT} df | / m0                 ...eq.5
```

- **Lag = Tz = the mean zero-crossing period = Tm02.** [PRIMARY, explicit in the paper: "Tz is the mean zero-crossing wave period"] — this answers the brief's open question directly: **Tm02, not Tm01.**
- **κ is the MODULUS of the complex integral, divided by m0 — not squared.** The `| |` in eq.5 denotes the modulus of the complex number `∫E(f)e^{i2πfT}df`; the division is by m0 (first power), not m0². [PRIMARY]
- **Relation to Kimura's own parameter:** "Kimura's parameter ρ equals ½κ" [PRIMARY, p.643] — i.e. `ρ_K = κ/2` (§C's ρ_K). The paper also notes an alternative time-domain check: κ² equals the coefficient of linear correlation between H² and H²_{n+1} (Battjes, ref 2), but the spectral route (eqs.4–5) is what "obviates the need to use the correlation coefficient of successive wave heights" and is what feeds our pipeline.
- **Empirical validation in the same paper:** 33 North Sea Waverider records; Kimura's predicted mean group length using the *spectral* κ-route slightly under-predicts observations at high correlation (attributed to bound higher-harmonic energy broadening the spectrum, which lowers the spectral κ estimate relative to the true swell-only κ) — worth knowing if our SWAN spectrum includes bound harmonics. [PRIMARY, "DISCUSSION," p.643–645]

**Independent triple-confirmation of the exact same formula, found this session without being asked to cross-check:**

1. **Holthuijsen (2007), Note 4C, p.67** [PRIMARY]: `κ² = (1/m0²)·{ [∫₀^∞ E(f)cos(2πf/f̄0)df]² + [∫₀^∞ E(f)sin(2πf/f̄0)df]² }`, with `f̄0 = √(m2/m0)` — i.e. `1/f̄0 = √(m0/m2) = Tm02`, and κ² here is the sum of squares of the real and imaginary parts of the same complex integral, i.e. κ² = |integral|²/m0², so κ (not κ²) = |integral|/m0. **Exact algebraic match to Battjes & van Vledder's own eqs.4–5.**
2. **SWAN User Manual** (`docs/reference/swan-user-manual.txt` :5908–5911) [PRIMARY, local project reference]: SWAN's own output quantity `FSPR` is defined as *"the normalized frequency width of the spectrum (frequency spreading), as defined by Battjes and Van Vledder (1984): `FSPR = |∫E(σ)e^{iστ}dσ| / Etot, for τ = Tm02`."* **This is κ, verbatim, already a standard SWAN output quantity, citing the same paper by name.** Practical implication for the coder: check whether `FSPR` can simply be requested in the existing `QUANTITY`/SPECOUT block instead of hand-computing the integral — this may already exist in our pipeline or be a one-line addition, not new physics.

**Answer to the brief's two open questions (§6):**
- Lag: **Tm02 (mean zero-crossing period), confirmed identically by three independent primary sources** (Battjes & van Vledder's own paper, Holthuijsen's textbook restatement, SWAN's own manual). No disagreement found — nothing to escalate.
- Modulus vs square: **modulus** (κ = |·|/m0). No disagreement found.

---

## E. Equivalence of the two routes for narrow spectra

[NOT verified against primary full text — Royal Society paper not reachable (§B); based on the paper's abstract as rendered by search-engine synthesis, plus consistent citations in Holthuijsen (2007) and two arXiv papers that were fetched in full]

What is confirmed, from multiple independent (but all secondary/abstract-level) sources agreeing verbatim in substance:
- Longuet-Higgins (1984) "unifies two different approaches to wave grouping: (a) treating the sea state as a Gaussian process with group properties given by the wave envelope function [→ ν], and (b) treating the sequence of wave-heights as a one-step Markov process [→ Kimura's p+, p−], showing that the spectral width parameter ν plays an important role in both approaches," and "finds approximate analytic expressions for p+ and p− that show the two approaches are roughly equivalent, **to order ν**." [Royal Society abstract, via search synthesis — not independently re-read by me from the primary]
- Holthuijsen (2007) §4.2.3 [PRIMARY, p.95, literature list]: cites Longuet-Higgins (1984) alongside Kimura (1980) and Battjes & van Vledder (1984) in the same paragraph discussing groupiness vs spectral width, consistent with (not contradicting) the equivalence claim, but does not restate the "to order ν" result itself.
- The ship-motion-statistics arXiv paper (2108.03636, fetched in full) states plainly: *"the statistics of wave groups... is formulated by Longuet-Higgins (1957) through the spectral moments, and by Kimura (1980) through the correlation between the successive waves. In Longuet-Higgins (1984), it is shown that the results given by the two formulations are consistent for small bandwidth of the spectra."* [fetched, full text, but this is a tertiary citation of LH1984, not the primary itself]

**No relation between κ and ν in the narrow-band limit was found stated explicitly anywhere** (not in Kimura 1980, not in Battjes & van Vledder 1984, not in Holthuijsen 2007). Both κ and ν are spectral-width measures but via different weighting of the spectrum (ν via moments m0,m1,m2; κ via the spectrum's Fourier-cosine/sine transform at frequency 1/Tm02) — they are NOT algebraically identical parameters, only both monotonically related to spectral narrowness. **Do not treat ν and κ as interchangeable or convertible via a simple formula; compute whichever the chosen route needs directly from S(f).**

**Practical takeaway for the coder:** because the envelope/ν route (§B) could not be verified and the equivalence-in-the-narrow-limit result could not be read in full, do **not** use "compute via ν and cross-check via κ" as a design — pick the Kimura/κ route (§C+§D, fully verified) as the sole computation path, per §G's recommendation.

---

## F. Worked numbers for known-answer tests

### F.1 Envelope route (brief's formula, §B — NOT verified against primary; included only because the brief's numbers needed independent arithmetic verification)

ρ = √2 (threshold = Hs), Tm = 13 s. `N_set = 1/(√(2π)·ν·ρ)`, `N_rep = e^{ρ²}/(√(2π)·ν·ρ) = e²/(√(2π)·ν·√2)`, `T_set = N_rep × Tm`.

| ν | N_set (waves) | N_rep (waves) | T_set (s) | T_set (min) |
|---|---|---|---|---|
| 0.05 | 5.64 | 41.69 | 542.0 | 9.03 |
| 0.10 | 2.82 | 20.84 | 271.0 | 4.52 |
| 0.20 | 1.41 | 10.42 | 135.5 | 2.26 |

Method: direct closed-form evaluation (Python, `math`/`numpy`), 3 s.f. shown; exact rational arithmetic possible if needed (no numerical integration involved). These reproduce the brief's own quoted approximate values (≈21 waves/4.5 min at ν=0.10, ≈10 waves/2.3 min at ν=0.20, ≈42 waves/9 min at ν=0.05) essentially exactly — confirms the brief did its own arithmetic on this formula correctly; it does **not** confirm the formula against Longuet-Higgins (1984).

### F.2 Kimura/Markov route (§C+§D — fully primary-verified; **use these as the KAT reference values**)

Threshold = Hs (ρ = √2, h* = √2·h_r, h_r = 1 normalized). ρ_K = κ/2 (Battjes & van Vledder relation, §D).

Method: numerical double integration (`scipy.integrate.dblquad`) of Kimura's eqs.(5),(6),(12) using the exponentially-scaled Bessel function `scipy.special.i0e` to avoid overflow (`I₀(x) = i0e(x)·e^x`, so `exp(−A)·I₀(B) = exp(B−A)·i0e(B)` — a numerical-stability technique, not a physics change). Integration domain 0 to 12·h_r stood in for infinity (h_r=1, so this is 8.5σ beyond the h*=√2 threshold — the Rayleigh tail beyond 12·h_r is negligible to well past double precision). `epsabs=1e-10, epsrel=1e-8`.

| κ | ρ_K = κ/2 | p11 | p22 | N_set = 1/(1−p22) | N_rep = 1/(1−p11)+1/(1−p22) |
|---|---|---|---|---|---|
| 0.3 | 0.150 | 0.8723 | 0.1841 | 1.226 | 9.06 |
| 0.5 | 0.250 | 0.8860 | 0.2719 | 1.373 | 10.15 |
| 0.8 | 0.400 | 0.9235 | 0.5111 | 2.045 | 15.11 |

**Cross-validation against Kimura's own published simulation results** (this is the strongest evidence in this document — an independent check I ran, not requested by the brief, but directly answering the "known-answer" mandate in `rules/verification.md`): Kimura's Table 1 (`RESEARCH-SET-CONSISTENCY-2026-08-23.md` §3.3 restates it) reports, from 5000-wave numerical simulation at threshold Hs, N_set = 1.28–1.53 waves and N_rep = 9.3–10.7 waves as γ_h rises 0.19→0.38. Converting κ=0.5 to γ_h via eq.(7) [PRIMARY, using `scipy.special.ellipk/ellipe`]: **γ_h = 0.233** — inside Kimura's quoted 0.19–0.38 range — and my computed **N_set = 1.373, N_rep = 10.15 — both inside Kimura's quoted 1.28–1.53 and 9.3–10.7 ranges.** This independently confirms both the equations were transcribed correctly and the numerical integration is correct, using the original author's own validation data as the known answer.

**Numerical tolerance to accept for the KAT:** given the integration's own `epsrel=1e-8`, I'd accept **±0.5%** (relative) or **±0.01** (absolute) on p11/p22, propagating to roughly **±1%** on N_set/N_rep — tight enough to catch a wrong equation or a sign error, loose enough to survive a different (but equally valid) quadrature routine or integration cutoff (10·h_r vs 12·h_r changes the answer by <10⁻⁶ at these κ values — verified by re-running with `INF=10` and `INF=15`, both reproduced the table above to the digits shown).

---

## Fetch failures (complete list, for the record)

| Source | Result |
|---|---|
| Royal Society, `doi.org/10.1098/rsta.1984.0061` (2 URL variants) | HTTP 403 (paywalled) |
| Springer, `link.springer.com/chapter/10.1007/978-94-009-4668-2_3` | Redirected to IdP login wall, not fetched |
| ScienceDirect, "Wave Group" topic overview page | HTTP 403 |
| ScienceDirect ×3 other citing papers (Masson & Chandler abstract page, group-height/length papers) | HTTP 403 (abstract pages only attempted; not counted separately, same host) |
| IFREMER, `data-ww3.ifremer.fr/BIB/Masson_Chandler_CE1993.pdf` | `ECONNREFUSED` |

## Sources successfully reached and read in full this session

- Kimura, A. (1980), ICCE ch.178, pp.2955–2973 — fetched, OCR-extracted, page images inspected for equations 5,6,7,11,12,15,16,17,18,19.
- Battjes, J.A. & van Vledder, G.Ph. (1984), ICCE ch.43, pp.642–648 — fetched, full text read, eqs.1–5 extracted.
- Holthuijsen, L.H. (2007), *Waves in Oceanic and Coastal Waters*, Cambridge — 405-page PDF fetched, full-text searched, §4.2.1–4.2.4 and Notes 4A/4C read in full, key formula pages rendered as images and visually re-checked.
- Mansard, E.P.D. & Sand, S.E. (1994), ICCE ch.61, pp.832–843 — fetched, full text read.
- SWAN User Manual (local, `docs/reference/swan-user-manual.txt`) — TM01/TM02/FSPR definitions, :5844–5911.
- Two arXiv papers citing Longuet-Higgins (1984) (2108.03636, 2309.02134) — fetched, full text searched.
- `SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md`, `RESEARCH-SET-CONSISTENCY-2026-08-23.md`, `ADR-101-surf-score-geometric-mean.md`, `rules/verification.md` — read per the reading list.

Working files (OCR text extracts, the numerical-integration script) are kept under `scratch/wave-group-formulas/`; all bulky third-party PDFs and rendered page images were deleted after their content was captured into this document, per scope.
