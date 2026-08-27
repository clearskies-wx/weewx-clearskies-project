# M4-DASH brief — surf height map background: OSM light raster / Protomaps dark rasterized (PA9)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, task M4 (dashboard side). Date 2026-08-27. Lead:
coordinator. Teammates: `clearskies-dashboard-dev` (code) + `clearskies-test-author` (vitest).
Auditor: `clearskies-auditor`, results-free gate `scratch/GATE-M4-DEFINITION.md`.
**Dispatch condition:** after M1-DASH's dev closeout is accepted (`src/lib/basemap.ts` exists) AND
M4-API has landed (the `/imagery/config` shape).

**Pre-round verification (lead, fill at dispatch):** dashboard HEAD `<hash>`, clean; `npx tsc --noEmit`
zero; `npx vitest run src/components/marine/tabs/HeatMapCard.test.tsx src/hooks/useImageryConfig.test.ts`
→ `<n passed>`.

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"M4 — SURF-MAP-BASEMAP … lead mechanics" (the
**Dashboard** bullet: light = OSM raster via `substituteTileUrl(light.tileUrl, …)`; dark = data URLs
rasterized in the browser from the local tier with protomaps-leaflet's `View`/`TileCache`/
`PmtilesSource`/`paint` — mirror `node_modules/protomaps-leaflet/src/frontends/leaflet.ts`'s
`renderTile`; no labels in surf-map dark tiles; `useRasterizedTiles(tiles, enabled)`; attribution
follows the theme; gate rows), PA9, directive 15, Q5. The API contract: M4-API's `/imagery/config`
(`provider: "basemap"`, `light`, `dark`, `zoomMin`, `zoomMax`; legacy fields carry light).

**Lead mechanics (binding):**
- `src/api/types.ts` `ImageryConfigResponse` gains the optional `light`/`dark`/`zoomMin`/`zoomMax`
  fields (generated from the contract — `src/api/openapi-v1.yaml` is synced from the meta contract
  in the same commit).
- `src/lib/basemap.ts` gains `rasterizeBasemapTile(z, x, y, size = 256): Promise<string>` — one
  module-level `View` per tier URL (lazy; `new View(new TileCache(new PmtilesSource(url, true),
  1024), BASEMAP_TIERS.local.maxZoom, 2)`), `getDisplayTile({z, x, y})` → offscreen canvas 256×256
  (`document.createElement('canvas')`; `OffscreenCanvas` when available) → `paint(ctx, z, new
  Map([[key, [tile]]]), null, darkBasePaintRules(), bbox, origin, true)` → `canvas.toDataURL()`.
  Bounded in-memory memo (Map, ≤ 256 entries, LRU-evict) so animation/re-render does not
  re-rasterize. Errors reject; the caller renders nothing for that tile (no fallback to a remote
  provider — directive 15).
- `src/hooks/useRasterizedTiles.ts` (new): `useRasterizedTiles(tiles: {z,x,y}[], enabled: boolean)`
  → `Record<key, string>` resolved incrementally; cancels on unmount/tile-set change.
- `HeatMapCard.tsx`: `resolvedTheme === 'dark'` → the `<image href>` at `:1896–1904` reads from the
  rasterized map (tile omitted until resolved); light → `substituteTileUrl(imageryConfig.light?.tileUrl
  ?? imageryConfig.tileUrl, …)`. The mosaic geometry code (`imageryLayer` memo `:1346–1413`,
  `snapImageryBBoxToTiles`, `computeImageryTiles`, rotation, pivot) is NOT touched — byte-identical
  `imageryLayer` output is a gate row. `IMAGERY_ZOOM_MIN/MAX` unchanged. The info-modal attribution
  (`:1103–1210`) shows `light.attribution` or `dark.attribution` by theme. `HEATMAP_CELL_OPACITY`-style
  constants for the dark ground: keep today's values (the dark tiles are darker than a photo; if the
  heat cells read wrong on the render, REPORT with the screenshot — do not retune).
