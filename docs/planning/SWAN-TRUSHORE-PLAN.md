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
| `docs/manuals/API-MANUAL.md` §17 | Current wave_transform.py supplements, surf_scorer.py scoring rules, wind source precedence, NWPS/WW3 fallback behavior |
| `docs/manuals/PROVIDER-MANUAL.md` §14.3, §14.6 | WaveWatch III module identity and ERDDAP access, NWPS module identity and error handling |
| `docs/manuals/OPERATIONS-MANUAL.md` §1 | Native install pip extras pattern (model for `[nearshore]` extra) |
| `rules/clearskies-process.md` | Agents must read source documents directly; git restrictions; deploy scripts; verification mandate |

**Agents must read source documents directly — NEVER paraphrase manuals or plans into agent prompts.** The coordinator tells agents WHICH files to read and WHICH sections are relevant. The agent reads the original text. See `rules/clearskies-process.md` "Agents must read source documents directly."

**Git restrictions (mandatory in every agent prompt):**

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

**Agents edit and commit on the local machine only.** All source code editing and `git commit` happens on the local machine at `c:\CODE\weather-belchertown\repos\weewx-clearskies-*`. SSH to containers is for READ-ONLY verification: running tests, reading logs, checking service status. Never edit source files on weewx or weather-dev.

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

**NWPS deprecation order:** NWPS is not removed until Phase 3 T3.4. Until then it continues to serve as legacy fallback while TruShore is validated alongside it. Never remove the NWPS module before T3.4 acceptance criteria are met.

---

## Phase 0 — ADR & Manual Updates

Before any code is written, the governing documents must describe the architecture we are building toward. This gives dev agents a correct reading list and prevents them from implementing against stale contracts.

### T0.1 — Draft ADR: SWAN + TruShore nearshore model decision

- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-{next}.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` (full), `docs/decisions/_TEMPLATE.md`

**Do:**
- Draft an ADR (status: Proposed) documenting the decision to run our own SWAN instance (TruShore) instead of depending on NWPS.
- Follow the Nygard format per `docs/decisions/_TEMPLATE.md`.
- Decision section: 1–2 sentences. Context section: why NWPS is inadequate (from §1 of the research brief). Options considered: NWPS dependency (current), NWPS with extended cache TTL (partial mitigation), own SWAN instance (chosen). Consequences: SWAN binary dependency, HRRR provider needed, NWPS downgraded to legacy. Implementation guidance: pip extra `[nearshore]`, config key `[marine] nearshore_model`.
- Keep to ~80 lines per ADR content standards in `rules/clearskies-process.md`.

**Accept:**
- ADR exists as Proposed in `docs/decisions/`.
- All required Nygard sections are present (Status, Context, Options, Decision, Consequences, Implementation guidance, References).
- Options table includes all three options evaluated.
- User reviews and approves before status changes to Accepted.

### T0.2 — Draft ADR: surf wind source (HRRR forecast wind)

- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-{next+1}.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §4, `docs/manuals/API-MANUAL.md` §17 "Wind source for surf quality scoring"

**Do:**
- Draft an ADR (status: Proposed) documenting the change in wind source for surf quality scoring from the current precedence chain (station hardware → forecast provider) to HRRR forecast wind as the canonical source for TruShore-driven surf forecasts.
- Context: current rule prefers station hardware, but station hardware is a real-time observation — not a forecast. For 72-hour surf forecasts, HRRR forecast wind (the same model that forces SWAN) is the correct source. Station hardware remains correct for the current-conditions snapshot but not for forecast timesteps.
- Decision: for TruShore-sourced surf forecasts, wind source = HRRR (the same model run that drove SWAN). The current station hardware → forecast provider rule applies only when nearshore_model is set to `nwps` (legacy) or when scoring current conditions.
- Implementation guidance: surf_scorer.py receives wind data with a `source` tag; when source is `hrrr_trushore`, the station hardware lookup is bypassed.

**Accept:**
- ADR exists as Proposed.
- Decision clearly distinguishes between current-conditions scoring (station hardware) and forecast scoring (HRRR).
- No conflict with existing §17 rule — the existing rule applies to NWPS mode; the new rule applies to TruShore mode.
- User approves before Accepted status.

### T0.3 — Update API-MANUAL §17 — TruShore as nearshore model

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §2, §6, §7; current §17 text

**Do:**
- Add a sub-section under §17 "NWPS supplement processor" documenting TruShore as the new default nearshore model when `[nearshore]` extra is installed.
- Document the HRRR wind sourcing rule for TruShore-mode forecasts (from T0.2 ADR).
- Document the SWAN integration: subprocess model, input sources (HRRR wind → SWAN, WW3 boundary conditions, CUDEM bathymetry, RTOFS tidal currents), output format (MarineForecastPoint per timestep).
- Update the no-fallback rule: when TruShore is configured, WW3 is NEVER used as the surf forecast source. WW3 remains the deep-water boundary input to SWAN and continues to serve the marine endpoint's deep-water forecast. The surf endpoint serves the last successful TruShore cache if the runner fails.
- Note NWPS as legacy mode (`nearshore_model = nwps`).

**Accept:**
- §17 correctly describes TruShore as the primary model when `[nearshore]` extra is installed.
- HRRR wind sourcing rule is documented with the distinction between forecast mode and current-conditions mode.
- WW3's role is correctly scoped: boundary input to SWAN + marine deep-water endpoint, never surf forecast primary source.
- NWPS is documented as legacy with a deprecation note.

### T0.4 — Update PROVIDER-MANUAL — HRRR wind provider + NWPS deprecation

- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §4 (HRRR access details); current §14.6 NWPS

**Do:**
- Add §14.{next} documenting the HRRR wind provider: module identity (`providers/wind/hrrr.py`, PROVIDER_ID `hrrr`, DOMAIN `wind`), NOMADS Grib Filter URL, AWS S3 backup URL, geographic bounding box config, U/V at 10m AGL variable names, grid-relative to earth-relative rotation requirement (`wgrib2 -new_grid_winds earth`), hourly fixed schedule, cache TTL.
- Update §14.6 NWPS: mark as "Legacy — superseded by TruShore when `[nearshore]` extra installed." Keep the full technical documentation intact (NWPS remains functional and supported for operators who set `nearshore_model = nwps`). Add a note at the top of the section: "**Legacy provider.** When `[nearshore]` pip extra is installed, the default nearshore model is TruShore (own SWAN instance). NWPS remains available via `[marine] nearshore_model = nwps`. See §14.{trushore section} for TruShore provider documentation."
- Add §14.{trushore} documenting the TruShore/SWAN runner: not a network provider but a local subprocess provider; SWAN binary dependency; input sources; output points format; cache key and TTL; run schedule tied to HRRR cycle.

**Accept:**
- HRRR wind provider fully documented: URL, variables, rotation requirement, schedule, TTL.
- NWPS §14.6 carries a legacy marker and a forward reference to TruShore.
- TruShore/SWAN runner documented as a local subprocess provider.
- No existing documented behavior removed (NWPS still works; it's just not the default).

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

### QC Gate 0

- All five documents (ADRs Proposed, API-MANUAL, PROVIDER-MANUAL, ARCHITECTURE.md) reflect a consistent architecture.
- ADRs are Proposed (not Accepted — user approval pending); no other documents say "Accepted" on behalf of the user.
- NWPS is documented as legacy, not removed.
- WW3's role is correctly limited: marine deep-water endpoint + SWAN boundary conditions.
- No manual update contradicts any existing Accepted ADR.
- Adversarial auditor (`clearskies-auditor`) reviews all five documents for internal consistency before Phase 1 begins.

---

## Phase 1 — HRRR Wind Provider

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
- The Lambert Conformal wind rotation formula: `rot_angle = lon_grid_point - lov`, then U_earth = U_grid × cos(rot_angle) - V_grid × sin(rot_angle), V_earth = U_grid × sin(rot_angle) + V_grid × cos(rot_angle). Source the exact HRRR Lambert parameters from the GRIB2 metadata (cfgrib or pygrib can extract them).
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
- Add a cache warmer entry for the HRRR wind provider, but only when `nearshore_model = trushore` is configured. The HRRR fetch should run at startup and on the hourly schedule (HRRR cycle cadence).
- The HRRR warm does NOT block the API startup — it fires async in the background. SWAN cannot run until HRRR data is warm, but the API can serve other endpoints while the first HRRR fetch completes.
- If HRRR warm fails at startup, log WARNING (not ERROR) — the SWAN runner will retry on the next hourly cycle.

**Accept:**
- API startup log shows HRRR cache warm attempt when `nearshore_model = trushore`.
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

## Phase 2 — SWAN Model Integration

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
- The API startup check: if `nearshore_model = trushore` is configured but SWAN binary is not found on PATH, log a CRITICAL error with installation instructions and fall back to `nearshore_model = nwps`.

**Accept:**
- `pip install weewx-clearskies-api[nearshore]` completes without error on a clean Ubuntu 22.04 system (after `apt install gfortran libopenmpi-dev`).
- `swan --version` returns a SWAN version string after `install_swan.sh` runs.
- API startup log shows "SWAN found at /usr/local/bin/swan, version 41.xx" when `[nearshore]` extra is installed.
- API startup falls back gracefully to `nearshore_model = nwps` with CRITICAL log when SWAN binary is not found.
- Docker image builds successfully with SWAN included.

### T2.2 — Implement SWAN runner service

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/services/__init__.py` (if not present)
- Reference: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §6, §7; API-MANUAL §17 (current NWPS supplement processor — output format this must match)

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
- Reference: API-MANUAL §17 (MarineForecastPoint format the NWPS provider also produces — TruShore must produce the same shape); PROVIDER-MANUAL §14.6 (NWPS output format for comparison)

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
- MarineForecastPoint objects from SWAN output match the same schema as NWPS-sourced MarineForecastPoint objects (verified by comparing API-MANUAL §17 field names).

