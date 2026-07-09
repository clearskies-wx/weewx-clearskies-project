# weewx-clearskies-feelslike Extension — Execution Plan

**Status:** COMPLETE
**Created:** 2026-07-08
**Approved:** 2026-07-08
**Completed:** 2026-07-08
**Component:** New weewx XType extension (`weewx-clearskies-feelslike`)

---

## Context

weewx's `StdWXCalculate` computes `appTemp` (Steadman apparent temperature) and `windchill` (NWS 2001 formula) on every loop packet using whatever instantaneous wind speed the anemometer reports — typically a 2–3 second sample. Both formulas were designed and calibrated against **sustained (time-averaged) wind**, not instantaneous readings:

- **Steadman's AT formula** (`AT = Ta + 0.33×e − 0.70×ws − 4.00`) assumes steady-state thermal equilibrium. The Australian BoM, which uses this formula, feeds it 10-minute averaged wind (WMO standard).
- **NWS wind chill formula** (2001 revision) was calibrated against ASOS data reporting **2-minute averaged wind** (twenty-four 5-second samples). NWS defines sustained wind as a 2-minute average for all routine surface weather; the 1-minute period applies only to tropical cyclone intensity.
- **NWS heat index** (Rothfusz regression) has **no explicit wind input** — wind is baked in as a constant 5 knots from Steadman's original model. No correction needed.

The result: on gusty days, `appTemp` and `windchill` jitter with every gust, producing values that don't match what anyone actually feels. The formulas' contract says "give me sustained wind" and weewx doesn't honor that contract.

This extension maintains a 2-minute rolling wind average and provides corrected observation types that use it. It does NOT override existing `appTemp`/`windchill` (those remain for charts and archive continuity). The Clear Skies API will use the new corrected fields as the primary "Feels Like" display value.

### Scientific references

1. **Steadman (1984)** — "A Universal Scale of Apparent Temperature", J. Climate Appl. Meteor., 23, 1674–1687. Assumes steady-state thermal equilibrium.
2. **Osczevski & Bluestein (2005)** — "The New Wind Chill Equivalent Temperature Chart", BAMS. Calibrated against human facial cooling trials using ASOS 2-minute averaged wind.
3. **Rothfusz (1990)** — NWS Technical Attachment SR 90-23, "The Heat Index Equation". Wind baked in as constant 5 knots — no explicit wind variable. No correction needed.
4. **NWS Glossary** — Sustained wind = 2-minute average. ASOS implementation: twenty-four 5-second samples.
5. **WMO-No. 306** — International standard: 10-minute average for surface wind.
6. **Australian BoM** — Uses Steadman formula with WMO 10-minute averaged wind.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — coding standards
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, QC gates

**Repos:**
- **New:** `repos/weewx-clearskies-feelslike` — independent nested git repo (see repo setup below)
- **Pattern source:** `repos/weewx-clearskies-truesun` — clone its Service + XType structure exactly
- **Context:** `repos/weewx-clearskies-extension` — Loop Relay (how packets reach the API)

**Repo setup — independent nested git repo (same as TrueSun):**
- Each Clear Skies repo lives under `repos/` as its own independent git repository with its own `.git` directory
- The meta project (`weather-belchertown`) gitignores all child repos via `repos/*` with only `!repos/.gitkeep` exception — the meta project does NOT track child repo contents
- NOT a git submodule — no `.gitmodules` file exists. Each repo is cloned/managed independently
- The new repo will be created with `git init` inside `repos/weewx-clearskies-feelslike/`
- GitHub repo created separately by the user; agents do NOT push (per git safety rules)

**Optional extension — not required for Clear Skies to function:**
- When this extension is NOT installed, weewx continues computing `appTemp` and `windchill` with its built-in instantaneous-wind formulas. No regression — existing behavior is unchanged.
- When installed, it provides ADDITIONAL observation types (`sustainedWindSpeed`, `feelsLike`, `windchillSustained`) alongside the existing ones. It does not override or replace `appTemp`/`windchill`.
- Same optionality pattern as TrueSun: "When this extension is not installed, weewx falls back to its built-in [method] (no regression)."
- The API and dashboard will prefer the corrected fields when available, but degrade gracefully to the built-in fields when absent.

