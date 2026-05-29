# Unit System, Realtime BFF, and skin.conf Compliance

## Context

The Now page shows ~20 weather values but only 3 update in realtime (windDir, outHumidity, UV). Root cause: weewx-mqtt publishes field names with unit suffixes (`outTemp_F`, `windSpeed_mph`) but the dashboard expects bare names. We can't change the weewx MQTT config because Belchertown depends on suffixed names.

Investigation revealed a deeper issue: Clear Skies markets as a weewx skin but has no unit system. weewx's Cheetah engine provides unit conversion and labeling for free to traditional skins — we chose React (ADR-002) for interactivity but never accounted for the unit handling we walked away from. weewx documents a well-defined skin.conf schema that operators expect skins to support.

Additionally, the dashboard talks to two backends (API for REST, realtime for SSE). The realtime service should become a BFF (Backend-for-Frontend) — the browser's single gateway — so unit conversion happens in one place.

Finally, researching skin.conf revealed 5 sections relevant to Clear Skies that inform the customization we should offer and enable migration from existing skins.

---

## Phase 1: Documentation (before any code)

### New ADRs

**ADR: Realtime service as BFF**
- Realtime service becomes dashboard's single backend gateway
- Proxies REST API requests to upstream API on weewx host
- Serves SSE from MQTT/direct input
- Applies unit conversion to ALL outbound data (one conversion layer)
- Rationale: weewx host stays internal (ADR-034), browser has one connection point, unit conversion in one place
- Amends ADR-005 (adds BFF responsibility; input mode decision unchanged)
- Supersedes ADR-019 (no server-side unit conversion → BFF converts to display units)

**ADR: Unit system**
- Clear Skies supports all weewx unit groups and valid values (full compatibility)
- Operator configures display units per group (equivalent to skin.conf `[Units][[Groups]]`)
- Conversion happens in realtime BFF — dashboard receives value+label pairs with zero unit knowledge
- MQTT field name suffixes detected and stripped in BFF, source unit identified from suffix
- Supports all 14 unit groups from weewx docs (see table below)
- Also supports: StringFormats (decimal places), Labels (display symbols), Ordinates (compass directions), TimeFormats, DegreeDays, Trend

**ADR: skin.conf compliance**
- Documents keep/replace/ignore decision for each skin.conf section
- Enables migration: wizard can import existing skin.conf
- Sections:

| Section | Decision | How |
|---|---|---|
| `[Units]` | **KEEP** — full support | Wizard unit config step + BFF conversion |
| `[Labels][[Generic]]` | **KEEP** — observation display names | Ingest to i18n, configurable in wizard |
| `[Texts]` | **REPLACE** — use react-i18next | Already in place, ingest translations on migration |
| `[Extras]` — branding | **KEEP** — site title, logos | Wizard branding step |
| `[Extras]` — feature toggles | **INGEST, DEFER** — future site builder feature | Parse and store, implement display later |
| `[Extras]` — provider config | **INGEST** — pull API keys | Map to our provider config where possible |
| `[Extras]` — social | **KEEP** — build into footer | Wizard social config, footer component |
| `[Extras]` — PWA/manifest | **KEEP** — low effort | Generate manifest.json from config |
| `[Extras]` — MQTT | **KEEP** — already handled | Wizard step 5 |
| `[Almanac]` | **KEEP** — moon phase labels | Feed into i18n system |
| `[Generators]` | **IGNORE** | Cheetah-specific |
| `[CheetahGenerator]` | **IGNORE** | Cheetah-specific |
| `[ImageGenerator]` | **IGNORE** | Cheetah-specific |
| `[CopyGenerator]` | **IGNORE** | Cheetah-specific |

### Update ARCHITECTURE.md
- Realtime service: "passthrough bridge" → "BFF gateway"
- Topology diagram: dashboard → realtime → API (not dashboard → API directly)
- Caddy routing: `/api/v1/*` routed to realtime service, not directly to API
- Add unit conversion layer description

### Modify existing ADRs
- **ADR-005** — amend: BFF responsibility added, input mode decision unchanged
- **ADR-019** — supersede: BFF converts to operator display units (API still passes raw values to BFF)

---

## Phase 2: skin.conf ingestion engine (stack repo)

### Purpose
Parse an existing weewx skin's `skin.conf` and extract configuration that maps to Clear Skies settings. Used by the wizard to pre-populate all configuration steps.

