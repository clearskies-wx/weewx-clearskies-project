# M0 brief — Map extent inventory + extract measurements (READ-ONLY)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, task M0. Date 2026-08-27. Lead: coordinator.
Implementer: one general-purpose agent (Sonnet). Auditor: none (read-only inventory; the lead
reproduces every number).

## Scope

**Deliverable — the ONLY file you write:** `c:\CODE\weather-belchertown\scratch\M0-MAP-EXTENTS.md`.
Contents (a)–(d) exactly as `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"M0 — Extent
inventory + measurements" specifies. Read that section first; it is the spec. Do not restate it
from memory — quote it.

**In scope:** reading dashboard/API/stack source; read-only SSH to `weewx` (`ssh -F .local/ssh/config
weewx "<cmd>"` from `c:\CODE\weather-belchertown`); live GETs against the API on weewx
(`curl -sk https://127.0.0.1:8765/api/v1/...` inside the ssh); running `pmtiles extract` on weewx
into the named scratch directory `/tmp/m0-basemap/` (create it; write NOTHING anywhere else on
any host — this directory is the operator-authorized scratch carve-out for this task, per
rules/agents.md "Scratch-experiment carve-out"; the plan is the authorization). Also `pmtiles show`
on each extract for tile counts.

**Out of scope / files NOT to touch:** every file in every repo (no edits, no git add/commit); any
path on weewx other than `/tmp/m0-basemap/`; `/etc/weewx-clearskies/` (you cannot read it as the
`claude` user — use the live API endpoints for config-derived values instead); librewxr and
weather-dev (not needed). No deploys, no restarts, no `chown`/`chmod`.

**Verification command (before closeout):** `ls -la /tmp/m0-basemap/` on weewx and `pmtiles show
<file>` for every extract, pasted raw into the deliverable.

## Reading list (read BEFORE measuring)
1. `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` — §START HERE (first 45 lines), §NAMED
   CONSTANTS "Map extents (M1)", §PHASE M (M0, M1, M3, M4, Gate M), PRIME DIRECTIVE 13–15.
2. `docs/decisions/ADR-078-geographic-features-overlay.md` — the existing PMTiles feature (its
   extract command shape is what you will reuse).
3. `docs/reference/pmtiles-protomaps-reference.md` — local reference; do NOT web-fetch Protomaps docs
   for anything this file already answers.
4. `repos/weewx-clearskies-dashboard/src/components/marine/LocationMap.tsx` (whole file, 416 lines),
   `repos/weewx-clearskies-dashboard/src/routes/seismic.tsx` (lines 100–300),
   `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx` (lines 380–560 and
   800–840, 1270–1360) — the three map surfaces' extent/zoom rules AS CODED. Also find the surf
   height map's Leaflet container (grep the dashboard `src/` for `imagery` / `esri` / `naip`) and
   record its extent/zoom rule too — the plan lists it as the fourth surface.
5. `repos/weewx-clearskies-api/weewx_clearskies_api/services/geographic_features.py` — the
   existing `pmtiles extract` invocation (lines 108–130).
6. `repos/weewx-clearskies-dashboard/node_modules/protomaps-leaflet/` — `package.json` (version),
   `dist/index.d.ts` or `src/` — for (d): which built-in themes/`paintRules`/`labelRules` exports
   exist in the INSTALLED version and how a labels-only rule set is expressed. Cite file + line.

## Lead calls (already decided — do not re-derive)
- Live values: station lat/lon, quake radius and marine locations come from the live API
  (`/api/v1/earthquakes/config`, `/api/v1/marine`, `/api/v1/capabilities` for the radar `bounds`).
  Paste each raw response excerpt with its command.
- Box arithmetic: seismic box = station ± radius_km × 1.15 converted to degrees (lat: km/111.32;
  lon: km/(111.32·cos lat)) — this mirrors `seismic.tsx:203–210`; show the arithmetic. Marine box =
  bounding box of all marine locations + the map's 40 px padding at zoom 15 (state the metres/pixel
  at z15 for this latitude and the resulting degree pad). Union box = union of the two. Radar box
  = the capability `bounds` verbatim.
- Extracts to run (all against `https://build.protomaps.com/<latest available YYYYMMDD>.pmtiles`;
  try today UTC then yesterday, as the service does):
  1. `world.pmtiles`: `--bbox=-180,-85,180,85 --maxzoom=6`
  2. `local.pmtiles`: union box, `--minzoom=7 --maxzoom=15` (if the installed CLI has no
     `--minzoom`, run `--maxzoom=15` and say so — record the CLI version from `pmtiles --help`/`version`)
  3. `marine15.pmtiles`: marine box only, `--maxzoom=15` (isolates the z15 cost)
  4. `radar.pmtiles`: radar coverage box, `--maxzoom=12`
  Record for each: wall-clock, bytes, tile count (`pmtiles show`), and the exact command.
- Ceilings stated by the plan BEFORE these measurements: world ≤ 100 MB, local ≤ 400 MB. Report
  against them; do not adjust them.
- Run the extracts sequentially with `nice -n 10`; the API host is production. If any single
  extract exceeds 30 minutes, kill it, record the partial, and continue with the next.

## Git restrictions
You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout`
of remote branches. You may only `git status`, `git log`, `git diff` (read-only task — no `git add`
or `git commit` either). If the remote is ahead or behind, STOP and report via SendMessage.

## Architectural changes — STOP, do not proceed
This task changes nothing; if any step would require a change to code, config, or a persisted
file outside `/tmp/m0-basemap/`, STOP and report via SendMessage.

## Stale tests — STOP, do not obey them
Not applicable (no code), but if you notice a test that contradicts the plan's M-phase design,
note it in the deliverable as a finding.

## Reporting
1. First action: SendMessage the lead a scope acknowledgment (deliverable, what you will not touch,
   the verification command). Then proceed without waiting (the lead pre-confirms this brief).
2. Status every ~4 minutes (which extract is running, elapsed).
3. Closeout: SendMessage with the deliverable path and the four extract size/tile-count numbers.
Every number in the deliverable carries the command that produced it.
