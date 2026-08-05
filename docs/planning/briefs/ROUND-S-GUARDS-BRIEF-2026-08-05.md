# ROUND S GUARDS BRIEF — tests for the 5-component geometric-mean scorer

**Identity:** test-author leg for Round S (ADR-101, marine repo at `766190c` — verify;
STOP if different). The scorer commits are LOCAL and operator-gated — do not push.
Read first: ADR-101, research brief §7.2 (:255-377), the S1b ruling record in
docs/planning/scratch/EYEBALL-FIX-EXECUTION-SCRATCH-2026-08-04.md ("S1b RULING"
section), rules/verification.md (known-answer mandate), rules/coding.md. Then read the
new `enrichment/surf_scorer.py` in full.

## Deliverables

**T-S1 — geometric-mean KAT.** Fixed synthetic inputs → hand-computed factor values
and total (literals + arithmetic in comments, independently derived from ADR-101's
formula, not from the code). Cover: all-balanced (score 100), one factor at
intermediate value (e.g. shape 0.43 → total 81.0 — pin the arithmetic the lead
hand-verified), any-factor-zero → score 0.

**T-S2 — S1b ruin-override pins.** (a) peel ≤ 10° pins Shape to ≤ 5.0 on the wire
regardless of breaker type and jacking (assert sweetener cannot un-ruin); (b)
blown-out wind pins Conditions to ≤ 5.0 regardless of DSPR/cross-swell; (c) peel just
ABOVE the threshold does NOT pin; (d) the two ADR worked-example scenarios land at
their S1b closeout values (47.3 / 47.1 — recompute by hand, cite the lead's math).

**T-S3 — null-handling pins (S2 rule).** (a) missing sub-input renormalizes internal
weights (peel None → Shape = breaker alone); (b) whole component unavailable →
excluded + exponents renormalize (assert weights on the wire reflect it); (c) measured
zero ≠ missing (flat day → size 0, score 0, size dataState "full"); (d) each dataState
value ("full"/"partial"/"fallback"/"excluded") appears under the right construction.

**T-S4 — config weights.** Absent section → defaults; malformed/zero/negative value →
warn + default (caplog); custom positive weights normalize by sum (hand-computed
effective weights on the wire); weights affect the total per the formula (one literal
check).

**T-S5 — wire-contract pins.** SurfScoringBreakdown has exactly the five factor
fields + weights{} + dataState{}; old fields (waveHeight/wavePeriod/waveOrganization/
organization*/beachAlignment/directionalExposure/timeOfDay) are GONE (assert absent
from the model). Single-use guard: a grep-style test asserting `surf_scorer.py` never
references `tideLevel`/`breakingHawaiianHeight`/`igWaveHeightM` (the explicit
not-an-input list §7.2).

**T-S6 — repair the 7 stale tests** in `tests/test_swell_dominance_ratio.py` (the
complete supersession list — every one pins the deleted old scorer shape:
`spectral_components` param, `_swell_dominance_score`, `_ORG_WEIGHT_SWELL_DOMINANCE`,
`.scoring.organizationSwellDominance`/`.waveOrganization`). The CONTINUOUS-ratio wire
field itself (`swellDominance`) still exists (it feeds Consistency's fallback) — keep
the tests that pin the ratio-on-wire behavior by rewriting them against the new shape;
DELETE (with a supersession comment) only those pinning the removed bucketing/organization
composite. Do not weaken anything else.

## Rules

Files: new `tests/test_surf_score_s*.py` (your naming) + exactly
`tests/test_swell_dominance_ratio.py` for T-S6. NO production code — a test that
can't pass without a prod change = STOP and report. Full suite at closeout
(`python -m pytest tests/ -q --ignore=tests/services`; in a sandbox without network
you may additionally ignore test_facing_divergence_check.py / test_tls.py /
test_structure_coordinates_configobj_roundtrip.py, stating so) — expect 0 failures
beyond (possibly) the known flaky test_h4_chunked_json timing test; report the tail.
Git add/commit/status/log/diff only; NO push. No architectural changes; CLAUDE.md
7-trigger list → STOP. Scope ack to "main" BEFORE code; WAIT for confirmation.
Closeout: commit hashes, full tail, KAT hand-arithmetic.
