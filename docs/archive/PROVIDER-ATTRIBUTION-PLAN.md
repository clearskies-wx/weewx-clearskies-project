# Provider Attribution Architecture — Execution Plan

**Status:** COMPLETE  
**Created:** 2026-07-01  
**Components:** API (`weewx-clearskies-api`), Dashboard SPA (`weewx-clearskies-dashboard`), Docs (`weewx-clearskies-project`)

---

## Context

We prototyped attribution footers on forecast cards, AQI card, and the alert banner to comply with provider ToS (Xweather, OWM, Open-Meteo, IQAir). The visual design is settled — CardFooter with provider logo (32px standard, 16px compact for tiles). But the implementation has three problems: (1) cards directly import a hardcoded `ForecastAttribution` component, violating the card plugin contract (§8); (2) all providers show "Powered by" instead of their ToS-mandated wording; (3) no i18n — hardcoded English, missing locale entries. This plan formalizes attribution into the architecture: the API declares attribution requirements per provider, the dashboard host renders the footer, cards never touch attribution.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §5 WCAG accessibility, §7 build verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind + shadcn/ui). Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. Lint: `ruff check`, `mypy`.

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (~2 min warm)

**Key existing ADRs:**
- ADR-064 — Card plugin contract (archived to DASHBOARD-MANUAL §8): uniform `CardComponentProps` (dataBag, layout, stationTz), self-extraction, host owns chrome
- ADR-010 — Canonical data model: `source: str` field on all API responses
- ADR-006 — Compliance model: operators manage provider ToS compliance

**Key files discovered in research:**

| File | What | Lines |
|------|------|-------|
| `api/providers/_common/capability.py` | `ProviderCapability` dataclass | 28–79 |
| `api/models/responses.py` | `CapabilityDeclaration` Pydantic model | 718–741 |
| `api/endpoints/capabilities.py` | `GET /api/v1/capabilities` handler | 40–105 |
| `dashboard/src/routes/now.tsx` | Now page card rendering loop | 177–197 |
| `dashboard/src/routes/forecast.tsx` | Forecast page (direct imports) | 32–58 |
| `dashboard/src/hooks/useWeatherData.ts` | `useCapabilities()` hook | 648–669 |
| `dashboard/src/lib/card-registry.ts` | Card registry + `CardComponentProps` | 19–27 |
| `dashboard/src/components/forecast/ForecastAttribution.tsx` | Current hardcoded attribution | 1–92 |
| `dashboard/src/routes/about.tsx` | About page with hardcoded `PROVIDER_INFO` | 16–35 |

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase — not batched.

---

## 1. Gap Inventory

### A. Plugin Contract Violations

| # | Issue | Current state | Required state |
|---|-------|---------------|----------------|
| A1 | Cards import `ForecastAttribution` directly | 4 cards import from `components/forecast/` | Host renders attribution; cards never import it |
| A2 | `ForecastAttribution` lives in `forecast/` | Used by AQI card too — wrong location | Move to `components/shared/ProviderAttribution.tsx` |
| A3 | Hardcoded `PROVIDERS` map in dashboard | Duplicates provider metadata | Read from capabilities API |
| A4 | Attribution not in dataBag contract | Cards self-manage attribution | Host injects based on `source` + capabilities |

### B. Attribution Text Errors

| # | Provider | Required wording (ToS) | Current wording |
|---|----------|----------------------|-----------------|
| B1 | Xweather | "powered by Vaisala Xweather" | "Powered by" + logo |
| B2 | OpenWeatherMap | "Weather data provided by OpenWeather" | "Powered by" + logo |
| B3 | Open-Meteo | "Weather data by Open-Meteo.com" | "Powered by" + logo |
| B4 | IQAir | "Powered by IQAir" | "Powered by IQAir" (OK) |
| B5 | NWS | None required | "Powered by" + logo (over-attributing, harmless) |

### C. i18n Gaps

| # | Issue | Files affected |
|---|-------|---------------|
| C1 | "Aeris Weather" in legal.json | All 13 locale files |
| C2 | Missing domain labels (baseMaps, seismicData, astronomical) | 12 non-English about.json files |
| C3 | Attribution text hardcoded in English | `ForecastAttribution.tsx`, `alert-banner.tsx` |
| C4 | No `text_translatable` flag | All attribution text stays English for v0.1 — ToS-mandated, brand names, or no accepted translations (US govt). Flag exists as future infrastructure. |

### D. API Schema Gaps

