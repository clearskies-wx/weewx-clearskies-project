---
status: Archived — consolidated into OPERATIONS-MANUAL.md
date: 2026-07-09
archived: 2026-07-09
deciders: shane
---

# ADR-085: eccodes native dependency for marine feature

## Context

NWPS nearshore wave data (ADR-084) is distributed as GRIB2 files only — no JSON or REST endpoint exists. Processing GRIB2 requires eccodes, ECMWF's C library for GRIB/BUFR encoding and decoding. This would be the first native (non-pure-Python) dependency in Clear Skies API.

The pre-Clear-Skies Phase II extension already used eccodes/pygrib with a `GRIBProcessor` class supporting both backends. eccodes is the actively maintained upstream library; pygrib is a Python wrapper that depends on eccodes under the hood.

The marine feature is operator-opt-in. Not every Clear Skies installation is coastal, and inland operators should not need to install a C library they will never use.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Require eccodes for all pip installs (`pip install weewx-clearskies-api` always pulls it) | Simple — no extras to manage. Always available if operator decides to enable marine later. | Inland operators forced to install a C library with system-level prerequisites (`apt install libeccodes-dev`) they will never use. Increases install friction for the common non-marine case. |
| Require eccodes only for marine via pip extra (`pip install weewx-clearskies-api[marine]`) | Inland operators have a clean install. Marine operators opt in explicitly. | Operator must install the system library before pip extra works. Requires clear error messaging if marine is enabled without eccodes. |
| Skip NWPS entirely, use WaveWatch III via ERDDAP only | No native dependency at all. | Loses 50m–1.8 km nearshore resolution, rip current probability, total water level, wave runup. Significant quality regression for surf and beach safety. |

Docker images always include eccodes regardless of which pip option is chosen — the image is built once and should be marine-capable out of the box. The decision above applies to native pip installs only.

## Decision

eccodes is provided via pip optional extra `[marine]` for native installs. Docker images always include it.

- **Docker compose:** eccodes baked into the API Dockerfile (`apt install libeccodes-dev` in build stage). Every Docker deployment is marine-capable with no operator action.
- **Native pip install:** Operator installs the system library (`apt install libeccodes-dev` or equivalent), then `pip install weewx-clearskies-api[marine]` to pull the Python binding. Operators who don't enable marine never encounter this.

### Detection and error handling

When an operator enables marine features (adds a `[marine]` section to `api.conf` or completes the marine wizard step) but eccodes is not installed:

1. At API startup, the marine provider module attempts `import eccodes` (or `import pygrib` as fallback).
2. If both fail, the API logs a clear error with platform-specific install instructions and raises a startup error for the marine feature only — the rest of the API continues to function.
3. The wizard's marine step checks eccodes availability before allowing marine configuration. If absent, it displays install instructions and blocks the marine setup (not the entire wizard).

## Consequences

- **First native dependency precedent.** This ADR establishes the pattern for future native dependencies: pip extras for opt-in features, Docker always includes them, clear detection with actionable error messages.
- **Dockerfile change:** Add `libeccodes-dev` to the API Dockerfile's build stage.
- **pyproject.toml change:** Add `[marine]` extras group with `eccodes` (or `cfgrib` which pulls eccodes).
- **OPERATIONS-MANUAL:** Documents platform-specific prerequisites (Debian/Ubuntu: `apt install libeccodes-dev`, RHEL: `dnf install eccodes-devel`, macOS: `brew install eccodes`, Alpine: `apk add eccodes-dev`).
- **No degradation within marine.** If marine is enabled, eccodes must be present. No "marine without NWPS" mode.

## Acceptance criteria

- [ ] `pip install weewx-clearskies-api` (without `[marine]`) does not require or install eccodes
- [ ] `pip install weewx-clearskies-api[marine]` pulls the eccodes Python binding
- [ ] API starts normally without eccodes when no `[marine]` config section exists
- [ ] API logs a clear error with platform-specific install instructions when `[marine]` config exists but eccodes is not available
- [ ] API continues to serve all non-marine features when eccodes is missing and marine is not configured
- [ ] Docker image includes eccodes and can process GRIB2 files without additional operator action
- [ ] The wizard marine step checks eccodes availability and shows install instructions if missing

## Implementation guidance

- **Detection module:** `providers/marine/_grib_check.py` — attempts `import eccodes`, falls back to `import pygrib`, raises `MissingDependencyError` with platform-specific message if both fail. Called at marine provider module registration time.
- **pyproject.toml:** `[project.optional-dependencies] marine = ["eccodes>=2.35"]` (or `cfgrib` — coordinator decides at implementation time based on current ecosystem state).
- **Dockerfile:** In the API Dockerfile build stage: `RUN apt-get update && apt-get install -y --no-install-recommends libeccodes-dev && rm -rf /var/lib/apt/lists/*`
- **Out of scope:** GRIB processing logic (Phase 2, T2.1). This ADR covers dependency management only.

## References

- Related ADRs: ADR-084 (NWPS as primary nearshore source), ADR-083 (marine domain architecture)
- eccodes: [ECMWF eccodes](https://confluence.ecmwf.int/display/ECC)
- Research: `docs/planning/briefs/MARINE-DATA-AUDIT-BRIEF.md` §2 (GRIBProcessor class)
