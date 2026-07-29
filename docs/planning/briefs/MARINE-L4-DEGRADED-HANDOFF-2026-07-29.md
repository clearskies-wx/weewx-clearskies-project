# Handoff: Marine Model — degraded surf forecast, two open findings (2026-07-29)

Every claim is marked **VERIFIED** (command run this session, cited) or **UNVERIFIED / HYPOTHESIS**
(not proven — do not trust). The authoring session made errors (looked on the wrong host, conflated
two runs, misreported deep-water height as break height, asserted SWAN mechanics without reading the
manual). Re-check from primary evidence rather than inheriting those claims.

## Goal
Coordinator for the **Marine Model Restoration Plan** (Clear Skies). This phase: get the Huntington
Beach surf forecast producing a correct **break height** and validate against reality (Surfline /
surf-forecast: ~4–6 ft face, 16–18 s period, ~3 swell trains). Standing operator authorizations:
"push/deploy as needed for testing" and "keep going unless you need me." **No architectural change
without explicit operator approval** (CLAUDE.md hard block).

## Where things actually run — VERIFIED this session
- Marine model (SWAN + surf pipeline) runs on **`librewxr` (192.168.7.22)**, unit
  **`weewx-clearskies-marine.service`**, port **8780** (TLS). NOT on `weewx`, NOT inside the API.
  Authority: `reference/clearskies-dev.md` §"librewxr (compute host) — this is where SWAN runs".
- SSH from repo root `c:\CODE\weather-belchertown`: `ssh -F .local/ssh/config librewxr "<cmd>"`.
  Repo commands need `sudo -u ubuntu`.
- Marine code on librewxr: `/home/ubuntu/repos/weewx-clearskies-marine/` (confirmed via journal
  traceback paths). Python: `/home/ubuntu/repos/weewx-clearskies-api/.venv/bin/python`.
- Served forecast cache: `/run/weewx-clearskies/swan/forecast_cache.json`.
- Preserved failed L4 workdir (primary evidence): `/var/run/weewx-clearskies/swan/level4_0/` —
  `INPUT`, `PRINT`, `BOTTOM.txt`, `hotstart.dat`.
- Logs: `sudo journalctl -u weewx-clearskies-marine.service` (JSON lines).

## Current state — VERIFIED
Three runs of the same fixed cycle `2026-07-29T00:00:00Z` ran today:

| Time | Event | L4 convergence |
|---|---|---|
| 01:14 | run | `valid_fraction=100.0%` PASS |
| 03:33 | run (32/32 transects resolved per-transect handoff) | `valid_fraction=100.0%` PASS |
| **05:15:37** | **operator `POST /config` (HB-only) → grid_sizing_chain regenerated all grids** | — |
| 05:22 | run (currently served) | `valid_fraction=0.0%` **FAIL** → fell back to L2 DWR (7 timesteps) |

Served cache (`run_time 05:22:05`), spot `huntington-city-beach-pier`:
- Forecast only **7 hours** (2026-07-31T18:00Z → 08-01T00:00Z — tail of a 72 h window).
- `wavePeriod` present (13.46 s dominant) but **`waveHeightAtBreak` = null for all 7 hours**,
  `qualityStars` = null for all 7.
- `handoff_by_transect` present on **0 of 7** spectral entries.

**Correction to prior claims:** an earlier checkpoint ("B validated, L4 passed, ~4 ft face") described
the **03:33** run, not the served **05:22** run. The "~4 ft" was deep-water `waveHeight` misread as
break height. **Break height was never validated.**

## L4 PRINT errors (05:22) — VERIFIED (`/var/run/weewx-clearskies/swan/level4_0/PRINT`)
```
** Severe error : No value for variable YP        (right after OBSTACLE; echo truncated ~char 120)
** Error        : start time [tbegc] before current time    (at COMPUTE NONST 20260729.000000 ...)
** Warning      : (corner)point outside comp. grid
** Error        : Unexpected end of file while reading UNKNOWN_FILE   (×3, during COMPUTE)
```

