# Round brief — Marine Service Separation Plan, Phase 4 (Marine Service Repo + Scaffold)

**Round:** MARINE-SEP-P4
**Date:** 2026-07-24
**Lead (coordinator):** Opus
**Implementation agent:** `clearskies-api-dev` (Sonnet)
**Test agent:** `clearskies-test-author` (Sonnet) — T4.6, dispatched after implementation lands
**Auditor:** `clearskies-auditor` (Sonnet) — adversarial audit, mandatory, no deferral

---

## 1. Round identity and mandate

You are implementing **Phase 4, tasks T4.1 through T4.5** of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`.

**NO DEFERRAL RULE applies.** Read §"NO DEFERRAL RULE" at the top of the plan.
Every task must be completed. "Deferred", "stubbed for later", "blocked on X" are
not acceptable outcomes. If you genuinely cannot complete a task, STOP and report
via SendMessage — do not silently narrow scope.

---

## 2. Reading list — read these BEFORE writing any code

Read the original text. Do not work from this brief's summary of them; this brief
deliberately does not restate their content.

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` —
   - §0.1 Execution context
   - §0.3 Agent assignments (git restrictions block)
   - §0.4 Scratch file discipline
   - §0.6 Code inventory (tells you what will land in this scaffold in Phase 5 —
     the directory layout must accommodate all of it)
   - **§"PART B — Marine Service Separation" → "Target architecture"** diagram
   - **§"Phase 4 — Marine Service Repo + Scaffold", tasks T4.1–T4.5 in full**,
     including every "Do" step and every "Accept" bullet. These are your
     specification. T4.3 contains the literal manifest JSON your `/manifest`
     endpoint must produce.
   - §"Adversarial Audit — Phase 4" and §"QC Gate 4" — these are what your work
     will be checked against.
2. `docs/ARCHITECTURE.md` — the **Services** table row for "Marine service",
   the **Authoritative port registry** row for port 8780, and the three
   `(target — pending ADR-099 acceptance)` marine callout blocks (marine
   companion service, manifest registration pattern, configuration, runtime
   failure handling, alerts stay in the API, API footprint).
3. `docs/decisions/ADR-099-marine-service-separation.md` — the full ADR.
4. `docs/manuals/PROVIDER-MANUAL.md` — §15 (marine service provider
   architecture) and the sections defining the provider module pattern
   (CAPABILITY declaration, `fetch()` interface, canonical field mapping,
   cache TTL management, error handling). T4.2 requires you to reproduce this
   pattern.
5. `docs/manuals/OPERATIONS-MANUAL.md` — the marine service deployment section
   (deployment model, `marine_service_url`, `MARINE_SERVICE_SECRET`, config push,
   health check) and §11 filesystem permissions model. Also read §12 (TLS) —
   your TLS implementation must match the API's existing pattern.
6. `rules/coding.md` — §1 in full (security: secrets, input validation, IP-version
   agnosticism, dependency pinning, Clear Skies API security constraints),
   §2, §3, §4.
