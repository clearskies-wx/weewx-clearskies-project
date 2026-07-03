# Operator Documentation, Help System & Licensing — Execution Plan

**Status:** PLANNING  
**Created:** 2026-07-02  
**Components:** Config UI (`weewx-clearskies-stack`), Dashboard SPA (`weewx-clearskies-dashboard`), API (`weewx-clearskies-api`), Meta repo (`weewx-clearskies-project`)

---

## Context

Clear Skies has completed i18n compliance and is approaching v1. The codebase has extensive developer-facing governing documents but **no operator-facing documentation or in-app help**. The wizard and admin UI have minimal field-level hints (`help_text` populated on 2 of ~40 registry fields; `wizard_help` populated on zero) and no contextual guidance explaining what each step does or how to make configuration decisions.

Additionally, the project's GPL v3 license does not match the creator's intent — commercial use (advertising, subscriptions, managed hosting) should require a paid license, while personal, educational, nonprofit, government, and community use should be free.

This plan covers four deliverables: a licensing change, an in-app help system, an operator manual, and doc-code sync rule updates.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §5 WCAG accessibility, §6 i18n rules
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-stack` — Config UI (Jinja2 + HTMX + Pico CSS v2). No build step. Branch: `main`.
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind + shadcn/ui). Build: `npm run build`. Branch: `main`.
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`.

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- Config UI: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (~2 min warm)
- Direct SSH: `ssh -F .local/ssh/config weather-dev`, `ssh -F .local/ssh/config weewx`

**Key existing state:**
- EULA exists as wizard step 3 (`step_eula.html`), 18 sections, GPL v3 focused. `static/EULA.txt` + 12 locale translations.
- Dashboard Legal page (`legal.tsx`): 4 collapsible cards — Terms of Use, Privacy Policy, Accessibility Statement, Open-Source Licenses. Content in `public/locales/{lang}/legal.json`.
- GPL v3 references exist in: EULA.txt (§1, §2, §6, §7, §16), legal.json (4 locations), LICENSE (all repos), LICENSE-RATIONALE.md (4 repos), ADR-003.
- Config UI translations: flat JSON, 923 keys, identity mapping in en.json. No markdown rendering — `translate()` returns `Markup()` for HTML safety.
- Wizard layout: `layout.html` extends `base.html`. Steps swap into `<section id="wizard-content">`. Header at lines 514-517. Pico CSS v2 has native `<dialog>` support (unused currently).
- Admin layout: `landing.html` has grid with sidebar nav + section cards.
- No CSS files exist (all inline). 3 JS files (Sortable, card-layout-editor, conditional-visibility).
- `ConfigField.help_text` populated on 2 of ~40 fields. `ConfigField.wizard_help` populated on 0.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase — no phase advances until sign-off.

---

## 1. Gap Inventory

### A. License Change

| # | Item | Current state | Target state |
|---|------|--------------|-------------|
| A1 | LICENSE files (api, dashboard, stack, design-tokens) | GPL v3 verbatim (675 lines each) | PolyForm Noncommercial 1.0.0 full text |
| A2 | LICENSE files (extension, truesun) | GPL v3 | No change (legally required — weewx derivative works) |
| A3 | ADDITIONAL-USES.md | Does not exist | New file in 4 repos: permitted uses + commercial requirements |
| A4 | LICENSE-RATIONALE.md (api, dashboard, stack) | GPL v3 rationale | Updated for PolyForm Noncommercial, explains weewx split. Note: realtime repo archived per ADR-058 — no longer applicable. |
| A5 | ADR-003 (license decision) | Accepted, GPL v3, archived | Superseded by new ADR documenting license change |
| A6 | EULA.txt + 12 locale translations | GPL v3 focused (§1 supplements GPL, §2 reaffirms GPL rights, §6 IP under GPL, §7 extends GPL §15-16, §16 GPL rights survive) | PolyForm Noncommercial focused — update §1-2 license grant, §6 IP, §7-8 warranty/liability, §16 termination |
| A7 | EULA wizard step template | References "GPL v3" in checkbox label and version text | Updated references |
| A8 | EULA wizard route handler | No changes needed | Version bump triggers re-acceptance |
| A9 | Dashboard legal.json (en) | GPL v3 refs in termsOfUse.dataAccuracy, .intellectualProperty, .limitationOfLiability, openSource.body | Updated to PolyForm Noncommercial + Additional Permitted Uses |
| A10 | Dashboard legal.json (12 non-English locales) | GPL v3 refs translated | Updated translations |
| A11 | Dashboard legal.tsx | "Open-Source Licenses" card section | Renamed to "License" with PolyForm summary |
| A12 | CLAUDE.md | Line 195: "GPL v3" | "PolyForm Noncommercial 1.0.0 (core repos); GPL v3 (weewx extensions)" |
| A13 | SPDX inconsistency | ADR-003 says `GPL-3.0-or-later`, LICENSE-RATIONALE says `GPL-3.0-only` | Resolved in new ADR — moot for PolyForm repos, fixed for extension/truesun |

### B. Help System

| # | Item | Current state | Target state |
|---|------|--------------|-------------|
| B1 | Help panel component (CSS) | No CSS files exist | `static/css/help-panel.css` — slide-out side panel |
| B2 | Help panel component (JS) | No help-related JS | `static/js/help-panel.js` — toggle, keyboard, HTMX load |
| B3 | Help panel Jinja2 macro | Does not exist | `templates/macros/help_panel.html` — reusable `<dialog>` |
| B4 | Markdown rendering in i18n | Not supported — `translate()` returns raw `Markup()` | Add `markdown` library, render help body values to HTML |
| B5 | Help triggers in wizard | No `?` icon on any step | `?` button in every step header, loads help via HTMX |
| B6 | Help triggers in admin | No `?` icon on any section | `?` button in every section header |
| B7 | Wizard help routes | No `/wizard/step/{N}/help` routes | New route handlers returning help content fragments |
| B8 | Admin help routes | No admin help routes | New route handlers returning help content fragments |
| B9 | Wizard help content (en) | Zero help content exists | Step-level help for all 17 wizard steps |
| B10 | Admin help content (en) | Zero help content exists | Section-level help for all admin sections |
| B11 | Help content translations | N/A | All help keys translated to 12 non-English locales |
| B12 | `ConfigField.help_text` | Populated on 2 of ~40 fields | Populated on all ~40 fields |
| B13 | `ConfigField.wizard_help` | Populated on 0 fields | Populated where wizard context differs from admin |
| B14 | Hand-built step inline help | Minimal `<small>` elements | Enhanced inline help on all hand-built step fields |