**Architecture updates required (doc-code sync):**
- ARCHITECTURE.md vocabulary table: add `FeelsLike XType` row with canonical name, repo, description
- ARCHITECTURE.md container inventory callout: add a `>` block-quote paragraph (matching the TrueSun and Loop Relay callouts) documenting the extension as NOT a container, optional, installed via `weectl extension install`, no external dependencies, with fallback behavior
- ARCHITECTURE.md repo layout table: add row for `weewx-clearskies-feelslike`

**Technical architecture:**
- Extension follows **Pattern B (StdService + XType)** like TrueSun
- Registers as `xtype_services` in `weewx.conf`
- XType prepended to position 0 in `weewx.xtypes.xtypes` list
- New observation types registered in `weewx.units.obs_group_dict` at module import time
- Requires `[[Calculations]]` entries in `weewx.conf` with `software, loop` directives
- Loop Relay broadcasts the entire packet dict — new fields automatically relayed to the API
- **NO external dependencies** beyond weewx itself (unlike TrueSun which needs pvlib)
- License: GPL v3 (weewx extensions)

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree.

**Coordinator pre-read requirement (HARD RULE):**
The coordinator MUST read all relevant docs and source code BEFORE two actions:

1. **Before issuing agent assignments.** The coordinator reads the plan, the pattern source files (TrueSun extension, TrueSun installer), the weewx XType docs, and `rules/coding.md` before briefing any dev agent. This ensures prompts are accurate, file paths are current, and the agent isn't sent to implement against stale assumptions. The coordinator does NOT delegate understanding — it verifies the context is correct before handing off work.

2. **Before performing QC on any phase or task.** The coordinator reads the deliverable files (the actual code, installer, README, ARCHITECTURE.md changes) AND the relevant gate criteria from §4 before signing off. QC is not "did the agent say it's done?" — it's "does the deliverable satisfy every check in the gate?"

**QC documentation requirement (HARD RULE):**
QC is a prerequisite for sign-off on completion of any phase or task. It must be documented:
- The coordinator records QC evidence for each gate check: what was verified, what the result was, and any issues found.
- Evidence format: a QC block in the coordinator's reply (not a separate file) listing each gate check as PASS or FAIL with a one-line rationale.
- A phase or task is NOT complete until QC evidence is recorded and all applicable gate checks show PASS.
- If any gate check shows FAIL, the coordinator specifies what needs to change and sends the task back to the dev agent before re-checking.
- "The agent reported success" is not QC evidence. The coordinator must independently verify by reading the files.

---

## 1. Gap Inventory

### A. Core Extension Code

| # | Item | Description |
|---|------|-------------|
| A1 | `_WindBuffer` class | 2-minute ring buffer of (timestamp, windSpeed_mps) tuples with expiry, deduplication, and unit conversion |
| A2 | `_Hysteresis` class | ±1°F dead-band on `feelsLike` output to prevent cosmetic jitter |
| A3 | `sustainedWindSpeed` XType | Returns 2-minute mean wind speed as a `ValueTuple` |
| A4 | `feelsLike` XType | Corrected Steadman AT formula using sustained wind + hysteresis |
| A5 | `windchillSustained` XType | NWS 2001 wind chill formula using sustained wind |
| A6 | Service lifecycle class | `ClearSkiesFeelsLikeService(StdService)` — config, XType registration, shutdown |

### B. Installer and Configuration

| # | Item | Description |
|---|------|-------------|
| B1 | `install.py` | `ExtensionInstaller` subclass registering in `xtype_services` |
| B2 | Config section | `[ClearSkiesFeelsLike]` with `averaging_period`, `min_samples`, `dead_band_f` |

### C. Project Files

| # | Item | Description |
|---|------|-------------|
| C1 | LICENSE | GPL v3 |
| C2 | README.md | Problem statement, installation, configuration, scientific references, explicit "optional — not required" language |
| C3 | changelog | Initial release entry |
| C4 | CI workflows | DCO check, gitleaks, dep-audit, release (copy from TrueSun) |

### D. Governing Document Updates (doc-code sync)

