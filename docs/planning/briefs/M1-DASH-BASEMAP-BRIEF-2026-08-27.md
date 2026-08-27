# M1-DASH brief — CS-BASEMAP dashboard side (M1 marine/seismic + M3 radar rebase)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, tasks M1 (dashboard) + M3 RADAR-REBASE. Date
2026-08-27. Lead: coordinator. Teammates: `clearskies-dashboard-dev` (code) +
`clearskies-test-author` (vitest). Auditor: `clearskies-auditor`, adversarial, results-free gate file
`scratch/GATE-M1-DASH-DEFINITION.md` (lead-written; teammates never edit it). M4 (surf height map)
is a SEPARATE later round — do not touch `HeatMapCard.tsx`/`useImageryConfig.ts`.

**Pre-round verification (lead, 2026-08-27):** dashboard repo
`c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard` HEAD `125b642` = origin/main, clean;
`node_modules` present locally; `protomaps-leaflet` 5.1.0 + `@protomaps/basemaps` 5.7.2 installed;
exports verified in `node_modules/protomaps-leaflet/dist/esm/index.d.ts:674` (`leafletLayer`,
`paintRules`, `labelRules`, `LineSymbolizer`, `exp`, `PMTiles` via the `pmtiles` package) and
`@protomaps/basemaps/dist/esm/index.d.ts:141` (`DARK`, `LIGHT`, `namedFlavor`). The API endpoints
this round consumes are being built concurrently (M1-API round) to the contract in the plan; they
are NOT deployed. For rendering, the lead has staged the real M0 extracts in
`c:\CODE\weather-belchertown\scratch\basemap-dev\` (`basemap-world.pmtiles`, `basemap-local.pmtiles`,
`basemap-radar.pmtiles`, `status.json`) — serve them with
`npx http-server c:\CODE\weather-belchertown\scratch\basemap-dev -p 8799 --cors -s` (Range-capable)
and run the dev server with `BASEMAP_DEV_ORIGIN=http://localhost:8799` and
`API_DEV_ORIGIN=https://weather-test.shaneburkhardt.com` (live data through the dev site's own
`/api` proxy).

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` → §"M1 — CS-BASEMAP" in full, especially
"Required content of the dark basemap", "Lead mechanics — dashboard side" (every bullet binding),
§"M3 — RADAR-REBASE", PRIME DIRECTIVE 13–15, and §"Gate M". Also `scratch/M0-MAP-EXTENTS.md` (d)
for the verified theme API facts and the box coordinates.

## Scope — dashboard-dev
**Allowlist (exhaustive):** NEW `src/lib/basemap.ts`; `src/lib/map-attribution.ts`;
`src/components/marine/LocationMap.tsx`; `src/routes/seismic.tsx`; `src/components/shared/radar-map.tsx`;
`src/routes/about.tsx` (line 28 only); `vite.config.ts` (the env-gated dev proxy ONLY);
`public/locales/*/…` — the marine namespace file in all 13 locales for the ONE new key
`map.basemapUnavailable` (find the namespace file that carries `map.ariaLabel`); `CHANGELOG.md`
(dashboard). META repo docs (separate commit in `c:\CODE\weather-belchertown`, branch `main`):
`docs/manuals/DASHBOARD-MANUAL.md` §10 (the "Basemap swap" bullet and the whole "Geographic
features vector tile overlay (ADR-078)" block → rewritten to the as-built single
`ProtomapsLayer mode="satellite-outlines"`), §12 map-layer contract (grep `CARTO`, `light_only_labels`,
`TILE_CONFIG`); `docs/manuals/DESIGN-MANUAL.md` only where it names CARTO (grep).
**NOT to touch:** `HeatMapCard.tsx`, `useImageryConfig.ts`, `radar-card.tsx`, `radar-layer-panel.tsx`,
`radar.tsx`, `MapBoundsEnforcer`/`BoundsMask` (directive 14), any test file (test-author), `package.json`
(no new dependency — both packages are already installed), `src/api/openapi-v1.yaml` (contract round),
anything else.

**Named traps:** (1) the radar map gets the `radar` tier only — never the world/local tiers, never
a box from anywhere but the `bounds` the map already enforces (Q8/directive 14). (2) Freeways must
be visible from z7 — do not keep the flavor's own road min-zooms. (3) Labels: never two label
layers at one zoom (world ≤ 6, local ≥ 7). (4) No `CARTO` string survives anywhere (`grep -ri
cartocdn src/` = 0 is a gate row). (5) The `PMTiles` instance cast (`as any` with the eslint
disable) is the existing accepted pattern — keep it, do not "fix" it. (6) The dark base under the
satellite view stays OFF (satellite frames are opaque); only the outlines+labels layer draws above
them. (7) `key={resolvedTheme}` remount semantics in `LocationMap.tsx` stay. (8) i18n: every new
user-visible string through `t()`; a11y: the banner keeps its `role`/`aria-live`. (9) `tsc --noEmit`
ZERO errors. (10) Do not add a basemap toggle or any control — zero controls (PRIME DIRECTIVE 11).

**Render-and-look is mandatory (rules/coding.md §4):** with the dev server + http-server running,
screenshot `/marine` (full and hero variants — the hero appears after selecting a location; if the
headless route cannot select, screenshot the full map and say so), `/seismic`, `/radar` (radar view
and satellite view) in BOTH themes. Use `npx playwright screenshot --color-scheme=dark
--viewport-size=1400,900 <url> <png>` if Playwright's chromium is installed (`npx playwright install
chromium` is allowed), else headless Edge (`"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
--headless=new --disable-gpu --force-dark-mode --screenshot=… --window-size=1400,900 <url>`). Save
PNGs to `c:\CODE\weather-belchertown\scratch\m1-dash-renders\` named `<route>-<theme>[-satellite].png`
and, for each, write one sentence of what the image actually shows (freeways named — I-405/I-5/SR-55
must be identifiable on the dark seismic map at its initial zoom and on the dark marine hero at
z14; labels present; no watermark; no blank inside the box; a pan outside the box shows world ground).
Open each PNG with the Read tool and LOOK before claiming it.

**Verification commands (before closeout):** `npx tsc --noEmit` (zero errors);
`npx vitest run src/lib/basemap.test.ts src/components/marine/LocationMap.test.tsx` plus any test
file the test-author names; `grep -ri cartocdn src/ ; grep -rn "CARTO_OSM_ATTRIBUTION\|geographic-features" src/`
(both empty); `npx @axe-core/cli http://localhost:5173/marine` (and /seismic, /radar) — zero
violations or each named.

**Deliverable:** commits on dashboard `main` (local; never push) + one meta docs commit; closeout per
your agent definition with raw outputs and the render descriptions.

## Scope — test-author
**Allowlist:** NEW `src/lib/basemap.test.ts`; `src/components/marine/LocationMap.test.tsx` (update —
the CARTO label-overlay assertions are STALE by design of this round: update them in the same
round, list each changed assertion with the reason); any existing test that references
`radar-map.tsx`'s deleted symbols or `CARTO_OSM_ATTRIBUTION` (grep `src/` for tests; list them).
Nothing else.
**Tests to write (against the plan's contract):** `darkBasePaintRules()` — contains no `buildings`/
`landuse`/`pois` rules; exactly two `roads` rules; the freeway rule's filter accepts
`{kind:'highway'}` at z7 and z15 and rejects `{kind:'minor_road'}`; the primary rule's filter
accepts `{kind_detail:'primary'}` only at z ≥ 11; widths evaluated at z7/z11/z15 match the plan's
`exp()` stops. `labelRulesFor('dark')`/`('light')` — only `places`/`water` data layers.
`SATELLITE_OUTLINE_PAINT_RULES` — the four ADR-078 rules with their exact colours/widths/opacities
(`#ffffff` 1.5 0.7 ×2, `#999999` 1 0.5 highway|major_road, `#4a90d9` 1 0.6 non-ocean).
`BASEMAP_TIERS` URLs. `LocationMap` — in dark theme renders the world+local `ProtomapsLayer`
pair and no CARTO `TileLayer`; in light theme one OSM `TileLayer` + the label layers; attribution
strings contain "Protomaps" in dark. Pre-change failure transcript in each new/changed module's
docstring comment (run at `125b642` first).
**Verification:** `npx vitest run <your files>`; deliverable: commits on dashboard `main`.

## Reading list (both, in order)
1. Plan §M1 (whole) + §M3 + Gate M + PRIME DIRECTIVE 13–15; `scratch/M0-MAP-EXTENTS.md`.
2. `docs/manuals/DASHBOARD-MANUAL.md` §10 (`:797–950`) and §12 (`:1023–1360`, the map-layer contract);
   `docs/manuals/DESIGN-MANUAL.md` (grep `map`, `Leaflet`, `CARTO`).
3. `docs/reference/pmtiles-protomaps-reference.md` (local reference — do not web-fetch Protomaps docs
   for anything it answers); `docs/decisions/ADR-078-geographic-features-overlay.md`.
4. `src/components/shared/radar-map.tsx` `:1–30`, `:386–575`, `:800–840`, `:1265–1365`;
   `src/components/marine/LocationMap.tsx` (whole, 416 lines); `src/routes/seismic.tsx` `:1–30`,
   `:120–140`, `:195–215`, `:280–300`; `src/lib/map-attribution.ts`; `src/routes/about.tsx` `:20–35`;
   `src/hooks/useApiQuery.ts` + `src/api/client.ts` (`fetchApi`); `src/lib/theme-provider.tsx`.
5. `node_modules/protomaps-leaflet/src/frontends/leaflet.ts` (how `leafletLayer` consumes
   `paintRules`/`labelRules`/`maxDataZoom`/pane and which GridLayer options pass through) and
   `node_modules/@protomaps/basemaps/dist/esm/index.js` (`paintRules`/`labelRules` structure:
   `dataLayer` names, the roads rules' filters and the flavor colour fields).
6. `rules/coding.md` §4 (render and look), §5, §6, §9, §10; `rules/verification.md` KAT section.

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
or `git checkout` of remote branches. You may only `git add <explicit paths>`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve
it yourself. Edit and commit ONLY on the local machine; SSH to containers is read-only.

**Architectural changes — STOP, do not proceed.** You may not make an architectural change. If your
task requires one, STOP and report via SendMessage — do not implement it, do not work around it, do
not pick an option. A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or criterion inside one. This does NOT cover changing how the same equation is solved — iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the first is architectural. An approximation that does not converge to the original equation IS a formula change and is covered.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units crossing a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
**These do NOT authorize you:** "my task's acceptance criteria are unreachable without it" (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a finding to report, not permission to change code).
You MAY still: resolve a contradiction between two statements inside the same document by taking the reading its own examples support (and say so); apply a rule already written in the rules files; fix code that diverges from its own stated contract.
**The coordinator's ruling on your report is FINAL.** You surface an architectural concern ONCE, via SendMessage, then comply with the coordinator's answer. If the coordinator states that operator approval exists, that statement is your full authorization — verifying the approval chain is the coordinator's responsibility and the coordinator's alone. Do not refuse a second time, do not demand to see the paper trail, do not audit the coordinator's authority.
*Coordinator statement for this round:* replacing CARTO with the product basemap on the marine,
seismic and radar/satellite maps, consuming the new `/api/v1/basemap/*` endpoints, and removing the
dashboard's reads of `/api/v1/geographic-features/*` (triggers 2, 7) are operator-approved — plan
PA2, M3, directives 13–15 (rulings 2026-08-27). That statement is your full authorization for exactly
those items and nothing else.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing. *For this round the lead has pre-identified `LocationMap.test.tsx`'s CARTO label
assertions as stale-by-design; the test-author updates them; the dev reports any OTHER failing test.*

## Reporting
Scope ack first (SendMessage to the lead), then proceed — pre-confirmed unless the ack names a file
outside the allowlist. Status every ~4 minutes. Closeout per your agent definition with raw outputs.
