# ROUND P BRIEF — beach-profile data unification (marine + API)

**Round identity:** Round P (profile unification), authorized by operator 2026-08-04 in chat:
(a) "Yes" to deleting the endpoint-local second model run and computing zones/shapes/jacking
from the main pipeline; (b) "Yes on publishing the signed beach elevations + tide aware
waterline" (contract addition). Lead: coordinator. Implementer: clearskies-api-dev (marine
Python + API). Guards: clearskies-test-author (separate, after). Auditor: blind, after.

## Pre-round verification (lead)

- marine repo (c:\CODE\weather-belchertown\repos\weewx-clearskies-marine): verify clean at
  dispatch (coordinator runs git status before you start; you re-verify).
- Chimera confirmed by lead code-trace: `transect`+`breakPoints` come from the pipeline
  (beach_profile.py:531-558, :561-648) while `surfZones`+`waveShapes`+`jackingFactors` come
  from an endpoint-local `run_1d_analytical()` call (beach_profile.py:654-719) fed ONLY the
  dominant partition with `tide_level=0.0` — live consequence: zones at 77-156 ft vs
  published breaks at 11-54 ft ("phantom zones", operator-confirmed defect).
- The pipeline's per-transect data (real CO-OPS tide included) is in scope at the endpoint:
  `tr.depths` / `tr.distances` / blended hs (`_blended_hs_m`) / published `break_points`
  (:648, sorted seaward-first). Tide: `_tide_level` resolved at beach_profile.py:1053.
- Signed raw profile: `t_info.bathymetric_profile` (in scope at :660-668) — land carries
  NEGATIVE depth (Amendment 4 signed sampling); `tr.depths` is CLAMPED (`max(signed+tide,
  0.01)` at surf_1d_analytical.py:780-781) and CANNOT recover the waterline.
- Existing zero-crossing interpolator to model on: `_interpolate_zero_depth_crossing`
  (enrichment/bathymetry.py:1928-1953).

## Scope

**Files you may modify (exhaustive):**
1. `repos/weewx-clearskies-marine/weewx_clearskies_marine/endpoints/beach_profile.py`
2. `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surf_1d_analytical.py`
   (ONLY to extract existing classifier logic into callable module-level helpers with the
   SAME math — see P1.3; no formula/threshold changes of any kind)
3. `repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/bathymetry.py`
   (ONLY to add `_interpolate_waterline_crossing()` beside the existing zero-crossing
   helper, same interpolation method)
4. `repos/weewx-clearskies-api/weewx_clearskies_api/` — the marine payload display-unit
   conversion table ONLY (the same table commit c1a8212 extended for `shadowFaceHeight` —
   find it via `git show c1a8212` in the api repo): entries for the three new fields.

**Files you must NOT touch:** tests (test-author owns), dashboard repo, surf.py, the
pipeline (surf_1d_pipeline.py, surf_pipeline_timestep.py), SWAN/SwellTrack/SurfBeat code,
config, docs/manuals (coordinator owns doc sync).

## Reading list (read BEFORE coding)

1. This brief, fully.
2. `endpoints/beach_profile.py` — `_build_transect_profile()` end to end (:500-743) and the
   route handler around :1013-1103 (where `_tide_level` and `t_info` live).
3. `services/surf_1d_analytical.py` — `run_1d_analytical()` (:749-854), `_classify_zones`
   (:514-578), and locate the wave-shape and jacking logic it invokes.
4. `enrichment/bathymetry.py:1928-1953` (`_interpolate_zero_depth_crossing`) and the
   docstring at :2007-2021 (distance-0 semantics).
5. api repo: `git show c1a8212` — the conversion-table pattern to extend.

## Per-deliverable spec (lead calls — implement exactly)

**P1.1 — Delete the side-run.** Remove the `run_1d_analytical(...)` block at
beach_profile.py:654-719 (including the bathy PCHIP refine done only for it, if now
unused). `wave_shapes` / `surf_zones` / `jacking_factors` must no longer come from any
endpoint-local model run.

**P1.2 — Zones from pipeline data.** Compute `surf_zones` via the EXISTING
`_classify_zones(Hs, depths, distances, break_points)` with: Hs = the same blended profile
published as `transect[].hs` (`_blended_hs_m`), depths = `tr.depths`, distances =
`_raw_distances_m`, break_points = `BreakPoint` instances built from the PUBLISHED
`break_points` list (seaward-first order preserved; map distance/depth/hs/breakerType/
iribarren 1:1). No change to `_classify_zones` itself. Null semantics: no published break
points → `SurfZones()` empty exactly as the classifier already returns.

