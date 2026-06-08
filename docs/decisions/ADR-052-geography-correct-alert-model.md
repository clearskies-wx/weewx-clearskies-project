---
status: Accepted
date: 2026-06-01
amended: 2026-06-07
deciders: shane
supersedes:
superseded-by:
---

# ADR-052: Geography-correct alert severity model

## Context

ADR-010 defines `AlertRecord.severity` as `advisory | watch | warning` — NWS terminology. ADR-016 locks three day-1 alert providers (NWS, Aeris, OWM) and a single-source-per-deploy model. Both are Accepted.

The problem: the canonical severity enum forces every national alert system into US vocabulary. An operator in the UK sees their Met Office "Amber" warning labeled "watch." An operator in France sees Météo-France "Vigilance jaune" labeled "advisory." The terms "advisory," "watch," and "warning" don't exist in those systems and misrepresent the alert's meaning.

Additionally:
- The NWS provider (`nws.py`) has a bug: it maps from the CAP severity field (Extreme/Severe/Moderate/Minor) instead of the actual NWS three-tier system (Warning/Watch/Advisory) encoded in the event name. A "Tornado Warning" (CAP "Severe") maps to our "watch."
- The OWM provider has no severity field and does English keyword substring matching, which collapses UK Met Yellow/Amber/Red into one tier and defaults non-English alerts to "advisory."
- The Aeris provider discards `dataSource`, `localLanguages`, `details.color`, and `details.cat` — all of which carry information needed for correct rendering.

Research at [docs/reference/GLOBAL-ALERT-SYSTEMS-RESEARCH.md](../reference/GLOBAL-ALERT-SYSTEMS-RESEARCH.md) documents 11 national alert systems across the 10+ regions our providers cover, the provider wire formats, live API verification, and the cross-mapping between Aeris's suffix scheme and each national system's native labels.

## Options considered

| Option | Verdict |
|---|---|
| A. Keep `advisory\|watch\|warning` enum, improve mappings only | Rejected — the enum itself is the problem. Renaming NWS terms doesn't fix UK/EU/JMA operators seeing foreign vocabulary on their alerts. |
| B. Numeric severity level + native severity label (this ADR) | **Selected** — `severityLevel` (1–4 integer) for sorting/filtering/ARIA; `severityLabel` (string) for display in the operator's native system terminology. Providers populate both. |
| C. Pass through provider-specific severity verbatim, no normalization | Rejected — the dashboard needs a sortable, comparable severity for multi-alert ordering, ARIA urgency, and visual treatment intensity. Raw strings can't be compared across providers. |

## Decision

### Replace the severity enum with a two-field model

The canonical `AlertRecord.severity` field (`advisory | watch | warning`) is replaced by:

- **`severityLevel`**: integer 1–4 (1 = lowest, 4 = highest). OWM defaults to 2 (see amendment note below). Used for sorting, filtering, ARIA urgency, and visual treatment intensity.
- **`severityLabel`**: string. The source system's native severity name (e.g., "Amber", "Vigilance jaune", "Warning", "Orange"). Used for display. OWM defaults to "Alert" (see amendment note below).

The old `severity` field is removed from the canonical model.

### Severity level mapping

| Level | NWS (US/CA) | MeteoAlarm (EU) | UK Met Office | JMA (Japan) | BoM (Australia) | IMD (India) | INMET (Brazil) | SAWS (S. Africa) | KMA (S. Korea) | SMN (Mexico) |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | Warning | Red | Red | Emergency/Urgent Warning | Severe/Very Dangerous | Red | Red (Grande Perigo) | Level 9–10 | Red | Red/Purple |
| 3 | Watch | Orange | Amber | Warning | Warning | Orange | Orange (Perigo) | Level 5–8 | Orange | Orange |
| 2 | Advisory | Yellow | Yellow | Advisory | Watch | Yellow | Yellow (Atenção) | Level 3–4 | Yellow | Yellow |
| 1 | Statement | Green | — | — | Advice | Green | Gray | Level 1–2 | Green | Green |

### Add new canonical fields