| # | Item | Description |
|---|------|-------------|
| D1 | ARCHITECTURE.md vocabulary table | Add `FeelsLike XType` row: canonical name, what it is, repo `weewx-clearskies-feelslike`, banned terms |
| D2 | ARCHITECTURE.md container callout | Add `>` block-quote paragraph after the TrueSun callout: NOT a container, optional, installed via `weectl extension install`, no external deps, fallback behavior |
| D3 | ARCHITECTURE.md repo layout table | Add row: `weewx-clearskies-feelslike`, `repos/weewx-clearskies-feelslike`, main, Python, No (installs into weewx via `weectl extension install`). No external deps. |

### E. Out of Scope

| Feature | Why |
|---------|-----|
| API changes to prefer `feelsLike` over `appTemp` | Separate repo, separate plan |
| Dashboard display of `feelsLike` | Separate repo, separate plan |
| Configurable WMO 10-minute window option | v0.2 — 2-minute NWS default is correct for v0.1 |

---

## 2. Implementation Phases

### PHASE 0 — Repository Scaffolding

**T0.1 — Create repo structure and CI workflows**
- Owner: Sonnet agent
- Create:
  ```
  repos/weewx-clearskies-feelslike/
  ├── bin/user/clearskies_feelslike.py   (placeholder)
  ├── install.py                         (placeholder)
  ├── LICENSE                            (GPL v3)
  ├── README.md                          (placeholder)
  ├── changelog                          (placeholder)
  └── .github/workflows/
      ├── dco.yml
      ├── gitleaks.yml
      ├── dep-audit.yml
      └── release.yml
  ```
- CI workflows copied from TrueSun, changing only the archive name in `release.yml`.
- Accept: Directory structure matches TrueSun. `git init` + initial commit. LICENSE is GPL v3. CI YAMLs parse.

### PHASE 1 — Core Extension

**T1.1 — Wind speed buffer**
- File: `bin/user/clearskies_feelslike.py`
- Class: `_WindBuffer`
- Stores `list[tuple[float, float]]` — `(epoch_timestamp, wind_speed_mps)` tuples, all internally in m/s.
- Methods:
  - `add(timestamp, wind_speed, us_units)` — converts to m/s, deduplicates by timestamp, appends
  - `mean_mps() -> float | None` — returns mean, or None if fewer than `min_samples` entries
  - `mean_mph() -> float | None` — mean converted to mph (for NWS wind chill)
- Unit conversion constants (matching TrueSun pattern):
  - `_US = 1`, `_METRIC = 16`, `_METRICWX = 17`
  - `_MPH_TO_MPS = 0.44704`, `_KMH_TO_MPS = 1.0 / 3.6`

**T1.2 — Hysteresis dead-band**
- Class: `_Hysteresis`
- State: `_last_emitted: float | None`
- `apply(computed) -> float` — returns `_last_emitted` if `abs(computed - _last_emitted) <= dead_band`, otherwise updates and returns `computed`. First call always emits.

**T1.3 — XType class**
- Class: `ClearSkiesFeelsLikeXType(weewx.xtypes.XType)`
- Handles three `obs_type` values: `sustainedWindSpeed`, `feelsLike`, `windchillSustained`
- On every `get_scalar()` call: reads `record['windSpeed']` and `record['dateTime']`, feeds the wind buffer, then dispatches to the requested calculation.

- **`sustainedWindSpeed`**: returns 2-minute mean in the record's unit system as `ValueTuple(value, unit, "group_speed")`

- **`feelsLike`** (corrected Steadman AT):
  ```
  AT = Ta + 0.33 × e − 0.70 × ws_sustained − 4.00
  e  = (rh / 100) × 6.105 × exp(17.27 × Ta / (237.7 + Ta))
  ```
  All computation in °C / m/s. Apply hysteresis dead-band (±1°F) after formula, before return. Return in record's unit system.

- **`windchillSustained`** (NWS 2001):
  ```
  WCT = 35.74 + 0.6215×T − 35.75×V^0.16 + 0.4275×T×V^0.16
  ```
  T in °F, V in mph (sustained). Valid only when T ≤ 50°F AND V > 3 mph; return `ValueTuple(None, ...)` otherwise. Return in record's unit system.

