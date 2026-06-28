# Unified Config Registry — Config UI Refactor Plan

## Context

The wizard (15-step setup) and admin (ongoing config) in `weewx-clearskies-stack` are disconnected codebases that duplicate metadata, validation, and rendering logic. This caused the LibreWxR bug (fields missing from admin because `provider_section.html` has its own hardcoded copy of provider metadata separate from `wizard/providers.py`). The admin landing page is 748 lines of hardcoded HTML. Adding a new provider field requires changes in 3+ places. This architecture also blocks plugin card extensibility (v2) — there's no way for a third-party card to declare config fields.

**Goal:** One config registry, two rendering modes (wizard = linear guided, admin = random-access domain-organized). Cards and pages can declare their own config fields via manifest metadata. The admin gets a fresh UI built dynamically from the registry.

## Architecture

### Config field declaration

Each configurable field is a Python frozen dataclass (`ConfigField`) carrying:
- **Identity:** `field_id`, `field_type` (text/url/number/boolean/select/radio/password/file_or_url/radio_swatch/textarea)
- **Display:** `label`, `help_text`, `wizard_help` (extra guidance shown only in wizard mode), `placeholder`
- **Value:** `default`, `options` (for select/radio — each option has value, label, description)
- **Validation:** tuple of `ValidationRule` (required, min, max, pattern, one_of, etc.)
- **Persistence:** `config_target` (e.g. `"api.conf:radar"`), `config_key`, `is_secret`, `secret_env_key`
- **Visibility:** `conditions` (show when another field equals X — replaces per-template JS), `wizard_visible`, `admin_visible`, `admin_landing_display`
- **Layout:** `grid_column` (full/half for side-by-side fields)

The `Condition` dataclass expresses conditional visibility: `Condition(field_id="providers.radar.provider", operator="eq", value="librewxr")`. Rendered as `data-*` attributes on field wrapper divs, handled by one shared ~30-line JS function that replaces all the per-section inline scripts.

### Sections and wizard steps