7. **Reference implementation — read these API repo files and mirror their
   patterns.** You are building a sibling service; a developer who knows the API
   repo must be able to navigate the marine repo without learning a new layout:
   - `repos/weewx-clearskies-api/pyproject.toml` — packaging, extras, entry points
   - `repos/weewx-clearskies-api/weewx_clearskies_api/__main__.py` — CLI entry point
   - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/__init__.py` and
     `providers/_common/` — the provider base pattern, registry, and dispatch you
     must reproduce
   - `repos/weewx-clearskies-swan-swelltrack/weewx_clearskies_swan/service.py`
     and `__main__.py` — a working example of a standalone Clear Skies companion
     service with TLS, bearer auth, CLI args and systemd. Read both files in
     full; several T4.3/T4.4 requirements have a working precedent here.
   - `repos/weewx-clearskies-stack/examples/systemd/weewx-clearskies-api.service`
     — the API's systemd unit template. T4.4's unit must match its conventions
     (User, EnvironmentFile, ExecStart form, Restart policy, hardening
     directives). Also read
     `repos/weewx-clearskies-trushore/systemd/weewx-clearskies-trushore.service`
     as a second example of unit placement inside a component repo — your unit
     lands in the marine repo at `packaging/`, not in the stack repo.
   - `repos/weewx-clearskies-api/weewx_clearskies_api/tls.py` — the API's TLS
     self-signed cert generation. T4.4 requires the same pattern (see lead call
     #4 about not importing it).
   - `repos/weewx-clearskies-api/weewx_clearskies_api/app.py` — FastAPI app
     construction, startup, middleware wiring, health endpoints.

---

## 3. Pre-round verification (performed by the lead, 2026-07-24)

- API repo HEAD `0d87b28`, equal to `origin/main`. Clean except two pre-existing,
  unrelated deltas carried since Phase 1: a one-line comment change in
  `providers/alerts/nws.py` and an untracked
  `services/surfbeat_strip_benchmark.py`. **Do not touch either.**
- `repos/weewx-clearskies-marine` does not exist. GitHub
  `clearskies-wx/weewx-clearskies-marine` does not exist. You are creating the
  local repo from scratch.
- Phase 1 (governing docs) closed with QC Gate 1 PASSED. ARCHITECTURE.md,
  ADR-099, API-MANUAL, OPERATIONS-MANUAL and PROVIDER-MANUAL already describe the
  target marine service. They are your authority — they are not stale.
- `weewx-clearskies-swan-swelltrack` is a 322-line thin wrapper over the API's
  modules. It is *not* the marine service and is not to be modified.

---

## 4. Scope

### 4.1 Files to create (exhaustive)

All under `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine\`:

```
pyproject.toml
LICENSE
.gitignore
README.md
weewx_clearskies_marine/__init__.py
weewx_clearskies_marine/__main__.py
weewx_clearskies_marine/service.py
weewx_clearskies_marine/config.py
weewx_clearskies_marine/providers/__init__.py
weewx_clearskies_marine/providers/_common/__init__.py
weewx_clearskies_marine/providers/_common/<base pattern modules as needed>
weewx_clearskies_marine/providers/buoy/__init__.py
weewx_clearskies_marine/providers/tides/__init__.py
weewx_clearskies_marine/providers/marine/__init__.py
weewx_clearskies_marine/providers/wind/__init__.py
weewx_clearskies_marine/providers/ocean/__init__.py
weewx_clearskies_marine/providers/nearshore/__init__.py
weewx_clearskies_marine/services/__init__.py
weewx_clearskies_marine/enrichment/__init__.py
weewx_clearskies_marine/endpoints/__init__.py
weewx_clearskies_marine/endpoints/<health/manifest/config handler modules>
weewx_clearskies_marine/data/.gitkeep
tests/__init__.py
tests/conftest.py
packaging/weewx-clearskies-marine.service      (systemd unit template)
```

The exact module decomposition inside `providers/_common/`, `endpoints/`, and
`services/` is yours to choose — but it must mirror the API repo's decomposition,
and the top-level tree must match T4.1's specified structure exactly.

The **stub provider** required by T4.2's Accept criteria goes in
`providers/_common/` or a clearly-named `providers/_stub.py` — your call, but it
must be obviously a scaffold artifact and must be referenced in the README as
such (it is deleted in Phase 5 when real providers land).

### 4.2 Files NOT to touch

- Anything in `repos/weewx-clearskies-api/` — **read-only reference only.**
- Anything in `repos/weewx-clearskies-dashboard/`.
- Anything in `repos/weewx-clearskies-swan-swelltrack/`.
- Anything in `repos/weewx-clearskies-stack/`.
- Any file in the meta repo (`c:\CODE\weather-belchertown\docs\`, `rules\`,
  `reference\`) — the coordinator owns governing-doc updates this round.
- `tests/` beyond `__init__.py` and `conftest.py` — **`clearskies-test-author`
  owns T4.6 scaffold tests.** Do not write the endpoint/auth/TLS tests yourself.
  You may write `conftest.py` fixtures that test-author will build on.
- Any file on any container. **You are forbidden from editing files on weewx,
  weather-dev, or librewxr by any mechanism.**

### 4.3 Verification command

Run on **weather-dev** (read-only remote execution is permitted; editing there is
not). The repo is not yet on weather-dev, so verify locally first and report what
you could and could not exercise:

```
# Local (Windows) — syntax and import surface:
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-marine
python -m compileall weewx_clearskies_marine
```

Then report to the lead which of T4.5's Accept criteria (`pip install -e .`,
`pip install -e ".[nearshore]"`, `python -m weewx_clearskies_marine --help`)
you were able to exercise and which need a Linux host. **The lead will run the
Linux-host verification** — do not attempt to install on a container yourself.

If a Python 3.12 interpreter is available locally, run `pip install -e .` into a
throwaway venv under `c:\tmp\` (never into the repo, never into a container) and
report the result.

### 4.4 Deliverable definition

What the lead expects to see in `git log` when you are done:

- A local git repository at `repos/weewx-clearskies-marine` initialised with
  `git init`, default branch `main`, with **5 or more commits** — at minimum one
  per task T4.1–T4.5, each message naming its task (`feat(T4.1): …`).
- `git status` clean at the end.
- A SendMessage closeout naming, per task T4.1–T4.5, each of that task's "Accept"
  bullets from the plan and the evidence that it is satisfied (file path + what it
  contains, or the command run + its output). **Assertion without evidence will
  be rejected.**

---

## 5. Lead calls — decisions already made; follow them, do not re-derive

1. **Repo creation is local-only this round.** Run `git init` and commit locally.
   Do **not** create a GitHub repo, add a remote, or push. The coordinator creates
   and pushes the GitHub repo after review, with user authorization.

2. **Default branch is `main`** (matching every other `weewx-clearskies-*` code
   repo; only the meta repo uses `master`). Run
   `git init -b main` or `git symbolic-ref HEAD refs/heads/main` before the first
   commit.

3. **License is PolyForm Noncommercial 1.0.0**, matching the API, dashboard, stack
   and SWAN service repos (core repos). Copy `LICENSE` verbatim from
   `repos/weewx-clearskies-api/LICENSE` and set the same
   `license = {text = "PolyForm-Noncommercial-1.0.0"}` form in `pyproject.toml`
   that `repos/weewx-clearskies-swan-swelltrack/pyproject.toml` uses.

4. **The marine service does NOT depend on `weewx-clearskies-api`.** The whole
   point of this separation is to remove the coupling. Do not add
   `weewx-clearskies-api` to `pyproject.toml` dependencies, and do not import
   anything from `weewx_clearskies_api` in marine service source. The SWAN
   service repo does depend on the API — that is the broken pattern we are
   replacing, not a model to copy. Where you need a helper that currently lives
   in the API (HTTP client, rate limiter, cache, error classes), the Phase 5 move
   will bring a copy into `providers/_common/`. For Phase 4 scaffold, write the
   minimal base pattern you need directly in `providers/_common/`, mirroring the
   API's structure and naming.

5. **Config source of truth.** Per ADR-099 and ARCHITECTURE.md, the marine
   service never reads `api.conf`. `config.py` reads the marine service's own
   config file, populated by `POST /config` from the API. Choose
   `/etc/weewx-clearskies/marine/marine.conf` as its path (consistent with T4.4's
   `/etc/weewx-clearskies/marine/` TLS cert location). Persist the pushed config
   to disk atomically (temp file + rename) per `rules/coding.md` §1
   "Expensive computed data must be persisted to disk" and so it survives
   restart.

6. **`MARINE_SERVICE_SECRET` is read from the process environment**, sourced from
   `secrets.env` by the systemd unit's `EnvironmentFile=`. Do not read
   `secrets.env` directly in Python and do not put the secret in `marine.conf`.
   This matches how the API and SWAN service handle their secrets — verify by
   reading the SWAN service's `service.py` auth code and the API's systemd unit.

7. **Bearer token comparison must be constant-time** (`hmac.compare_digest`).
   The SWAN service already does this; match it.

8. **Bind address must be IP-version-agnostic** per `rules/coding.md` §1
   "Network code is IP-version-agnostic". T4.4 says default `0.0.0.0`,
   configurable via CLI arg — implement the CLI arg such that an IPv6 literal or
   a hostname is accepted and resolved correctly, and any URL you build or log
   around an IPv6 literal is bracketed.

9. **Health and manifest are unauthenticated; everything else requires auth.**
   This includes `POST /config`. There is no third tier. Do not invent one.

10. **The manifest's `locations` and `capabilities` fields are dynamic** —
    derived from loaded config and registered providers, not hardcoded literals.
    In the scaffold (no config, no real providers) they are empty/minimal, and
    the `endpoints` array is the literal list from T4.3. Structure the code so
    that Phase 5 populates them without rewriting the handler.

11. **No `--reload`, no debug mode, no `0.0.0.0`-only assumptions in tests.**

12. **Scratch file:** append your progress to `c:\tmp\marine-sep-P4-scratch.md`
    after every commit and every decision. Do not reconstruct it at the end.

---

## 6. Open questions — SendMessage the lead, do NOT resolve unilaterally

Surface any of these if you hit them:

- If the plan's T4.1 directory structure and the API repo's actual conventions
  conflict in a way you cannot satisfy both, describe the conflict — do not pick
  one silently.
- If `PROVIDER-MANUAL` §15's provider pattern requires a dependency the plan's
  T4.5 dependency list does not include, name it and stop.
- If the API's TLS cert generation code cannot be reproduced without importing
  from `weewx_clearskies_api` (which lead call #4 forbids), say so.
- Anything that would require touching a file in §4.2.

---

## 7. Git restrictions (MANDATORY)

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`,
> `git rebase`, `git merge`, or `git checkout` of remote branches. You may only
> `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is
> ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

Additionally, from `rules/clearskies-process.md` "Agent orchestration":

> **Agents edit and commit ONLY on the local machine — HARD BAN on container
> edits.** All source code editing and `git commit` happens on the local machine
> at `c:\CODE\weather-belchertown\repos\weewx-clearskies-*`. You must NEVER edit
> source files on weewx, weather-dev, or librewxr, and must never run any git
> write operation on any container. SSH to containers is READ-ONLY (running
> tests, reading logs, checking service status).

You have **no GitHub rights**. `git init` on a brand-new local repo is permitted
and required; adding a remote or pushing is not.

**Commit messages:** use `git commit -F c:\tmp\<name>-msg.txt` for multi-line
messages — PowerShell heredocs break on parens and quotes.

---

## 8. Scope acknowledgment — required before any code

Before writing any code, SendMessage the lead with a one-paragraph scope
acknowledgment stating: what you will deliver, what you will NOT touch, and the
verification commands you will run before closeout. Wait for confirmation.
