# Round brief — Marine Service Separation Plan, Phase 4A task T4A.3

**Round:** MARINE-SEP-P4A-A4 (CUDEM at apply time + depth-contour grid sizing)
**Date:** 2026-07-24
**Lead (coordinator):** Opus
**Implementation agent:** `clearskies-api-dev` (Sonnet)
**Auditor:** `clearskies-auditor` (Sonnet) — adversarial audit, mandatory, no deferral

---

## 1. Round identity and mandate

You are implementing **T4A.3 — Move CUDEM download to apply time** of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`.

This is the largest task in Phase 4A. It moves an existing, working chain from
SWAN runtime to operator-apply time, and fixes two grid-sizing bugs on the way
(L2's hardcoded 6 km, L3's 2.5 km fallback).

**NO DEFERRAL RULE applies.** Read §"NO DEFERRAL RULE" at the top of the plan.
Every one of T4A.3's 11 Do steps and 10 Accept bullets must be completed. If you
cannot complete one, STOP and report via SendMessage — do not narrow scope, do
not leave a TODO, do not stub, do not "handle in a follow-up".

**T4A.2 has landed before you.** Its `interpolate_profile_pchip()` in
`enrichment/bathymetry.py` is the function T4A.3 step 6 calls. Read its actual
implemented signature and docstring in the repo — do not assume.

---

## 2. Reading list — read these BEFORE writing any code

Read the original text. This brief deliberately does not restate their content.

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`:
   - §0.1 Execution context, §0.3 (git restrictions), §0.4 (scratch discipline)
   - §"Phase 4A" Purpose and the 7-item Origin list
   - **§T4A.3 in full** — the Problem paragraph, the "What changes" paragraph, the
     "Critical constraint" paragraph, the "Current state of grid sizing (verified
     2026-07-23)" block, the **10-step correct-dependency-chain diagram**, all 11
     Do steps, and all 10 Accept bullets. This is your specification. The chain
     diagram is normative, not illustrative — implement that order.
   - **§T4A.2 in full** — you are the caller of the function it created.
   - §"Adversarial Audit — Phase 4A" items 6 and 7, and §"QC Gate 4A".
2. `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md` — §6 (datum consistency — the
   vertical-datum metadata T4A.3 step 8 requires) and §6.1.
3. `docs/planning/briefs/BATHYMETRY-RESOLUTION-BRIEF.md` — read it in full.
   It is the research basis for the per-level resolution tiers in Do step 2.
4. `docs/planning/briefs/SWAN-DATUM-CONSISTENCY-BRIEF.md` — the datum rules your
   stored profile metadata must satisfy.
5. `docs/ARCHITECTURE.md` — the SWAN nearshore model callout (bathymetry cache
   paths, the DEM priority chain, the 3-level grid design) and the setup-endpoint
   table row for `/setup/apply`.
6. `docs/manuals/API-MANUAL.md` — §17 SwellTrack configuration and the
   `/setup/apply` contract.
7. `docs/manuals/OPERATIONS-MANUAL.md` — the config and filesystem sections
   (§11 filesystem permissions model in particular; you are writing new files
   under `/etc/weewx-clearskies/`).
8. `docs/manuals/PROVIDER-MANUAL.md` — §14.7 CUDEM.
9. `rules/coding.md` — §1 in full. Especially: "Expensive computed data must be
   persisted to disk — never volatile-only" (atomic temp+rename; this is exactly
   what you are building), "Clear Skies API — security constraints" #1 (never
   write outside `/etc/weewx-clearskies/` or `/tmp`) and #11 (never hardcode
   weewx operational parameters). Then §2, §3, §4.