### C. Operator Manual

| # | Item | Status |
|---|------|--------|
| C1 | Quick Start | Not started |
| C2 | System Requirements | Not started — need to measure on running containers |
| C3 | Installation — Native path | Not started (content exists in OPERATIONS-MANUAL.md §1 but developer-oriented) |
| C4 | Installation — Docker compose | Unblocked — compose files finalized by BETA-RELEASE-PLAN Phase 1 (2026-07-02). Content ready to write. |
| C5 | Installation — weewx extensions | Not started (content exists in OPERATIONS-MANUAL.md §1 but developer-oriented) |
| C6 | First-Run Wizard guide | Not started — cross-references help system content |
| C7 | Admin Guide | Not started — cross-references help system content |
| C8 | Under the Hood | Not started |
| C9 | Charts Configuration | Not started (content exists in ARCHITECTURE.md but developer-oriented) |
| C10 | Troubleshooting | Not started |
| C11 | Getting Help | Not started |
| C12 | Support Scope | Not started — boundaries defined in dialog |
| C13 | Legal | Not started — depends on license change |
| C14 | Graphics/diagrams | Not started — identified during writing |

### D. Doc-Code Sync

| # | Item | Current state | Target state |
|---|------|--------------|-------------|
| D1 | Help text sync rule | No rule exists | Rule in `rules/clearskies-process.md` |
| D2 | Operator manual sync rule | No rule exists | Rule in `rules/clearskies-process.md` |
| D3 | License doc sync rule | No rule exists | Rule in `rules/clearskies-process.md` |

### E. Deferred Items (Tracked, Not Executed)

| # | Item | Why deferred | Track where |
|---|------|-------------|-------------|
| E1 | ~~Docker container finalization~~ | **Resolved by BETA-RELEASE-PLAN Phases 1+4 (2026-07-02).** Socket mount added to compose files, stale realtime artifacts removed, image tag defaults bumped to `1.0.0b1`, Config UI verified in compose. | BETA-RELEASE-PLAN.md |
| E2 | ~~Install scripts~~ | **Resolved by BETA-RELEASE-PLAN Phase 2 (2026-07-02).** `scripts/install-prerequisites.sh` created, systemd units parameterized with `User=clearskies` and pip-installed binary paths. | BETA-RELEASE-PLAN.md |
| E3 | ~~Docker compose installation docs~~ | **Resolved by BETA-RELEASE-PLAN Phase 2 T2.3 (2026-07-02).** Stack INSTALL.md updated with numbered dependency chain covering both Docker and native paths. | BETA-RELEASE-PLAN.md |
| E4 | CheckMK monitoring plugin | Future deliverable, not v1 | CLEAR-SKIES-PLAN.md |
| E5 | Home Assistant integration | Future deliverable, not v1. Goal: eliminate duplicate HA provider calls | CLEAR-SKIES-PLAN.md |
| E6 | Operator Manual i18n | Manual is English-only for v1 | CLEAR-SKIES-PLAN.md |
| E7 | Commercial licensing page/portal | Needs URL for operators to request commercial licenses | CLEAR-SKIES-PLAN.md |

---

## 2. Implementation Phases

### PHASE 0 — License Change

> All other phases reference the license. This phase must complete first.

**T0.1 — Obtain PolyForm Noncommercial 1.0.0 license text**
- Owner: Coordinator (Opus)
- Do: Fetch the full PolyForm Noncommercial 1.0.0 license text from polyformproject.org. Save to `c:\tmp\polyform-nc-1.0.0.txt` for reference.
- Accept: Full verbatim license text captured.

**T0.2 — Author ADDITIONAL-USES.md**
- Owner: Coordinator (Opus)
- Files: New `ADDITIONAL-USES.md` (will be copied to 4 repos)
- Content structure:
  - Header: "Clear Skies — Additional Permitted Uses & Commercial Requirements"
  - §1 Additional Permitted Uses (extends base PolyForm NC 1.0.0):
    - Community weather sharing (HOAs, neighborhood groups, voluntary associations) — no revenue
    - Family-owned farms and agricultural operations (<50 employees, not publicly traded)
    - Amateur radio weather stations and citizen science weather networks
    - Agricultural cooperatives and CSA programs
    - Tax-exempt organizations under IRC 501(c)(3), (c)(4), (c)(6), (c)(7) or international equivalent
  - §2 Commercial Use — License Required:
    - Displaying advertising (banner ads, sponsored content, affiliate links)
    - Paid subscriptions, memberships, or premium/gated access
    - Hosting Clear Skies as a managed service for third parties
    - Revenue-generating marketing activities (resort weather page driving bookings, etc.)
    - Publicly traded companies or organizations >50 employees (except government/nonprofits exempt under base license)
    - Reselling, white-labeling, or bundling as part of a commercial product
  - §3 Obtaining a Commercial License: contact information, GitHub link
  - §4 Provider Compliance: "Operators are responsible for complying with the terms of service of all external data providers they configure..."
- Accept: Complete document with all categories from dialog. Clear, readable, plain English.
- **QC (Opus):** Review against dialog decisions. Verify all scenarios from the discussion are correctly categorized.

**T0.3 — Replace LICENSE files in 4 core repos**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical file replacement
- Files:
  - `repos/weewx-clearskies-api/LICENSE`
  - `repos/weewx-clearskies-dashboard/LICENSE`
  - `repos/weewx-clearskies-stack/LICENSE`
  - `repos/weewx-clearskies-design-tokens/LICENSE`
- Do: Replace GPL v3 text with PolyForm Noncommercial 1.0.0 full text.
- Accept: All 4 files contain PolyForm NC 1.0.0. Extension and truesun repos unchanged (GPL v3).

**T0.4 — Copy ADDITIONAL-USES.md to 4 core repos**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical file copy
- Files: `ADDITIONAL-USES.md` in api, dashboard, stack, design-tokens repos
- Do: Copy the authored document from T0.2 to each repo root.
- Accept: Identical `ADDITIONAL-USES.md` in all 4 repos.

