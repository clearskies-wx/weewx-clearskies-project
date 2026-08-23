# Brief — verify the wave-group run-length formulas before coding (CONSISTENCY-SCORING pre-work, task V1)

**Round:** CONSISTENCY-SCORING pre-coding verification, 2026-08-23. **Lead:** coordinator (Fable). **Teammate:** one research agent (Sonnet, read-only). **Auditor:** none for this task (the lead checks the result against the primary-source quotes the agent returns). **Operator ruling that opened this round:** Q14 in `docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md` — "q14 recommendation is fine" (2026-08-23, chat).

## 1. Task

`docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.3 and §7 say, in the brief's own words, that two things must be verified before any code is written:

1. "the exact Longuet-Higgins envelope run-length expressions (or implement the Kimura route, whose equations are quoted from the paper in §3.3 and need only the Battjes–van Vledder κ-from-spectrum relation confirmed)";
2. (handled by a separate agent — NOT you) typical partition-band ν/κ from our cached spectra.

You do item 1. Deliver a verification document that a coder can implement from WITHOUT opening any paper, and that a known-answer test can be written from.

## 2. Scope block

**Deliverable (one file, create):** `docs/planning/briefs/WAVE-GROUP-FORMULAS-VERIFICATION-2026-08-23.md`.

**Files you may read:** anything in this workspace. **Files you may NOT create or modify:** anything else — no repo code, no tests, no plan edits, no scratch files outside `scratch/` (if you must save a fetched PDF's extracted text, put it under `scratch/wave-group-formulas/` and delete bulky third-party material once its extraction is captured).

**Verification command:** none (research task). Your closeout is the document plus a SendMessage to the lead listing (a) each formula you confirmed and its primary source, (b) each formula you could NOT confirm from a primary source and what you found instead, (c) every fetch that failed.

**Scope acknowledgment:** before doing any work, SendMessage the lead one paragraph: what you will deliver, what you will not touch, and how you will source each formula. Wait for confirmation.

## 3. Reading list (read these first, in this order)

1. `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` — §3.3 (both routes, the caveat in the envelope-route bullet), §4.2–4.3 (κ is reused in the amplitude index), §7 "Before coding, verify", §8 sources. This is the brief whose claims you are verifying.
2. `docs/planning/briefs/RESEARCH-SET-CONSISTENCY-2026-08-23.md` — §2.2 (wave groups physics as already researched), §8 (its source list; the caveat about the un-re-verified Longuet-Higgins form originates there).
3. `docs/decisions/ADR-101-surf-score-geometric-mean.md` — §"Implementation guidance" item 4 (known-answer tests are mandatory — your document must make them writable).
4. `rules/verification.md` — the "known-answer test" mandate only (search the file for "known-answer").
5. `CLAUDE.md` §"Always-applicable rules" → "When you don't know, search the web" and the global ban on the `deep-research` skill (a few targeted `WebSearch`/`WebFetch` calls, not a fan-out).

## 4. What the document must contain (per-deliverable spec)

For each quantity below: the exact expression, every symbol defined with units, the assumptions it rests on (narrow-band? Rayleigh heights? threshold convention?), the PRIMARY source with page/equation number where you could read it, and — if you could not reach the primary text — the best secondary source and an explicit "NOT verified against primary" flag. No expression may be written down without one of those two labels.

A. **Spectral moments and width parameters** from a 1-D frequency spectrum S(f): m_n = ∫ f^n S(f) df; Tm01 = m0/m1; Tm02 = √(m0/m2); Longuet-Higgins ν = √(m0·m2/m1² − 1); Goda's peakedness Qp = (2/m0²)∫ f S(f)² df. State which Tm each run-length formula wants (Tm01 vs Tm02 vs Tp) — this matters for the set interval in seconds.

B. **Envelope route (Longuet-Higgins 1984, Phil. Trans. R. Soc. A 312:219–250):** for threshold ρ = H*/H_rms, (i) the mean number of waves in a "high run" (waves exceeding H*), (ii) the mean "total run" / repetition length (start of one high run to the start of the next), both in waves, as functions of ν and ρ. The brief quotes N_set ≈ 1/(√(2π)·ν·ρ) and N_rep ≈ e^{ρ²}/(√(2π)·ν·ρ). Confirm, correct, or flag. Also state the expected number of waves per group that the same theory gives (the "group length" 1/(√(2π) ν ρ)-type expression) and whether "set" = "high run above Hs (ρ=√2)" is the right identification. Holthuijsen, *Waves in Oceanic and Coastal Waters* (2007) §4.2.3–4.2.4 covers this in textbook form — an acceptable primary for the textbook expressions if the Royal Society paper is paywalled; say which you used.

C. **Markov route (Kimura 1980, ICCE ch. 178 — the brief says its equations were read from the paper text last session; re-read the same source, link in the brief's §8):** the bivariate Rayleigh transition probabilities p11, p22 as integrals in the correlation parameter κ; mean high-run length 1/(1 − p22); mean total run 1/(1 − p11) + 1/(1 − p22). Write the integrals explicitly so a coder can evaluate them numerically (state the Bessel function I₀ form and the integration limits for threshold H*).

D. **κ from the spectrum (Battjes & van Vledder 1984, ICCE "Verification of Kimura's theory for wave group statistics"):** the exact relation between κ and the spectrum — the brief says "modulus of the spectrum's autocorrelation at one mean-period lag." Give the formula (is it κ = |∫S(f)·e^{i2πfT}df| / m0 with T = Tm01? Tm02? and is κ the modulus of that complex correlation, or its square?). This is the single most important line in your document because both the timing term and the amplitude term read κ. If the paper is unreachable, Masson & Chandler 1993 (Coastal Eng.) and Holthuijsen 2007 both restate it — cite which.

E. **Equivalence of the two routes for narrow spectra** (Longuet-Higgins 1984 showed the Markov and envelope routes agree for narrow spectra; the relation between κ and ν in that limit). One paragraph with the source; it lets the coder pick one route and test it against the other.

F. **Worked numbers for known-answer tests.** Compute by hand (show the arithmetic) for: ν = 0.05, 0.10, 0.20 at ρ = √2 with Tm = 13 s → N_set, N_rep, T_set (s and min); and the Kimura route for κ = 0.3, 0.5, 0.8 at threshold Hs → N_set, N_rep (numerical integration is fine; state the method and step). These become the KAT expected values, so precision to 3 significant figures and a statement of the numerical tolerance you'd accept.

G. **A one-page "implement this" summary** at the top: which route you recommend coding (and why), the exact formulas in order of evaluation from S(f) to (T_set, N_set, κ), and the list of constants with their provenance.

## 5. Lead calls (follow, do not re-derive)

- This is verification of the brief's physics, not new research: no survey of alternatives, no commercial comparisons, no redesign of the score. The score structure, the curves in §3.2/§4.3, and the 0.7/0.3, 0.6/0.4, 0.4/0.6 weights are operator-approved and out of your scope.
- SurfBeat has been removed from the system (operator ruling 2026-08-23). Ignore every SurfBeat sentence in the briefs you read; do not write about it.
- Targeted web use only: a handful of `WebFetch`/`WebSearch` calls on the specific sources named above. The `deep-research` skill is banned project-wide.
- SWAN/WW3 questions, if any arise, are answered from the local manuals under `docs/reference/` — never from the web.

## 6. Open questions you must surface (SendMessage), not resolve

- If the primary sources disagree with each other on a formula (e.g. two different forms of the Longuet-Higgins repetition length), report both with sources and stop — the lead rules.
- If κ's definition in Battjes & van Vledder uses a lag other than a mean period (e.g. the peak period), say so and give both; do not pick.

## 7. Mandatory blocks

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself. (For this task: do not commit at all — the lead commits your document.)

> **Architectural changes — STOP, do not proceed.** You may not make an architectural change. If your task requires one, STOP and report via SendMessage — do not implement it, do not work around it, do not pick an option.
>
> A change is architectural if it does ANY of these (mechanical test, not judgment):
> 1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or criterion inside one. **This does NOT cover changing how the same equation is solved** — iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the first is architectural. An approximation that does not converge to the original equation IS a formula change and is covered.
> 2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
> 3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
> 4. Changes a data contract between components — field names, shapes, nullability, units crossing a boundary.
> 5. Changes where a computation happens — host, service, process, or lifecycle stage.
> 6. Changes a schedule, trigger, or cadence.
> 7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
>
> **These do NOT authorize you:** "my task's acceptance criteria are unreachable without it" (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a finding to report, not permission to change code).
>
> You MAY still: resolve a contradiction between two statements inside the same document by taking the reading its own examples support (and say so); apply a rule already written in the rules files; fix code that diverges from its own stated contract.
>
> **The coordinator's ruling on your report is FINAL.** You surface an architectural concern ONCE, via SendMessage, then comply with the coordinator's answer. If the coordinator states that operator approval exists, that statement is your full authorization — verifying the approval chain is the coordinator's responsibility and the coordinator's alone. Do not refuse a second time, do not demand to see the paper trail, do not audit the coordinator's authority. (Operator ruling 2026-08-05.)

> **Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own authority. A behavior change and its test updates land in the same commit, per your task's design; a test you were not told to touch that fails against your change is a finding. Your closeout report must list every test you modified or deleted, with the reason, and every guard, invariant, or viability check that fired during your work — including ones you believe are unrelated or pre-existing. (For this task: you touch no tests; the list is "none".)

**Tone:** concise, direct, no filler. Plain English with every symbol defined once.
