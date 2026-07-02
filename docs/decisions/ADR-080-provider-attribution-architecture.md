---
status: Accepted
date: 2026-07-01
deciders: shane
supersedes:
superseded-by:
---

# ADR-080: Provider attribution architecture

## Context

We prototyped attribution footers on forecast cards, the AQI card, and the alert banner. The visual design is settled (CardFooter, 32px standard / 16px compact logos). Three problems:

1. **Plugin contract violation.** Cards import a hardcoded `ForecastAttribution` component from `components/forecast/`, violating the host-owns-chrome principle established in the card plugin contract (ADR-064, consolidated into DASHBOARD-MANUAL §8). The AQI card also imports from `forecast/` — wrong location.
2. **Incorrect attribution text.** All providers show "Powered by" + logo. Each provider's ToS mandates specific wording (e.g., Xweather requires "powered by Vaisala Xweather", OpenWeatherMap requires "Weather data provided by OpenWeather"). See PROVIDER-ATTRIBUTION-BRIEF.md for the full table.
3. **No i18n mechanism.** Attribution text is hardcoded English with no flag to indicate whether translation is appropriate. ToS-mandated text must not be translated; a future provider might allow it.

Additionally, the API's `ProviderCapability` dataclass and `CapabilityDeclaration` response model have no attribution metadata. The dashboard duplicates provider metadata in a hardcoded `PROVIDERS` map.

## Options considered

| Option | Verdict |
|---|---|
| A. API declares attribution metadata on ProviderCapability; dashboard host renders | **Selected.** Single source of truth, no card-level attribution imports, correct ToS text set once in the provider module. |
| B. Dashboard-only: move the PROVIDERS map to a shared config, cards still render | Rejected — cards violate the plugin contract; the API already has the source field on responses. |
| C. API serves rendered attribution HTML | Rejected — mixing presentation into the data layer; logo selection depends on the dashboard's active theme. |

## Decision

**Attribution metadata lives on the API's `ProviderCapability` dataclass and is exposed via `GET /api/v1/capabilities`.** The dashboard host (Now page, Forecast page) renders attribution using a shared `ProviderAttribution` component — cards never import it.

Two attribution systems coexist:

1. **Card footer attribution** — for data providers (forecast, AQI, alerts, earthquakes, seeing). Host-rendered `ProviderAttribution` component. Driven by the capabilities API's `attribution` block. The host reads `source` from the card's dataBag response, matches it against capabilities, and renders a footer when `attributionRequired` is true.

2. **Leaflet map attribution** — for map tile/overlay providers (basemaps, radar, faults, geographic features). Leaflet's built-in attribution control. Basemaps use dashboard constants; overlays are API-driven (`RadarFrameList.attribution`, `FaultFeatureCollection.attribution`). No change to this system.

Key fields on `ProviderAttribution` (API dataclass, frozen):

| Field | Type | Purpose |
|---|---|---|
| `attribution_required` | `bool` | Whether the host must render a footer for this provider |
| `display_name` | `str` | Human-readable provider name (for about page, fallback text) |
| `attribution_text` | `str` | ToS-mandated wording rendered verbatim |
| `url` | `str` | Provider URL (linked from attribution text) |
| `text_translatable` | `bool` | False = render verbatim (ToS-mandated English). True = pass through `t()` (future use) |
| `text_language` | `str` | BCP-47 language tag for the attribution text (default "en") |
| `logo_required` | `bool` | Whether the provider's ToS mandates a logo |
| `do_not_use_logo` | `bool` | Whether the provider's ToS forbids logo use (e.g., IQAir, AstronomyAPI) |

`text_translatable` is False for ALL providers in v0.1. ToS-mandated text must not be translated. The flag exists so a future provider that permits translation can be enabled without code changes — just set `text_translatable: True` and add locale keys.

Card designers must account for the attribution footer in their content area budget: 53px standard, 23px compact (tile footprint).

Multi-provider cards (one card showing data from two providers): avoid. If unavoidable, the host renders a combined single-line footer. This is a design constraint, not a technical limitation.

## Consequences

