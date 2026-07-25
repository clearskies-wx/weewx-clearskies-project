# Round brief — Marine Service Separation Plan, Phase 4A tasks T4A.2 + T4A.2b

**Round:** MARINE-SEP-P4A-A1 (SwellTrack physics)
**Date:** 2026-07-24
**Lead (coordinator):** Opus
**Implementation agent:** `clearskies-api-dev` (Sonnet)
**Auditor:** `clearskies-auditor` (Sonnet) — adversarial audit, mandatory, no deferral

---

## 1. Round identity and mandate

You are implementing **T4A.2 (PCHIP variable-resolution profile generation)** and
**T4A.2b (Battjes-Janssen forward-marching energy integration)** of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`.

**NO DEFERRAL RULE applies.** Read §"NO DEFERRAL RULE" at the top of the plan.
If you cannot complete a task, STOP and report via SendMessage. Do not narrow
scope silently, do not leave a TODO, do not stub.

This is the task that makes the SwellTrack 1D model produce non-zero output for
the first time in production. Everything downstream in Phase 4A depends on it.

---

## 2. Reading list — read these BEFORE writing any code

Read the original text. This brief deliberately does not restate their content.

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`:
   - §0.1 Execution context, §0.3 (git restrictions), §0.4 (scratch discipline)
   - §"Phase 4A — Fix SwellTrack Pipeline + Vocabulary Unification" — the whole
     Purpose and Origin block (7 numbered failures), so you understand where your
     two tasks sit in the chain.
   - **§T4A.2 in full** — every Do step and every Accept bullet. This is your spec.
   - **§T4A.2b in full** — every Do step and every Accept bullet.
   - §T4A.3 — read it even though it is not yours. Another agent implements it
     immediately after you, and it *calls* the function you are writing in T4A.2.
     Your function signature must be what T4A.3 expects.
   - §"Adversarial Audit — Phase 4A" and §"QC Gate 4A" — what you will be checked
     against.
2. `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md` — **§6 Required Inputs (datum
   consistency)** and **§6.1 Variable-resolution 1D grid** in full. §6.1 is the
   research basis for T4A.2: the depth-based zone table, the PCHIP rationale, the
   XBeach dx ≤ 2m finding, and the caching model. **Note:** §6.1's
   `fine_zone_max_depth` formula predates the plan's and lacks the 1.3 shoaling
   margin — see lead call **LC-1** below; the plan wins.
3. `docs/manuals/API-MANUAL.md` — §17 SwellTrack configuration.
4. `docs/manuals/PROVIDER-MANUAL.md` — §14.7 (CUDEM bathymetry attribution and
   the data-source priority chain).
5. `rules/coding.md` — §1 (especially "Expensive computed data must be persisted
   to disk", "Treat your own output as untrusted", "Validate inputs at trust
   boundaries"), §2, §3 (single responsibility, no mega-files, DRY — search
   before writing a new helper), §4.
6. `rules/clearskies-process.md` — the "Research-to-implementation discipline"
   section in full. Several rules there are directly load-bearing for this task:
   "Verify data coverage claims per-location before coding against them",
   "Never silently fall back to 0.0 for datum conversion failure — fail
   explicitly", "Grid sizing must come from actual data, not illustrative
   estimates in briefs", "Agents do not make design decisions — they implement
   prescribed solutions", and "'Data is flowing' is not verification — check
   physical plausibility".
7. Source files you are modifying — read each in full before editing:
   - `repos/weewx-clearskies-api/weewx_clearskies_api/services/surf_1d_analytical.py`
   - `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/bathymetry.py`
