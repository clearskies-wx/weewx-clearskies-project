# Part B Coordinator Session Prompt

Use this as the opening prompt for a new Claude Code session to execute Part B of the MARINE-SERVICE-SEPARATION-PLAN. Copy everything below the line into the new session.

---

## Session objective

Execute Part B of `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — starting with Phase 4A (Fix SwellTrack Pipeline + Vocabulary Unification), then Phase 4 through Phase 8 (Marine Service Separation).

Read the plan FIRST. Read CLAUDE.md FIRST. Read `rules/clearskies-process.md` FIRST. Read `docs/ARCHITECTURE.md` FIRST. Read `reference/clearskies-dev.md` FIRST. These are not optional — every rule, SSH path, git restriction, and deploy script is in those files.

## Why this work exists

The Clear Skies weather station project has a marine/surf forecasting system (~28,000 lines) embedded in the API service. An audit found this architectural violation and a partial extraction attempt (SWAN on librewxr:8767, compute service on librewxr:8770) left the surf page broken for 24+ hours. Part A of the plan patched the broken remote mode so data flows again. Part B properly separates all marine code into a standalone companion service.

But before the code moves (Phases 4-8), the SwellTrack 1D wave transformation model — the core of the surf forecast — must be fixed. **SwellTrack has never produced non-zero output in production.** Every face height shown on the dashboard comes from a single-point K-G/Caldwell formula (SWAN CURVE fallback), not from the 1D physics model. The surf endpoint silently falls back and sets `degraded=True`, but the response looks normal. Phase 4A fixes this.

## What's broken and why (root cause chain)

1. **Profile resolution**: The bathymetric profile at `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` has 50 points at 50m spacing. At this resolution, the Battjes-Janssen breaking dissipation over-attenuates wave energy — the wave dies before reaching shallow enough water to break. SwellTrack returns `best_peak=0.00 m` on all 32 transects, every run. Confirmed: the same data interpolated to 5m resolution produces 3 correct break points.

2. **Battjes-Janssen implementation**: `_battjes_janssen()` in `surf_1d_analytical.py` computes dissipation at each grid point independently instead of forward-marching (accumulating energy loss from offshore to shore). The roller model below it IS forward-marching but operates on the wrong B-J output. This makes dissipation scale linearly with dx — the root cause of both the 50m failure (total attenuation) and the fine-grid "fix" (dissipation becomes negligible, model degenerates to gamma×d cap).

3. **Silent fallback**: The surf endpoint (`endpoints/surf.py`) has a two-phase write: Phase 1 always computes SWAN CURVE K-G/Caldwell face heights, Phase 2 conditionally overrides with SwellTrack. When SwellTrack returns zero, the `else` branch at line 1172 silently keeps SWAN CURVE values. The surf scorer always uses SWAN CURVE face height, never SwellTrack.

4. **L2/L3 grid sizing**: L2 uses a hardcoded 6km offshore distance (`swan_domain.py` line 291) instead of the actual 30m depth contour. L3 falls back to 2.5km when no profile exists. Both are guesses that vary wildly by coast.

5. **Vocabulary split**: The API and dashboard have two parallel type systems for beach profile data — `BeachProfileTransectPoint` (distanceFromShore, waveHeight) vs `HeatMapEnvelopePoint` (distance, hs). The model's internal vocabulary is `distance`, `depth`, `hs`.

6. **CUDEM download timing**: Downloads happen at SWAN runtime. Should happen at wizard apply time after all spots are defined (the unified bounding box defines the SWAN grids). The dependency chain is: L1 (GSFM, static) → coarse CUDEM download → L2 from actual 30m contour → medium download → L3 from actual 15m contour → fine download → variable-resolution profiles.

## Execution order

**Phase 4A** must complete before Phase 4. The tasks within Phase 4A should execute in this order:

1. **T4A.1** (vocabulary unification) — can start immediately, no dependencies
2. **T4A.2b** (Battjes-Janssen fix) — can start immediately, no dependencies
3. **T4A.2** (PCHIP profile generation) — can start immediately, no dependencies
4. **T4A.3** (CUDEM at apply time) — depends on T4A.2 (uses the PCHIP function)
5. **T4A.4** (remove SWAN CURVE fallback) — depends on T4A.2b (B-J must work first)
6. **T4A.5** (regenerate profiles + verify) — depends on ALL above. **Deploy T4A.5 BEFORE or WITH T4A.4** — never after. Removing the fallback before SwellTrack produces non-zero output means zeros everywhere.

After Phase 4A QC gate passes, proceed with Phases 4-8 in order per the plan.

## Key technical details

### Variable-resolution profile (T4A.2)
- PCHIP interpolation of CUDEM raw profile (sampled at native DEM resolution ~10m at HB)
- Fine zone: 1-2m dx, shore to `max(1.3 × max_hs_m / gamma, structure_zone_depth)`
- `structure_zone_depth`: deepest structure depth + margin. Default 0.0 (no structures = fine zone covers only surf zone)
- 1.3× margin accounts for shoaling amplification before breaking
- Shoaling zone: 3-5m dx. Approach zone: native DEM resolution.
- Deduplicate x-values before fitting PchipInterpolator

### Battjes-Janssen fix (T4A.2b)
- Convert `_battjes_janssen()` from vectorized-independent to forward-marching loop
- Pattern: `_roller_model()` right below it already shows the correct approach
- ~20 lines of code change, but affects every wave height in the surf zone
- Validate against Surfline comparisons

### CUDEM tiered download (T4A.3)
- L1 bounding box from GSFM (static) → coarse download (CRM sufficient for 1km grid)
- From coarse data: locate 30m contour per each spot's bearing (not averaged), take max distance → L2 bbox
- Medium download for L2 area → locate 15m contour → L3 bbox
- Fine download for L3 area → extract raw profiles at native resolution → PCHIP interpolate
- Per-spot-bearing contour search — averaged bearing through a submarine canyon mislocates contours

### SWAN CURVE removal (T4A.4)
- `modelStatus` field replaces boolean `degraded`: "ok", "no_breaking", "unavailable", "degraded_bulk"
- null face height = model failure. 0.0 face height = genuinely flat. These are different.
- Scorer returns null quality on model failure — no confident "flat" rating during outages.
- `breakingHawaiianHeight` recomputed from SwellTrack face height, not the removed CURVE value.

## Repos and paths

| Repo | Local path | GitHub | Default branch |
|------|-----------|--------|----------------|
| Project (meta) | `c:\CODE\weather-belchertown` | `clearskies-wx/weewx-clearskies-project` | main |
| API | `repos/weewx-clearskies-api` | `clearskies-wx/weewx-clearskies-api` | main |
| Dashboard | `repos/weewx-clearskies-dashboard` | `clearskies-wx/weewx-clearskies-dashboard` | main |
| Stack (config UI) | `repos/weewx-clearskies-stack` | `clearskies-wx/weewx-clearskies-stack` | main |
| SWAN+SwellTrack | `repos/weewx-clearskies-swan-swelltrack` | `clearskies-wx/weewx-clearskies-swan-swelltrack` | master |

Librewxr repos at `/home/ubuntu/repos/` (same names). SSH: `ssh -F .local/ssh/config librewxr`.

## What was already done (2026-07-23 session)

Fixes already deployed and committed (DO NOT redo):
- `fc5680a` (swan-swelltrack): SWAN standalone service now serves spectral + transect data, restores from disk on startup
- `099e874` (API): Beach profile endpoint routes SwellTrack through compute service
- `0d87b28` (API): Beach profile field names partially aligned (needs T4A.1 to complete — the rename used wrong vocabulary, will be reverted)
- GitHub credentials installed on librewxr (`gh auth`)
- Repo renamed from `weewx-clearskies-swan` to `weewx-clearskies-swan-swelltrack` everywhere
- `rules/coding.md`: disk persistence rule added
- All doc updates committed

## Rules to follow

1. **Read CLAUDE.md before anything else.** It has SSH rules, git restrictions, deploy scripts, filesystem permissions.
2. **NO agent worktree isolation.** All work in the primary local checkout.
3. **Agents must NOT git pull/push/fetch.** Only add, commit, status, log, diff. Coordinator handles push with user approval.
4. **Deploy scripts only** — no manual git pull or systemctl on containers.
5. **Doc-code sync** — every code change that affects a governing doc updates the doc in the same commit.
6. **No silent fallbacks** — if something fails, it fails visibly. Zero output is zero, not a formula guess.
7. **Expensive computed data persists to disk** — never volatile-only (rules/coding.md §1).
8. **Adversarial audit is mandatory per phase** — no deferral.
