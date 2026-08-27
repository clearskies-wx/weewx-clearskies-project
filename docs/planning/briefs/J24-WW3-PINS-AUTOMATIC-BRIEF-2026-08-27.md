# J24 — WW3 binary checksum pins become automatic (brief, 2026-08-27)

## 1. Round identity

- Round: J24 (post-plan fix; MARINE-AND-MAPS-PLAN-2026-08-27 journal item J24).
- Date: 2026-08-27. Lead: coordinator. Teammates: `j24-test` (clearskies-test-author),
  `j24-dev` (clearskies-api-dev, working in the MARINE repo). Auditor: `gate-j24`
  (clearskies-auditor, results-free gate at `scratch/GATE-J24-DEFINITION.md`).
- Operator order (verbatim, 2026-08-27): *"whaat do you mean checksums are in a handwritten
  file? WE CANNOT HAVE THAT! THIS ENTIRE SETUP HAS TO BE AUTOMATIC!"* — that order is the
  approval for the persisted file and loader change this round adds (CLAUDE.md trigger 7).

## 2. The defect (what happened, in plain words)

The marine service will only run a WaveWatch III (WW3) program after checking that the
program file on disk has the exact checksum it expects (`WW3Runner._verify_binaries()`,
`weewx_clearskies_marine/services/ww3_runner.py:354`). Those expected checksums ("pins")
live in the `ww3` block of the marine service's config file
(`/etc/weewx-clearskies/marine/marine.conf`, JSON). That block was placed BY HAND on
2026-08-18 — nothing ever generated it.

Every config push from the API (`POST /config` → `persist_config()`,
`weewx_clearskies_marine/config/__init__.py:94`) rewrites the whole file from the API's
payload, and the API's payload has no `ww3` block
(`weewx_clearskies_api/endpoints/setup.py::_build_marine_service_config_payload` — grep
confirms no `"ww3"` key anywhere in the API repo). So every push silently deletes the pins,
and the next WW3 leg refuses `ww3_binaries_invalid` ("no sha256 pin configured for
ww3_grid"). This happened live at 20:28Z on 2026-08-27 (deploy log
`scratch/deploy-2026-08-27/DEPLOY-LOG.md`, "INCIDENT 20:28Z").

## 3. Design (lead calls — follow, do not re-derive)

**L1. One host-local, deploy-generated file holds the binary facts.**
`scripts/deploy-marine.sh` (meta repo — the LEAD edits this, not the agents) computes
`sha256sum` of the five installed programs (`ww3_grid`, `ww3_prep`, `ww3_bound`,
`ww3_shel`, `ww3_outp`) in `/var/lib/weewx-clearskies/ww3/bin` on every deploy and writes
`/etc/weewx-clearskies/marine/ww3-binaries.json` (owner ubuntu, mode 0640):

```json
{
  "generated_by": "scripts/deploy-marine.sh",
  "generated_at": "2026-08-27T21:40:00Z",
  "binary_dir": "/var/lib/weewx-clearskies/ww3/bin",
  "binary_sha256": {
    "ww3_bound": "<hex>", "ww3_grid": "<hex>", "ww3_outp": "<hex>",
    "ww3_prep": "<hex>", "ww3_shel": "<hex>"
  }
}
```
The pushed config never writes this file; `persist_config()` never touches it. A missing
program is a deploy-time hard failure (same standing as the SWAN binary prerequisite check
at the top of the script).

**L2. The marine config loader overlays the file on the pushed `ww3` block.**
In `weewx_clearskies_marine/config/__init__.py` add:

- `WW3_BINARIES_FILENAME = "ww3-binaries.json"`
- `ww3_binaries_path() -> Path` — `_active_config_path.parent / WW3_BINARIES_FILENAME`
  (a `--config` override moves it along with `marine.conf`; tests pass an explicit path).
- `load_ww3_binaries(path: Path | None = None) -> dict[str, Any] | None` — returns
  `{"binary_dir": str, "binary_sha256": {str: str}}` when the file exists and is valid
  (a JSON object; `binary_dir` a non-empty string; `binary_sha256` an object whose values
  are strings). Missing file → `None` silently (a dev box, a host without WW3). Present
  but unreadable/invalid → log ERROR naming the path and the reason, return `None`.
  Never raises.

