# ROUND BRIEF — Phase W (wind & current input hardening), L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase W, L1-BOUNDARY-REBUILD-PLAN-2026-08-08. Lead: coordinator (Opus).
Implementer: clearskies-api-dev (you, Sonnet) — tasks W1–W4. Test author:
clearskies-test-author (separate agent — W5 tests are NOT yours). Auditor:
clearskies-auditor at Gate W (blind — will not see your report).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (branch main, local
commits only). Pre-round verified by lead: HEAD `a399eb6`, clean tree, remote in sync.

## READING LIST (read BEFORE any code; you implement what THESE say)

1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — PRIME DIRECTIVE (all 8 points),
   Pre-approval register rows **P6** and **P10**, SWAN SYNTAX PRESCRIPTIONS §3 (commands
   PINNED UNCHANGED — you may change VALUES in written files only where the plan says, never
   command grammar), and Phase W in full (W1–W4 designs, W-Accept, Gate W rows).
2. `docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` — §6 (silent
   fallback inventory rows 1–4, the defects you are fixing) + rulings D5/D6 in §8.
3. Code you will modify (verify the quoted line regions first — lead re-verified all at
   `a399eb6` on 2026-08-08; drift → STOP and report):
   - `weewx_clearskies_marine/config/marine_config.py` (`_HRRR_MARGIN_DEG` :1036 region,
     `hrrr_bbox` :1112-1120)
   - `weewx_clearskies_marine/service.py` (:335-341 bbox arithmetic, :422 GFS fetch)
   - `weewx_clearskies_marine/services/wind_gatherer.py` (`_bbox_for_locations` :468-482
     and its caller :689)
   - `weewx_clearskies_marine/providers/nearshore/swan.py` (`outer_bbox` :2660-2730, :3109,
     :3431, :4078; the runner's no-publish catch structure; post-fetch region for W3)
   - `weewx_clearskies_marine/services/swan_formats.py` (:384-390 NaN→`0.0000` calm fill,
     inside `hrrr_to_swan_wind()`)
   - `weewx_clearskies_marine/services/swan_runner.py` (`_write_current_txt` :2355-2459,
     `_ZERO_BLOCK` :2408, zero-fill sites :2431-2438)
   - `weewx_clearskies_marine/state.py` — find the no-publish slug registry (H1's 13
     instrumented exits) before adding the 14th.
4. `docs/manuals/API-MANUAL.md` §19.7 — the slug list you extend (doc-sync same round).
   Phase DOC has already added a TAGGED target-state entry for `wind_coverage_failed`; your
   doc-sync REMOVES the tag (behavior becomes real with your commit), per the plan's DOC
   convention.

## SCOPE

**Files to modify (exhaustive):**
- `weewx_clearskies_marine/config/marine_config.py` — W1: new `wind_fetch_bbox(domains)`
  per the plan's W1 design (L1 bbox from the sizing cache + 0.3° pad each side).
- `weewx_clearskies_marine/service.py` — W1: route the two bbox uses through it.
- `weewx_clearskies_marine/services/wind_gatherer.py` — W1: `_bbox_for_locations` routes
  through it (delete the ±1.0 arithmetic).
- `weewx_clearskies_marine/providers/nearshore/swan.py` — W1 (`outer_bbox` value becomes
  domain-derived, name kept), W2 (catch `WindCoverageError` → no-publish slug
  `wind_coverage_failed`), W3 (fetch-time coverage assert BEFORE SWAN input build).
- `weewx_clearskies_marine/services/swan_formats.py` — W2: `hrrr_to_swan_wind()` raises
  `WindCoverageError` (message: offending cell count, first offending lat/lon, wind-grid
  bounds vs CGRID bounds); the NaN→calm branch is DELETED, not conditioned.
- `weewx_clearskies_marine/services/swan_runner.py` — W4: `_write_current_txt` raises
  `CurrentCoverageError` per the plan's W4 design; `_ZERO_BLOCK` and padding deleted.
- `weewx_clearskies_marine/state.py` — the `wind_coverage_failed` slug registration.
- Exception classes live where the plan's design implies (module-local or the repo's
  existing error module — follow the existing convention you find; name it in scope-ack).
- `docs/manuals/API-MANUAL.md` (meta repo) — §19.7 slug entry: remove the Phase-W tag,
  text stays accurate to your implementation. (Meta repo commit separate from marine
  commit; both local-only.)