| # | Issue | File |
|---|-------|------|
| D1 | No `attribution` field on `ProviderCapability` | `capability.py` line 28 |
| D2 | No `attribution` on `CapabilityDeclaration` response | `responses.py` line 718 |
| D3 | No mapping in capabilities endpoint | `capabilities.py` line 71 |
| D4 | `is_observed_source` not exposed in response | `responses.py` (missing) |

### E. Logo Organization

| # | Issue | Current state | Required state |
|---|-------|---------------|----------------|
| E1 | Logos in `src/assets/providers/` (build-time imports) | Vite-hashed into JS bundle | Move to `public/providers/` (static, no rebuild needed) |
| E2 | Inconsistent filenames | `xweather-dark.svg`, `openweathermap-master.png` | `{provider_id}.{ext}` / `{provider_id}-dark.{ext}` convention |
| E3 | "dark" means logo color, not theme | Confusing — "dark" logo used on light theme | `-dark` suffix means "for dark theme" |

**New naming convention:**

| Current file | New file | Meaning |
|-------------|----------|---------|
| `xweather-dark.svg` | `aeris.svg` | Primary (dark-colored, used on light backgrounds) |
| `xweather-light.svg` | `aeris-dark.svg` | Dark theme variant (light-colored) |
| `openweathermap-master.png` | `owm.png` | Primary |
| `openweathermap-negative.png` | `owm-dark.png` | Dark theme variant |
| `nws.svg` | `nws.svg` | Single file, both themes |
| `open-meteo.png` | `openmeteo.png` | Single file, both themes |

**Lookup rule:** Given `source: "aeris"`, dashboard checks `/providers/aeris.svg` (primary) and `/providers/aeris-dark.svg` (dark variant, optional). No map needed — convention-based.

### F. Leaflet Map Attribution

| # | Issue | Current state | Required state |
|---|-------|---------------|----------------|
| F1 | Basemap attributions duplicated across files | Inline strings in `radar-map.tsx` (lines 323, 327, 332) and `seismic.tsx` (lines 132, 136) | Extract to shared constants file |
| F2 | Wind arrow TileLayer missing attribution | `radar-map.tsx:1070` — no `attribution` prop | Add `radarFrameList?.attribution` (same as radar overlay) |
| F3 | Radar/fault overlay attributions | API-driven ✓ (`RadarFrameList.attribution`, `FaultFeatureCollection.attribution`) | No change — already correct |

**Two attribution systems coexist (document in ADR-080):**
- **Card footer attribution** — for data providers (forecast, AQI, alerts). Host-rendered `ProviderAttribution` component. Driven by capabilities API.
- **Leaflet map attribution** — for map tile/overlay providers (basemaps, radar, faults, geographic features). Leaflet's built-in attribution control. Basemaps use constants; overlays are API-driven. LibreWxR attribution is externally controlled via their API response.

### G. Aeris → Xweather Naming Migration (remaining occurrences)

The about page and API `operator_notes` were fixed in the prototype. These remain:

| # | Layer | File(s) | Current text | Fix |
|---|-------|---------|-------------|-----|
| G1 | Stack wizard | `wizard/providers.py` line 66 | `"Aeris Weather"` (display_name) | → `"Xweather (Vaisala)"` |
| G2 | Stack wizard | `wizard/providers.py` lines 72, 119 | `signup_url="https://www.aerisweather.com/signup/"` | → `"https://www.xweather.com/signup/"` |
| G3 | Stack provider docs | `docs/providers.md` lines 109, 113 | `### Aeris Weather`, `Aeris (AerisWeather / Xweather)` | → `### Xweather (Vaisala)` |
| G4 | Stack EULA | `static/EULA.txt` line 44 + 13 locale copies | `Aeris Weather (aerisweather.com)` | → `Xweather (xweather.com)` |
| G5 | API docstrings | `providers/forecast/aeris.py` line 1, `aqi/aeris.py` line 1, `alerts/aeris.py` line 1, `radar/aeris.py` line 1 | `"Aeris (AerisWeather/Xweather)..."` | → `"Xweather (Vaisala) — module id: aeris"` |
| G6 | API radar attribution | `providers/radar/aeris.py` line 96 | `ATTRIBUTION` constant with "AerisWeather" | → "Xweather" |
| G7 | Docs: PROVIDER-MANUAL | Multiple sections (§4, §5, §7) | "Aeris" as company name | → "Xweather" where referring to company; keep `aeris` for code identifiers |
| G8 | Docs: OPERATIONS-MANUAL | Lines 264, 427, 594, 603 | "Aeris" as company name | → "Xweather" |
| G9 | Docs: reference/api-docs/aeris.md | Header | "Aeris (AerisWeather / Xweather)" | → "Xweather (Vaisala) — API reference (module: aeris)" |

