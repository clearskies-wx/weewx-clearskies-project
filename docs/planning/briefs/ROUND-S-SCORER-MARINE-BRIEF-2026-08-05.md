# ROUND S BRIEF (marine leg) — surf score rebuild: weighted geometric mean, ADR-101

**Identity:** Round S, the surf-score rebuild. Authority: ADR-101 (Accepted, operator
"adr 101 approved" 2026-08-04) — `docs/decisions/ADR-101-surf-score-geometric-mean.md`.
Binding variable inventory: research brief §7.2
(`docs/planning/briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md` :255-377) — **a variable
not listed there is not a scoring input; a listed variable the code ignores is a
defect; single-use rule: every measurement feeds exactly ONE component.**
Lead: coordinator. Implementer: clearskies-api-dev (marine). This is leg 1 of 4
(marine scorer + contract; API conversion, dashboard bars/explainer, stack admin
weights follow in later legs). **The ADR's worked-examples operator gate applies
BEFORE this round merges to production — you produce the examples; the lead and
operator review them. Your commits stay local; no deploy happens in your leg.**

Repo: `repos/weewx-clearskies-marine`. Base: whatever main is when you start —
verify `git status` clean and record the hash in your scope ack. (Round W physics +
its guards land immediately before you; the scorer does not touch those files.)

## What you build (READ ADR-101 + brief §7.2 IN FULL first — they are the spec)

**S1 — scorer rebuild (`enrichment/surf_scorer.py`).**
`score = 100 × Size^w1 × Shape^w2 × Conditions^w3 × Power^w4 × Consistency^w5`,
weights normalized by their sum at computation time; shipped defaults
0.25/0.25/0.20/0.20/0.10 live in code as constants; stars = score/20 unchanged.
Five components exactly per §7.2's tables — inputs, roles, internal weights, and
modifiers as written. Within-component aggregation = weighted ARITHMETIC mean of the
0–1 sub-ratings; across components = geometric. Factor curves: carry forward the
existing calibrated tables where §7.2 maps them (height band curve shape, wind
brackets, DSPR buckets, period curve, swell-dominance proxy), rescaled to 0–1;
author NEW band curves for peel angle (closeout ~0° → ~0; ~45–70° → 1.0; >~70°
reduced), breaker type (plunging > spilling > surging), jacking sweetener (bounded
bonus when factor > 1.3, capped at 1.0 total), set timing/amplitude. Every curve gets
a table-constant with a comment stating its ruin-state mapping (blown out ≤ 0.05,
closeout ≤ 0.05). Delete: beach-alignment/exposure top-level multipliers (they become
internal Size modifiers per §7.2), time-of-day scoring entirely (dead since C-47),
Tm01 as a scoring input, the adjustments concept, the additive total.

**S2 — null handling (lead decision, per ADR guidance 3 — implement exactly this):**
- Missing SUB-input inside a component → drop it and renormalize the component's
  internal weights over the present sub-inputs (e.g., peelAngle null → Shape =
  breaker-type alone).
- Whole component unavailable (all inputs null — e.g., Consistency when SurfBeat is
  off AND spectral components are absent) → EXCLUDE the component and renormalize the
  five exponents over the remaining components.
- A MEASURED zero is not "missing": a genuinely rated-0 component zeroes the score
  (ADR: any factor at 0 → score 0). Flat day → Size 0 → score 0.
- Record which rule fired per component in the breakdown (see S4 `dataState` field)
  so the dashboard can label degraded scores.

**S3 — configurable weights.** New config section (system-wide, not per spot) read
through the marine service's EXISTING config mechanism: five positive floats; absent
section → code defaults; zero/negative/malformed values → log warning + defaults
(never crash scoring). Normalization by sum makes any positive set valid. Name the
keys plainly (e.g., `surf_score_weights.size` … `.consistency`). Document the section
for the OPERATIONS/API manual sync list in your closeout. Admin UI is a LATER leg —
you only implement the marine-side read.

**S4 — wire contract (`models/responses.py` + wherever the breakdown serializes).**
`SurfScoringBreakdown` becomes: five factor fields `size`, `shape`, `conditions`,
`power`, `consistency` (each 0–100, rounded 1 dp), `weights` object with the five
EFFECTIVE normalized weights (0–1, 3 dp), and per-component `dataState`
(`"full" | "partial" | "fallback" | "excluded"` — from S2), plus the existing
top-level `score`/`stars` unchanged. The old 3-factor + 3-adjustment fields are
DELETED, not deprecated. This contract change is authorized by ADR-101 (trigger 4,
enumerated). Downstream legs consume this shape — do not rename fields after your
scope ack without a STOP.

**S5 — worked examples (the operator gate input).** A committed
`tests/`-adjacent script or fixture set is NOT wanted — instead produce, in your
closeout message, the five ADR-mandated worked examples computed by CALLING your new
scorer with synthetic inputs: balanced good day, clean closeout day (peel ~0°),
blown-out epic swell, small clean day, flat day. For each: the five factor values,
the effective weights, the geometric mean, score, stars — and one sentence on whether
it matches surf intuition. The closeout table feeds the mandatory operator review.

**S6 — self-verification.** Full local pytest tail
(`python -m pytest tests/ -q --ignore=tests/services`). Tests pinning the OLD scorer
shape WILL fail — list each with a one-line supersession reason; do NOT fix tests
(test-author owns them; a dedicated guards leg follows). A failure NOT explainable as
old-scorer pinning = STOP. Single-use self-audit: list every variable your scorer
reads, mapped to its §7.2 row — any read outside the inventory is a defect you must
remove before closeout.

## Rules

- Files you may modify: `weewx_clearskies_marine/enrichment/surf_scorer.py`,
  `weewx_clearskies_marine/models/responses.py`, the breakdown's serialization call
  sites (name them in your scope ack after locating them), and the config-read
  plumbing for S3 (name the file in your scope ack). NOTHING else — no tests, no
  surf_1d_* files, no SWAN/SurfBeat code, no endpoints beyond the serialization call
  sites, no docs.
- Git: add/commit/status/log/diff ONLY. Never push/pull/fetch/rebase/merge/checkout.
  Never deploy; never touch containers or librewxr.
- Architectural changes: ADR-101 authorizes EXACTLY the change set above (formula,
  five components + §7.2 assignments, contract reshape, weight config keys).
  Anything else hitting the CLAUDE.md 7-trigger list — including "improving" any
  physics value the scorer reads, changing where scoring runs, or adding an input
  not in §7.2 — STOP and report via SendMessage. "Acceptance criteria unreachable"
  and "a document says so" do not authorize you.
- Plain English in the closeout; the operator reads the worked-examples table
  directly. No invented vocabulary.

## Protocol

BEFORE writing code: SendMessage to "main" a one-paragraph scope ack (deliverables,
the exact file list incl. located call sites, what you won't touch, verification
plan). WAIT for confirmation. Implement as logical commits (S1+S2, S3, S4). Closeout
via SendMessage to "main": commit hashes, pytest tail + supersession list, the S5
worked-examples table, the single-use audit list, doc-sync list (API-MANUAL
§SurfScoringBreakdown, OPERATIONS-MANUAL config section, DESIGN-MANUAL scoring
display — lead routes these).