- **Unit group registration** at module level:
  ```python
  weewx.units.obs_group_dict["sustainedWindSpeed"] = "group_speed"
  weewx.units.obs_group_dict["feelsLike"] = "group_temperature"
  weewx.units.obs_group_dict["windchillSustained"] = "group_temperature"
  ```

**T1.4 — Service class**
- Class: `ClearSkiesFeelsLikeService(weewx.engine.StdService)`
- Reads `[ClearSkiesFeelsLike]` config: `averaging_period` (default 120), `min_samples` (default 10), `dead_band_f` (default 1.0)
- Creates `_WindBuffer` and `_Hysteresis`, passes to XType
- `weewx.xtypes.xtypes.insert(0, self._xtype)` — prepend for priority
- `shutDown()` removes XType from list (matching TrueSun pattern)
- No background threads (unlike TrueSun) — all computation is synchronous in `get_scalar()`

**QC after Phase 1:**
1. `python -m py_compile bin/user/clearskies_feelslike.py` passes
2. Formula verification: trace reference data points:
   - Steadman: 30°C, 50% RH, 3 m/s sustained → AT ≈ 30.9°C
   - NWS WCT: 20°F, 15 mph sustained → WCT ≈ 6.2°F
3. Unit conversion dimensional check: 10 mph × 0.44704 = 4.4704 m/s
4. Verify XType at position 0, `shutDown` removes it, `obs_group_dict` at module level

### PHASE 2 — Installer

**T2.1 — Write `install.py`**
- Follow TrueSun installer exactly. Key differences: config section name, keys, service path.
- Config template:
  ```ini
  [ClearSkiesFeelsLike]
      # Rolling window in seconds for sustained wind calculation.
      # 120 = 2 minutes, matching NWS ASOS sustained wind definition.
      averaging_period = 120
      # Minimum wind samples before using averaged wind.
      # Below this, the extension raises CannotCalculate and weewx
      # falls back to its built-in instantaneous-wind formulas.
      min_samples = 10
      # Hysteresis dead-band for feelsLike output (degrees Fahrenheit).
      dead_band_f = 1.0
  ```
- Accept: Installer matches TrueSun structure. `xtype_services` registration. Import compatibility try/except.

### PHASE 3 — Documentation