### T2.5 — Integration with cache warmer: run SWAN on HRRR cycle schedule

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/cache_warmer.py` (or scheduling equivalent)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/trushore.py` (new provider wrapper)
- Reference: ARCHITECTURE.md (cache warmer startup sequence); PROVIDER-MANUAL §14.6 (NWPS cache TTL pattern to match or improve upon)

**Do:**
- Create `providers/nearshore/trushore.py` as a thin provider wrapper around `services/swan_runner.py`. This is the object the endpoint calls, matching the same provider interface as `providers/marine/nwps.py`.
- `TrushoreProvider.fetch(surf_spot_id, ...)`: retrieves HRRR wind, WW3 boundary, CUDEM bathymetry (all from cache — they run on their own schedules); calls `SWANRunner.run()`; caches results keyed by `(provider_id, spot_domain_id, hrrr_cycle_time)` with a TTL of 55 minutes (matching HRRR cycle cadence).
- SWAN runs in a background thread (not in the request path). The cache warmer fires the first SWAN run at startup (after HRRR and WW3 data are warm) and on the hourly schedule thereafter.
- If SWAN run fails: log ERROR, retain the last successful cache entry. Do NOT invalidate the cache on failure — stale TruShore data is always preferred to no data.
- Expose cache age in the surf endpoint response (e.g., `dataAge: 3420` seconds) so the dashboard can show when the last SWAN run completed.

