# ROUND S LEGS 2–4 — api / dashboard / stack (one file, three briefs)

Shared context for all three legs: ADR-101 (Accepted) rebuilt the surf score as a
weighted geometric mean of five 0–100 components. The marine leg is DONE (marine repo
LOCAL commits 53d4315..766190c, operator-gated). The FROZEN wire shape of
`SurfScoringBreakdown` (authoritative doc: API-MANUAL §SurfScoringBreakdown, updated
2026-08-05):

```
{ size, shape, conditions, power, consistency: float 0-100 (1 dp),
  weights:   { size, shape, conditions, power, consistency: float 0-1 (3 dp) },
  dataState: { size, shape, conditions, power, consistency:
               "full"|"partial"|"fallback"|"excluded" } }
```
Old fields (waveHeight/wavePeriod/waveOrganization/organization*/beachAlignment/
directionalExposure/timeOfDay) are DELETED. `score` (0-100) and `stars` (1-5)
top-level fields are unchanged.

**Shared rules, all legs:** work on a NEW BRANCH named `round-s-scoring` off current
main of YOUR repo (this keeps main deployable while Round S is operator-gated — do
NOT commit to main). Git: branch/add/commit/status/log/diff only — no push, no merge,
no checkout of other branches after creating yours. No deploys, no containers, no
librewxr. No architectural changes (CLAUDE.md 7-trigger list → STOP via SendMessage);
the wire shape above is FROZEN — if it cannot work as specified, STOP, never adapt it.
Scope ack to "main" BEFORE code; WAIT for confirmation. Closeout with commit hashes +
verification tails.

---

## LEG 2 — api (repos/weewx-clearskies-api, implementer: clearskies-api-dev)

The API companion proxies marine responses and mirrors marine models. Grep-verified
touch points: `models/responses.py` (~:1640-1669 old SurfScoringBreakdown mirror),
`services/marine_enrichment.py`, `services/marine_response_conversion.py`.

Deliverables: (A) reshape the mirrored SurfScoringBreakdown model to the frozen shape
(docstring cites ADR-101 + date). (B) Update every reference in enrichment/conversion:
scores are unitless 0-100 — confirm no unit conversion applies to the five factors
(delete any conversion entries for the removed fields; add none). (C) Verify the
proxy passes the new shape through intact: extend/adjust existing marine-response
tests' fixtures IF the repo's convention is dev-owned fixtures (check how prior marine
reshapes were tested here and follow that pattern; if tests are test-author-owned in
this repo, list needed updates in your closeout instead). (D) Full repo test suite
tail in closeout; failures must be explained (superseded old-shape pins listed
one-line each, pre-existing proven at your branch point).

## LEG 3 — dashboard (repos/weewx-clearskies-dashboard, implementer: clearskies-dashboard-dev)

Read DESIGN-MANUAL scoring sections + ADR-101 Display paragraph first. Current code:
the scoring breakdown UI renders the OLD 3-factor + adjustments shape (locate it —
grep scoringBreakdown / waveOrganization in src/).

Deliverables: (A) five bars, each 0-100 fixed denominator (ADR-096 per-category fill
rule), labeled Size / Shape / Conditions / Power / Consistency (i18n keys, 13-locale
English duplication per repo convention). (B) DELETE the adjustments column/rows UI
entirely (ADR-101: "deleted, not hidden"). (C) Visitor explainer (the ADR's sentence):
"The score is a weighted geometric mean of the five factors — they average together,
but one very poor factor sinks the whole score." — placed per DESIGN-MANUAL card
anatomy (info affordance or caption). (D) Degraded-data labeling from `dataState`
(e.g. a subtle "estimated"/"partial data" marker on non-"full" bars — plain words,
tooltip or suffix, your design call within DESIGN-MANUAL tokens). (E) types.ts:
replace the old breakdown type with the frozen shape. (F) Update co-located tests to
the new shape (fixtures + assertions); KNOWN: the full suite has 12 pre-existing
failures in 3 non-marine files (proven at 96f5478 — alert-icon-map, Grid gap token,
useRealtimeObservation) — do not touch them, scoped runs of your changed areas are
fine per your standing rule. (G) `npx tsc -b` (NOT tsc --noEmit — root tsconfig
checks nothing) + `npm run build` clean; tails in closeout. CAUTION: CSS comments
must not contain literal `--name`-shaped text (Tailwind v4 silently drops the next
declaration).

## LEG 4 — stack admin weights form (locate the admin config UI first)

Implementer: clearskies-api-dev or dashboard-dev depending on where the admin config
UI lives — SCOPE ACK MUST name the repo+files after locating it (the config UI runs
on weather-dev port 9876; its source lives in one of the clearskies repos — find it,
don't guess). Deliverables per ADR-101 guidance 6: a "Surf score weights" admin
section — five inputs pre-filled with current values (defaults if unset),
effective-percentage display (value ÷ sum, live), reset-to-defaults button, reject
zero/negative/malformed at the form; writes flow through the EXISTING admin → API →
marine `/config` path (the admin never talks to the marine service directly — if that
path cannot carry a new section without a new endpoint, STOP and report; trigger 7).
New admin section ⇒ `help.admin.*` keys + Operator Manual listed in closeout for lead
routing.