**T3.1 — README.md**
- Problem statement (instantaneous vs sustained wind — the formulas' contract violation)
- Requirements: weewx 5.x, Python 3.10+, no external deps
- Installation: `weectl extension install`
- Configuration: show `[ClearSkiesFeelsLike]` section AND required `[[Calculations]]` entries:
  ```ini
  [StdWXCalculate]
      [[Calculations]]
          sustainedWindSpeed = software, loop
          feelsLike = software, loop
          windchillSustained = software, loop
  ```
- New observation types table
- Why new types instead of overriding existing ones (archive/chart continuity)
- All 6 scientific references with full citations
- Fallback behavior (insufficient samples → `CannotCalculate` → weewx uses built-in formulas)

**T3.2 — changelog**
- Initial `0.1.0` entry listing all three new observation types.

**T3.3 — ARCHITECTURE.md updates (doc-code sync)**
- Owner: Coordinator (Opus) — governs the meta repo, not the extension repo
- File: `docs/ARCHITECTURE.md` (in the `weather-belchertown` meta repo)
- Do:
  1. **Vocabulary table** (line ~27 area): Add row after TrueSun:
     - Canonical name: **FeelsLike XType**
     - What it is: weewx extension that provides `sustainedWindSpeed`, `feelsLike`, and `windchillSustained` observation types using 2-minute averaged wind instead of instantaneous readings. Registered as an XType before `StdWXXTypes`. Code class: `ClearSkiesFeelsLikeXType`.
     - Repo: `weewx-clearskies-feelslike`
     - Banned terms: ~~the feelslike extension~~ (use the canonical name)
  2. **Container inventory callout** (after the TrueSun block-quote, ~line 89): Add block-quote:
     > **ClearSkiesFeelsLikeXType weewx extension** (`weewx-clearskies-feelslike`) is NOT a container. It is a weewx XType extension that runs inside the weewx process, installed via `weectl extension install`. It provides corrected thermal comfort values (`feelsLike`, `windchillSustained`) using 2-minute averaged wind (NWS ASOS sustained wind standard) instead of instantaneous readings. When this extension is not installed, weewx falls back to its built-in instantaneous-wind formulas for `appTemp` and `windchill` (no regression). No external dependencies.
  3. **Repo layout table** (~line 588 area): Add row after TrueSun:
     `weewx-clearskies-feelslike | repos/weewx-clearskies-feelslike | main | Python | No (installs into weewx via weectl extension install). No external deps.`
- Accept: All three locations updated. Vocabulary, callout, and repo table entries present. No contradictions with existing entries.

### PHASE 4 — Integration Verification

**T4.1 — Install and test on weewx container**
- Owner: Coordinator (Opus), requires user-authorized push
- Install extension, add `[[Calculations]]` entries, restart weewx
- Verify: syslog shows registration message
- After 2+ minutes: verify new fields in loop packets via Loop Relay socket
- Verify values are physically reasonable and less jittery than `appTemp`/`windchill`
- Verify existing `appTemp`/`windchill` unchanged

**T4.2 — Verify API SSE picks up new fields**
- Loop Relay sends full packet dict — new fields should appear in SSE automatically
- No API code changes needed for this phase

### PHASE 5 — QA Audit

> **Purpose:** Independent verification that all QC gates (1–6) were actually satisfied during Phases 0–4. The QA auditor has NOT seen the implementation work and approaches the code fresh. If any gate was skipped, rubber-stamped, or has findings, the auditor sends the affected phase back for rework before the plan can close.

**T5.1 — Full QA audit**
- Owner: `clearskies-auditor` agent (independent of the dev and coordinator agents)
- Model: Opus
- Inputs: the completed code at `repos/weewx-clearskies-feelslike/`, this plan (for gate criteria), and the pattern source at `repos/weewx-clearskies-truesun/`
- Scope: walk every check in Gates 1–6 against the actual deliverables. The auditor does NOT trust prior QC sign-offs — it re-verifies from scratch.

**Audit checklist (maps to gates):**

| Audit area | Gate | What the auditor does |
|------------|------|-----------------------|
| Code quality | Gate 1 | Run `py_compile` on both `.py` files. Grep for `from __future__ import annotations`. Verify no imports outside stdlib + weewx. Spot-check PEP 8 (line length, naming). Verify module docstring + copyright + GPL v3 notice. |
| Formula correctness | Gate 2 | Read each formula in the code and character-compare against the plan's reference formulas. Manually compute both reference data points (Steadman 30°C/50%/3m/s, NWS WCT 20°F/15mph) and compare to what the code would produce. Verify wind chill validity bounds (T ≤ 50°F, V > 3 mph). Verify hysteresis is applied after formula, before return. Verify unit conversion constants match weewx source. |
| Pattern compliance | Gate 3 | Diff `clearskies_feelslike.py` structure against `clearskies_truesun.py`. Verify: XType inheritance, position 0 insert, `shutDown` cleanup, `obs_group_dict` at module level, `UnknownType`/`CannotCalculate` protocol, `noqa: N802` on `shutDown`. Diff `install.py` against TrueSun installer — only name/config/service differences allowed. |
| Scientific accuracy | Gate 4 | Read README.md. Verify all 6 scientific references present with correct attribution. Verify "2-minute average" (not "1-minute"). Verify heat index documented as not needing correction. Verify ASOS 24×5-second detail present. |
| Repo setup & doc sync | Gate 5 | Verify `repos/weewx-clearskies-feelslike/.git` exists as independent repo (not submodule). Read ARCHITECTURE.md — verify vocabulary table row, container callout block-quote, and repo layout table row are all present and accurate. Verify README states extension is optional with fallback behavior. |
| Integration evidence | Gate 6 | Review coordinator's Phase 4 evidence (syslog output, loop packet samples, SSE output). If evidence is missing or incomplete, flag as a finding — the auditor does NOT re-run live tests, but verifies the coordinator actually captured the evidence. |

**Findings and rework protocol:**

1. The auditor produces a findings report with severity levels:
   - **BLOCK** — gate criterion not met; must be fixed before plan closes. Examples: formula mismatch, missing `obs_group_dict` registration, wrong service list, missing scientific reference.
   - **WARN** — gate criterion partially met or has a minor issue that doesn't affect correctness. Examples: missing `# noqa` comment, minor PEP 8 violation, README phrasing could be clearer.
   - **PASS** — gate criterion fully satisfied.

2. Any **BLOCK** finding sends the affected task back to the dev agent for rework:
   - The auditor specifies: which file, which line/function, what's wrong, what the fix should be.
   - The dev agent fixes and commits.
   - The coordinator re-runs the QC for the affected gate only.
   - The auditor re-checks the specific finding (not a full re-audit).

3. **WARN** findings are reported to the user. The user decides whether to fix or accept.

4. The plan is complete only when the auditor reports **all gates PASS** (no remaining BLOCKs).

**Accept:** Auditor report with per-gate PASS/WARN/BLOCK status. Zero BLOCK findings remaining. Any WARN findings acknowledged by user.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 0 | T0.1 Repo scaffolding | `clearskies-feelslike-dev` | Sonnet | Directory layout matches TrueSun; LICENSE is GPL v3 verbatim | After T0.1 |
| 0 | T0.1 CI workflows | `clearskies-feelslike-dev` | Sonnet | Diff each workflow against TrueSun source; only repo name differs | After T0.1 |
| 1 | T1.1 Wind buffer | `clearskies-feelslike-dev` | Sonnet | Unit conversion dimensional spot-check; expiry logic; dedup | After Phase 1 |
| 1 | T1.2 Hysteresis | `clearskies-feelslike-dev` | Sonnet | Dead-band suppresses small oscillations; first call always emits | After Phase 1 |
| 1 | T1.3 XType class | `clearskies-feelslike-dev` | Sonnet | Formula verification with reference values; unit returns; `CannotCalculate` paths | After Phase 1 |
| 1 | T1.4 Service class | `clearskies-feelslike-dev` | Sonnet | Config parsing; XType at position 0; `shutDown` cleanup | After Phase 1 |
| 2 | T2.1 Installer | `clearskies-feelslike-dev` | Sonnet | Diff against TrueSun installer; `xtype_services` registration | After Phase 2 |
| 3 | T3.1 README | `clearskies-feelslike-dev` | Sonnet | All 6 scientific references; `[[Calculations]]` entries documented; fallback behavior | After Phase 3 |
| 3 | T3.2 Changelog | `clearskies-feelslike-dev` | Sonnet | Format matches TrueSun | After Phase 3 |
| 3 | T3.3 ARCHITECTURE.md | Coordinator | Opus | Vocabulary row, container callout, repo layout row all present; no contradictions | After Phase 3 |
| 4 | T4.1 Install + test | Coordinator | Opus | Live verification on weewx container; new fields in loop packets | After Phase 4 |
| 4 | T4.2 SSE verification | Coordinator | Opus | New fields visible in API SSE stream without API code changes | After Phase 4 |
| 5 | T5.1 Full QA audit | `clearskies-auditor` | Opus | Independent re-verification of all Gates 1–6; BLOCK/WARN/PASS per gate | After Phase 4 |
| 5 | Rework (if needed) | `clearskies-feelslike-dev` | Sonnet | Fix any BLOCK findings from auditor; coordinator re-QCs affected gate | After T5.1 findings |
| 5 | Re-check (if needed) | `clearskies-auditor` | Opus | Re-verify specific BLOCK findings only (not full re-audit) | After rework |

**Sequencing:**
- Phase 0 (scaffolding) → Phase 1 (core code) → Phase 2 (installer) → Phase 3 (docs) → Phase 4 (integration) → Phase 5 (QA audit)
- Phases 0–3 are small enough for a single Sonnet agent session (~200 lines of Python + installer + README)
- Phase 4 requires user authorization to push to GitHub
- Phase 5 runs AFTER Phase 4 and is performed by the `clearskies-auditor` agent, which is independent of the dev agent and coordinator — it has not seen the implementation and approaches the code fresh
- If the auditor finds BLOCK issues, the rework → re-QC → re-check cycle repeats until all 6 gates PASS
- Plan closes only when the auditor reports zero remaining BLOCKs across all 6 gates

**QC role: Coordinator (Opus).** The coordinator performs QC after EVERY phase completes — not batched at the end. No phase advances until the coordinator signs off.

**QA role: `clearskies-auditor` (Opus).** The auditor is a separate agent that independently re-verifies all 6 QC gates after Phase 4. It does not trust prior QC sign-offs. It can send work back to the dev agent via BLOCK findings. The plan is not complete until the auditor reports all 6 gates PASS.

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)