**Accept:**
- `GET /surf/{spot_id}` returns TruShore data when `nearshore_model = trushore` is configured.
- Wave data varies across all 144 forecast timesteps (not identical values — this is the key regression vs. WW3 fallback).
- Data age is present in the response.
- SWAN run failure retains last-good cache: verify by temporarily breaking SWAN binary path, confirm API continues to serve (stale but non-null) surf data.
- SWAN completes within 15 minutes on the weewx host hardware (it will likely be 2–5 minutes; 15 minutes is the upper bound tolerance).

### QC Gate 2

- SWAN produces physically reasonable wave forecasts for the Huntington Beach test domain: Hs 0.3–3.0m, Tm01 8–16s for a typical SoCal winter swell.
- Wave data varies across forecast timesteps (not identical values across 144 hours).
- Compare TruShore Hs at surf spot against NWPS Hs at the same location for overlapping cycles: values should be within ±0.5m for typical conditions. Significant divergence indicates an input data or domain setup error.
- SWAN run completes within 15 minutes on weewx host.
- Cache retains last-good data on SWAN failure.
- All Phase 1 test baselines hold.
- Unit tests for SWAN runner and TruShore provider pass.

---

## Phase 3 — TruShore Post-Processing Integration

SWAN output replaces NWPS as the input to the existing wave_transform.py and surf_scorer.py processors. This is primarily wiring, not new code.

### T3.1 — Wire SWAN output through wave_transform.py

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/wave_transform.py` (if NWPS-specific assumptions exist)
- Reference: API-MANUAL §17 (NWPS supplement processor spec — same supplements must run on SWAN output); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §7

**Do:**
- In the surf endpoint, when `nearshore_model = trushore`, use `TrushoreProvider.fetch()` to get wave data instead of `NWPSProvider.fetch()`. Pass the resulting wave data to `wave_transform.apply_supplements()` exactly as NWPS data is currently passed.
- Verify that wave_transform.py makes no NWPS-specific assumptions about its input data format. The input to `apply_supplements()` is `MarineForecastPoint` — if SWAN produces the same format (T2.4), no changes to wave_transform.py are needed.
- If wave_transform.py has any code paths that check `data_source == "nwps"`, update those to also accept `data_source == "trushore"`.
- All four supplements (γ correction, structure effects, spatial interpolation, topographic focusing) must fire for TruShore data exactly as they do for NWPS data.

**Accept:**
- `GET /surf/{spot_id}` with TruShore configured returns `waveHeight` values that differ from the raw SWAN output (confirming supplements were applied, not bypassed).
- Structure effects: a surf spot with a configured jetty shows a lower wave height than the raw SWAN output at that point (confirming Kt multiplication was applied).
- All four supplements confirmed active via log output (wave_transform.py should log at DEBUG level which supplements ran and their correction factors).

### T3.2 — Wire SWAN output through surf_scorer.py using HRRR wind

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py`
- Reference: API-MANUAL §17 (surf quality scorer spec, wind source precedence); T0.2 ADR (HRRR wind source for TruShore mode)

**Do:**
- In `surf_scorer.py`, add a `wind_source` parameter to `score_surf()`. When `wind_source == "hrrr_trushore"`, use the HRRR wind field (interpolated to the surf spot location and the relevant forecast timestep) instead of the station hardware wind observation.
- The HRRR wind for a given forecast timestep is already in the TruShore cache (it was the forcing wind for that SWAN run). Extract the HRRR wind at the surf spot coordinates and the timestep's `valid_time` for wind quality scoring.
- Wind quality scoring (offshore/cross_offshore/cross/cross_onshore/onshore classification) uses the same angle formula regardless of wind source — only the source of the U/V values changes.
- Station hardware wind source remains active for current-conditions snapshot scoring (the "now" card). HRRR wind is used for the 72-hour forecast timesteps.