### H. PROVIDER-MANUAL Doc-Code Drift

| # | Issue | Current text | Fix |
|---|-------|-------------|-----|
| H1 | ReNASS URL outdated | `renass.unistra.fr` | → `franceseisme.fr` or `epos-france.fr` |
| H2 | GeoNet license version wrong | "CC BY 4.0" | → "CC BY 3.0 NZ" (per actual GeoNet website) |
| H3 | OpenAQ listed as day-1 AQI provider | In §5 provider table | Mark as "not wired — module exists but not in dispatch registry; bootstrap feature dropped" |
| H4 | Weather Underground listed as day-1 forecast provider | In §4 provider table | Mark as "not offered in wizard — insufficient data for full site operation" |

### I. Deferred (documented, not implemented)

| Feature | Why deferred |
|---------|-------------|
| Card ingestion system | No card installation mechanism exists yet. Document in ADR-080 that future ingestion reads card manifest → discovers attribution + logos → copies logos to `public/providers/` → registers provider in capabilities. Include cleanup metadata for uninstall. |

---

## 2. Implementation Phases

### PHASE 0 — ADR-080: Provider Attribution Architecture

**T0.1 — Draft ADR-080 as Proposed**
- Owner: Coordinator (Opus)
- File: New `docs/decisions/ADR-080-provider-attribution-architecture.md`
- Decisions to codify:
  - Attribution metadata lives on the API's `ProviderCapability` declaration
  - The API capabilities endpoint exposes attribution to the dashboard
  - The dashboard host renders the attribution footer — cards never import attribution components
  - Logos remain in the dashboard's asset directory; the API declares requirements, not graphics
  - `attribution_required` flag determines whether the host renders a footer
  - `text_translatable` flag controls i18n behavior
  - Card designers must account for attribution footer in their content area budget (53px standard, 23px compact)
  - Multi-provider cards: avoid. If unavoidable, host renders combined single-line footer
  - Future card ingestion system will automate logo placement and capability registration
- Accept: ADR-080 Proposed, reviewed by user, status flipped to Accepted.

**QC (Opus) — after Phase 0:** ADR content aligns with brief requirements, doesn't contradict ADR-064 (card plugin contract) or ADR-006 (compliance model). Format matches `_TEMPLATE.md`.

### PHASE 1 — API: Attribution Schema

**T1.1 — Add ProviderAttribution model to API**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/_common/capability.py`
- Do: Add a `ProviderAttribution` dataclass (frozen):

```python
@dataclass(frozen=True)
class ProviderAttribution:
    attribution_required: bool
    display_name: str
    attribution_text: str
    url: str
    text_translatable: bool = False
    text_language: str = "en"
    logo_required: bool = False
    do_not_use_logo: bool = False
```

- Add `attribution: ProviderAttribution | None = None` field to `ProviderCapability` (line ~79).
- Accept: `mypy` clean. `ruff check` clean. Field is optional with `None` default — no existing provider breaks.

**T1.2 — Add attribution to CapabilityDeclaration response model**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`
- Do: Add `ProviderAttributionResponse` Pydantic model mirroring the dataclass (camelCase fields). Add `attribution: ProviderAttributionResponse | None = None` to `CapabilityDeclaration` (line ~741).
- Accept: Pydantic serialization round-trip works. `mypy` clean.

