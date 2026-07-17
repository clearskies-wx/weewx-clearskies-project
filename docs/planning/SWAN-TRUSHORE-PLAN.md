# SWAN + TruShore Nearshore Wave Model — Implementation Plan

**Status:** APPROVED
**Created:** 2026-07-16
**Origin:** Research brief documenting the case for replacing NWPS dependency with a locally-run SWAN model (TruShore). See `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` for the full technical findings.

## Context

The current surf endpoint depends on NWPS (Nearshore Wave Prediction System) as its primary data source. NWPS is an NWS operational tool designed for weather forecasters, not a public data service. Its run schedule is human-gated (forecasters must submit wind grids before NWPS can run), making availability 2–8 times per day with no fixed schedule. When a cycle has not posted, NOMADS returns 404. The current 30-minute cache TTL means the last good NWPS fetch is discarded when a 404 is received, forcing a fallback to WaveWatch III — a 50km deep-water global model with no nearshore physics. On WaveWatch III fallback, the surf forecast returns identical wave values across all 144 forecast timesteps, and all four wave_transform.py supplements are skipped.

No commercial surf forecast provider depends on NWPS. Every major surf forecast product (Surfline, MSW, WindGuru) runs its own NWPS-equivalent pipeline on a fixed automated schedule.

This plan implements TruShore: the complete Clear Skies nearshore wave pipeline. TruShore replaces the NWPS dependency with a locally-run SWAN instance driven by HRRR forecast winds on a fixed hourly schedule. It connects SWAN output to the existing wave_transform.py and surf_scorer.py enrichment processors that are already built and deployed. The result is surf forecast data that varies across all 144 forecast timesteps, accounts for coastal structure physics, and is always available regardless of NWS operational state.

---

## 0. Orientation — Execution Context

**Mandatory reading before dispatching any agent.** Read the source documents directly — do not paraphrase their content into agent prompts.

| Document | What the coordinator reads for |
|---|---|
| `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` | Full technical findings: NWPS failure analysis, SWAN compute requirements, input data inventory, HRRR wind evidence, industry practice, architecture decisions |
| `docs/ARCHITECTURE.md` | Services table, provider module layout, container topology, port registry |
| `docs/manuals/API-MANUAL.md` §17 | Current wave_transform.py supplements, surf_scorer.py scoring rules, wind source precedence |
| `docs/manuals/PROVIDER-MANUAL.md` §14.3 | WaveWatch III module identity and ERDDAP access |
| `docs/manuals/OPERATIONS-MANUAL.md` §1 | Native install pip extras pattern (model for `[nearshore]` extra) |
| `rules/clearskies-process.md` | Agents must read source documents directly; git restrictions; deploy scripts; verification mandate |

**Agents must read source documents directly — NEVER paraphrase manuals or plans into agent prompts.** The coordinator tells agents WHICH files to read and WHICH sections are relevant. The agent reads the original text. See `rules/clearskies-process.md` "Agents must read source documents directly."

**All tasks are mandatory.** No deferrals are allowed. Every T-numbered task in every phase must be completed and verified before the plan is considered done. If a task cannot be completed, STOP and report to the user — do not silently defer it.

**Git restrictions (mandatory in every agent prompt):**

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, `git checkout` of remote branches, `git add`, or `git commit`. You may only run read-only git commands: `git status`, `git log`, `git diff`. All commits are made by the coordinator, not agents. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

**Only the coordinator commits.** Agents edit files on the local machine at `c:\CODE\weather-belchertown\repos\weewx-clearskies-*` but do NOT run `git add` or `git commit`. The coordinator reviews agent work and commits. SSH to containers is for READ-ONLY verification: running tests, reading logs, checking service status. Never edit source files on weewx or weather-dev.

**Deploy scripts — use these, not manual commands:**
- `scripts/deploy-api.sh` — API changes → weewx container
- `scripts/redeploy-weather-dev.sh` — Dashboard changes → weather-dev
- `scripts/sync-to-weather-dev.sh` — Source-only refresh on weather-dev

**Verification mandate:** Every provider fix and new module MUST include a live API test as part of the acceptance criteria. "Code compiles and unit tests pass" is not sufficient — new providers must return real data from the real external API.

**Run targeted tests only.** Do not run the full pytest suite. Run only the tests relevant to the files changed, e.g. `pytest tests/providers/wind/test_hrrr.py -q`. The full suite takes minutes and floods agent context.

**Test baselines (must not regress):**

| Suite | Baseline | Command |
|---|---|---|
| API pytest | Establish at Phase 1 kickoff | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | Establish at Phase 5 kickoff | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |

**NWPS elimination:** NWPS is removed entirely — code, docs, cache warmer schedule, config keys. There is no legacy mode. SWAN+TruShore is the only nearshore model. Phase 3 T3.4 handles the deletion.

---

## Phase 0 — ADR & Manual Updates ✅ COMPLETE (2026-07-16)

Before any code is written, the governing documents must describe the architecture we are building toward. This gives dev agents a correct reading list and prevents them from implementing against stale contracts.

### T0.1 — Draft ADR: SWAN + TruShore nearshore model decision

- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-{next}.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` (full), `docs/decisions/_TEMPLATE.md`

**Do:**
- Draft an ADR (status: Proposed) documenting the decision to run our own SWAN instance (TruShore) instead of depending on NWPS.
- Follow the Nygard format per `docs/decisions/_TEMPLATE.md`.
- Frontmatter includes `supersedes: ADR-084` — this ADR replaces the "NWPS as primary nearshore source" decision. The four supplements from ADR-084 (γ correction, structure effects, spatial interpolation, topographic focusing) survive and apply to SWAN output; only the primary source decision changes.
- Decision section: 1–2 sentences. Context section: why NWPS is inadequate (from §1 of the research brief). Options considered: NWPS dependency (current), NWPS with extended cache TTL (partial mitigation), own SWAN instance (chosen). Consequences: SWAN binary dependency, HRRR provider needed, NWPS eliminated (code and docs removed). Implementation guidance: pip extra `[nearshore]`, SWAN+TruShore is the only nearshore model (no `nearshore_model` config key — if `[nearshore]` extra is installed, SWAN+TruShore runs).
- Keep to ~80 lines per ADR content standards in `rules/clearskies-process.md`.
- Update ADR-084: add `superseded-by: ADR-{this ADR's number}` to its frontmatter. Add a one-line note at top of its Decision section: "**Superseded by ADR-{N}.** NWPS is eliminated. The nearshore source is now SWAN+TruShore (locally-run SWAN instance). The four supplements defined here continue to apply to SWAN output."
- Update the ADR INDEX: move ADR-084 from "Archived" to "Superseded" section, noting the superseding ADR.

**Accept:**
- ADR exists as Proposed in `docs/decisions/`.
- All required Nygard sections are present (Status, Context, Options, Decision, Consequences, Implementation guidance, References).
- Options table includes all three options evaluated.
- ADR-084 frontmatter has `superseded-by` populated.
- ADR INDEX reflects the supersession.
- User reviews and approves before status changes to Accepted.

### T0.2 — Draft ADR: surf wind source (HRRR forecast wind)

- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-{next+1}.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §4, `docs/manuals/API-MANUAL.md` §17 "Wind source for surf quality scoring"

**Do:**
- Draft an ADR (status: Proposed) documenting the change in wind source for surf quality scoring from the current precedence chain (station hardware → forecast provider) to HRRR forecast wind as the canonical source for TruShore-driven surf forecasts.
- Context: current rule prefers station hardware, but station hardware is a real-time observation — not a forecast. For 72-hour surf forecasts, HRRR forecast wind (the same model that forces SWAN) is the correct source. Station hardware remains correct for the current-conditions snapshot but not for forecast timesteps.
- Decision: for SWAN+TruShore surf forecasts, wind source = HRRR (the same model run that drove SWAN). Station hardware wind observations remain the source for the current-conditions snapshot (`t=0` scoring).
- Implementation guidance: surf_scorer.py receives wind data with a `source` tag; when source is `hrrr_trushore`, the station hardware lookup is bypassed.

**Accept:**
- ADR exists as Proposed.
- Decision clearly distinguishes between current-conditions scoring (station hardware) and forecast scoring (HRRR).
- No conflict with existing §17 rule — the existing station hardware rule applies to `t=0` current conditions; the HRRR rule applies to forecast timesteps.
- User approves before Accepted status.

### T0.3 — Update API-MANUAL §17 — TruShore as nearshore model

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §2, §6, §7; current §17 text

**Do:**
- Rewrite §17 "NWPS supplement processor" as "SWAN+TruShore nearshore model". Remove all NWPS content — NWPS is eliminated, not legacy.
- Document SWAN+TruShore as the nearshore model when `[nearshore]` extra is installed. No `nearshore_model` config key — if the extra is installed, SWAN+TruShore runs.
- Document the HRRR wind sourcing rule for forecast timesteps (from T0.2 ADR).
- Document the SWAN integration: subprocess model, input sources (HRRR wind → SWAN, WW3 boundary conditions, CUDEM bathymetry, RTOFS tidal currents), output format (MarineForecastPoint per timestep).
- Document the no-WW3-fallback rule: WW3 is NEVER used as the surf forecast source. WW3 remains the deep-water boundary input to SWAN and continues to serve the marine endpoint's deep-water forecast. The surf endpoint serves the last successful SWAN+TruShore cache if the runner fails.

**Accept:**
- §17 describes SWAN+TruShore as the only nearshore model. No NWPS documentation remains.
- HRRR wind sourcing rule is documented with the distinction between forecast mode and current-conditions mode.
- WW3's role is correctly scoped: boundary input to SWAN + marine deep-water endpoint, never surf forecast source.

### T0.4 — Update PROVIDER-MANUAL — HRRR wind provider + NWPS removal

- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §4 (HRRR access details); current §14.6 NWPS

**Do:**
- Add §14.{next} documenting the HRRR wind provider: module identity (`providers/wind/hrrr.py`, PROVIDER_ID `hrrr`, DOMAIN `wind`), NOMADS Grib Filter URL, AWS S3 backup URL, geographic bounding box config, U/V at 10m AGL variable names, grid-relative to earth-relative rotation requirement (`wgrib2 -new_grid_winds earth`), hourly fixed schedule, cache TTL.
- Remove §14.6 NWPS entirely. NWPS is eliminated, not legacy. The section is deleted (the archived ADR-084 preserves the historical decision rationale).
- Add §14.{trushore} documenting the SWAN+TruShore runner: not a network provider but a local subprocess provider; SWAN binary dependency; input sources; output points format; cache key and TTL; run schedule tied to HRRR cycle.

**Accept:**
- HRRR wind provider fully documented: URL, variables, rotation requirement, schedule, TTL.
- NWPS §14.6 is removed. No NWPS documentation remains in the PROVIDER-MANUAL.
- SWAN+TruShore runner documented as a local subprocess provider.

### T0.5 — Update ARCHITECTURE.md — SWAN subprocess, HRRR wind provider, TruShore service option

- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §6; current services table

**Do:**
- Add a note to the API service table entry: "Optional `[nearshore]` extra adds SWAN subprocess (Fortran, runs locally), wgrib2, and the HRRR wind provider. SWAN runs as a subprocess within the API process on the same host. When `[trushore] service_url` is set to a remote host, the API reads TruShore output from that host instead."
- Add a new optional component note (following the weewx extension notes pattern): "**ClearSkiesTruShore** (`weewx-clearskies-trushore`) is an OPTIONAL standalone service. Operators who want to run SWAN on dedicated hardware install this pip package on a separate machine. It runs SWAN hourly on the HRRR cycle and serves results via Redis or HTTP. The API reads from it via `[trushore] service_url`. When not installed, TruShore runs bundled inside the API process on the weewx host."
- Add `wgrib2` and SWAN to the API's technology column (under the `[nearshore]` extra).

**Accept:**
- ARCHITECTURE.md reflects that SWAN runs as a subprocess in the API process by default.
- Optional separated TruShore service is documented following the existing extension note pattern.
- No port changes (SWAN is internal to the API process, not a network service in the default topology).

### T0.6 — Amend ADR-091 Decision 1: waveHeight source contract

- Owner: Coordinator (Opus)
- Files: `docs/archive/decisions/ADR-091-marine-card-data-sources-and-ofs-ocean-data.md`, `docs/manuals/API-MANUAL.md` (if Decision 1's table was consolidated there)
- Reference: T0.1 ADR (supersedes ADR-084), T0.3 (API-MANUAL §17 TruShore update)

**Do:**
- ADR-091 Decision 1 defines the `waveHeight` card data source contract as: primary = `NWPS → wave_transform.apply_supplements()`, fallback = `WaveWatch III first forecast point (no supplements per ADR-084), then NDBC buoy Hs`. NWPS is eliminated and WW3 is removed from the surf fallback chain.
- Amend Decision 1's `waveHeight` row: primary = `SWAN+TruShore → wave_transform.apply_supplements()`. Fallback = last successful SWAN+TruShore cache (any age) → null. No NWPS, no WW3 for surf.
- Add an amendment note at the top of ADR-091: "**Amendment (SWAN+TruShore, ADR-{T0.1 number}):** Decision 1 waveHeight source updated — NWPS eliminated, SWAN+TruShore is the only nearshore source. WW3 removed from the surf fallback chain. See ADR-{T0.1 number}."
- If Decision 1's table was consolidated into API-MANUAL.md or PROVIDER-MANUAL.md, update the manual table to match. (T0.3 likely covers this — verify no conflict.)

**Accept:**
- ADR-091 Decision 1 `waveHeight` row reflects SWAN+TruShore as default primary.
- WW3 no longer listed as a surf fallback in ADR-091.
- Amendment note references the superseding ADR by number.
- No conflict with T0.3 API-MANUAL updates (same contract, documented in both places).

### QC Gate 0

- All documents (ADRs Proposed, API-MANUAL, PROVIDER-MANUAL, ARCHITECTURE.md, ADR-084 superseded, ADR-091 amended) reflect a consistent architecture.
- ADRs are Proposed (not Accepted — user approval pending); no other documents say "Accepted" on behalf of the user.
- ADR-084 has `superseded-by` in its frontmatter; ADR INDEX reflects this.
- ADR-091 Decision 1 waveHeight row matches the SWAN+TruShore source contract.
- NWPS documentation is removed from all manuals (not marked legacy — eliminated).
- WW3's role is correctly limited: marine deep-water endpoint + SWAN boundary conditions.
- No manual update contradicts any existing Accepted ADR.
- Adversarial auditor (`clearskies-auditor`) reviews all documents for internal consistency before Phase 1 begins.

---

## Phase 1 — HRRR Wind Provider ✅ COMPLETE (2026-07-16)

HRRR is the wind forcing source for SWAN. This provider must be implemented and validated against real HRRR data before SWAN integration can proceed.

### T1.1 — Implement HRRR wind provider module

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/wind/hrrr.py`
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/wind/__init__.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/__init__.py` (register wind domain)
- Reference: PROVIDER-MANUAL §14.{HRRR section added in T0.4} and its READING LIST; `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §4

**Do:**
- Implement `providers/wind/hrrr.py` with `PROVIDER_ID = "hrrr"`, `DOMAIN = "wind"`.
- Fetch the most recent available HRRR cycle from NOMADS Grib Filter (`https://nomads.ncep.noaa.gov/cgi-bin/filter_hrrr_2d.pl`) for a configurable coastal bounding box.
- Extract U-component and V-component of wind at 10m above ground level (UGRD_10maboveground, VGRD_10maboveground).
- Rotate grid-relative winds to earth-relative using the Lambert Conformal grid parameters. Do NOT skip this step — grid-relative winds are systematically wrong by up to ~20° near domain boundaries.
- Cache the full wind field (all forecast hours available in the HRRR run, up to 18 or 48 hours depending on cycle) with a TTL of 55 minutes (slightly less than the hourly HRRR cycle to ensure fresh data on each cycle).
- Implement cycle fallback: if the most recent cycle (e.g., 15Z) returns 404 (not yet posted), try the previous cycle (14Z). Log at INFO level which cycle was used.
- Follow the existing provider module patterns in `providers/marine/wavewatch.py` for cache key structure, error handling, and rate limiting.
- Do NOT make this provider part of the standard provider registry startup — it is invoked by the SWAN runner, not by the cache warmer directly.

**Accept:**
- `fetch(bbox=(lon_min, lat_min, lon_max, lat_max))` returns a wind field object with U and V components for all available forecast hours, confirmed earth-relative (not grid-relative).
- Wind values at known SoCal coastal sites match NDBC buoy wind observations within ±3 m/s for at least 3 separate test cycles (this is a sanity check, not a formal validation — HRRR vs. real-time observations will differ due to forecast lead time).
- Cycle fallback confirmed working: temporarily provide an invalid cycle time, verify the provider falls back and logs the fallback.
- Unit tests in `tests/providers/wind/test_hrrr.py` cover: successful fetch, cycle fallback, 404 on all cycles (raises ProviderUnavailableError), wind rotation (known Lambert Conformal grid parameters → expected earth-relative output).

### T1.2 — Add wgrib2 integration for GRIB2 wind rotation

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/wind/hrrr.py`
  - Modify: `repos/weewx-clearskies-api/pyproject.toml` (add wgrib2 availability check to `[nearshore]` extra dependencies note)
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §4 (rotation requirement); OPERATIONS-MANUAL §1 (native dependency pattern, following eccodes precedent)

**Do:**
- Implement GRIB2 wind rotation using either: (a) subprocess call to `wgrib2 -new_grid_winds earth` if wgrib2 is available on PATH; or (b) Python formula using the Lambert Conformal grid's `lov` and `latin1`/`latin2` parameters to compute the rotation angle per grid point. Option (b) is preferred as it eliminates the wgrib2 binary requirement for the wind rotation step.
- The Lambert Conformal wind rotation formula (NCEP Office Note 388, Appendix C): compute cone factor `n = sin(latin1)` (tangent case; HRRR: latin1 = latin2 = 38.5° → n ≈ 0.6225), then per grid point `alpha = radians(n × (lon - lov))`, `U_earth = U_grid × cos(alpha) - V_grid × sin(alpha)`, `V_earth = U_grid × sin(alpha) + V_grid × cos(alpha)`. Source the exact HRRR Lambert parameters (`lov`, `latin1`, `latin2`) from the GRIB2 metadata (eccodes or pygrib).
- Add a validation step: after rotation, compute wind direction at a test point and verify it is within ±5° of the expected direction based on the synoptic pattern.
- Document the rotation approach in the module docstring with a source citation (NCEP GRIB2 documentation or equivalent).

**Accept:**
- Wind direction computed from earth-relative U/V matches the expected synoptic wind direction for a test cycle at a coastal California site to within ±10°.
- No wgrib2 binary required if the Python formula approach is used. If wgrib2 subprocess is used, log a clear error if wgrib2 is not found on PATH.

### T1.3 — Add HRRR to docs cache warmer (indirect)

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/cache_warmer.py` (or equivalent)
- Reference: ARCHITECTURE.md (cache warmer runs at API startup); OPERATIONS-MANUAL §1 (startup sequence)

**Do:**
- Add a cache warmer entry for the HRRR wind provider, active when the `[nearshore]` pip extra is installed. The HRRR fetch should run at startup and on the hourly schedule (HRRR cycle cadence).
- The HRRR warm does NOT block the API startup — it fires async in the background. SWAN cannot run until HRRR data is warm, but the API can serve other endpoints while the first HRRR fetch completes.
- If HRRR warm fails at startup, log WARNING (not ERROR) — the SWAN runner will retry on the next hourly cycle.

**Accept:**
- API startup log shows HRRR cache warm attempt when `[nearshore]` extra is installed.
- HRRR warm failure at startup does not cause API startup to fail.
- On the hour, HRRR is re-fetched automatically (verify via log entries).

### QC Gate 1

- HRRR provider returns a valid wind field for the SoCal bounding box (lon: -121 to -116, lat: 32 to 35) for the most recent available cycle.
- Wind values at coastal sites are earth-relative (not grid-relative): verify by comparing wind direction at a known site against a NOAA weather station or NDBC buoy report for the same period.
- Cycle fallback working: provider returns data from the previous cycle when the latest cycle is not yet available.
- Unit tests pass for the HRRR module: `uv run pytest tests/providers/wind/test_hrrr.py -q`.
- API pytest baseline established and all tests pass.
- PROVIDER-MANUAL §14.{HRRR} matches implemented behavior (from T0.4).

---

## Phase 2 — SWAN Model Integration ✅ COMPLETE (2026-07-17)

SWAN is the wave physics engine. This phase installs SWAN, implements the runner service, and produces physically correct wave forecasts at configured surf spot locations.

### T2.1 — Package SWAN as optional dependency

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/pyproject.toml` — add `[nearshore]` optional dependency group
  - New: `repos/weewx-clearskies-api/scripts/install_swan.sh` — download and compile SWAN for native installs
  - Modify: `repos/weewx-clearskies-api/Dockerfile` — add SWAN compilation to the Docker image build for the `[marine][nearshore]` target
- Reference: OPERATIONS-MANUAL §1 (native dependency pattern — follows eccodes precedent); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §6 (pip extra design)

**Do:**
- Add `[nearshore]` to `pyproject.toml` optional dependencies, following the same pattern as `[marine]` (which adds eccodes). The `[nearshore]` extra includes: cfgrib or pygrib (GRIB2 processing), xarray, the HRRR provider (T1.1), and documentation of the SWAN binary requirement.
- SWAN binary is NOT a pip package — it is compiled Fortran. `install_swan.sh` automates: download SWAN 41.45 source from sourceforge, compile with gfortran and OpenMP, install binary to `/usr/local/bin/swan`.
- Dockerfile: add a build stage that runs `install_swan.sh`. The `[nearshore]` Docker target builds on the `[marine]` target.
- The API startup check: if `[nearshore]` extra is installed but SWAN binary is not found on PATH, log a CRITICAL error with installation instructions. The surf endpoint returns null surf data until SWAN is available — no fallback to any other model.

**Accept:**
- `pip install weewx-clearskies-api[nearshore]` completes without error on a clean Ubuntu 22.04 system (after `apt install gfortran libopenmpi-dev`).
- `swan --version` returns a SWAN version string after `install_swan.sh` runs.
- API startup log shows "SWAN found at /usr/local/bin/swan, version 41.xx" when `[nearshore]` extra is installed.
- API startup logs CRITICAL with install instructions when SWAN binary is not found. Surf endpoint returns null (no fallback model).
- Docker image builds successfully with SWAN included.

### T2.2 — Implement SWAN runner service

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/services/__init__.py` (if not present)
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §6, §7; API-MANUAL §17 (MarineForecastPoint output format)

**Do:**
- Implement `services/swan_runner.py` with a `SWANRunner` class:
  - `__init__`: takes config (domain bbox, surf spot coordinates, bathymetry data, HRRR bbox, SWAN binary path)
  - `run(hrrr_wind_field, ww3_boundary, cudem_bathymetry)`: orchestrates the full SWAN run and returns a list of `MarineForecastPoint` objects (one per surf spot per timestep)
  - `_write_input_files(tmpdir)`: writes all SWAN input files to a temporary directory
  - `_spawn_swan(tmpdir)`: subprocess call to `swan < INPUT`, captures stdout/stderr, raises `SWANRunError` if non-zero exit
  - `_parse_output(tmpdir)`: reads SWAN TABLE output files, extracts Hs, Tm01, MWD at each configured OUTPUT POINT
- SWAN input files to generate:
  - `INPUT`: the main SWAN command file (CGRID, INPGRID BOTTOM, READINP BOTTOM, INPGRID WIND, READINP WIND, INPGRID WL, READINP WL, BOUND SPEC, PHYSICS, NUMERIC, OUTPUT POINTS TABLE, COMPUTE, STOP)
  - `BOTTOM.txt`: ASCII depth grid from CUDEM bathymetry (negative = ocean, positive = land)
  - `WIND.txt`: ASCII wind field (U, V) from HRRR at each grid point and timestep
  - `BOUND_SPEC.txt`: directional wave spectrum at the domain boundary from WaveWatch III
  - `OUTPUT_POINTS.txt`: coordinates of surf spot output points (tab-separated lat/lon)
- `_parse_output`: reads SWAN TABLE format — fixed-width ASCII with columns (Xp, Yp, Hs, Tm01, MWD) and one row per timestep per point. Map to `MarineForecastPoint(wave_height=Hs, wave_period=Tm01, wave_direction=MWD, source="trushore", timestamp=...)`.
- Run SWAN in a temporary directory that is cleaned up after a successful run. On failure, preserve the temp directory and log its path for debugging.

**Accept:**
- `run()` returns a non-empty list of `MarineForecastPoint` objects for a test domain (Huntington Beach, bbox ~33.5–33.8°N, 118.2–117.9°W).
- Wave height values are physically reasonable (0.1–10m range) for normal conditions.
- Wave period values are physically reasonable (5–20s range) for a nearshore domain.
- Wave direction is expressed as degrees from North (0–360), direction waves travel FROM.
- Temporary directory is cleaned up after a successful run.
- Failed SWAN run raises `SWANRunError` with the SWAN stderr output attached.
- Unit tests in `tests/services/test_swan_runner.py` cover: input file generation (verify file structure with known test inputs), output parsing (verified against a reference SWAN TABLE file).

### T2.3 — SWAN input file generation: wind, boundary, bathymetry

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (T2.2 continuation)
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py` — input file format writers
- Reference: SWAN manual §5 (input file syntax); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §3 (data sources); API-MANUAL §17 (WaveWatch III data format the wavewatch.py provider returns)

**Do:**
- `swan_formats.py` contains format conversion utilities:
  - `hrrr_to_swan_wind(wind_field, grid_bbox, grid_resolution_m)`: bilinear-interpolate the HRRR wind field onto the SWAN computational grid; write SWAN ASCII WIND format (one timestep per block, U then V in row-major order)
  - `cudem_to_swan_bottom(depth_profile, grid_bbox, grid_resolution_m)`: write SWAN ASCII BOTTOM format (depth in meters, positive = ocean, negative = land — note: SWAN convention is opposite of CUDEM's sign convention; flip sign)
  - `ww3_to_swan_boundary(ww3_spectrum, domain_boundary_nodes)`: write SWAN BOUND SPEC format from WaveWatch III's directional energy spectrum. WW3 provides E(f, θ) at the domain corners; SWAN's BOUND SPEC 2D DSPEC expects the same.
- SWAN grid resolution: 200m default (configurable per `[marine] swan_grid_resolution_m`). For a 30km × 15km domain, this is 150 × 75 = 11,250 grid points — well within the tested range.
- SWAN time step: 10 minutes default (SWAN's default non-stationary time step). Forecast output timestep: 1 hour (matching HRRR wind input cadence).

**Accept:**
- `hrrr_to_swan_wind` produces an ASCII file that SWAN reads without "UNABLE TO READ" errors.
- `cudem_to_swan_bottom` produces a depth grid where land is positive and ocean is negative (SWAN convention), verified by reading a known point.
- `ww3_to_swan_boundary` produces a BOUND SPEC 2D DSPEC file that SWAN reads without errors.
- End-to-end: SWAN runs to completion on the Huntington Beach test domain using real HRRR, WW3, and CUDEM data.

### T2.4 — SWAN output parsing and MarineForecastPoint conversion

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
- Reference: API-MANUAL §17 (MarineForecastPoint format — SWAN+TruShore must produce this shape)

**Do:**
- SWAN TABLE output format: space-separated columns. The table header (starting with `%`) names the columns. Parse the header to identify Hs, Tm01, MWD column indices — do not hardcode column positions.
- Timestamp extraction: SWAN output includes the simulation time in `Run_xxx` file or in the table header. Parse the actual simulation time, not the HRRR cycle time.
- Unit conversion: SWAN outputs wave height in meters, wave period in seconds, direction in degrees (nautical convention: direction waves come FROM). These match the MarineForecastPoint base units. No conversion needed for wave height (base unit is meters in the API), but apply any configured unit conversion at the endpoint level (not here).
- Multi-spot: parse all configured OUTPUT POINTS. Each spot's data is a separate TABLE file (or separate sections in one file, depending on SWAN config). Map each point back to its configured surf spot ID by matching coordinates.
- Validation: reject any timestep where Hs > 20m or Hs < 0m, Tm01 < 1s or Tm01 > 30s, or MWD is NaN — these indicate numerical instability. Log the rejected values at WARNING level.

**Accept:**
- Parser correctly identifies column positions from TABLE header regardless of column order.
- Multi-spot output produces correctly labeled data per surf spot.
- Validation rejects physically impossible values and logs them.
- MarineForecastPoint objects from SWAN output match the API-MANUAL §17 schema.

### T2.5 — Integration with cache warmer: run SWAN on HRRR cycle schedule

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/cache_warmer.py` (or scheduling equivalent)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/trushore.py` (new provider wrapper)
- Reference: ARCHITECTURE.md (cache warmer startup sequence)

**Do:**
- Create `providers/nearshore/trushore.py` as a thin provider wrapper around `services/swan_runner.py`. This is the object the endpoint calls, following the existing provider interface pattern.
- `TrushoreProvider.fetch(surf_spot_id, ...)`: retrieves HRRR wind, WW3 boundary, CUDEM bathymetry (all from cache — they run on their own schedules); calls `SWANRunner.run()`; caches results keyed by `(provider_id, spot_domain_id, hrrr_cycle_time)` with a TTL of 55 minutes (matching HRRR cycle cadence).
- SWAN runs in a background thread (not in the request path). The cache warmer fires the first SWAN run at startup (after HRRR and WW3 data are warm) and on the hourly schedule thereafter.
- If SWAN run fails: log ERROR, retain the last successful cache entry. Do NOT invalidate the cache on failure — stale TruShore data is always preferred to no data.
- Expose cache age in the surf endpoint response (e.g., `dataAge: 3420` seconds) so the dashboard can show when the last SWAN run completed.

**Accept:**
- `GET /surf/{spot_id}` returns SWAN+TruShore data when `[nearshore]` extra is installed.
- Wave data varies across all 144 forecast timesteps (not identical values — this is the key regression vs. WW3 fallback).
- Data age is present in the response.
- SWAN run failure retains last-good cache: verify by temporarily breaking SWAN binary path, confirm API continues to serve (stale but non-null) surf data.
- SWAN completes within 15 minutes on the weewx host hardware (it will likely be 2–5 minutes; 15 minutes is the upper bound tolerance).

### T2.6 — Implement Hsig → breaking face height conversion

- Owner: Coordinator (Opus) for research (DONE — see brief); `clearskies-api-dev` (Sonnet) for implementation
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/breaker_height.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py` (score using `breakingFaceHeight`)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py` (add three height fields to response)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py` (add `swellHeight`, `breakingFaceHeight`, `breakingHawaiianHeight` to `SurfForecast`)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py` (add per-spot `breaker_formula` and `surf_height_display`)
- Reference: `docs/planning/briefs/WAVE-BREAKING-CONVERSION-BRIEF.md` (full research findings — read §3–§5 before coding); SWAN manual §4 (output variables)

**Research findings (completed 2026-07-16):**

Full research brief at `docs/planning/briefs/WAVE-BREAKING-CONVERSION-BRIEF.md`. Key decisions:

- **Two breaker formulas supported.** Komar-Gaughan (1973) is the default — general-purpose, works for all periods and coastline types. Caldwell (2007) is an opt-in alternative for steep volcanic island coasts (Hawaii, Indonesia, Tahiti) — empirically tuned against 32 years of Oahu visual surf observations, predicts H1/10 (set waves), but fails below 10s period.
- **Three height fields in the surf response.** `swellHeight` (raw SWAN Hsig), `waveHeightAtBreak` (post-supplement Hsig, backward compatible), `breakingFaceHeight` (trough-to-crest face height via breaker formula) + `breakingHawaiianHeight` (back-of-wave, ×0.5 of face height). All four always present in every response — the operator's display preference selects which the dashboard shows as primary, but the API returns all.
- **Scorer uses face height.** `surf_scorer.py` scores using `breakingFaceHeight`, not raw Hsig. The scoring thresholds represent what surfers consider good waves — surfers think in face height. `_WAVE_HEIGHT_RANGES_FT` recalibrated accordingly.
- **Hawaiian and face height are always proportional** (fixed ×0.5 factor). Scoring always uses face height regardless of display preference — the score is scale-independent.
- **Per-spot operator config.** `breaker_formula` (default `komar_gaughan`, opt-in `caldwell`) and `surf_height_display` (default `face`, alt `hawaiian`) are per-spot fields in the marine location config. Set via wizard/admin.
- **Caldwell auto-crossover.** When `breaker_formula = caldwell`, the system uses Caldwell for timesteps where Tp ≥ 10s and automatically falls to Komar-Gaughan for Tp < 10s (Caldwell is unreliable for short-period wind swell).
- **Existing supplements preserved.** All four wave_transform.py supplements (γ correction, structure effects, spatial interpolation, topographic focusing) fire before the face height conversion. No changes to supplement behavior. The pipeline is: SWAN Hsig → supplements → corrected Hsig → breaker formula → face height.

**Do:**

- **`breaker_height.py`:** Implement `hsig_to_face_height(hsig_m, period_s, output_depth_m, formula)` using both formulas:
  - **Komar-Gaughan (1973):** `Hb = 0.39 × g^(1/5) × (Tp × Hsig²)^(2/5)`. Depth-aware correction when SWAN output is in shallow water (< 15m) to avoid double-counting shoaling SWAN already computed. Clamp output to [Hsig, 3 × Hsig].
  - **Caldwell (2007):** Empirical formula from the Caldwell & Aucan paper. Auto-fall to Komar-Gaughan when Tp < 10s.
  - `hawaiian_height(face_height_m)`: returns `face_height_m × 0.5`.
- **`SurfForecast` model:** Add `swellHeight`, `breakingFaceHeight`, `breakingHawaiianHeight` fields (all `float | None`). Existing `waveHeightAtBreak` field retained (backward compatible — post-supplement Hsig, same semantics as today).
- **Surf endpoint pipeline:**
  ```
  SWAN output (Hsig at output point)
    → store as swellHeight
    → wave_transform.apply_supplements() → corrected Hsig
    → store as waveHeightAtBreak
    → breaker_height.hsig_to_face_height(corrected_hsig, Tp, depth, formula)
    → store as breakingFaceHeight
    → breaker_height.hawaiian_height(face_height) → store as breakingHawaiianHeight
    → surf_scorer.score_surf(breakingFaceHeight, ...) → quality score
  ```
- **Scorer recalibration:** Change `score_surf()` wave height input from `waveHeightAtBreak` to `breakingFaceHeight`. Adjust `_WAVE_HEIGHT_RANGES_FT` thresholds upward by ~15–20% to reflect face height values (e.g., optimal range shifts from 3–6ft Hsig to approximately 3.5–7ft face height). Verify that scoring produces the same quality labels as before for typical conditions — this is a recalibration, not a redesign.
- **Per-spot config:** Add `breaker_formula` and `surf_height_display` to the marine location config model in `marine_config.py`. Default values: `komar_gaughan` and `face`.
- **Unit conversion:** All three height fields (`swellHeight`, `breakingFaceHeight`, `breakingHawaiianHeight`) are converted to the operator's configured `group_wave_height` unit (feet or meters) at the endpoint level, same as `waveHeightAtBreak`.

**Accept:**
- Research findings documented in `docs/planning/briefs/WAVE-BREAKING-CONVERSION-BRIEF.md` (DONE — completed 2026-07-16).
- `breaker_height.py` implements both Komar-Gaughan and Caldwell formulas with correct constants and source citations.
- Three new fields present in every `SurfForecast` entry: `swellHeight` (raw SWAN Hsig), `breakingFaceHeight` (face height via breaker formula), `breakingHawaiianHeight` (×0.5 of face height).
- `waveHeightAtBreak` retained with its current semantics (post-supplement Hsig) — no breaking change.
- Face height increases monotonically with wave period for the same Hsig: a 4ft Hsig at 16s produces a taller `breakingFaceHeight` than 4ft Hsig at 8s.
- Komar-Gaughan worked examples match the brief's §3 table within ±5%.
- Caldwell auto-crossover: with `breaker_formula = caldwell`, timesteps with Tp < 10s use Komar-Gaughan (verify via unit test).
- `breakingHawaiianHeight` is exactly `breakingFaceHeight × 0.5` for all timesteps.
- Scorer uses `breakingFaceHeight`: verify that `qualityStars` changes when the same Hsig is presented with a short vs. long period (the period amplifies face height, which changes the height score).
- Existing γ correction (Supplement 1) still fires and does not double-count — supplements operate on Hsig before the face height conversion.
- All four supplements confirmed active in the pipeline (log output or unit test).
- Unit tests in `tests/enrichment/test_breaker_height.py` cover: Komar-Gaughan formula (known inputs → expected outputs), Caldwell formula, Caldwell auto-crossover at Tp < 10s, depth-aware correction, Hawaiian conversion, clamp bounds.

### QC Gate 2

- SWAN produces physically reasonable wave forecasts for the Huntington Beach test domain: Hs 0.3–3.0m, Tm01 8–16s for a typical SoCal winter swell.
- Wave data varies across forecast timesteps (not identical values across 144 hours).
- Compare SWAN+TruShore breaking face height at surf spot against NDBC buoy observations at the nearest coastal buoy for overlapping periods: values should be physically reasonable and within the expected nearshore-to-buoy offset range.
- Three height fields present in every `SurfForecast` entry: `swellHeight` < `waveHeightAtBreak` ≤ `breakingFaceHeight` for typical nearshore conditions (supplements reduce height; face conversion amplifies it).
- `breakingFaceHeight` increases with period for the same Hsig: verify a 1.2m Hsig at 16s produces a larger face height than 1.2m Hsig at 8s.
- `breakingHawaiianHeight` is exactly 0.5× `breakingFaceHeight` for all timesteps.
- Komar-Gaughan worked examples from the brief match implementation output within ±5%.
- Caldwell auto-crossover verified: with `breaker_formula = caldwell`, a timestep with Tp = 8s uses Komar-Gaughan.
- Scorer `qualityStars` uses `breakingFaceHeight` — verified by checking that two timesteps with identical Hsig but different periods produce different height scores.
- SWAN run completes within 15 minutes on weewx host.
- Cache retains last-good data on SWAN failure.
- All Phase 1 test baselines hold.
- Unit tests for SWAN runner, TruShore provider, and `breaker_height.py` pass.

---

## Phase 3 — TruShore Post-Processing Integration ✅ COMPLETE (2026-07-17)

SWAN output feeds the existing wave_transform.py and surf_scorer.py enrichment processors. This phase wires the new data source, removes NWPS, and cleans up.

### T3.1 — Wire SWAN output through wave_transform.py

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/wave_transform.py` (remove any NWPS-specific assumptions)
- Reference: API-MANUAL §17 (supplement processor spec); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §7

**Do:**
- In the surf endpoint, use `TrushoreProvider.fetch()` to get wave data. Store raw SWAN Hsig as `swellHeight`. Pass the resulting wave data to `wave_transform.apply_supplements()`. Store the supplement-corrected Hsig as `waveHeightAtBreak`. Then pass it through `breaker_height.hsig_to_face_height()` to produce `breakingFaceHeight` and `breakingHawaiianHeight`.
- Remove any NWPS-specific code paths in wave_transform.py (e.g., `data_source == "nwps"` checks). The input is `MarineForecastPoint` — source-agnostic.
- All four supplements (γ correction, structure effects, spatial interpolation, topographic focusing) must fire for SWAN+TruShore data. The supplements operate on Hsig BEFORE the face height conversion — they are unchanged.
- The full pipeline per forecast timestep is: SWAN Hsig → `swellHeight` → supplements → `waveHeightAtBreak` → breaker formula → `breakingFaceHeight` → ×0.5 → `breakingHawaiianHeight`.

**Accept:**
- `GET /surf/{spot_id}` with TruShore configured returns `waveHeightAtBreak` values that differ from `swellHeight` (confirming supplements were applied, not bypassed).
- `breakingFaceHeight` ≥ `waveHeightAtBreak` for all timesteps (face height conversion amplifies, does not reduce).
- Structure effects: a surf spot with a configured jetty shows a lower `waveHeightAtBreak` than `swellHeight` at that point (confirming Kt multiplication was applied).
- All four supplements confirmed active via log output (wave_transform.py should log at DEBUG level which supplements ran and their correction factors).

### T3.2 — Wire SWAN output through surf_scorer.py using HRRR wind and face height

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py`
- Reference: API-MANUAL §17 (surf quality scorer spec, wind source precedence); T0.2 ADR (HRRR wind source for TruShore mode); `docs/planning/briefs/WAVE-BREAKING-CONVERSION-BRIEF.md` §5 (scorer recalibration)

**Do:**
- In `surf_scorer.py`, change `score_surf()` to accept `breakingFaceHeight` (from T2.6) as the wave height input instead of `waveHeightAtBreak`. Recalibrate `_WAVE_HEIGHT_RANGES_FT` thresholds upward by ~15–20% to reflect face height values. The score must produce the same quality labels as before for typical conditions — this is a recalibration to a new height convention, not a redesign of the scoring logic.
- Add a `wind_source` parameter to `score_surf()`. When `wind_source == "hrrr_trushore"`, use the HRRR wind field (interpolated to the surf spot location and the relevant forecast timestep) instead of the station hardware wind observation.
- The HRRR wind for a given forecast timestep is already in the TruShore cache (it was the forcing wind for that SWAN run). Extract the HRRR wind at the surf spot coordinates and the timestep's `valid_time` for wind quality scoring.
- Wind quality scoring (offshore/cross_offshore/cross/cross_onshore/onshore classification) uses the same angle formula regardless of wind source — only the source of the U/V values changes.
- Station hardware wind source remains active for current-conditions snapshot scoring (the "now" card). HRRR wind is used for the 72-hour forecast timesteps.

**Accept:**
- Scorer uses `breakingFaceHeight` as wave height input: verified by unit test showing that two calls with identical Hsig but different periods (8s vs 16s) produce different height sub-scores (the longer period amplifies face height via Komar-Gaughan).
- `_WAVE_HEIGHT_RANGES_FT` thresholds are expressed in face-height feet. Typical SoCal conditions still produce the same quality labels as before (e.g., a 4ft Hsig at 14s was "Good" before; 4.6ft face height at 14s should still be "Good" or "Very Good").
- Wind quality scores vary across forecast timesteps (a morning sea-breeze pattern produces onshore wind during the day, potentially shifting to offshore at night — the HRRR forecast should reflect this).
- `windQualityScore` is non-null for all TruShore forecast timesteps.
- `windSource` field in `SurfForecast` response reflects `"hrrr_trushore"` for forecast timesteps and `"station"` or `"forecast_provider"` for the current-conditions snapshot.
- The "glassy" wind quality label (wind < 5 mph) applies correctly when HRRR reports winds below that threshold.

### T3.3 — Update surf endpoint to use SWAN+TruShore as sole source

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
- Reference: API-MANUAL §17 (data source hierarchy); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §5 (last-good-run fallback industry pattern)

**Do:**
- The surf endpoint uses `TrushoreProvider.fetch()` as its only data source. No config branch, no alternative model — SWAN+TruShore is the only nearshore model.
- Fallback chain: SWAN+TruShore (current cache) → SWAN+TruShore (last successful cache, any age) → no surf data (return null surf fields with a note "surf forecast unavailable"). Do NOT fall to WW3 for surf data.
- Add `nearshoreModel` field to the surf endpoint response: `"swan_trushore"`.
- Add `lastRunTime` field: ISO timestamp of when the SWAN run that produced this data completed.
- Add `breakerFormula` field: `"komar_gaughan"` or `"caldwell"` — which formula was used for this spot.
- Add `surfHeightDisplay` field: `"face"` or `"hawaiian"` — the operator's configured display preference for this spot. The dashboard uses this to select which height field to show as primary.
- All four height fields (`swellHeight`, `waveHeightAtBreak`, `breakingFaceHeight`, `breakingHawaiianHeight`) are present in every `SurfForecast` entry regardless of display preference. The API always returns all representations.

**Accept:**
- `GET /surf/{spot_id}` returns `nearshoreModel: "swan_trushore"`.
- `breakerFormula` and `surfHeightDisplay` reflect the spot's per-location config.
- All four height fields present and non-null for every forecast timestep.
- `lastRunTime` is present and reflects the SWAN run timestamp (not the request time).
- With SWAN unavailable (binary broken): response returns null surf fields with `error: "surf forecast unavailable"`. No WW3 fallback.
- With stale cache (last run 6 hours ago): response serves the stale cache with `dataAge: 21600`. Does not fall to WW3.

### T3.4 — Delete NWPS module and clean up all references

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Delete: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nwps.py`
  - Delete: `repos/weewx-clearskies-api/tests/providers/marine/test_nwps.py` (and any NWPS test fixtures)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/__init__.py` (remove NWPS registration)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/cache_warmer.py` (remove NWPS schedule entry)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py` (remove any remaining NWPS import or reference)
  - Modify: any config files or examples that reference `nwps` or `nearshore_model`

**Do:**
- Delete `providers/marine/nwps.py` and its tests. NWPS is eliminated — no dead code.
- Remove NWPS from the cache warmer schedule.
- Remove NWPS from the provider registry.
- Remove any `nearshore_model` config key — there is no choice to make. If `[nearshore]` extra is installed, SWAN+TruShore runs.
- Remove `nwps_wfo` from any config models or apply logic (the wizard resolved this per-location for NWPS grid selection — SWAN+TruShore uses its own configurable grid bbox instead).
- Grep the entire API codebase for "nwps" (case-insensitive) and remove all references. This includes imports, config parsing, error messages, comments, and test fixtures.
- Grep the stack repo for "nwps" and remove all references: `nwps_wfo` from config_writer.py, marine wizard step templates, admin marine section, and translation files. NWPS setup/admin UI is eliminated along with the code.

**Accept:**
- `grep -ri "nwps" repos/weewx-clearskies-api/` returns zero hits (excluding git history).
- `grep -ri "nwps" repos/weewx-clearskies-stack/` returns zero hits (excluding git history).
- No `nearshore_model` config key exists anywhere.
- API starts and serves surf data without any NWPS code present.
- All existing non-NWPS tests pass.

### T3.5 — Scope WaveWatch III correctly as marine (not surf) source

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/marine.py` (confirm WW3 still serves marine deep-water forecast)
- Reference: API-MANUAL §17 (WW3 role — boundary input to SWAN and marine deep-water endpoint, not surf fallback); T0.3 updates

**Do:**
- Remove WaveWatch III from the surf endpoint fallback chain. WW3 must not appear as a fallback for the surf endpoint.
- Confirm WaveWatch III continues to serve the marine endpoint's deep-water wave forecast (not affected by TruShore).
- Confirm WaveWatch III continues to be fetched by the TruShore pipeline as a boundary condition input (T2.3). The wavewatch.py provider is unchanged and continues to be called — just not for surf fallback.
- Add a code comment in `endpoints/surf.py`: "WaveWatch III (50km resolution) is not used as a surf forecast source. See API-MANUAL §17. WW3 data serves as SWAN boundary conditions via TrushoreProvider."

**Accept:**
- `GET /surf/{spot_id}` response never shows `waveDataSource: "wavewatch"`.
- `GET /marine/{location_id}` response continues to show WaveWatch III deep-water wave data.
- TruShore pipeline continues to fetch WW3 for boundary conditions (verify via WW3 cache hit logs).

### QC Gate 3

- `GET /surf/{spot_id}` returns varying `swellHeight`, `breakingFaceHeight`, `wavePeriod`, and `waveDirection` across all 144 forecast timesteps — not identical values.
- All four height fields present in every `SurfForecast` entry: `swellHeight`, `waveHeightAtBreak`, `breakingFaceHeight`, `breakingHawaiianHeight`.
- `breakingFaceHeight` > `swellHeight` for ground swell conditions (period ≥ 12s), confirming supplements + face height conversion are active.
- `breakingHawaiianHeight` = `breakingFaceHeight × 0.5` for all timesteps.
- All four wave_transform.py supplements fire for SWAN+TruShore data (verify via DEBUG logs or supplement-specific unit tests).
- Scorer uses `breakingFaceHeight`: `qualityStars` varies with period for the same Hsig.
- `windQualityScore` varies across forecast timesteps, reflecting the HRRR forecast wind pattern.
- `windSource` field correctly reflects "hrrr_trushore" for forecast timesteps.
- `nearshoreModel: "swan_trushore"` is present in the surf response.
- `breakerFormula` and `surfHeightDisplay` fields present and reflect per-spot config.
- WaveWatch III never appears as a surf data source.
- `grep -ri "nwps" repos/weewx-clearskies-api/` returns zero hits (T3.4 cleanup confirmed).
- All Phase 1 and 2 test baselines hold.

---

## Phase 4 — Separated Service Option 🔄 IN PROGRESS

Operators who want to run SWAN on dedicated hardware (a more powerful machine, a cloud VM) can install the standalone TruShore service. This phase implements that option.

> **Session 2 progress (2026-07-17):** T4.1–T4.3 complete and committed. T4.4/T4.5 code written (wizard template, admin template, routes, state, config_writer) and committed as WIP — **translation keys (13 locales) and Operator Manual (T4.6) still pending.** See `docs/planning/SWAN-TRUSHORE-PROGRESS.md` for full commit list and remaining work. Known issue: `step_trushore.html` uses Jinja2 `{% do %}` extension — verify it's enabled in the app's Jinja2 env before testing.

### T4.1 — Create `weewx-clearskies-trushore` pip package

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New repo: `repos/weewx-clearskies-trushore/` (new repository, minimal)
  - New: `repos/weewx-clearskies-trushore/weewx_clearskies_trushore/service.py` — FastAPI service exposing TruShore results
  - New: `repos/weewx-clearskies-trushore/weewx_clearskies_trushore/runner.py` — SWAN runner wrapper (imports from `weewx-clearskies-api[nearshore]` or reimplements)
  - New: `repos/weewx-clearskies-trushore/systemd/weewx-clearskies-trushore.service`
  - New: `repos/weewx-clearskies-trushore/pyproject.toml`
- Reference: ARCHITECTURE.md (TruShore standalone service note added in T0.5); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §6 (separated service design)

**Do:**
- The standalone TruShore service is a minimal FastAPI application:
  - `GET /health` — returns `{"status": "ok", "last_run": "<ISO timestamp>", "spots": [...]}`
  - `GET /surf/{spot_id}/forecast` — returns the TruShore MarineForecastPoint list for the spot (identical schema to the surf endpoint's wave data subset)
  - `POST /trigger` — manually trigger a SWAN run (for testing)
- The service reads config from `/etc/weewx-clearskies/trushore.conf` (same config format as api.conf for the relevant `[marine]` and `[trushore]` sections).
- The service publishes results to a local Redis instance (same Redis the API uses, if on the same host; or a separate Redis if on a different machine) keyed identically to how TrushoreProvider caches them.
- When the API is configured with `[trushore] service_url = http://<remote-host>:8767`, it reads from that endpoint instead of running SWAN locally.
- Systemd unit: `weewx-clearskies-trushore.service`, ExecStart points to the installed package entry point.

**Accept:**
- `pip install weewx-clearskies-trushore` installs the standalone service with SWAN binary and dependencies.
- `GET /health` returns a valid response from a running standalone instance.
- `GET /surf/{spot_id}/forecast` returns TruShore wave data for a configured spot.
- API configured with `service_url = http://localhost:8767` retrieves data from the standalone service (not from a local SWAN run).
- Isolated test: run standalone TruShore on the same weewx host as the API, configure `service_url = http://localhost:8767`, verify identical output vs. bundled mode.

### T4.2 — Add `service_url` config option to API

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/trushore.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py`
- Reference: ARCHITECTURE.md (optional remote topology); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §6

**Do:**
- Add `[trushore]` config section to `marine_config.py`:
  ```
  [trushore]
  service_url = http://localhost:trushore   # default: bundled mode (local subprocess)
  ```
- When `service_url` is not the default sentinel, `TrushoreProvider.fetch()` calls the remote HTTP endpoint instead of running SWAN locally. The returned data goes through the same cache.
- The API does not run the local SWAN runner when `service_url` points to a remote host.
- Config validation: if `service_url` is set but points to an unreachable host, log ERROR at startup and fall back to bundled mode (if SWAN is installed locally). Document this fallback behavior.

**Accept:**
- Config loads without error when `[trushore] service_url` is present.
- With `service_url = http://remote:8767`: API calls the remote endpoint, not the local SWAN runner.
- With `service_url = http://unreachable:8767`: API falls back to bundled mode with ERROR log.
- Wizard SWAN+TruShore step (T4.4) presents `service_url` only when operator selects the separated service deployment mode.

### T4.3 — Health check and unreachable-service fallback

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/trushore.py`
- Reference: API-MANUAL §17 (T3.3 fallback chain — same policy, extended to cover remote service)

**Do:**
- `TrushoreProvider` polls `GET {service_url}/health` every 60 seconds when in remote mode. If health check fails three times consecutively, log ERROR "TruShore remote service unreachable" and serve the last successful cache.
- The surf endpoint's response includes `lastRunTime` from the TruShore service's last completed SWAN run (available in the health check response).
- No fallback to WW3 for surf data, consistent with T3.3. Serve stale TruShore cache indefinitely on remote service failure. Log warnings at increasing intervals.

**Accept:**
- With remote service down: API serves stale TruShore cache (last successful data) with `dataAge` reflecting how long ago that run completed.
- With remote service back up: API resumes fresh data on the next health check cycle (within 60 seconds).
- `dataAge` accurately reflects the age of the SWAN output, not the age of the API's last cache fetch.

### T4.4 — Add SWAN+TruShore setup to the wizard

- Owner: `clearskies-api-dev` (Sonnet) + `clearskies-docs-author` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_trushore.html`
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py` (add step)
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/config_writer.py` (write `[trushore]` config)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` (accept `[trushore]` in apply payload)
  - Modify: all 13 locale translation files in `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/`
- Reference: OPERATIONS-MANUAL §1 (wizard step patterns); existing marine wizard step for reference

**Do:**
- Add a SWAN+TruShore wizard step (shown only when the `[nearshore]` pip extra is detected via the existing eccodes-style check pattern — `GET /setup/marine/swan-check`).
- Step presents two deployment modes:
  - **Bundled** (default): SWAN runs as a subprocess inside the API. No additional config needed beyond the SWAN binary being on PATH.
  - **Separated service**: Operator provides `service_url` pointing to a remote SWAN+TruShore instance. Step validates connectivity with a test request to `{service_url}/health`.
- Step also collects:
  - SWAN computational grid bounding box (pre-filled from the marine location coordinates configured in an earlier wizard step, with a default margin of ±0.2°).
  - Grid resolution (default 200m, configurable).
- **Per-spot surf config fields** (shown for each spot with `surf` activity enabled):
  - **Breaker formula** (`breaker_formula`): `komar_gaughan` (default) or `caldwell`. Help text explains: Komar-Gaughan is a general-purpose formula suitable for most coastlines. Caldwell is empirically tuned for steep volcanic island coasts (Hawaii, Indonesia, Tahiti) and auto-falls to Komar-Gaughan for short-period swell (< 10s).
  - **Surf height display** (`surf_height_display`): `face` (default) or `hawaiian`. Help text explains: Face height measures trough-to-crest of the breaking wave face (standard in US mainland, Europe). Hawaiian/traditional measures from the back of the wave (~half face height, standard in Hawaii and Australia).
- Add a `GET /setup/marine/swan-check` endpoint that probes whether the SWAN binary is available on PATH and returns `{"available": true/false, "version": "41.xx", "path": "/usr/local/bin/swan"}`.
- All labels, descriptions, help text, and error messages must use i18n translation keys. Add keys to all 13 locale JSON files (English values first; translations follow the existing pattern of marking new keys for translator review).
- Step-level help content: `help.wizard.trushore.*` keys explaining what SWAN+TruShore is, what the deployment modes mean, and how to install the SWAN binary if missing. Follow the existing `ConfigField.help_text` pattern.

**Accept:**
- Wizard step renders and functions in all 13 locales.
- SWAN binary check blocks the step with install instructions if SWAN is not found.
- Bundled mode: step completes with no `service_url` in the apply payload.
- Separated mode: step validates connectivity before allowing next.
- Apply payload includes `[trushore]` section; API's `ApplyRequest` model accepts it without 422.
- All strings are i18n-keyed; no hardcoded English in templates.

### T4.5 — Add SWAN+TruShore section to admin

- Owner: `clearskies-api-dev` (Sonnet) + `clearskies-docs-author` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/trushore.html`
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/config/routes.py` (add admin section)
  - Modify: all 13 locale translation files
- Reference: existing admin marine section for patterns; OPERATIONS-MANUAL (admin section patterns)

**Do:**
- Add a SWAN+TruShore section under the admin marine configuration area. The section allows operators to:
  - Switch between bundled and separated deployment modes.
  - Update `service_url` for separated mode (with connectivity test button).
  - View current SWAN+TruShore status: last run time, SWAN version, grid bbox, resolution.
  - Trigger a manual SWAN run (calls `POST /trigger` on the service or bundled runner).
  - **Per-spot surf settings** (editable per surf location): breaker formula (Komar-Gaughan / Caldwell) and surf height display preference (face / Hawaiian). Changes apply via `/setup/apply` same as other per-spot config.
- Admin section reads current config from `/setup/current-config` (same pattern as other admin sections).
- All strings use i18n translation keys. Add `help.admin.trushore.*` keys for the admin help panel.

**Accept:**
- Admin section renders and functions in all 13 locales.
- Deployment mode switch applies via `/setup/apply` without 422.
- SWAN+TruShore status (last run, version, grid) displays correctly.
- Manual trigger fires a SWAN run and reports completion.
- All strings are i18n-keyed.

### T4.6 — Update Operator Manual for SWAN+TruShore setup

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md`
- Reference: OPERATIONS-MANUAL §1 (native dependency documentation pattern)

**Do:**
- Add a "SWAN+TruShore Nearshore Model" section to the Operator Manual documenting:
  - Prerequisites: SWAN binary installation (`install_swan.sh` or `apt install` on Debian), gfortran, OpenMP.
  - Wizard setup flow: what each field means, bundled vs. separated mode.
  - Admin maintenance: how to check status, trigger manual runs, switch modes.
  - Troubleshooting: common SWAN errors, missing binary, grid resolution tuning.
- Follow the existing native dependency documentation pattern (eccodes section).

**Accept:**
- Operator Manual has a complete SWAN+TruShore section.
- Prerequisites are documented with platform-specific install commands.
- Both deployment modes are documented with when to use each.

### QC Gate 4

- Standalone `weewx-clearskies-trushore` service starts and returns health and forecast data.
- API in remote mode (`service_url` set): data matches bundled mode output for the same HRRR cycle.
- Remote service failure: API serves stale cache, logs ERROR, never falls to WW3.
- Remote service recovery: API resumes fresh data within 60 seconds of health check recovery.
- No regression in bundled mode (the default, no `service_url` set).
- Wizard SWAN+TruShore step functional in all 13 locales.
- Admin SWAN+TruShore section functional in all 13 locales.
- Operator Manual SWAN+TruShore section present and complete.
- All wizard/admin i18n keys present in all 13 locale files.

---

## Phase 5 — Dashboard Integration and Polish 🔄 IN PROGRESS

The dashboard surf tab already has a 72-hour forecast card that shows wave data. With TruShore providing varying per-timestep data, the visualization should display meaningful variation rather than a flat line.

> **Session 2 progress (2026-07-17):** T5.1 and T5.2 implemented and committed (types.ts, openapi, 14 locale files, SurfingTab height field switch + NearshoreModelIndicator). T5.3 verified (no code change needed). TypeScript type-check passes. **Pending:** axe-core a11y scan of NearshoreModelIndicator not yet run — must run before release sign-off. See `docs/planning/SWAN-TRUSHORE-PROGRESS.md` for commits and remaining work.

### T5.1 — Verify 72-hour forecast card displays varying TruShore data

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Review: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx` (or equivalent)
  - Review: surf forecast chart/table component
- Reference: DASHBOARD-MANUAL §12 (surf tab behavior); API-MANUAL §17 (SurfForecast response shape)

**Do:**
- Load `GET /surf/{spot_id}` with TruShore data active and verify the 72-hour chart/table correctly renders per-timestep wave height, period, and surf score.
- The chart's primary height value must come from the operator's configured `surfHeightDisplay` preference (returned in the surf response): use `breakingFaceHeight` when `surfHeightDisplay: "face"`, use `breakingHawaiianHeight` when `surfHeightDisplay: "hawaiian"`. The API returns all four height fields — the dashboard selects which to display.
- If the dashboard hardcoded handling for "identical values across timesteps" (which was the WW3 fallback behavior), remove that workaround. TruShore data varies — the chart should show the variation.
- Verify time axis: forecast timesteps should display in the operator's configured timezone, not UTC.
- Verify units: wave height displayed in the operator's `group_wave_height` configured unit (feet or meters), not always meters.

**Accept:**
- 72-hour surf forecast chart shows a curve, not a flat line, for a real TruShore SWAN run.
- Chart plots `breakingFaceHeight` (or `breakingHawaiianHeight` per operator config) — NOT `swellHeight` or `waveHeightAtBreak`.
- Time axis is in the operator's configured timezone.
- Wave height is in the configured unit (feet for US preset).
- Chart handles edge cases: null surf data (SWAN unavailable) shows an appropriate empty/error state.

### T5.2 — Add data source indicator on surf tab

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Modify: relevant surf tab components
- Reference: DESIGN-MANUAL (attribution badge pattern if one exists); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §7 (TruShore name)

**Do:**
- Add a data source indicator on the surf tab showing: "Model: SWAN+TruShore" (from `nearshoreModel: "swan_trushore"` in the API response).
- Include a small tooltip or info icon that explains: "SWAN+TruShore is the Clear Skies nearshore wave model powered by SWAN, running on an hourly schedule independent of NWS operations."
- Placement: footer of the surf forecast card, or alongside the "Last updated" timestamp. Consistent with how other data source attributions appear on the dashboard.
- `lastRunTime` from the API response: display as "Last model run: [relative time]" (e.g., "34 minutes ago").
- All user-facing strings (indicator label, tooltip) must use i18n translation keys, not hardcoded English.

**Accept:**
- "Model: SWAN+TruShore" indicator visible on the surf tab.
- Tooltip text is present and accessible (keyboard focusable, screen reader compatible).
- `lastRunTime` displays as a relative timestamp.
- All strings are i18n-keyed (no hardcoded English in component JSX).

### T5.3 — Update current conditions card to use TruShore snapshot

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Review: Now page marine summary card component
- Reference: DASHBOARD-MANUAL §12 (marine card data sources per ADR-091); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §7

**Do:**
- The Now page marine summary card shows `surfRating` stars. Verify this value is sourced from TruShore's current-conditions output (the `t=0` timestep of the TruShore forecast) when TruShore is configured.
- The current-conditions surf score uses the same surf_scorer.py scoring logic as the forecast. The wind source for `t=0` follows the station hardware → forecast provider precedence (per T0.2 ADR — HRRR wind is for forecast timesteps; `t=0` uses current-conditions wind if available).
- No chart changes needed for the Now page — just confirm the data source is correct.

**Accept:**
- `surfRating` on the Now page reflects SWAN+TruShore's `t=0` output.
- Wind source for `t=0` scoring: station hardware if available, HRRR `t=0` otherwise.

### QC Gate 5

- 72-hour surf forecast chart shows varying data (wave height curve, not flat line) for real TruShore output.
- Data source indicator "Model: SWAN+TruShore" visible and accessible on surf tab.
- `lastRunTime` relative timestamp displayed correctly.
- Current conditions surf rating sourced from TruShore.
- Dashboard vitest baseline holds.
- All surf tab strings are i18n-keyed.

---

## Phase 6 — Final QA: Adversarial Meta-Audit

This phase re-validates everything independently after implementation is complete. All acceptance criteria from previous phases are verified by a separate auditor agent with no shared context from implementation agents.

### T6.1 — QC gate integrity audit

- Owner: `clearskies-auditor` (Sonnet)
- Reading list: every QC Gate from Phases 0–5 in this plan; current state of `docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`, `docs/ARCHITECTURE.md`

**Do:**
- Re-run every QC gate check from Phases 0–5 as if for the first time. Do not trust implementation agent reports.
- For each QC gate item: run the verification command, observe the actual output, record pass/fail.
- Report all failures, even those that were previously marked as passed.

**Accept:**
- All QC gate items pass independently.
- No acceptance criterion was silently skipped or "verified" without evidence.

### T6.2 — Silent deferral sweep

- Owner: `clearskies-auditor` (Sonnet)
- Reading list: this plan (every T-numbered task); `git log --oneline` for all repos modified

**Do:**
- Walk every task in Phases 0–5. For each task: confirm it has a corresponding commit in git log, or is explicitly documented as deferred with a reason.
- Report any task that has no corresponding commit and no documented deferral.
- This is the backstop against "we said we'd do it later and forgot."

**Accept:**
- Every task is either committed (cite hash) or documented as deferred with explicit reasoning and a tracking location.
- No task exists in an undocumented limbo state.

### T6.3 — Manual-code consistency verification

- Owner: `clearskies-auditor` (Sonnet)
- Reading list: `docs/manuals/API-MANUAL.md` §17; `docs/manuals/PROVIDER-MANUAL.md` §14.{HRRR}, §14.{TruShore}; `docs/ARCHITECTURE.md`; relevant source files

**Do:**
- For each claim in the updated §17 and PROVIDER-MANUAL sections, trace the claim to the implementing code.
- Examples to check: wind rotation step documented → find the rotation code; SWAN grid resolution default documented → find the config constant; WW3 excluded from surf fallback documented → find the endpoint code that excludes it.
- Report any documented behavior that is not implemented, or implemented behavior that is not documented.

**Accept:**
- Every documented behavior has corresponding implementation.
- Every implemented behavior is documented.
- No claim in the manuals refers to code that does not exist.

### T6.4 — End-to-end validation: SWAN+TruShore output sanity check

- Owner: `clearskies-auditor` (Sonnet)
- Environment: live weewx host

**Do:**
- Compare SWAN+TruShore output at a surf spot against the nearest NDBC coastal buoy observations for the same time period:
  - Hs (significant wave height): should be physically reasonable for the nearshore environment (typically lower than offshore buoy due to bottom friction).
  - Tm01 (mean period): should be within ±3s of buoy-observed dominant period.
  - MWD (mean wave direction): should be consistent with the regional swell direction.
- Verify physically impossible values are absent in live output (Hs > 20m, Tm01 < 1s, MWD out of range, NaN).
- Verify wave data varies across forecast timesteps in the live surf endpoint response.
- Verify `grep -ri "nwps" repos/weewx-clearskies-api/` returns zero hits — NWPS is fully eliminated.

**Accept:**
- Sanity check results documented (pass/fail per metric, with observed values).
- No physically impossible values in live output.
- Wave data varies across forecast timesteps.
- No NWPS code or references remain in the API codebase.

### T6.5 — Performance verification

- Owner: `clearskies-auditor` (Sonnet)
- Environment: live weewx host

**Do:**
- Trigger a SWAN run and time it from `POST /trigger` to `GET /health` showing an updated `last_run`.
- Verify SWAN runs complete within 15 minutes on the weewx host hardware.
- Verify API response time for `GET /surf/{spot_id}` is unaffected by a concurrent SWAN run (SWAN runs in background — the API serves from cache while SWAN is running).
- Verify memory usage during SWAN run does not exhaust the weewx host (expected peak: 100–300 MB for the SWAN process, verify against actual measurements).

**Accept:**
- SWAN run completes in <15 minutes.
- API response time for `/surf/{spot_id}` is <500ms during a concurrent SWAN run (served from cache).
- Peak SWAN memory usage documented.
- No OOM kill during SWAN run.

---

## Phase 7 — Remedial: Nested Grid Architecture + GFS Wind + 72-Hour Forecast

**Added 2026-07-17.** Phases 1–6 implemented SWAN with a single flat grid (462×555, 200m resolution over a 1° domain). Production deployment on 2026-07-17 revealed two critical issues:

1. **Memory:** The flat grid produces ~257,000 grid points requiring ~1.3 GB RAM. The weewx host has 1.9 GB total — SWAN was OOM-killed after 15 minutes of swap-thrashing. Every operational nearshore system uses nested grids (coarse outer + fine inner), not flat grids. See research brief §2 "Grid Configuration: Nested Grids."
2. **Forecast range:** HRRR extends to only 18 or 48 hours depending on the cycle (4 extended cycles/day reach 48h; the other 20 reach only 18h). The dashboard's 72-hour surf forecast card requires 72 hours of wind forcing. NWPS used GFS wind (extends to 384h). See research brief §4 "HRRR Forecast Range Limitation."

**All document and manual updates in T7.0 must be completed BEFORE any coding work in T7.1–T7.5.** The Phases 1–6 pattern of coding first and documenting later led to the flat-grid estimate going unvalidated. Documents first forces the design to be reviewed before implementation.

### T7.0 — Document and manual updates (BEFORE coding)

- Owner: Coordinator (Opus)
- Files:
  - `docs/manuals/API-MANUAL.md` §17 — update SWAN+TruShore description to specify nested grid architecture (outer grid + inner nest), GFS wind for hours 48–72, and memory budget (≤300 MB combined)
  - `docs/manuals/PROVIDER-MANUAL.md` — add §14.{next} GFS wind provider: module identity (`providers/wind/gfs.py`, PROVIDER_ID `gfs`, DOMAIN `wind`), NOMADS URL, 0.25° resolution, forecast range 384 hours, cache TTL
  - `docs/manuals/PROVIDER-MANUAL.md` §14.{HRRR} — amend to document the 18/48-hour forecast range limitation and the blended wind approach
  - `docs/manuals/PROVIDER-MANUAL.md` §14.{TruShore} — amend to document nested grid architecture (two sequential SWAN runs per cycle) and the memory budget
  - `docs/ARCHITECTURE.md` — update SWAN subprocess description to specify nested grid execution and GFS wind provider
  - `docs/manuals/OPERATIONS-MANUAL.md` — update SWAN+TruShore section (§5) to document nested grid parameters visible in wizard/admin (outer resolution, inner resolution, nest domain)

**Accept:** All governing documents describe the nested grid architecture and GFS wind supplement before any code is written. No document references a flat single-grid SWAN configuration.

### T7.1 — Implement GFS wind provider

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/wind/gfs.py`
- Reference: PROVIDER-MANUAL §14.{GFS section from T7.0}

**Do:**
- Implement `providers/wind/gfs.py` with `PROVIDER_ID = "gfs"`, `DOMAIN = "wind"`.
- Fetch GFS 0.25° forecast wind (U/V at 10m AGL) from NOMADS Grib Filter for a configurable bounding box.
- GFS forecast hours: f00–f384, 3-hour timesteps. For TruShore, fetch hours 48–72 (or the full range for simplicity).
- Cache with TTL matching GFS cycle cadence (6 hours).
- Follow the same provider module patterns as `providers/wind/hrrr.py`.

**Accept:**
- `fetch(bbox=..., hours_start=48, hours_end=72)` returns a wind field for the requested forecast range.
- GFS wind values at coastal sites are physically reasonable.
- Unit tests cover: successful fetch, 404 handling, wind rotation (if GFS uses a non-earth-relative grid).

### T7.2 — Implement nested grid SWAN runner

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py`
- Reference: PROVIDER-MANUAL §14.{TruShore section from T7.0}; research brief §2 "Grid Configuration: Nested Grids"

**Do:**
- Modify `swan_runner.py` to execute two sequential SWAN runs per cycle:
  1. **Outer grid:** ~2–3 km resolution, large domain (from `MarineConfig.hrrr_bbox`). Writes `NESTOUT` command to produce boundary files for the inner nest.
  2. **Inner nest:** ~200–500m resolution, tight domain around surf spots (from `MarineConfig.swan_domain_bbox`). Reads outer grid boundary via `NGRID` command.
- Modify `marine_config.py` to add `outer_grid_resolution_km` and `inner_nest_resolution_m` config fields with appropriate defaults.
- Modify `swan_formats.py` to generate input files for both grid levels.
- Stitch HRRR wind (hours 0–48) and GFS wind (hours 48–72) into a single SWAN WIND input spanning 72 hours.

**Accept:**
- Two SWAN runs complete per cycle (outer + inner), total memory ≤300 MB.
- Inner nest produces output at configured surf spot coordinates.
- Wave data spans 72 forecast hours (not limited to 18 or 48).
- SWAN completes within 15 minutes total (both levels) on the weewx host.
- No OOM kill during a full cycle.

### T7.3 — Update cache warmer and TruShore provider for nested execution

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/cache_warmer.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/trushore.py`

**Do:**
- Cache warmer: fetch both HRRR (hours 0–48) and GFS (hours 48–72) wind, pass both to TruShore as a single combined wind field.
- TruShore `run_all_spots()`: run outer grid first, then inner nest, using outer grid boundary output.
- Schedule: run on extended HRRR cycles (00/06/12/18Z, 4×/day) to get the full 48-hour HRRR range. GFS supplements to 72 hours.
- Cache TTL: 6 hours (matches extended cycle interval).

**Accept:**
- `GET /surf/{spot_id}` returns 72 hours of forecast data.
- HRRR wind used for hours 0–48, GFS for hours 48–72.
- `windSource` field correctly reflects `"hrrr_trushore"` for hours 0–48 and `"gfs_trushore"` for hours 48–72.
- SWAN memory stays under 300 MB during execution.

### T7.4 — Wizard/admin updates for nested grid parameters

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: wizard and admin templates for TruShore step
  - Modify: all 13 locale translation files

**Do:**
- Update wizard TruShore step to display nested grid parameters (outer resolution, inner resolution) instead of the single flat grid resolution.
- Update admin TruShore section similarly.
- Add translation keys for new/changed labels.

**Accept:**
- Wizard and admin display nested grid parameters.
- All strings i18n-keyed.

### T7.5 — End-to-end verification and Phase 6 completion

- Owner: `clearskies-auditor` (Sonnet)

**Do:**
- Verify SWAN produces 72 hours of varying wave data at the configured surf spot.
- Verify memory stays under 300 MB during SWAN execution.
- Verify SWAN completes in <15 minutes.
- Compare SWAN output against nearest NDBC buoy for physical reasonableness.
- Complete T6.4 and T6.5 (blocked since Phase 6 by the flat-grid OOM issue).
- Run full QC gate sweep across all phases.

**Accept:**
- All Phase 6 (T6.1–T6.5) acceptance criteria met.
- 72-hour surf forecast card on dashboard shows a wave height curve, not a flat line.
- SWAN memory ≤300 MB, runtime ≤15 minutes, no OOM kill.

---

## Verification

After all phases complete (including Phase 7 remedial):

- Surf endpoint returns varying wave data across all 144 forecast timesteps
- All four height fields present in every `SurfForecast` entry: `swellHeight`, `waveHeightAtBreak`, `breakingFaceHeight`, `breakingHawaiianHeight`
- `breakingFaceHeight` increases with period for the same Hsig (Komar-Gaughan period dependence confirmed)
- `breakingHawaiianHeight` = `breakingFaceHeight × 0.5` for all timesteps
- All four wave_transform.py supplements fire for SWAN+TruShore data (γ correction, structure effects, spatial interpolation, topographic focusing) — supplements apply to Hsig BEFORE face height conversion
- Scorer uses `breakingFaceHeight` — `qualityStars` reflects face height, not raw Hsig
- Wind quality in surf score reflects HRRR forecast wind, not station observation, for forecast timesteps
- `nearshoreModel: "swan_trushore"` appears in surf endpoint responses
- `breakerFormula` and `surfHeightDisplay` fields present and reflect per-spot config
- Per-spot config: `breaker_formula` (komar_gaughan / caldwell) and `surf_height_display` (face / hawaiian) configurable via wizard and admin
- Caldwell auto-crossover: with `breaker_formula = caldwell`, timesteps with Tp < 10s automatically use Komar-Gaughan
- `lastRunTime` reflects SWAN run completion time
- WaveWatch III never appears as a surf endpoint data source
- NWPS is fully eliminated: `grep -ri "nwps" repos/weewx-clearskies-api/` returns zero hits
- No `nearshore_model` config key exists — SWAN+TruShore is the only nearshore model
- WaveWatch III continues to serve the marine endpoint and as SWAN boundary conditions via `providers/marine/wavewatch.py`
- Standalone `weewx-clearskies-trushore` service starts and serves data (Phase 4)
- 72-hour surf forecast chart on dashboard shows a curve, not a flat line, using `breakingFaceHeight` or `breakingHawaiianHeight` per operator display preference
- "Model: SWAN+TruShore" indicator visible on surf tab, i18n-keyed
- Wizard/admin SWAN+TruShore setup section functional with i18n-compliant help content, including per-spot breaker formula and surf height display fields
- All governing documents (API-MANUAL §17, PROVIDER-MANUAL, ARCHITECTURE.md) match implemented code — no NWPS references remain
- Phase-boundary ADR compliance sweep: every ADR that touches marine/surf/nearshore is verified against the SWAN+TruShore implementation
- All test baselines established at phase kickoff hold at plan completion
