# Installation, Packaging & Beta Release Readiness — Execution Plan

**Status:** PLANNING  
**Created:** 2026-07-02  
**Components:** API (`weewx-clearskies-api`), Dashboard (`weewx-clearskies-dashboard`), Config UI (`weewx-clearskies-stack`), Loop Relay (`weewx-clearskies-extension`), TrueSun (`weewx-clearskies-truesun`), Meta repo (`weather-belchertown`)

---

## Context

Clear Skies has completed i18n compliance, UI components, the enrichment pipeline, conditions text engine, 35+ API endpoints, 13-locale translations, and is approaching beta readiness. The **Docs/Help/Licensing Plan** (DOCS-HELP-LICENSING-PLAN.md) identified that Docker container finalization, pip packaging, install scripts, and installation documentation are not yet sorted — items E1–E3 were explicitly deferred because "containers and compose files not finalized."

Investigation reveals the infrastructure is more complete than expected — Dockerfiles, compose files, pyproject.toml, INSTALL.md guides, systemd units, and even CI release workflows all exist. But none of it has been **published, tested as a fresh deploy, or cleaned up for release**. The gap is the last mile: getting from "works on our dev machines" to "an operator can install this."

This plan covers six deliverables: version strategy, code/Docker gap fixes, systemd/install polish, CI/CD gap filling, metadata and version bump, and end-to-end validation. It also updates the Docs/Help/Licensing Plan's deferred items (E1–E3) with specifics.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §1 IPv4/IPv6 dual-stack, §4 release verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/ARCHITECTURE.md` — container inventory, port registry, Known gaps
- `docs/manuals/OPERATIONS-MANUAL.md` — §1 Deployment, §4 Configuration, §7 Observability (CI gates)

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. GitHub: `clearskies-wx/weewx-clearskies-api`.
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind). Branch: `main`. GitHub: `clearskies-wx/weewx-clearskies-dashboard`.
- `weewx-clearskies-stack` — Config UI + Compose + Caddyfiles. Branch: `main`. GitHub: `clearskies-wx/weewx-clearskies-stack`.
- `weewx-clearskies-extension` — Loop Relay weewx extension. Branch: `master`. GitHub: `clearskies-wx/weewx-clearskies-extension`.
- `weewx-clearskies-truesun` — TrueSun weewx extension. Branch: `main`. GitHub: `clearskies-wx/weewx-clearskies-truesun`.
- `weewx-clearskies-design-tokens` — Phase 6+ placeholder. Branch: `main`. GitHub: `inguy24/weewx-clearskies-design-tokens` (not in org — tracked in gap inventory).

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- Config UI: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (~2 min warm)
- Direct SSH: `ssh -F .local/ssh/config weather-dev`, `ssh -F .local/ssh/config weewx`

**Key existing state:**
- **Dockerfiles:** Exist and are production-grade for API (40 lines, multi-stage, hardened), Dashboard (24 lines, init container pattern), Config UI (44 lines, multi-stage, two-repo build context), dev seed (21 lines).
- **Docker Compose:** Four topologies complete — `dev/`, `frontend-host/`, `single-host/`, `weewx-host/`. All have `.env.example` files.
- **pyproject.toml:** Complete for API (16 runtime deps, 2 console scripts) and Config (`weewx-clearskies-config`, 16 deps, 1 console script). Both use hatchling 1.27.0. Neither published to PyPI.
- **INSTALL.md:** Comprehensive in all repos (API: 283 lines, Dashboard: 199 lines, Stack: 370 lines).
- **Systemd units:** Three examples in `stack/examples/systemd/` — API, Realtime (stale), Config. Hardcoded `/home/ubuntu/repos/` paths.
- **CI release workflows:** Exist for API (`release.yml`: pytest → PyPI + GHCR + GH Release), Dashboard (`release.yml`: build → GHCR + GH Release), Stack (`release.yml`: GH Release only — no build/publish). Triggered on `v*.*.*` tag push.
- **Universal CI:** DCO, gitleaks, dep-audit workflows present on all org repos except extension and truesun.
- **API life-support mode:** Already implemented. When `api.conf` is absent, `load_settings()` returns `Settings(configured=False)` and the API starts with only `/setup/*` endpoints + 503 catch-all. No crash. Known gap #2 in ARCHITECTURE.md is stale.
- **Config UI in compose:** Already present in `frontend-host/` and `single-host/` compose files as the `config` service. Known gap #1 in ARCHITECTURE.md may be partially stale.
- **Packages not on PyPI.** The Config UI Dockerfile explicitly comments: "weewx-clearskies-api is not on PyPI; install from sibling repo first."
- **Cross-dependency:** `weewx-clearskies-config` declares `weewx-clearskies-api>=0.1.0` as a runtime dependency. API must publish to PyPI first.
- **Version:** All packages at `0.1.0`. Target: `1.0.0b1`.
- **License metadata:** pyproject.toml files say `GPL-3.0-or-later`. Docs plan Phase 0 changes license to PolyForm Noncommercial — metadata update depends on that.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase — no phase advances until sign-off.

---

## 1. Gap Inventory

### A. Docker & Compose Gaps

| # | Item | Current state | Target state |
|---|------|--------------|-------------|
| A1 | Unix socket mount missing | No compose file mounts `/var/run/weewx-clearskies/` for the Loop Relay socket. `DirectAdapter` reconnects with backoff but SSE never connects. | `weewx-host/` and `single-host/` compose files mount host socket directory into API container |
| A2 | Known gap #1 (Config UI not in compose) | Config service IS in `frontend-host/` and `single-host/` compose files. Caddy routes for `/wizard*`, `/admin*`, `/login*`, `/bootstrap*`, `/static/*` ARE in all Caddyfiles. | Verify end-to-end, close gap in ARCHITECTURE.md |
| A3 | Known gap #2 (API crashes without config) | Already fixed — `load_settings()` returns `Settings(configured=False)`, API starts in setup mode | Close gap in ARCHITECTURE.md |
| A4 | Known gap #3 (Dashboard unconfigured detection) | Global `ErrorBoundary` exists but no redirect to `/wizard` when API returns `configured: false` | Dashboard checks `/api/v1/status` on load; if `configured: false`, shows first-run message with wizard URL |
| A5 | Stale realtime compose references | `config/realtime.conf.example` exists (marked DEPRECATED). `examples/systemd/weewx-clearskies-realtime.service` exists. | Remove or clearly archive stale files |