**T0.5 — Update LICENSE-RATIONALE.md in 4 repos**
- Owner: Coordinator (Opus)
- Files:
  - `repos/weewx-clearskies-api/LICENSE-RATIONALE.md`
  - `repos/weewx-clearskies-dashboard/LICENSE-RATIONALE.md`
  - `repos/weewx-clearskies-stack/LICENSE-RATIONALE.md`
  - `repos/weewx-clearskies-realtime/LICENSE-RATIONALE.md` (archived repo — update for record)
- Do: Explain license change from GPL v3 to PolyForm NC 1.0.0. Explain weewx extension repos remain GPL v3 (derivative works of GPL v3 weewx). Reference new ADR. Remove paho-mqtt election note (no longer relevant).
- Accept: All 4 files updated. Rationale clearly explains the change and the split.

**T0.6 — Author ADR superseding ADR-003**
- Owner: Coordinator (Opus)
- File: New `docs/archive/decisions/ADR-0XX-license-change-polyform.md` (next available number)
- Do: Nygard format. Context: GPL v3 permits commercial use which conflicts with creator's intent. Options: stay GPL v3, BSL 1.1, Elastic License 2.0, PolyForm Noncommercial 1.0.0, custom license. Decision: PolyForm NC 1.0.0 for core repos, GPL v3 for weewx extensions. Consequences: not OSI "open source", Additional Permitted Uses extends coverage, commercial licensing available. Supersedes ADR-003.
- Also: Update `docs/archive/decisions/ADR-003-license.md` status to "Superseded by ADR-0XX". Update `docs/decisions/INDEX.md`.
- Accept: ADR follows template. Status `Proposed` (user approves to `Accepted`). ADR-003 marked superseded.

**T0.7 — Update EULA text (English)**
- Owner: Coordinator (Opus)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/static/EULA.txt`
- Do: Update all GPL v3 references to PolyForm Noncommercial 1.0.0:
  - §1 ACCEPTANCE: "Supplements the PolyForm Noncommercial 1.0.0 license and ADDITIONAL-USES.md"
  - §2 LICENSE GRANT: Restate PolyForm NC rights. Free for non-commercial. Commercial requires license.
  - §3 THIRD-PARTY SERVICES: No change (provider list is license-agnostic)
  - §6 IP: "Software licensed under PolyForm Noncommercial 1.0.0"
  - §7 WARRANTIES: Update "Per GPL v3 §15-16" references to PolyForm NC warranty text
  - §8 LIABILITY: Update GPL v3 §16 reference to PolyForm NC liability text
  - §9 OPERATOR RESPONSIBILITIES: Add "Compliance with the PolyForm Noncommercial license and ADDITIONAL-USES.md commercial use requirements"
  - §16 TERMINATION: Update "GPL v3 rights survive" to PolyForm NC termination terms
  - Version bump to 2.0, update "Last Updated" date
- Accept: Zero GPL v3 references remain. All 18 sections reviewed. Version 2.0.

**T0.8 — Translate updated EULA to 12 non-English locales**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical translation from English original
- Files: `repos/weewx-clearskies-stack/weewx_clearskies_config/static/EULA_{locale}.txt` (12 files)
- Do: Full translation of updated EULA. Each translated file MUST begin with a prominent disclaimer in both English and the target language:
  ```
  ═══════════════════════════════════════════════════════════════
  IMPORTANT / WICHTIG:
  This is a translation provided for your convenience. The
  English version (EULA.txt) is the sole legally binding
  document. In case of any conflict between this translation
  and the English original, the English version prevails.

  [Same disclaimer translated into the target language]
  ═══════════════════════════════════════════════════════════════
  ```
  Governing law (California) and arbitration clauses in English legal terms with translated context.
- Accept: All 12 files updated. Every file starts with the bilingual disclaimer. Spot-check de, ja, pt-BR for correct legal terminology.

**T0.9 — Update EULA wizard step template**
- Owner: `clearskies-docs-author` (Sonnet) — template edits + translation key updates
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_eula.html`
- Do: Update checkbox label from "EULA Version 1.0, Last Updated 2026-06-10" to "EULA Version 2.0, Last Updated {date}". Update any hard-coded GPL v3 text.
- Also update translation keys in `translations/en.json` (lines 378, 576, 697-698) and corresponding keys in 12 non-English locale files.
- Accept: Wizard step renders with updated version. Auto-advances on re-run if version unchanged. Version change triggers re-acceptance.

**T0.10 — Update dashboard Legal page content**
- Owner: Coordinator (Opus) — audience-facing legal content
- Files:
  - `repos/weewx-clearskies-dashboard/public/locales/en/legal.json` — update 4 GPL v3 references (lines 21, 25, 37, 295)
  - `repos/weewx-clearskies-dashboard/src/routes/legal.tsx` — rename "Open-Source Licenses" card to "License"; update content rendering
- Do: Replace GPL v3 references with PolyForm Noncommercial language. Add summary of permitted uses and commercial requirements. Add link to ADDITIONAL-USES.md on GitHub. Update `openSource` section key to `license`.
- Accept: Legal page renders with updated license information. Zero GPL v3 references in legal.json.

**T0.11 — Translate updated legal.json to 12 non-English locales**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical translation
- Files: 12 files in `repos/weewx-clearskies-dashboard/public/locales/{locale}/legal.json`
- Do: Update all license-related translations to match English changes. Add a `"legalDisclaimer"` key to every non-English locale file:
  ```json
  "legalDisclaimer": "This is a translation provided for your convenience. The English version is the sole legally binding document. In case of any conflict between this translation and the English original, the English version prevails."
  ```
  The value is translated into the target language. The English version (`en/legal.json`) does NOT get this key.
- Also: Update `legal.tsx` to render `legalDisclaimer` as a prominent banner at the top of the Legal page when the active locale is not `en`. Style: info-level alert with a border, not dismissible.
- Accept: All 12 non-English files have the disclaimer key. Legal page renders the disclaimer banner for non-English locales. English locale shows no banner. `JSON.parse` succeeds on each file.