**T1.3 — Map attribution in capabilities endpoint**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/capabilities.py`
- Do: In the `ProviderCapability` → `CapabilityDeclaration` mapping loop (lines 71–94), map `cap.attribution` to the response model.
- Accept: `GET /api/v1/capabilities` returns attribution blocks for providers that declare them.

**T1.4 — Populate attribution on all provider CAPABILITY declarations**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: Every provider module's `CAPABILITY` declaration. Representative list:

| Module file | provider_id | attribution_required | attribution_text | text_translatable | Rationale |
|-------------|------------|---------------------|-----------------|-------------------|-----------|
| `providers/forecast/aeris.py` | aeris | True | "powered by Vaisala Xweather" | False | ToS requires exact English |
| `providers/forecast/nws.py` | nws | False | "Data courtesy of the National Weather Service" | False | US govt — no accepted translations exist |
| `providers/forecast/openmeteo.py` | openmeteo | True | "Weather data by Open-Meteo.com" | False | ToS requires exact English |
| `providers/forecast/owm.py` | owm | True | "Weather data provided by OpenWeather" | False | ToS requires exact English |
| `providers/aqi/aeris.py` | aeris | True | (same — shared provider_id) | False | — |
| `providers/aqi/iqair.py` | iqair | True | "Powered by IQAir" | False | ToS language vague, keep English |
| `providers/aqi/openmeteo.py` | openmeteo | True | (same) | False | — |
| `providers/alerts/aeris.py` | aeris | True | (same) | False | — |
| `providers/alerts/nws.py` | nws | False | (same) | False | — |
| `providers/alerts/owm.py` | owm | True | (same) | False | — |
| `providers/earthquakes/usgs.py` | usgs | False | "Earthquake data courtesy of the U.S. Geological Survey" | False | US govt — no accepted translations exist |
| `providers/radar/rainviewer.py` | rainviewer | True | "RainViewer" | False | Brand name |
| `providers/radar/librewxr.py` | librewxr | True | "LibreWxR — Data: CC-BY-4.0" | False | License text, keep English |
| `providers/seeing/seven_timer.py` | seven_timer | False | "7Timer!" | False | Brand name |

**Note on US government agencies (NWS, USGS):** `text_translatable` is False despite public domain status. There are no formally accepted translations of these agency names. Well-established informal translations exist in some languages (e.g., "Servicio Nacional de Meteorología" for NWS in Spanish), but NWS's own multilingual program is paused since early 2026 (EO 14224). The `text_translatable` flag preserves the mechanism — if authoritative translations become available, flipping to True + adding locale keys enables translation without code changes.

- Also update `operator_notes` on `aeris` modules: change "Aeris (AerisWeather/Xweather)" to "Xweather (Vaisala)" in human-visible portions.
- Accept: All provider modules have `attribution=ProviderAttribution(...)` in their CAPABILITY. `ruff check` + `mypy` clean. API starts without errors.

**QC (Opus) — after Phase 1:** Restart API on weewx. `curl /api/v1/capabilities | jq '.providers[].attribution'` returns correct attribution blocks. Verify each provider's `attribution_text` matches the brief's ToS requirements. `attribution_required` is True only for providers that mandate it. `text_translatable` is False for ALL providers in v0.1.

### PHASE 2 — Manual Updates (guide agents)

**T2.1 — Update API-MANUAL §12: capabilities attribution schema**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/API-MANUAL.md`
- Do: In §12 (Capabilities), document the `ProviderAttributionResponse` schema, all fields with types, and the per-provider attribution table. Note that `attribution_text` for ToS-mandated providers must not be translated.
- Accept: Schema documented. Table matches Phase 1 values.

**T2.2 — Update DASHBOARD-MANUAL §8: attribution as host responsibility**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/DASHBOARD-MANUAL.md`
- Do: In §8 (Card Plugin Contract), add subsection: "Attribution rendering is a host responsibility. Cards must NOT import attribution components. The host reads `source` from the dataBag response, matches it against capabilities attribution, and renders a `ProviderAttribution` footer when `attribution_required` is true." Document content area specs (53px standard, 23px compact). Document single-provider-per-card guidance.
- Accept: Contract updated. Content area specs match DESIGN-MANUAL.

**T2.3 — Update PROVIDER-MANUAL §12: API-driven attribution**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Do: Update §12 to reference the `ProviderAttribution` schema on `CapabilityDeclaration`. Remove references to hardcoded `ForecastAttribution` component. Document that provider module authors populate attribution in their CAPABILITY declaration.
- Accept: §12 references API schema, not dashboard component.

**T2.4 — Update DESIGN-MANUAL §6: host-rendered attribution**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/DESIGN-MANUAL.md`
- Do: Update "Provider Attribution Footer" subsection — rename component path from `ForecastAttribution` to `ProviderAttribution` in `shared/`. Note host rendering pattern. Keep sizing specs unchanged (32px/16px, 53px/23px).
- Accept: Component path correct. Host pattern documented.

**QC (Opus) — after Phase 2:** All four manuals internally consistent. §8 card contract doesn't contradict §12 provider attribution. Content area specs match between DESIGN-MANUAL and DASHBOARD-MANUAL.

### PHASE 3 — Dashboard: Logos, Constants, Host-Rendered Attribution

**T3.0a — Move logos to `public/providers/` with provider_id naming**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do: Move all files from `src/assets/providers/` to `public/providers/` with new names per §E naming convention. Delete `src/assets/providers/`. Update any remaining `import ... from '../../assets/providers/...'` to URL string references (`/providers/aeris.svg`).
- Accept: `ls public/providers/` shows `aeris.svg`, `aeris-dark.svg`, `owm.png`, `owm-dark.png`, `nws.svg`, `openmeteo.png`. No files in `src/assets/providers/`. `tsc --noEmit` clean.