| Field | Type | Source | Purpose |
|---|---|---|---|
| `severityLevel` | `int \| null` | All providers | Sortable severity (1–4). OWM defaults to 2. |
| `severityLabel` | `string \| null` | All providers | Native system label for display. OWM defaults to "Alert". |
| `alertSystem` | `string \| null` | Aeris `dataSource`, NWS literal, OWM `sender_name` | Source system identifier (e.g., `"meteoalarm"`, `"nws"`, `"ukmet"`). |
| `hazardType` | `string \| null` | Aeris `details.cat`, OWM `tags[0]` | Hazard category (e.g., `"thunderstorm"`, `"wind"`, `"fire"`). |
| `nativeName` | `string \| null` | Aeris `localLanguages[0].name` | Native-language alert name (e.g., `"Vigilance jaune orages"`). |
| `color` | `string \| null` | Aeris `details.color` | Provider-recommended hex color for rendering. NOT the national system's color. |

### Remove old field

`severity: advisory | watch | warning` — removed. The `?severity=` query parameter filter on `/alerts` changes to `?minLevel=1|2|3|4` (filter by minimum severity level).

### Two rendering modes

**Rich mode** (Aeris, NWS direct): `severityLevel` and `severityLabel` are populated. Dashboard renders severity-colored glass, native label, hazard-specific icon, severity-based ARIA.

**OWM default mode**: `severityLevel` defaults to 2 and `severityLabel` defaults to "Alert". If an alert exists, it warrants advisory-level visibility — treating it as null downplays it. Dashboard renders level-2 (yellow/advisory) glass, `ph:warning` icon, event text as-is, `role="status"` ARIA. Operator documentation must make this quality tradeoff explicit: the level-2 default conveys that an alert exists and deserves attention, but does not represent classified severity metadata from the provider.

### Fix the NWS provider

Map severity from the event name tier (Warning/Watch/Advisory/Statement), NOT the CAP severity field. Extract by checking the event string suffix or use the VTEC code suffix (`.W`/`.A`/`.Y`/`.S`). Delete `_NWS_SEVERITY_MAP`. Populate `severityLabel` with the tier name.

### Capture discarded Aeris fields

The Aeris provider must capture: `dataSource` → `alertSystem`, `localLanguages[0]` → `nativeName`, `details.color` → `color`, `details.cat` → `hazardType`. Update Aeris CAPABILITY `geographic_coverage` from `"us-ca-eu"` to include all documented regions (US, Canada, Europe, UK, Japan, Australia, India, Brazil, South Africa, South Korea, Mexico).

### Add 5 alert icons

Extend the ADR-050 alert icon set with 5 Material Symbols cross-pack glyphs for international hazard types:

| Icon | Codepoint | Hazard |
|---|---|---|
| `material-symbols:earthquake` | `f64f` | Earthquake |
| `material-symbols:volcano` | `ebda` | Volcanic Activity |
| `material-symbols:weather-hail` | `f67f` | Hail |
| `material-symbols:landslide` | `ebd7` | Avalanche |
| `material-symbols:air` | `efd8` | Dust Storm |

Drought, Road Conditions, Iceberg, Sheep Grazing, Unknown, and Special Weather use generic `ph:warning` (not immediate weather events or too niche for dedicated icons). Cyclone/typhoon uses existing `ph:hurricane` (same phenomenon, regional naming).

### OWM limitation — documented, not hidden

OWM One Call 3.0/4.0 provides no severity field. The API defaults `severityLevel=2` and `severityLabel="Alert"` for all OWM alerts — an operator directive that if an alert exists, it warrants advisory-level visibility. Null-severity treatment downplays alerts the user needs to see. Operator documentation must state: "Aeris and NWS provide classified, severity-aware alerts with native labels and hazard-specific icons. OWM alerts are assigned level-2 advisory visibility by default, not derived from provider metadata — actual severity may be higher or lower."

OWM's separate Push Weather Alerts API has CAP-style severity/urgency/certainty for 195+ countries but requires manual email signup with opaque pricing — not a practical option for operators.

### Future: direct national provider modules

Expanding direct provider coverage (Met Office API, JMA API, BoM API, IMD API, etc.) per ADR-038's provider module pattern is the path to full-quality alerts globally without depending on Aeris as the sole international intermediary. Each would be a new-module PR delivering native severity data directly.

## Consequences