8. Callers you must not break — read enough to understand the contract:
   - `repos/weewx-clearskies-api/weewx_clearskies_api/services/surf_1d_pipeline.py`
   - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/beach_profile.py`
     (the `run_1d_analytical` call site)
9. Existing tests you must keep green:
   - `repos/weewx-clearskies-api/tests/test_bathymetry.py`

---

## 3. Pre-round verification (performed by the lead, 2026-07-24)

- API repo HEAD `0d87b28`, equal to `origin/main`. Working tree clean except two
  pre-existing, unrelated deltas carried since Phase 1: a one-line comment change
  in `providers/alerts/nws.py` and an untracked
  `services/surfbeat_strip_benchmark.py`. **Do not touch either.**
- **Test baseline at `0d87b28`, run on weewx:**
  ```
  .venv/bin/python -m pytest tests/test_bathymetry.py tests/test_surf_endpoint.py \
      tests/test_surf_scorer.py tests/test_marine_endpoint.py --tb=no -q
  → 3 failed, 95 passed
  ```
  Pre-existing failures you inherit (must not grow, must not be "fixed" by
  changing the tests):
  1. `test_bathymetry.py::test_download_profile_mock`
  2. `test_bathymetry.py::test_download_profile_mock_triggers_refinement`
  3. `test_surf_scorer.py::test_perfect_conditions`
- **Problem state confirmed live by the lead**, not assumed:
  `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` on both
  weewx and librewxr is 2147 bytes containing 50 points at ~49.8 m spacing
  (`0.0, 49.8, 99.6, 149.4, …`). The 50-point/50m profile in T4A.2's problem
  statement is real and current.
- The current surf endpoint returns `degraded: true`, `bestPeakFaceHeight: null`,
  `breakPoints: null`, `openTransectCount: 0` of 32 transects — i.e. SwellTrack
  is producing nothing, exactly as T4A.2 describes.
- **Architecture context the plan does not state:**
  `repos/weewx-clearskies-swan-swelltrack` is a 322-line thin wrapper that
  `import`s `weewx_clearskies_api.providers.nearshore.swan`,
  `...config.marine_config`, `...providers.wind.hrrr` and friends. All physics
  lives in the API repo. Your changes to `surf_1d_analytical.py` and
  `bathymetry.py` therefore run on librewxr too, via its API-repo checkout.
  **Do not modify the SWAN service repo.**

---

## 4. Scope

### 4.1 Files to create or modify (exhaustive)

| File | What changes |
|---|---|
| `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/bathymetry.py` | Add `interpolate_profile_pchip()` per T4A.2. Do not change existing download/refinement logic in this round — T4A.3 owns the download restructuring. |
| `repos/weewx-clearskies-api/weewx_clearskies_api/services/surf_1d_analytical.py` | Rewrite `_battjes_janssen()` per T4A.2b + LC-2. |
| `repos/weewx-clearskies-api/pyproject.toml` | Only if `scipy` is not already a dependency — `PchipInterpolator` comes from `scipy.interpolate`. Verify first; do not add a duplicate pin. |
| `repos/weewx-clearskies-api/tests/test_surf_1d_analytical.py` | **New file.** See §4.2 — you own these specific tests. |
| `repos/weewx-clearskies-api/tests/test_bathymetry.py` | Add tests for `interpolate_profile_pchip()` only. Do not modify or "fix" the 2 pre-existing failing tests. |

### 4.2 Files NOT to touch

- `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py`,
  `services/swan_domain.py`, `providers/nearshore/swan.py` — **T4A.3 owns these**,
  implemented by a different agent right after you. Touching them creates a
  merge conflict in a shared checkout.
- `endpoints/surf.py`, `endpoints/beach_profile.py` — **T4A.4 and T4A.1 own these.**
- Anything in `repos/weewx-clearskies-dashboard/`,
  `repos/weewx-clearskies-swan-swelltrack/`, `repos/weewx-clearskies-stack/`,
  `repos/weewx-clearskies-marine/`.
- `providers/alerts/nws.py` and `services/surfbeat_strip_benchmark.py` (the
  pre-existing dirty files).
- Any file in the meta repo (`docs/`, `rules/`, `reference/`) — the coordinator
  owns governing-doc updates this round, including the SURF-ZONE-MODEL-BRIEF §6.1
  formula correction.
- **Any file on any container.** You are forbidden from editing files on weewx,
  weather-dev, or librewxr by any mechanism.

**Test ownership exception:** normally `clearskies-test-author` owns tests. For
this round the lead assigns you the two test files above, because the acceptance
criteria for T4A.2 and T4A.2b are numerical physics assertions that cannot be
written without the implementation in hand. Write them as real tests, not
tautologies that assert whatever your code happens to produce.

### 4.3 Verification commands

Run on **weewx** (read-only remote execution — running tests is permitted;
editing is not). You must run all three and report raw output:

```bash
# 1. Your new + touched tests
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && \
  .venv/bin/python -m pytest tests/test_surf_1d_analytical.py tests/test_bathymetry.py --tb=short -q"

