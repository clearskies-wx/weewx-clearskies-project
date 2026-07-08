# Operator Documentation, Help System & Licensing — Execution Plan

**Status:** COMPLETE  
**Created:** 2026-07-02  
**Completed:** 2026-07-07  
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
- GPL v3 references exist in: EULA.txt (§1, §2, §6, §7, §16), legal.json (4 locations), LICENSE (3 core repos + 2 extension repos), LICENSE-RATIONALE.md (3 core repos), ADR-003. Note: design-tokens repo removed, realtime repo archived — no longer applicable.
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
| A1 | LICENSE files (api, dashboard, stack) | GPL v3 verbatim (675 lines each) | PolyForm Noncommercial 1.0.0 full text. Note: design-tokens repo deleted (Phase 6+ placeholder with no code, removed 2026-07-02). |
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
| C3 | Installation — Native path | Unblocked — `scripts/setup.sh` (interactive, handles network stack selection) + `scripts/install-prerequisites.sh` + parameterized systemd units all created by BETA-RELEASE-PLAN (2026-07-02). INSTALL.md has numbered dependency chain. Content ready to write as operator-facing guide. |
| C4 | Installation — Docker compose | Unblocked — compose files finalized, `scripts/setup.sh` handles Docker setup interactively (asks topology, network stack, domain, generates .env + secrets.env + api.conf). Content ready to write. |
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

### PHASE 0 — License Change ✅ COMPLETE (2026-07-02)

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

**T0.3 — Replace LICENSE files in 3 core repos**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical file replacement
- Files:
  - `repos/weewx-clearskies-api/LICENSE`
  - `repos/weewx-clearskies-dashboard/LICENSE`
  - `repos/weewx-clearskies-stack/LICENSE`
- Do: Replace GPL v3 text with PolyForm Noncommercial 1.0.0 full text.
- Accept: All 3 files contain PolyForm NC 1.0.0. Extension and truesun repos unchanged (GPL v3).
- Note: design-tokens repo removed (2026-07-02) — was a Phase 6+ placeholder with no code.

**T0.4 — Copy ADDITIONAL-USES.md to 3 core repos**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical file copy
- Files: `ADDITIONAL-USES.md` in api, dashboard, stack repos
- Do: Copy the authored document from T0.2 to each repo root.
- Accept: Identical `ADDITIONAL-USES.md` in all 3 repos.

**T0.5 — Update LICENSE-RATIONALE.md in 3 repos**
- Owner: Coordinator (Opus)
- Files:
  - `repos/weewx-clearskies-api/LICENSE-RATIONALE.md`
  - `repos/weewx-clearskies-dashboard/LICENSE-RATIONALE.md`
  - `repos/weewx-clearskies-stack/LICENSE-RATIONALE.md`
- Do: Explain license change from GPL v3 to PolyForm NC 1.0.0. Explain weewx extension repos remain GPL v3 (derivative works of GPL v3 weewx). Reference new ADR.
- Accept: All 3 files updated. Rationale clearly explains the change and the split.
- Note: realtime repo archived per ADR-058, design-tokens repo removed — neither needs updating.

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

**QC (Opus) — after Phase 0:** Grep all 3 core repos (api, dashboard, stack) for "GPL", "GNU", "General Public License" — verify zero remaining references except in git history. Verify extension/truesun repos unchanged (GPL v3). EULA renders in wizard with version 2.0. Dashboard Legal page renders updated license section. ADR-003 marked superseded. New ADR exists as Proposed.

---

### PHASE 1 — Help System Infrastructure ✅ COMPLETE (2026-07-03)

> Build the help panel component and wiring before adding content.

**T1.1 — Create help panel CSS**
- Owner: `general-purpose` (Sonnet)
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
- Owner: `general-purpose` (Sonnet)
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
- Owner: `general-purpose` (Sonnet)
- File: New `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/macros/help_panel.html`
- Do: Reusable macro `{% macro help_trigger(help_url, label="Help") %}` that emits:
  - A `?` button with `aria-label="{{ label }}"`, `aria-expanded="false"`, `aria-controls="help-panel"`
  - The panel `<aside>` container (hidden by default) with `role="complementary"`, `aria-label="Help"`, close button, scrollable content area with `id="help-panel-content"` and `hx-get="{{ help_url }}"` + `hx-trigger="intersect once"`
