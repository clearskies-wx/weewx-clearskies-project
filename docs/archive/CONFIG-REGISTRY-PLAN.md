# Unified Config Registry — Config UI Refactor Plan

**Status:** COMPLETE
**Created:** 2026-06-28
**Components:** Config Wizard + Admin UI (`weewx-clearskies-stack`), Dashboard (`weewx-clearskies-dashboard` for Phase 6 only)

---

## Context

The wizard (15-step setup) and admin (ongoing config) in `weewx-clearskies-stack` are disconnected codebases that duplicate metadata, validation, and rendering logic. Codebase research (2026-06-28) confirmed the problem is worse than suspected:

- **13 providers × 5 fields** duplicated between `wizard/providers.py` and `templates/config/provider_section.html` lines 20-34 (the template's comment on line 15 explicitly says "mirrors wizard/providers.py")
- **3 active value mismatches** between wizard and admin — not hypothetical drift, but bugs shipping today (§1.C)
- **250-300 lines of copy-pasted boilerplate** across 10 admin POST handlers
- **477 lines of merge functions** (3 near-identical copy-paste merge blocks in wizard/routes.py)
- **749-line hardcoded landing page** that must be manually updated for every new section
- **Zero shared macros** — not a single `{% import %}` or `{% from %}` exists across 42 templates

**Goal:** One config registry, two rendering modes (wizard = linear guided, admin = random-access domain-organized). Cards and pages can declare their own config fields via manifest metadata. The admin gets a fresh UI built dynamically from the registry.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §5 WCAG accessibility, §7 build verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/manuals/OPERATIONS-MANUAL.md` §"Config Registry" — prescriptive rules for the registry pattern (available after T0.2)

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-stack` — Config wizard + admin (Jinja2 + HTMX + Pico CSS). No build step. Branch: `main`.
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind + shadcn/ui). Build: `npm run build`. Branch: `main`. Phase 6 only.

**Deploy:**
- Wizard/admin: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- Dashboard: `bash scripts/redeploy-weather-dev.sh`

**Governing manuals (prescriptive — what agents follow):**
- `docs/manuals/OPERATIONS-MANUAL.md` — config registry rules (added in T0.2), wizard scope, deployment, auth
- `docs/manuals/DESIGN-MANUAL.md` — UI patterns, tokens, component styling (for render_field macro output)

**Reference ADRs (decision context — why, not what to do):**
- ADR-022 — Theming/branding: 6 curated accents, logo upload + alt text, custom CSS slot, branding.json delivery
- ADR-023 — Light/dark mode: data-theme attribute, 4 modes (light/dark/auto-os/auto-sunrise-sunset)
- ADR-027 — Config wizard: 15-step flow, scope boundary
- ADR-038 — Wizard-to-API channel: `/setup/apply` endpoint

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

---

## 1. Current State Inventory

### A. Key Files and Sizes

| File | Lines | Role |
|------|-------|------|
| `wizard/routes.py` | 3,388 | 35 route handlers (18 GET, 17 POST), 15 wizard steps, ~20 hardcoded validation constants |
| `wizard/providers.py` | 322 | 13 `ProviderInfo` frozen dataclasses — model pattern for data-driven config |
| `wizard/state.py` | 257 | `WizardState` dataclass — 58 fields (49 scalar, 8 dict, 1 nested dict) |
| `wizard/state_persistence.py` | 652 | Save/load/merge logic, `populate_from_config()` reads api.conf + stack.conf + branding.json |
| `admin/routes.py` | 1,285 | 23 route handlers (13 GET, 10 POST), 8 hardcoded constant dicts, 12 admin sections |
| `config/routes.py` | 587 | Generic section handler, `_SECTION_META` (9 sections), `_SECTION_ALLOWED_KEYS` allowlist |
| `templates/admin/landing.html` | 749 | Hardcoded landing page — 19 section cards, 5 domain groups, sticky sidebar |
| `templates/config/provider_section.html` | 403 | Duplicated `provider_meta` dict (lines 20-34), provider field rendering |
| Templates (42 files total) | 7,849 | 24 wizard, 12 admin, 5 config, 1 shared. Zero `{% import %}` or `{% from %}` |

**Total lines in scope:** ~14,340 across Python + templates.

### B. Metadata Duplication Map

| Metadata | Source A | Source B | Source C |
|----------|----------|----------|----------|
| Provider display names, auth_fields, coverage, notes (13 providers × 5 fields) | `wizard/providers.py` lines 30-179 | `templates/config/provider_section.html` lines 20-34 | — |
| Accent color options (6 values) | `wizard/routes.py` line 2101 (`_VALID_ACCENTS`, local set) | `admin/routes.py` line 71 (`_ACCENT_OPTIONS`, module list) | — |
| Theme mode options (4 values) | `wizard/routes.py` line 2106 (`_VALID_THEME_MODES`, local set) | `admin/routes.py` line 74 (`_THEME_OPTIONS`, module list) | — |
| Earthquake setting defaults | `wizard/routes.py` lines 2300-2317 (inline) | `admin/routes.py` lines 103-107 (`_EARTHQUAKE_DEFAULTS`) | — |
| TLS mode options | `wizard/routes.py` line 2351 (`_VALID_TLS_MODES`, local tuple) | `admin/routes.py` lines 110-115 (`_TLS_MODES`, list of dicts) | — |
| `_require_session()` helper | `wizard/routes.py` lines 660-665 | `admin/routes.py` lines 149-156 | `config/routes.py` lines 190-197 |
| API provider fetch logic | `wizard/routes.py` lines 3177-3388 (`_merge_from_api_current_config`) | `admin/routes.py` lines 231-260 (`_fetch_api_providers`) | `config/routes.py` lines 236-276 (`_get_api_provider_values`) |

### C. Active Value Mismatches (Bugs)

These are not hypothetical risks — these are values that **differ right now** between wizard and admin:

| Field | Wizard Value | Admin Value | Impact |
|-------|-------------|-------------|--------|
| Theme mode option name | `"auto-sunrise-sunset"` (line 2106) | `"auto-sunrise"` (line 74) | Operator sets `auto-sunrise-sunset` in wizard; admin shows unknown value. Or admin sets `auto-sunrise`; wizard rejects it. |
| Earthquake radius default | `100.0` (line 2300) | `"500"` (line 105) | New wizard install gets 100km; editing in admin without changing shows 500km. |
| Earthquake magnitude default | `2.0` (line 2306) | `"2.5"` (line 105) | Same — wizard 2.0, admin 2.5. |
| Earthquake days default | `7` (line 2315) | `"30"` (line 105) | Same — wizard 7 days, admin 30 days. |
| TLS modes available | `acme_http01`, `acme_dns01`, `behind_proxy` | `self-signed`, `acme_http01`, `acme_dns01`, `manual` | Wizard offers `behind_proxy` (absent from admin). Admin offers `self-signed` and `manual` (absent from wizard). |

### D. Boilerplate Quantification

| Pattern | Location | Lines | What It Is |
|---------|----------|-------|------------|
| Admin POST handler boilerplate | `admin/routes.py` (10 handlers) | ~250-300 | Session check + assert + form read + try/except + error handling + render_result. ~25-30 lines per handler. |
| Wizard merge blocks | `wizard/routes.py` lines 746-869, 3033-3174, 3177-3388 | ~477 | Three near-identical field-by-field merge functions covering the same ~60 fields. |
| Dead code | `admin/routes.py` lines 293-303 | 11 | `_safe_int_range()` — defined but never called. |

### E. Sections That Stay Custom (Escape Hatches)

These sections have interactive behavior beyond form-field rendering and will NOT be genericized:

| Section | Why Custom | Template |
|---------|-----------|----------|
| Haze Calibration | Per-month calibration grid, API state fetch, destructive reset button, OpenAQ sensor search | `admin/haze_calibration.html` (314 lines) |
| Card Layout | Drag-and-drop with SortableJS, card palette, footprint/rowspan selection | `admin/card_layout.html` (275 lines) |
| Column Mapping | Dynamic table from schema introspection, canonical field autocomplete | `config/column_mapping.html` (189 lines) |
| API Connection (admin) | Writes caddy.env, runs `systemctl reload caddy` subprocess | `admin/connection.html` (85 lines) |

Custom sections use `custom_template` in their `SectionDef`. The registry still owns field metadata; the custom template calls `render_field()` for individual form fields within its custom layout.

---

## 2. Architecture

### ConfigField dataclass

Each configurable field is a Python frozen dataclass carrying:
- **Identity:** `field_id` (globally unique, e.g. `"earthquakes.radius_km"`), `field_type` (one of: `text`, `url`, `number`, `boolean`, `select`, `radio`, `password`, `file_or_url`, `radio_swatch`, `textarea`, `checkbox_group`)
- **Display:** `label`, `help_text`, `wizard_help` (extra guidance in wizard mode), `placeholder`
- **Value:** `default`, `options` (list of `FieldOption(value, label, description)` for select/radio types)
- **Validation:** tuple of `ValidationRule(rule_type, value)` — rule types: `required`, `min`, `max`, `step`, `pattern`, `one_of`, `max_length`, `max_file_size`
- **Persistence:** `config_target` (e.g. `"stack.conf:earthquakes"`, `"branding.json"`, `"secrets.env"`), `config_key`, `is_secret`, `secret_env_key`
- **Visibility:** `conditions` (list of `Condition(field_id, operator, value)` for conditional show/hide), `wizard_visible`, `admin_visible`, `admin_landing_display`
- **Layout:** `grid_column` (`"full"` or `"half"` for side-by-side fields)

### SectionDef and WizardStepDef

- **`SectionDef`:** Groups fields for admin display. Has `section_id`, `display_name`, `domain_group` (one of: station, providers, appearance, dashboard, advanced, cards), `config_source` (which file/API this section reads from), optional `custom_template` / `custom_handler` escape hatches.
- **`WizardStepDef`:** Groups sections for wizard flow. Has `step_number`, `title`, `description`, `section_ids`, optional `custom_template`.

### ConfigRegistry

Central registry built at import time. Methods:
- `register_section(section, fields)` — register a section with its fields
- `register_wizard_step(step)` — register a wizard step
- `register_card_config(card_type, fields)` — register fields from a card manifest
- Query: `get_sections_for_group()`, `get_fields_for_section()`, `get_wizard_steps()`, `get_all_domain_groups()`

### Rendering engine

**`render_field` Jinja2 macro** (~150 lines) handles individual field rendering by `field_type`. Covers all 11 field types. Replaces field rendering scattered across 20+ templates.

**`render_section_fields` macro** loops over fields, applies `data-condition-*` attributes for conditional visibility, respects `grid_column` layout.

**Conditional visibility JS** (~30 lines, shared): One function replaces all per-section inline scripts. Reads `data-condition-*` attributes, shows/hides field wrappers. Replaces: `step_tls.html` lines 133-160 (`applyMode()`), `provider_section.html` lines 336-383 (`onProviderChange`), etc.

---

## 3. Implementation Phases

### Phase 0 — Decision + Manual Update

ADRs do not govern code or QC — they document *why* a decision was made. The manuals govern *what to do*. Coding cannot begin until the governing manual is updated with prescriptive rules extracted from the accepted ADR.