**Accept:**
- Wind quality scores vary across forecast timesteps (a morning sea-breeze pattern produces onshore wind during the day, potentially shifting to offshore at night — the HRRR forecast should reflect this).
- `windQualityScore` is non-null for all TruShore forecast timesteps.
- `windSource` field in `SurfForecast` response reflects `"hrrr_trushore"` for forecast timesteps and `"station"` or `"forecast_provider"` for the current-conditions snapshot.
- The "glassy" wind quality label (wind < 5 mph) applies correctly when HRRR reports winds below that threshold.

### T3.3 — Update surf endpoint to use TruShore as primary source

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
- Reference: API-MANUAL §17 (data source hierarchy); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §5 (last-good-run fallback industry pattern)

**Do:**
- Add config branch: `if config.marine.nearshore_model == "trushore": use TrushoreProvider else: use NWPSProvider`.
- TruShore primary fallback chain: TruShore (current cache) → TruShore (last successful cache, any age) → no surf data (return null surf fields with a note "surf forecast unavailable"). Do NOT fall to WW3 for surf data.
- NWPS mode fallback chain (legacy, unchanged): NWPS → WW3 → identical values across timesteps.
- Add `nearshoreModel` field to the surf endpoint response: `"trushore"` or `"nwps"` so the dashboard can display the data source.
- Add `lastRunTime` field: ISO timestamp of when the SWAN run that produced this data completed.

**Accept:**
- `GET /surf/{spot_id}` returns `nearshoreModel: "trushore"` when TruShore is configured.
- `lastRunTime` is present and reflects the SWAN run timestamp (not the request time).
- With TruShore unavailable (SWAN binary broken): response returns null surf fields with `nearshoreModel: "trushore"`, `error: "surf forecast unavailable"`. No WW3 fallback for surf data.
- With TruShore in legacy/stale state (last run 6 hours ago): response serves the stale cache with `dataAge: 21600` in the response. Does not fall to WW3.

### T3.4 — Move NWPS to legacy status

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nwps.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/cache_warmer.py`
- Reference: PROVIDER-MANUAL §14.6 (legacy marker added in T0.4)

**Do:**
- Add a deprecation warning to `NWPSProvider.fetch()`: when called with no `nearshore_model = nwps` config, log WARNING "NWPS is the legacy nearshore model. Set `nearshore_model = trushore` and install the `[nearshore]` pip extra for TruShore (recommended)."
- Remove NWPS from the cache warmer's default schedule when `nearshore_model = trushore` is configured. NWPS should only run on schedule if `nearshore_model = nwps` is explicitly set.
- NWPS module itself is NOT removed or modified further — it remains functional for operators who choose to use it.

**Accept:**
- With `nearshore_model = trushore`: NWPS does not appear in startup cache warmer logs.
- With `nearshore_model = nwps`: NWPS runs on schedule, no deprecation warning at startup (the operator has made an explicit choice).
- NWPS module passes all existing tests without modification.

### T3.5 — Scope WaveWatch III correctly as marine (not surf) source

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/marine.py` (confirm WW3 still serves marine deep-water forecast)
- Reference: API-MANUAL §17 (WW3 role — boundary input to SWAN and marine deep-water endpoint, not surf fallback); T0.3 updates

**Do:**
- Remove WaveWatch III from the surf endpoint fallback chain when `nearshore_model = trushore`. WW3 must not appear as a fallback for the surf endpoint.
- Confirm WaveWatch III continues to serve the marine endpoint's deep-water wave forecast (not affected by TruShore).
- Confirm WaveWatch III continues to be fetched by the TruShore pipeline as a boundary condition input (T2.3). The wavewatch.py provider is unchanged and continues to be called — just not for surf fallback.
- Add a code comment in `endpoints/surf.py`: "WaveWatch III (50km resolution) is not used as a surf forecast source. See API-MANUAL §17. WW3 data serves as SWAN boundary conditions via TrushoreProvider."

