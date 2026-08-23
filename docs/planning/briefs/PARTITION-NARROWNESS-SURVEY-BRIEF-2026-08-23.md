# Brief — measure typical partition-band spectral narrowness (ν, Qp, κ) at our 15 m deep-water-reference point (CONSISTENCY-SCORING pre-work, task V2)

**Round:** CONSISTENCY-SCORING pre-coding verification, 2026-08-23. **Lead:** coordinator (Fable). **Teammate:** one compute agent (Sonnet). **Auditor:** none for this task (the lead spot-checks two of your numbers by hand from your saved inputs). **Operator ruling that opened this round:** Q14 in `docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md` — "q14 recommendation is fine" (2026-08-23, chat). A sibling agent (task V1) is verifying the run-length formulas from the literature at the same time; you do not depend on it.

## 1. Task, in plain English

The approved design scores set timing from how NARROW the dominant swell's part of the wave spectrum is (a narrow swell arrives in well-spaced sets; a broad windsea arrives continuously). Nobody has measured what "narrow" actually looks like for a single swell partition at OUR 15 m reference point — the brief found no literature value. Before curves are coded we need the real distribution: for every spectrum we have on disk from the last three days, restrict to each swell partition's frequency band and compute the width numbers ν, Qp and κ, then report their distributions by partition type. Also compute, as an indicator only, what set interval the brief's provisional formulas would give from those widths — so the lead can see whether minutes-scale intervals actually appear.

## 2. Scope block

**Create:**
- `docs/planning/briefs/PARTITION-NARROWNESS-SURVEY-2026-08-23.md` — the report (tables + method + caveats; no narrative padding).
- `scratch/partition-narrowness/` (local, gitignored) — your extraction script(s), the pulled inputs, the computed CSV. Keep the raw inputs (the lead will spot-check from them). Nothing else under `scratch/`.

**Do NOT touch:** any file under `repos/` (no code edits, no tests, no commits), any other doc, any plan. **No writes on any container** — SSH is read-only for you (see §6). **Do not run pytest anywhere.**

**Verification command:** none in the pytest sense. Your closeout SendMessage lists: number of spectra pulled per source, number of partitions analysed, and the two or three headline numbers (median ν of the dominant swell band; fraction of hours with T_set ≥ 2 min under the provisional formula).

**Scope acknowledgment:** before doing any work, SendMessage the lead one paragraph: what you will deliver, what you will not touch, which host paths you will read, and where your local outputs go. Wait for confirmation.

## 3. Reading list (read first, in this order)