**T3.0b — Extract basemap attribution constants**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: New `src/lib/map-attribution.ts`
- Do: Create constants for all hardcoded basemap attribution strings:
  ```typescript
  export const OSM_ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';
  export const CARTO_OSM_ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>';
  export const OSM_ODBL_ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors (ODbL)';
  ```
- Replace inline strings in `radar-map.tsx` (lines 323, 327, 332, 480) and `seismic.tsx` (lines 132, 136) with these constants.
- Accept: Zero hardcoded attribution strings in map components. `tsc --noEmit` clean.

**T3.0c — Fix wind arrow tile attribution**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-map.tsx` (line ~1070)
- Do: Add `attribution={radarFrameList?.attribution ?? undefined}` to the wind arrow TileLayer. Leaflet deduplicates — same string as radar overlay won't show twice.
- Accept: Wind TileLayer has attribution prop. No visual duplication in Leaflet control.

**T3.1 — Move and rename attribution component**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do: Move `src/components/forecast/ForecastAttribution.tsx` → `src/components/shared/ProviderAttribution.tsx`. Rename export to `ProviderAttribution`. Update all current import paths (NowForecastCard, ForecastDailyCard, ForecastHourlyCard, aqi-card — these imports will be removed in T3.3 but need to compile during transition).
- Accept: `tsc --noEmit` clean. No functional change yet.

**T3.2 — Read attribution from capabilities instead of hardcoded map**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/ProviderAttribution.tsx`
- Do: Replace the hardcoded `PROVIDERS` map with a props interface that accepts attribution metadata directly. The component becomes a pure renderer — it receives `attributionText`, `logoLight`, `logoDark`, `logoRequired`, `doNotUseLogo`, `compact` as props. Keep the provider-ID-to-logo-filename mapping in a small static map (logos are dashboard assets, not API-served).
- Accept: Component renders from props, not internal lookup. `tsc --noEmit` clean.

**T3.3 — Now page: host renders attribution in card loop**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/routes/now.tsx` (lines 177–197)
- Do: In the card rendering loop, after rendering `<CardComponent>`, check if the card's dataBag endpoint has a `source` field. If so, look up that source in the capabilities attribution data. If `attribution_required`, render `<ProviderAttribution>` as a sibling after the card inside a wrapper. Use the card's `footprint` to determine compact (tile) vs standard.
- Requires: Add capabilities to the Now page — call `useCapabilities()` alongside existing data hooks.
- Remove: Direct `<ForecastAttribution>` import from `NowForecastCard.tsx` and `aqi-card.tsx`.
- Accept: Now page renders attribution footers identically to current behavior but driven by capabilities. Cards no longer import attribution. `tsc --noEmit` clean.

**T3.4 — Forecast page: host renders attribution**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/routes/forecast.tsx`
- Do: The forecast page uses direct imports (not the card registry). Add `useCapabilities()`. After each forecast card, render `<ProviderAttribution>` if the forecast source requires it. Remove `<ForecastAttribution>` from `ForecastHourlyCard.tsx` and `ForecastDailyCard.tsx`.
- Accept: Forecast page attribution unchanged visually. Cards no longer import attribution.

**T3.5 — Alert banner: read provider name from capabilities**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/alert-banner.tsx`
- Do: Replace the hardcoded ternary (`alert.source === 'aeris' ? 'Xweather' : ...`) with a lookup against capabilities data. The alert banner needs access to capabilities — either pass as prop from the layout, or call `useCapabilities()`.
- Accept: Alert banner shows correct provider name from API. No hardcoded provider names.

**T3.6 — Fix per-provider attribution text**
- Owner: Automatic — resolved by T3.2 + T1.4. The API now provides the correct ToS-mandated `attribution_text` per provider. The dashboard renders it verbatim.
- Accept: Each provider's footer shows their required wording, not generic "Powered by".

**T3.7 — Delete old ForecastAttribution.tsx**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do: After all imports are removed, delete `src/components/forecast/ForecastAttribution.tsx`. Verify no remaining imports.
- Accept: File deleted. `tsc --noEmit` clean. `vite build` clean.

**QC (Opus) — after Phase 3:** Deploy dashboard to weather-dev. Visual verification: Now page forecast card shows "powered by Vaisala Xweather" (not "Powered by"). AQI card shows compact attribution. Forecast page shows attribution on both cards. Alert banner shows correct provider name when alerts are active. No card component imports any attribution module. `grep -r "ForecastAttribution" src/` returns zero hits.

### PHASE 4 — i18n Fixes

**T4.1 — Update "Aeris Weather" → "Xweather (Vaisala)" in all legal.json files**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: 13 files at `public/locales/{en,de,es,fil,fr,it,ja,nl,pt-BR,pt-PT,ru,zh-CN,zh-TW}/legal.json`
- Do: Find-and-replace "Aeris Weather" → "Xweather (Vaisala)" in the third-party services text.
- Accept: `grep -r "Aeris Weather" public/locales/` returns zero hits.

**T4.2 — Add domain labels to non-English about.json files**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: 12 files at `public/locales/{de,es,fil,fr,it,ja,nl,pt-BR,pt-PT,ru,zh-CN,zh-TW}/about.json`
- Do: Add translated keys for `dataProviders.domain.baseMaps`, `dataProviders.domain.seismicData`, `dataProviders.domain.astronomical`. Use appropriate translations per language.
- Accept: All 13 locales have all domain labels. `JSON.parse` succeeds on each.

**T4.3 — Handle text_translatable in ProviderAttribution**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/ProviderAttribution.tsx`
- Do: When `textTranslatable` is false (all providers in v0.1), render `attribution_text` verbatim — never pass through `t()`. The component should check the flag so the infrastructure is ready for future use: when a provider eventually sets `textTranslatable: true` and matching locale keys exist, translation will work without code changes.
- Accept: All attribution text renders in English. No `t()` calls on attribution text. The flag-checking code path exists but is not exercised in v0.1.