## Finding 1 — Hotstart timestamp bug (DOCUMENTED)
- Authority: `docs/reference/swan-commands-extract.md` §"WHY THE HOTSTART ACTUALLY FAILS — timestamp,
  not syntax (measured 2026-07-25)".
- Mechanism (per doc): `HOTFILE` saves the field at the **end** of the window; each cycle restarts
  from the **beginning**; SWAN can't rewind, reports `tbegc before current time`, **clamps the start
  forward to the hotfile's time**, so only the tail computes. Doc verdict: hotstart is "unusable with
  the current run scheduling… **Operator decision, not a code fix**." Options: (a) write hotfile at
  the *next* cycle's start, (b) chain windows forward, (c) drop hotstart.
- Explains the 7-hour truncation + L4 0% valid + L2-DWR fallback: `tbegc before current time` is in
  the 05:22 PRINT.
- **UNVERIFIED:** did not read the actual timestamp inside `hotstart.dat`; did not prove why
  01:14/03:33 passed but 05:22 failed (hypothesis: hotfile advanced past the window start across
  repeated same-cycle re-runs). Next session: read the hotfile date line and confirm.

## Finding 2 — OBSTACLE emitted as one over-long line
- **VERIFIED code:** `weewx_clearskies_marine/services/swan_formats.py:1707` joins all structure
  vertices into one string and emits `OBSTACLE {params} LINE {coord_str}` — HB pier = 35 vertices /
  ~600 chars on one text line. SWAN's PRINT echo truncates it (~char 120) → `No value for variable YP`
  severe error → pier obstacle malformed → **marine invariant 3 fires: "1 structure configured but 0
  of 32 transects shadowed"** (VERIFIED in 05:22 log).
- **VERIFIED:** emitted coordinates already form a **closed ring** (first vertex == last vertex);
  per-type physics exists at `swan_formats.py:1688-1694` (pier→`TRANSM 0.82`,
  breakwater→`DAM DANGREMOND`, jetty→`DAM GODA`, seawall→`REFL 0.5`, groin→`DAM GODA`).
- **OPERATOR DOMAIN DIRECTION (open, must be incorporated):** obstacles should be **polygons
  (footprints), not single lines** — a pier is not a wall; only sheetpile is a wall. Whether the fix
  is (i) emitting the existing ring across multiple lines / continuation so SWAN parses it, or (ii) a
  deeper change to structure representation (footprint polygon vs thin barrier; how transmission /
  reflection applies), is an **open architectural question for the operator.**
- **UNVERIFIED — read the manual first:** did NOT confirm from `docs/reference/swan-user-manual.pdf`
  (a) SWAN input line-length limit, (b) line-continuation syntax, (c) whether/how OBSTACLE represents
  closed polygons vs polylines, (d) correct physics for a pile-supported pier. Read the SWAN user
  manual OBSTACLE + input-syntax sections before proposing any fix. Do not assert SWAN behavior from
  memory.

## B fix (curve-clip rotation) — status
- Commit `daddf19` in `swan_formats.py` (`build_swan_input` inner-branch: account for L4 grid rotation
  when building the curve-clip bbox). Deployed; present in the passing 03:33 run. **Break-height
  validation still owed** once a clean converging run exists.

## Open decisions for the operator
1. **Hotstart:** which of write-at-next-start / chain-forward / drop-hotstart? Blocks a full,
   non-truncated forecast.
2. **Obstacles:** confirm intended representation (footprint polygon vs thin barrier; sheetpile = wall
   exception) so the SWAN-input emission is fixed correctly, not just line-wrapped.

## Immediate next steps
1. Read `docs/reference/swan-user-manual.pdf` (OBSTACLE + input/command syntax incl. line length &
   continuation) and the `swan-commands-extract.md` hotstart section — **before** touching code.
2. `cat` the timestamp line of `/var/run/weewx-clearskies/swan/level4_0/hotstart.dat`; confirm
   Finding 1.
3. Do NOT change hotstart scheduling or obstacle representation without operator sign-off — both are
   architectural.