- **API change.** `ProviderCapability` gains an `attribution` field. `CapabilityDeclaration` response model gains a matching `ProviderAttributionResponse`. The capabilities endpoint maps the new field. Every provider module populates `attribution=ProviderAttribution(...)` in its CAPABILITY declaration.
- **Dashboard refactor.** `ForecastAttribution` moves to `components/shared/ProviderAttribution.tsx` and becomes a pure renderer (props-driven, no internal lookup). All card-level attribution imports are removed. The Now page and Forecast page render attribution at the host level.
- **Logo reorganization.** Logos move from `src/assets/providers/` (Vite build-time imports) to `public/providers/` (static, convention-based lookup by `provider_id`). No rebuild needed when logos change.
- **About page.** Derives provider names from the capabilities API instead of a hardcoded `PROVIDER_INFO` map.
- **Correct ToS compliance.** Each provider's footer shows their mandated wording, not generic "Powered by".
- **Future card ingestion.** When a card import system ships (v2), the ingestion process reads the card manifest, discovers attribution requirements + logos, copies logos to `public/providers/`, and registers the provider in capabilities. This ADR documents the interface; no ingestion code is built now.

## Acceptance criteria

- [ ] `ProviderCapability` has an `attribution: ProviderAttribution | None` field. `mypy` clean.
- [ ] `CapabilityDeclaration` has an `attribution: ProviderAttributionResponse | None` field. Pydantic serialization round-trips.
- [ ] `GET /api/v1/capabilities` returns `attribution` blocks for all providers that declare them.
- [ ] Each provider's `attribution_text` matches the PROVIDER-ATTRIBUTION-BRIEF.md requirements table.
- [ ] Zero card components import `ForecastAttribution` or `ProviderAttribution`. Only host pages (`now.tsx`, `forecast.tsx`) and `shared/ProviderAttribution.tsx` definition reference it.
- [ ] Now page and Forecast page render attribution footers identically to the current prototype but driven by capabilities.
- [ ] `text_translatable` is False for all providers in v0.1. Attribution text is never passed through `t()`.
- [ ] Logos are in `public/providers/` with `{provider_id}.{ext}` naming convention.
- [ ] About page derives provider names from the capabilities API (no hardcoded `PROVIDER_INFO`).
- [ ] DASHBOARD-MANUAL §8, PROVIDER-MANUAL §12, DESIGN-MANUAL §6, and API-MANUAL §12 all describe the same architecture.

## Implementation guidance

- **API dataclass location:** `providers/_common/capability.py`, add `ProviderAttribution` frozen dataclass above `ProviderCapability`.
- **API response model location:** `models/responses.py`, add `ProviderAttributionResponse` Pydantic model with camelCase fields.
- **Capabilities endpoint:** `endpoints/capabilities.py`, map `cap.attribution` to the response in the existing loop (lines 71–94).
- **Provider modules:** Each module's `CAPABILITY = ProviderCapability(...)` gains `attribution=ProviderAttribution(...)`. The `attribution_text` values come from the PROVIDER-ATTRIBUTION-BRIEF.md table.
- **Dashboard component:** `components/shared/ProviderAttribution.tsx` — pure renderer receiving `attributionText`, `logoLight`, `logoDark`, `logoRequired`, `doNotUseLogo`, `compact` as props. Logo filenames derived from `provider_id` by convention (`/providers/{id}.svg` or `.png`), not a lookup map.
- **Host rendering in Now page:** After rendering `<CardComponent>`, the Now page checks `dataBag[endpoint].source` against capabilities. If `attributionRequired`, renders `<ProviderAttribution>` as a sibling. Uses React Fragment or inherits grid span to avoid layout disruption.
- **Out of scope:** Leaflet map attribution (unchanged), card ingestion system (documented only), translated attribution text (infrastructure built, not exercised).

## References

- Related: ADR-064 (card plugin contract), ADR-006 (compliance model), ADR-010 (canonical data model)
- Research: [PROVIDER-ATTRIBUTION-BRIEF.md](../briefs/PROVIDER-ATTRIBUTION-BRIEF.md)
- Execution: [PROVIDER-ATTRIBUTION-PLAN.md](../planning/PROVIDER-ATTRIBUTION-PLAN.md)
