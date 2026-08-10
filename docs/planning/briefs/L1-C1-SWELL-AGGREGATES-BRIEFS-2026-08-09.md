# ROUND BRIEFS — C1: Current Swell Conditions card aggregates (three dispatches, one file)

**Round identity:** Phase C task C1. Lead: coordinator (session 6). Three sequential
dispatches: (1) server half `clearskies-api-dev` (marine repo — queues behind the S1+S4a
round and A1 on that repo, lead states HEAD at dispatch); (2) API KATs
`clearskies-test-author` (marine repo, after 1); (3) card half `clearskies-dashboard-dev`
(dashboard repo, after 1's payload shape is live on weather-test or lead-pasted). Auditor:
`clearskies-auditor` at Gate C (with C2's pending rows).

**Authorization:** register row **P13** (additive wire-shape change, eligibility rule
server-side; operator swell-card instruction 2026-08-08). R5 is CLOSED (its
`endpoints/surf.py` sections are frozen core — C1 touches ONLY the headline/summary
assembly section the plan names).

**Common reading list (all three):** plan §C1 in full (the spec, verbatim — eligibility
rule, min/max heights, energy-weighted period with the worked example, additive-only,
KAT list, accept row); §Gate C rows; register row P13.

## Dispatch 1 — server half (`clearskies-api-dev`, marine repo)
**Files:** `endpoints/surf.py` headline/summary assembly section ONLY (NOT the R5
breakPoints/zones sections — Gate C diffs your commit against R5's sections);
`docs/contracts/openapi-v1.yaml` (additive fields).
**Do NOT touch:** the 1D pipeline, per-partition machinery (READ it, never modify),
providers, services, tests, dashboard repo, API-MANUAL (lead's doc-sync).
**Design:** plan §C1 verbatim. Fields: `swellHeightMinFt`/`swellHeightMaxFt`,
`faceHeightMinFt`/`faceHeightMaxFt`, `combinedPeriodS`. Eligibility: wind swell with
period < 5.0 s excluded; if NOTHING is eligible, aggregate over ALL components (never
blank). Energy weights `Hs_i²`. Additive only — no existing field changes shape or
meaning.
**Verification:** the test files matching `endpoints/surf.py` + `tests/services/`,
`.venv-round4`, pre/post counts, 0 new failures. Scope-ack before code.

## Dispatch 2 — API KATs (`clearskies-test-author`, marine repo)
**Files:** new KAT file(s) only (names in scope-ack).
**KATs (plan §C1 list, verbatim):** eligibility boundary (4.9 s wind swell excluded,
5.0 s included); all-excluded fallback (aggregates over all components, never empty);
weighted-period arithmetic pin (the plan's worked example: (1.5²·16.4 + 1.1²·12.8)/
(1.5²+1.1²) ≈ 15.1 s); single-swell collapse (min = max, one number). Falsifiability
transcripts per rules/verification.md (Gate C mutates weights Hs² → Hs¹ and your KAT
must fail).
**Do NOT touch:** source files, existing tests, meta repo.

## Dispatch 3 — card half (`clearskies-dashboard-dev`, dashboard repo)
**Files:** the swell-conditions card component (exact name resolved at YOUR scope-ack
from the repo) + its vitest file (same commit — stale-test rule).
**Design:** dumb renderer of the server fields: "min–max ft" (single value collapses to
one number); combined period one number, one decimal. NO eligibility logic client-side
(Gate C greps for a dashboard reimplementation — its presence fails the gate). The
incoming-swell table is UNCHANGED.
**Verification:** the card's vitest file + affected suites, pre/post counts; bundle
per-chunk baseline recorded (entry + marine route chunk, gzip).

## MANDATORY BLOCKS — all three comply verbatim
The three blocks (git restrictions; stale-test; architectural) from `rules/agents.md`.
Scope-ack via SendMessage to "main" BEFORE ANY CODE, every dispatch. Tone: concise.
