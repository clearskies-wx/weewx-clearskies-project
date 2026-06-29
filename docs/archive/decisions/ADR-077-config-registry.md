---
status: Archived — consolidated into OPERATIONS-MANUAL.md
date: 2026-06-28
archived: 2026-06-28
deciders: shane
supersedes:
superseded-by:
---

# ADR-077: Unified Config Registry

> **Archived.** Prescriptive rules extracted into [OPERATIONS-MANUAL.md §4.1](../../manuals/OPERATIONS-MANUAL.md#41-config-registry). This file preserves the historical decision rationale only. For current implementation rules, read the manual.

## Context

The config wizard (15-step setup) and admin UI (ongoing config management) in `weewx-clearskies-stack` are disconnected codebases that duplicate metadata, validation, and rendering logic. Codebase research (2026-06-28) found:

- **13 providers x 5 fields** duplicated between `wizard/providers.py` and `templates/config/provider_section.html`.
- **3 active value mismatches** between wizard and admin (theme modes, earthquake defaults, TLS modes) — bugs shipping today.
- **~250-300 lines** of copy-pasted boilerplate across 10 admin POST handlers.
- **477 lines** of near-identical merge functions in wizard/routes.py.
- **749-line** hardcoded landing page requiring manual updates for every new section.
- **Zero shared macros** across 42 templates.

The duplication produces real bugs: an operator who sets `auto-sunrise-sunset` in the wizard sees an unknown value in the admin; earthquake defaults silently change when switching between wizard and admin; TLS modes offered differ between the two UIs.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| A: Unified config registry (Python dataclasses + Jinja2 macros) | Single source of truth for fields, validation, defaults. One rendering engine, two modes. Eliminates all 3 mismatches. Extensible via card manifests. | ~800 lines of new registry code. Multi-phase migration. |
| B: Sync constants manually | No new abstractions. | Fragile — mismatches will recur. Doesn't solve boilerplate or landing page. |
| C: Generate admin from wizard code | Reuses wizard's field definitions. | Wizard and admin have different UX patterns (sequential vs. random-access). Tight coupling. |

## Decision

Option A. Introduce a unified config registry: Python frozen dataclasses (`ConfigField`, `SectionDef`, `WizardStepDef`) registered at import time in a `ConfigRegistry` class. A single `render_field` Jinja2 macro renders all 11 field types. Admin sections are generated from the registry; wizard steps share field metadata and validation. Custom sections (haze calibration, card layout, column mapping, API connection) use escape hatches — the registry owns field metadata, the custom template owns layout.

### Value mismatch resolutions

| Field | Canonical value | Rationale |
|---|---|---|
| Theme mode option | `auto-sunrise-sunset` | Admin's `auto-sunrise` is a truncation bug. Full name matches ADR-023 and DESIGN-MANUAL.md §15. |
| Earthquake radius default | `250` km | Middle ground — broad enough for regional context, not so wide it floods with distant micro-quakes. |
| Earthquake min magnitude default | `2.0` | Approximate human perception threshold — "did I feel that?" |
| Earthquake default days | `30` | 30-day window gives meaningful seismic context. Wizard's `7` is too narrow. |
| TLS modes | Union: `self-signed`, `acme_http01`, `acme_dns01`, `manual`, `behind_proxy` | Wizard shows subset via `wizard_visible`. Admin shows all 5. |

## Consequences

- **Eliminates all metadata duplication** between wizard and admin.
- **Fixes 3 active value mismatches** (theme mode, earthquake defaults, TLS modes).
- **Estimated net reduction:** ~3,300 lines (see CONFIG-REGISTRY-PLAN.md §7).
- **New code:** ~800 lines in `registry/` package + ~150 lines in `render_field` macro.
- **Plugin extensibility:** Cards can declare `configFields` in their manifest; the registry auto-generates admin sections for them.
- **Migration risk:** Mitigated by incremental per-section migration with visual comparison before deleting old templates.
- **Behavior change:** New wizard installs get earthquake defaults 250/2.0/30 instead of 100/2.0/7.

## Acceptance criteria

- [ ] `ConfigField`, `SectionDef`, `WizardStepDef`, `ConfigRegistry` are importable frozen dataclasses.
- [ ] All ~40 config fields declared in registry with correct types, defaults, and validation rules.
- [ ] `render_field` macro handles all 11 field types with `aria-describedby` on all inputs.
- [ ] Conditional visibility JS works for TLS mode selection (fields show/hide based on mode).
- [ ] `validate_form_against_fields()` catches missing required fields, out-of-range numbers, pattern mismatches.
- [ ] `save_field_values()` dispatches to correct backend per `config_target`.
- [ ] Admin landing page generated from registry (under 60 lines, down from 749).
- [ ] Each migrated admin section renders identically to the old template; edit/save round-trip works.
- [ ] Full wizard walkthrough (15 steps) succeeds with registry-shared fields.
- [ ] Grep confirms: no `auto-sunrise` (without `-sunset`) in Python/template, no `_EARTHQUAKE_DEFAULTS` in admin/routes.py, all 5 TLS modes in registry.
- [ ] Card `configFields` in manifest appear in admin UI automatically.
- [ ] `pytest tests/test_registry.py` — all pass, 0 fail.

## Implementation guidance

Full implementation plan in `docs/planning/CONFIG-REGISTRY-PLAN.md`. Seven phases:

1. **Phase 0:** This ADR + manual update (extract rules into OPERATIONS-MANUAL.md).
2. **Phase 1:** Registry foundation — dataclasses, declarations, macros, validation helpers, unit tests. No visible changes.
3. **Phase 2:** Admin migration — simple sections (earthquakes, social, analytics, webcam, branding, pages, TLS).
4. **Phase 3:** Sky classification + provider metadata dedup.
5. **Phase 4:** Landing page from registry (749 → ~50 lines).
6. **Phase 5:** Wizard field sharing — wizard steps use `render_section_fields` and registry validation.
7. **Phase 6:** Plugin card extensibility — `configFields` in card manifests auto-register in admin.
8. **Phase 7:** Cleanup — delete all remaining duplicate constants, consolidate routers.

### Schema

```python
@dataclass(frozen=True)
class ConfigField:
    field_id: str           # e.g. "earthquakes.radius_km"
    field_type: str         # text|url|number|boolean|select|radio|password|file_or_url|radio_swatch|textarea|checkbox_group
    label: str
    help_text: str = ""
    wizard_help: str = ""
    placeholder: str = ""
    default: Any = None
    options: tuple[FieldOption, ...] = ()
    validation: tuple[ValidationRule, ...] = ()
    config_target: str = ""  # e.g. "stack.conf:earthquakes"
    config_key: str = ""
    is_secret: bool = False
    secret_env_key: str = ""
    conditions: tuple[Condition, ...] = ()
    wizard_visible: bool = True
    admin_visible: bool = True
    admin_landing_display: bool = False
    grid_column: str = "full"  # "full" or "half"
```

### Out of scope

- Refactoring the 4 custom sections (haze calibration, card layout, column mapping, API connection) — these keep custom templates with escape hatches.
- Migrating `WizardState`'s 58 individual fields to `registry_values` — incremental, not big-bang.
- Provider-specific rendering logic inside `provider_section.html` — only the metadata source changes.

## References

- CONFIG-REGISTRY-PLAN.md — full implementation plan with phase breakdown, QC gates, and agent assignments
- ADR-022 — Theming/branding (accent colors, logos)
- ADR-023 — Light/dark mode (theme modes including `auto-sunrise-sunset`)
- ADR-027 — Config wizard (15-step flow, scope boundary)
- ADR-038a — Wizard-to-API channel (`/setup/apply` endpoint)
- ADR-064 — Card plugin contract (`configFields` extension point)
- OPERATIONS-MANUAL.md §4.1 — Config Registry rules (prescriptive; supersedes this ADR for implementation)
- DESIGN-MANUAL.md §17 — Wizard design standards