### B. Pip & PyPI Gaps

| # | Item | Current state | Target state |
|---|------|--------------|-------------|
| B1 | Not published to PyPI | Neither `weewx-clearskies-api` nor `weewx-clearskies-config` on PyPI | Both published as `1.0.0b1` with `--pre` install |
| B2 | Cross-dependency | Config depends on API `>=0.1.0`. Docker build installs from sibling dir. | API publishes first. Config dependency updated to `>=1.0.0b1`. Release workflow enforces order. |
| B3 | Missing `[project.urls]` | No homepage, repository, documentation, or changelog URLs in pyproject.toml | URLs added pointing to `clearskies-wx` GitHub org repos |
| B4 | Missing classifiers | No PyPI classifiers for discoverability | Add relevant classifiers (Framework::FastAPI, Topic::Scientific/Engineering::Atmospheric Science, etc.) |
| B5 | License metadata | `license = "GPL-3.0-or-later"` | Updated after docs plan Phase 0 completes license change |
| B6 | Version at 0.1.0 | All packages and `__init__.py` files say `0.1.0` | Bumped to `1.0.0b1` (Python PEP 440) / `1.0.0-beta.1` (npm semver) |

### C. CI/CD Gaps

| # | Item | Current state | Target state |
|---|------|--------------|-------------|
| C1 | Stack release workflow minimal | Only creates GH Release — no build, no PyPI publish, no GHCR push | Add PyPI publish for `weewx-clearskies-config` + GHCR push for config container image |
| C2 | Extension repo: no CI | No `.github/` directory at all. Branch: `master` | Add gitleaks + dep-audit + DCO workflows |
| C3 | TrueSun repo: no CI | No `.github/` directory at all | Add gitleaks + dep-audit + DCO workflows |
| C4 | SECURITY.md stale links | References `github.com/inguy24/weewx-clearskies-stack` | Update to `github.com/clearskies-wx/weewx-clearskies-stack` |
| C5 | design-tokens not in org | Remote: `inguy24/weewx-clearskies-design-tokens` | Transfer to `clearskies-wx` org (or defer — placeholder repo) |
| C6 | CONTRIBUTING.md license refs | Says "GPL-3.0" | Updated after docs plan Phase 0 |
| C7 | Extension uses `master` branch | Default branch is `master` while all others use `main` | Rename to `main` for consistency |

### D. Systemd & Install Gaps

| # | Item | Current state | Target state |
|---|------|--------------|-------------|
| D1 | Systemd units hardcoded paths | `/home/ubuntu/repos/weewx-clearskies-api/.venv/bin/weewx-clearskies-api` | Parameterized with documented substitution (or use `$VIRTUAL_ENV/bin/` pattern) |
| D2 | Stale realtime systemd unit | `examples/systemd/weewx-clearskies-realtime.service` exists | Removed |
| D3 | No bare-metal install script | Bare-metal script exists in OPS-MANUAL §1 but not as a standalone file in the stack repo | Extract to `scripts/install-prerequisites.sh` in stack repo |
| D4 | Install order not documented as prerequisite chain | INSTALL.md files exist per-repo but don't emphasize cross-repo ordering | Stack INSTALL.md updated with numbered dependency chain |

### E. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred | Track where |
|---------|-------------|-------------|
| GitHub Pages marketing site | Separate project; needs design/content | CLEAR-SKIES-PLAN.md |
| Auto-update mechanism | Explicitly deferred to post-v1 per OPERATIONS-MANUAL §8 | OPERATIONS-MANUAL.md |
| Dependabot configuration | Nice-to-have; existing dep-audit workflows sufficient for beta | Post-beta |
| Issue/PR templates | Nice-to-have for community contribution; not blocking beta | Post-beta |
| Watchtower documentation | Operator's choice per OPERATIONS-MANUAL §8 | Operator Manual (docs plan) |
| design-tokens org transfer | Placeholder repo with no code; low priority | Post-beta |

---

## 2. Implementation Phases

### PHASE 0 — Version Strategy

> Decision phase — no code changes. Establishes the version numbering and publishing order that all subsequent phases follow.

**T0.1 — Document version strategy**
- Owner: Coordinator (Opus)
- File: New `docs/planning/BETA-RELEASE-PLAN.md` (this plan, committed to meta repo)
- Decisions:
  - **First public release:** `1.0.0b1` (PEP 440 beta). Signals mature codebase in final testing. Subsequent betas: `1.0.0b2`, `1.0.0b3`. Stable release: `1.0.0`.
  - **Dashboard version:** `1.0.0-beta.1` (npm semver equivalent).
  - **Docker image tags:** `1.0.0b1` (matches Python version). Also tagged `beta` (floating tag, always points to latest beta).
  - **weewx extensions:** Stay at `1.1.0` (Loop Relay) and `0.1.0` (TrueSun). Not on PyPI. Distributed as tarballs via GitHub Releases.
  - **Publishing order:** (1) API to PyPI + GHCR, (2) Config to PyPI + GHCR (depends on API), (3) Dashboard to GHCR, (4) Extensions to GH Releases, (5) Stack to GH Release (compose files + Caddyfiles).
  - **`pip install` behavior:** `pip install weewx-clearskies-api` will NOT install betas by default (PEP 440). Operators use `pip install --pre weewx-clearskies-api` or `pip install weewx-clearskies-api==1.0.0b1`. INSTALL.md documents this.
- Accept: Decisions documented and committed. All subsequent phases reference these decisions.

---

### PHASE 1 — Docker & Compose Finalization