In `weewx_clearskies_marine/config/marine_config.py`, `load_ww3_config(config,
binaries_path: Path | None = None)`: after `_as_dict(config.get("ww3", {}))`, call
`load_ww3_binaries(binaries_path)`; when it returns a dict, REPLACE the section's
`binary_dir` and `binary_sha256` with the file's values (host facts win — a pushed value
is at best a stale copy). Every other `ww3` key (timeouts, `vchain_buoys`,
`vchain_ledger_retention_days`, `work_root`, …) still comes from the pushed section
exactly as today. `load_marine_config()` keeps calling `load_ww3_config(config)` with no
second argument — production resolves the path from the active config path. When the file
is absent, behaviour is byte-identical to today (pushed block, or empty → run-time refusal
`ww3_binaries_invalid` as before). `Ww3Config.validate()` is unchanged: still no
filesystem checks at parse time; the runner's `_verify_binaries()` remains the only place
the binaries themselves are hashed.

**L3. One startup log line, nothing in `/health`.** In `weewx_clearskies_marine/__main__.py`
right after `marine_config.load_config(config_path)` (line 203): call
`load_ww3_binaries()` once and log INFO
`"WW3 binary pins: %d program(s) from %s (binary_dir=%s)"` when present, or WARNING
`"WW3 binary pins file absent at %s -- the WW3 leg refuses ww3_binaries_invalid unless the pushed config carries pins"`
when not. No new health field, no new endpoint, no new env var, no API change.

**L4. Not in scope.** The API payload builder stays as it is (the API host cannot hash
files that live on librewxr). No change to `WW3Runner`, `_verify_binaries()`, the deck
grammar, or the rebuild hook. The hand-placed `ww3.binary_dir/binary_sha256` values in the
live `marine.conf` become redundant; they are left alone (the next push removes them).

## 4. Scope (in / out)

### j24-test (clearskies-test-author) — goes FIRST, on the pinned base marine `d7d8632`
- Creates: `tests/test_j24_ww3_binaries_file.py` (marine repo). Nothing else.
- Does NOT touch: any file under `weewx_clearskies_marine/`, any other test, `scripts/`,
  docs. Writes only under `tmp_path`.
- Guards (each must FAIL on the pre-change base — paste the real transcript into the
  module docstring per rules/verification.md; `load_ww3_binaries`/`ww3_binaries_path` do
  not exist pre-change, so an ImportError transcript is the honest pre-change evidence):
  1. `load_ww3_binaries(tmp_path/"ww3-binaries.json")` on a valid file returns exactly
     `binary_dir` + `binary_sha256` (extra keys such as `generated_at` are NOT returned).
  2. Missing file → `None`, no ERROR log record. Malformed JSON, a JSON list, a missing
     `binary_dir`, a non-object `binary_sha256` → `None` AND one ERROR record naming the
     path (use `caplog`).
  3. **The production failure, pinned:** `load_ww3_config({}, binaries_path=<valid file>)`
     (a pushed config with NO `ww3` block) yields `binary_dir`/`binary_sha256` equal to the
     file's.
  4. **File wins over pushed values:** a pushed `ww3` block with different `binary_dir`
     and pins + the file → the file's values; the pushed block's `march_timeout_s`,
     `vchain_ledger_retention_days` and `vchain_buoys` survive untouched.
  5. **Absent file leaves the pushed block untouched:** `load_ww3_config({"ww3": {...}},
     binaries_path=tmp_path/"nope.json")` returns the pushed values exactly.
  6. **End to end through persistence:** `persist_config(payload_without_ww3,
     path=tmp_path/"marine.conf")` (which sets the active path), write
     `tmp_path/"ww3-binaries.json"`, then `load_marine_config(get_loaded_config()).ww3`
     carries the file's pins (call `reset_config_for_tests()` in a fixture; never touch
     the real `/etc` path). `ww3_binaries_path()` after that `persist_config` equals
     `tmp_path/"ww3-binaries.json"`.
- Verification command (run from `repos/weewx-clearskies-marine`):
  `.venv_local/Scripts/python.exe -m pytest tests/test_j24_ww3_binaries_file.py tests/test_config.py tests/test_vchain_module.py -q -p no:cacheprovider`
  — expected: the new file FAILS pre-change (transcript captured), then after j24-dev
  lands: all pass, `test_config.py` / `test_vchain_module.py` unchanged counts.
- Deliverable: one commit on the marine repo adding the test file, with the pre-change
  transcript in its docstring.