10. `rules/clearskies-process.md` — **"Research-to-implementation discipline" in
    full.** Six rules there are directly load-bearing here and each one was
    written after a bug in this exact code path:
    - "Verify data coverage claims per-location before coding against them"
      (CUDEM 1/9 arc-second does not exist south of 36°N on the Pacific coast)
    - "Grid sizing must come from actual data, not illustrative estimates in
      briefs"
    - "All SWAN grid geometry is fixed at setup time — no runtime overrides"
      (`compute_domains()` computes L1/L2/L3 together, once; nothing may resize
      `cluster.grid` afterwards)
    - "Never silently fall back to 0.0 for datum conversion failure — fail
      explicitly"
    - "Silent skipping of configured inputs is a bug pattern"
    - "Agents do not make design decisions — they implement prescribed
      solutions" (fix the caller; do not add a workaround elsewhere in the
      pipeline)
11. Source files you are modifying — read each in full before editing:
    - `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_domain.py`
    - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py`
    - `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/bathymetry.py`
    - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py`
12. `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py` —
    `SurfSpotConfig` (Do step 11 adds `max_hs_m`) and the structure config shape
    (Do step 5 computes `structure_zone_depth` from it).
13. `repos/weewx-clearskies-api/weewx_clearskies_api/services/bathymetry_resolver.py`
    — the DEM priority chain Do step 2 relies on.
14. `repos/weewx-clearskies-api/weewx_clearskies_api/services/shelf_boundary.py`
    — `find_shelf_distance()`, the L1 sizing input (Do step 1).

---

## 3. Pre-round verification (performed by the lead, 2026-07-24)

Facts I verified directly in the code. Use them as your starting map; confirm
each yourself before relying on it, since T4A.2's commits landed after I looked.

- **`swan_domain.compute_domains()`** (line ~94) takes `spot_locations`,
  `structures`, `spot_l3_configs` and per-level resolution/margin/depth kwargs.
  It calls `_compute_level1` → `_compute_level2` → `_cluster_spots` →
  `_compute_level3_grid` per cluster. It already accepts
  `level2_offshore_depth_m=30.0` and `level3_offshore_depth_m=15.0`.
- **L2 bug confirmed:** `_compute_level2` (line ~269) accepts `offshore_depth_m`
  and then never uses it — line ~292 is `offshore_km = 6.0`, a hardcoded literal.
- **L3 bug confirmed:** `_compute_level3_grid` (line ~537) uses
  `offshore_distance_m / 1000.0 + 0.1` when a profile-derived distance is
  supplied, else falls back to `offshore_km = 2.5` at line ~582.
- **The runtime chain you are moving** lives in
  `providers/nearshore/swan.py`: `download_bidirectional_profile` is called at
  line ~1548-1551 inside `_run_all_spots_locked()`; `offshore_distance_m` is
  stuffed into `spot_locations_for_domains` at line ~1609; `compute_domains()` is
  called at line ~1612. **A second, near-duplicate copy of the same
  offshore-distance + `compute_domains()` logic exists at lines ~1952-1975** in
  the quick-update path. Both must be handled — a fix to only one leaves the
  quick-update path downloading CUDEM at runtime. Do not miss it.
- **`/setup/apply`** is `async def apply(body: ApplyRequest, request: Request)`
  at `endpoints/setup.py` line ~1861, decorated `@router.post("/apply", ...)`.
  The `[marine]` section is written by a helper around line ~1059 and the apply
  handler writes `[marine]` around line ~1357.
- **Cache paths in use today**, verified live on librewxr:
  `/etc/weewx-clearskies/swan_bathymetry_L1.json`, `_L2.json`,
  `_L3_0f38a4a3.json`, `_L3_a77270dd.json`, and
  `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json`.
  The HB spot profile is **2147 bytes, 50 points at ~49.8 m spacing** — the
  broken profile T4A.2/T4A.3 replace.
- `_PROFILE_CACHE_DIR = Path("/etc/weewx-clearskies/spot_profiles")` at
  `swan.py` line ~106.