### Parser behavior
- Read ConfigObj-format INI file (same format weewx uses)
- Extract and map each relevant section
- Return structured data that the wizard steps can pre-fill from
- Silently skip Cheetah-specific sections ([Generators], [CheetahGenerator], etc.)
- Log warnings for settings that don't map to any Clear Skies equivalent

### Mapping by section

**[Units][[Groups]]** → Unit preferences per group → pre-fills wizard unit config step
**[Units][[Labels]]** → Display symbols → stored in realtime config
**[Units][[StringFormats]]** → Decimal places → stored in realtime config  
**[Units][[Ordinates]]** → Compass directions → stored in realtime config
**[Units][[TimeFormats]]** → Date/time display → stored in config, served to dashboard
**[Units][[DegreeDays]]** → Base temps → stored in API config (affects calculations)
**[Units][[Trend]]** → Trend window → stored in API config (affects barometer trend)
**[Units][[TimeZone]]** → Timezone → pre-fills wizard station step

**[Labels][[Generic]]** → Observation names, page headers, Beaufort labels, forecast codes, alert codes → mapped to i18n keys where they align, flagged where they don't

**[Extras]** → Mapped by key pattern:
- `site_title`, `logo_image*` → branding config
- `forecast_provider`, `*_api_id`, `*_api_secret` → provider config / API keys
- `mqtt_websockets_*` → MQTT config (wizard step 5)
- `*_enabled` → feature toggles (stored, deferred)
- `earthquake_maxradiuskm` → earthquake config
- `manifest_*` → PWA manifest config
- `facebook_enabled`, `twitter_enabled`, `social_share_html` → social config
- `theme`, `theme_toggle_enabled` → theme config

**[Almanac]** → `moon_phases` → i18n keys

### Wizard flow change
- Step 0 (new): "Start fresh" OR "Import from existing skin" (file upload)
- If importing: parse skin.conf, store results, pre-fill all subsequent steps
- Each step shows imported values with visual indicator ("imported from Belchertown") and allows editing

### File location
- `C:\CODE\weewx-clearskies-stack\weewx_clearskies_config\wizard\skin_import.py`

---

## Phase 3: Realtime service → BFF (realtime repo)

### Current state
- 1,241 LOC, pure MQTT→SSE passthrough
- No HTTP client, no data transformation
- FastAPI with `/sse` endpoint only

### Changes

**New dependency:** `httpx` for API proxying

**New files:**
- `proxy.py` — HTTP client to upstream API, request forwarding
- `units/groups.py` — unit group definitions, valid values (from weewx docs)
- `units/conversion.py` — conversion factors between units within each group
- `units/labels.py` — display labels/symbols per unit
- `units/transformer.py` — applies conversion + labeling to data dicts
- `mqtt_fields.py` — detect MQTT unit suffix, extract base field name + source unit

**Modified files:**
- `pyproject.toml` — add httpx
- `config/settings.py` — add `[api]` upstream URL, `[units]` preferences
- `app.py` — add proxy routes for `/api/v1/*`, wire unit conversion to both proxy responses and SSE events
- `health.py` — add upstream API connectivity probe

**New config sections in `realtime.conf`:**
```ini
[api]
upstream_url = https://weewx-host:8765
tls_verify = false

[units]
    [[groups]]
    group_temperature = degree_F
    group_speed = mile_per_hour
    group_pressure = inHg
    group_rain = inch
    group_rainrate = inch_per_hour
    group_altitude = foot
    group_distance = mile
    # ... defaults to US if omitted
    
    [[labels]]
    degree_F = " °F"
    mile_per_hour = " mph"
    # ...
    
    [[string_formats]]
    degree_F = %.1f
    inch = %.2f
    # ...
    
    [[ordinates]]
    directions = N, NNE, NE, ENE, E, ESE, SE, SSE, S, SSW, SW, WSW, W, WNW, NW, NNW
    
    [[time_formats]]
    # strftime patterns for different contexts
    
    [[degree_days]]
    heating_base = 65, degree_F
    cooling_base = 65, degree_F
    
    [[trend]]
    time_delta = 10800
    time_grace = 300
```

### Unit groups (complete, from weewx docs)

