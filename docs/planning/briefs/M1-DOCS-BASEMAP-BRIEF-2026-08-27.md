# M1-DOCS brief — governing docs for CS-BASEMAP + ADR-078 amendment (meta repo)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, task M1 (docs). Date 2026-08-27. Lead: coordinator.
Teammate: `clearskies-docs-author`. Auditor: the Gate M zero-drift row.

**Pre-round verification (lead):** meta repo `c:\CODE\weather-belchertown` HEAD `7aa9cbb1` on `main`
(remote default `master`; do not touch branches). Other agents commit to this repo concurrently
(S12's docs commit touches ARCHITECTURE.md's marine handoff paragraph; M1-DASH's touches
DASHBOARD-MANUAL §10/§12). Use Edit (never Write) on shared files, `git add` only your paths, and
retry on an index-lock collision.

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §M1 (whole: extent derivation, radar tier, files,
endpoint family, "Lead mechanics — API side", "Lead mechanics — dashboard side"), §M3, §M4 (context
only), PRIME DIRECTIVE 13–15, PA2, Q8, Q12. Facts: `scratch/M0-MAP-EXTENTS.md` (measured sizes).

## Deliverables (each a separate commit; messages start `docs(M1):`)
1. **ADR-078 amendment, status Proposed** — append to `docs/decisions/ADR-078-geographic-features-overlay.md`
   an "Amendment 2 (2026-08-27) — superseded by the product basemap (Proposed)" section: context
   (CARTO watermarking/retirement; operator rulings of 2026-08-27 quoted from the plan's Q5/Q6/Q8
   and directives 13–15), the decision (the geographic-features extract/endpoints/admin action/config
   key are replaced by the basemap family — name each old and new item side by side; the four
   outline `LineSymbolizer` rules survive verbatim as the satellite outlines layer), consequences,
   and the acceptance line "Status: Proposed — takes effect on the operator's acceptance in chat; the
   removal commit of the old feature waits for it (plan journal J3)". Do NOT change the ADR's header
   status (still Accepted for the original decision). Fix `docs/decisions/INDEX.md:151`'s stale
   "OSM via Overpass API" title to the ADR's real title and add the amendment note.
2. **ARCHITECTURE.md** (Edit, targeted): API endpoints table (`:376` geographic features row → add
   a "Basemap" row: `/api/v1/basemap/{world,local,radar}/tiles`, `/api/v1/basemap/status`; note the
   geographic-features row as "superseded by Basemap pending ADR-078 amendment acceptance");
   setup endpoints table (`:415` → add `POST /setup/basemap/update`); configuration files table
   (`:642` → add the three `basemap-*.pmtiles` rows with tiers/zooms and the `[basemap] enabled`
   key); the Dashboard row's technology cell if it names CARTO (grep). Bump the "Last verified" line
   with a one-sentence note.
3. **API-MANUAL.md**: the section that documents `geographic-features` (grep) gains a sibling
   "Basemap" section: endpoints, auth levels (public tiles/status; proxy-secret update), response
   shapes (per-tier status fields; 202/409), the extent-derivation rule (station + earthquake radius
   × 1.15 ∪ marine locations padded 40 px @ z15; radar tier = provider coverage box else station
   box), the three-tier zoom table, and the refusal rule (marine configured-but-unreachable →
   refuse, no fallback). `docs/contracts/openapi-v1.yaml`: add the three paths with schemas.
4. **OPERATIONS-MANUAL.md** §4 "File inventory" (`:537–560`): the three basemap files; §1 the
   `pmtiles` CLI prerequisite line (grep the existing ADR-078 mention and extend it); a "Basemap"
   paragraph in the admin landing page section (`:601–633`) beside Geographic Features; monitoring
   note: `last_error` in `/api/v1/basemap/status`.
5. **PROVIDER-MANUAL.md**: only if it carries a CARTO/Esri basemap attribution table (grep `CARTO`,
   `cartocdn`, `Esri`) — update the map-attribution rows to "OpenStreetMap contributors / Protomaps";
   leave the wizard's Esri satellite toggle documentation alone (directive 15).
6. **CHANGELOG** (`docs/CHANGELOG.md`): one entry "CS-BASEMAP (M1)".

**NOT to touch:** DASHBOARD-MANUAL.md (M1-DASH's agent owns it this round), the marine handoff
paragraphs of ARCHITECTURE.md (S12's agent), any file under `docs/archive/`, any repo under
`repos/`, the plan file itself (the lead edits it).

**Verification command:** `grep -rn "cartocdn\|CARTO" docs/ARCHITECTURE.md docs/manuals/API-MANUAL.md docs/manuals/OPERATIONS-MANUAL.md docs/manuals/PROVIDER-MANUAL.md` (only historical-note hits remain, each quoted in your closeout) and `git diff --stat` per commit.

## Reading list
1. Plan sections above; `scratch/M0-MAP-EXTENTS.md`.
2. `docs/decisions/ADR-078-geographic-features-overlay.md` (whole), `docs/decisions/INDEX.md:140–160`,
   `docs/decisions/_TEMPLATE.md`; `rules/clearskies-process.md` "ADR discipline" (Proposed → operator).
3. `docs/ARCHITECTURE.md` `:353–430` (endpoints), `:626–654` (config files), `:38–48` (services table);
   `docs/manuals/API-MANUAL.md` (grep `geographic-features`, `imagery`); `docs/manuals/OPERATIONS-MANUAL.md`
   `:34–60`, `:526–560`, `:601–633`; `docs/contracts/openapi-v1.yaml` (grep `geographic-features`).
4. `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/geographic_features.py` (the shape being
   generalised) and, once present, `endpoints/basemap.py` + `services/basemap_extract.py` (read the
   code if it has landed — `git -C repos/weewx-clearskies-api log --oneline -5`; if not yet, document
   the plan's contract and say so in your closeout).

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
or `git checkout` of remote branches. You may only `git add <explicit paths>`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve
it yourself. Edit and commit ONLY on the local machine.

**Architectural changes — STOP, do not proceed.** You write documentation only. If a governing
document contradicts the plan's design, that is a finding to report via SendMessage — never resolve
it by choosing. The seven-trigger test in `rules/agents.md` §"Architectural change block" applies to
any change you would document as current state that the plan does not authorize.

**Stale tests — STOP, do not obey them.** Not applicable (no code); report any test you notice that
pins CARTO/geographic-features behaviour as a finding.

## Reporting
Scope ack first, then proceed (pre-confirmed unless the ack names a file outside the allowlist).
Status every ~4 minutes. Closeout per your agent definition: commits, files, grep output, and the
exact wording of the ADR-078 amendment's decision paragraph pasted.