**Accept:**
- `GET /surf/{spot_id}` response never shows `waveDataSource: "wavewatch"` when `nearshore_model = trushore`.
- `GET /marine/{location_id}` response continues to show WaveWatch III deep-water wave data.
- TruShore pipeline continues to fetch WW3 for boundary conditions (verify via WW3 cache hit logs).

### QC Gate 3

- `GET /surf/{spot_id}` returns varying `waveHeight`, `wavePeriod`, and `waveDirection` across all 144 forecast timesteps — not identical values.
- All four wave_transform.py supplements fire for TruShore data (verify via DEBUG logs or supplement-specific unit tests).
- `windQualityScore` varies across forecast timesteps, reflecting the HRRR forecast wind pattern.
- `windSource` field correctly reflects "hrrr_trushore" for forecast timesteps.
- `nearshoreModel` field is present in the surf response.
- WaveWatch III never appears as a surf data source when `nearshore_model = trushore`.
- NWPS module passes all existing tests (no regression from T3.4 changes).
- All Phase 1 and 2 test baselines hold.

---

## Phase 4 — Separated Service Option

Operators who want to run SWAN on dedicated hardware (a more powerful machine, a cloud VM) can install the standalone TruShore service. This phase implements that option.

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
- Config wizard (if applicable) does not show `service_url` field unless `nearshore_model = trushore` is set (advanced operator option — not a day-1 wizard requirement).

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

### QC Gate 4

- Standalone `weewx-clearskies-trushore` service starts and returns health and forecast data.
- API in remote mode (`service_url` set): data matches bundled mode output for the same HRRR cycle.
- Remote service failure: API serves stale cache, logs ERROR, never falls to WW3.
- Remote service recovery: API resumes fresh data within 60 seconds of health check recovery.
- No regression in bundled mode (the default, no `service_url` set).

---

## Phase 5 — Dashboard Integration and Polish

The dashboard surf tab already has a 72-hour forecast card that shows wave data. With TruShore providing varying per-timestep data, the visualization should display meaningful variation rather than a flat line.

### T5.1 — Verify 72-hour forecast card displays varying TruShore data

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Review: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx` (or equivalent)
  - Review: surf forecast chart/table component
- Reference: DASHBOARD-MANUAL §12 (surf tab behavior); API-MANUAL §17 (SurfForecast response shape)

**Do:**
- Load `GET /surf/{spot_id}` with TruShore data active and verify the 72-hour chart/table correctly renders per-timestep wave height, period, and surf score.
- If the dashboard hardcoded handling for "identical values across timesteps" (which was the WW3 fallback behavior), remove that workaround. TruShore data varies — the chart should show the variation.
- Verify time axis: forecast timesteps should display in the operator's configured timezone, not UTC.
- Verify units: wave height displayed in the operator's `group_wave_height` configured unit (feet or meters), not always meters.

**Accept:**
- 72-hour surf forecast chart shows a curve, not a flat line, for a real TruShore SWAN run.
- Time axis is in the operator's configured timezone.
- Wave height is in the configured unit (feet for US preset).
- No visual regression compared to NWPS mode (chart renders correctly when NWPS data is shown via legacy mode).

### T5.2 — Add data source indicator on surf tab

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Modify: relevant surf tab components
- Reference: DESIGN-MANUAL (attribution badge pattern if one exists); `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §7 (TruShore name)

**Do:**
- Add a data source indicator on the surf tab showing: "Model: TruShore" (when `nearshoreModel: "trushore"` in the API response) or "Model: NWPS" (when `nearshoreModel: "nwps"`).
- Include a small tooltip or info icon that explains: "TruShore is a Clear Skies nearshore wave model that runs on an hourly schedule, independent of NWS operations."
- Placement: footer of the surf forecast card, or alongside the "Last updated" timestamp. Consistent with how other data source attributions appear on the dashboard.
- `lastRunTime` from the API response: display as "Last model run: [relative time]" (e.g., "34 minutes ago").