# 2. Regression against the baseline set
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && \
  .venv/bin/python -m pytest tests/test_bathymetry.py tests/test_surf_endpoint.py \
  tests/test_surf_scorer.py tests/test_marine_endpoint.py --tb=no -q"
```

**Important:** the checkout on weewx is at `0d87b28` and you cannot push or pull.
To exercise your code on weewx you must either (a) run the tests against a copy
of your changed files that you place under `c:\tmp\` and transfer as *data* for a
one-off script, or (b) report that remote verification requires the lead to
deploy first. **Option (b) is acceptable and expected** — say so explicitly
rather than inventing a workaround that edits the container. The lead will deploy
and re-run.

What you **must** verify locally without a container, and report:

```
# 3. Physical-plausibility check — the real acceptance test for this round.
#    Write a throwaway script under c:\tmp\ (NOT in the repo) that:
#      a) loads the REAL 50-point HB profile shape (reproduce the distances and
#         depths from the values in this brief's §3, or from the plan)
#      b) runs interpolate_profile_pchip() on it
#      c) runs run_1d_analytical(hs=1.0, tp=10.3, direction=..., profile) on BOTH
#         the raw 50-point profile and the interpolated profile
#      d) prints: point count, per-zone dx min/max, break point count, break
#         point depths, face heights, and the full Hs envelope for both
```
Report the actual printed numbers. T4A.2's Accept bullet requires
"`run_1d_analytical()` with the interpolated profile finds ≥1 break point with
non-zero face height for 1.0m Hs / 10.3s Tp input" — that is a number you must
show me, not a claim you make.

Per `rules/clearskies-process.md`: **"'Data is flowing' is not verification —
check physical plausibility."** A break point at 40 m depth, or a face height of
50 m, or an Hs envelope that increases monotonically to shore, is a failure even
if no exception was raised. Sanity-check your own output and say what you checked.

### 4.4 Deliverable definition

What the lead expects in `git log` on `repos/weewx-clearskies-api`:

- 2–4 commits on the local `main` branch, messages naming the tasks
  (`feat(T4A.2): …`, `fix(T4A.2b): …`).
- `git status` clean at the end apart from the two pre-existing dirty files.
- A SendMessage closeout that walks **every Accept bullet of T4A.2 and every
  Accept bullet of T4A.2b** and gives, per bullet, the evidence: the file and
  function, or the command and its raw output. Assertion without evidence will be
  rejected and sent back.

---

## 5. Lead calls — decisions already made; implement them, do not re-derive

### LC-1 — `fine_zone_max_depth` uses `max()`, not addition

The plan's T4A.2 step 4 code block is internally inconsistent with the two worked
examples directly beneath it, with T4A.2's own Accept bullet, and with QC Gate 4A.
The block writes `1.3 * max_hs_m / gamma + structure_zone_depth`; everything else
writes `max(1.3 * max_hs_m / gamma, structure_zone_depth)`. The Newport example
(`max(7.1, 10.0) = 10.0`) is decisive — addition would give 17.1 m.

**Implement:**
```
fine_zone_max_depth = max(1.3 * max_hs_m / gamma, structure_zone_depth)
```
Reason: the two terms are independently-derived depths for the same zone, not
additive contributions. The coordinator is correcting the plan text and
`SURF-ZONE-MODEL-BRIEF.md` §6.1 separately — do not edit those docs yourself.

### LC-2 — `_battjes_janssen()` must march the energy FLUX, not re-seed each step

This is the most important call in this brief. Read it carefully.

T4A.2b's pseudocode sketches `E_in = 0.125*rho*g*Hs[i]**2  # Hs[i] has shoaling
applied`. Implemented literally, that reads the *input* array at every step —
which is the same independence bug the task exists to fix, just written as a loop.

Verified current code path in `run_1d_analytical()` (lines ~455-484):
`L`/`Cg`/`C` from dispersion → `Ks = sqrt(Cg0/Cg)` → `Kr` from Snell →
`Hs = hs * Ks * Kr` → optional `_bottom_friction` → `_battjes_janssen` →
`_roller_model` → `np.minimum(Hs, gamma*depths)`.

So shoaling and refraction are **already baked into the array handed to
`_battjes_janssen`**. A naive forward march that propagates `Hs[i-1]` forward
destroys them and the model collapses.

**Implement conservative energy-flux marching.** `F = E · Cg` is the conserved
quantity in the absence of dissipation:

```
eps = small positive guard (match the existing 0.01 guards in this module)