| Group | Valid Units | Default (US) |
|---|---|---|
| group_temperature | degree_F, degree_C, degree_K, degree_E | degree_F |
| group_speed | mile_per_hour, km_per_hour, knot, meter_per_second, beaufort | mile_per_hour |
| group_speed2 | mile_per_hour2, km_per_hour2, knot2, meter_per_second2 | mile_per_hour2 |
| group_pressure | inHg, mbar, hPa, kPa | inHg |
| group_pressurerate | inHg_per_hour, mbar_per_hour, hPa_per_hour, kPa_per_hour | inHg_per_hour |
| group_rain | inch, cm, mm | inch |
| group_rainrate | inch_per_hour, cm_per_hour, mm_per_hour | inch_per_hour |
| group_altitude | foot, meter | foot |
| group_distance | mile, km | mile |
| group_direction | degree_compass | degree_compass |
| group_radiation | watt_per_meter_squared | watt_per_meter_squared |
| group_percent | percent | percent |
| group_moisture | centibar | centibar |
| group_volt | volt | volt |

### Data flow after changes

**REST (API proxy):**
1. Dashboard requests `/api/v1/current`
2. Realtime BFF forwards to upstream API
3. API returns raw archive values (e.g., `outTemp: 72.5` in Fahrenheit)
4. BFF converts to operator display units and attaches labels
5. Dashboard receives `{ outTemp: { value: 22.5, label: "°C", formatted: "22.5" } }` (if operator chose Celsius)

**SSE (MQTT):**
1. MQTT packet arrives: `{ "outTemp_F": "72.5", "windSpeed_mph": "5.2", "windDir": "241" }`
2. `mqtt_fields.py` strips suffixes: `outTemp` (source: degree_F), `windSpeed` (source: mile_per_hour), `windDir` (source: degree_compass)
3. `transformer.py` converts to display units and attaches labels
4. SSE sends same value+label format as REST proxy

**Derived values (Beaufort, comfort index):**
- BFF calculates Beaufort label from wind speed (in whatever unit) — dashboard doesn't need thresholds
- BFF determines comfort index (wind chill vs heat index) from temperature — dashboard doesn't need °F thresholds

---

## Phase 4: Dashboard changes

### Core principle
Dashboard renders `{value, label}` pairs. Zero unit knowledge. No hardcoded unit strings.

### Changes needed (from audit)

**45+ hardcoded unit references to remove across:**

| File | Refs | What |
|---|---|---|
| `src/routes/now.tsx` | 8 | "mph", "in", beaufortLabel() thresholds (lines 48-62, 431-443) |
| `src/routes/charts.tsx` | 15 | "°F" in chart axes, tooltips, tables |
| `src/routes/forecast.tsx` | 5 | "°" temperature display |
| `src/routes/earthquakes.tsx` | 2 | "km" earthquake depth |
| `src/components/current-conditions-card.tsx` | 6 | °F fallback, comfort thresholds (50°F/80°F) |
| `src/components/precipitation-barometer-card.tsx` | 3 | "in", "in/hr", "inHg" |
| `src/components/solar-uv-card.tsx` | 1 | "W/m²" |
| `src/utils/format.ts` | review | Decimal places (now from backend) |
| `src/mock/current.ts` | update | Mock units block |
| `public/locales/*/now.json` | 24+ | "mph" in wind strings (12 languages × 2 strings) |
| `public/locales/*/forecast.json` | 12+ | "mph" in wind forecast (12 languages) |

**Remove beaufortLabel() from now.tsx** — Beaufort label comes from BFF
**Remove comfort index thresholds from current-conditions-card.tsx** — wind chill vs heat index decision comes from BFF

**Update types:**
- `src/api/types.ts` — Observation fields include value + unit label
- `src/hooks/useRealtimeObservation.ts` — receives pre-converted data from BFF (no more WEEWX_TO_OBSERVATION mapping)

**i18n locale files:**
- Wind strings use `{{unit}}` interpolation instead of hardcoded "mph"
- All 12 language files updated

---

## Phase 5: Wizard enhancements (stack repo)

### New/modified wizard steps

**Step 0 (new): Import or Fresh Start**
- "Start fresh" button → empty config, proceed to step 1
- "Import from existing skin" → file upload, parse skin.conf, pre-fill all steps
- Each subsequent step shows imported values with visual indicator and edit capability

**Step N (new): Unit Configuration**
- Table of unit groups with dropdown selectors (similar to column matching UI in step 3)
- Pre-filled from: detected archive unit system (step 2) OR imported skin.conf
- Each group shows: group name, current selection, dropdown of valid units
- Preview of how values will display (e.g., "Wind: 5.2 kt" or "Wind: 9.6 km/h")

