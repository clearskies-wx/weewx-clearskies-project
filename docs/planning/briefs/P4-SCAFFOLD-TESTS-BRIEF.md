# Round brief — Marine Service Separation Plan, Phase 4 task T4.6

**Round:** MARINE-SEP-P4-T4.6 (marine service scaffold tests)
**Date:** 2026-07-24
**Lead (coordinator):** Opus
**Implementation agent:** `clearskies-test-author` (Sonnet)
**Auditor:** `clearskies-auditor` (Sonnet) — adversarial audit follows, mandatory

---

## 1. Round identity and mandate

You are implementing **T4.6 — Write marine service scaffold tests** of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`.

T4.1–T4.5 are complete and committed. The service is built, installable, and
verified running. Your job is the test suite that keeps it that way.

**NO DEFERRAL RULE applies.** Read §"NO DEFERRAL RULE" at the top of the plan.
No skipped tests, no `pytest.mark.skip` without an explicit reason surfaced to
me, no "covered in Phase 5".

---

## 2. Reading list — read these BEFORE writing any tests

Read the original text. This brief deliberately does not restate their content.

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`:
   - §0.3 (git restrictions), §0.4 (scratch discipline)
   - **§T4.6 in full** — its 3 Do steps and 3 Accept bullets. This is your spec.
   - **§T4.3 and §T4.4 in full** — the behaviour you are testing, including the
     literal `/manifest` specimen in T4.3 Do step 2 and T4.4's auth/TLS rules.
   - §"Adversarial Audit — Phase 4" and §"QC Gate 4" — what your tests must make
     verifiable.
2. `docs/planning/briefs/P4-MARINE-SCAFFOLD-BRIEF.md` — the implementer's brief,
   especially §5 lead calls. Several behaviours exist because of a lead call
   rather than because of the plan.
3. `c:\tmp\marine-sep-P4-scratch.md` — the round's decision record. Read
   **LC-25, LC-26, LC-31, LC-32** in particular; each has a testable consequence.
4. `docs/ARCHITECTURE.md` — marine service Services-table row, port registry row
   8780, and the marine callout blocks.
5. `rules/coding.md` — §1 (security posture — your auth and TLS tests are
   security tests), §3, §4.
