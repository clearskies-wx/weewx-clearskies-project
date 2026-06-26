# WMS-T Rendering Research

**Date:** 2026-06-26
**Status:** Complete
**PoC:** [wms-t-poc/](wms-t-poc/) (standalone HTML, verified working against live IEM endpoints)

---

## 1. Why the first attempt failed

The previous implementation treated WMS tiles like CDN XYZ tiles: every time
frame was rendered as a separate `<TileLayer>` component, all mounted
simultaneously. For RainViewer (a CDN serving pre-rendered PNGs), this works —
tiles are static files fetched from edge servers.

WMS is fundamentally different. Every GetMap request triggers server-side
rendering: the WMS server reads the data, applies symbology, composites
layers, and renders the response image on demand. Mounting 300 TileLayer
components simultaneously means 300 × (tiles per viewport) simultaneous
server-side render requests. With a typical viewport showing ~12 tiles, that's
~3,600 concurrent WMS render jobs. The server either throttles, times out, or
returns errors.

Additionally, the code used Leaflet's `TileLayer` (XYZ pattern) for WMS URLs,
embedding `{bbox-epsg-3857}` as a template variable. Leaflet's TileLayer only
knows `{x}`, `{y}`, `{z}`, `{s}`, `{r}` — any other `{variable}` throws
"No value provided for variable". The correct class is `L.TileLayer.WMS`,
which handles BBOX, CRS, and WMS-specific parameters internally.

## 2. The correct WMS-T animation pattern

**One WMS layer, TIME parameter swaps per frame.**

The pattern has three parts:

### 2.1 TimeDimension (time manager)

`L.TimeDimension` manages the time array — an ordered list of ISO 8601
timestamps. It tracks the current time, provides next/previous navigation, and
emits events when time changes. All time-aware layers register with the same
TimeDimension instance, which is how they stay synchronized.

```javascript
// TimeDimension is created automatically when map has timeDimension: true
var map = L.map('map', {
  timeDimension: true,
  timeDimensionOptions: {
    timeInterval: startISO + '/' + endISO,  // e.g. last 2 hours
    period: 'PT5M'                          // 5-minute steps
  }
});
```

### 2.2 WMS layer wrapper

`L.timeDimension.layer.wms` wraps a standard `L.TileLayer.WMS`. When the
TimeDimension's current time changes, the wrapper updates the WMS layer's
`time` parameter and triggers a tile refresh. The wrapper also manages a cache
of hidden layers for adjacent time steps so frame transitions are instant.

```javascript
var wmsLayer = L.tileLayer.wms(WMS_ENDPOINT, {
  layers: 'nexrad-n0r-wmst',
  format: 'image/png',
  transparent: true,
  version: '1.1.1'
});

var tdLayer = L.timeDimension.layer.wms(wmsLayer, {
  cache: 20,            // total cached layers
  cacheBackward: 10,    // preload 10 past frames
  cacheForward: 5,      // preload 5 future frames
  wmsVersion: '1.1.1'
});
tdLayer.addTo(map);
```

### 2.3 Animation player

`L.TimeDimension.Player` advances the current time at a configurable rate. It
maintains a buffer of pre-loaded frames and pauses playback when the buffer
runs low (waiting for tiles to load before advancing).

```javascript
// Player is created automatically with timeDimensionControl: true
timeDimensionControlOptions: {
  playerOptions: {
    transitionTime: 400,    // ms between frames
    loop: true,
    buffer: 5,              // pre-load 5 frames ahead
    minBufferReady: 2       // pause if <2 frames ready
  }
}
```

## 3. Library evaluation

### 3.1 leaflet-timedimension (recommended)

- **npm:** `leaflet-timedimension@1.1.1`
- **Source:** github.com/socib/Leaflet.TimeDimension
- **License:** MIT
- **Leaflet compatibility:** Works with Leaflet 1.9.x (verified in PoC)
- **Dependencies:** `iso8601-js-period@0.2.1` (ISO 8601 duration parsing)
- **Maintenance:** Last npm publish: 2019. Not actively developed, but stable
  and widely used for WMS-T. The API surface is complete for our use case.

**Strengths:**
- Handles the entire WMS-T animation lifecycle (time management, layer
  caching, player, controls)
- Built-in support for `requestTimeFromCapabilities` (auto-discover available
  times from WMS GetCapabilities)
- Multiple layers sync to the same TimeDimension automatically
- Cache/preload mechanism (`cacheBackward`/`cacheForward`) avoids flash on
  frame transitions
- Player buffers frames and pauses when buffer is low