**T0.12 — Update CLAUDE.md**
- Owner: Coordinator (Opus)
- File: `CLAUDE.md`
- Do: Change "GPL v3" to "PolyForm Noncommercial 1.0.0 (core repos); GPL v3 (weewx extensions only)".
- Accept: CLAUDE.md reflects new license.

**QC (Opus) — after Phase 0:** Grep all 4 core repos for "GPL", "GNU", "General Public License" — verify zero remaining references except in git history. Verify extension/truesun repos unchanged. EULA renders in wizard with version 2.0. Dashboard Legal page renders updated license section. ADR-003 marked superseded. New ADR exists as Proposed.

---

### PHASE 1 — Help System Infrastructure

> Build the help panel component and wiring before adding content.

**T1.1 — Create help panel CSS**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: New `repos/weewx-clearskies-stack/weewx_clearskies_config/static/css/help-panel.css`
- Do: Style a slide-out side panel:
  - Desktop: fixed right, width 24rem, full height, z-index 100, glass-morphism matching the wizard container style
  - Mobile (≤768px): full-screen overlay, z-index 200, close button prominent
  - Content area: scrollable, padded, semantic HTML (headings, lists, paragraphs)
  - Transitions: slide-in/out 0.3s ease
  - `?` trigger button: circular, 2rem, Pico CSS primary color, positioned in step/section header
  - Dark mode: `@media (prefers-color-scheme: dark)` variant
  - Pico CSS compatibility: use Pico custom properties (`--pico-*`) for consistency
- Accept: Panel slides in/out smoothly. Renders correctly in light/dark. Mobile overlay covers viewport. No Pico CSS conflicts.

**T1.2 — Create help panel JS**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: New `repos/weewx-clearskies-stack/weewx_clearskies_config/static/js/help-panel.js`
- Do: Vanilla JS (~50-80 lines), no framework:
  - Toggle panel open/close on `?` button click
  - Close on Escape key
  - Load help content via HTMX `hx-get` on first open (lazy load)
  - Focus management: move focus to panel heading on open, return focus to trigger on close
  - Mobile: close button handler
  - `aria-expanded` toggle on trigger button
  - Persist open/closed state in sessionStorage (optional — decide during implementation)
- Accept: Panel opens/closes. Keyboard accessible. Focus managed correctly. Content loads via HTMX on first open.

**T1.3 — Create help panel Jinja2 macro**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: New `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/macros/help_panel.html`
- Do: Reusable macro `{% macro help_trigger(help_url, label="Help") %}` that emits:
  - A `?` button with `aria-label="{{ label }}"`, `aria-expanded="false"`, `aria-controls="help-panel"`
  - The panel `<aside>` container (hidden by default) with `role="complementary"`, `aria-label="Help"`, close button, scrollable content area with `id="help-panel-content"` and `hx-get="{{ help_url }}"` + `hx-trigger="intersect once"`
- Accept: Macro renders valid HTML. `aria-*` attributes correct. HTMX attributes present.

**T1.4 — Add markdown rendering to i18n pipeline**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/pyproject.toml` — add `markdown>=3.6` dependency
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/i18n.py` — add `translate_md(key, locale)` function that calls `translate()` then pipes through `markdown.markdown()` with `extensions=['tables', 'fenced_code']`, returns `Markup()`
- Do: New function alongside existing `translate()`. Does not modify `translate()` behavior. Used only for help body content (long-form markdown). Field labels and short help text continue using `translate()`.
- Accept: `translate_md("help.wizard.step_db.body")` returns rendered HTML `Markup`. Existing `_()` behavior unchanged.

**T1.5 — Add help route handlers to wizard routes**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py`
- Do: Add `GET /wizard/help/{step_id}` route that:
  1. Reads help translation keys: `help.wizard.{step_id}.title`, `help.wizard.{step_id}.body`, `help.wizard.{step_id}.tip` (optional)
  2. Renders body through `translate_md()`, title/tip through `translate()`
  3. Returns an HTML fragment (not a full page) for HTMX swap into the help panel
- Template: New `templates/wizard/help_fragment.html` — simple `<h3>{{ title }}</h3><div>{{ body }}</div>{% if tip %}<aside class="help-tip">{{ tip }}</aside>{% endif %}`
- Accept: `GET /wizard/help/step_db` returns HTML fragment with rendered help content. 404 for unknown step_id.

**T1.6 — Add help route handlers to admin routes**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/config/routes.py` (or `admin/routes.py` — verify correct file)
- Do: Add `GET /admin/help/{section_id}` route, same pattern as T1.5.
- Accept: `GET /admin/help/providers` returns HTML fragment.