**T1.1 — Add Unix socket volume mount to compose files**
- Owner: `clearskies-docs-author` (Sonnet) — mechanical file edits
- Files:
  - `repos/weewx-clearskies-stack/weewx-host/docker-compose.yml` — add volume to `api` service
  - `repos/weewx-clearskies-stack/single-host/docker-compose.yml` — add volume to `api` service
  - `repos/weewx-clearskies-stack/weewx-host/.env.example` — add `WEEWX_SOCKET_DIR` variable
  - `repos/weewx-clearskies-stack/single-host/.env.example` — add `WEEWX_SOCKET_DIR` variable
- Do: Add to the `api` service volumes in both compose files:
  ```yaml
  - ${WEEWX_SOCKET_DIR:-/var/run/weewx-clearskies}:/var/run/weewx-clearskies:ro
  ```
  Add to `.env.example` files:
  ```bash
  # Path to the weewx-clearskies socket directory on the host.
  # The Loop Relay extension creates loop.sock here.
  # Default: /var/run/weewx-clearskies
  # WEEWX_SOCKET_DIR=/var/run/weewx-clearskies
  ```
- Accept: Both compose files mount the socket directory. API container can read `/var/run/weewx-clearskies/loop.sock` from the host. Default path works without setting the env var. `docker compose config` validates in both directories.

**T1.2 — Clean up stale realtime artifacts**
- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - Remove: `repos/weewx-clearskies-stack/config/realtime.conf.example`
  - Remove: `repos/weewx-clearskies-stack/examples/systemd/weewx-clearskies-realtime.service`
- Do: Delete both files. They are deprecated per ADR-058 (realtime merged into API). The `realtime.conf.example` is already marked `# DEPRECATED` at the top. The systemd unit references a service that no longer exists.
- Accept: Files removed. No compose file, Caddyfile, or INSTALL.md references a `realtime` service (verify with grep).