**T0.1 — Draft ADR for unified config registry pattern**
- Owner: Coordinator (Opus)
- File: New `docs/decisions/ADR-0XX-config-registry.md`
- Do: Draft Proposed ADR covering: field schema, section/step registry, rendering engine, plugin integration path, migration approach. Must resolve the 3 value mismatches documented in §1.C — specify the canonical value for each:
  - Theme modes: use `"auto-sunrise-sunset"` (the wizard's full name; admin's `"auto-sunrise"` is a truncation bug)
  - Earthquake defaults: decide on one set of defaults (recommend admin's 500/2.5/30 as they match USGS reasonable defaults for a broad audience)
  - TLS modes: union of both sets — `self-signed`, `acme_http01`, `acme_dns01`, `manual`, `behind_proxy`. Wizard may show a subset via `wizard_visible`.
- Accept: ADR is Proposed. User reviews and approves.

**T0.2 — Extract prescriptive rules into OPERATIONS-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - Modify `docs/manuals/OPERATIONS-MANUAL.md` — add new section "Config Registry" with prescriptive rules extracted from the accepted ADR: field declaration format, section/step registration API, rendering macro usage, validation/save helpers, conditional visibility pattern, plugin card config integration, escape hatch pattern for custom sections
  - Modify `docs/decisions/ADR-0XX-config-registry.md` — status becomes "Archived — consolidated into OPERATIONS-MANUAL.md"
  - Move ADR to `docs/archive/decisions/`
- Do: Extract every prescriptive rule from the ADR into the manual. The manual section must be self-contained — an agent implementing Phase 1+ reads the manual, not the ADR. Include: canonical values for the 3 resolved mismatches, the ConfigField schema, the SectionDef/WizardStepDef schema, the registry API, the render_field macro contract, the conditional visibility JS contract, the validation/save helper signatures.
- Accept: OPERATIONS-MANUAL.md contains a "Config Registry" section with all prescriptive rules. ADR is archived. An agent reading only the manual has enough information to implement Phase 1.
- **QC (Opus):** Verify manual section is self-contained. Verify ADR is archived. Verify no prescriptive content remains only in the ADR. Cross-check against OPERATIONS-MANUAL.md existing sections for consistency.

### Phase 1 — Registry Foundation (no visible changes)

**T1.1 — Create registry package with dataclasses and registry class**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - New `weewx_clearskies_config/registry/__init__.py` — exports public API
  - New `weewx_clearskies_config/registry/fields.py` — `ConfigField`, `ValidationRule`, `Condition`, `FieldOption` frozen dataclasses
  - New `weewx_clearskies_config/registry/sections.py` — `SectionDef`, `WizardStepDef` frozen dataclasses
  - New `weewx_clearskies_config/registry/registry.py` — `ConfigRegistry` class with registration and query methods
- Do: Implement all dataclasses per the architecture in §2. `ConfigRegistry` uses dict-based storage, O(1) lookups by section_id. No external dependencies beyond stdlib `dataclasses`.
- Accept: `python -c "from weewx_clearskies_config.registry import ConfigField, SectionDef, ConfigRegistry"` succeeds. All dataclasses are frozen. Registry query methods return correct results for a manually registered test section.

**T1.2 — Declare fields for pilot sections**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: New `weewx_clearskies_config/registry/declarations.py`
- Do: Declare fields for all admin sections that will be genericized (not custom escape-hatch sections). Organized by section, each section registered via `registry.register_section()`. Sections and their fields:

  **Earthquake Settings** (3 fields, config_target `stack.conf:earthquakes`):
  - `radius_km`: number, min=1, max=20000, default="250"
  - `min_magnitude`: number, min=0, max=10, step=0.1, default="2.0"
  - `default_days`: select, options=[1,7,14,30], default="30"

  **Social Links** (4 fields, config_target `branding.json:social`):
  - `facebook_url`, `twitter_url`, `instagram_url`, `youtube_url`: all url type, no validation beyond type

  **Analytics & Privacy** (2 fields, config_target `branding.json`):
  - `google_analytics_id`: text, pattern=`G-[A-Za-z0-9]+`, placeholder="G-XXXXXXXXXX"
  - `privacy_regions`: select, options=[global, eu_gdpr, us_ccpa, both], default="global"

  **Webcam** (4 fields, config_target `stack.conf:webcam`):
  - `webcam_enabled`: boolean, default=false
  - `image_url`: url, default="/webcam/weather_cam.jpg"
  - `video_url`: url, default="/webcam/weewx_timelapse.mp4"
  - `refresh_interval`: number, min=10, max=3600, default="60"

  **Branding** (9 fields, config_target `branding.json`):
  - `site_title`: text, max_length=100
  - `copyright_entity`: text, max_length=100
  - `accent`: radio_swatch, options=blue/teal/indigo/purple/green/amber, default="blue"
  - `default_theme_mode`: radio, options=light/dark/auto-os/auto-sunrise-sunset, default="auto-os"
  - `favicon_url`: url
  - `custom_css_url`: url
  - `logo_light_url`: file_or_url (in admin; wizard handles file upload separately)
  - `logo_dark_url`: file_or_url
  - `logo_alt`: text, max_length=200

  **Pages Visibility** (1 field, config_target `pages.json`):
  - `hidden_pages`: checkbox_group, options=dynamically populated from `_ALL_PAGES` (9 built-in pages), admin_landing_display=true

  **TLS** (6 fields, config_target `stack.conf:tls`):
  - `mode`: radio, options=self-signed/acme_http01/acme_dns01/manual/behind_proxy (union of wizard+admin sets)
  - `domain`: text, conditions=[mode eq acme_http01 OR mode eq acme_dns01]
  - `acme_email`: text, conditions=[mode eq acme_http01 OR mode eq acme_dns01]
  - `dns_provider`: select, options=cloudflare/route53/google_cloud/digitalocean/namecheap, conditions=[mode eq acme_dns01]
  - `dns_api_token`: password, is_secret=true, conditions=[mode eq acme_dns01]
  - `cert_path`, `key_path`: text, conditions=[mode eq manual]

  **Sky Classification** (6 fields, config_target `api.conf:sky_classification`):
  - `scatter_few_max`: number, min=0, max=1, step=0.01, default="0.97"
  - `scatter_sct_max`: number, min=0, max=1, step=0.01, default="0.85"
  - `scatter_bkn_max`: number, min=0, max=1, step=0.01, default="0.52"
  - `overcast_km_threshold`: number, min=0, max=1, step=0.01, default="0.15"
  - `overcast_kv_threshold`: number, min=0, max=1, step=0.01, default="0.03"
  - `sza_min_elevation`: number, min=0, max=90, step=0.1, default="5.0"

- Accept: All sections registered. `registry.get_fields_for_section("earthquakes")` returns 3 fields with correct types/defaults. Total ~40 field declarations. `python -m py_compile` passes.

**T1.3 — Write render_field macro and conditional visibility JS**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - New `weewx_clearskies_config/templates/macros/form_fields.html` — `render_field` and `render_section_fields` Jinja2 macros (~150 lines)
  - New `weewx_clearskies_config/static/js/conditional-visibility.js` — shared conditional visibility handler (~30 lines)
- Do: (a) `render_field(field, value, mode)` macro dispatches on `field.field_type`. Must handle all 11 types: text (with placeholder), url, number (with min/max/step), boolean (Pico CSS switch), select (with options), radio (with per-option descriptions), password (with show/hide toggle), file_or_url, radio_swatch (accent color swatches with CSS), textarea, checkbox_group. Each field wrapper div gets `data-condition-field`, `data-condition-op`, `data-condition-value` attributes from `field.conditions`. All inputs get `aria-describedby` linking to help text. (b) `render_section_fields(fields, values, mode)` loops fields, applies grid layout, calls `render_field`. (c) JS handler reads `data-condition-*` attributes, registers change listeners on controlling fields, shows/hides field wrappers.
- Accept: Template compiles without Jinja2 errors. Each field type renders correct HTML matching existing admin templates. Conditional visibility JS toggles field wrapper visibility when controlling field changes. `aria-describedby` present on all inputs.

**T1.4 — Write validation/save helpers and unit tests**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - New `weewx_clearskies_config/registry/validation.py` — `validate_form_against_fields()`, `extract_field_values()`, `save_field_values()`
  - New `tests/test_registry.py` — unit tests
- Do: (a) `validate_form_against_fields(form_data, fields)` → list of errors. Checks required, min/max, pattern, one_of against `ValidationRule` tuples. (b) `extract_field_values(form_data, fields)` → dict of {config_key: value}, filtering by `_SECTION_ALLOWED_KEYS`-equivalent logic. (c) `save_field_values(values, section_def, config_dir)` → dispatches to `update_managed_region()` for .conf files, `update_branding()` for branding.json, `update_secrets()` for secrets, `update_pages()` for pages.json. (d) Tests: registry population, field query, validation pass/fail, value extraction, save dispatch.
- Accept: `pytest tests/test_registry.py` — all pass, 0 fail. Validation catches missing required fields, out-of-range numbers, pattern mismatches. Save dispatches to correct backend per `config_target`.

**QC (Opus) — after Phase 1:** Import registry in Python REPL. Query all sections, verify field counts match declarations. Run test suite. Verify no template compilation errors. Verify conditional visibility JS is syntactically valid. Check that field defaults match canonical values specified in OPERATIONS-MANUAL.md "Config Registry" section (from T0.2).

### Phase 2 — Admin Migration: Simple Sections

**T2.1 — Create generic admin section handler and template**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - New `weewx_clearskies_config/templates/admin/generic_section.html` (~30 lines) — breadcrumb + section title + `{% from "macros/form_fields.html" import render_section_fields %}` + save/cancel buttons
  - Modify `weewx_clearskies_config/admin/routes.py` — add `generic_section_get()` and `generic_section_post()` handlers that: (a) look up section in registry, (b) read current values from config backend per `section_def.config_source`, (c) render/validate/save using registry helpers
- Do: Generic handlers replace the per-section handler pattern. GET: read values → render generic template with fields from registry. POST: extract form → validate → save → render result. Route paths use section_id: `/admin/section/{section_id}`.
- Accept: Generic handler renders for a test section. POST validates and saves. Error handling matches existing `_render_result()` pattern. No changes to existing handlers yet — this adds new routes alongside them.

**T2.2 — Migrate earthquake settings, social links, and analytics/privacy**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/admin/routes.py` — delete `earthquakes_get`/`earthquakes_post` (lines 657-718), `social_get`/`social_post` (lines 540-588), `analytics_get`/`analytics_post` (lines 597-648). Delete `_EARTHQUAKE_DEFAULTS` (lines 103-107). Update landing page sidebar links to use generic routes.
  - Delete `weewx_clearskies_config/templates/admin/feature_settings.html` (107 lines)
  - Delete `weewx_clearskies_config/templates/admin/social.html` (98 lines)
  - Delete `weewx_clearskies_config/templates/admin/analytics_privacy.html` (87 lines)
  - Modify `weewx_clearskies_config/templates/admin/landing.html` — update edit links for these 3 sections to point to generic routes
- Do: Route admin sidebar links for Earthquake Settings, Social Links, and Analytics & Privacy to the generic handler. Verify rendered output matches old templates for each section. Delete old handlers and templates.
- Accept: All 3 sections render via generic handler. Edit/save round-trip works. Old templates deleted. Landing page links work. `_EARTHQUAKE_DEFAULTS` removed from admin/routes.py.

**T2.3 — Migrate webcam, pages visibility, branding, and TLS**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/admin/routes.py` — delete `pages_get`/`pages_post` (lines 393-446), `branding_get`/`branding_post` (lines 455-531), `tls_get`/`tls_post` (lines 727-804), and webcam is already in config/routes.py generic handler. Delete `_ACCENT_OPTIONS` (line 71), `_THEME_OPTIONS` (line 74), `_TLS_MODES` (lines 110-115), `_ALL_PAGES` (lines 58-68).
  - Delete `weewx_clearskies_config/templates/admin/pages_visibility.html` (69 lines)
  - Delete `weewx_clearskies_config/templates/admin/branding.html` (197 lines)
  - Delete `weewx_clearskies_config/templates/admin/tls.html` (182 lines)
  - Modify `weewx_clearskies_config/templates/admin/landing.html` — update edit links
- Do: Migrate remaining simple-to-medium sections. Branding is the most complex (9 fields, radio_swatch for accent, radio for theme mode). TLS has conditional visibility (fields appear/disappear based on selected mode) — must use the conditional visibility JS from T1.3. Pages has a checkbox_group field type. Webcam uses the generic section handler for its 4 fields.
- Accept: All 4 sections render via generic handler. TLS conditional visibility works (selecting acme_dns01 shows DNS fields, selecting manual shows cert/key paths). Branding accent swatches render as colored radio buttons. Pages checkboxes show all 9 pages. Old templates and constants deleted.

**QC (Opus) — after Phase 2:** Walk each migrated section in the admin UI on weather-dev: open, edit a value, save, verify it persists. Specifically test: (1) earthquake radius save round-trip, (2) branding accent color change, (3) TLS mode switch shows/hides conditional fields, (4) pages visibility toggle. Verify deleted templates are gone. Verify `_EARTHQUAKE_DEFAULTS`, `_ACCENT_OPTIONS`, `_THEME_OPTIONS`, `_TLS_MODES`, `_ALL_PAGES` are removed from admin/routes.py. Count remaining lines in admin/routes.py (should drop by ~400+).

### Phase 3 — Admin Migration: Sky Classification + Provider Dedup

**T3.1 — Migrate sky classification**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/admin/routes.py` — delete `sky_classification_get`/`sky_classification_post` (lines 920-995). Delete `_SKY_DEFAULTS` (lines 86-93), `_KC_REFERENCE` (lines 77-83).
  - Delete `weewx_clearskies_config/templates/admin/sky_classification.html` (237 lines)
  - Modify `weewx_clearskies_config/registry/declarations.py` — sky classification section already declared in T1.2
  - Modify generic section template or create `templates/admin/sky_classification_generic.html` if the KC reference table needs a custom sub-template
- Do: Sky classification has 6 float fields with the standard generic form PLUS a read-only Kasten-Czeplak reference table and a "Reset to defaults" button. Options: (a) if the reference table and reset button can be handled by adding a `custom_footer` slot to the generic template, do that. (b) If not, use a `custom_template` escape hatch that calls `render_section_fields` for the form fields and adds the reference table and reset button manually.
- Accept: Sky classification renders with all 6 fields, the KC reference table, and the reset button. Save round-trip works. Reset button restores defaults. Old template and constants deleted.

**T3.2 — Migrate provider sections to use registry metadata**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/templates/config/provider_section.html` — delete the `provider_meta` dict (lines 20-34) and `domain_providers` mapping (lines 36-42). Replace with data passed from the route handler, sourced from `wizard/providers.py` via the registry.
  - Modify `weewx_clearskies_config/config/routes.py` `section_get()` (lines 387-430) — for provider sections, pass `providers_by_domain()` from `wizard/providers.py` to the template context instead of relying on the template's hardcoded dict.
  - Modify `weewx_clearskies_config/registry/declarations.py` — register provider sections with fields derived from `PROVIDERS` list in `wizard/providers.py`
- Do: Eliminate the provider metadata duplication. The template's `provider_meta` (13 providers × 5 fields) and `domain_providers` mapping are deleted. The route handler passes provider data from `wizard/providers.py` (the single source of truth) to the template. The template iterates over the data-driven provider list instead of its hardcoded dict. Provider-specific field rendering (API key inputs, test button, LibreWxR config) stays in the template — only the metadata source changes.
- Accept: Provider section renders identically. The comment "mirrors wizard/providers.py" on line 15 is deleted along with the dict it describes. Adding a new provider to `wizard/providers.py` automatically appears in both wizard and admin. `domain_providers` ordering matches `PROVIDERS` list order.

**QC (Opus) — after Phase 3:** Verify provider_section.html no longer contains `provider_meta` or `domain_providers`. Open each provider domain (forecast, alerts, aqi, earthquakes, radar) in the admin config editor and verify correct provider list, key fields, and test button. Sky classification round-trip: edit a threshold, save, verify persisted in api.conf.

### Phase 4 — Admin Landing from Registry

**T4.1 — Replace landing.html with registry-driven template**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Rewrite `weewx_clearskies_config/templates/admin/landing.html` — replace 749 lines with ~50-line registry-driven template
  - Modify `weewx_clearskies_config/admin/routes.py` `admin_landing()` (lines 313-384) — build template context from `registry.get_all_domain_groups()` instead of reading every config source individually
- Do: New landing template iterates `registry.get_all_domain_groups()` to build the sidebar nav and section cards. For each section, fields with `admin_landing_display=True` show their current values on the card. Custom sections (haze calibration, card layout, column mapping, connection) retain their current landing card rendering via escape hatch. The sidebar structure (5 groups: Station, Providers, Appearance, Dashboard, Advanced) is generated from registry domain_group values.
- Accept: Landing page renders all 19 section cards with correct current values. Sidebar navigation works (HTMX swap into `#admin-content`). Adding a new section to the registry automatically adds it to the landing page and sidebar. Template is under 60 lines (down from 749).

**QC (Opus) — after Phase 4:** Visual comparison of old vs. new landing page — same sections, same domain groups, same sidebar structure, same edit links. Verify all HTMX navigation works (click each sidebar item, verify correct section loads). Count template lines (should be <60). Verify custom sections (haze calibration, card layout) still render correctly.

### Phase 5 — Wizard Field Sharing

**T5.1 — Add `registry_values` to WizardState and persistence**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/wizard/state.py` — add `registry_values: dict[str, Any] = field(default_factory=dict)` to `WizardState`
  - Modify `weewx_clearskies_config/wizard/state_persistence.py` — update `_state_from_dict()` (line 605) to handle `registry_values` as a dict field. Update `populate_from_config()` to populate `registry_values` for registry-declared fields instead of individual state fields.
- Do: `registry_values` is a flat dict keyed by `field_id` (e.g. `"earthquakes.radius_km": "500"`). For fields that have both a dedicated `WizardState` attribute AND a registry declaration (e.g., `webcam_enabled`), the existing attribute remains the source of truth during Phase 5 — `registry_values` is used only for fields that don't have dedicated attributes. This avoids a big-bang migration of all 58 state fields.
- Accept: State round-trips through JSON serialization with `registry_values` populated. `populate_from_config()` fills `registry_values` for registry-declared fields. No import errors. Existing wizard flow unchanged.

**T5.2 — Migrate simple wizard steps to use render_section_fields**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/templates/wizard/step_webcam.html` (67 lines) — replace form body with `{% from "macros/form_fields.html" import render_section_fields %}` call. Keep step wrapper (heading, explanatory text, prev/next buttons, progress bar include).
  - Modify `weewx_clearskies_config/templates/wizard/step_feature_settings.html` (76 lines) — same pattern
  - Modify `weewx_clearskies_config/wizard/routes.py` — update `step7_post` (webcam, lines 1941-1950) and `step_feature_settings_post` (lines 2293-2320) to use `extract_field_values()` + `validate_form_against_fields()` from registry instead of inline validation
- Do: For these 2 simplest wizard steps, replace the handcoded form fields with `render_section_fields`. The step wrapper template (heading text, prev/next navigation, progress bar) remains step-specific. The route handler delegates field validation to the registry. Step GET handlers pass registry fields and current values to the template.
- Accept: Webcam and feature settings wizard steps render identically. Form submission validates via registry. Round-trip: fill → save → re-run → fields pre-populate. Progress bar and prev/next navigation unchanged.

**T5.3 — Migrate remaining declarable wizard steps**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `templates/wizard/step_appearance.html` (326 lines) — use `render_field` for individual fields (accent swatch, theme radio, social URLs, logo alt, custom CSS). Keep file upload handling separate (file_or_url field type or custom).
  - Modify `templates/wizard/step_privacy_legal.html` (143 lines) — use `render_field` for GA ID and privacy region checkboxes. Keep file upload for custom terms/privacy.
  - Modify `templates/wizard/step_tls.html` (165 lines) — use `render_section_fields` with conditional visibility. TLS modes in wizard may show a subset via `wizard_visible` flag on field options.
  - Modify `wizard/routes.py` — update POST handlers for steps 11, 12, 14 to use registry validation. Delete inline constants: `_VALID_ACCENTS` (line 2101), `_VALID_THEME_MODES` (line 2106), `_VALID_TLS_MODES` (line 2351).
- Do: Migrate 3 more wizard steps. Appearance is the most complex — it has file uploads (logo, favicon) which stay as custom handling alongside registry-rendered fields. Privacy/Legal has file uploads (custom terms/privacy markdown) — same pattern. TLS uses full conditional visibility from the registry.
- Accept: All 3 steps render correctly. Wizard round-trip: new session → fill all fields → review → apply → re-run → all fields pre-populate. Inline validation constants deleted from routes.py. `render_field` produces same HTML as old templates. Conditional visibility works for TLS mode selection.

**QC (Opus) — after Phase 5:** Full wizard walkthrough on weather-dev (15 steps): Step 1 → through all steps → Review → Apply → re-run → verify pre-fill. Specifically test: (1) webcam step renders via registry, (2) earthquake settings step renders via registry, (3) appearance accent swatches work, (4) TLS conditional visibility works in wizard, (5) privacy region checkboxes work. Verify deleted constants: `_VALID_ACCENTS`, `_VALID_THEME_MODES`, `_VALID_TLS_MODES` are gone from wizard/routes.py.

### Phase 6 — Plugin Card Extensibility

**T6.1 — Extend card-manifest.json schema with configFields**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Modify `repos/weewx-clearskies-dashboard/src/lib/card-metadata.ts` — add optional `configFields` array to `CardMetadata` interface (lines 29-35). Each config field: `{ fieldId, fieldType, label, helpText, default, options?, validation? }`.
  - Modify `repos/weewx-clearskies-dashboard/scripts/generate-card-manifest.ts` — include `configFields` in manifest output
- Do: Extend `CardMetadata` with an optional `configFields?: CardConfigField[]` array. Define `CardConfigField` interface matching the registry's `ConfigField` schema (subset: fieldId, fieldType, label, helpText, default, options, validation). The build script passes `configFields` through to `card-manifest.json`. For v0.1, no built-in cards declare `configFields` — this is infrastructure for future third-party cards.
- Accept: `npm run build` passes. `card-manifest.json` includes `configFields` key (empty array or absent) for each card. TypeScript compiles clean. Existing card layout editor still works.

**T6.2 — Load card config fields into registry**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/registry/registry.py` — add `load_card_config_fields(manifest_path)` method
  - Modify `weewx_clearskies_config/admin/routes.py` — call `load_card_config_fields()` at startup, passing the path to `card-manifest.json` from the dashboard web root
- Do: `load_card_config_fields()` reads `card-manifest.json`, iterates cards that have non-empty `configFields`, converts each to `ConfigField` objects, and registers them under `card_{card_type}` sections in the "cards" domain group. These sections appear in the admin UI automatically via the registry-driven landing page.
- Accept: Add a test `configFields` entry to one card in `card-manifest.json`. Verify it appears in the admin landing page under "Card Settings" group. Edit/save round-trip works. Remove the test entry after verification.

**QC (Opus) — after Phase 6:** Verify card-manifest.json schema is valid. `tsc --noEmit` and `vite build` pass on dashboard. Test with a mock `configFields` entry — verify it appears in admin, edit, save, verify persisted. Verify no regression in card layout editor.

### Phase 7 — Cleanup

**T7.1 — Delete all remaining duplicate metadata and dead code**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/admin/routes.py` — delete `_safe_int_range()` (lines 293-303, dead code), `_HAZE_DEFAULTS` (lines 96-100, stays only if haze calibration still needs it), `_KC_REFERENCE` (lines 77-83, if moved to sky classification custom template).
  - Modify `weewx_clearskies_config/config/routes.py` — delete `_SECTION_META` (lines 48-60), `_SECTION_ALLOWED_KEYS` (lines 70-84), `_SECTION_SECRETS` (lines 92-94), and derived dicts — replaced by registry.
  - Modify `weewx_clearskies_config/wizard/routes.py` — delete remaining inline validation constants: `_VALID_AERIS_FILTERS` (line 1882), `_VALID_OPENMETEO_INDEXES` (line 1883), `_VALID_IQAIR_SCALES` (line 1884), `_PROVIDER_NAME_MAP` (lines 2418-2423) if superseded.
- Do: Sweep all files for metadata constants that are now superseded by registry declarations. Delete each one. Verify no runtime references remain (grep for the constant name).
- Accept: Grep for each deleted constant name returns zero hits. `python -m py_compile` passes on all modified files. No import errors.

**T7.2 — Consolidate admin/routes.py and config/routes.py**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - Modify `weewx_clearskies_config/admin/routes.py` — absorb remaining config/routes.py functionality (column mapping, test-provider, config dashboard) into the admin router
  - Delete `weewx_clearskies_config/config/routes.py` (587 lines)
  - Delete `weewx_clearskies_config/config/` directory if empty after routes.py removal (reader.py and updater.py may stay)
  - Modify `weewx_clearskies_config/app.py` or equivalent — remove config router registration, ensure admin router handles all routes
- Do: With the registry owning all section metadata, there's no need for two separate routers. The generic section handler (from config/routes.py) and the domain-specific handlers (remaining in admin/routes.py) merge into one router. Deduplicate `_require_session()`, `_raise_unauthorized()`, `_render()` — keep one copy. Deduplicate API fetch logic — keep one `_fetch_api_providers()`.
- Accept: Single router handles all admin + config routes. No duplicate helper functions. All existing URLs continue to work (add redirects if paths changed). `python -m py_compile` passes. Full admin UI functional test.

**QC (Opus) — after Phase 7:** Grep for all deleted constants — zero hits. Full admin UI walkthrough: landing page, each section edit, provider test, column mapping. Full wizard walkthrough. Verify no import errors, no 404s, no broken links. Count total lines across all modified files — verify net reduction matches estimate.

---

## 4. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 0 | T0.1 ADR | Coordinator | Opus | User review + approval | Before T0.2 |
| 0 | T0.2 Manual update | `clearskies-docs-author` | Sonnet | Manual self-contained check | Before Phase 1 |
| 1 | T1.1 Registry package | `clearskies-stack-dev` | Sonnet | Import test + dataclass review | After Phase 1 |
| 1 | T1.2 Field declarations | `clearskies-stack-dev` | Sonnet | Field count + default value check | After Phase 1 |
| 1 | T1.3 Macros + JS | `clearskies-stack-dev` | Sonnet | Template compile + a11y | After Phase 1 |
| 1 | T1.4 Validation + tests | `clearskies-stack-dev` | Sonnet | pytest pass/fail | After Phase 1 |
| 2 | T2.1 Generic handler | `clearskies-stack-dev` | Sonnet | Route test | After Phase 2 |
| 2 | T2.2 Simple sections | `clearskies-stack-dev` | Sonnet | Edit/save round-trip × 3 | After Phase 2 |
| 2 | T2.3 Medium sections | `clearskies-stack-dev` | Sonnet | Conditional visibility + round-trip × 4 | After Phase 2 |
| 3 | T3.1 Sky classification | `clearskies-stack-dev` | Sonnet | Float validation + reset | After Phase 3 |
| 3 | T3.2 Provider dedup | `clearskies-stack-dev` | Sonnet | Provider list identity check | After Phase 3 |
| 4 | T4.1 Landing page | `clearskies-stack-dev` | Sonnet | Visual comparison + line count | After Phase 4 |
| 5 | T5.1 WizardState evolution | `clearskies-stack-dev` | Sonnet | Serialization round-trip | After Phase 5 |
| 5 | T5.2 Simple wizard steps | `clearskies-stack-dev` | Sonnet | Wizard walkthrough | After Phase 5 |
| 5 | T5.3 Complex wizard steps | `clearskies-stack-dev` | Sonnet | Full 15-step walkthrough | After Phase 5 |
| 6 | T6.1 Card manifest schema | `clearskies-dashboard-dev` | Sonnet | `tsc --noEmit` + build | After Phase 6 |
| 6 | T6.2 Load card config | `clearskies-stack-dev` | Sonnet | Mock configField test | After Phase 6 |
| 7 | T7.1 Delete duplicates | `clearskies-stack-dev` | Sonnet | Grep for deleted names | After Phase 7 |
| 7 | T7.2 Consolidate routers | `clearskies-stack-dev` | Sonnet | Full admin + wizard test | After Phase 7 |

**Sequencing:**
- Phase 0 (ADR → manual update) → Phase 1 (foundation — no visible changes)
- Phase 1 → Phase 2 (admin simple sections — depends on registry + macros)
- Phase 2 → Phase 3 (admin complex — depends on generic handler proven)
- Phase 3 → Phase 4 (landing page — depends on all sections migrated)
- Phase 1 → Phase 5 (wizard — depends on registry + macros, independent of Phase 2-4)
- Phase 5 → Phase 6 (plugin — depends on registry proven in wizard)
- Phase 4 + Phase 5 → Phase 7 (cleanup — depends on all migrations complete)
- **Phases 2-4 (admin) and Phase 5 (wizard) can run in parallel after Phase 1.**

---

## 5. QC Gates

### Gate 1 — Code Quality (every phase)
- Stack: `python -m py_compile <file>` passes on all modified files. Templates render without Jinja2 errors.
- Dashboard (Phase 6 only): `tsc --noEmit` 0 errors. `vite build` clean.

### Gate 2 — Feature Correctness (per phase, Opus verifies)
- Phase 1: Registry populates, queries return correct field sets, tests pass.
- Phase 2: Each migrated admin section renders identically to old template. Edit/save round-trip works.
- Phase 3: Provider list in admin matches wizard. Sky classification reset works.
- Phase 4: Landing page shows all sections with correct current values. Line count <60.
- Phase 5: Full wizard walkthrough (15 steps) succeeds. Fields pre-populate on re-run.
- Phase 6: Mock card configField appears in admin.
- Phase 7: No duplicate constants remain. All routes functional.

### Gate 3 — Value Mismatch Resolution (Phase 2, Opus verifies)
- Theme mode: `auto-sunrise-sunset` is the canonical value in registry. Grep confirms no `auto-sunrise` (without `-sunset`) in any Python or template file.
- Earthquake defaults: single set of defaults in registry declarations. Grep confirms no `_EARTHQUAKE_DEFAULTS` in admin/routes.py and no hardcoded `100.0`/`2.0`/`7` in wizard/routes.py.
- TLS modes: all 5 modes in registry. Wizard step shows subset via `wizard_visible`. Admin shows all.

### Gate 4 — Accessibility (Phase 1 + Phase 2, Opus verifies)
- All rendered form fields have `<label>` elements with correct `for` attribute.
- All inputs have `aria-describedby` linking to help text.
- Conditional visibility uses `aria-hidden` and `inert` attributes (not just `display: none`).
- Radio swatches have visible focus indicators.
- Keyboard navigation works for all field types.

### Gate 5 — Regression (Phase 5 + Phase 7, Opus verifies)
- Full wizard walkthrough: new session → 15 steps → review → apply → re-run → verify all fields pre-populate.
- Full admin walkthrough: landing → each section → edit → save → verify persisted.
- Provider test button works in both wizard and admin.
- No broken HTMX navigation (sidebar links, edit links, prev/next).

---

## 6. Self-Audit

**Risk: Template rendering fidelity.** Generic rendering must produce visually identical output to handwritten templates. Mitigation: Phase 2 migrates one section at a time with visual comparison before deleting the old template. Rollback = revert one route.

**Risk: Conditional visibility complexity.** TLS and provider sections have multi-field conditional visibility with mode-dependent required fields. Mitigation: The `Condition` dataclass supports AND/OR logic. The JS handler is tested against the TLS case (the most complex) before migrating provider sections.

**Risk: State persistence backward compatibility.** Adding `registry_values: dict` to `WizardState` must not break existing saved progress files. Mitigation: `dataclasses.field(default_factory=dict)` — `_state_from_dict()` fills the default for missing keys on deserialization. No migration needed.

**Risk: File upload fields.** Branding and privacy steps have file uploads (logos, favicon, custom markdown). These can't go through a generic form handler without multipart handling. Mitigation: File uploads remain custom code in the route handler. The `file_or_url` field type renders the URL input via `render_field`; the file upload input is added by the step template alongside it. The generic handler processes URL-type values; file uploads are handled by the existing `_handle_branding_upload()` helper.

**Risk: Value mismatch resolution is a behavior change.** Fixing the earthquake defaults from 100/2.0/7 to 500/2.5/30 changes what new wizard installs get. Mitigation: ADR (Phase 0) documents the decision. The correct defaults are the ones matching USGS reasonable-scope defaults, not the wizard's arbitrarily smaller values.

**Risk: Provider section migration complexity.** The provider section template (403 lines) has domain-specific sub-sections (LibreWxR config, AQI regional fields, Aeris model). These are too complex for full generic rendering. Mitigation: Phase 3 only eliminates the `provider_meta` duplication — it changes the data source, not the rendering logic. The template keeps its domain-specific rendering but reads provider metadata from the route handler (sourced from `wizard/providers.py`) instead of its own hardcoded dict.

**Risk: Dead code introduced by incremental migration.** During Phases 2-5, old handlers coexist with generic handlers. Mitigation: Each task explicitly lists which handlers and templates to delete. Phase 7 does a final sweep with grep to catch any stragglers.

**Risk: Landing page dynamic generation performance.** Reading config from multiple sources (branding.json, stack.conf, api.conf, API endpoints) for every landing page load. Mitigation: This is exactly what `admin_landing()` already does (lines 313-384). The registry-driven version reads the same sources — it just iterates sections from the registry instead of hardcoding them. No performance change.

---

## 7. Estimated Impact

| Metric | Before | After (estimated) |
|--------|--------|--------------------|
| admin/routes.py | 1,285 lines | ~400 lines (generic handler + custom escape hatches) |
| config/routes.py | 587 lines | 0 (consolidated into admin) |
| templates/admin/ (12 files, 2,775 lines) | 2,775 lines | ~500 lines (generic_section.html + landing + custom) |
| templates/config/provider_section.html | 403 lines | ~380 lines (same rendering, no hardcoded metadata) |
| wizard/routes.py (inline constants) | ~100 lines of validation constants | 0 (moved to registry) |
| New: registry/ package | 0 | ~800 lines (fields, sections, registry, declarations, validation) |
| New: templates/macros/form_fields.html | 0 | ~150 lines |
| **Net reduction** | — | **~3,300 lines** + elimination of all cross-file metadata duplication |