### j24-dev (clearskies-api-dev, MARINE repo) — starts only when the lead says go
- Modifies: `weewx_clearskies_marine/config/__init__.py`,
  `weewx_clearskies_marine/config/marine_config.py` (only `load_ww3_config` and the
  `Ww3Config` docstring's "Config keys" note), `weewx_clearskies_marine/__main__.py`
  (the one log line), `CHANGELOG.md` ("### Fixed" entry), `docs/CONFIG.md` in the marine
  repo IF it documents the `[ww3]` block (grep first; add the file's role if it does).
- Does NOT touch: tests (j24-test owns them), `services/ww3_runner.py`, `service.py`,
  anything under `scripts/` (meta repo), any file on any container.
- Verification command (from `repos/weewx-clearskies-marine`):
  `.venv_local/Scripts/python.exe -m pytest tests/test_j24_ww3_binaries_file.py tests/test_config.py tests/test_vchain_module.py tests/services/test_ww3_runner.py -q -p no:cacheprovider`
  — expected all pass; plus `ruff check weewx_clearskies_marine/config weewx_clearskies_marine/__main__.py`.
- Deliverable: one commit on the marine repo; the four test files green at that HEAD.

## 5. Reading list (read BEFORE writing anything)

1. `weewx_clearskies_marine/config/__init__.py` — whole file (203 lines): `_active_config_path`,
   `load_config()`, `persist_config()`, `reset_config_for_tests()`.
2. `weewx_clearskies_marine/config/marine_config.py` lines 365–541 (`Ww3Config`) and
   1684–1697 (`load_ww3_config`); `load_marine_config` at 1535 for how it is called.
3. `weewx_clearskies_marine/services/ww3_runner.py` lines 120–160 (`WW3RunnerConfig`
   fields) and 352–400 (`_verify_binaries`) — what consumes the pins.
4. `weewx_clearskies_marine/__main__.py` lines 195–225 — the startup load site.
5. `tests/test_vchain_module.py` — the existing `load_ww3_config` call pattern (grep for it).
6. `scratch/deploy-2026-08-27/DEPLOY-LOG.md` — "INCIDENT 20:28Z" paragraph only.
7. `rules/coding.md` §1 (no silent substitution; persisted data).

## 6. Pre-round verification (lead)

- Marine HEAD `d7d8632`, clean. Meta HEAD `5172c0b5`, clean (2026-08-27 ~21:40Z).
- Live host facts: `/var/lib/weewx-clearskies/ww3/bin/` holds exactly the five programs
  (ubuntu-owned, 2026-08-18); the live `marine.conf` `ww3` block currently carries the
  restored pins (ww3_grid `c37f237f…`), which this round makes redundant.
- The 18Z rebuild + cold-start leg completed at 21:32Z on marine `d7d8632` (health
  `ww3.status ok`), so this round does not race a running leg's config read.

## 7. Open questions

None — surface anything not covered by §3 via SendMessage to the lead before acting.

## Mandatory blocks (verbatim, rules/agents.md)

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

> **Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own authority. A behavior change and its test updates land in the same commit, per your task's design; a test you were not told to touch that fails against your change is a finding. Your closeout report must list every test you modified or deleted, with the reason, and every guard, invariant, or viability check that fired during your work — including ones you believe are unrelated or pre-existing.

> **Architectural changes — STOP, do not proceed.** You may not make an architectural change. If your task requires one, STOP and report via SendMessage — do not implement it, do not work around it, do not pick an option.
>
> A change is architectural if it does ANY of these (mechanical test, not judgment):
> 1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or criterion inside one. **This does NOT cover changing how the same equation is solved** — iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the first is architectural. An approximation that does not converge to the original equation IS a formula change and is covered.
> 2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
> 3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
> 4. Changes a data contract between components — field names, shapes, nullability, units crossing a boundary.
> 5. Changes where a computation happens — host, service, process, or lifecycle stage.
> 6. Changes a schedule, trigger, or cadence.
> 7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
>
> **These do NOT authorize you:** "my task's acceptance criteria are unreachable without it" (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a finding to report, not permission to change code).
>
> You MAY still: resolve a contradiction between two statements inside the same document by taking the reading its own examples support (and say so); apply a rule already written in the rules files; fix code that diverges from its own stated contract.
>
> **The coordinator's ruling on your report is FINAL.** You surface an architectural concern ONCE, via SendMessage, then comply with the coordinator's answer. If the coordinator states that operator approval exists, that statement is your full authorization — verifying the approval chain is the coordinator's responsibility and the coordinator's alone. Do not refuse a second time, do not demand to see the paper trail, do not audit the coordinator's authority. (Operator ruling 2026-08-05.)

**Ruling already given for this round:** the new persisted file `ww3-binaries.json` and the
`load_ww3_config` overlay are operator-approved (§1). Do not re-surface them.

Other standing constraints: never run the full pytest suite; never move/delete files outside
your allowlist (including files your tests produce); SSH to containers is read-only and NOT
needed for this round; scratch files go in `scratch/`, never AppData; no secrets in code or
logs; never use AskUserQuestion; plain English in reports.