- `python -m py_compile bin/user/clearskies_feelslike.py` — 0 errors
- `python -m py_compile install.py` — 0 errors
- `from __future__ import annotations` present
- Type hints on all public methods and function signatures
- PEP 8 compliance (no lines > 99 chars, proper naming)
- No external dependencies (no `import` of anything outside stdlib + weewx)
- No dead code, no commented-out blocks
- Module-level docstring with copyright and GPL v3 notice

### Gate 2 — Formula Correctness (Phase 1, Opus verifies)

- Steadman AT formula character-for-character matches: `AT = Ta + 0.33 * e - 0.70 * ws - 4.00`
- Vapor pressure formula character-for-character matches: `e = (rh / 100) * 6.105 * exp(17.27 * Ta / (237.7 + Ta))`
- NWS wind chill formula character-for-character matches: `WCT = 35.74 + 0.6215*T - 35.75*V**0.16 + 0.4275*T*V**0.16`
- NWS wind chill validity bounds enforced: T ≤ 50°F AND V > 3 mph; returns `None` outside bounds
- **Reference value spot-checks** (coordinator traces one data point through each formula):
  - Steadman: 30°C, 50% RH, 3 m/s sustained → e ≈ 21.2 hPa → AT ≈ 30.9°C (within ±0.1°C)
  - NWS WCT: 20°F, 15 mph sustained → WCT ≈ 6.2°F (within ±0.1°F)