**T1.3 — Dashboard unconfigured-state handling (Known gap #3 completion)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-dashboard/src/lib/client.ts` or equivalent API client — add `checkConfigured()` function
  - `repos/weewx-clearskies-dashboard/src/main.tsx` or app entry — call on mount
  - `repos/weewx-clearskies-dashboard/src/routes/not-configured.tsx` — new route (or inline in error boundary)
- Do: On app load, fetch `GET /api/v1/status`. If response contains `"configured": false`, render a first-run message:
  - "Clear Skies is not yet configured."
  - "Open the setup wizard at `https://<current-host>/wizard` to get started."
  - No redirect (wizard may be on a different port during first-run before Caddy is configured).
  - Style: centered card, friendly tone, matches existing error boundary pattern.
  - If `/api/v1/status` fetch fails entirely (API not running), the existing `ErrorBoundary` handles it — no change needed there.
- Accept: Fresh install with no `api.conf` → API starts in setup mode → Dashboard shows first-run message instead of error wall. `tsc --noEmit` passes. `vite build` clean.

**T1.4 — Verify Known gaps #1 and #2, update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md` (Known gaps table)
- Do:
  - **Gap #1 (Config UI not in compose):** Verify `config` service is in `frontend-host/` and `single-host/` compose files. Verify Caddy routes for `/wizard*`, `/admin*`, `/login*`, `/bootstrap*`, `/static/*`. If verified, update gap status to "Resolved" with date and evidence.
  - **Gap #2 (API crashes without config):** Verify `load_settings()` returns `Settings(configured=False)` when `api.conf` absent. Verify API starts and serves `/setup/*`. Update gap status to "Resolved" — already implemented in code; gap description was stale.
  - **Gap #3 (Dashboard unconfigured):** Update to "Resolved" after T1.3 deploys.
- Accept: Known gaps table updated. Resolved gaps moved to "Resolved gaps" section with date and resolution description.

**QC (Opus) — after Phase 1:** `docker compose config` validates in `weewx-host/` and `single-host/` with socket mount present. Grep across stack repo for "realtime" — only historical references remain (comments, DEPRECATED notes in ARCHITECTURE.md). Dashboard builds clean (`tsc --noEmit` + `vite build`). ARCHITECTURE.md Known gaps updated.

---

### PHASE 2 — Systemd & Install Tooling

**T2.1 — Parameterize systemd unit templates**
- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/examples/systemd/weewx-clearskies-api.service`
  - `repos/weewx-clearskies-stack/examples/systemd/weewx-clearskies-config.service`
- Do: Replace hardcoded `/home/ubuntu/repos/weewx-clearskies-api/.venv/bin/weewx-clearskies-api` with a documented substitution pattern. Two options (choose during implementation):
  - **Option A (simpler):** Use the pip-installed binary directly: `ExecStart=/usr/local/bin/weewx-clearskies-api` with a comment "# Adjust path if installed in a venv: /path/to/venv/bin/weewx-clearskies-api"
  - **Option B (template):** Use `%h` systemd specifier or environment variable: `Environment=VENV=/opt/clearskies` + `ExecStart=${VENV}/bin/weewx-clearskies-api`
  - Add `WorkingDirectory=` (remove dependency on CWD).
  - Ensure `User=clearskies` (not `ubuntu`) matches the bare-metal install script's service user.
  - Keep all existing hardening: `NoNewPrivileges=true`, `ProtectSystem=strict`, `PrivateTmp=true`.
  - Add `ReadWritePaths=/var/run/weewx-clearskies` to the API unit (for socket access).
- Accept: Units work with a standard pip install (no path editing needed for default `/usr/local/bin/` install). Comments document venv and custom-path scenarios. `systemd-analyze verify` passes on both units.

**T2.2 — Extract bare-metal install script to stack repo**
- Owner: `clearskies-docs-author` (Sonnet)
- File: New `repos/weewx-clearskies-stack/scripts/install-prerequisites.sh`
- Do: Extract the bare-metal install script from OPERATIONS-MANUAL.md §1 into a standalone shell script. The script creates:
  - `clearskies` system user (no login, no home, no sudo)
  - `weewx-ro` group for read-only DB access
  - Group memberships (`clearskies` → `weewx-ro`, `weewx`)
  - `/etc/weewx-clearskies/` config directory (owned by `clearskies`, mode 750)
  - `/var/run/weewx-clearskies/` runtime directory (owned by `clearskies:weewx`, mode 770)
  - `/var/www/clearskies/` web root (owned by `caddy:caddy` if Caddy installed, mode 755)
  - SQLite permission fix (`chgrp weewx-ro`, `chmod g+r`)
  - Add `#!/bin/bash`, `set -euo pipefail`, idempotency checks (don't fail if user/group/dir already exists), root check.
  - Print summary of what was created at the end.
- Accept: Script runs idempotently on Debian/Ubuntu. Creates all required filesystem state. Fails gracefully if run as non-root.

**T2.3 — Update Stack INSTALL.md with install dependency chain**
- Owner: Coordinator (Opus)
- File: `repos/weewx-clearskies-stack/INSTALL.md`
- Do: Add a "Prerequisites & Install Order" section at the top, before topology descriptions. The numbered chain:
  1. **weewx** — must be running (operator's existing install)
  2. **ClearSkiesLoopRelay extension** — `weectl extension install` into weewx. Creates the Unix socket. Restart weewx.
  3. **(Optional) ClearSkiesTruesun extension** — `weectl extension install` + pvlib/cdsapi deps. Restart weewx.
  4. **Run `install-prerequisites.sh`** — creates users, groups, directories (native path only).
  5. **API** — `pip install --pre weewx-clearskies-api` (native) or `docker compose up` (Docker). Starts in setup mode if no config.
  6. **Config UI** — `pip install --pre weewx-clearskies-config` (native) or included in compose. Run wizard to generate `api.conf`.
  7. **Dashboard** — `npm run build` + rsync (native) or init container in compose.
  8. **Caddy** — reverse proxy. Configure with provided Caddyfile example.
  9. **Verify** — `curl https://your-site/api/v1/status` returns `{"configured": true}`.
- Accept: Dependency chain is clear. A new operator reading top-to-bottom knows what to install in what order and why.

**QC (Opus) — after Phase 2:** Review systemd units — verify no hardcoded paths, `User=clearskies`, hardening directives present. Run `bash -n scripts/install-prerequisites.sh` (syntax check). Review INSTALL.md dependency chain for accuracy against ARCHITECTURE.md.

---

### PHASE 3 — CI/CD Gap Filling

**T3.1 — Add CI workflows to extension repo**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: New `.github/workflows/` directory in `repos/weewx-clearskies-extension/` with:
  - `dco.yml` — copied from API repo, trigger on PR to `main` (after branch rename in T3.4)
  - `gitleaks.yml` — copied from API repo
  - `release.yml` — trigger on `v*.*.*` tag push: create GitHub Release with the tarball (weewx extensions are distributed as tarballs, not PyPI packages). Attach `weewx-clearskies-extension-<version>.tar.gz` as release asset.
- Accept: PRs to `main` run DCO + gitleaks. Tag push creates a GH Release with tarball attachment.

**T3.2 — Add CI workflows to truesun repo**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: New `.github/workflows/` directory in `repos/weewx-clearskies-truesun/` with:
  - `dco.yml`, `gitleaks.yml` — same pattern as T3.1
  - `dep-audit.yml` — pip-audit for pvlib/cdsapi/h5netcdf dependencies
  - `release.yml` — same pattern as T3.1 (tarball as GH Release asset)
- Accept: PRs to `main` run DCO + gitleaks + dep-audit. Tag push creates GH Release with tarball.

**T3.3 — Enhance stack release workflow**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `repos/weewx-clearskies-stack/.github/workflows/release.yml`
- Do: Add two jobs to the existing workflow:
  - **`pypi` job:** Build `weewx-clearskies-config` wheel → publish to PyPI via `pypa/gh-action-pypi-publish`. Needs `PYPI_API_TOKEN` secret (or Trusted Publisher).
  - **`docker` job:** Build config UI container image → push to `ghcr.io/clearskies-wx/weewx-clearskies-config:<version>` and `:beta`. Build context is the repos parent directory (same as Dockerfile requires).
  - **Dependency:** `pypi` job must run AFTER API's `pypi` job completes (cross-repo dependency — see T3.5).
- Accept: Tag push triggers PyPI publish + GHCR push + GH Release. Manual test: `pip install --pre weewx-clearskies-config==1.0.0b1` installs successfully from PyPI (after first publish).

**T3.4 — Rename extension default branch to `main`**
- Owner: Coordinator (Opus)
- Do: On GitHub, rename `master` → `main` for `clearskies-wx/weewx-clearskies-extension`. Update any branch references in CI workflows, INSTALL.md, and ARCHITECTURE.md (`Repo layout` table currently says `master`).
- Accept: Default branch is `main`. All references updated. `git clone` + `git checkout main` works.

**T3.5 — Document cross-repo publishing order**
- Owner: Coordinator (Opus)
- File: New `repos/weewx-clearskies-stack/docs/RELEASE-PROCEDURE.md`
- Do: Document the exact release procedure:
  1. **Pre-release checks:** All repos clean, CI green, CHANGELOG.md updated per repo.
  2. **Tag API:** `git tag v1.0.0b1 && git push origin v1.0.0b1` → triggers API release workflow (pytest → PyPI + GHCR + GH Release).
  3. **Wait for API PyPI publish** — verify `pip install --pre weewx-clearskies-api==1.0.0b1` works.
  4. **Tag Stack:** `git tag v1.0.0b1 && git push origin v1.0.0b1` → triggers Stack release workflow (PyPI + GHCR + GH Release). Config package resolves API dependency from PyPI.
  5. **Tag Dashboard:** `git tag v1.0.0b1 && git push origin v1.0.0b1` → triggers Dashboard release workflow (GHCR + GH Release).
  6. **Tag Extensions:** `git tag v1.1.0 && git push origin v1.1.0` (Loop Relay), `git tag v0.1.0 && git push origin v0.1.0` (TrueSun) → triggers tarball releases.
  7. **Verify:** `docker compose pull` in `single-host/` succeeds. `pip install --pre weewx-clearskies-api weewx-clearskies-config` succeeds.
- Accept: Procedure is clear, step-by-step, with verification after each step.

**T3.6 — Fix SECURITY.md stale links**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: `SECURITY.md` in all 5 org repos (api, dashboard, stack, extension, truesun)
- Do: Replace `github.com/inguy24/weewx-clearskies-*` URLs with `github.com/clearskies-wx/weewx-clearskies-*`. Update any GPL v3 references to note the license change is pending (or coordinate with docs plan Phase 0).
- Accept: All SECURITY.md files reference the correct org. No stale `inguy24` links.

**QC (Opus) — after Phase 3:** Verify workflow YAML syntax (`yamllint` or manual review). Verify extension and truesun repos have `.github/workflows/` with correct trigger branches. Verify stack release workflow includes pypi + docker jobs. Verify RELEASE-PROCEDURE.md is accurate against actual workflow triggers. Grep SECURITY.md files for `inguy24` — zero hits.

---

### PHASE 4 — Metadata & Version Bump

> **Dependency:** This phase runs AFTER the Docs/Help/Licensing Plan Phase 0 (license change from GPL v3 to PolyForm Noncommercial). The license metadata, CONTRIBUTING.md updates, and SECURITY.md license references all depend on the license change being committed.

**T4.1 — Update pyproject.toml metadata (API)**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `repos/weewx-clearskies-api/pyproject.toml`
- Do:
  - `version = "1.0.0b1"` (was `0.1.0`)
  - `license = "PolyForm-Noncommercial-1.0.0"` (was `GPL-3.0-or-later`)
  - Add `[project.urls]`:
    ```
    Homepage = "https://github.com/clearskies-wx"
    Repository = "https://github.com/clearskies-wx/weewx-clearskies-api"
    Documentation = "https://github.com/clearskies-wx/weewx-clearskies-stack/blob/main/docs/OPERATOR-MANUAL.md"
    Changelog = "https://github.com/clearskies-wx/weewx-clearskies-api/blob/main/CHANGELOG.md"
    ```
  - Add classifiers:
    ```
    "Development Status :: 4 - Beta",
    "Framework :: FastAPI",
    "Topic :: Scientific/Engineering :: Atmospheric Science",
    "Intended Audience :: End Users/Desktop",
    "Programming Language :: Python :: 3.12",
    ```
  - Update `weewx_clearskies_api/__init__.py`: `__version__ = "1.0.0b1"`
- Accept: `pip install .` succeeds. `python -c "import weewx_clearskies_api; print(weewx_clearskies_api.__version__)"` prints `1.0.0b1`.

**T4.2 — Update pyproject.toml metadata (Config / Stack)**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `repos/weewx-clearskies-stack/pyproject.toml`
- Do:
  - `version = "1.0.0b1"`
  - `license = "PolyForm-Noncommercial-1.0.0"`
  - Update dependency: `weewx-clearskies-api>=1.0.0b1` (was `>=0.1.0`)
  - Add `[project.urls]` (same pattern as T4.1, pointing to stack repo)
  - Add classifiers (same as T4.1)
  - Update `weewx_clearskies_config/__init__.py`: `__version__ = "1.0.0b1"`
- Accept: `pip install .` succeeds (requires API installed first). Version prints correctly.

**T4.3 — Update package.json version (Dashboard)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/package.json`
- Do: `"version": "1.0.0-beta.1"` (was `"0.1.0"`). npm semver equivalent of PEP 440 `1.0.0b1`.
- Accept: `npm run build` succeeds. Version in package.json matches beta scheme.

**T4.4 — Update CONTRIBUTING.md (5 repos)**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: `CONTRIBUTING.md` in api, dashboard, stack, extension, truesun repos
- Do: Update license references from "GPL-3.0" to "PolyForm Noncommercial 1.0.0" for the 4 core repos. Extension stays "GPL-3.0" (weewx derivative). Add DCO sign-off instructions if not already present.
- Accept: License reference matches the actual LICENSE file in each repo.

**T4.5 — Update Docker image references in compose files**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: All `docker-compose.yml` files in stack repo that reference GHCR images
- Do: Update image tags from `latest` or unversioned to `${CLEARSKIES_VERSION:-1.0.0b1}`. The `.env.example` files already have a `CLEARSKIES_VERSION` variable — verify it defaults to `1.0.0b1`.
- Accept: `docker compose config` shows correct image tags. `.env.example` documents the version variable.

**QC (Opus) — after Phase 4:** Verify version strings are consistent: `1.0.0b1` in all pyproject.toml, `__init__.py`, package.json, `.env.example` defaults, compose image tags. Grep for `0.1.0` — should only appear in extension (`1.1.0`) and truesun (`0.1.0`) version fields and historical docs. License metadata matches docs plan Phase 0 output.

---

### PHASE 5 — End-to-End Validation

> This phase validates the entire install experience from scratch. Both Docker and native paths are tested. **All testing uses the existing `weewx` and `weather-dev` LXD containers.** Backup and restore procedures protect existing state.

**T5.0 — Backup existing state before any testing**
- Owner: Coordinator (Opus)
- Do: Before ANY test task in this phase, create backups of both hosts:

  **weewx host (critical — production weather data):**
  ```bash
  ssh -F .local/ssh/config weewx "sudo systemctl stop weewx-clearskies-api"
  ssh -F .local/ssh/config weewx "sudo systemctl stop weewx"

  # Back up weewx config and database
  ssh -F .local/ssh/config weewx "sudo cp /etc/weewx/weewx.conf /etc/weewx/weewx.conf.pre-beta-test"
  ssh -F .local/ssh/config weewx "sudo cp /var/lib/weewx/weewx.sdb /var/lib/weewx/weewx.sdb.pre-beta-test"

  # Back up Clear Skies config directory
  ssh -F .local/ssh/config weewx "sudo tar czf /home/ubuntu/clearskies-config-backup.tar.gz /etc/weewx-clearskies/"

  # Back up API venv + repo state
  ssh -F .local/ssh/config weewx "tar czf /home/ubuntu/clearskies-api-repo-backup.tar.gz -C /home/ubuntu/repos weewx-clearskies-api/"

  # Restart services
  ssh -F .local/ssh/config weewx "sudo systemctl start weewx"
  ssh -F .local/ssh/config weewx "sudo systemctl start weewx-clearskies-api"
  ```

  **weather-dev host (dashboard, config UI, Caddy):**
  ```bash
  ssh -F .local/ssh/config weather-dev "sudo systemctl stop weewx-clearskies-config"

  # Back up Clear Skies config directory
  ssh -F .local/ssh/config weather-dev "sudo tar czf /home/ubuntu/clearskies-config-backup.tar.gz /etc/weewx-clearskies/"

  # Back up dashboard web root
  ssh -F .local/ssh/config weather-dev "sudo tar czf /home/ubuntu/clearskies-webroot-backup.tar.gz /var/www/clearskies/"

  # Back up Caddy config
  ssh -F .local/ssh/config weather-dev "sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.pre-beta-test"

  # Back up repo state (dashboard, stack, config UI venv)
  ssh -F .local/ssh/config weather-dev "tar czf /home/ubuntu/clearskies-repos-backup.tar.gz -C /home/ubuntu/repos weewx-clearskies-dashboard/ weewx-clearskies-stack/"

  ssh -F .local/ssh/config weather-dev "sudo systemctl start weewx-clearskies-config"
  ```

  **Verify backups exist:**
  ```bash
  ssh -F .local/ssh/config weewx "ls -lh /home/ubuntu/clearskies-*.tar.gz /etc/weewx/weewx.conf.pre-beta-test /var/lib/weewx/weewx.sdb.pre-beta-test"
  ssh -F .local/ssh/config weather-dev "ls -lh /home/ubuntu/clearskies-*.tar.gz /etc/caddy/Caddyfile.pre-beta-test"
  ```

- Accept: All backup files exist with non-zero size. weewx and API services restarted and healthy after backup.

**T5.0-RESTORE — Restore procedure (use only if testing breaks something)**
- Do: If any test leaves the hosts in a broken state, restore from backups:

  **weewx host:**
  ```bash
  ssh -F .local/ssh/config weewx "sudo systemctl stop weewx-clearskies-api && sudo systemctl stop weewx"
  ssh -F .local/ssh/config weewx "sudo cp /etc/weewx/weewx.conf.pre-beta-test /etc/weewx/weewx.conf"
  ssh -F .local/ssh/config weewx "sudo cp /var/lib/weewx/weewx.sdb.pre-beta-test /var/lib/weewx/weewx.sdb"
  ssh -F .local/ssh/config weewx "sudo tar xzf /home/ubuntu/clearskies-config-backup.tar.gz -C /"
  ssh -F .local/ssh/config weewx "sudo systemctl start weewx && sudo systemctl start weewx-clearskies-api"
  ```

  **weather-dev host:**
  ```bash
  ssh -F .local/ssh/config weather-dev "sudo systemctl stop weewx-clearskies-config && sudo systemctl stop caddy"
  ssh -F .local/ssh/config weather-dev "sudo tar xzf /home/ubuntu/clearskies-config-backup.tar.gz -C /"
  ssh -F .local/ssh/config weather-dev "sudo tar xzf /home/ubuntu/clearskies-webroot-backup.tar.gz -C /"
  ssh -F .local/ssh/config weather-dev "sudo cp /etc/caddy/Caddyfile.pre-beta-test /etc/caddy/Caddyfile"
  ssh -F .local/ssh/config weather-dev "sudo systemctl start caddy && sudo systemctl start weewx-clearskies-config"
  ```

- Accept: Services restored to pre-test state. Dashboard renders. API serves data.

**T5.1 — Docker fresh deploy test (single-host topology)**
- Owner: Coordinator (Opus)
- **Prerequisite:** T5.0 backups complete.
- Do: On `weather-dev` (use a separate directory, not the existing repos — do NOT disturb the running native install):
  1. `mkdir /home/ubuntu/beta-docker-test && cd /home/ubuntu/beta-docker-test`
  2. Clone `weewx-clearskies-stack` repo into the test directory.
  3. Copy `.env.example` to `.env` in `single-host/`, fill in required values. Use a **different port** (e.g., `8080:80`, `8443:443`) so the test doesn't conflict with the running Caddy on ports 80/443.
  4. `docker compose up -d` in `single-host/`.
  5. Verify: all containers start, health checks pass, dashboard loads on test port, API returns `configured: false` (no wizard run yet).
  6. Access `/wizard` via test port → complete wizard flow → API restarts → dashboard shows weather data.
  7. Verify SSE stream connects (socket mount works).
  8. Verify `/branding.json`, `/pages.json`, `/webcam.json` served by Caddy.
  9. Verify admin UI accessible at `/admin`.
  10. **Tear down:** `docker compose down -v` + `rm -rf /home/ubuntu/beta-docker-test`. Existing native install untouched.
- Accept: Full fresh deploy succeeds without manual intervention beyond `.env` configuration. All services healthy. Dashboard renders weather data. Test directory cleaned up. Existing native install confirmed unaffected.
- **Record:** Container resource usage (RSS, disk) for the Operator Manual system requirements section (docs plan T3.2).

**T5.2 — Native pip fresh deploy test**
- Owner: Coordinator (Opus)
- **Prerequisite:** T5.0 backups complete.
- Do: On `weather-dev`, test pip install into a **separate venv** (do NOT modify the existing venvs):
  1. `python3.12 -m venv /home/ubuntu/beta-pip-test-venv`
  2. Verify `pip install --pre weewx-clearskies-api==1.0.0b1` installs cleanly into the test venv.
  3. Verify `pip install --pre weewx-clearskies-config==1.0.0b1` installs cleanly (resolves API dependency from PyPI).
  4. Start API from the test venv on a **non-conflicting port** (e.g., `--bind localhost --port 18765`) — verify it enters setup mode.
  5. Start Config UI from the test venv on a **non-conflicting port** (e.g., `--port 19876`) — verify it shows bootstrap URL.
  6. **Do NOT run the wizard** (would write to `/etc/weewx-clearskies/` and overwrite existing config). Instead verify the setup handshake works and the wizard renders.
  7. **Tear down:** Stop test processes. `rm -rf /home/ubuntu/beta-pip-test-venv`. Existing venvs and config untouched.
- Accept: Both packages install from PyPI without errors. CLI entry points work. Setup mode verified. Test venv cleaned up. Existing install confirmed unaffected.
- **Note:** This test can only run after Phase 4 (version bump) and the first actual PyPI publish. If PyPI publish hasn't happened yet, test from local wheel builds instead.

**T5.3 — Smoke test checklist**
- Owner: Coordinator (Opus)
- Do: After either deploy path, verify:
  | Check | Method | Expected |
  |-------|--------|----------|
  | API health | `curl https://site/api/v1/status` | `{"configured": true}` |
  | Current obs | `curl https://site/api/v1/current` | JSON with `data`, `units`, `stationClock`, `freshness` |
  | SSE stream | `curl -N https://site/sse` | `event: loop` events every ~2.5s |
  | Dashboard loads | Browser → `https://site/` | Now page renders with weather data |
  | Forecast page | Browser → `https://site/forecast` | Forecast cards render |
  | Charts page | Browser → `https://site/charts` | Charts render with data |
  | Admin access | Browser → `https://site/admin` | Admin landing page |
  | Wizard re-run | Browser → `https://site/wizard` | Fields pre-populated |
  | Locale switch | Change browser language | UI switches to that locale |
  | Mobile layout | Resize to 375px width | Responsive layout, no horizontal scroll |
- Accept: All checks pass. Evidence recorded (screenshots or curl output).

**QC (Opus) — after Phase 5:** Review all test evidence. Verify resource measurements are captured for docs plan. Any failures → triage as blocking vs. known limitation for beta release notes.

---

### PHASE 6 — Documentation Sync

**T6.1 — Update Docs/Help/Licensing Plan deferred items**
- Owner: Coordinator (Opus)
- File: `docs/planning/DOCS-HELP-LICENSING-PLAN.md`
- Do: Update deferred items E1–E3 with specifics from this plan's execution:
  - **E1 (Docker container finalization):** "Resolved by BETA-RELEASE-PLAN Phase 1. Socket mount added, stale realtime cleaned up, compose files verified end-to-end."
  - **E2 (Install scripts):** "Resolved by BETA-RELEASE-PLAN Phase 2. `scripts/install-prerequisites.sh` created, systemd units parameterized."
  - **E3 (Docker compose installation docs):** "Resolved by BETA-RELEASE-PLAN Phase 2 T2.3. Stack INSTALL.md updated with dependency chain and Docker compose instructions verified against end-to-end test."
  - **C4 (Installation — Docker compose):** Remove DEFERRED flag, mark as covered by this plan's output.
- Accept: All deferred items updated with resolution status and cross-references.

**T6.2 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Do:
  - Close Known gaps #1, #2, #3 (move to Resolved section with dates).
  - Update "Container inventory" note about Config UI: remove "NOT containerized" note — it now has a Dockerfile and is in the compose files.
  - Update version references if any (currently says `v0.1`).
  - Update "Repo layout" table: extension branch `master` → `main`, add version column.
- Accept: Known gaps table accurate. Container inventory matches reality.

**T6.3 — Update OPERATIONS-MANUAL.md**
- Owner: Coordinator (Opus)
- File: `docs/manuals/OPERATIONS-MANUAL.md`
- Do:
  - §1 Deployment: Update distribution channels table with actual PyPI package names and GHCR image paths (`ghcr.io/clearskies-wx/weewx-clearskies-api:1.0.0b1`).
  - §1 Deployment: Update install commands to use `pip install --pre` for beta.
  - §8 Updates: Add beta-to-stable upgrade notes.
  - §7 CI gates: Verify CI gate table matches actual workflow files after Phase 3 changes.
- Accept: Manual matches the actual published state. Install commands work.

**QC (Opus) — after Phase 6:** Read ARCHITECTURE.md Known gaps — all resolved gaps moved to resolved section. Grep OPERATIONS-MANUAL.md for `0.1.0` — only historical references remain. Docs plan deferred items updated.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1 Version strategy | Coordinator | Opus | Immediately — decision gate |
| 1 | T1.1 Socket mount | `clearskies-docs-author` | Sonnet | After Phase 1 |
| 1 | T1.2 Realtime cleanup | `clearskies-docs-author` | Sonnet | After Phase 1 |
| 1 | T1.3 Dashboard unconfigured | `clearskies-dashboard-dev` | Sonnet | After Phase 1 |
| 1 | T1.4 Known gaps update | Coordinator | Opus | After Phase 1 |
| 2 | T2.1 Systemd units | `clearskies-docs-author` | Sonnet | After Phase 2 |
| 2 | T2.2 Install script | `clearskies-docs-author` | Sonnet | After Phase 2 |
| 2 | T2.3 INSTALL.md chain | Coordinator | Opus | After Phase 2 |
| 3 | T3.1 Extension CI | `clearskies-docs-author` | Sonnet | After Phase 3 |
| 3 | T3.2 TrueSun CI | `clearskies-docs-author` | Sonnet | After Phase 3 |
| 3 | T3.3 Stack release workflow | `clearskies-docs-author` | Sonnet | After Phase 3 |
| 3 | T3.4 Extension branch rename | Coordinator | Opus | After Phase 3 |
| 3 | T3.5 Release procedure doc | Coordinator | Opus | After Phase 3 |
| 3 | T3.6 SECURITY.md links | `clearskies-docs-author` | Sonnet | After Phase 3 |
| 4 | T4.1 API metadata + version | `clearskies-docs-author` | Sonnet | After Phase 4 |
| 4 | T4.2 Config metadata + version | `clearskies-docs-author` | Sonnet | After Phase 4 |
| 4 | T4.3 Dashboard version | `clearskies-dashboard-dev` | Sonnet | After Phase 4 |
| 4 | T4.4 CONTRIBUTING.md | `clearskies-docs-author` | Sonnet | After Phase 4 |
| 4 | T4.5 Compose image tags | `clearskies-docs-author` | Sonnet | After Phase 4 |
| 5 | T5.1 Docker test | Coordinator | Opus | After Phase 5 |
| 5 | T5.2 Native pip test | Coordinator | Opus | After Phase 5 |
| 5 | T5.3 Smoke test | Coordinator | Opus | After Phase 5 |
| 6 | T6.1 Docs plan update | Coordinator | Opus | After Phase 6 |
| 6 | T6.2 ARCHITECTURE.md | Coordinator | Opus | After Phase 6 |
| 6 | T6.3 OPERATIONS-MANUAL.md | Coordinator | Opus | After Phase 6 |

**Sequencing:**
- Phase 0 (version strategy) → all other phases (everything references the version)
- Phase 1 (Docker/compose fixes) and Phase 2 (systemd/install) can run in parallel
- Phase 3 (CI/CD) can run in parallel with Phases 1–2
- Phase 4 (metadata/version bump) depends on Docs Plan Phase 0 (license change) AND Phases 1–3
- Phase 5 (end-to-end validation) depends on Phase 4
- Phase 6 (documentation sync) depends on Phase 5

**Cross-plan dependency:** Phase 4 of this plan CANNOT run until the Docs/Help/Licensing Plan Phase 0 (license change) is complete. Phases 0–3 of this plan have no such dependency and can run in parallel with the docs plan.

---

## 4. QC Gates

### Gate 1 — Docker Readiness (after Phase 1)
- `docker compose config` validates in `weewx-host/` and `single-host/` directories
- Socket mount volume present in both compose files
- Grep for `realtime` across stack repo — only archived/historical references
- Dashboard: `tsc --noEmit` + `vite build` clean
- ARCHITECTURE.md Known gaps #1, #2, #3 updated

### Gate 2 — Install Tooling (after Phase 2)
- Systemd units: no hardcoded paths, `User=clearskies`, hardening present
- `bash -n scripts/install-prerequisites.sh` passes (syntax check)
- Stack INSTALL.md has numbered dependency chain
- Dependency chain matches ARCHITECTURE.md topology

### Gate 3 — CI/CD (after Phase 3)
- Extension + truesun repos have `.github/workflows/` with DCO + gitleaks
- Stack release workflow includes pypi + docker jobs
- RELEASE-PROCEDURE.md exists with step-by-step publishing order
- All SECURITY.md files reference `clearskies-wx` org (not `inguy24`)
- Extension default branch is `main`

### Gate 4 — Version Consistency (after Phase 4)
- `1.0.0b1` in: API pyproject.toml, API `__init__.py`, Config pyproject.toml, Config `__init__.py`
- `1.0.0-beta.1` in: Dashboard package.json
- License metadata: `PolyForm-Noncommercial-1.0.0` in core repos, `GPL-3.0-only` in extension/truesun
- CONTRIBUTING.md license refs match LICENSE files
- Compose `.env.example` defaults reference `1.0.0b1`
- Grep for `0.1.0` — only in extension version, truesun version, and historical docs

### Gate 5 — End-to-End (after Phase 5)
- Docker fresh deploy: all containers start, wizard completes, dashboard renders data
- Native pip install: packages install from PyPI (or local wheels), CLI entry points work
- Smoke test checklist: all 10 checks pass
- Resource measurements recorded (for docs plan Operator Manual)

### Gate 6 — Documentation (after Phase 6)
- Docs plan deferred items E1–E3 updated with resolution status
- ARCHITECTURE.md Known gaps current (resolved gaps in resolved section)
- OPERATIONS-MANUAL.md distribution channels and install commands match published state

---

## 5. Self-Audit

**Risk: Cross-repo publishing order.** The Config package depends on the API package on PyPI. If the API publish fails or is delayed, the Config publish will fail. Mitigation: RELEASE-PROCEDURE.md documents the order with explicit "wait and verify" steps between tags. The release workflow does not auto-chain — each repo is tagged independently.

**Risk: Beta pip install discoverability.** `pip install weewx-clearskies-api` will NOT install a beta by default (PEP 440 excludes pre-releases from unqualified installs). Operators must use `--pre` or pin the exact version. Mitigation: All INSTALL.md files and the Operator Manual document the `--pre` flag. This is actually a safety feature — operators don't accidentally install a beta when they want stable.

**Risk: Docker socket mount permissions.** The socket at `/var/run/weewx-clearskies/loop.sock` is created by the Loop Relay (running as the weewx user inside the weewx process). The API container runs as `clearskies` (UID 1000). For the container to read the socket, the weewx host must have the `clearskies` user in the `weewx` group (handled by `install-prerequisites.sh`), OR the socket directory must have group-write permissions with both users in the same group. The `:ro` mount flag in the compose file is sufficient for reading the socket. Verify during T5.1.

**Risk: Config UI Docker build context.** The Config UI Dockerfile requires the repos parent directory as build context (to access `weewx-clearskies-api/` as a sibling). The GHCR workflow must replicate this by checking out both repos. The existing Dockerfile documents this: "weewx-clearskies-api is not on PyPI; install from sibling repo first." After PyPI publish, the Dockerfile can be simplified to `pip install weewx-clearskies-api` from PyPI instead of the sibling copy. Consider this simplification as a post-beta cleanup.

**Risk: Phase 4 blocked on docs plan.** Phase 4 (metadata/version bump) cannot run until the docs plan Phase 0 changes the license. If the docs plan is delayed, Phases 0–3 of this plan can still proceed — they are independent. The version bump and publishing are the only gated items.

**Risk: Extension branch rename.** Renaming `master` → `main` on a repo with no CI won't break any workflows. But any documentation or scripts referencing `master` must be updated. Grep and fix in the same commit.

**Risk: design-tokens repo not in org.** This is a placeholder repo with no code. Transferring it to the org is low-priority. Deferred to post-beta to avoid scope creep.

**Risk: Stale SECURITY.md content.** Beyond the link fixes (T3.6), the SECURITY.md files reference GPL v3 warranty disclaimers. These will need updating after the license change. Coordinate with docs plan — the SECURITY.md GPL v3 references are part of the same license-change sweep.