**Weaknesses:**
- No React wrapper — requires custom component integration (see §5)
- Control UI is styled with its own CSS, not customizable without overrides
- The `iso8601-js-period` dependency is tiny but old

**Verdict:** Use it. The library solves exactly the problem we have. It's
stable, well-documented, and the PoC proves it works with IEM NEXRAD. The
lack of React wrapper is manageable — we need a custom component anyway to
match our UI design.

### 3.2 leaflet-wms-animator

- **npm:** `leaflet-wms-animator@0.1.1`
- **Last publish:** 2016
- **Verdict:** Abandoned. Pre-fetches temporal slices as image overlays, not
  tiled WMS. No caching, no player, no multi-layer sync.

### 3.3 Leaflet-WMS-Time-Slider

- **Source:** github.com/BobTorgerson/Leaflet-WMS-Time-Slider
- **Verdict:** Proof-of-concept quality. Creates separate WMS layers per time
  step (the anti-pattern we're avoiding). No npm package.

### 3.4 Custom implementation (no library)

- **Approach:** Use `L.TileLayer.WMS.setParams({ time: isoString })` directly
  in a React hook/timer.
- **Verdict:** Viable but reinvents the wheel. We'd need to build: time array
  management, preloading/caching, player with buffer, multi-layer sync. All of
  this already exists in leaflet-timedimension. The library is ~15KB minified;
  the custom implementation would be larger and less tested.

### 3.5 OpenLayers

- **Verdict:** Not applicable. Our dashboard uses Leaflet/react-leaflet.
  Noted only for reference — OpenLayers has native WMS-T support via
  `ol.source.TileWMS` with `updateParams({ TIME: value })`.

## 4. Dual-layer synchronization

Verified in PoC with two IEM NEXRAD layers (n0r and n0q).

**How it works:** All `L.timeDimension.layer.wms` instances on the same map
share the map's `L.TimeDimension` instance. When the TimeDimension advances
to the next time step, it fires a `timeload` event. Every registered layer
receives the event and updates its WMS `time` parameter. The layers update in
the same event loop tick — they don't drift.

**For NEXRAD + MRMS sync:**
```javascript
// Both layers use the same map (same TimeDimension)
var nexradLayer = L.timeDimension.layer.wms(nexradWms, { /* opts */ });
var mrmsLayer = L.timeDimension.layer.wms(mrmsWms, { /* opts */ });
nexradLayer.addTo(map);
mrmsLayer.addTo(map);
// Time advances → both layers update TIME in lockstep
```

**Time step alignment:** NEXRAD and MRMS both update every 5 minutes but may
have slightly different available times. The TimeDimension uses the time array
set via `timeInterval`/`period` — both layers request the same TIME value. If
a layer has no data for that exact time, the WMS server returns the nearest
available (IEM) or a blank tile (some servers). This is acceptable for our
use case.

**For satellite layers:** Same pattern. GOES satellite WMS-T layers added to
the same map will sync to the same TimeDimension.

## 5. react-leaflet integration strategy

No official React wrapper exists. The integration pattern is a custom React
component using react-leaflet v5's `useMap()` hook.

**Pattern:** The component accesses the Leaflet map instance via `useMap()`,
creates the TimeDimension and WMS layers using Leaflet's imperative API, and
manages lifecycle with `useEffect`. React state drives the play/pause/seek
UI; the TimeDimension player handles the actual animation.

```tsx
// Simplified pattern — full implementation in D5
function WmsTimeLayer({ url, layers, timeInterval, period }) {
  const map = useMap();

  useEffect(() => {
    // Create TimeDimension if not already on the map
    if (!map.timeDimension) {
      map.timeDimension = L.timeDimension({
        timeInterval,
        period
      });
      map.timeDimension.addTo(map);
    }

    // Create WMS layer and wrap
    const wmsLayer = L.tileLayer.wms(url, {
      layers, format: 'image/png', transparent: true
    });
    const tdLayer = L.timeDimension.layer.wms(wmsLayer, {
      cache: 20, cacheBackward: 10, cacheForward: 5
    });
    tdLayer.addTo(map);

    return () => { map.removeLayer(tdLayer); };
  }, [map, url, layers, timeInterval, period]);

  return null; // renders nothing — side-effect only
}
```

**Why not use leaflet-timedimension's built-in controls:**
Our dashboard has its own time slider, play/pause buttons, and layer panel
(per the DESIGN-MANUAL). We don't want leaflet-timedimension's control UI.
Instead, we use its TimeDimension + Player API programmatically:

- `map.timeDimension.setCurrentTime(ms)` — seek to a specific time
- `player.start()` / `player.stop()` — play/pause
- `map.timeDimension.on('timeload', callback)` — update React state when
  frame changes
- `map.timeDimension.getAvailableTimes()` — get time array for slider

The dashboard's React components call these methods; leaflet-timedimension
handles the WMS TIME parameter internally.

**TypeScript:** leaflet-timedimension has no `@types` package. We'll need a
minimal `.d.ts` declaration file for the classes we use (`L.TimeDimension`,
`L.timeDimension.layer.wms`, `L.TimeDimension.Player`).

## 6. Known gotchas and mitigations

### 6.1 CORS

IEM NEXRAD endpoints respond with `Access-Control-Allow-Origin: *`. NOAA
nowCOAST and MapServer endpoints also support CORS. No proxy needed for
browser-direct WMS requests.

### 6.2 Tile preloading and memory

Each cached frame holds a full set of tiles in memory. With
`cacheBackward: 10` and `cacheForward: 5`, that's 15 frames × ~12 tiles per
viewport = ~180 tile images in memory. At ~50KB each (PNG, 256×256), that's
~9MB — well within browser limits.

For 300-frame NOAA sets in the expanded view, DO NOT cache all 300 frames.
Cap at `cacheBackward: 20, cacheForward: 10` (30 cached frames, ~18MB). The
player's buffer mechanism handles the rest — it pauses when the buffer runs
low, waits for tiles to load, then resumes.

### 6.3 Missing TIME values

If a requested TIME value has no data, IEM returns a transparent tile (blank).
This is correct behavior — the frame shows as empty, which is visually
acceptable for brief data gaps. No error handling needed for this case.

### 6.4 WMS request rate

At 5fps animation speed with ~12 tiles per viewport, that's ~60 tile
requests per second during cache-miss frames. IEM handles this without
issues — their servers are designed for this load. The cache mechanism means
most frames are cache hits after the initial preload.

### 6.5 Frame count management

- **Card view:** Cap at 24 most-recent frames (2 hours at PT5M). The card
  view is a preview — not the full animation.
- **Expanded view:** Full frame set (up to 300). Adaptive animation speed
  targets ~15-20s loop. Cache window slides with playback position.

### 6.6 Leaflet z-index stacking

Multiple WMS layers need deterministic z-ordering. Use Leaflet panes:
```javascript
map.createPane('satellite');    // z-index 350
map.createPane('radar');        // z-index 400
map.createPane('overlays');     // z-index 450
wmsLayer.options.pane = 'radar';
```

### 6.7 L.TileLayer.WMS pane prop

Do NOT pass `undefined` to the `pane` option on `L.TileLayer.WMS`. Leaflet
calls `appendChild` on the pane element — `undefined` causes a crash. Either
set a valid pane name or omit the option entirely (defaults to `tilePane`).

### 6.8 iso8601-js-period global

leaflet-timedimension expects `iso8601-js-period` as a global (`nezasa`
namespace). When bundling with Vite/webpack, either:
- Import it as a side-effect: `import 'iso8601-js-period'` (it self-registers)
- Or add to `index.html` as a `<script>` tag before the bundle

## 7. Recommended approach

**Library:** leaflet-timedimension 1.1.1 (+ iso8601-js-period 0.2.1)

**Animation pattern:** Single `L.TileLayer.WMS` per data source, wrapped with
`L.timeDimension.layer.wms`. TIME parameter swaps per frame. Preloading via
`cacheBackward`/`cacheForward`.

**Dual-layer sync:** Both NEXRAD and MRMS layers share the same
`L.TimeDimension` on the map. Time advances update both layers in lockstep.

**react-leaflet integration:** Custom component using `useMap()` hook. No
leaflet-timedimension UI controls — dashboard provides its own per the design
manual. Use TimeDimension + Player API programmatically.

**What is NOT recommended:**
- Pre-rendering all frames as separate TileLayer components
- Using `TileLayer` (XYZ) for WMS URLs
- Using `requestTimeFromCapabilities` with IEM (returns 15-year range)
- Caching all 300 frames simultaneously

---

## 8. Provider quality comparison (added during research session)

Research into the visual quality gap between raw IEM NEXRAD and commercial
radar products surfaced findings that affect the provider architecture
decision upstream of this rendering research.

### 8.1 Why raw WMS looks bad

IEM NEXRAD WMS-T serves unprocessed radar mosaics — individual radar site
scans stitched together with visible gaps, noisy edges, ground clutter, and
no interpolation between scan times. This is what every free government WMS
endpoint provides. Commercial providers (RainViewer, Tomorrow.io, LibreWxR)
process the raw data before serving tiles:

| Processing step | What it does | Who does it |
|---|---|---|
| Gaussian blur / smoothing | Softens pixelated edges | LibreWxR (`LIBREWXR_SMOOTH_RADIUS`, default 2.0) |
| Noise floor filtering | Removes low-dBZ clutter | LibreWxR (`LIBREWXR_NOISE_FLOOR_DBZ`, default 10.0) |
| Speckle removal | Eliminates isolated noisy pixels | LibreWxR (`LIBREWXR_DESPECKLE_MIN_NEIGHBORS`, default 3) |
| Spatial interpolation | Fills gaps between radar sites | Tomorrow.io (AI/neural net), RainViewer (proprietary) |
| Temporal interpolation | Generates inter-scan frames for smooth animation | LibreWxR (optical flow), RainViewer (optical flow) |
| Nowcasting | Extrapolates radar forward 30-60 min | LibreWxR (optical flow + NWP blend), Tomorrow.io (AI) |

None of this processing can happen at the dashboard or API layer — WMS
returns pre-rendered PNG tiles. To improve quality, you need access to the
raw data and a processing pipeline upstream of tile rendering.

### 8.2 LibreWxR capabilities (more than initially understood)

LibreWxR is not just a radar tile server — it is a full weather data
processing and visualization platform:

- **Radar sources:** NOAA MRMS (quality-controlled, not raw NEXRAD) + 7
  other national networks (OPERA Europe, JMA Japan, MSC Canada, etc.)
- **Processing:** Gaussian smoothing, noise filtering, speckle removal,
  optical flow interpolation, snow/rain differentiation
- **Satellite:** Global NOAA GMGSI composite (GOES + Meteosat + Himawari),
  VIS/IR with day/night crossfade, hourly cadence
- **Nowcasting:** 60-min optical flow extrapolation with radar/NWP blending
- **Alerts:** Global WMO CAP + NWS point endpoint
- **NWP model chain:** HRRR (3km US) → regional models → ECMWF IFS (9km
  global fallback), with soft-feathering at domain edges
- **13 color schemes**, motion arrows, configurable quality settings
- **Tile format:** XYZ pre-rendered (existing dashboard animation works —
  no WMS-T needed)

### 8.3 LibreWxR self-hosting constraints

- **Minimum config (US + ECMWF):** ~3-4 GB RAM
- **Full regional:** ~9-10 GB RAM
- **Smallest geographic unit:** CONUS (full continental US). Cannot scope
  to a state or sub-region.
- **Why it's so large:** MRMS grid is 3,500 × 7,000 pixels (0.01°
  resolution). ~25 MB per frame raw. The full CONUS mosaic loads regardless
  of how small your area of interest is.