6. `rules/clearskies-process.md` — "Never run the full pytest suite" (run only
   the marine repo's tests), and the "Independent lead verification" section
   (I will re-run everything you report).
7. The code under test — read each in full:
   - `repos/weewx-clearskies-marine/weewx_clearskies_marine/service.py`
   - `.../endpoints/{health,manifest,config}.py`
   - `.../auth.py`, `.../config.py`, `.../state.py`, `.../tls.py`, `.../errors.py`
   - `.../providers/_common/dispatch.py`, `.../providers/_stub.py`
   - **`repos/weewx-clearskies-marine/tests/conftest.py`** — fixtures already
     exist. Build on them; do not duplicate or replace them.
8. The API repo's test suite as a style reference (read-only):
   `repos/weewx-clearskies-api/tests/` — pick two or three endpoint/auth test
   files and match their idiom, naming and fixture style.

---

## 3. Pre-round verification (performed by the lead, 2026-07-24)

I verified the service independently on **weather-dev (Linux, Python 3.12)** —
the real target platform, not the implementer's Windows box — using `curl`, not
the implementer's `httpx`. Everything below is measured, not reported to me:

```
pip install -e .            → OK, importlib.metadata version == "0.1.0"
pip install -e ".[nearshore]" → OK (xarray 2026.7.0, netCDF4 1.7.4)
python -m weewx_clearskies_marine --help → 5 CLI args, all documented

GET  /health   (no auth) → {"status":"ok","version":"0.1.0","last_run":null,
                            "spots":[],"run_in_progress":false}
GET  /manifest (no auth) → 6 endpoint entries, matches the plan specimen
POST /config   (no token)      → 401
POST /config   (wrong token)   → 401
POST /config   (correct token) → 200
plain HTTP to the TLS port     → connection failure (curl exit, code 000)

After a config push:
  /manifest capabilities → ['surf']
  /manifest locations    → [{'id': 'huntington-city-beach-pier'}]
  /health   spots        → []           <-- see §5 LC-36
  persisted file mode    → -rw-r-----  (0640)
  TLS key mode           → -rw-------  (0600)
  TLS cert mode          → -rw-rw-r--
```

Repo state: `repos/weewx-clearskies-marine` at `25ae32e`, 5 commits, working tree
clean, `origin/main` on GitHub (private) at the same commit. **You may not push.**

Verified structural facts you can rely on:
- Zero `import weewx_clearskies_api` anywhere in the marine repo (32 textual
  mentions exist, all docstring/comment credits — not imports).
- `hmac.compare_digest` at `auth.py:62`.
- Atomic persist at `config.py`: `tempfile.mkstemp` → `os.chmod(0o640)` →
  `os.replace`.
- Zero `eval`/`exec`/`pickle.loads`/`yaml.load`/`shell=True`.

---

## 4. Scope

### 4.1 Files to create or modify (exhaustive)

All under `repos/weewx-clearskies-marine/tests/`:

| File | Contents |
|---|---|
| `test_health.py` | `/health` response shape and field types |
| `test_manifest.py` | `/manifest` shape, the literal endpoint specimen, dynamic fields |
| `test_config.py` | `POST /config` accept, persist, round-trip, validation |
| `test_auth.py` | The full auth matrix, both protected and unauthenticated routes |
| `test_tls.py` | Cert generation and HTTPS-only behaviour |
| `conftest.py` | **Extend only.** Do not rewrite the existing fixtures. |

Decomposition into more files is fine if it improves clarity; consolidating into
fewer is not.

### 4.2 Files NOT to touch

- **Any file under `weewx_clearskies_marine/`.** You are the test author. If a
  test cannot be written without a production-code change (a missing seam, an
  untestable hard-coded path), **STOP and report it via SendMessage** — do not
  edit the module. That is a finding, and possibly a design defect worth knowing.
- `pyproject.toml` — unless a test-only dependency is genuinely required, in
  which case ask first.
- Anything in `repos/weewx-clearskies-api/`, `-dashboard/`, `-stack/`,
  `-swan-swelltrack/`.
- Any file in the meta repo (`docs/`, `rules/`, `reference/`).
- **Any file on any container.** Editing on weewx / weather-dev / librewxr is
  banned by any mechanism. SSH is read-only.

### 4.3 Verification commands — report raw output

```bash
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-marine
python -m pytest tests/ -q --tb=short
python -m pytest tests/ -q --tb=no          # summary line
```

Report the pass/fail/skip counts and the commit hash. **Any skipped test must be
named with its reason** — I will treat an unexplained skip as a silent deferral.

I will re-run your suite on weather-dev (Linux, 3.12) myself. If a test passes on
Windows and fails on Linux, that is a finding about the test, not about Linux —
so prefer platform-neutral assertions (`Path`, `tmp_path`, no drive letters, no
POSIX-mode assertions that cannot hold on Windows).

### 4.4 Deliverable definition

- 1–3 commits on the local `main` branch of the marine repo, messages naming the
  task (`test(T4.6): …`).
- `git status` clean.
- A SendMessage closeout walking **each of T4.6's 3 Accept bullets** with
  evidence, plus the full pytest output, plus any test you could not write and
  why.

---

## 5. Lead calls — implement these; do not re-derive

### LC-36 — `/health.spots` stayed empty after a config push. Probe it; do not assume.

In my verification, pushing a config with
`locations: [{"id": "huntington-city-beach-pier"}]` populated `/manifest`'s
`locations` and `capabilities`, but `/health`'s `spots` stayed `[]`.

That may be **correct** — `spots` plausibly means *surf spots* (locations with a
surf sub-config), and my test payload had a bare location with no surf block. Or
it may be a wiring gap.

**Do:** determine which by reading `endpoints/health.py` and `state.py`, then
write a test that pins the actual intended semantics. If `spots` is meant to
track surf-configured locations, test it with a payload that has a surf block and
assert it populates. If `spots` is genuinely unwired to config, that is a
**finding** — report it via SendMessage and write a test that documents current
behaviour with a comment explaining it is provisional. Do not silently assert
`spots == []` as if that were the specification.

### LC-37 — Test the auth matrix by behaviour, and include the 500 case

T4.4's Accept bullets name three cases. There are five states, and the
implementation deliberately distinguishes them:

1. no `Authorization` header → 401
2. malformed / non-Bearer header → 401
3. wrong token → 401
4. correct token → 200
5. `MARINE_SERVICE_SECRET` unset server-side → **500, not 401**

Case 5 is a deliberate design decision (a missing server secret is a deployment
fault, not a client fault). Test it, and **also assert the response body does not
disclose whether a secret exists** — leaking that distinction is what makes a 401
into an oracle.

Test `/health` and `/manifest` return 200 with **no** header, and that
`POST /config` is in the protected set. A future endpoint accidentally landing
outside the auth dependency is exactly what this test catches.

### LC-38 — Fixtures must never touch the default paths

Per LC-32 in the scratch file: the default config path is POSIX-absolute and on
Windows resolves to a real drive-root path (`C:\etc\weewx-clearskies\...`), which
the service will happily create. The implementer twice created a stray directory
during manual verification before hardening `conftest.py`.

**Every** test must override both the config path and the cert dir via the
existing fixtures — `tmp_path`-based, never the defaults. Do not add a test that
relies on the default path even to assert what the default *is*; assert the
constant instead. If you find any path by which a test could write outside
`tmp_path`, report it.

### LC-39 — Manifest test must diff against the literal, not spot-check it

T4.3 Do step 2 contains a literal 6-entry manifest specimen. Assert against the
**whole** structure — all six entries, each with `path`, `method`, `upstream`,
`cache_ttl` — not a length check plus one sampled entry. A wrong `cache_ttl` on
one endpoint is precisely the kind of thing a spot-check misses and Phase 6's
companion proxy then inherits.

Assert `capabilities` and `locations` are **dynamic**: empty before a config
push, populated after, with no service restart. That behaviour is what Phase 5
depends on.

Do **not** assert `version == "1.0.0"`. Per LC-25 the version resolves from
package metadata (currently `0.1.0`) and will change. Assert it is a non-empty
string matching a version pattern, and assert `/health` and `/manifest` report
the **same** value — that is the invariant worth pinning.

### LC-40 — TLS tests: assert behaviour, not implementation

T4.6 Do step 3 asks for "verify service only listens on HTTPS, verify cert
generation". Two cautions:

- Assert the cert and key are **created** at the configured dir when absent, that
  the key is not world-readable, and that an existing cert is **not** silently
  regenerated on restart (regeneration would break every client's pinned
  fingerprint). Skip POSIX-mode assertions on Windows via a platform guard rather
  than dropping them — I run the suite on Linux where they must hold.
- For "HTTPS only", prefer asserting the server is constructed with TLS
  parameters over spinning a real socket, unless the existing fixtures already
  make a real-socket test cheap. A flaky port-binding test in CI is worse than a
  narrower assertion. Tell me which you chose.

Note the known constraint (scratch file): Windows curl/schannel cannot handshake
Ed25519 certs. This affects manual verification only — Python's `ssl`/`httpx`
handle it fine, so it should not shape your tests. Do not work around a
non-problem.

---

## 6. Open questions — SendMessage the lead; do NOT resolve unilaterally

- Any test that cannot be written without changing production code.
- LC-36's `spots` semantics, if reading the code does not settle it.
- Any behaviour you find that contradicts T4.3/T4.4's Accept bullets — that is a
  finding for me, not something to encode as expected behaviour in a test.
- Any test-only dependency you need added to `pyproject.toml`.

---

## 7. Git restrictions (MANDATORY)

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`,
> `git rebase`, `git merge`, or `git checkout` of remote branches. You may only
> `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is
> ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

**Note:** this repo now has a GitHub remote (`origin`, private) at `25ae32e`.
That makes the push prohibition live rather than theoretical. The coordinator
pushes.

> **Agents edit and commit ONLY on the local machine — HARD BAN on container
> edits.** All editing and committing happens at
> `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`. SSH to containers
> is READ-ONLY.

Stage only your own named paths (`tests/…`). Never `git add -A`, never `git add .`.

**Commit messages:** use `git commit -F c:\tmp\<name>-msg.txt`.

**Scratch file:** append to `c:\tmp\marine-sep-P4-scratch.md` after every commit
and every decision.

---

## 8. Scope acknowledgment — required before any tests

Before writing any tests, SendMessage the lead with a one-paragraph scope
acknowledgment: what you will deliver, what you will NOT touch, and the exact
verification commands you will run.