1. `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.3 (the two routes and the provisional expressions you will evaluate as indicators), §4.1 (what the 15 m spectrum is), §7 "Before coding, verify" (your task is its second item).
2. `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/trace.py` — `emit()` and `emit_spectrum()` (record shape: the stage name, `spot_id`, `valid_time`, `freqs_hz`, `dirs_deg`, `energy` = E[i_freq][i_dir] in m²/Hz/deg, plus `summary`). The stage you want is `"spec_l2_dwr"` (emitted at `services/swan_runner.py` ~:3953 — read that call site too, and the M-0b comment just above it; the extra fields are `level`, `n_components`).
3. `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/swan_spectral.py` — `parse_specout_file()` (:69–310; parses a SWAN SPEC2D file to the same `{time, freqs_hz, dirs_deg, energy}` records), `compute_total_m0()` (:974 — the df/dd bin-width convention you must reuse), `decompose_spectrum()` (:712–896 — the in-repo partitioner; returns `frequencyRange` per component), `parse_table_pt_partitions()` (:1029 onward — SWAN's own watershed PT* partitions: Hs, Tp, Dir, Dspr per partition; note the absence-signal comments).
4. `docs/reference/swan-commands-extract.md` — the SPECOUT / Appendix D spectral-file section and the "Spectral partitioning output (PT* quantities)" section, ONLY if you need to understand the file formats beyond what the parsers document. Do NOT web-search SWAN behaviour; the manual is local.
5. `reference/clearskies-dev.md` — SSH access section (host alias `librewxr`, `ssh -F .local/ssh/config librewxr "<cmd>"`), and CLAUDE.md "SSH access to containers — HARD RULES".

## 4. Inputs (lead verified on 2026-08-23 ~14:30Z)

On host `librewxr` (SSH alias `librewxr`; FQDNs/aliases only, never raw IPs in anything you write):

- Trace files: `/var/log/weewx-clearskies/marine-trace-20260821.jsonl` (2.85 GB, 568 `spec_l2_dwr` lines), `…-20260822.jsonl` (2.83 GB, 556 lines), `…-20260823.jsonl` (1.38 GB as of 09:39Z, 266 lines). **Never copy whole files.** Extract on the host with a read-only pipeline and stream only the matching lines home, e.g. `ssh -F .local/ssh/config librewxr "grep -h '\"spec_l2_dwr\"' /var/log/weewx-clearskies/marine-trace-2026082*.jsonl" > scratch/partition-narrowness/spec_l2_dwr.jsonl`. Confirm the JSON field name for the stage from `trace.emit()` before grepping. Runs are hourly and forecast windows overlap, so the SAME valid_time appears many times — dedupe by (spot_id, valid_time) keeping the latest record (file order = emission order) AND report the count before/after dedup.
- Latest full run's DWR outputs: `/var/lib/weewx-clearskies/swan/level2/SPEC_DWR_1.txt` and, if present, `/var/lib/weewx-clearskies/swan/level2/TABLE_DWR_1.txt` (SWAN's watershed PT* partitions for the same point and timesteps). Also `/var/lib/weewx-clearskies/swan/stationary/level2/` equivalents. `cat` them home (they are small text files). Read the directory listing first (`ls -la`) and record file mtimes in the report.
- Python: local machine has Python 3.14 with numpy 2.4 / scipy 1.17 — use them. Import the repo's parsers by putting `repos/weewx-clearskies-marine` on `PYTHONPATH` (pure-python modules; no install). Do not pip-install anything.

## 5. Per-deliverable spec — what to compute

Per spectrum (each deduped trace record, and each timestep of the SPEC_DWR file):

1. **1-D spectrum** S(f) = Σ_j E[i][j]·dd_j using the repo's bin-width convention (`compute_total_m0`); report total m0, Hs = 4√m0, Tm01, Tm02, Tp (peak bin), ν_total, Qp_total.
2. **Partitions and bands — two definitions, both reported:**
   - (P) **Production partitions**: where `TABLE_DWR_1.txt` exists for the same timestep, SWAN's PT* partitions (Hs, Tp per partition). Band for partition k: in frequency, from the midpoint between its peak frequency and the next-lower-frequency partition's peak frequency to the midpoint toward the next-higher one; outermost partitions extend to the spectrum edge. (Lead call — the PT* table gives no band bounds; this half-way rule is the working definition. Flag in the report if it produces obviously wrong bands, e.g. a band that contains almost none of the partition's own Hs² — check Σ band m0 vs (Hs_PT/4)² and report the ratio distribution.)
   - (D) **Repo partitioner**: `decompose_spectrum()` on the same 2-D spectrum; use its `frequencyRange` as the band. Applies to every spectrum (trace records have no PT table).
   Where both exist for a timestep, report how often the dominant partition's period agrees within 10 %.
3. **Per partition band** (dominant = highest Hs; also secondary): m0, Hs_k, Tm01_k, Tp_k, **ν_k**, **Qp_k**, **κ_k** where κ_k = | ∫_band S(f)·exp(i·2π·f·Tm01_k) df | / m0_k (the modulus of the normalised complex autocorrelation at one mean-period lag — the Battjes & van Vledder working definition per the brief; task V1 may refine it, which would be a one-line change in your script — write the lag and the normalisation as parameters). Also compute κ at lag Tm02_k and at lag Tp_k so the sensitivity is on the table.
4. **Indicator only (not a result to be believed yet):** the brief's provisional envelope-route numbers for the dominant band at ρ = √2: N_set = 1/(√(2π)·ν·ρ), N_rep = e^{ρ²}/(√(2π)·ν·ρ), T_set = N_rep × Tm01_k; plus the two-swell beat T_beat = 1/|1/Tp₁ − 1/Tp₂| whenever the secondary holds ≥ 25 % of the summed partition m0. Label the column "provisional (V1 verifying)".
5. **Classification** of each partition: use the repo's `_classify_period()` convention (swell / windsea etc. as it defines them) so the tables group the way the scorer will.

**Report tables (medians, 10th/90th percentiles, n):**
- ν, Qp, κ(Tm01) for the dominant band by classification and by definition (P vs D); same for ν_total for contrast.
- Distribution of provisional T_set (minutes) and N_set for the dominant band; fraction of hours with T_set ≥ 2, ≥ 5, ≥ 10 min; fraction where the beat override fires.
- κ sensitivity to lag choice (Tm01 vs Tm02 vs Tp): median absolute difference.
- Band-sanity ratio for definition (P) (item 2).
- Per-spot breakdown if more than one spot_id is present.
- Spectral axis facts: nfreq, ndir, frequency range and spacing (log? linear?), direction step — these bound how well ν can be resolved; say so in one sentence.

**Caveats section (mandatory):** three days only (retention caps at 3 trace files); what sea states were present (range of Hs/Tp) so the reader knows what the sample covers; which of the two band definitions you trust more and why.

## 6. Lead calls (follow, do not re-derive)

- Read-only on the container. `grep`/`cat`/`ls` over SSH only. You create nothing on `librewxr`. If a command would write there, don't run it — ask.
- SurfBeat is removed from the system (operator, 2026-08-23). Ignore any SurfBeat lines in files you read; write nothing about it.
- The provisional formulas in item 4 are NOT yours to correct — V1 owns that. Your job is the measured widths; the indicator columns just make them readable.
- No plots required; CSV + markdown tables. If a plot is trivial and helps, a PNG under `scratch/partition-narrowness/` is fine, referenced from the report by relative path.
- The `deep-research` skill is banned. No web use should be needed; if a definition is unclear, ask the lead.

## 7. Open questions to surface (SendMessage), not resolve

- If the trace records turn out NOT to carry the energy matrix (`include_matrix` False) for `spec_l2_dwr`, stop and report — the survey then runs on the SPEC_DWR files only.
- If `TABLE_DWR_1.txt` is absent, say so; definition (P) is then unavailable and you report (D) only.
- If the 15 m-point spectrum's frequency spacing is too coarse to resolve ν below some value, quantify it (the smallest ν a single-bin partition can show) and flag it.

## 8. Mandatory blocks

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself. (For this task: do not commit at all — the lead commits your report.)

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

**Tone:** concise, direct, no filler. Numbers with units; every table column defined once.