**Step N+1 (new): Site Branding**
- Site title (text input)
- Logo upload with guidance: recommended dimensions, accepted filetypes (SVG, PNG, JPG), max size
- Dark mode logo variant (optional)
- PWA manifest name and short name

**Step N+2 (new): Social & Footer**
- Toggle social links on/off
- Platform URLs (configurable list — at minimum: Facebook, Twitter/X, Instagram, YouTube)
- Footer copyright text
- Footer disclaimer text

**Step N+3 (new): Display Labels**
- Observation label overrides (what to call "outTemp" — default "Outside Temperature")
- Pre-filled from: i18n defaults OR imported skin.conf [Labels][[Generic]]
- Only show commonly-customized labels; advanced users get full list via expand

### On apply
- Writes `[units]` section to `realtime.conf`
- Writes branding config (where? — needs decision: API branding endpoint or static config)
- Writes social/footer config
- Writes label overrides to i18n override file or config
- Stores feature toggle state (for future site builder, not displayed yet)

---

## Phase 6: Verification

1. **ADR review** — all new/modified ADRs accepted before code
2. **skin.conf ingestion** — import a real Belchertown skin.conf, verify each wizard step pre-fills correctly
3. **Unit conversion** — test every supported conversion pair against weewx's own factors
4. **MQTT field handling** — verify all 47 live MQTT fields correctly parsed
5. **Dashboard audit** — zero hardcoded unit strings in `src/`
6. **End-to-end on weather-dev:**
   - BFF proxies API requests successfully
   - SSE values update every ~5s for ALL observations
   - Switch unit config (group_speed = knot) → verify labels change everywhere
   - Date/time formats respect config
   - Compass ordinates respect config
7. **Belchertown regression** — production site unaffected
8. **i18n** — unit labels correct in 2+ non-English locales

---

## Repos affected

| Repo | Scope |
|---|---|
| weather-belchertown (meta) | New ADRs, architecture update |
| weewx-clearskies-realtime | BFF proxy, unit conversion, MQTT field handling |
| weewx-clearskies-dashboard | Remove hardcoded units, update types/components |
| weewx-clearskies-stack | skin.conf parser, wizard steps (import, units, branding, social, labels) |

## Implementation order

1. ~~Write research briefs (meta repo)~~ DONE
2. ~~ADRs + architecture docs (meta repo)~~ DONE
3. ~~skin.conf parser (stack repo)~~ DONE — f49b8c7, 17 tests
4. ~~Unit conversion module (realtime repo)~~ DONE — 1b78b1e, 34 tests
5. ~~API proxy in BFF (realtime repo)~~ DONE — a56e9a1, 9 tests
6. ~~MQTT field handling in BFF (realtime repo)~~ DONE — b04961b + ac3e125, 29+29 tests
7. ~~Dashboard unit label removal~~ DONE — ed89613, 45+ refs removed
8. ~~Wizard steps: import, units (stack repo)~~ DONE — e0a78cd, 19 tests
9. ~~skin.conf generation on wizard apply (API + stack repos)~~ DONE — API dc61e86 (16 tests), stack 40ef4f3 (21 tests)
10. ~~Image import on skin.conf ingest (API + stack repos)~~ DONE — API 70ab789 (12 tests), stack dd0b8a8 (12 tests)
11. Wizard steps: branding, social, labels (stack repo) — deferred to next phase

---

## Research briefs

Findings from the 2026-05-26 investigation session. Load the relevant brief when working on a specific phase.

- [MQTT field name analysis](briefs/brief-mqtt-field-names.md) — what MQTT publishes, why only windDir updates, why we can't change MQTT config
- [weewx unit system architecture](briefs/brief-weewx-units.md) — how weewx stores data, 3 unit systems, where overrides live
- [skin.conf schema analysis](briefs/brief-skinconf-schema.md) — all 9 sections, keep/ignore/replace decisions, Belchertown implementation details
- [Dashboard unit audit](briefs/brief-dashboard-unit-audit.md) — every hardcoded unit reference, 45+ locations across 7 files + 12 locales
- [Realtime service architecture audit](briefs/brief-realtime-audit.md) — current 1,241 LOC codebase, what needs to change for BFF