- **`SectionDef`**: Groups fields for admin display. Has `section_id`, `display_name`, `domain_group` (station/providers/appearance/dashboard/advanced/cards), `config_source`, `provider_domain` (links to providers.py), optional `custom_template`/`custom_handler` escape hatches.
- **`WizardStepDef`**: Groups sections for wizard flow. Has `step_number`, `title`, `description`, `section_ids` (which sections' fields appear in this step), optional `custom_template`.
- A field lives in one section. A wizard step references one or more sections. Same `ConfigField` objects serve both wizard and admin.

### `ConfigRegistry` class

Central registry. Methods:
- `register_section(section, fields)` — register a section with its fields
- `register_wizard_step(step)` — register a wizard step
- `register_card_config(card_type, fields)` — register fields from a card manifest (auto-creates a section under the "cards" domain group)
- Query: `get_sections_for_group()`, `get_fields_for_section()`, `get_wizard_steps()`, `get_fields_for_wizard_step()`

Built once at import time. ~100 fields total, O(n) dict insertions, no performance concern.

### Rendering engine

**Jinja2 macro** (`render_field`) handles individual field rendering based on `field_type`. Covers: text, url, number, boolean (switch), select, radio (with per-option descriptions), radio_swatch (accent colors), password (with show/hide toggle), textarea. ~150 lines replaces field rendering scattered across 20+ templates.

**`render_section_fields` macro** loops over fields, applies `data-*` attributes for conditional visibility, respects grid layout.

**Category-specific templates** control layout and custom behavior (provider radio+test buttons, DB test button, column mapping table). They call `render_field()` for individual fields, getting de-duplication without forcing complex UX into a generic form.

**Generic admin section template** (~30 lines): breadcrumb + section title + `render_section_fields()` + save/cancel buttons. Replaces most of the 17 handwritten admin templates.

**Generated admin landing page**: Iterates `registry.get_all_domain_groups()` to build sidebar nav and section cards. Fields with `admin_landing_display=True` show current values on the card. Replaces the 748-line hardcoded `landing.html`.

### Plugin card config integration

Extend `card-metadata.ts` (dashboard repo) with optional `configFields` array. Build script passes them through to `card-manifest.json`. The config UI reads the manifest at startup, converts card config fields to `ConfigField` objects, registers them under `card_<type>` sections in the "Card Settings" domain group. Card config appears in admin automatically; optionally surfaced in wizard features step.

### What stays custom (escape hatches)

These wizard steps have interactive behavior beyond form-field rendering:
- **API Connection** (step 1): TLS fingerprint verification, trust token handshake
- **Import** (step 2): file upload, skin.conf parsing
- **EULA** (step 3): scroll-to-accept
- **Database** (step 4): inline "Test Connection" button with live feedback
- **Column Mapping** (step 5): dynamic table from schema introspection
- **Providers** (step 9): radio per domain, inline key test buttons — but individual fields (LibreWxR endpoint, bounds, Aeris model) come from registry via `render_field()`
- **Review** (step 15): read-only summary — actually benefits from registry (iterate sections to build summary programmatically)

Admin custom sections: Card Layout Editor (drag-and-drop), Haze Calibration (API calibration state + reset button), Column Mapping (dynamic table).

All custom sections use `custom_template` in their `SectionDef`. The registry still owns field metadata; the custom template calls `render_field()` for individual fields within its custom layout.

### WizardState evolution

Keep `WizardState` dataclass for complex/interactive fields (api_address, session_id, column_mapping, schema_data, imported_config). Add a generic `registry_values: dict[str, Any]` field for registry-declared fields. Simplifies `state_persistence.py` serialization for the ~40 fields that are simple key-value pairs.

## Implementation phases

### Phase 0: ADR
Draft ADR for the unified config registry pattern. Covers: field schema, section/step registry, rendering engine, plugin integration, migration approach. Needs user approval before code.

### Phase 1: Registry foundation (no visible changes)
- Create `registry/` package: `fields.py`, `sections.py`, `registry.py`
- Declare fields for simplest sections: earthquake settings (3 numeric fields), social links (4 URL fields), webcam (1 boolean + 3 text fields)
- Write `validate_form_against_fields()` and `save_field_values()` 
- Write `render_field` / `render_section_fields` Jinja2 macros
- Write conditional visibility JS handler
- Tests verifying registry produces same field set and validation as current code

### Phase 2: Admin generic rendering (incremental migration)
- Add generic `section_get`/`section_post` route handlers alongside existing routes
- Migrate one section at a time, starting with earthquake settings (simplest)
- Verify generic template renders identically to handwritten template
- Route admin sidebar link to generic handler, delete handwritten template
- Repeat for: social, analytics/privacy, webcam, station identity, branding, TLS, pages visibility, API connection
- Provider sections last (most complex conditional visibility)
- Each section migrates independently; rollback = revert one route

### Phase 3: Admin landing from registry
- Replace `landing.html` with registry-driven template (~40 lines replaces 748)
- Sidebar navigation generated from `registry.get_all_domain_groups()`
- Delete handwritten landing template

### Phase 4: Wizard field sharing
- For fully-declarable steps (webcam, features, units, TLS, appearance, privacy), change template form body to use `render_section_fields` from registry
- Step wrapper (numbering, explanatory text, prev/next) stays in step template
- Complex steps (DB, column mapping, providers, EULA, import, API connection) keep custom templates but use `render_field()` for individual fields within custom layout
- Add `registry_values: dict[str, Any]` to WizardState for registry-declared fields

### Phase 5: Plugin extensibility
- Extend `card-manifest.json` schema with `configFields`
- Implement `load_card_config_fields()` in the registry
- Card config fields appear in admin "Card Settings" domain group
- Optionally surface in wizard features step

### Phase 6: Cleanup
- Delete `_SECTION_META`, `_SECTION_ALLOWED_KEYS`, `_SECTION_SECRETS` from `config/routes.py`
- Delete `_ACCENT_OPTIONS`, `_THEME_OPTIONS`, `_TLS_MODES`, `_EARTHQUAKE_DEFAULTS`, etc. from `admin/routes.py`
- Delete `provider_meta` dict from `provider_section.html`
- Consolidate `admin/routes.py` and `config/routes.py` into single router

## Key files

| File | Lines | Role in refactor |
|------|-------|-----------------|
| `wizard/providers.py` | 321 | Model pattern — cleanest data-driven component, extend this approach |
| `wizard/routes.py` | 3,388 | Phase 4: extract field metadata from step handlers into registry |
| `wizard/state.py` | 256 | Phase 4: add `registry_values` dict field |
| `admin/routes.py` | 1,285 | Phase 2-3: replace 24 hardcoded handlers with generic routing |
| `config/routes.py` | 586 | Phase 2: replace `_SECTION_META`/`_SECTION_ALLOWED_KEYS` with registry |
| `templates/admin/landing.html` | 748 | Phase 3: replace with ~40-line registry-driven template |
| `templates/config/provider_section.html` | 403 | Phase 2: delete duplicated `provider_meta` dict |

## Estimated impact

- **Before:** ~13,800 lines across wizard + admin (9,200 + 4,600)
- **After (estimated):** ~8,000 lines — registry (~600), generic rendering (~300), field declarations (~800), remaining custom templates (~2,000), wizard routes streamlined (~3,000), shared utilities (~1,300)
- **Net reduction:** ~5,800 lines, plus elimination of all duplication between wizard and admin

## Verification

- Each phase has independent verification: migrate one section, compare rendered HTML
- Provider section: verify LibreWxR endpoint/bounds appear in both wizard and admin from same field declarations
- Plugin: add a test `configFields` entry to card-manifest.json, verify it appears in admin
- Regression: full wizard walkthrough (15 steps) after Phase 4
- The existing wizard test suite covers the step flow; add registry-specific unit tests in Phase 1