**T1.7 — Integrate help trigger into wizard layout**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/layout.html` — add `<link>` to `help-panel.css` in `<style>` block (or as external `<link>`), add `<script src>` for `help-panel.js`
  - Each of the 17 `step_*.html` templates — add `{% from "macros/help_panel.html" import help_trigger %}` and `{{ help_trigger("/wizard/help/{step_id}") }}` in the `<header>` section of each step, next to the `<h2>`
- Do: The `?` icon appears in every wizard step header. Step templates that are HTMX-swapped carry the macro call.
- Accept: Every wizard step shows `?` icon. Clicking opens side panel. Content loads for each step.

**T1.8 — Integrate help trigger into admin templates**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/landing.html` — add CSS/JS links
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/generic_section.html` — add help trigger in section header
  - Custom admin templates (sky_classification.html, haze_calibration.html, forecast_correction.html, card_layout.html, connection.html, geographic_features.html) — add help triggers
- Accept: Every admin section has `?` icon. Panel loads section-specific help.

**QC (Opus) — after Phase 1:** Walk wizard steps 1-15 on weather-dev. Verify `?` icon visible on every step. Click `?` — panel slides in with placeholder content (or "Help content coming soon" if content not yet authored). Close with Escape. Verify keyboard focus management. Verify mobile layout. Verify admin sections have `?` icons. `python -m py_compile` on all modified Python files.

---

### PHASE 2 — Help Content

> ⚠️ NEEDS DETAIL: The actual help text for each wizard step and admin section has not been authored. This phase requires content authoring for all 17 wizard steps and all admin sections. The structure and key naming convention are defined; the content itself needs to be written per-step.

**T2.1 — Author wizard help content (English)**
- Owner: Coordinator (Opus) — original content authoring for non-technical audience
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/en.json`
- Do: Add structured help keys for all 17 wizard steps. Each step gets 2-3 keys:
  - `help.wizard.{step_id}.title` — step purpose (one line)
  - `help.wizard.{step_id}.body` — detailed guidance (markdown, 3-10 paragraphs)
  - `help.wizard.{step_id}.tip` — best practice tip (one line, optional)

  Steps requiring content:
  | Step ID | Step name | Content focus |
  |---------|-----------|---------------|
  | `step_language` | Language Selection | Explains wizard UI language vs station default locale |
  | `step_api` | API Connection | Trust handshake, fingerprint verification, what happens behind the scenes |
  | `step_import` | Skin Import | What gets imported from Belchertown, what to expect |
  | `step_eula` | EULA | Summary of key terms, what operator is agreeing to |
  | `step_db` | Database | SQLite vs MariaDB, auto-detection, when to override |
  | `step_schema` | Column Mapping | What columns are, confidence levels, when to adjust |
  | `step_station` | Station Identity | Location, timezone, altitude, station photo, about text |
  | `step_units` | Display Units | Presets, per-group overrides, what visitors see |
  | `step_providers` | Data Providers | Provider comparison, key acquisition, observed vs model-based AQI |
  | `step_webcam` | Webcam | Setup requirements, capture process, refresh interval |
  | `step_appearance` | Appearance & Branding | Accent colors, logos, theme mode, social links, custom CSS |
  | `step_privacy_legal` | Privacy, Legal & Analytics | Region selection, GA consent, policy overrides |
  | `step_feature_settings` | Feature Settings | Earthquake radius, display preferences |
  | `step_tls` | TLS Configuration | Self-signed vs ACME, domain requirements, behind-proxy mode |
  | `step_review` | Review & Apply | What happens on apply, service restarts, what to verify after |
  | `step_complete` | Complete | Next steps, admin access, verification checklist |

  ⚠️ NEEDS DETAIL: Each step's body content needs to be authored. The table above defines the scope; the actual paragraphs are written during execution. Brief the agent with the step template content, the relevant manual sections, and the target audience (non-technical weather station operator).

- Accept: All 17 steps have help keys in en.json. Markdown renders correctly via `translate_md()`. Content is helpful and accurate.

**T2.2 — Author admin help content (English)**
- Owner: Coordinator (Opus) — original content authoring
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/en.json`
- Do: Add structured help keys for all admin sections:

  | Section ID | Section name | Content focus |
  |-----------|-------------|---------------|
  | `station` | Station Identity | How to update station details after initial setup |
  | `database` | Database | Connection changes, migration between SQLite/MariaDB |
  | `providers` | Data Providers | Changing providers, key rotation, observed vs model |
  | `appearance` | Appearance & Branding | Theme changes, logo updates, custom CSS |
  | `social` | Social Media | URL format, where links appear |
  | `analytics` | Analytics & Privacy | GA setup, consent banner behavior, region selection |
  | `webcam` | Webcam | Changing URLs, disabling |
  | `pages` | Page Visibility | What hiding a page does, Now protection |
  | `card_layout` | Now Page Layout | Drag-and-drop, footprints, saving |
  | `column_mapping` | Column Mapping | When to remap, impact on charts/records |
  | `tls` | TLS | Certificate renewal, mode changes |
  | `sky_classification` | Sky Classification | What the thresholds mean, sensor accuracy |
  | `haze_calibration` | Haze Calibration | Monthly grid, sensor override, reset implications |
  | `forecast_correction` | Forecast Correction | Training data, retrain schedule, enabling corrections |
  | `geographic_features` | Geographic Features | Map data download, storage requirements |

  ⚠️ NEEDS DETAIL: Same as T2.1 — content needs to be authored per section.

- Accept: All admin sections have help keys in en.json. Content is accurate and helpful.

**T2.3 — Populate ConfigField help_text and wizard_help**
- Owner: `clearskies-stack-dev` (Sonnet) — mechanical: populate fields from Opus-authored content
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/registry/declarations.py`
- Do: For all ~40 `ConfigField` declarations, populate:
  - `help_text` — what this field does, valid values, impact of changes (shown in admin)
  - `wizard_help` — same but with additional first-time guidance (shown in wizard, falls back to `help_text` if empty)
- Also add corresponding translation keys to en.json for each help_text/wizard_help value.

  ⚠️ NEEDS DETAIL: The exact help text per field needs to be authored. The registry field list from `declarations.py` defines the scope.

- Accept: All ~40 fields have non-empty `help_text`. `wizard_help` populated where it differs. All strings passed through `_()` in templates.

**T2.4 — Add inline help to hand-built wizard step templates**
- Owner: `clearskies-stack-dev` (Sonnet) — template edits from Opus-authored hint text
- Files: All hand-built step templates (~11 files: step_api, step_import, step_eula, step_db, step_schema, step_station, step_units, step_providers, step_review, step_complete, step_language)
- Do: For every `<input>`, `<select>`, and `<textarea>` that lacks a `<small>` hint, add a `<small id="help_...">{{ _("...") }}</small>` with `aria-describedby` on the input.
- Accept: Every form input in every wizard step has an associated help hint. All hints translatable via `_()`.

**T2.5 — Translate all help content to 12 non-English locales**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical translation from Opus-authored English
- Files: 12 files in `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/{locale}.json`
- Do: Translate all new help keys (wizard step help, admin section help, field help_text, field wizard_help, inline hints) to all 12 non-English locales.
- Accept: All 12 locale files have complete translations for all new keys. `JSON.parse` succeeds on each.

**QC (Opus) — after Phase 2:** Walk wizard with help panel open for 5 representative steps (step_api, step_db, step_providers, step_appearance, step_tls). Verify content is helpful, accurate, and renders correctly. Switch to German locale — verify help renders in German. Check admin help for 3 sections (providers, sky_classification, haze_calibration). Spot-check 5 registry fields for populated `help_text`.

---

### PHASE 3 — Operator Manual

> ⚠️ NEEDS DETAIL: The manual content itself has not been written. This phase defines the structure, file locations, and acceptance criteria. Actual content is authored during execution.