E0    = 0.125 * rho * g * Hs_in[0]**2
F[0]  = E0 * Cg[0]
Hs[0] = Hs_in[0]                    # boundary condition unchanged

for i in 1 .. n-1:
    # Predicted height at i from the flux arriving from i-1.
    # Shoaling emerges from the Cg gradient; refraction from the Kr increment.
    E_pred  = F[i-1] / max(Cg[i], eps)
    Hs_pred = sqrt(8 * E_pred / (rho * g)) * (Kr[i] / max(Kr[i-1], eps))

    # Battjes-Janssen dissipation evaluated at this point, on the predicted
    # height — same Hmax / Qb / Dtot formulation already in the function.
    Hmax = gamma * d[i]
    Qb, Dtot = <existing formulation, using Hs_pred instead of Hs_in[i]>

    F[i]  = max(F[i-1] * (Kr[i]/max(Kr[i-1],eps))**2 - Dtot * abs(dx[i]), 0.0)
    Hs[i] = sqrt(8 * (F[i] / max(Cg[i], eps)) / (rho * g))
```

Consequences you must handle:
- `_battjes_janssen()` now needs `Kr` and the un-refracted boundary condition.
  **Change its signature** and update the single call site in
  `run_1d_analytical()`. Pass `Kr` in. Do not recompute Snell inside the function
  — `run_1d_analytical` already has it (DRY, `rules/coding.md` §3).
- `Hs_in` passed to `_battjes_janssen` still carries `Ks*Kr` (and friction).
  Only element `[0]` of it is used as the boundary condition; the interior is
  regenerated by the march. Make that explicit in a comment (WHY, not WHAT).
- Do **not** change `_bottom_friction()`, `_roller_model()`, `_find_break_points()`,
  the `np.minimum(Hs, gamma*depths)` cap, or the shoaling/refraction computation.
  T4A.2b's Accept bullet "Break points at the same locations as before (gamma×d
  crossing unchanged)" depends on that cap and that detector staying put.
- Vectorise if you can do so without reintroducing independence, but a plain
  Python loop is acceptable here — `_roller_model()` already uses one, and
  profiles are a few hundred points.

**Mandatory regression invariant — this is a required deliverable, not optional.**
Add a test proving shoaling survived: run the marching function on a monotonic
profile with breaking suppressed (choose `gamma` large enough that
`Hs < gamma·d` everywhere, and friction off) and assert the output matches
`hs * Ks * Kr` to within 1e-6 relative at every point. If that test does not pass,
your implementation is wrong regardless of what the break-point counts look like.

Also add, per T4A.2b's Accept bullets:
- a multi-bar profile test showing Hs **recovers** in the trough between bars
  (reformation) — assert `Hs[trough] > Hs[bar_crest]` shoreward of the first break.
- a test that post-breaking Hs is **not** identical to `gamma * depth` through the
  surf zone (the degenerate behaviour T4A.2b exists to fix). Assert a meaningful
  fraction of post-break points differ from `gamma*d` by more than a small
  tolerance.
- a dx-sensitivity test: the same physical profile sampled at 2 m and at 5 m must
  produce break points within a few metres of each other and face heights within
  a modest tolerance. Under the old code this test would fail badly; that is the
  point.

### LC-3 — PCHIP specifics

- Use `scipy.interpolate.PchipInterpolator`. **Check `pyproject.toml` first** —
  `scipy` may already be a dependency (`ellipk`/`ellipj` are imported from
  `scipy.special` in `surf_1d_analytical.py`, so it almost certainly is). Do not
  add a duplicate or conflicting pin.
- T4A.2 step 2 requires de-duplicating x-values before fitting. Verified cause:
  the adaptive-refinement path in `bathymetry.py` can emit near-duplicate
  `distance_m` values. De-duplicate on a tolerance, not on exact equality, and
  keep the shallower/first occurrence deterministically. `PchipInterpolator`
  raises on non-strictly-increasing x — a silent `try/except` around it is a
  defect, not a fix.
- `interpolate_profile_pchip()` is a pure function: raw profile in, variable-
  resolution profile out. It does **not** download, does **not** write files, does
  **not** read config. T4A.3's caller owns I/O. Keep it that way — Phase 5 lifts
  this function into the marine service.
- Signature is fixed by the plan:
  `interpolate_profile_pchip(raw_profile, max_hs_m, gamma, structure_zone_depth=0.0) -> list[dict]`
  Do not change it; T4A.3's agent is coding against it.
- Return dicts with the same `{"distance_m": float, "depth_m": float}` keys the
  existing spot-profile cache uses, so the on-disk format is unchanged and
  existing readers keep working. (The `distance`/`depth`/`hs` renaming in T4A.1
  applies to the **HTTP response**, not to this internal profile cache. Do not
  conflate them.)
- Return the zone metadata (`fine_zone_max_depth`, and anything else T4A.3's
  step 8 needs to persist) in a way T4A.3 can consume — but the function's
  primary return stays the point list per the fixed signature. Expose the
  computed threshold via a small companion helper rather than changing the
  signature, and tell me what you chose.
- **Never silently fall back.** Per `rules/clearskies-process.md`, if the raw
  profile is too short, non-monotonic in depth in a way PCHIP cannot handle, or
  has fewer than the minimum points needed, raise with a clear message. Do not
  return the raw profile unchanged and log a warning.

### LC-4 — What you are NOT doing

You are not changing where the raw profile comes from. T4A.2 step 3 ("raw profile
extraction at native DEM resolution") describes the *input contract* your function
must be fed; **wiring that extraction is T4A.3's job**, in `swan_domain.py` /
`setup.py` / `bathymetry.py`'s download path. Your function must be written to
accept a native-resolution raw profile (~3–10 m spacing) and must document that
contract, but you do not implement the extraction. If your function silently
"works" on a 50 m profile by interpolating garbage, that is a defect — validate
the input spacing and warn (loudly) or raise when it is coarser than plausible
native DEM resolution. Tell me which you chose and why.

---

## 6. Open questions — SendMessage the lead; do NOT resolve unilaterally

- If `scipy` is **not** already a dependency of the API package, stop and tell me
  before adding it — it is a heavyweight dependency and I need to confirm it is
  acceptable in the base install versus the `[nearshore]` extra.
- If the flux-marching formulation in LC-2 produces break points at materially
  different locations than the current code (T4A.2b's Accept bullet says they
  should be unchanged), do not "adjust" the break-point detector to compensate.
  Report the discrepancy with numbers and stop.
- If the HB profile's native DEM resolution turns out to be coarser than the
  ~10 m T4A.2 assumes (see `rules/clearskies-process.md`: "Verify data coverage
  claims per-location before coding against them" — CUDEM 1/9 arc-second does not
  exist south of 36°N on the Pacific coast), say so with evidence. That changes
  what T4A.3 can deliver and I need to know before it dispatches.
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
> operation on any container. SSH to containers is READ-ONLY: running tests,
> reading logs, checking service status.

**Commit messages:** use `git commit -F c:\tmp\<name>-msg.txt` — PowerShell
heredocs break on parens and quotes.

**Scratch file:** append to `c:\tmp\marine-sep-P4A-scratch.md` after every commit
and every decision. Do not reconstruct it at the end.

---

## 8. Scope acknowledgment — required before any code

Before writing any code, SendMessage the lead with a one-paragraph scope
acknowledgment: what you will deliver, what you will NOT touch, and the exact
verification commands you will run before closeout.
