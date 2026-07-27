# Adversarial audit brief — Marine Service Separation Plan, Phase 4

**Round:** MARINE-SEP-P4-AUDIT
**Date:** 2026-07-24
**Lead (coordinator):** Opus
**Auditor:** `clearskies-auditor` (Sonnet)
**Subject:** the `weewx-clearskies-marine` repo produced by Phase 4 tasks T4.1–T4.6

---

## 1. Mandate

You are performing the **mandatory adversarial audit** for Phase 4 of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`. Per the plan's NO DEFERRAL
RULE, this audit cannot be skipped, batched, or deferred, and QC Gate 4 cannot
close until your findings are zero-unresolved.

**You are adversarial. Your job is to find what is wrong, not to confirm what is
right.** The implementing agent has already told me its work satisfies the
acceptance criteria. Assume that claim is unverified. An empty audit is an
acceptable outcome — a *credulous* audit is not.

**You never implement.** Report findings; the lead synthesises and dispatches
remediation.

---

## 2. Reading list — read before auditing

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`:
   - **§"Phase 4 — Marine Service Repo + Scaffold"** in full: T4.1–T4.6, every Do
     step and every Accept bullet. These are the criteria.
   - **§"Adversarial Audit — Phase 4"** — your 7 scope items.
   - **§"QC Gate 4"** — the gate you are informing.
   - §0.6 Code inventory — what Phase 5 will land in this scaffold. A structure
     that cannot accommodate it is a finding.
2. `docs/planning/briefs/P4-MARINE-SCAFFOLD-BRIEF.md` — the brief the implementer
   worked from, including its §5 lead calls (LC-4 no API imports, LC-6 dependency
   split, and the ones added mid-round via SendMessage). **A violated lead call is
   a finding.**
3. `docs/ARCHITECTURE.md` — Services table row for the marine service, port
   registry row 8780, and the marine callout blocks (manifest registration,
   configuration, runtime failure handling, alerts stay in the API, API footprint).
4. `docs/decisions/ADR-099-marine-service-separation.md` — full ADR, including its
   acceptance criteria. Per `rules/clearskies-process.md`
   "Acceptance-criteria-driven sweep", walk the ADR's criteria checklist, not just
   its prose.
5. `docs/manuals/PROVIDER-MANUAL.md` §15 and the provider-pattern sections;
   `docs/manuals/OPERATIONS-MANUAL.md` marine deployment section, §11 filesystem
   permissions, §12 TLS.
6. `rules/coding.md` — §1 in full (this is a security-surface audit: secrets,
   input validation at trust boundaries, IP-version agnosticism, dependency
   pinning, dangerous functions), §2, §3, §4.