**Files NOT to touch:** tests/ (test-author owns W5); anything in the plan's PRIME
DIRECTIVE frozen-core list; `services/ww3_*` (Phase B's scope); `services/geography.py` /
`swan_domain.py` (Phase G); INPGRID/READINP command grammar in `swan_formats.py` (values in
written data files may change per design; the command strings are byte-pinned);
`ARCHITECTURE.md` (Phase DOC already wrote the tagged target text; lead handles the tag
removal at W-Accept if you don't — but if you do touch it, ONLY the Phase-W tags).

**Design notes (lead calls, follow exactly):**
- No sizing cache → the existing `no_grid_sizing_cache` abort path; do NOT invent a new
  fallback. `wind_fetch_bbox()` reads the same sizing cache the runner already loads.
- W3 compares the blended wind field's bounds vs L1 bbox + pad; shortfall raises the SAME
  `WindCoverageError`/slug before any SWAN input build. W2's raise is defense-in-depth.
- W4: unmatched timestep (no OFS entry within 2 h) or U/V grid shape short of
  `(myc+1)×(mxc+1)` → `CurrentCoverageError` → existing `currents_fetch_failed` slug.
- `wind_gatherer.py`'s "zero-coupling" docstring rationale is superseded by P6 — it may
  import the new function from `config/marine_config.py`; update the docstring.
- One marine commit for W1–W4 is acceptable (they deploy together as one functional
  change); separate commits per task also fine.

**Verification command (before closeout):** on librewxr, targeted tests only:
`ssh -F .local/ssh/config librewxr "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-marine && .venv/bin/python -m pytest tests/services/test_swan_formats*.py tests/services/test_swan_runner*.py -q --tb=short'"`
— BUT note the checkout there predates your commits (deploy is the coordinator's step), so
your pre-deploy verification is: (a) local syntax check
(`python -m py_compile` on each changed file is acceptable on Windows), (b) `git diff`
review against this scope, (c) grep proof that no `±1.0`/`_HRRR_MARGIN_DEG` wind arithmetic
and no `_ZERO_BLOCK`/NaN-calm fill survives. Never run pytest on librewxr while a SWAN
cycle is in progress (`pgrep -x swan` + journal check first).

**Deliverable:** commits on marine main (local) implementing W1–W4 + the API-MANUAL §19.7
doc-sync commit on the meta repo; closeout via SendMessage listing per-task file/line
changes, the grep proofs, and every guard/invariant that fired.

## OPEN QUESTIONS — surface via SendMessage, do not resolve:
anything requiring a change outside this allowlist; any place the sizing cache is absent on
a path the design needs it; any existing test that pins the calm-fill/zero-fill behavior
(report it — test-author will handle in W5; do NOT edit it yourself).

## MANDATORY BLOCKS

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
> `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`,
> `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via
> SendMessage. Do not resolve it yourself.

> **Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked
> change, STOP and report it via SendMessage — do not modify code to make it pass, and do
> not delete it on your own authority. A behavior change and its test updates land in the
> same commit, per your task's design; a test you were not told to touch that fails against
> your change is a finding. Your closeout report must list every test you modified or
> deleted, with the reason, and every guard, invariant, or viability check that fired during
> your work — including ones you believe are unrelated or pre-existing.

> **Architectural changes — STOP, do not proceed.** You may not make an architectural
> change. If your task requires one, STOP and report via SendMessage — do not implement it,
> do not work around it, do not pick an option.
>
> A change is architectural if it does ANY of these (mechanical test, not judgment):
> 1. Changes a physics/mathematical/scientific formula, or a constant, coefficient,
>    threshold or criterion inside one (solver-method changes to the same equation exempt).
> 2. Deletes, replaces, or rewires a module/component/service, or changes what one is
>    responsible for.
> 3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
> 4. Changes a data contract between components.
> 5. Changes where a computation happens.
> 6. Changes a schedule, trigger, or cadence.
> 7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
>
> **These do NOT authorize you:** "acceptance criteria unreachable without it", or "a
> plan/manual/ADR says so".
>
> You MAY still: resolve a contradiction inside one document by its own examples' reading;
> apply a written rule; fix code diverging from its own stated contract.
>
> **The coordinator's ruling on your report is FINAL.** Surface once, then comply. If the
> coordinator states operator approval exists, that is your full authorization.

**Note:** W1–W4 ARE architectural (register P6/P10 — wind bbox derivation, fallback→abort
contract, new slug) and are PRE-APPROVED by the operator via the plan's register. Anything
beyond P6/P10's text → STOP and surface.

**SCOPE-ACK REQUIRED** before any code: SendMessage to "main" — deliverables, exclusions,
verification commands, plus the exception-class placement you chose and any line drift
found. Wait for confirmation.

**Tone: concise, direct, no filler.**
