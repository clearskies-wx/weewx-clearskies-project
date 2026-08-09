# ROUND BRIEF — Phase S: RTOFS currents, STOFS water level, Hawaii datum (L1-BOUNDARY-REBUILD-PLAN)

**Round identity:** Phase S tasks S1–S3 (S4 is test-author's, separate brief). Lead:
coordinator. You: clearskies-api-dev (Sonnet). Auditor: `clearskies-auditor` at Gate S
(blind). **Two deploys** (lead runs both): S1+S4a currents first, S2+S4b water level
second — your commits must keep the two changes separable (currents commits distinct
from wlevel commits; S3 rides with the wlevel group).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits
only). Dispatched only after Gate G closes (marine repo runs one round at a time).

**Authorization:** S1–S3 ARE architectural (new providers, source-selection rules,
datum branch) and are PRE-APPROVED via the plan's Pre-approval register **P7, P8, P9,
P12** (rulings D9/D10/D13 + the operator's 2026-08-08 compositing directive, quoted in
P7). Anything beyond those rows' text → STOP and surface.

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — §PHASE S in full
   (S1–S4, S-Accept, Gate S: your spec, verbatim — especially S1's tidal-current
   compositing block and S2's cutover bias gate) + register rows P7–P9/P12.
2. `docs/ARCHITECTURE.md` — "L1-BOUNDARY-REBUILD-PLAN target state" block, third
   bullet (SWAN input chain: the ruled current/wlevel/datum designs in prose).
3. `docs/manuals/PROVIDER-MANUAL.md` — the OFS currents section and §14.3-family NOMADS
   grib-filter conventions (your RTOFS/STOFS fetchers reuse these idioms).
4. `weewx_clearskies_marine/providers/ocean/ofs.py` — `OFS_DOMAINS` (:58),
   `find_ofs_model` (:86), `fetch_surface_currents` (:461-670) — the output shape your
   RTOFS fetcher must reproduce exactly.
5. `weewx_clearskies_marine/providers/nearshore/swan.py` — tide-predictions block
   (:3068-3103, the site S2's chain replaces) and the currents fetch site (:3157-3178,
   the site S1's selector routes; C-77 abort semantics live here — read the
   surrounding no-publish machinery).
6. `weewx_clearskies_marine/services/swan_runner.py` — `_write_wlevel_txt` (:2285-2326 —
   NOTE, lead-verified 2026-08-09: this is the spatially-UNIFORM tide stamp, NOT a
   spatially-varying path) AND `_write_wlevel_grid_txt` (:2329-2352 — the EXISTING
   spatially-varying grid writer, takes `grids[timestep][j][i]`; **S2 = feed STOFS fields
   to THIS existing function — wiring, not generalization**), `_write_current_txt`
   (:2378-, post-W4 abort semantics you must not weaken).
7. `weewx_clearskies_marine/services/vertical_datum.py` — whole module (S3's branch
   lands here; the Great Lakes LWD/IGLD85 branch is the precedent pattern).
8. `weewx_clearskies_marine/data/ncei_regional_dem_index.json` — structure; find out
   whether a generator script exists (plan S3's own instruction) before hand-editing.
9. `providers/_common/http.py` — client + rate limiter (reuse, do not duplicate).
10. `rules/verification.md` — falsifiability; your commits leave pure seams for S4.

## PRE-ROUND VERIFICATION (lead, 2026-08-09, marine HEAD `70d442f`)
- Line drift vs plan text: tide block :3021-3080 → **:3068-3103**; currents site
  :3086-3140 → **:3157-3178**; `_write_current_txt` → **:2378**. `_write_wlevel_txt`
  :2285 matches. ofs.py/vertical_datum.py/dem-index paths confirmed to exist.
- NOTE: if Phase G landed between this brief's writing and your dispatch, the lead will
  re-state HEAD at dispatch; re-verify these anchors then and report drift in scope-ack.

## SCOPE
**Create:** `providers/ocean/rtofs_currents.py` (S1), `providers/ocean/stofs_wlevel.py`
(S2 — one fetcher extracting BOTH the water-level field and u/v velocity from the same
files).
**Modify:** `providers/ocean/ofs.py` (add `find_current_source(l1_bbox)` per S1 —
containment, not centre-in-box; do not alter `find_ofs_model`'s existing behavior for
its other callers), `providers/nearshore/swan.py` (the two fetch sites only),
`services/swan_runner.py` (S2 wiring ONLY: route the all-levels wlevel path through the
EXISTING `_write_wlevel_grid_txt`; do not rewrite either writer),
`services/vertical_datum.py` (S3 branch), `providers/tides/coops.py` (S3 — ADDITIVE
`datums` product support ONLY; the existing predictions/water_level/water_temperature
paths are untouched; lead ruling 2026-08-09, no datums support exists today),
`data/ncei_regional_dem_index.json` (P12 entries).
**Do NOT touch:** wind path (hrrr.py, wind_gatherer), `swan_formats.py`,
`boundary_reconstruction.py`, `ww3_partition_fields.py`, geography/swan_domain/
grid_sizing_chain (Phase G's files), `_write_current_txt`'s W4 abort semantics, any
endpoint, tests (S4 owns them). No new config keys. New deps: NONE — RTOFS/STOFS via
grib filter (eccodes already present) or ERDDAP (existing client); if you conclude a
new dependency is required → STOP and surface.

## DESIGN (decided — plan §PHASE S tasks S1–S3, verbatim; hard edges restated)
1. **Bounded decisions:** the RTOFS access route is NO LONGER yours to pin — both
   plan-named candidates (NOMADS grib filter; ERDDAP griddap) were verified DEAD on
   NOAA's side 2026-08-09 (scope-ack evidence, preserved in the session handoff); the
   route is an open operator question (plan §OPEN OPERATOR QUESTIONS) and the lead
   states the ruled route at dispatch — do not begin S1 without it. STOFS regional
   product filenames remain yours to pin from the NCO inventory (region tokens
   live-verified plain `conus`/`hawaii`, 4 cycles/day). Record pinned choices + raw
   evidence in your closeout.
2. **Compositing (P7, operator directive):** RTOFS branch ONLY: `u = u_RTOFS +
   u_STOFS`, `v = v_RTOFS + v_STOFS` per cell per timestep; missing either component
   at a timestep → `CurrentCoverageError` (no partial composite). OFS regions NEVER
   composite (they are tidal-inclusive natively — adding STOFS would double-count).
3. **WLEVEL chain (P8):** STOFS primary → CO-OPS-uniform fallback (loud log, bathy-
   chain pattern) → refuse `tide_fetch_failed`. The "~30 km uniform tide" justification
   comment is deleted WITH the uniform-primary path. The cutover bias gate (24 h STOFS
   vs CO-OPS at the tide-station cell, |mean bias| ≤ 0.15 m) is measured by the LEAD at
   S-Accept, pre-deploy-cutover — your code must make the comparison possible (expose
   the STOFS value at a given cell/time via a plain function), not run the gate itself.
4. **Depth-averaged caveat:** STOFS velocity is depth-averaged; the tidal component is
   barotropic so depth-averaged ≈ surface for exactly the component STOFS supplies —
   this statement must appear in your module docstrings (S4's KATs and Gate S will look
   for it). ALL meta-repo doc-sync (PROVIDER-MANUAL RTOFS/STOFS sections + §14.12 note,
   ARCHITECTURE.md paragraph) is the LEAD's work — meta repo is off limits to you.
5. **S3 (P9):** VDatum-less AND all-tidal-referenced sources → CO-OPS `datums`-product
   offsets (station nearest domain centre, cached at config push, constant across
   domain); any geodetic source there → `DatumConversionError` refuse. Great Lakes
   branch is the pattern; do not modify it.
6. Every fetch failure path is LOUD (log naming source + reason) — no silent
   substitution anywhere (D5; Gate S greps for zero-fill patterns).

## VERIFICATION (yours, before closeout)
`.venv-round4\Scripts\python.exe -m pytest <tests matching your changed files +
tests/services/> -q` — name the exact selection in scope-ack; record pre/post counts;
NEVER the full suite. S4's KATs are test-author's — do not write test files.

## LEAD CALLS
- Commit grouping: currents commits (S1 + ofs.py selector + swan.py currents site)
  strictly separate from wlevel commits (S2 + swan_runner + swan.py tide site) and S3.
  Name the group in each commit message ("S1:", "S2:", "S3:").
- `find_current_source` returns the model name or `"RTOFS"`; selection logged once per
  cycle at INFO (provenance, not flagging).
- The STOFS fetcher is ONE module serving both consumers (P8 text) — no parallel
  second fetcher for velocity.

## OPEN QUESTIONS
None pre-identified beyond the two bounded pins (design pt 1). Anything else ambiguous
→ SendMessage, do not pick.

## MANDATORY BLOCKS
Comply verbatim with the three blocks in
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS (git
restrictions; stale-test; architectural). **SCOPE-ACK REQUIRED via SendMessage to
"main" before any code:** deliverables, exclusions, exact verification command, the two
bounded pins' candidate list, anchor-drift report. Wait for confirmation. Tone: concise.