7. `rules/clearskies-process.md` — "Audit rules" (especially **"Real findings
   only"**) and "Provider module rules".
8. `c:\tmp\marine-sep-P4-scratch.md` — the round's decision record, including all
   lead calls. Read it; several rulings there are not in the plan.

---

## 3. Audit scope

Execute **all seven items** in the plan's §"Adversarial Audit — Phase 4". Read
them from the plan; I am not restating them. In addition, the lead requires:

### 3.1 Mechanical checks — run these, report raw output

These are pattern matches, not judgment calls. FAIL if any violation is found.

```bash
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-marine

# LC-4: the marine service must NOT depend on or import the API package.
grep -rn "weewx_clearskies_api\|weewx-clearskies-api" . --include=*.py --include=*.toml

# Secrets must never be in source or config file (plan audit item 6).
grep -rni "secret\|token\|password" --include=*.py --include=*.toml --include=*.conf .

# rules/coding.md §1 dangerous functions.
grep -rn "eval(\|exec(\|pickle.loads\|yaml.load(\|shell=True" --include=*.py .

# rules/coding.md §1 IP-version agnosticism — these are anti-patterns.
grep -rn "gethostbyname\|127\.0\.0\.1\|0\.0\.0\.0" --include=*.py .

# rules/coding.md §3 — no dead code, no speculative helpers.
grep -rn "TODO\|FIXME\|XXX\|HACK\|NotImplementedError\|^\s*pass\s*$" --include=*.py .

# LC-6: dependency split. Core must NOT contain eccodes/xarray/netCDF4.
# Speculative deps (shapely, rasterio, cfgrib, coastalmodeling-vdatum) must be absent.
cat pyproject.toml
```

### 3.2 Runtime verification — do not audit from source alone

`rules/clearskies-process.md` "Audit rules" requires **two modes, both**: runtime
tests against real backends AND source-only review. Source-only is insufficient.

Stand the service up and exercise it. If you cannot install it locally, say so
explicitly and tell the lead what needs a Linux host — **do not silently downgrade
to a source-only audit and report it as complete.**

At minimum, verify by execution rather than by reading:

- `/health` returns the field set T4.3 Do step 1 specifies. Paste the actual JSON.
- `/manifest` — **diff the actual emitted JSON against the literal specimen in
  T4.3 Do step 2**, field by field, including `cache_ttl` values and the
  `capabilities` list. Paste both. Plan audit item 5 says "manifest format matches
  the specification"; a prose assertion does not discharge it.
- **Auth enforcement, all four cases:** no token → 401; wrong token → 401;
  correct token → 200 on a protected endpoint; `/health` and `/manifest` → 200
  with no token. `POST /config` **must** be in the protected set — confirm it is
  not accidentally exempt.
- **TLS:** confirm the service refuses plain HTTP and that the cert is generated
  at the path T4.4 specifies.
- `pip install -e .` and `pip install -e ".[nearshore]"`.

### 3.3 Judgment checks the plan's audit scope does not name

1. **Constant-time token comparison.** A `==` string comparison on the bearer
   token is a timing-oracle finding. Verify `hmac.compare_digest` or equivalent.
2. **Config persistence is atomic and survives restart.** `rules/coding.md` §1
   "Expensive computed data must be persisted to disk" and the lead's brief call
   #5 require temp-file + rename. A direct write that can be truncated by a crash
   mid-write is a finding. Verify by reading the write path, then by restarting
   the service and confirming the pushed config is still there.
3. **`POST /config` validates its input at the trust boundary.** It accepts a
   payload from the network. `rules/coding.md` §1 "Validate inputs at trust
   boundaries" applies. An endpoint that persists arbitrary unvalidated JSON to a
   file under `/etc/` is a finding.
4. **Path traversal.** Any file path derived from request input (config push,
   location ids) must be validated. `rules/coding.md` §1 Clear Skies constraint #1:
   never write outside `/etc/weewx-clearskies/` or `/tmp`; normalise with
   `Path.resolve()` before the traversal check.
5. **Structure accommodates Phase 5.** Cross-check the directory tree against
   §0.6's inventory: 11 provider modules across 6 domains, 12 physics modules,
   3 enrichment, 3 config/services. A missing domain directory or a layout that
   forces Phase 5 to restructure is a finding now, not in Phase 5.
6. **The stub provider is unambiguously scaffold-only** and documented as deleted
   in Phase 5. A stub that could be mistaken for a real provider is a finding.
7. **Error responses.** The API returns RFC 9457 `application/problem+json`.
   Check whether the marine service is consistent, and whether inconsistency is
   deliberate and documented or accidental.

### 3.4 Reverse check — what should have been built but wasn't

Per `rules/clearskies-process.md` "Phase-boundary ADR compliance sweep": run the
audit in the *other* direction. Walk ADR-099's acceptance criteria and
ARCHITECTURE.md's marine callouts and ask, for each requirement, whether Phase 4
scope produced code, config, or documentation for it — or whether it fell in the
gap between T4.1–T4.6 and Phase 5. Requirements legitimately belonging to Phase 5
are not findings; requirements belonging to **no** phase are.

---

## 4. What counts as a finding

Per `rules/clearskies-process.md` "Real findings only": every finding must cite a
specific ADR, rule, manual section, plan Accept bullet, or RFC, **and** identify
one of:

- (a) a specific failure mode — describe the input or state that triggers it and
  the wrong behaviour that results;
- (b) a missed constraint from a governing document;
- (c) forced downstream rework (e.g. Phase 5 cannot land without restructuring).

Generic tradeoffs, style preferences, and "consider adding" suggestions are **not
findings**. Do not pad. An audit with two real findings beats one with fifteen
observations.

Classify each finding **BLOCKER** (QC Gate 4 cannot close) or **NON-BLOCKING**
(should fix, does not gate), and say which.

---

## 5. Report format

SendMessage the lead with:

1. **Per-task verdict** for T4.1–T4.6: for each, walk its Accept bullets and mark
   each PASS / FAIL / UNVERIFIED, with the evidence (command + raw output, or file
   + line). "UNVERIFIED" is an honest and acceptable answer when you lacked the
   environment — a false PASS is not.
2. **Per-item verdict** for the plan's 7 audit scope items.
3. **Findings list**, each with: id, BLOCKER/NON-BLOCKING, the cited authority,
   the failure mode, the file and line, and a suggested remediation.
4. **Mechanical check output**, raw, for every command in §3.1.
5. **Runtime evidence**, raw, for §3.2 — actual JSON, actual HTTP status codes.
6. **Explicit statement of what you could not verify and why.**

---

## 6. Constraints

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`,
> `git rebase`, `git merge`, or `git checkout` of remote branches. You may only
> `git status`, `git log`, `git diff`. **You are an auditor — you do not commit
> at all.**

> **You never edit source.** Not to "quickly fix" a finding, not to demonstrate a
> patch. Report it.

> **HARD BAN on container edits.** SSH to weewx / weather-dev / librewxr is
> READ-ONLY: running commands, reading logs, checking service status.

Do not take the implementing agent's closeout claims as evidence. Re-run its
verification commands yourself. Per `rules/clearskies-process.md`, a teammate's
self-reported numbers are one data point, not truth — and the false-claim protocol
exists because an agent once reported "1762 passed, 0 failed" against a reality of
103 failures.
