---
status: Accepted
date: 2026-06-27
deciders: shane
supersedes:
superseded-by:
---

# ADR-076: GitHub organization migration

## Context

Clear Skies started as tweaks to the Belchertown weewx skin, so the project hub (`weather-belchertown`) is a fork of `poblabs/weewx-belchertown` — carrying someone else's commit history, README, and license. The 5 component repos are scattered under the personal `inguy24` GitHub account with no project identity. There is no centralized place for users to file issues or start discussions.

Three problems: (1) the project looks like a fork, not an original project; (2) repos are scattered under a personal account; (3) no single support channel.

The local directory stays at `c:\CODE\weather-belchertown\` — changing it would break Nextcloud sync, SSH config, and scripts.

## Options considered

| Option | Verdict |
|---|---|
| Stay under `inguy24/` | Reject — no project identity, fork baggage persists, no centralized support |
| Create `clearskies-wx` GitHub org, transfer repos, push project history to a new non-fork repo | **Chosen** |
| Monorepo (merge all components into one repo) | Reject — ADR-001 established the 5-component split; monorepo contradicts independent release/build per ADR-034 |

## Decision

Create a `clearskies-wx` GitHub organization. Transfer the 5 active component repos (`api`, `dashboard`, `stack`, `extension`, `truesun`) from `inguy24/` to the org. Create `weewx-clearskies-project` as a new (non-fork) repo with the full commit history from the Belchertown fork, then remove the skin files in a "divorce" commit. Centralize Issues and Discussions on the project repo only; disable Issues on component repos.

## Consequences

- GitHub creates permanent redirects from old `inguy24/weewx-clearskies-*` URLs — existing clones and bookmarks continue to work.
- The Belchertown fork (`inguy24/weewx-belchertown`) stays untouched under the personal account.
- All `inguy24` references in docs, docker-compose files, `legal.tsx`, and `setup-local.ps1` updated to `clearskies-wx`.
- Container git remotes (weewx + weather-dev) repointed to the org.
- Local directory path unchanged (`c:\CODE\weather-belchertown\`).
- The `master` branch (Belchertown-era) is pushed as `main` on the project repo.
- `weewx-clearskies-realtime` (archived) and `weewx-clearskies-design-tokens` (placeholder) stay under `inguy24/`.

## Acceptance criteria

- [x] All 5 component repos live under `clearskies-wx/`
- [x] `weewx-clearskies-project` exists with full commit history (1,800+ commits)
- [x] Belchertown skin files removed from project repo
- [x] Issues enabled only on project repo; disabled on component repos
- [x] `grep -r "inguy24"` returns zero hits for clearskies repo references across all repos
- [x] Old `inguy24/` URLs redirect correctly
- [x] Container remotes (weewx + weather-dev) point to `clearskies-wx/`
- [x] Dashboard rebuilt and deployed with updated `legal.tsx` URL
- [x] Local directory path unchanged

## Implementation guidance

Executed 2026-06-27 per `docs/planning/GITHUB-ORG-MIGRATION-PLAN.md`. Six phases: pre-flight → create project repo with history → transfer component repos → update references → repoint local + container remotes → cleanup + redeploy.

## References

- Migration plan: [GITHUB-ORG-MIGRATION-PLAN.md](../planning/GITHUB-ORG-MIGRATION-PLAN.md)
- Related: ADR-001 (component breakdown), ADR-004 (repo naming), ADR-036 (workspace layout)
- Org: https://github.com/clearskies-wx