- **Cropping feasibility:** The GRIB2 download is full-CONUS, but the numpy
  array could be sliced to a bounding box at ingest time before storing in
  FrameStore. For Southern California (~300 × 500 pixels), that's 0.6% of
  the full grid — massive RAM savings. Would require modifying LibreWxR
  source code: add a `LIBREWXR_BBOX` config, slice after GRIB2 decode.
  Conceptually straightforward but unverified — would need to read the
  actual fetcher code to confirm edge cases.

### 8.4 What LibreWxR does NOT provide (NOAA-unique layers)

- SPC severe weather outlooks (tornado/hail/wind probability maps)
- GOES multi-band satellite (5 separate bands vs. single composite)
- MRMS as a separately visible layer (blended into composite)

### 8.5 Open question: provider architecture direction

This research session established that WMS-T rendering works (PoC proven),
but surfaced a larger question: **what provider architecture makes sense
given the quality and resource trade-offs?**

Options under consideration (user decision, not yet resolved):

1. LibreWxR self-hosted with regional cropping (custom fork) — best
   quality, full control, requires source code modification
2. LibreWxR self-hosted as-is — best quality, no code changes, but 3-4 GB
   RAM for CONUS when only SoCal matters
3. Raw NOAA WMS-T via IEM — free, no hosting, but raw/noisy quality
4. Custom MRMS processing pipeline — fetch NOAA MRMS GRIB2 data, apply
   smoothing/filtering/interpolation locally, serve XYZ tiles. Could
   borrow processing techniques from LibreWxR (AGPL). Scoped to operator's
   region. For personal use only (not distributed to other operators).
5. Some combination of the above

The rendering approach (leaflet-timedimension for WMS-T, existing TileLayer
pattern for XYZ) is settled regardless of which provider path is chosen.
The provider decision affects which rendering path is primary.
