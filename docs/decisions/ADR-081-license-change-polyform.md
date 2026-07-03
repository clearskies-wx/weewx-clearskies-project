---
status: Proposed
date: 2026-07-02
deciders: shane
supersedes: ADR-003
superseded-by:
---

# ADR-081: License change — PolyForm Noncommercial 1.0.0

## Context

Clear Skies was originally licensed under GPL v3 (ADR-003) to mirror the weewx
ecosystem. However, GPL v3 permits unrestricted commercial use — any party can
deploy Clear Skies with advertising, paid subscriptions, managed hosting, or
white-labeling without compensating the creator. This conflicts with the
project's intent: free for personal, educational, nonprofit, government, and
community use; commercial revenue-generating use requires a paid license.

The weewx extensions (`weewx-clearskies-extension`, `weewx-clearskies-truesun`)
are genuine derivative works of weewx and must remain GPL v3. The core repos
(API, Dashboard, Config UI) are independent works — they read weewx's config
and database but contain no weewx code.

## Options considered

| Option | Verdict |
|---|---|
| Stay GPL v3 | Exclude — permits the exact commercial use the creator wants to restrict |
| BSL 1.1 (Business Source License) | Exclude — time-delayed conversion to open-source doesn't fit; there is no date at which commercial use should become unrestricted |
| Elastic License 2.0 | Exclude — designed for SaaS protection, overly complex for a self-hosted weather dashboard |
| PolyForm Noncommercial 1.0.0 | **Chosen** — plain-English, well-drafted by experienced licensing attorneys, directly addresses noncommercial intent, already adopted by other projects |
| Custom license | Exclude — legal risk, unfamiliarity, maintenance burden |

## Decision

Core repos (API, Dashboard, Config UI) licensed under **PolyForm Noncommercial
1.0.0**, supplemented by an **ADDITIONAL-USES.md** that extends coverage for
community organizations, family farms, amateur radio operators, agricultural
cooperatives, and tax-exempt organizations. weewx extensions remain GPL v3.

## Consequences

- **Not OSI "open source."** PolyForm NC does not meet the Open Source
  Definition because it restricts commercial use. The source code remains
  publicly available and modifiable for noncommercial purposes.
- **ADDITIONAL-USES.md extends coverage** beyond the base license for
  specifically enumerated use cases (community weather sharing, family farms
  <50 employees, amateur radio, agricultural cooperatives, tax-exempt orgs).
- **Commercial licensing available.** Revenue-generating uses (advertising,
  paid access, managed hosting, large organizations, resale/bundling) require
  a separate paid license from the developer.
- **License split between repos.** Core repos = PolyForm NC. weewx extensions
  = GPL v3. LICENSE-RATIONALE.md in each repo explains the split.
- **EULA version bump.** The EULA moves from version 1.0 (GPL v3 focused) to
  version 2.0 (PolyForm NC focused). Version change triggers mandatory
  re-acceptance in the setup wizard.
- **SPDX inconsistency resolved.** ADR-003 said `GPL-3.0-or-later`; the
  LICENSE-RATIONALE files said `GPL-3.0-only`. Moot for the core repos (now
  PolyForm NC, no SPDX identifier). For the extension/truesun repos, the
  correct identifier is `GPL-3.0-or-later` per ADR-003's reasoning (future
  version compatibility).
- **Dependency license audit:** the existing audit
  (`docs/reference/DEPENDENCY-LICENSE-AUDIT.md`) was against GPL v3
  compatibility. PolyForm NC is more permissive about dependencies (no
  copyleft propagation) so all existing deps remain compatible. Future deps
  do not need GPL-compatibility verification for the core repos.

## Acceptance criteria

- [x] LICENSE files in api, dashboard, stack repos contain PolyForm NC 1.0.0 verbatim
- [x] ADDITIONAL-USES.md present in api, dashboard, stack repos with all categories from the plan
- [x] LICENSE-RATIONALE.md updated in all 3 core repos explaining the change
- [ ] Extension and truesun repos unchanged (still GPL v3)
- [ ] EULA.txt updated to version 2.0 with zero GPL v3 references
- [ ] EULA translated to 12 non-English locales with bilingual disclaimer
- [ ] Wizard step template updated with version 2.0
- [ ] Dashboard legal.json updated with PolyForm NC language (English)
- [ ] Dashboard legal.json translated to 12 non-English locales
- [ ] CLAUDE.md updated with new license description
- [ ] Grep of all 3 core repos: zero hits for "GPL", "GNU", "General Public License" outside git history
- [ ] ADR-003 marked superseded

## Implementation guidance

**Files affected per repo:**

Core repos (api, dashboard, stack):
- `LICENSE` — replace GPL v3 verbatim text with PolyForm NC 1.0.0 verbatim text
- `ADDITIONAL-USES.md` — new file (identical in all 3 repos)
- `LICENSE-RATIONALE.md` — rewrite to explain PolyForm NC choice and weewx split

Meta repo (weather-belchertown):
- `docs/decisions/ADR-081-license-change-polyform.md` — this file
- `docs/archive/decisions/ADR-003-license.md` — status → "Superseded by ADR-081"
- `docs/decisions/INDEX.md` — move ADR-003 to Superseded section, add ADR-081
- `CLAUDE.md` — update license reference

Stack repo (config UI):
- `static/EULA.txt` — update all GPL v3 references to PolyForm NC
- `static/EULA_{locale}.txt` (12 files) — translate updated EULA with bilingual disclaimer
- `templates/wizard/step_eula.html` — update version number in checkbox label
- `translations/en.json` — update any GPL v3 translation keys

Dashboard repo:
- `public/locales/en/legal.json` — update 4 GPL v3 references
- `public/locales/{locale}/legal.json` (12 files) — translate updated content
- `src/routes/legal.tsx` — rename "Open-Source Licenses" section to "License"

**Out of scope:**
- Extension and truesun repos — unchanged (GPL v3, weewx derivative works)
- pyproject.toml license fields — update when publishing to PyPI (deferred)
- package.json license field — update when publishing to npm (deferred)

## References

- Supersedes: [ADR-003](../archive/decisions/ADR-003-license.md) (License = GPL v3)
- Related: [ADR-006](../archive/decisions/ADR-006-compliance-model.md) (compliance model — unaffected)
- PolyForm Noncommercial 1.0.0: https://polyformproject.org/licenses/noncommercial/1.0.0
- Plan: [DOCS-HELP-LICENSING-PLAN.md](../planning/DOCS-HELP-LICENSING-PLAN.md), Phase 0