- Accept: Macro renders valid HTML. `aria-*` attributes correct. HTMX attributes present.

**T1.4 — Add markdown rendering to i18n pipeline**
- Owner: `general-purpose` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/pyproject.toml` — add `markdown>=3.6` dependency
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/i18n.py` — add `translate_md(key, locale)` function that calls `translate()` then pipes through `markdown.markdown()` with `extensions=['tables', 'fenced_code']`, returns `Markup()`
- Do: New function alongside existing `translate()`. Does not modify `translate()` behavior. Used only for help body content (long-form markdown). Field labels and short help text continue using `translate()`.
- Accept: `translate_md("help.wizard.step_db.body")` returns rendered HTML `Markup`. Existing `_()` behavior unchanged.

**T1.5 — Add help route handlers to wizard routes**
- Owner: `general-purpose` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py`
- Do: Add `GET /wizard/help/{step_id}` route that:
  1. Reads help translation keys: `help.wizard.{step_id}.title`, `help.wizard.{step_id}.body`, `help.wizard.{step_id}.tip` (optional)
  2. Renders body through `translate_md()`, title/tip through `translate()`
  3. Returns an HTML fragment (not a full page) for HTMX swap into the help panel
- Template: New `templates/wizard/help_fragment.html` — simple `<h3>{{ title }}</h3><div>{{ body }}</div>{% if tip %}<aside class="help-tip">{{ tip }}</aside>{% endif %}`
- Accept: `GET /wizard/help/step_db` returns HTML fragment with rendered help content. 404 for unknown step_id.

**T1.6 — Add help route handlers to admin routes**
- Owner: `general-purpose` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/config/routes.py` (or `admin/routes.py` — verify correct file)
- Do: Add `GET /admin/help/{section_id}` route, same pattern as T1.5.
- Accept: `GET /admin/help/providers` returns HTML fragment.