- Unit conversion factors verified against weewx source: `_MPH_TO_MPS = 0.44704`, `_KMH_TO_MPS = 1.0 / 3.6`
- Dimensional spot-check: 10 mph × 0.44704 = 4.4704 m/s
- Hysteresis applied AFTER formula computation, BEFORE `ValueTuple` return

### Gate 3 — Pattern Compliance (Phase 1 + Phase 2, Opus verifies)

- XType class inherits `weewx.xtypes.XType`
- Service class inherits `weewx.engine.StdService`
- XType inserted at position 0: `weewx.xtypes.xtypes.insert(0, self._xtype)`
- `shutDown()` removes XType from list with `try/except ValueError`
- `obs_group_dict` registration at module level (not inside a function or `__init__`)
- Installer registers as `xtype_services` (not `restful_services` or `data_services`)
- Installer has import compatibility: `try: from weecfg.extension` / `except: from weewx.extensioninstaller`
- Config dict uses `configobj.ConfigObj(StringIO(...))` pattern (matching TrueSun)
- `get_scalar()` raises `weewx.UnknownType` for unhandled `obs_type`
- `get_scalar()` raises `weewx.CannotCalculate` when inputs missing or buffer insufficient
- `shutDown` method uses weewx camelCase convention with `# noqa: N802` suppression

### Gate 4 — Scientific Accuracy (Phase 3, Opus verifies)

- README cites all 6 references from the Context section with full attribution
- NWS sustained wind correctly documented as **2-minute average** (not 1 minute)
- 1-minute averaging documented as tropical-cyclone-only exception
- ASOS implementation detail: twenty-four 5-second samples over 2 minutes
- Heat index explicitly documented as NOT needing correction (no wind input — baked in as 5 kt constant)
- Steadman (1984) cited for AT formula with steady-state assumption
- Osczevski & Bluestein (2005) cited for NWS wind chill calibration methodology
- Fallback behavior documented: insufficient samples → `CannotCalculate` → weewx built-in formulas

### Gate 5 — Repo Setup and Doc-Code Sync (Phase 0 + Phase 3, Opus verifies)