- `useImageryConfig.ts`: unchanged except the type.
- About page: remove Esri/NAIP attribution rows ONLY if `grep -rn "esri\|naip" src/` shows no other
  user-facing consumer (the wizard's toggle is in the stack repo, not here).
- Docs (meta): DASHBOARD-MANUAL §12 Surfing tab (HeatMapCard background paragraph) rewritten to the
  as-built; DESIGN-MANUAL only where it names orthophoto/Esri for the heat map (grep).

**Render-and-look (mandatory):** the Marine page Surfing tab with a selected spot, both themes,
same dev-server recipe as M1-DASH (`scratch/basemap-dev` + http-server + Vite env vars); PNGs to
`scratch/m4-dash-renders/`; describe what the ground shows under the heat cells (streets/coast
visible in dark; OSM raster in light); confirm in the browser network log (or Vite proxy log) that no
request to `arcgisonline`/`usgs.gov`/`cartocdn` leaves the page.

## Scope — dashboard-dev
**Allowlist:** `src/api/types.ts`, `src/api/openapi-v1.yaml`, `src/lib/basemap.ts` (additive),
`src/hooks/useRasterizedTiles.ts` (new), `src/hooks/useImageryConfig.ts` (type only),
`src/components/marine/tabs/HeatMapCard.tsx` (the `<image>` hrefs, the attribution selection, the
theme read), `src/routes/about.tsx` (attribution rows, conditional on the grep), `CHANGELOG.md`;
meta docs listed. **NOT to touch:** the mosaic geometry functions/memo, `IMAGERY_*` constants,
`LocationMap.tsx`/`seismic.tsx`/`radar-map.tsx`, tests, `package.json`.
**Verification:** `npx tsc --noEmit`; `npx vitest run src/components/marine/tabs/HeatMapCard.test.tsx src/hooks/useImageryConfig.test.ts src/hooks/useRasterizedTiles.test.ts src/lib/basemap.test.ts`;
`grep -rn "arcgisonline\|naip\|esri" src/components src/hooks src/lib` (empty, or each hit justified);
`npx @axe-core/cli http://localhost:5173/marine`.

## Scope — test-author
**Allowlist:** `src/hooks/useRasterizedTiles.test.ts` (new — mocks `rasterizeBasemapTile`; incremental
resolution; cancellation), `src/lib/basemap.test.ts` (add: `rasterizeBasemapTile` memo hit/miss with
a mocked `View`/`paint`), `src/components/marine/tabs/HeatMapCard.test.tsx` (update: light href =
`light.tileUrl` substituted; dark href = data URL from the mocked rasterizer; `imageryLayer` geometry
unchanged vs a snapshot taken pre-change at the same inputs — capture it FIRST), `src/hooks/useImageryConfig.test.ts`
(the new fields pass through). Pre-change transcripts in module comments.

## Reading list (both)
Plan §M4 (+ mechanics), PA9, Q5, directive 15; `src/components/marine/tabs/HeatMapCard.tsx` `:196–270`,
`:510–660`, `:1090–1250`, `:1340–1420`, `:1860–1920`; `src/hooks/useImageryConfig.ts`; `src/api/types.ts:2300–2360`;
`src/lib/basemap.ts` (as landed by M1-DASH); `node_modules/protomaps-leaflet/src/frontends/leaflet.ts`
(`renderTile`), `src/view.ts`, `src/painter.ts` (signature of `paint`); `docs/manuals/DASHBOARD-MANUAL.md`
§12 Surfing tab; `rules/coding.md` §4 (render and look), §5, §6, §9, §12 (memory: bounded memo).

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
*Coordinator statement:* replacing the surf height map's Esri/NAIP background with the product
basemap and the browser-side rasterization (triggers 2, 4, 5) are operator-approved — plan PA9 (Q5,
2026-08-27). Removal of the API's imagery modules is NOT (Q10-6 open).

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing. *Pre-identified stale-by-design: `HeatMapCard.test.tsx` assertions on the Esri/NAIP
`tileUrl` substitution; the test-author updates them.*

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw outputs and
the render descriptions.