**P1.3 — Wave shapes + jacking from pipeline data.** Locate the logic inside
`run_1d_analytical()` that produces `wave_shapes` and `jacking_factors`. If it is already
a callable helper, call it with: the pipeline arrays above + Tp = `dominant_pbi.period_s
or 10.0` (same fallback the deleted block used). If it is fused inline, EXTRACT it into a
module-level function in surf_1d_analytical.py with byte-identical math (pure
restructuring; state this explicitly in your closeout) and call that. Any temptation to
"improve" a threshold, formula, or criterion while extracting = STOP and report.

**P1.4 — New contract fields (operator-approved additions).** Add to the per-transect
response dict (beach_profile.py:729-742):
- `tideLevel`: float, metres (SI at the marine boundary, like every other length) — the
  `_tide_level` used by the pipeline for this timestep. Thread it into
  `_build_transect_profile()` as a parameter.
- `waterlineDistance`: float metres | null — the crossing where `signed_depth ==
  -tide_level` along `t_info.bathymetric_profile`, computed by the new
  `_interpolate_waterline_crossing(profile, tide_level)` in bathymetry.py (same linear
  interpolation as `_interpolate_zero_depth_crossing`; seaward-most crossing if several;
  null when the profile never reaches `-tide_level` landward, with a WARNING naming the
  shortfall).
- `beachElevation`: list of `{"distance": m, "elevation": m}` from the RAW signed
  `bathymetric_profile` (elevation = `-depth_m`, positive up, LMSL datum), all points with
  `distance_m <= max(_raw_distances_m)`. Native resolution, no refinement, no clamping.
- All three null/absent-safe when `t_info` or `bathymetric_profile` is missing (same
  guards the deleted block used).

**P2 — API conversion table.** Add `tideLevel` (m→ft), `waterlineDistance` (m→ft), and
`beachElevation` (per-item `distance`/`elevation` m→ft) to the marine payload conversion
table extended by c1a8212, with matching `units` entries. Follow that commit's pattern
exactly.

## Verification (your own, before closeout)

Marine tests run on librewxr, NEVER the full suite. Targeted only:
`ssh -F .local/ssh/config librewxr "sudo -u ubuntu /home/ubuntu/repos/weewx-clearskies-api/.venv/bin/python -m pytest <specific marine test files touched by your change> -q"`
— but note the marine repo's checkout on librewxr is deploy-state; you CANNOT test
uncommitted local edits there. Your pre-closeout verification is therefore: (a) targeted
LOCAL syntax/import check is not available (no toolchain on DILBERT) — rely on careful
diff review; (b) grep-verify: `run_1d_analytical` has ZERO call sites in
endpoints/beach_profile.py; `tide_level=0.0` appears NOWHERE in beach_profile.py;
`waterlineDistance`/`tideLevel`/`beachElevation` present in the response dict and the API
conversion table. Deployment + live verification is the COORDINATOR's step, not yours.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If a remote is ahead or behind, STOP and report via SendMessage.
Edit and commit ONLY in the local checkouts (repos\weewx-clearskies-marine,
repos\weewx-clearskies-api). Never edit or commit on any container or on librewxr.

## Architectural changes — STOP, do not proceed

You may not make an architectural change beyond the two operator-authorized items in this
brief (side-run deletion + the three new fields). A change is architectural if it:
(1) changes a physics/math formula or any constant/threshold/criterion inside one (NOT
covered: solving the same equation differently); (2) deletes/replaces/rewires a module or
changes its responsibility; (3) changes a model's domain/grid/boundary/resolution/handoff;
(4) changes a data contract (beyond the three authorized fields); (5) changes where a
computation happens (beyond the authorized side-run deletion); (6) changes a schedule/
trigger/cadence; (7) adds/removes a dependency, port, endpoint, config key, or persisted
file. "Acceptance criteria unreachable" and "a document says so" do NOT authorize you —
STOP and report via SendMessage. You MAY fix code that diverges from its own stated
contract, and extract pure helpers with identical math (P1.3, declared in closeout).

## Stale tests — STOP, do not obey them

If an existing test contradicts your tasked change (e.g., pins the side-run's zones), STOP
and report via SendMessage — do not modify code to make it pass, and do not delete it on
your own authority. Closeout must list every test you modified or deleted with reason, and
every guard/invariant that fired during your work.

## Known adjacent defect — DO NOT FIX, report only

`endpoints/surf.py:389-423` `_compute_median_bathy_profile()` feeds SurfBeat with no
distance filter (negative-distance land points included). OUT OF SCOPE — the round auditor
investigates it; if your change makes it worse/better, note it in closeout.

## Protocol

Before writing ANY code: SendMessage the lead ("main") a one-paragraph scope ack (what you
will deliver, what you will NOT touch, your grep-verification list). WAIT for confirmation.
Implement as 3 commits: (1) P1.1+P1.2+P1.3 marine unification, (2) P1.4 marine new fields,
(3) P2 api conversion. Closeout via SendMessage: commit hashes per repo, the grep outputs,
extraction declaration (P1.3), tests touched (expected none).
