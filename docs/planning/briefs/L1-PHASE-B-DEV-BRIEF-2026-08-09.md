# ROUND BRIEF — Phase B (partition-reconstruction boundary, B1–B4), L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase B tasks B1–B4, L1-BOUNDARY-REBUILD-PLAN-2026-08-08. Lead:
coordinator (Opus). You: clearskies-api-dev (Sonnet). Tests (B5): clearskies-test-author,
separate agent, after you. Auditor: clearskies-auditor at Gate B (blind).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (HEAD `95abc74`,
verified clean, deployed). Local commits only — coordinator pushes/deploys.

## READING LIST (read BEFORE any code; the plan + brief ARE the design — no re-derivation)
1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md`:
   - **SWAN SYNTAX PRESCRIPTIONS** — §1 (BOUNDSPEC grammar, CCW corner map, `[len]` in
     UTM metres, one point per L1 boundary cell at `len_i = i × dx`, FORBIDDEN list),
     §2 (Appendix-D 2-D nonstationary file template — implement EXACTLY), §3 (pinned
     commands — byte-identical emission; only the BOUNDSPEC block and grid numerals may
     differ in INPUT), §4 (deployed-binary deviations).
   - **Phase B** — B1/B2/B3/B4 designs in full (your spec), B-Accept, Gate B rows.
   - Named-constants block (spreads s=28/s=7, σf 0.015 Hz, γ 3.3, spacing = L1 dx,
     `r` bounds [1.10, 1.35] measured-then-pinned).
   - PRIME DIRECTIVE (frozen core; spectral grid CIRCLE 72 0.03 1.0 34 PINNED).
2. `docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` §5 (design
   record: what NOAA publishes, reconstruction losses, D3/D4 rulings).
3. `docs/manuals/PROVIDER-MANUAL.md` — §14.3 (existing WW3 partition fetch conventions,
   ≥9998 missing guard, direction-convention proof chain :2344-2363 region), the new
   "§14.3a/b Amendment: partition-reconstruction boundary (target — Phase B)" section
   (Phase DOC wrote your spec there — your doc-sync makes it live and removes tags),
   §14.15 (deployed-binary deviations).
4. **LOCAL SWAN manual ONLY** (`docs/reference/swan-user-manual.txt`,
   `docs/reference/swan-commands-extract.md`) for any SWAN question — cites are in the
   plan's syntax section. **Downloading SWAN documentation is FORBIDDEN** (the manual is
   in-repo; reference/clearskies-dev.md).
5. Code: `services/ww3_spectrum.py` (the Appendix-D writer you EXTRACT in B2 — find
   `ww3_spectrum_to_swan_boundary`; the SPECOUT-mirror parser — check its consumers
   before deleting anything), `services/swan_formats.py` (`ww3_boundary_files_and_command`
   :2563; the nest/CGRID blocks you must NOT touch), `services/swan_runner.py` (:4497
   region — boundary file writing), `services/ww3_station_selection.py` (the
   `_offshore_sides` logic that MOVES into boundary_reconstruction; the
   cycle-fallback idiom that moves into B1's fetcher; H2.2 backoff conventions),
   `services/grid_sizing_chain.py` (`_validate_ww3_boundary_viability` — replaced by the
   partition-fetch smoke test), `providers/nearshore/swan.py` (`_run_all_spots_locked`
   boundary call site), `providers/marine/wavewatch.py` (the live-verified gridded
   partition fetch + direction handling B1/B2 adopt), `providers/_common/http.py`.

## SCOPE
**Files to CREATE:** `weewx_clearskies_marine/services/ww3_partition_fields.py` (B1),
`weewx_clearskies_marine/services/boundary_reconstruction.py` (B2).
**Files to MODIFY:** `services/swan_formats.py` (B2 writer extraction →
`write_swan_2d_spectrum_file()`; B3 rework of `ww3_boundary_files_and_command()` — same
public name), `services/swan_runner.py` (boundary file-writing region),
`services/ww3_spectrum.py` (delete station fetch + parser ONLY per B4's conditions),
`services/grid_sizing_chain.py` (config-time smoke test), `providers/nearshore/swan.py`
(boundary call site).
**Files to DELETE (register P5, pre-approved):**
`services/ww3_station_selection.py`, `services/ww3_station_catalogue.py`,
`weewx_clearskies_marine/data/ww3_station_catalogue.json` (note: package-relative path —
the plan's `data/...` means this file).
**Tests:** you delete/modify NOTHING under tests/ — station-suite deletion is B5's
(test-author's), enumerated at ITS scope-ack. If your changes break existing tests,
LIST them in your closeout for B5; do not edit them.

**Commit structure:** one commit per task — B1, B2, B3, B4 — in that order, so the
auditor can walk them separately.

## LEAD CALLS (decided; do not re-derive)
1. **Measured-then-pinned `r`** (wind-sea mean→peak ratio): implement the measurement in
   B2 as a one-shot dev-time script or test-invocable function comparing reconstruction
   vs 3 live `.spec` cycles (the station path still exists at your starting HEAD — use it
   for the comparison BEFORE B4 deletes it). Pin the measured value as a named module
   constant with the measurement recorded in its docstring (date, cycles used, per-cycle
   values). Out of bounds [1.10, 1.35] → STOP and surface. Same for the
   direction-convention cross-check (must agree within 15° or STOP).
2. **B1 product pinning** (ocean f000–f072 3-hourly via `filter_gfswave.pl` product
   `gfswave.tCCz.global.0p16`; GLWU: filter-if-present else `.idx` byte-range): pin after
   ONE live shape check each, record the choice + evidence in the module docstring. The
   GLWU live check may be run against the Great Lakes bbox from the D7 matrix context —
   config-time style, nothing published.
3. **`BoundaryNotViableError` retained as the exception type** (new message text).
4. **Boundary sides:** resolved from `open_water_bearing` via `_offshore_sides` logic
   MOVED into `boundary_reconstruction.py` (not imported from the deleted module).
5. **Per-timestep FACTOR** = `max_density / 990000`; zero-energy timestep → FACTOR 1.0 +
   all-zero matrix (never NODATA).
6. **Emission grammar is prescribed verbatim** in the plan's syntax §1/§2 — a mismatch
   between the plan and the local manual is a STOP-and-surface finding, never an
   improvisation.

## VERIFICATION (before closeout)
- `python -m py_compile` on every changed file + full-module import via `.venv-round4`.
- Functional smoke: synthetic 2-partition input → reconstruction → file text: verify
  header order (SWAN 1 / TIME / LOCATIONS / AFREQ 35 / NDIR 72 / QUANT — count is msc+1,
  coordinator ruling 2026-08-09 after live SPECOUT verification), frequency-major
  35×72 matrix, FACTOR arithmetic round-trips (`integer × factor` recovers density to 6
  sig figs), bin-sum identity `|4√m0 − √(ΣHs_p²)| ≤ 5%` on the discrete grid.
- The `r` measurement + direction cross-check per Lead Call 1, values pasted in closeout.
- grep: zero imports of the deleted modules anywhere outside tests/.
- Do NOT run pytest suites (B5's and the coordinator's job); list expectedly-broken test
  files instead.

**Deliverable:** 4 commits (B1–B4) on marine main (local); closeout via SendMessage with
per-task file/line changes, the pinned constants + measurement evidence, the smoke-check
transcript, the expectedly-broken test list, and every guard that fired.

## MANDATORY BLOCKS
Read and comply verbatim with the three mandatory blocks (git restrictions / stale tests /
architectural changes) in `docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md`
§MANDATORY BLOCKS — they bind you identically. B1–B4 are pre-approved architectural
changes (register P4/P5 — boundary data contract + station-path deletion). Anything beyond
P4/P5's text → STOP and surface. The frozen-core list (plan PRIME DIRECTIVE 1) is
absolute; the spectral grid `CIRCLE 72 0.03 1.0 34` may not change.

**SCOPE-ACK REQUIRED** before any code: SendMessage to "main" with deliverables,
exclusions, the ww3_spectrum.py parser-consumer finding (keep or delete, with evidence),
the verification plan, and any line-number drift. Wait for confirmation.
**Tone: concise, direct, no filler.**
