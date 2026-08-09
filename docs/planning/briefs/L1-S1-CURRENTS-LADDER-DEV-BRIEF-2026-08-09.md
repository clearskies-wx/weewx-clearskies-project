# ROUND BRIEF — S1: current-source ladder (RE-AMENDED, NO RTOFS) — L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase S task S1 only (S4a is test-author's, separate brief, dispatches
after your commits). Lead: coordinator (session 6). You: `clearskies-api-dev` (Sonnet).
Auditor: `clearskies-auditor` at Gate S currents half (blind). Deploy: lead, single-change
(S1+S4a together), after your round + S4a close.

**This brief SUPERSEDES the S1 sections of `L1-PHASE-S-DEV-BRIEF-2026-08-09.md`** (written
before the operator's 2026-08-09 re-ruling). That brief's S2/S3 sections are history (done).
Its MANDATORY BLOCKS section still binds you (see bottom).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`, HEAD `462b38f` at brief
time — lead re-states HEAD at dispatch; verify and report drift in scope-ack. Local commits
only.

**Authorization:** S1 is architectural and PRE-APPROVED via plan register row **P7 as
RE-AMENDED 2026-08-09** (operator, in chat, twice: RTOFS rung REMOVED; ladder exhausted =
REFUSE). Anything beyond P7's re-amended text → STOP and surface.

## HARD EDGES (operator rulings — violating any of these fails the round)
- **NO RTOFS anywhere.** `providers/ocean/rtofs_currents.py` is NOT created; no RTOFS URL,
  module, constant, or fallback path exists in your diff. A non-tidal source is not a
  fallback — it is missing required input.
- **Ladder exhausted = REFUSE.** `CurrentCoverageError` at selection time → existing C-77
  no-publish machinery (`currents_fetch_failed` class), message naming the L1 bbox and the
  three declined rungs. Never publish on missing currents.
- **NO summing** on any rung. Per-CYCLE source selection; a missing timestep on the selected
  source → `CurrentCoverageError`, never a mid-cycle source switch.
- Output shape IDENTICAL to `fetch_surface_currents` (list of {time, u_grid, v_grid} at SWAN
  grid dims) so `_write_current_txt` is untouched.

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` §S1 (RE-AMENDED design — your
   spec verbatim), §S4 row (a) + (f) (the KAT seams your code must leave pure), §S-Accept
   currents rows, §Gate S, register row P7, PRIME DIRECTIVE (esp. 8).
2. `docs/ARCHITECTURE.md` "L1-BOUNDARY-REBUILD-PLAN target state" block, SWAN input chain
   bullet (ruled ladder prose).
3. `docs/manuals/PROVIDER-MANUAL.md` — OFS currents section + §14.10a (ladder doc section;
   your round's doc-sync is the LEAD's work, but read what it promises).
4. `weewx_clearskies_marine/providers/ocean/ofs.py` — `OFS_DOMAINS` (:58), `find_ofs_model`
   (:86), `fetch_surface_currents` (:461) — the output contract.
5. `weewx_clearskies_marine/providers/nearshore/swan.py` :3190-3230 — the currents fetch site
   (the call at :3219 is what routes through your selector; C-77 abort semantics live in the
   surrounding no-publish machinery — read it).
6. `weewx_clearskies_marine/providers/ocean/stofs_wlevel.py` — the S2 provider whose idioms
   (cycle candidates, regional tokens, loud failure paths) your STOFS-3D-Atl fetcher mirrors
   where applicable (it is netCDF, not grib — see LEAD CALLS).
7. `providers/_common/http.py` — client + rate limiter (reuse).
8. `rules/verification.md` — falsifiability; leave pure seams for S4a.

## PRE-ROUND VERIFICATION (lead, 2026-08-09 session 6, HEAD `462b38f`)
- Anchors: `OFS_DOMAINS` :58, `find_ofs_model` :86, `fetch_surface_currents` :461,
  swan.py currents call :3219 (drifted from the old brief's :3157-3178),
  `_write_current_txt` :2462 (W4 abort semantics — do not touch).
- Baseline: 249 pass / 3 tracked pre-existing on the recorded selection (see VERIFICATION).
- STOFS-3D-Atl inventory live-verified today (see LEAD CALLS 2 — the file pin).

## SCOPE
**Create:** `providers/ocean/stofs3d_currents.py` (STOFS-3D-Atl velocity fetcher),
`providers/ocean/pacioos_roms.py` (PacIOOS ROMS Hawaii fetcher).
**Modify:** `providers/ocean/ofs.py` (add `find_current_source(l1_bbox)` — containment, not
centre-in-box; `find_ofs_model`'s existing behavior for its other callers unchanged),
`providers/nearshore/swan.py` (the currents fetch site ONLY, :3190-3230 region).
**Do NOT touch:** `services/swan_runner.py` (`_write_current_txt` W4 abort semantics),
`stofs_wlevel.py`, wind path, boundary/geometry files, `vertical_datum.py`, endpoints,
tests (S4a owns them), meta repo. No new config keys. No new dependencies (netCDF4 +
eccodes + existing HTTP client suffice; a new dep → STOP and surface).

## DESIGN (decided — plan §S1 verbatim; ladder restated)
Selection = first rung whose domain CONTAINS the L1 bbox (containment of the whole box,
not centre-in-box):
1. **Regional OFS** — existing `OFS_DOMAINS`; an OFS qualifies only if its box CONTAINS the
   L1 bbox; highest-resolution qualifier wins; tidal-inclusive natively.
2. **STOFS-3D-Atlantic** (US East + Gulf + PR) — total current (circulation+tide+surge).
3. **PacIOOS ROMS Main Hawaiian Islands** (`roms_hiig`, ERDDAP griddap) — 4 km, TPXO tidal
   forcing.
4. **Exhausted → REFUSE** (`CurrentCoverageError` → `currents_fetch_failed` no-publish;
   message names bbox + the three declined rungs).
Selection logged once per cycle at INFO (provenance, not flagging). Missing timestep on the
selected source → `CurrentCoverageError` (no cross-rung mixing within a cycle).

## LEAD CALLS (decided — do not re-derive)
1. **`find_current_source(l1_bbox)` returns a source descriptor** (rung name + any
   rung-specific handle, e.g. the qualifying OFS model name); the swan.py fetch site
   dispatches on it. HB (WCOFS containment) must keep returning WCOFS — zero behavior
   change at the live site beyond the new INFO selection line.
2. **STOFS-3D-Atl file pin (lead, live-verified from librewxr 2026-08-09):** velocity is NOT
   in the grib2 products (single cwl message, discipline 10 cat 3 param 250 — lead-verified)
   and NOT structured anywhere. Pin: **`stofs_3d_atl.tXXz.field2d_f*.nc` / `field2d_n*.nc`**
   on NOMADS (`.../stofs/prod/stofs_3d_atl.YYYYMMDD/`), variables **`uvel_surface`/
   `vvel_surface`** (`(time=12, nSCHISM_hgrid_node=2926236)` float64, unstructured SCHISM
   mesh; coords `SCHISM_hgrid_node_x/y`, `depth`; `time` float64). `fields.out2d_*`
   (`depthAverageVelX/Y`) REJECTED — surface velocity is the quantity the
   `fetch_surface_currents` contract serves. **One cycle/day (t12z only), forecast to 96 h,
   12 h per file** — cycle-candidate logic must tolerate a cycle age up to ~29 h
   (yesterday's t12z covering `age+67 h ≤ 96 h`).
   **Access route: netCDF-over-HTTPS byte-range — `netCDF4.Dataset(url + '#mode=bytes')`**
   (lead-verified working from librewxr against the live file today). Fetch strategy: read
   node coords ONCE per selection (cacheable within the fetch), build the bbox node-index
   mask, then per-timestep fancy-index reads of u/v at masked nodes; resample to SWAN grid
   dims (nearest-wet idiom consistent with existing providers). Chunking is
   `[1, 1463118]` uncompressed (two chunks per timestep per var, ~11.7 MB each) — a bbox
   read transfers ~12–23 MB per timestep per var. That cost is acceptable for config-time
   smoke and East-Coast deployments; note it in the module docstring. MEMORY: stream
   per-timestep, retain ONLY the SWAN-dims subset as float32 — the S2 OOM incident
   (production-shaped memory KATs now mandatory for fetchers) applies to you; leave a
   seam for S4a's memory KAT (a pure per-timestep extraction function).
3. **PacIOOS ROMS Hawaii:** ERDDAP dataset `roms_hiig` at `https://pae-paha.pacioos.hawaii.edu/erddap/`
   (griddap; existing ERDDAP client idioms), surface-layer u/v, 3-hourly, 7-day horizon.
   Verify the exact variable names from the dataset's DDS at implementation and record them
   in your closeout (bounded pin — dataset ID is fixed, variable names are yours to read off
   the live DDS; if `roms_hiig` itself is absent → STOP and surface, do not substitute a
   different dataset).
4. **Depth/surface caveat docstrings:** STOFS-3D field2d serves SURFACE velocity — state it;
   PacIOOS ROMS surface layer — state it. (Gate S and S4a look for these.)
5. Commit prefix `S1:`; commits separable from anything else.

## VERIFICATION (yours, before closeout)
`.venv-round4\Scripts\python.exe -m pytest tests/test_island_autosizing.py tests/services/ tests/test_coops_fetch_datums.py tests/test_stofs_wlevel_provider.py tests/test_swan_wlevel_chain_fallback.py -q`
— expected 249 pass / 3 tracked pre-existing fail, 0 new. Name the exact selection +
pre/post counts in scope-ack and closeout. NEVER the full suite. Do not write test files.

## OPEN QUESTIONS
None pre-identified. Anything ambiguous → SendMessage to "main", do not pick.

## MANDATORY BLOCKS — comply verbatim
The three blocks (git restrictions; stale-test; architectural) as printed in
`rules/agents.md` §"Pre-flight repo verification", §"Stale-test block", §"Architectural
change block". **SCOPE-ACK REQUIRED via SendMessage to "main" BEFORE ANY CODE** — a
session-5 dev skipped it; it is ENFORCED this round: deliverables, exclusions, exact
verification command, anchor-drift report, your reading of the ladder's refusal semantics
in one sentence. Wait for lead confirmation. Tone: concise, no filler.