**QC (Opus) — after Phase 4:** Legal page shows "Xweather (Vaisala)" in 3 spot-checked locales (de, ja, pt-BR). About page domain labels render in non-English locales. No i18n errors in console.

### PHASE 5 — About Page: Derive from Capabilities

**T5.1 — Replace hardcoded PROVIDER_INFO with capabilities data**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/routes/about.tsx`
- Do: Remove the `PROVIDER_INFO` map. The about page already calls `useCapabilities()`. For each provider in capabilities, use `attribution.display_name` and `attribution.url` instead of the hardcoded map. For providers without attribution (fallback), show the raw `providerId` with CSS capitalize (existing behavior).
- Keep: `STATIC_PROVIDERS` array for infrastructure providers (OpenStreetMap, CARTO, Protomaps, GEM, Skyfield, IMO) that don't come from the API. Protomaps is a courtesy credit — not legally required, but they request it and we want to reward contributors.
- Accept: About page shows correct provider names from API. No `PROVIDER_INFO` map in source.

**QC (Opus) — after Phase 5:** About page lists all configured providers with correct names. Static providers (including Protomaps) still appear. Deploy and visual verify.

### PHASE 6 — Aeris → Xweather Naming Sweep

**T6.1 — Stack repo: wizard labels + signup URL**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/providers.py`, `docs/providers.md`
- Do: Update display_name "Aeris Weather" → "Xweather (Vaisala)". Update signup URL `aerisweather.com/signup/` → `xweather.com/signup/`. Update providers.md headers and body text.
- Accept: `grep -r "Aeris Weather" repos/weewx-clearskies-stack/` returns zero hits. `grep -r "aerisweather.com" repos/weewx-clearskies-stack/` returns zero hits (except env var names which stay).

**T6.2 — Stack repo: EULA text (all 13 locales)**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `static/EULA.txt` + 12 locale EULA files
- Do: Replace "Aeris Weather (aerisweather.com)" → "Xweather (xweather.com)" in the third-party services section.
- Accept: `grep -r "Aeris Weather" repos/weewx-clearskies-stack/` returns zero hits.

**T6.3 — API: docstrings + radar attribution constant**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `providers/forecast/aeris.py`, `providers/aqi/aeris.py`, `providers/alerts/aeris.py`, `providers/radar/aeris.py`
- Do: Update module docstrings from "Aeris (AerisWeather/Xweather)" → "Xweather (Vaisala) — module id: aeris". Update `ATTRIBUTION` constant in radar/aeris.py.
- Accept: `grep -rn "AerisWeather" repos/weewx-clearskies-api/` returns zero hits outside of URL strings and env var names.

**T6.4 — Docs: full naming sweep**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: `docs/manuals/PROVIDER-MANUAL.md`, `docs/manuals/OPERATIONS-MANUAL.md`, `docs/reference/api-docs/aeris.md`
- Do: Replace "Aeris" with "Xweather" where it refers to the company/product name. Keep `aeris` for code identifiers (provider_id, module paths, config keys, env vars). Use pattern: "Xweather" for company, "`aeris`" (backtick-quoted) for code identifiers. Do NOT change archived ADRs or snapshot files.
- Accept: No unquoted "Aeris" used as a company name in active docs. Archived files untouched.