**T1.7 — Integrate help trigger into wizard layout**
- Owner: `general-purpose` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/layout.html` — add `<link>` to `help-panel.css` in `<style>` block (or as external `<link>`), add `<script src>` for `help-panel.js`
  - Each of the 17 `step_*.html` templates — add `{% from "macros/help_panel.html" import help_trigger %}` and `{{ help_trigger("/wizard/help/{step_id}") }}` in the `<header>` section of each step, next to the `<h2>`
- Do: The `?` icon appears in every wizard step header. Step templates that are HTMX-swapped carry the macro call.
- Accept: Every wizard step shows `?` icon. Clicking opens side panel. Content loads for each step.

**T1.8 — Integrate help trigger into admin templates**
- Owner: `general-purpose` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/landing.html` — add CSS/JS links
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/generic_section.html` — add help trigger in section header
  - Custom admin templates (sky_classification.html, haze_calibration.html, forecast_correction.html, card_layout.html, connection.html, geographic_features.html) — add help triggers
- Accept: Every admin section has `?` icon. Panel loads section-specific help.

**QC (Opus) — after Phase 1:** Walk wizard steps 1-15 on weather-dev. Verify `?` icon visible on every step. Click `?` — panel slides in with placeholder content (or "Help content coming soon" if content not yet authored). Close with Escape. Verify keyboard focus management. Verify mobile layout. Verify admin sections have `?` icons. `python -m py_compile` on all modified Python files.

---

### PHASE 2 — Help Content ✅ COMPLETE (2026-07-04)

> Content authoring for all wizard steps and admin sections.

**T2.1 — Author wizard help content (English)** ✅ COMPLETE (2026-07-03)
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

**T2.2 — Author admin help content (English)** ✅ COMPLETE (2026-07-04)
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
- **COMPLETED (2026-07-04):** Re-execution done across commits 626486a, af59c7f, 9d2bb08 (British→US spelling, "dashboard"→"weather site", orphaned keys removed, provider names fixed). Final pass added missing help content for station, database, and per-provider config editor sections (provider_forecast, provider_alerts, provider_aqi, provider_earthquakes, provider_radar) with help triggers added to config/section.html, config/provider_section.html, and config/column_mapping.html.

  **Granular change list — apply to each admin help section (`help.admin.*` keys in en.json):**

  **Global rules (apply to ALL admin help keys):**
  - Replace every instance of "dashboard" with "your weather site" or "weather site"
  - British → US English spelling: "customise" → "customize", "customisation" → "customization", "colour" → "color", "colours" → "colors", "organisation" → "organization", "metres" → "meters", "kilometres" → "kilometers", "centimetres" → "centimeters", "millimetres" → "millimeters", "recognised" → "recognized", "standardised" → "standardized"
  - Define technical terms on first use — do not assume the reader knows jargon
  - Every field that accepts a path/URL should include examples of both formats (e.g. `/images/logo.svg` and `https://example.com/logo.png`)

  **Per-section changes:**

  | Admin section | Wizard step it mirrors | Specific changes required |
  |---|---|---|
  | `station` | Step 6 | (1) Add "Pre-filled values" section noting fields come from weewx.conf. (2) Add warning: "Clear Skies does not write changes back to weewx.conf — update it manually to keep in sync." (3) Add decimal degrees example: `40.7128` / `-74.0060`. (4) Explain default language: "what your visitors see by default, not what you see in the admin." (5) Split photo/description into separate subsections. (6) Explain alt text with example ("Davis Vantage Pro2 mounted on a rooftop pole"). (7) Station description: explain purpose, appears on About page, keep to 2–3 sentences. |
  | `database` | Step 4 | **DEFERRED** — do not update until PINNED-ITEMS.md #2 (SQLite support) is resolved. Current content is MySQL-only; rewrite must cover both SQLite and MySQL paths, remind operator which type was detected, and explain how to recover credentials. |
  | `column_mapping` | Step 5 | (1) Replace "canonical name" with "tell Clear Skies what the column measures." (2) Lead with consequence: "If a column is not mapped, Clear Skies cannot read it — that measurement will not appear anywhere on your weather site." (3) Replace tip: "If you skip a custom column, you can always map it later — no data is lost from your weewx database." |
  | `providers` | Step 9 | **DEFERRED** — do not update until PINNED-ITEMS.md #6–12 are resolved (auto-selection removal, OWM/OpenAQ removal, haze bootstrap removal, comprehensive per-provider details). When re-executing: (1) Remove any "Selected for your location" language. (2) Remove all OpenAQ bootstrap references. (3) Remove OWM from AQI references. (4) Replace "keyless" with "no key needed." (5) Add per-provider collapsible details with registration links. |
  | `appearance` | Step 11 | (1) US spelling throughout. (2) Logo file requirements: SVG preferred, PNG with transparent background, max 500 KB, recommended ~200–400 × 40–80 px horizontal layout, warn vertical logos look oversized. (3) Explain upload OR path/URL with examples. (4) Favicon: ICO or PNG, 32×32 or 64×64 px, max 100 KB. (5) Remove Custom CSS section (per PINNED-ITEMS.md #14). (6) Remove Social Media section (per PINNED-ITEMS.md #23). |
  | `social` | Step 11 | **REMOVE ENTIRELY** — per PINNED-ITEMS.md #23, social media links are being removed from both wizard and admin. Delete the admin help keys for this section when the code removal happens. |
  | `analytics` | Step 12 | (1) Explain what visitor analytics is (track visits, page views, where visitors come from). (2) State we support Google Analytics. (3) Explain why privacy regions matter — laws require consent before tracking. (4) Bold disclaimer: operator is responsible for compliance. (5) Legal templates: "not legal advice, we are not lawyers, verify in your jurisdiction." (6) State built-in templates are translated to 13 languages. (7) Uploaded replacements are shown as-is — operator must provide own translations. |
  | `webcam` | Step 10 | (1) List supported formats: JPEG/PNG/GIF/WebP for still images, MP4 (H.264) for video. (2) Add path/URL format examples for both fields. (3) Explain refresh interval with example ("60 = once a minute"). |
  | `tls` | Step 14 | (1) Add "What is TLS?" section explaining encryption for laypersons (padlock icon, HTTPS, why it matters). (2) Self-signed: operator must provide own cert, we do not generate one; if cert is on a proxy, select Behind Proxy. (3) ACME: only when server is directly exposed to internet; if running ACME on NPM/Traefik, select Behind Proxy. (4) Behind Proxy: list examples (NPM, Traefik, Cloudflare/CDN, corporate load balancer). (5) Manual: PEM format — server cert + intermediates in one file, private key separate. (6) Tip: recommend public certificate since self-signed causes browser warnings. |
  | `pages` | N/A | Review for jargon and "dashboard" references. No wizard-specific changes to port. |
  | `card_layout` | N/A | Review for jargon and "dashboard" references. No wizard-specific changes to port. |
  | `sky_classification` | N/A | Review for jargon. No wizard-specific changes to port. |
  | `haze_calibration` | N/A | Review for jargon. Verify haze bootstrap references are removed (per PINNED-ITEMS.md #8). |
  | `forecast_correction` | N/A | Review for jargon and "dashboard" references. No wizard-specific changes to port. |
  | `geographic_features` | N/A | Review for jargon and "dashboard" references. No wizard-specific changes to port. |

  **Also update registry field `help_text` values (declarations.py) that were fixed during wizard review:**
  - `earthquakes.radius_km` — "kilometers" not "kilometres"
  - `earthquakes.min_magnitude` — "Moment Magnitude scale (Mw)" not "Richter scale"
  - `earthquakes.default_days` — "How many days of earthquake history to show by default"
  - `webcam.image_url` — "Path or URL" not just "URL"
  - `webcam.video_url` — "Path or URL", note "MP4 format"
  - `branding.favicon_url` — "Path or URL", note "ICO or PNG, 32×32 or 64×64"
  - `branding.logo_light_url` / `branding.logo_dark_url` — "Upload a file or enter a path/URL"
  - `branding.copyright_entity` — "organization" not "organisation"

**T2.3 — Populate ConfigField help_text and wizard_help** ✅ COMPLETE (2026-07-03)
- Owner: `general-purpose` (Sonnet) — mechanical: populate fields from Opus-authored content
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/registry/declarations.py`
- Do: For all ~40 `ConfigField` declarations, populate:
  - `help_text` — what this field does, valid values, impact of changes (shown in admin)
  - `wizard_help` — same but with additional first-time guidance (shown in wizard, falls back to `help_text` if empty)
- Also add corresponding translation keys to en.json for each help_text/wizard_help value.

  ⚠️ NEEDS DETAIL: The exact help text per field needs to be authored. The registry field list from `declarations.py` defines the scope.

- Accept: All ~40 fields have non-empty `help_text`. `wizard_help` populated where it differs. All strings passed through `_()` in templates.

**T2.4 — Add inline help to hand-built wizard step templates** ✅ COMPLETE (2026-07-03)
- Owner: `general-purpose` (Sonnet) — template edits from Opus-authored hint text
- Files: All hand-built step templates (~11 files: step_api, step_import, step_eula, step_db, step_schema, step_station, step_units, step_providers, step_review, step_complete, step_language)
- Do: For every `<input>`, `<select>`, and `<textarea>` that lacks a `<small>` hint, add a `<small id="help_...">{{ _("...") }}</small>` with `aria-describedby` on the input.
- Accept: Every form input in every wizard step has an associated help hint. All hints translatable via `_()`.

**T2.5 — Translate all help content to 12 non-English locales** ✅ COMPLETE (2026-07-05)
- Owner: `clearskies-docs-author` (Sonnet) — mechanical translation from Opus-authored English
- Files: 12 files in `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/{locale}.json`
- Do: Translate all new help keys (wizard step help, admin section help, field help_text, field wizard_help, inline hints) to all 12 non-English locales.
- Accept: All 12 locale files have complete translations for all new keys. `JSON.parse` succeeds on each.
- **COMPLETED (2026-07-05):** 95 missing help keys translated across all 12 locales (de, es, fil, fr, it, ja, nl, pt-BR, pt-PT, ru, zh-CN, zh-TW). Delegated to 4 parallel `clearskies-docs-author` agents (3 locales each). All 12 files validated: 107/107 help keys present, JSON.parse succeeds, 1064 total keys each. zh-TW used Taiwan-specific terminology (伺服器, 資料庫, 規模/震度). pt-PT used European Portuguese (ficheiro, palavra-passe). Scratchpad intermediates preserved at session scratchpad path.

**QC (Opus) — after Phase 2:** Walk wizard with help panel open for 5 representative steps (step_api, step_db, step_providers, step_appearance, step_tls). Verify content is helpful, accurate, and renders correctly. Switch to German locale — verify help renders in German. Check admin help for 3 sections (providers, sky_classification, haze_calibration). Spot-check 5 registry fields for populated `help_text`.

---

### PHASE 3 — Operator Manual ✅ COMPLETE (2026-07-04)

> Operator-facing manual with 13 sections, measured system requirements, and 5 SVG diagrams.

**T3.1 — Scaffold manual structure** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus) — establishes voice and structure
- File: New `repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md`
- Do: Create the file with the full section outline (11 sections + table of contents), placeholder text in each section noting what content goes there, and a "Support Scope" section with the boundaries we defined (supported, acknowledged-not-supported, not-documented).
- Accept: File exists with complete structure. Each section has a clear description of what it will contain.

**T3.2 — System Requirements section** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus)
- Measured on running containers 2026-07-03:
  - API RSS: ~600 MB idle, venv: 602 MB, skyfield ephemeris: 17 MB
  - Caddy RSS: ~43 MB, Config UI RSS: ~61 MB (venv: 286 MB)
  - Dashboard dist: 62 MB (node_modules 783 MB build-only)
  - Redis: 1.4 MB idle, 241 MB peak
  - Key deps: scipy 109 MB, pandas 73 MB, sklearn 49 MB, numpy 34 MB, babel 33 MB, pvlib 32 MB, timezonefinder 64 MB
  - Pi 4 (4 GB): feasible. Pi 4 (2 GB): marginal. Pi 3: not recommended.
- Accept: Table with measured values, not estimates. Pi 4 yes/no clearly stated.

**T3.3 — Installation — Native path** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus)
- Do: Operator-facing step-by-step guide. Adapts OPERATIONS-MANUAL.md §1 from developer-oriented to operator-oriented. Covers: prerequisites, Python 3.12+ venv creation, pip install, systemd unit setup, Caddy configuration, first-run wizard, verification.
- Accept: A non-technical operator can follow the guide from a fresh Debian/Ubuntu install to a running dashboard.

**T3.4 — Installation — weewx extensions** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus)
- Do: Separate sections for ClearSkiesLoopRelay (required) and ClearSkiesTruesun (optional).
  - Loop Relay: `weectl extension install`, verify socket creation, troubleshooting
  - TrueSun: dependencies (pvlib, cdsapi, h5netcdf), CAMS API key registration, weewx.conf stanza, verification (check `maxSolarRad` values at sunrise)
- Accept: Each extension has prerequisites, install command, config, verification.

**T3.5 — Under the Hood** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus) — educational writing explaining complex systems accessibly
- Covers: data flow (station → weewx → Loop Relay → API → Caddy → browser), unit conversion pipeline, sky conditions engine (Duchon-O'Malley / CAELUS indices, Kv/Km variability-first decision tree, 7 labels, dynamic thresholds, night fallback), enrichment pipeline (Beaufort, comfort, barometer trend, wind averages, weather text), forecast correction (Random Forest, pair collection, training), haze detection (two-channel: Kcs deficit + RH-graduated PM, solar elevation gate).
- Accept: Technically accurate. Explains concepts without requiring meteorology background.

**T3.6 — Charts Configuration deep dive** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus)
- Covers: INI syntax, three-level nesting (group → chart → series), all settings tables, special series types (windRose, weatherRange, haysChart) with code examples, cumulative rain example, grouped charts (xAxis_groupby), custom SQL queries, migration from Belchertown.
- Accept: Operator can add a new chart group, customize colors, add a custom SQL series by following the guide.

**T3.7 — Remaining manual sections** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus)
- Sections completed:
  - §1 Quick Start: 15-minute path from weewx + Docker to running dashboard
  - §6 First-Run Wizard guide: overview of every step, cross-references in-app help
  - §7 Admin Guide: all admin sections (station, providers, appearance, pages, layout, column mapping, TLS, sky classification, haze calibration, forecast correction, geographic features)
  - §10 Troubleshooting: common issues (no data, API won't start, no SSE, provider errors, wizard connection, stale data, TLS errors, high memory, collecting bug report info)
  - §11 Getting Help: GitHub issues, what to include, what not to include
  - §12 Support Scope: supported / acknowledged-not-supported / not-documented categories
  - §13 Legal: license summary (PolyForm NC + GPL v3 for extensions), permitted uses, commercial requirements, provider compliance, translation policy with disclaimer requirements
- Accept: All 13 manual sections written. Support scope clearly delineated. Legal section matches license documents. Translation policy documented.

**T3.8 — Graphics and diagrams** ✅ COMPLETE (2026-07-03)
- Owner: Coordinator (Opus)
- Created 5 SVG diagrams in `repos/weewx-clearskies-stack/docs/diagrams/`:
  - `data-flow.svg` — station → weewx → Loop Relay → API → Caddy → browser
  - `topology-two-host.svg` — weewx host (API + Redis) / front-end host (Caddy + dashboard + Config UI)
  - `topology-single-host.svg` — all services on one machine
  - `sky-classification.svg` — decision tree: SZA guard → Kv variability → Km clearness → 7 labels
  - `enrichment-pipeline.svg` — raw data → unit conversion → derived values → labels → sky classification → weather text
  - `wizard-flow.svg` — 16-step wizard flow from Language to Complete
- Accept: Diagrams are clear, readable, and accurate. SVG format for quality at any size.

**T3.9 — Revise manual to match wizard review findings** ✅ COMPLETE (2026-07-04)
- Owner: Coordinator (Opus)
- File: `repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md`
- Do: Apply all findings from the 2026-07-04 wizard help review to the operator manual. Execute AFTER T2.2 re-execution and AFTER all blocking pin items are resolved, so the manual matches the final in-app help.

  **Global changes (apply throughout the entire manual):**
  - Replace "dashboard" with "weather site" or "your weather site" consistently
  - British → US English: "customise/customisation/colour/colours/organisation/metres/kilometres/centimetres/millimetres" → US equivalents
  - Define technical terms on first use for non-technical operators

  **Per-section changes:**

  | Manual section | Changes required |
  |---|---|
  | §1 Quick Start | Replace "dashboard" throughout. Verify no jargon. |
  | §3 Installation — Native | Replace "dashboard" throughout. |
  | §4 Installation — Docker | Replace "dashboard" throughout. |
  | §5 Installation — Extensions | Replace "dashboard" throughout. |
  | §6 First-Run Wizard guide | **Major revision.** This section overviews every wizard step and must match the finalized in-app help: (1) Step 1 API — explain what the API is in plain terms, where to find trust token/fingerprint. (2) Step 2 Import — charts "not transferred automatically," point to migration tool. (3) Step 3 EULA — note English version is legally governing, translation notice exists. (4) Step 4 Database — DEFERRED until SQLite support resolved (pin #2). (5) Step 5 Columns — no "canonical name," explain consequences of unmapped columns. (6) Step 6 Station — pre-filled from weewx.conf, weewx.conf sync warning, decimal degrees example, alt text explained, description guidance. (7) Step 7 Units — US spelling, no "dashboard." (8) Step 9 Providers — remove auto-selection language, remove OWM AQI/OpenAQ/haze bootstrap references, "no key needed" not "keyless." DEFERRED sections per pin items. (9) Step 10 Webcam — supported formats (JPEG/PNG/GIF/WebP still, MP4 video), path/URL examples. (10) Step 11 Appearance — logo specs (SVG preferred, transparent bg, horizontal ~200-400×40-80 px), favicon specs, upload OR path/URL, remove Custom CSS and Social Media references. (11) Step 12 Privacy/Legal — explain analytics, compliance disclaimers, legal template disclaimers, translation status of built-in documents. (12) Step 13 Features — Moment Magnitude (Mw) not Richter, reworded time range. (13) Step 14 TLS — explain TLS for layperson, self-signed = operator provides cert, ACME = direct internet only, Behind Proxy for NPM/Traefik/Cloudflare, PEM format for manual certs. |
  | §7 Admin Guide | Must match T2.2 admin help content after its re-execution. Same per-section changes as the T2.2 granular list above. DEFER sections that depend on unresolved pin items (database, providers, social). |
  | §8 Under the Hood | Check for "Richter scale" → "Moment Magnitude (Mw)." Check for British spellings. |
  | §9 Charts Configuration | Check for "dashboard" and British spellings. |
  | §10 Troubleshooting | Replace "dashboard" throughout. Check for jargon. |
  | §11 Getting Help | Replace "dashboard." No other changes expected. |
  | §12 Support Scope | Review if features being removed (social media links, custom CSS from wizard) affect the scope categories. |
  | §13 Legal | Verify compliance disclaimer language matches the in-app step 12 help: "not legal advice, we are not lawyers." Verify translation policy section matches reality (which documents translated, which English-only, upload-your-own guidance). |

- Accept: Manual content matches finalized in-app help. No jargon mismatch between manual and wizard/admin. Zero British spellings. All deferred sections clearly noted as pending pin item resolution.
- **COMPLETED (2026-07-04):** Global "dashboard"→"weather site" applied in commit af59c7f (39 replacements). Final pass revised §6 (wizard guide — corrected provider lists, added column mapping consequences, station pre-fill/sync warning, decimal degrees, alt text, appearance logo/favicon specs, custom backgrounds, webcam formats, privacy "None/Disabled" option + compliance disclaimers, Moment Magnitude, full TLS mode descriptions) and §7 (admin guide — added database section, corrected provider section structure, fixed TLS to say "filesystem paths" not "upload", fixed geographic features to remove stale bounds reference). Zero British spellings confirmed via grep.

**QC (Opus) — after Phase 3:** Read full manual end-to-end. Verify system requirements match measured values. Walk native install guide mentally against OPERATIONS-MANUAL.md for accuracy. Verify support scope matches dialog. Verify legal section matches Phase 0 license documents. Verify no content duplicates in-app help verbatim (cross-references instead).

---

### PHASE 4 — Doc-Code Sync Rule Updates ✅ COMPLETE (2026-07-07)

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

### PHASE 5 — Deploy & Final Verification ✅ COMPLETE (2026-07-07)

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
| 1 | T1.1-T1.8 Help infrastructure (CSS/JS/macro/routes/templates) | `general-purpose` | Sonnet | Code, not prose |
| 2 | T2.1 Author wizard help content (English) | Coordinator | Opus | Core user-facing content; must be clear for non-technical operators |
| 2 | T2.2 Author admin help content (English) | Coordinator | Opus | Same — audience-facing prose |
| 2 | T2.3 Populate ConfigField help_text/wizard_help | `general-purpose` | Sonnet | Mechanical: populate fields from Opus-authored content outlines |
| 2 | T2.4 Add inline help to hand-built templates | `general-purpose` | Sonnet | Template edits from Opus-authored hint text |
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
- Grep all 3 core repos (api, dashboard, stack) for "GPL", "GNU", "General Public License" — zero hits in non-git-history files
- Extension/truesun repos unchanged (still GPL v3)
- EULA version 2.0 renders in wizard
- Dashboard Legal page shows PolyForm Noncommercial language
- ADDITIONAL-USES.md present in all 3 core repos
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
