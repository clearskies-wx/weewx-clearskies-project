# ROUND D5/D6 BRIEF — beach-profile card redesign + per-break zones + heat-map smoothing

**Identity:** dashboard implementation round for D5 (beach-profile card redesign,
operator-approved mockup 2026-08-05: "looks so much better... much more readable"),
D6 (per-break zones, operator-approved), and the operator's standing heat-map
smoothing request ("this is why i want the smoothing on the heat map, so a few
transects zeroing out does not make a difference"). Lead: coordinator. Implementer:
clearskies-dashboard-dev. Repo: `repos/weewx-clearskies-dashboard`, main at `96f5478`
(verify; STOP if different). Tests: you update/extend the component tests you touch —
this round's card tests are yours (the dedicated test-author round is for the marine
physics, not this).

## Design authority

`docs/planning/mockups/beach-profile-redesign-mockup.html` (meta repo, D5 iteration 3)
is the APPROVED design. Open it in a browser and read its inline script — it was built
from a real live payload and its rendering decisions (band geometry, water/sand
layering, whitewater treatment, legend, chips, axis treatment, theme tokens) are the
spec. Reproduce the design faithfully in React/ECharts-or-SVG as the existing
component architecture dictates — the mockup's LOOK is binding; its implementation
technique (vanilla JS + SVG) is not. Where the mockup and the existing card conflict,
the mockup wins. DESIGN-MANUAL.md is the authority for tokens/theming — use the
project's existing design tokens where they exist rather than hardcoding the mockup's
hex values; where the mockup introduces colors with no token equivalent, map them to
the nearest token or add component-scoped CSS variables consistent with the manual.

## Data contract (read docs/manuals/API-MANUAL.md beach-profile section before coding)

The live payload already carries everything you need (Round P + Z, deployed):
`zones` (impact/foam with foam ending at the tide-aware waterline), `perBreakZones`
(per-break impact/foam bands, ft, `units.breakDistance = ft`), `tideLevel`,
`waterlineDistance`, `beachElevation`, `waveShapes`, `jackingFactors`, break points.
A marine physics round (Round W) is about to redeploy and will change VALUES (break
positions/counts, Hs profile) but NOT the wire shape — build against the shape, make
no assumptions like "always exactly 2 breaks" or "foam always non-empty". Handle 0, 1,
2, and 3+ breaks gracefully.

## Deliverables

**D5.1 — card rebuild.** `BeachProfileChart.tsx` (and `BeachProfileCardBody.tsx` as
needed) re-rendered to the mockup: profile fill (sand), water surface with deep→mid
gradient, whitewater treatment over surf zones, impact/foam band rendering, waterline
placement from `waterlineDistance`, legend per mockup, caption/chips per mockup.
Existing behaviors that must SURVIVE the rebuild: transect selector, unit handling
(ft/m per user setting), loading/error states, accessibility (the card must keep
its text alternatives/aria structure per DESIGN-MANUAL).

**D5.2 — zero-width band skip.** Any zone/band whose width is zero or negative
(start == end within float tolerance) is NOT rendered and gets no legend/label
artifact. (Known upstream case: zero-width foam when a break sits at the waterline —
API-MANUAL documents the consumer-side skip as the agreed disposition.)

**D6 — per-break zones default ON.** When `perBreakZones` is present and non-empty,
render per-break impact/foam bands (the mockup's "D6 DEMO" toggle state) as the
DEFAULT and ONLY mode — no user toggle; fall back to the aggregate `zones` bands only
when `perBreakZones` is absent/empty. (Lead design call: the toggle in the mockup was
a review affordance, not shipping UI.)

**D7s — heat-map smoothing (HeatMapCard.tsx).** Display-side smoothing so isolated
transects zeroing out don't punch holes in the rendered surface: apply a centered
median filter over a 5-transect window (clamped at edges) to the per-transect values
at RENDER time. Raw values stay untouched in state/API; the tooltip shows the
smoothed value (one value shown, no raw/smoothed pair — keep it simple). Note the
smoothing in the card's caption or info affordance ("smoothed across neighboring
transects" in plain words). If the card already aggregates in a way that makes
median-5 wrong or redundant, STOP and report what you found instead of adapting the
spec silently — propose in your scope ack.

## Rules

- Files: `src/components/marine/tabs/BeachProfileChart.tsx`,
  `BeachProfileCardBody.tsx`, `HeatMapCard.tsx`, their co-located `.test.tsx` files,
  plus (only if genuinely required) small shared additions under `src/components/
  marine/` — name any such addition in your scope ack BEFORE building it. No API
  client changes, no hook changes, no api/marine repo changes, no config changes.
- Verification before closeout: `npm run build` clean; `npm test` (vitest) with the
  full tail pasted; component tests updated to the new rendering (do not delete
  assertions to make them pass — adapt them to assert the NEW spec, incl. a
  zero-width-skip test and a 1-break and 3-break rendering test and a median-5
  smoothing test with hand-computed literals).
- Git: add/commit/status/log/diff ONLY. No push/pull/fetch/rebase/merge/checkout.
  Never deploy; never touch containers or librewxr. The lead deploys via
  scripts/redeploy-weather-dev.sh after acceptance.
- Architectural changes: none authorized beyond the above. Anything hitting the
  CLAUDE.md 7-trigger list → STOP and report via SendMessage. "Acceptance criteria
  unreachable" / "a document says so" do not authorize you.
- Doc-code sync: this changes UI patterns → list the DESIGN-MANUAL.md and
  DASHBOARD-MANUAL.md sections that need updating in your closeout (the lead routes
  doc edits; do not edit the manuals yourself — they live in the meta repo you must
  not touch).
- Plain-English closeout via SendMessage to "main": commit hashes, build/test tails,
  screenshots not required (lead will verify against the live dev site after deploy),
  list of any mockup details you could not reproduce and why.

## Protocol

BEFORE writing code: SendMessage to "main" a one-paragraph scope ack (deliverables,
files, what you won't touch, verification plan, any shared-file additions you
foresee). WAIT for confirmation.