**QC (Opus) — after Phase 6:** Run `grep -ri "aeris weather\|aerisweather\|Aeris Weather" repos/ docs/` — only hits should be in `docs/archive/`, `docs/snapshots/`, env var names, and code identifiers. Zero hits in visitor-facing or operator-facing text.

### PHASE 7 — PROVIDER-MANUAL Doc-Code Drift Fixes

**T7.1 — Fix ReNASS URL, GeoNet license, OpenAQ and Weather Underground status**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Do:
  - §5 or wherever ReNASS is referenced: URL `renass.unistra.fr` → `franceseisme.fr`
  - GeoNet license: "CC BY 4.0" → "CC BY 3.0 NZ"
  - OpenAQ in §5 provider table: add note "Module exists but not wired into dispatch registry; bootstrap feature dropped. Not offered in wizard."
  - Weather Underground in §4 provider table: add note "Not offered in wizard — insufficient data for full site operation."
- Accept: All four corrections made. No other content changed.

**QC (Opus) — after Phase 7:** Spot-check each correction against the brief's §7 (ReNASS), §12-14 (GeoNet), §7 (OpenAQ), §5 (Weather Underground).

### PHASE 8 — Deploy & Final Verify

**T8.1 — Deploy API**
- Owner: Coordinator (Opus)
- Do: Push API changes to GitHub. Restart API service on weewx. Wait 2 min for cache warm.
- Accept: `curl /api/v1/capabilities | jq '.providers[] | {providerId, attribution}'` returns correct attribution for all providers.

**T8.2 — Deploy dashboard**
- Owner: Coordinator (Opus)
- Do: `tsc --noEmit` clean. `npm run build` clean. Deploy via `scripts/redeploy-weather-dev.sh`.
- Accept: All pages render. Attribution footers show correct ToS wording. About page derives from capabilities.