- **Cross-repo change.** API (`models/responses.py`, all 3 provider modules, endpoint filter), OpenAPI contract (both copies), dashboard (`types.ts`, `alert-banner.tsx`, `alert-icon-map.tsx`, `alert-category.ts`).
- **Breaking API change.** `severity` field removed, replaced by `severityLevel` + `severityLabel`. The `?severity=` query parameter becomes `?minLevel=`. This is a v0.1 pre-release change — no backward compatibility required.
- **Aeris CAPABILITY update.** `geographic_coverage` changes from `"us-ca-eu"` to an accurate value reflecting all 10+ documented regions.
- **ADR-050 amended.** 5 new Material Symbols cross-pack alert icons added; existing 13 unchanged.
- **ADR-010 amended.** AlertRecord entity table updated with new fields, old `severity` removed.
- **ADR-016 amended.** OWM passthrough limitation documented; future direct-provider path noted.
- **Operator documentation required.** Alert quality differences between providers must be explicit — not buried in code comments.

## Acceptance criteria

- [ ] `AlertRecord` has `severityLevel` (int 1–4 | null), `severityLabel` (string | null), `alertSystem` (string | null), `hazardType` (string | null), `nativeName` (string | null), `color` (string | null). Old `severity` field removed.
- [ ] NWS provider maps from event name tier (Warning→4, Watch→3, Advisory→2, Statement→1), NOT CAP severity field. `_NWS_SEVERITY_MAP` deleted.
- [ ] Aeris provider captures `dataSource`, `localLanguages[0].name`, `details.color`, `details.cat` into new canonical fields.
- [ ] Aeris provider maps `.EX`→4, `.SV`→3, `.MD`→2, `.MN`→1 for `severityLevel`; populates `severityLabel` with native system label using `dataSource` + `place.country` + suffix cross-mapping.
- [ ] OWM provider sets `severityLevel=2` and `severityLabel="Alert"` (operator directive — advisory-level default). Does NOT set null.
- [ ] OpenAPI contract updated: AlertRecord schema reflects new fields; `?severity=` becomes `?minLevel=`.
- [ ] Dashboard `AlertRecord` TypeScript type updated.
- [ ] Dashboard alert banner renders native label (`severityLabel`) when available, falls back to event text.
- [ ] Dashboard alert banner uses level-2 (yellow/advisory) glass, `ph:warning`, `role="status"` for OWM alerts (arrive with `severityLevel=2`, `severityLabel="Alert"`). Null treatment reserved for future providers with indeterminate severity.
- [ ] 5 new alert icons (earthquake, volcano, hail, landslide, air) added to `alert-icon-map.tsx`.
- [ ] `alert-category.ts` maps all 33 Aeris international hazard codes to icon categories.
- [ ] All 3 provider test suites pass with corrected severity mapping.
- [ ] Aeris CAPABILITY `geographic_coverage` updated to reflect all documented regions.

## Implementation guidance

**API repo (`weewx-clearskies-api`):**
- `models/responses.py`: Update `AlertRecord` — remove `severity: str`, add `severityLevel: int | None`, `severityLabel: str | None`, `alertSystem: str | None`, `hazardType: str | None`, `nativeName: str | None`, `color: str | None`.
- `providers/alerts/nws.py`: Delete `_NWS_SEVERITY_MAP`. New function: extract tier from `event` string (check for " Warning", " Watch", " Advisory", " Statement" suffix) or VTEC code. Map to severityLevel 4/3/2/1. Set `severityLabel` to the tier name. Set `alertSystem = "nws"`.
- `providers/alerts/aeris.py`: Capture `dataSource` → `alertSystem`, `localLanguages[0].name` → `nativeName`, `details.color` → `color`, `details.cat` → `hazardType`. Map suffix `.EX`→4, `.SV`→3, `.MD`→2, `.MN`→1 for `severityLevel`. For `severityLabel`: build a lookup from `(alertSystem, place.country, suffix)` → native label using the cross-mapping in the research doc §6. Update CAPABILITY `geographic_coverage`.
- `providers/alerts/openweathermap.py`: Remove `_owm_severity_from_event()` and `_SEVERITY_KEYWORD_PRIORITY`. Set `severityLevel = 2`, `severityLabel = "Alert"` (operator directive — advisory-level default; provider carries no severity metadata). Capture `tags[0]` → `hazardType`. Set `alertSystem` from `sender_name` parsing where recognizable (e.g., "NWS" → "nws", "Met Office" → "ukmet"), else null.
- `endpoints/alerts.py`: Change `?severity=` filter to `?minLevel=` (int). Filter: `record.severityLevel >= minLevel` (skip records with null severityLevel if minLevel specified).