**T3.1 — Scaffold manual structure**
- Owner: Coordinator (Opus) — establishes voice and structure
- File: New `repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md`
- Do: Create the file with the full section outline (11 sections + table of contents), placeholder text in each section noting what content goes there, and a "Support Scope" section with the boundaries we defined (supported, acknowledged-not-supported, not-documented).
- Accept: File exists with complete structure. Each section has a clear description of what it will contain.

**T3.2 — System Requirements section**
- Owner: Coordinator (Opus) + `clearskies-docs-author` (Sonnet)
- Coordinator measures actual resource usage on running containers:
  - SSH to `weewx` container: measure API process RSS, disk usage of venv + deps, disk usage of skyfield ephemeris
  - SSH to `weather-dev` container: measure dashboard build peak memory, built `dist/` size, Caddy RSS, config UI RSS
  - Catalog heavy transitive deps with approximate installed sizes:
    - API: numpy (~30 MB), scipy (~120 MB), pandas (~50 MB), scikit-learn (~25 MB), pvlib (~10 MB), skyfield (~5 MB code + ~30 MB ephemeris), cryptography (~15 MB), SQLAlchemy (~15 MB)
    - Dashboard build: Node 22 + npm deps. CJK fonts (Noto Sans JP/SC/TC: ~5-15 MB each)
    - Stack: timezonefinder (~40 MB timezone boundary data)
    - TrueSun: pvlib + pandas + numpy (shared with API if co-located) + optional netCDF4/cdsapi
  - Per-component table: CPU, RAM idle, RAM peak, storage (code + deps + data)
  - Minimum specs for single-host and two-host topologies
  - Raspberry Pi 4 feasibility assessment
- Sonnet writes the section from coordinator's measurements.
- Accept: Table with measured values, not estimates. Pi 4 yes/no clearly stated.

**T3.3 — Installation — Native path**
- Owner: Coordinator (Opus)
- Do: Operator-facing step-by-step guide. Adapts OPERATIONS-MANUAL.md §1 from developer-oriented to operator-oriented. Covers: prerequisites, Python 3.12+ venv creation, pip install, systemd unit setup, Caddy configuration, first-run wizard, verification.
- Accept: A non-technical operator can follow the guide from a fresh Debian/Ubuntu install to a running dashboard.

**T3.4 — Installation — weewx extensions**
- Owner: Coordinator (Opus)
- Do: Separate sections for ClearSkiesLoopRelay (required) and ClearSkiesTruesun (optional).
  - Loop Relay: `weectl extension install`, verify socket creation, troubleshooting
  - TrueSun: dependencies (pvlib, cdsapi, h5netcdf/netCDF4), CAMS API key registration, weewx.conf stanza, verification (check `maxSolarRad` values at sunrise)
- Accept: Each extension has prerequisites, install command, config, verification.

**T3.5 — Under the Hood**
- Owner: Coordinator (Opus) — educational writing explaining complex systems accessibly
- Do: Educational content (no support obligation) covering:
  - Sky conditions engine: Duchon-O'Malley architecture, CAELUS indices, ring buffer, dynamic thresholds, seven labels, night fallback
  - Enrichment pipeline: Beaufort scale, comfort index, barometer trend, wind averages, weather text composition
  - Forecast correction: Random Forest, pair collection, training cycle, enabling
  - Unit conversion pipeline: source → group → display unit → label
  - Data flow: weewx → Loop Relay → Unix socket → API → SSE/REST → Dashboard
  - Haze detection: two-channel, RH-graduated PM, solar elevation gate, monthly calibration
- Accept: Technically accurate. Explains concepts without requiring meteorology background. Cross-references API-MANUAL.md for implementation details.

  ⚠️ NEEDS DETAIL: Each sub-section needs to be authored. The list above defines scope.

**T3.6 — Charts Configuration deep dive**
- Owner: Coordinator (Opus)
- Do: Operator-facing guide to `charts.conf`. Covers: INI syntax, three-level nesting (group → chart → series), special series types (windRose, weatherRange, haysChart), custom SQL queries, migration from Belchertown (`clearskies-migrate-charts`), common operator customizations.
- Accept: Operator can add a new chart group, customize colors, add a custom SQL series by following the guide.

  ⚠️ NEEDS DETAIL: Specific examples and code samples need to be authored.