**Accept:**
- "Model: TruShore" indicator visible on the surf tab when TruShore is the configured model.
- Tooltip text is present and accessible (keyboard focusable, screen reader compatible).
- `lastRunTime` displays as a relative timestamp.
- In NWPS legacy mode: indicator shows "Model: NWPS" instead.

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
- `surfRating` on the Now page reflects TruShore's `t=0` output, not the NWPS output.
- Wind source for `t=0` scoring: station hardware if available, HRRR `t=0` otherwise (not legacy NDBC buoy).

### QC Gate 5

- 72-hour surf forecast chart shows varying data (wave height curve, not flat line) for real TruShore output.
- Data source indicator "Model: TruShore" visible and accessible on surf tab.
- `lastRunTime` relative timestamp displayed correctly.
- Current conditions surf rating sourced from TruShore.
- Dashboard vitest baseline holds.
- No visual regression in NWPS legacy mode.

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
- Reading list: `docs/manuals/API-MANUAL.md` §17; `docs/manuals/PROVIDER-MANUAL.md` §14.{HRRR}, §14.{TruShore}, §14.6; `docs/ARCHITECTURE.md`; relevant source files

**Do:**
- For each claim in the updated §17 and PROVIDER-MANUAL sections, trace the claim to the implementing code.
- Examples to check: wind rotation step documented → find the rotation code; SWAN grid resolution default documented → find the config constant; WW3 excluded from surf fallback documented → find the endpoint code that excludes it.
- Report any documented behavior that is not implemented, or implemented behavior that is not documented.

**Accept:**
- Every documented behavior has corresponding implementation.
- Every implemented behavior is documented.
- No claim in the manuals refers to code that does not exist.

### T6.4 — End-to-end validation: TruShore vs. NWPS comparison

- Owner: `clearskies-auditor` (Sonnet)
- Environment: live weewx host with both TruShore and NWPS available

**Do:**
- For a period when NWPS data is available, compare TruShore output against NWPS output at the same surf spot:
  - Hs (significant wave height): should be within ±0.5m for typical conditions.
  - Tm01 (mean period): should be within ±2s.
  - MWD (mean wave direction): should be within ±30°.
- Document any systematic biases (TruShore consistently higher/lower than NWPS). Biases are expected and acceptable — they do not indicate bugs. Document them for operator awareness.
- Verify physically impossible values are absent in the live TruShore output (Hs > 20m, Tm01 < 1s, MWD out of range, NaN).
- Verify wave data varies across forecast timesteps in the live surf endpoint response.

**Accept:**
- Comparison results documented (pass/fail per metric, with observed values).
- No physically impossible values in live output.
- Wave data varies across forecast timesteps.
- Systematic biases documented if present.

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

## Verification

After all phases complete:

- Surf endpoint returns varying wave data across all 144 forecast timesteps for TruShore-configured locations
- All four wave_transform.py supplements fire for TruShore data (γ correction, structure effects, spatial interpolation, topographic focusing)
- Wind quality in surf score reflects HRRR forecast wind, not station observation, for forecast timesteps
- `nearshoreModel: "trushore"` appears in surf endpoint responses
- `lastRunTime` reflects SWAN run completion time
- WaveWatch III never appears as a surf endpoint data source when TruShore is configured
- NWPS remains functional in legacy mode (`nearshore_model = nwps`) with no regression
- NWPS remains functional as SWAN boundary condition source via `providers/marine/wavewatch.py`
- Standalone `weewx-clearskies-trushore` service starts and serves data (if Phase 4 is complete)
- 72-hour surf forecast chart on dashboard shows a curve, not a flat line
- "Model: TruShore" indicator visible on surf tab
- All governing documents (API-MANUAL §17, PROVIDER-MANUAL, ARCHITECTURE.md) match implemented code
- Phase-boundary ADR compliance sweep: every ADR that touches marine/surf/nearshore is verified against the TruShore implementation
- All test baselines established at phase kickoff hold at plan completion