**Contract (`docs/contracts/openapi-v1.yaml` + dashboard copy):**
- Update AlertRecord schema with new fields, remove `severity`.
- Update `?severity` query param to `?minLevel`.

**Dashboard repo (`weewx-clearskies-dashboard`):**
- `src/api/types.ts`: Update `AlertRecord` interface.
- `src/components/icons/alert-icon-map.tsx`: Add 5 new Material Symbols inline SVGs (same pattern as existing `Flood` and `Tsunami` cross-pack components). Expand the switch statement in `AlertIcon`.
- `src/components/icons/alert-category.ts`: Expand category mapping to cover all 33 Aeris international hazard codes (`AW.XX` prefix → category).
- `src/components/shared/alert-banner.tsx`: Use `severityLabel` for display when non-null; fall back to `event`. Use `severityLevel` for ARIA urgency (4 → `role="alert"`, 1–3 → `role="status"`, null → `role="status"`). Apply severity-keyed glass color when `severityLevel` non-null; neutral alert glass when null. Note: OWM alerts arrive with `severityLevel=2` and `severityLabel="Alert"` by default, so the null branch is reserved for future providers with genuinely indeterminate severity.

**Out of scope:**
- Changing the OWM provider to use the Push Weather Alerts API (opaque pricing, manual signup).
- Adding direct national provider modules (Met Office, JMA, BoM, etc.) — future PRs per ADR-038.
- Severity-keyed glass colors per level (4=red, 3=amber, 2=yellow) — deferred to the alert card mockup phase; this ADR locks the data model only.
- Operator documentation content — needed but is a separate deliverable.

## References

- Research: [docs/reference/GLOBAL-ALERT-SYSTEMS-RESEARCH.md](../reference/GLOBAL-ALERT-SYSTEMS-RESEARCH.md) — provider wire formats, 11 national systems, cross-mapping, icon gaps, live API verification.
- Amends: [ADR-010](ADR-010-canonical-data-model.md) (AlertRecord entity), [ADR-016](ADR-016-severe-weather-alerts.md) (OWM limitation, coverage), [ADR-050](ADR-050-utility-stat-nav-icons.md) (5 new alert icons).
- Provider docs: [Aeris alerts](https://www.xweather.com/docs/weather-api/endpoints/alerts), [OWM One Call 3.0](https://openweathermap.org/api/one-call-3), [NWS API](https://www.weather.gov/documentation/services-web-api).
- Captured docs: `C:\tmp\Alert Types - Raster Maps - Xweather.htm` (full type/color table), `docs/reference/api-docs/aeris.md`, `docs/reference/api-docs/openweathermap.md`.
- Related: [ADR-038](ADR-038-data-provider-module-organization.md) (provider module pattern), [ADR-026](ADR-026-accessibility-commitments.md) (ARIA requirements).

## Amendment history

**Amended 2026-06-02: operator directive — OWM alerts default to level 2 rather than null.** Alerts deserve visibility regardless of provider metadata limitations. If an alert exists, it warrants advisory-level visibility; treating it as null downplays it. Changed: `severityLevel` null → 2, `severityLabel` null → "Alert" for OWM passthrough. Acceptance criterion 5 updated. Implementation guidance for `openweathermap.py` and `alert-banner.tsx` updated accordingly. The null branch in the dashboard banner is now reserved for future providers with genuinely indeterminate severity.

**Amended 2026-06-07: Statement-tier alerts (level 1) rendered identically to Advisory (level 2).** The data model is unchanged — `severityLevel=1` remains valid for sorting and the NWS provider still maps Statement events to level 1. The change is purely visual: the dashboard color palette now uses the same amber treatment (`#ca8a04`) for both level 1 and level 2 instead of the previous slate grey (`#475569`) for level 1. Rationale: the grey treatment de-emphasized statements to the point of invisibility — the badge had insufficient contrast on dark backgrounds (WCAG §1.4.3 failure) and the muted color communicated "ignorable" rather than "informational." Statements are informational alerts that still deserve attention. Applied to NWS, Environment Canada, and the generic fallback color maps in `alert-colors.ts`.