- `repos/weewx-clearskies-feelslike/.git` exists — independent git repo, not a submodule
- Meta repo's `.gitignore` already covers `repos/*` — no additional gitignore entry needed
- ARCHITECTURE.md vocabulary table has `FeelsLike XType` row with correct canonical name, repo, and banned terms
- ARCHITECTURE.md container callout block-quote present after TrueSun callout, states: NOT a container, optional, installed via `weectl extension install`, no external deps, fallback behavior ("no regression")
- ARCHITECTURE.md repo layout table has `weewx-clearskies-feelslike` row
- README.md explicitly states the extension is **optional — not required** for Clear Skies to function
- README.md documents fallback behavior: when not installed, weewx uses built-in instantaneous-wind formulas

### Gate 6 — Integration (Phase 4, Opus verifies on weewx container)

- Extension installs via `weectl extension install` without error
- `weewx.conf` shows `user.clearskies_feelslike.ClearSkiesFeelsLikeService` in `xtype_services`
- Service log message `ClearSkiesFeelsLike: registered XType` appears in syslog on restart
- After 2+ minutes (buffer fill), all three new types appear in loop packets:
  - `sustainedWindSpeed` — present, value between min and max of recent `windSpeed` values
  - `feelsLike` — present, close to `appTemp` but visibly smoother over a gusty period
  - `windchillSustained` — present when T ≤ 50°F and wind > 3 mph; `None` otherwise
- Existing `appTemp` and `windchill` values **unchanged** (new types are additive, not destructive)
- No errors or warnings in syslog from the extension during a 10-minute observation window
- API SSE stream includes new fields automatically (Loop Relay broadcasts full packet dict)
- No API restart required for new fields to appear in SSE

---

## 5. Self-Audit

**Risk: Buffer not full on startup.** The buffer starts empty. Before `min_samples` (default 10, ~20–30 seconds) are accumulated, the extension raises `CannotCalculate`. weewx falls back to its built-in instantaneous formulas for the standard types. The new types simply don't appear until the buffer is ready. Correct behavior — better to emit nothing than a value from insufficient data.

**Risk: Memory growth.** `_expire()` runs on every `add()`. With 5-second loop intervals and a 120-second window, the buffer holds at most ~24 entries. Negligible memory.

**Risk: ±1°F dead-band suppresses real changes.** 1°F is below human perception threshold. The dead-band only affects `feelsLike`; raw `appTemp` continues updating every packet for charts. Divergence only appears on gusty days — which is when the correction matters.

**Risk: Operator forgets `[[Calculations]]` entries.** The weewx installer API cannot modify existing config sections. README documents the required entries prominently. Extension silently produces no values if entries are missing (StdWXCalculate never calls `get_scalar()` for unlisted types). Known limitation of all weewx XType extensions.

**Risk: `get_scalar()` called for archive records.** The `loop` binding in `[[Calculations]]` prevents this. Even without it, archive records have pre-averaged wind, so the buffer would average an already-averaged value — harmless but suboptimal.

---

## 6. Critical Files

| File | Role |
|------|------|
| `repos/weewx-clearskies-truesun/bin/user/clearskies_truesun.py` | Pattern source: Service + XType structure, unit conversion, `ValueTuple` returns, `get_scalar()` dispatch |
| `repos/weewx-clearskies-truesun/install.py` | Pattern source: installer structure, config dict, `xtype_services` registration |
| `docs/reference/weewx-5.3/custom/xtypes.md` | XType API: `insert(0,...)` priority, `UnknownType`/`CannotCalculate` protocol |
| `docs/reference/weewx-5.3/reference/weewx-options/stdwxcalculate.md` | `[[Calculations]]` directives, `software` and `loop` binding |

---

## 7. Verification

After Phase 4 deployment:
1. SSH to weewx container, tail syslog for `ClearSkiesFeelsLike: registered XType` message
2. Wait 2+ minutes for buffer to fill
3. Read loop packets from the Unix socket — verify `sustainedWindSpeed`, `feelsLike`, `windchillSustained` are present
4. Compare `feelsLike` to `appTemp` — should be close but smoother (less gust-driven jitter)
5. Compare `windchillSustained` to `windchill` — should be close but smoother
6. Verify `sustainedWindSpeed` is between min and max of recent `windSpeed` values
7. Confirm existing `appTemp` and `windchill` fields are unchanged
8. Check API SSE stream for new fields (no API code changes needed)
