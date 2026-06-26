# WMS-T Radar Animation Proof-of-Concept

Standalone HTML page demonstrating WMS-T time animation in Leaflet using
leaflet-timedimension. No build step, no React, no Clear Skies API.

## How to run

Open `index.html` in a browser. That's it — everything loads from CDNs.

```
# or serve locally to avoid file:// CORS issues in some browsers:
npx serve .
# then open http://localhost:3000
```

## What it demonstrates

1. **Single WMS layer with TIME parameter swap** — one `L.TileLayer.WMS`
   wrapped with `L.timeDimension.layer.wms`. The TIME parameter changes per
   frame advance. No pre-rendered layers, no simultaneous server requests.

2. **Play/pause/slider controls** — `L.Control.TimeDimension` provides the
   standard animation UI.

3. **Frame preloading** — `cacheBackward: 10` and `cacheForward: 5` preload
   adjacent frames as hidden layers so transitions are instant.

4. **Dual-layer sync** — two WMS-T layers (n0r and n0q) share the same
   `L.TimeDimension` instance. When time advances, both layers update their
   TIME parameter in lockstep. Toggle layers via the control at top-right.

5. **Request logging** — the bottom panel logs every WMS GetMap request with
   its TIME value. Open DevTools Network tab to verify: requests are
   sequential (per frame), not simultaneous (all frames at once).

## Endpoint

- URL: `https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi`
- Layer: `nexrad-n0r-wmst`
- Time extent: 5-minute intervals, ISO 8601 (`2026-06-26T12:00:00Z`)
- CRS: EPSG:3857
- Format: image/png, transparent

## Libraries

| Library | Version | CDN |
|---------|---------|-----|
| Leaflet | 1.9.4 | jsdelivr |
| iso8601-js-period | 0.2.1 | jsdelivr |
| leaflet-timedimension | 1.1.1 | jsdelivr |

## Key pattern (copy-paste reference)

```javascript
// 1. Create standard WMS layer
var wmsLayer = L.tileLayer.wms(WMS_URL, {
  layers: LAYER_NAME,
  format: 'image/png',
  transparent: true,
  version: '1.1.1'
});

// 2. Wrap with TimeDimension — this handles TIME parameter swapping
var tdLayer = L.timeDimension.layer.wms(wmsLayer, {
  cache: 20,
  cacheBackward: 10,
  cacheForward: 5
});
tdLayer.addTo(map);
```

## What NOT to do

- Do NOT create separate TileLayer components for each time frame
- Do NOT use `TileLayer` (XYZ) for WMS URLs — use `TileLayer.WMS`
- Do NOT pass `{bbox-epsg-3857}` in a TileLayer URL template
- Do NOT pre-render 300 frames simultaneously — WMS renders server-side