**T8.3 — End-to-end verification**
- Desktop + mobile visual check on weather-dev:
  - Now page: forecast card footer = "powered by Vaisala Xweather" (or operator's provider)
  - Now page: AQI card compact footer = correct provider wording
  - Forecast page: both cards show footer
  - About page: provider names from API, static providers present
  - Legal page: "Xweather (Vaisala)" in English + spot-check 2 other locales
  - Dark theme: logos switch correctly (Xweather light variant, OWM negative variant)

### PHASE 9 — QA Audit

**T9.1 — Code audit: no attribution imports in cards**
- Owner: `clearskies-auditor` (Sonnet)
- Do: `grep -r "ForecastAttribution\|ProviderAttribution" src/components/` — verify zero hits inside card components. Only `shared/ProviderAttribution.tsx` definition and page-level hosts (`now.tsx`, `forecast.tsx`) should reference it.
- Accept: Zero card-level attribution imports.

**T9.2 — Manual consistency audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Read DASHBOARD-MANUAL §8, PROVIDER-MANUAL §12, DESIGN-MANUAL §6, API-MANUAL §12. Verify all four describe the same architecture: API declares, host renders, cards don't touch attribution. No contradictions.
- Accept: All four manuals consistent.

**T9.3 — ToS compliance audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Compare each provider's `attribution_text` in the API against the PROVIDER-ATTRIBUTION-BRIEF.md requirements table. Verify exact wording matches.
- Accept: All ToS-mandated text matches brief requirements.

**T9.4 — i18n audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Verify no "Aeris Weather" in any locale file. Verify all 13 locales have complete domain label keys. Verify ToS-mandated attribution text is not wrapped in `t()`.
- Accept: Zero i18n violations.

**T9.5 — Aeris→Xweather naming audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: `grep -ri "aeris weather\|aerisweather\|AerisWeather" repos/ docs/` across all three repos + docs. Only acceptable hits: `docs/archive/`, `docs/snapshots/`, env var names (`AERIS_CLIENT_ID` etc.), code identifiers in backticks. Zero unquoted company-name references in active files.
- Accept: Audit report with zero violations or documented exceptions.

**T9.6 — Doc-code drift audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Verify PROVIDER-MANUAL §4/§5 provider tables match reality: OpenAQ marked as unwired, Weather Underground marked as not in wizard, ReNASS URL corrected, GeoNet license corrected. Cross-check against brief §5 (Weather Underground), §7 (OpenAQ), §12-14 (GeoNet/EMSC/ReNASS).
- Accept: All four drift items corrected per Phase 7.

---

## 3. Agent Assignments

| Phase | Task | Owner | QC | QC Timing |
|-------|------|-------|----|-----------|
| 0 | T0.1 ADR-080 | Coordinator (Opus) | User review | After T0.1 |
| 1 | T1.1–T1.4 API schema + providers | `clearskies-api-dev` | Coordinator verifies capabilities response | After Phase 1 |
| 2 | T2.1–T2.4 Manual updates | `clearskies-docs-author` | Coordinator cross-checks consistency | After Phase 2 |
| 3 | T3.0a–T3.7 Dashboard: logos, constants, host rendering | `clearskies-dashboard-dev` | Coordinator deploys + visual verify | After Phase 3 |
| 4 | T4.1–T4.3 i18n fixes | `clearskies-dashboard-dev` | Coordinator spot-checks 3 locales | After Phase 4 |
| 5 | T5.1 About page | `clearskies-dashboard-dev` | Coordinator visual verify | After Phase 5 |
| 6 | T6.1–T6.4 Aeris→Xweather naming sweep | `clearskies-stack-dev` + `clearskies-api-dev` + `clearskies-docs-author` | Coordinator grep audit | After Phase 6 |
| 7 | T7.1 PROVIDER-MANUAL doc-code drift | `clearskies-docs-author` | Coordinator spot-check | After Phase 7 |
| 8 | T8.1–T8.3 Deploy + final verify | Coordinator (Opus) | End-to-end checklist | After Phase 8 |
| 9 | T9.1–T9.6 QA audit | `clearskies-auditor` | Coordinator reviews findings | After Phase 9 |

**Sequencing:**
- Phase 0 (ADR) → Phase 1 (API schema) → Phase 2 (manuals) → Phase 3 (dashboard)
- After Phase 3: Phase 4 (i18n) || Phase 5 (about page) || Phase 6 (naming sweep) || Phase 7 (doc drift) — all independent, can run in parallel
- Phase 8 (deploy) after all of 4–7 complete
- Phase 9 (QA audit) after Phase 8

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- API: `ruff check` + `mypy` clean. API starts without errors.
- Dashboard: `tsc --noEmit` 0 errors. `vite build` clean.

### Gate 2 — Feature Correctness (per phase)
- Phase 1: `GET /api/v1/capabilities` returns attribution for all providers with correct ToS text.
- Phase 3: Cards render attribution footers from API data. No hardcoded "Powered by" except where it matches ToS requirements.
- Phase 5: About page provider list matches capabilities response.

### Gate 3 — ADR + Manual Compliance
- ADR-080 accepted before implementation begins.
- All four manuals describe the same architecture after Phase 2.
- No card component imports attribution after Phase 3.

### Gate 4 — i18n Compliance
- Zero "Aeris Weather" in locale files.
- All 13 locales have complete domain labels.
- ToS-mandated text never translated.

### Gate 5 — Visual Verification (Phase 6)
- Desktop + mobile: all attribution footers render correctly.
- Dark theme: logo variants swap.
- Compact footer on AQI tile proportional to card.

---

## 5. Self-Audit

**Risk: Capabilities hook called in multiple places.** `useCapabilities()` is a standalone hook, not a context. The Now page, Forecast page, about page, and radar page each call it independently. Adding it to Now page is consistent with existing pattern. Caching via `useApiQuery` prevents redundant fetches.

**Risk: Provider with same ID across domains.** Aeris appears in forecast, AQI, and alerts. Each module declares attribution separately, but the `attribution_text` is the same for all three (Xweather ToS). The capabilities response will have multiple entries with the same `providerId` — the dashboard deduplicates by `providerId` when looking up attribution for a `source` field.

**Risk: Card rendering wrapper changes card layout.** Wrapping a card + footer in a container div could break grid placement. Use React Fragment or ensure the wrapper inherits the card's grid column/row span classes.

**Risk: Forecast page doesn't use card registry.** The forecast page renders cards via direct imports, not the registry loop. Attribution injection requires per-card footer rendering in `forecast.tsx` rather than a generic loop wrapper. This is acceptable — the forecast page only has 3 cards.

**Risk: Future card ingestion.** Not built now. Documented in ADR-080 as a future requirement: ingestion system reads manifest, copies logos to `public/providers/`, registers attribution in capabilities. No code for this — documentation only.

**Risk: Logo move loses Vite cache-busting.** Files in `public/` are served as-is without content hashing. Provider logos change rarely (rebrands happen on multi-year timescales). Caddy cache headers can be configured if needed. The benefit (no rebuild for new logos, ingestion-system-ready) outweighs the cache-busting loss.

**Risk: Convention-based logo lookup misses a file.** If a provider declares `logo_required: true` but no logo file exists at `/providers/{id}.svg` or `.png`, the component should degrade to text-only (same as IQAir). The `ProviderAttribution` component handles this with an `onError` handler on `<img>` that falls back to text.