**T3.7 — Remaining manual sections**
- Owner: Coordinator (Opus)
- Sections: Quick Start, First-Run Wizard guide, Admin Guide, Troubleshooting, Getting Help, Support Scope, Legal
- Do: Author each section per the outline in the Context section above.

  ⚠️ NEEDS DETAIL: All content needs to be written. Key constraints:
  - Quick Start: 15-minute path, minimal config
  - Wizard/Admin guides: cross-reference in-app help, don't duplicate
  - Troubleshooting: common issues (API won't start, dashboard errors, provider key rejected, connection refused)
  - Getting Help: GitHub issue template, what to include (logs, config redacted, browser console)
  - Support Scope: exact boundaries from dialog (supported / acknowledged-not-supported / not-documented)
  - Legal: license summary, permitted uses, commercial requirements, provider compliance, legal translation policy (what's translated, what's not, why, disclaimer requirements). Depends on Phase 0.

- Accept: All 11 manual sections written. Support scope clearly delineated. Legal section matches license documents. Translation policy documented.

**T3.8 — Graphics and diagrams**
- Owner: Coordinator (Opus)
- Do: Create SVG diagrams for inclusion in the manual:
  - Two-host vs single-host topology
  - Data flow: weewx → API → Dashboard
  - Sky classification decision tree
  - Enrichment pipeline flow
  - Wizard step flow overview

  ⚠️ NEEDS DETAIL: Exact diagrams identified during content authoring (T3.5-T3.7). This task executes after content is written.

- Accept: Diagrams are clear, readable, and accurate. SVG format for quality at any size.

**QC (Opus) — after Phase 3:** Read full manual end-to-end. Verify system requirements match measured values. Walk native install guide mentally against OPERATIONS-MANUAL.md for accuracy. Verify support scope matches dialog. Verify legal section matches Phase 0 license documents. Verify no content duplicates in-app help verbatim (cross-references instead).

---

### PHASE 4 — Doc-Code Sync Rule Updates

**T4.1 — Add help text sync rule**
- Owner: Coordinator (Opus)
- File: `rules/clearskies-process.md`
- Do: Add rule: "When a wizard step's behavior, fields, or options change, the step-level help content (`help.wizard.{step_id}.*` translation keys) and affected field-level help text (`ConfigField.help_text` / `wizard_help`) must be updated in the same commit."
- Accept: Rule added, clear and actionable.

**T4.2 — Add operator manual sync rule**
- Owner: Coordinator (Opus)
- File: `rules/clearskies-process.md`
- Do: Add rule: "When a feature, configuration option, or operational behavior documented in the Operator Manual changes, the manual must be updated in the same commit or PR. The Operator Manual is a governing document subject to the same doc-code sync rules as ARCHITECTURE.md and the component manuals."
- Accept: Rule added. Manual listed in the doc-code sync table in CLAUDE.md.

**T4.3 — Add license doc sync rule**
- Owner: Coordinator (Opus)
- File: `rules/clearskies-process.md`
- Do: Add rule: "Changes to licensing terms require updates to LICENSE, ADDITIONAL-USES.md, the EULA wizard step, and the dashboard Legal page in the same commit."
- Accept: Rule added.

**T4.5 — Add legal translation policy rule**
- Owner: Coordinator (Opus)
- Files: `rules/coding.md` (§6 i18n section), `rules/clearskies-process.md`
- Do: Add rule documenting what gets translated and what does not, with disclaimer requirements:

  **Legal document translation policy:**
  - `LICENSE` and `ADDITIONAL-USES.md` — English only, never translated. These are the legally binding documents.
  - `EULA.txt` — English is the authoritative version. Translations provided for operator convenience. Every non-English EULA file MUST begin with a bilingual disclaimer (English + target language) stating the English version is the sole legally binding document.
  - Dashboard Legal page content (`legal.json`) — Translated for visitor convenience. Every non-English locale MUST include a `legalDisclaimer` key rendered as a prominent non-dismissible banner at the top of the Legal page.
  - Wizard/admin UI chrome (step titles, labels, buttons, field hints) — Fully translated, no disclaimer needed. These are UI elements, not legal instruments.
  - Help panel content — Fully translated, no disclaimer needed. Educational/guidance content.
  - Operator Manual — English only for v1.

  **Why:** Translated legal text can alter legal meaning and create ambiguity about which version governs in a dispute. Industry standard (Stripe, Apple, FSF/GPL) is to translate for understanding but disclaim for legal authority. The English version under California governing law is always authoritative.

- Accept: Rule added to both files. Clear and comprehensive.

**T4.4 — Update CLAUDE.md doc-code sync table**
- Owner: Coordinator (Opus)
- File: `CLAUDE.md`
- Do: Add rows to the "What counts as a governing document change" table:
  - "Changing wizard step behavior or fields → update help content keys + Operator Manual §4"
  - "Changing admin section behavior → update admin help content keys + Operator Manual §5"
  - "Changing licensing terms → update LICENSE, ADDITIONAL-USES.md, EULA, Legal page"

**QC (Opus) — after Phase 4:** Verify all new rules are present in `rules/clearskies-process.md`. Verify CLAUDE.md doc-code sync table updated.

---

### PHASE 5 — Deploy & Final Verification

**T5.1 — Deploy config UI (stack)**
- Owner: Coordinator (Opus)
- Do: Push stack repo. Restart config UI service. Verify EULA step renders with version 2.0. Verify help panels work on all wizard steps.
- Accept: EULA re-acceptance triggered by version change. Help panels render. All translations load.

**T5.2 — Deploy dashboard**
- Owner: Coordinator (Opus)
- Do: `tsc --noEmit` passes. `npm run build` succeeds. Deploy via `scripts/redeploy-weather-dev.sh`.
- Accept: Legal page renders with updated license. All legal content translations load.

**T5.3 — Verify end-to-end**
- Owner: Coordinator (Opus)
- Do:
  1. Walk full wizard flow: EULA acceptance (version 2.0) → all steps → verify help panel on every step
  2. Walk admin: verify help panels on all sections
  3. Legal page: verify PolyForm NC language, permitted uses, commercial requirements
  4. Switch locale to de, ja, pt-BR: verify help and legal content render in each
  5. Verify operator manual is present in stack repo and complete
- Accept: All verifications pass. Evidence recorded.

---

## 3. Agent Assignments

### Writing quality split

**Opus writes all original English content** — the ADDITIONAL-USES.md, EULA updates, operator manual prose, wizard/admin help content, and doc-code sync rules. These are audience-facing documents where tone, clarity, and nuance matter. The documentation IS the deliverable here, not a byproduct of code.

**Sonnet handles mechanical work** — translations to 12 locales, copying files across repos, populating registry `help_text` fields from Opus-authored outlines, template integration (CSS/JS/macro/route wiring), and verification steps.

| Phase | Task | Owner | Model | Why |
|-------|------|-------|-------|-----|
| 0 | T0.1 License text fetch | Coordinator | Opus | — |
| 0 | T0.2 Author ADDITIONAL-USES.md | Coordinator | Opus | Quasi-legal document; tone and precision critical |
| 0 | T0.3-T0.4 Copy LICENSE + ADDITIONAL-USES to repos | `clearskies-docs-author` | Sonnet | Mechanical file copy |
| 0 | T0.5 Update LICENSE-RATIONALE.md | Coordinator | Opus | Explains a significant decision; needs clear reasoning |
| 0 | T0.6 Author new ADR | Coordinator | Opus | ADR authoring is a coordinator responsibility |
| 0 | T0.7 Update EULA text (English) | Coordinator | Opus | Legal language; every word matters |
| 0 | T0.8 Translate EULA (12 locales) | `clearskies-docs-author` | Sonnet | Mechanical translation from English original |
| 0 | T0.9 Update EULA wizard template + translation keys | `clearskies-docs-author` | Sonnet | Template edits + key updates |
| 0 | T0.10 Update dashboard legal.json (English) | Coordinator | Opus | Audience-facing legal content |
| 0 | T0.11 Translate legal.json (12 locales) | `clearskies-docs-author` | Sonnet | Mechanical translation |
| 0 | T0.12 Update CLAUDE.md | Coordinator | Opus | — |
| 1 | T1.1-T1.8 Help infrastructure (CSS/JS/macro/routes/templates) | `clearskies-stack-dev` | Sonnet | Code, not prose |
| 2 | T2.1 Author wizard help content (English) | Coordinator | Opus | Core user-facing content; must be clear for non-technical operators |
| 2 | T2.2 Author admin help content (English) | Coordinator | Opus | Same — audience-facing prose |
| 2 | T2.3 Populate ConfigField help_text/wizard_help | `clearskies-stack-dev` | Sonnet | Mechanical: populate fields from Opus-authored content outlines |
| 2 | T2.4 Add inline help to hand-built templates | `clearskies-stack-dev` | Sonnet | Template edits from Opus-authored hint text |
| 2 | T2.5 Translate help content (12 locales) | `clearskies-docs-author` | Sonnet | Mechanical translation |
| 3 | T3.1 Scaffold manual structure | Coordinator | Opus | Establishes the voice and structure |
| 3 | T3.2 System Requirements (measurement) | Coordinator | Opus | Requires SSH to containers + judgment |
| 3 | T3.3 Installation — Native path | Coordinator | Opus | Must be clear enough for a non-technical operator |
| 3 | T3.4 Installation — weewx extensions | Coordinator | Opus | Technical but audience-facing |
| 3 | T3.5 Under the Hood | Coordinator | Opus | Educational writing; explaining complex systems accessibly |
| 3 | T3.6 Charts Configuration | Coordinator | Opus | Operator-facing guide with examples |
| 3 | T3.7 Remaining manual sections | Coordinator | Opus | All audience-facing prose |
| 3 | T3.8 Graphics | Coordinator | Opus | Diagrams require architectural understanding |
| 4 | T4.1-T4.5 Rules + CLAUDE.md + translation policy | Coordinator | Opus | Rule authoring is coordinator work |
| 5 | T5.1-T5.3 Deploy + verify | Coordinator | Opus | — |

**Sequencing:**
- Phase 0 (license) → all other phases (everything references the license)
- Phase 1 (help infrastructure) → Phase 2 (help content requires the infrastructure)
- Phase 1 can run in parallel with Phase 0 (infrastructure doesn't reference license content)
- Phase 2 (help content) and Phase 3 (manual) can partially overlap — manual sections that don't cross-reference help can start during Phase 2
- Phase 4 (rules) can run after Phase 0 completes
- Phase 5 (deploy) after all content phases complete

---

## 4. QC Gates

### Gate 1 — License Correctness (after Phase 0)
- Grep all 4 core repos for "GPL", "GNU", "General Public License" — zero hits in non-git-history files
- Extension/truesun repos unchanged (still GPL v3)
- EULA version 2.0 renders in wizard
- Dashboard Legal page shows PolyForm Noncommercial language
- ADDITIONAL-USES.md present in all 4 core repos
- New ADR exists with status `Proposed`
- ADR-003 marked `Superseded`

### Gate 2 — Help Infrastructure (after Phase 1)
- `?` icon visible on every wizard step (17 steps)
- `?` icon visible on every admin section
- Panel opens/closes with click and Escape
- Focus management correct (focus to panel on open, return on close)
- HTMX content loading works (even with placeholder content)
- Mobile overlay renders full-screen
- `python -m py_compile` on all modified Python files

### Gate 3 — Help Content Quality (after Phase 2)
- Walk wizard with help panel open for 5 representative steps
- Help content is helpful, accurate, and non-trivial (not just restating the field label)
- Markdown renders correctly (paragraphs, lists, bold, links)
- Switch to 3 non-English locales — help renders in each
- All ~40 registry fields have populated `help_text`
- All hand-built wizard inputs have `<small>` hints

### Gate 4 — Manual Completeness (after Phase 3)
- All 11 sections present and non-empty
- System requirements contain measured (not estimated) values
- Native install guide is followable by a non-technical operator
- Support scope section matches dialog decisions exactly
- Legal section matches Phase 0 license documents
- No content duplicates in-app help verbatim
- Graphics are clear and accurate

### Gate 5 — Accessibility (after Phase 1 + Phase 2)
- Help trigger button: `aria-label`, `aria-expanded`, focus indicator
- Help panel: `role="complementary"`, `aria-label`, scrollable, focus management
- Close button: `aria-label="Close help"`, visible focus indicator
- Mobile overlay: focus trap while open
- All new form inputs in hand-built templates: `<label>` + `aria-describedby`
- axe-core on wizard with help panel open: 0 violations

---

## 5. Self-Audit

**Risk: PolyForm Noncommercial may not cover all edge cases.** The Additional Permitted Uses document addresses the scenarios discussed (family farms, HOAs, citizen science). Edge cases not explicitly listed fall to the base license's "noncommercial purposes" definition. The commercial licensing contact provides a human resolution path for genuine gray areas.

**Risk: EULA version change triggers re-acceptance for all operators.** This is intentional — the license change from GPL v3 to PolyForm NC is significant enough to warrant re-acceptance. The wizard auto-detects the version bump and requires the operator to read and accept the updated terms.

**Risk: Help content quality.** First-time help authoring across 17 wizard steps and 15+ admin sections is a large content task. QC Gate 3 spot-checks 5 steps, but comprehensive quality review of all help content should happen during Phase 5 deployment testing. Brief the docs-author agent with relevant manual sections, step template content, and target audience.

**Risk: Markdown in JSON translation values.** JSON doesn't support multi-line strings natively. Markdown content in translation values will use `\n` for line breaks. This is ugly for translators but functional. The `translate_md()` function handles rendering. Alternative: separate markdown files per locale per step — rejected for pipeline complexity.

**Risk: Translation volume.** Phase 0 + Phase 2 together add significant translation work (EULA × 12, legal.json × 12, ~200+ new help keys × 12). This is the largest single translation effort since the initial i18n compliance. Budget agent time accordingly.

**Risk: System requirements measurement.** Measured values depend on the current workload and configuration on weewx/weather-dev. Document the measurement conditions (date, uptime, active providers, archive size) so future readers know the context.

**Risk: Manual maintenance burden.** A standalone operator manual is another governing document to keep current. Phase 4 adds explicit doc-code sync rules to mitigate. The manual should reference the code as source of truth for volatile parts (step inventory, provider list, field names) and document only stable patterns — same principle as ARCHITECTURE.md.