- **Test baseline at `0d87b28`** (before T4A.2's commits), run on weewx:
  `pytest tests/test_bathymetry.py tests/test_surf_endpoint.py
  tests/test_surf_scorer.py tests/test_marine_endpoint.py --tb=no -q`
  → **3 failed, 95 passed**. Pre-existing failures you inherit and must not grow:
  `test_bathymetry.py::test_download_profile_mock`,
  `test_bathymetry.py::test_download_profile_mock_triggers_refinement`,
  `test_surf_scorer.py::test_perfect_conditions`. **Re-run this command at your
  actual starting HEAD** (T4A.2 will have moved it) and report your own baseline
  before you change anything.

---

## 4. Scope

### 4.1 Files to create or modify (exhaustive)

| File | What changes |
|---|---|
| **NEW** `weewx_clearskies_api/services/marine_setup.py` | The apply-time chain. See lead call **LC-3**. |
| `weewx_clearskies_api/services/swan_domain.py` | Fix `_compute_level2` (Do step 3) and `_compute_level3_grid` (Do step 4) to size from actual depth contours. |
| `weewx_clearskies_api/enrichment/bathymetry.py` | Native-resolution raw transect extraction (Do step 6) and depth-contour search (Do steps 3-4 support). **Coordinate carefully — T4A.2 just added `interpolate_profile_pchip()` here; do not disturb it.** |
| `weewx_clearskies_api/providers/nearshore/swan.py` | Remove CUDEM download + grid sizing from `_run_all_spots_locked()` **and from the quick-update path**; read pre-computed caches only; explicit ERROR + skip when caches are missing (Do step 9). |
| `weewx_clearskies_api/endpoints/setup.py` | `/setup/apply` invokes the chain (Do steps 1, 10). |
| `weewx_clearskies_api/config/marine_config.py` | Add `max_hs_m: float = 4.0` to `SurfSpotConfig` (Do step 11). |
| `weewx_clearskies_api/endpoints/` — apply-payload models | Only if `max_hs_m` must round-trip through `/setup/apply`. See lead call **LC-8** — read it before touching anything here. |
| `tests/test_swan_domain.py` (new if absent) | Contour-derived L2/L3 sizing tests. |
| `tests/test_marine_setup.py` (new) | Chain orchestration tests. |
| `tests/test_bathymetry.py` | Add tests for contour search / native extraction only. |

### 4.2 Files NOT to touch

- `weewx_clearskies_api/endpoints/surf.py` and `endpoints/beach_profile.py` —
  **T4A.4 and T4A.1 own these**, implemented by another agent in parallel with
  you. Touching them causes a conflict in the shared checkout.
- `weewx_clearskies_api/services/surf_1d_analytical.py` — T4A.2b's file; done.
- `providers/alerts/nws.py`, `services/surfbeat_strip_benchmark.py`
  (pre-existing dirty files).
- Anything in `repos/weewx-clearskies-dashboard/`,
  `repos/weewx-clearskies-swan-swelltrack/`, `repos/weewx-clearskies-stack/`,
  `repos/weewx-clearskies-marine/`.
- Any file in the meta repo (`docs/`, `rules/`, `reference/`) — the coordinator
  owns governing-doc updates this round. **Tell me in your closeout which
  documents your changes make stale** (I expect at minimum ARCHITECTURE.md's SWAN
  callout, API-MANUAL §17, and OPERATIONS-MANUAL's config section) and what
  specifically needs to change in each.
- **Any file on any container.** You are forbidden from editing files on weewx,
  weather-dev or librewxr by any mechanism. That includes "staging a file as data
  for a one-off script".

### 4.3 Verification commands

Report raw output for each.

```bash
# 1. Establish YOUR baseline at your starting HEAD, before any edit:
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-api
git log --oneline -1
# then the 4-file regression set (see §3) via whatever Python you have locally.

# 2. Your new + touched tests, after implementation.
# 3. The 4-file regression set again — must not have grown beyond your baseline.
```

Remote verification on weewx requires the lead to deploy first (the container
checkout is pinned and you cannot push). **Report that as the blocker** rather
than working around it; I will deploy and re-run as part of QC Gate 4A.

**Physical plausibility is the real acceptance test**, per
`rules/clearskies-process.md` "'Data is flowing' is not verification". Write a
throwaway script under `c:\tmp\` (never in the repo, never on a container) that
runs your contour search against the real HB coordinates and prints:
- the distance to the actual 30 m contour and to the actual 15 m contour, per
  spot bearing;
- the resulting L2 and L3 offshore extents, next to the old hardcoded 6.0 km and
  2.5 km for comparison;
- the resulting profile point count and per-zone dx.

Then sanity-check them and say what you checked. Huntington Beach sits on a
relatively gentle Southern California shelf; a 30 m contour reported at 200 m or
at 60 km offshore is a failure regardless of exit code. If you cannot reach the
NCEI service from your environment, say so and report which Accept bullets are
therefore unverified by you and need my verification.

### 4.4 Deliverable definition

- 3–6 commits on the local `main` branch, messages naming the task
  (`feat(T4A.3): …`, `fix(T4A.3): …`).
- `git status` clean apart from the two pre-existing dirty files.
- A SendMessage closeout walking **all 10 of T4A.3's Accept bullets** with
  evidence per bullet — file + function, or command + raw output. Plus the
  stale-documents list from §4.2. Assertion without evidence will be rejected.

---

## 5. Lead calls — decisions already made; implement them, do not re-derive

### LC-3 — The chain lives in one reusable, independently-invocable module

**This is the most important call in this brief.** T4A.3 triggers the chain from
`/setup/apply`, which runs on the **weewx** host. But SWAN runs on **librewxr**
and reads these caches *there*. Until the marine service exists (Phases 5-6, with
its `POST /config` push) there is no mechanism to distribute apply-time-generated
caches across hosts. Implementing the chain inline inside the apply handler would
therefore leave librewxr's SWAN with no caches at all, and — per Do step 9's
explicit-ERROR-and-skip — permanently broken.

**Implement:**
- A new module `weewx_clearskies_api/services/marine_setup.py` exposing a single
  orchestration entry point (name it `prepare_marine_caches`) that executes the
  entire 10-step chain from T4A.3's diagram.
- `/setup/apply` calls that function. The apply handler contains **orchestration
  only** — no CUDEM logic, no grid maths.
- The module is **also runnable standalone**: `python -m
  weewx_clearskies_api.services.marine_setup` with CLI args for config path and
  an optional spot-id filter. Give it a `--dry-run` that prints the computed
  contour distances, grid extents and profile stats without writing caches.
- It must be **importable and callable with no FastAPI request context**, no
  app state, and no HTTP dependencies. Phase 5 lifts this module into the marine
  service essentially unchanged — write it so that lift is a file move.

Do **not** add a runtime-download fallback. Do step 9's explicit ERROR + skip
stands, and `rules/clearskies-process.md` forbids silent degradation.

### LC-9 — Progress reporting must not block the apply response

Do step 1's "progress visible to the operator" and the Accept bullet "(progress
visible to operator)" collide with a real constraint: the full chain includes
three CUDEM download tiers and can take many minutes, while `/setup/apply` is a
request the wizard waits on, and the API restarts after apply.

**Implement:** run the chain in a background thread started by the apply handler,
and write structured progress to a status file under `/etc/weewx-clearskies/`
(e.g. `marine_setup_status.json`: current step, step index/total, per-step
started/completed timestamps, errors). The apply response returns immediately
with the job accepted. Do not add a new HTTP endpoint to poll it — that is an
architecture change and out of scope for this round; the status file is
sufficient for this phase and is what the coordinator will read to verify.
Log every step transition at INFO with the step name and elapsed time.

If the chain fails, the status file records the failing step and the error, and
the failure is logged at ERROR. The apply itself still succeeds (config was
written) — but SWAN will then correctly refuse to run per Do step 9. That is the
intended, visible behaviour, not a bug.

### LC-8 — `max_hs_m` round-trip: check the contract before you touch the models

Do step 11 adds `max_hs_m` to `SurfSpotConfig`. Whether it also needs to appear
in the `/setup/apply` payload models depends on whether it is operator-provided
or API-derived. Read `rules/clearskies-process.md` "Wizard ↔ API apply contract
sync" **and its two Why blocks** (the `marine_alert_radius_miles` 422 incident
and the `nwps_wfo` incident that silently discarded all marine config) before
deciding.

**My call:** `max_hs_m` is **operator-provided** (it is a per-spot wave-climate
setting with a 4.0 m default, not something the API can derive). So it belongs in
the apply payload's surf sub-block model with a matching default. But the wizard
does not send it yet, and the models use `extra="forbid"` in the *other*
direction — an optional field with a default is safe to add to the model without
a wizard change. **Add it to the model as optional-with-default; do not change
the wizard or stack repo** (out of scope, different repo, and the plan does not
assign it). Note in your closeout that the wizard/admin UI does not yet expose
`max_hs_m` so every spot will use 4.0 m until it does — I will decide whether
that becomes a follow-up task.

If reading the actual models contradicts my call, STOP and tell me — do not
guess your way through a 422.

### LC-10 — Contour search: per-spot bearing, max across spots, and fail loudly

Do steps 3, 4 and 7 together specify: search along **each spot's own** offshore
bearing (never an averaged bearing — a single averaged transect through a
submarine canyon mislocates the contour), take the **max** distance across spots
for the grid boundary, and use the finest DEM available for each contour's depth
range.

Two additions:
- **A contour that is not found within the search extent is an error, not a
  fallback.** Do not silently substitute 6.0 km or 2.5 km — deleting those
  literals is the entire point of Do steps 3 and 4. Raise with the spot id, the
  bearing, the target depth and the max depth actually reached.
- **Log every spot's contour result at INFO** (spot id, bearing, 30 m distance,
  15 m distance) and log explicitly which spot's distance won the `max()`.
  Per `rules/clearskies-process.md` "Silent skipping of configured inputs is a
  bug pattern", if any spot is skipped for any reason, that is a WARNING with the
  reason — never a silent omission.

### LC-11 — Do not resize `cluster.grid` after `compute_domains()` returns

`rules/clearskies-process.md` carries a rule written specifically after a Sonnet
agent broke this exact code path: *"All SWAN grid geometry is fixed at setup time
— no runtime overrides. No code may resize, reposition, or override
`cluster.grid` after `compute_domains()` returns. All inputs that affect grid
sizing (structures, depth profiles, spot positions) must be passed to
`compute_domains()` — not applied later."* The failure mode was L3 extending
beyond L2's NESTOUT coverage, producing 0.01 m Hs during a 6-8 ft swell with no
error.

Your chain computes contour distances **before** `compute_domains()` and passes
them in. If you find yourself wanting to adjust a grid after the fact, that is
the signal to fix the caller instead. If `compute_domains()`'s signature cannot
accept what you need, **change its signature** — do not add a post-hoc override.

### LC-12 — Both SWAN call sites, and cache-miss behaviour

`swan.py` has two places that build `spot_locations_for_domains` and call
`compute_domains()`: the full run in `_run_all_spots_locked()` (~line 1589-1612)
and the quick-update path (~line 1952-1975). Do step 9 must be applied to
**both**. Verify by grepping for `compute_domains` and `download_bidirectional_profile`
in that file after your change — the only remaining references should be reads of
pre-computed cache/metadata, or none at all.

Cache-miss behaviour, per Do step 9: log at **ERROR** with the missing path and
what the operator must do (run apply), then skip the run cleanly — do not raise
into the scheduler thread and do not partially run. Do not write a hotstart and
do not touch the forecast cache on a skipped run (the existing convergence-gate
code already models this behaviour — read it and be consistent).

### LC-42 — Finish the vocabulary rename in `swan.py`, WITH cache-key migration

**Added 2026-07-24, after T4A.1 landed.** T4A.1 unified the beach-profile
vocabulary to `distance` / `depth` / `hs` across both endpoints' **responses**.
One producer was left behind because it lives in *your* file:
`providers/nearshore/swan.py` (~line 1798) builds `transect_by_time` entries as
`{"distanceFromShore": …, "depth": …, "waveHeight": …}`.

Its consumers: `swan.py` itself (~1673 and ~2230, reading `prev_cache["transect"]`)
and `endpoints/surf.py` (~765, ~875, ~891, ~897).

I started this as a lead-direct fix and **reverted it before committing**, because
it is not mechanical: **these dicts are persisted in the SWAN forecast cache.**
Live cached data on weewx and librewxr uses the old spellings. Renaming the
producer without a migration path means every read of an existing cache entry
silently returns `None` — introducing the exact silent-degradation failure this
phase exists to remove, via the fix for it.

**Do:**
1. Rename the producer keys to `distance` / `depth` / `hs`.
2. Update every consumer listed above.
3. **Handle the migration explicitly.** Your call between: (a) readers accept
   both spellings for one cycle, with the legacy branch logged at INFO and a
   comment naming the release it can be deleted in; or (b) bump the cache key /
   version so stale entries are ignored and regenerated. **State which you chose
   and why in your closeout.** What is not acceptable is a rename with no
   migration story — that is the whole reason I reverted mine.
4. Verify afterwards: `grep -n "distanceFromShore\|waveHeight"
   weewx_clearskies_api/providers/nearshore/swan.py
   weewx_clearskies_api/endpoints/surf.py` — remaining hits must be only the
   `SwanForecastPoint` **attribute** reads (`getattr(pt, "distanceFromShore", …)`,
   SWAN's own object model, not part of this contract) and the legacy-read branch
   if you chose (a).

Note `_run_all_spots_locked()`'s `pt.waveHeight` attribute access and the
`CAPABILITY.supplied_canonical_fields` tuple containing `"waveHeight"` are
**different things** — canonical field names in the provider registry, unrelated
to the transect dict vocabulary. Do not touch either.

### LC-13 — Vertical datum metadata is mandatory and must not default to a guess

Do step 8 requires `vertical datum` in the per-spot profile metadata, citing
SURF-ZONE-MODEL-BRIEF §6. Per `rules/clearskies-process.md` "Never silently fall
back to 0.0 for datum conversion failure — fail explicitly" and "Match datums at
source rather than converting locally": the datum comes from the DEM that
actually supplied the data (via `bathymetry_resolver.py` / the NCEI regional DEM
index). If the resolver cannot report a datum for the DEM it used, write
`null` and **log a WARNING naming the DEM** — do not write `"MSL"` or any other
plausible-looking default. A wrong datum silently biases every depth in the
model.

---

## 6. Open questions — SendMessage the lead; do NOT resolve unilaterally

- If the HB location's finest available DEM is coarser than the ~10 m T4A.3
  assumes (CUDEM 1/9 arc-second does not exist south of 36°N on the Pacific
  coast — see `rules/clearskies-process.md`), report the actual resolution with
  evidence. That changes what "native DEM resolution" means for our test spot and
  I need to know before QC Gate 4A.
- If moving the chain out of `swan.py` requires changing `compute_domains()`'s
  signature in a way that breaks another caller, name the caller and stop.
- If `/setup/apply`'s existing structure makes LC-9's background-thread approach
  unworkable (e.g. the handler already restarts the service before the thread
  could run), describe the conflict — do not silently make the apply synchronous
  and slow.
- If the three download tiers in Do step 2 would exceed a rate limit or take
  implausibly long for the L1 area, report the estimated request count and
  runtime before implementing.
- Anything that would require touching a file in §4.2.

---

## 7. Git restrictions (MANDATORY)

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`,
> `git rebase`, `git merge`, or `git checkout` of remote branches. You may only
> `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is
> ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

> **Agents edit and commit ONLY on the local machine — HARD BAN on container
> edits.** All editing and committing happens at
> `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`. You must NEVER edit
> source files on weewx, weather-dev or librewxr, and never run any git write
> operation on any container. SSH to containers is READ-ONLY.

**Commit messages:** use `git commit -F c:\tmp\<name>-msg.txt` — PowerShell
heredocs break on parens and quotes.

**Scratch file:** append to `c:\tmp\marine-sep-P4A-scratch.md` after every commit
and every decision. Do not reconstruct it at the end.

---

## 8. Scope acknowledgment — required before any code

Before writing any code, SendMessage the lead with a one-paragraph scope
acknowledgment: what you will deliver, what you will NOT touch, your measured
starting baseline, and the exact verification commands you will run.
