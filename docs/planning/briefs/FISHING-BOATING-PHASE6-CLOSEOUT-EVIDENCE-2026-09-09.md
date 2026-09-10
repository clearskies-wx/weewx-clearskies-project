# Fishing/Boating Phase 6 closeout evidence — 2026-09-09

This is an evidence record, not a gate-passed declaration. All timestamps are
UTC unless stated otherwise.

## Deployed state

- Dashboard checkout on `weather-dev`: `5d4e09e`; published
  `/var/www/clearskies/index.html` was observed at `2026-09-09 22:38:09 UTC`.
- Marine service on `librewxr.shaneburkhardt.com`: `active`; main process start
  time `2026-09-09 22:55:24 UTC`; deployed checkout `b98bbae`.
- Fresh public detail-route checks returned `200` for `/api/v1/marine/huntington-harbor`,
  `/api/v1/fishing/huntington-harbor?selectedSpecies=kelp_bass`, and
  `/api/v1/tides/huntington-harbor`.

## Fresh source-to-field ledger

At `2026-09-09 23:36:32` the public Marine response named:

| Field/context | Source | Valid time / detail |
| --- | --- | --- |
| Location conditions and pressure | `aeris` | `2026-09-10T00:00:00Z` |
| Surface water temperature | `ofs:WCOFS` | `2026-09-09T06:00:00Z`, depth `0 m` |
| Offshore observation | NDBC `prjc1` | `2026-09-09T22:18:00Z`, `9.61 km` |
| Regional marine text | NWS CWF | `2026-09-10T01:00:00Z`–`2026-09-10T13:00:00Z`; issued `2026-09-09T20:07:00Z` |
| Tide data | CO-OPS | public Tide detail response, `200` |
| Selected active Fishing period | Kelp bass | score `100`, status `active`, Aeris pressure and `ofs:WCOFS` depth `12 m` |

The current Harbour model-wave forecast and the offshore record's wave-height
fields were null in the fresh response. No offshore value was substituted as a
selected-location wave value.

## NWS setup-save enforcement addendum

The Gate 3–4 independent report correctly says its own read-only audit did not
exercise setup saving. That limitation is superseded only for the unavailable-
NWS rejection case: the coordinator's authenticated, in-memory NWS Fishing
`POST /setup/apply` for Huntington Harbour returned HTTP `422` before any
configuration or secret persistence and named the unavailable hourly pressure
series. The proxy credential remained inside the privileged remote process and
was not printed or recorded. A successful NWS save at a pressure-capable
location remains a separate, unexercised case.

## Browser evidence

Primary coordinator browser session on the live Harbour page:

- Desktop Boating: 18 cards; horizontal region `scrollWidth=5388`,
  `clientWidth=1201`; one `Scroll right` action advanced `scrollLeft` to
  `958.67`.
- Desktop Fishing: 53 species controls and 18 forecast cards; horizontal
  species region `scrollWidth=7474`, `clientWidth=1201`; unavailable periods
  rendered explicitly. Arrow-right from the Boating tab selected Fishing.
- Mobile 390 px: Fishing accordion opened; Kelp bass selection was pressed;
  forecast region had 18 cards with `scrollWidth=5388`, `clientWidth=303`.
- Theme control progressed Auto → Light → Dark. In Dark state the accessible
  label was `Theme: dark — click to switch to system preference`, document
  theme was `dark`, body background was `oklch(0.145 0 0)`, and body foreground
  was `oklch(0.985 0 0)`. Temporary theme and viewport settings were restored
  after the check.

Independent browser attempt:

- The separate Gate 5 auditor's browser runtime had no available browser, so it
  produced no page-state evidence. Its failure is recorded as inconclusive, not
  as a passing independent check.

## Merged documentation reconciliation

- Documentation reconciliation commit: `0ac3f571`.
- Pull request: #1; merge commit on `main`:
  `ae074e5c8ece5d0dfd6e0eb95bdbec81ef314d76`.
- Independent documentation review accepted the exact-area runtime-row,
  OpenAPI, NWS pre-write enforcement, Dashboard wording, Operations procedure,
  and stale-plan corrections.
- Validation: the OpenAPI YAML parsed successfully and `git diff --check` was
  clean before commit.

No runtime documentation deployment applies: these are meta-repository
documentation and public-contract source files, not dashboard/API/marine code.

## Gate disposition and remaining condition

| Gate | Current evidence | Disposition |
| --- | --- | --- |
| Gate 1 | Manual, plan, and OpenAPI reconciliation independently accepted; exact-area runtime contract explicit. | Documentation portion supported. |
| Gates 3–4 | Existing real-host report plus the authenticated pre-write NWS 422 addendum. The report's clean-room limitation remains recorded. | Evidence retained; do not call that report a strict results-free audit. |
| Gate 5 | Primary desktop/mobile/theme/interaction evidence above. Independent browser auditor could not obtain a browser. | Primary evidence present; independent-browser limitation recorded. |
| Gate 6 | Fresh public API captures, process state, field ledger, and merged documentation. | Not final. |

The approved plan requires operator sign-off on the Huntington Harbour visual
result. Until that sign-off is supplied, do not mark Gate 5, Gate 6, or the
remediation plan complete.
