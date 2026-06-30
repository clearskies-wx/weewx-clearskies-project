# PMTiles & protomaps-leaflet Reference

Captured: 2026-06-29 via web research + official docs.

---

## PMTiles format

PMTiles is a single-file archive of pre-processed, zoom-level-simplified vector tiles. The browser loads only the tiles visible in the current viewport via HTTP Range requests — typically 20-50 KB per tile. No tile server required.

- Spec: https://docs.protomaps.com/pmtiles/
- Version: PMTiles v3
- Data source: OpenStreetMap (ODbL license)

## Protomaps basemap daily builds

- Download URL pattern: `https://build.protomaps.com/YYYYMMDD.pmtiles`
- Example: `https://build.protomaps.com/20260628.pmtiles`
- Browse builds: https://maps.protomaps.com/builds/
- Full planet size: ~120 GB (z0-z15)
- Docs: https://docs.protomaps.com/basemaps/downloads

## pmtiles CLI (Go binary)

The Go `pmtiles` CLI (`go-pmtiles`) does remote BBOX extraction with minimal byte-range I/O — it reads only the needed tiles from the remote file, NOT the whole planet.

**NOT the Python package.** The `pip install pmtiles` Python package is for reading/writing archives programmatically (beta quality) and does NOT expose a BBOX extract command.

### Extract command

```bash
pmtiles extract https://build.protomaps.com/20260628.pmtiles output.pmtiles \
  --bbox=-130,27,-106,41 --maxzoom=12
```

- `--bbox=west,south,east,north` (decimal degrees, no spaces)
- `--maxzoom=N` limits the maximum zoom level (reduces file size)
- `--dry-run` shows output size without downloading
- Source: https://docs.protomaps.com/pmtiles/cli

### Regional extract sizes

No published size tables. Use `--dry-run` for exact numbers. Rules of thumb:
- Each zoom level roughly quadruples tile count
- z0-5 world extract: ~17 MB
- z0-6 Berlin region: ~68 MB
- 14°×24° BBOX (SoCal + surrounding states) at z0-12: estimated **200-500 MB**

## protomaps-leaflet (npm package)

Canvas-based vector tile renderer for Leaflet. Works with existing Leaflet 1.x.

- Repo: https://github.com/protomaps/protomaps-leaflet
- npm: `protomaps-leaflet` + `pmtiles` (JS reader)
- Status: maintenance mode (Protomaps recommends MapLibre GL JS for new projects, but protomaps-leaflet is stable and works with Leaflet)

### Lines-only rendering (no full basemap)

To render ONLY lines without labels, buildings, or landuse, pass custom `paintRules` with only the desired layers, and pass empty `labelRules`:

```javascript
import * as protomapsL from "protomaps-leaflet";

const layer = protomapsL.leafletLayer({
  url: "/api/v1/geographic-features/tiles",
  paintRules: [
    {
      dataLayer: "boundaries",
      symbolizer: new protomapsL.LineSymbolizer({
        color: "#ffffff",
        width: 1.5,
        opacity: 0.7,
      }),
    },
    {
      dataLayer: "roads",
      symbolizer: new protomapsL.LineSymbolizer({
        color: "#999999",
        width: 1,
        opacity: 0.5,
      }),
      filter: (zoom, feature) =>
        ["highway", "trunk"].includes(feature.props["pmap:kind"]),
    },
    {
      dataLayer: "water",
      symbolizer: new protomapsL.LineSymbolizer({
        color: "#4a90d9",
        width: 1,
        opacity: 0.6,
      }),
    },
  ],
  labelRules: [], // no labels at all
});

layer.addTo(map);
```

### Styling API

- **`paintRules`**: Array of `{ dataLayer, symbolizer, filter?, minzoom?, maxzoom? }`
  - `dataLayer`: source layer name in the PMTiles archive (e.g., `"boundaries"`, `"roads"`, `"water"`, `"earth"`, `"natural"`, `"landuse"`, `"buildings"`, `"places"`)
  - `symbolizer`: one of `LineSymbolizer`, `PolygonSymbolizer`, `CircleSymbolizer`, `IconSymbolizer`, `GroupSymbolizer`
  - `filter`: `(zoom: number, feature: Feature) => boolean` — filter features within a layer
  - Feature properties accessed via `feature.props` (e.g., `feature.props["kind"]`). **Note: Protomaps basemap v4+ uses bare `kind`, NOT `pmap:kind` (that was the v2 schema).**
- **`labelRules`**: Array of label rules. Pass `[]` for no labels.
- **`LineSymbolizer` options**: `{ color, width, opacity, dash?, dashColor?, dashWidth? }`
- **`PolygonSymbolizer` options**: `{ fill, opacity, stroke?, width? }`

### Protomaps basemap layer names

The Protomaps basemap uses these layer names (subset relevant to geographic features):

| Layer | Contains | `kind` values | Notes |
|-------|----------|--------------|-------|
| `boundaries` | Administrative boundary lines | `country`, `region`, `county`, `locality` | Line geometry. `kind_detail` has admin level. |
| `roads` | Road network lines | `highway`, `major_road`, `medium_road`, `minor_road`, `path`, `ferry` | Line geometry. |
| `water` | Water bodies (polygons) + waterways (lines) | `water`, `lake`, `ocean`, `playa`, `other` | `kind_detail` distinguishes `river`, `riverbank`, `canal`. Rivers are LINE features; lakes/ocean are POLYGON. |
| `transit` | Railways, ferries | `rail`, `ferry` |
| `earth` | Land polygons | — |
| `natural` | Parks, forests | `park`, `forest`, `wetland` |
| `landuse` | Urban/industrial areas | `residential`, `commercial`, `industrial` |
| `buildings` | Building footprints | — |
| `places` | City/town labels | `city`, `town`, `village` |

**Note:** Actual layer names and property values should be verified against the specific PMTiles build being used. The `pmap:kind` property is Protomaps-specific.

## FastAPI/Starlette Range request compatibility

Starlette's `FileResponse` handles HTTP Range requests natively:
- Sends `Accept-Ranges: bytes` header
- Returns `206 Partial Content` for valid `Range: bytes=offset-end` headers
- Works out of the box with FastAPI — no additional middleware needed

The PMTiles JavaScript client (`pmtiles` npm package) uses **single-range** `Range: bytes=offset-end` requests (standard `fetch` with a Range header). It reads the header/root directory first, then issues individual range requests per tile. It does NOT use multi-range (`multipart/byteranges`).

**Result:** Starlette FileResponse is fully compatible with the PMTiles JS client.

## Installation on weewx host

The Go `pmtiles` CLI binary needs to be available on the weewx host for the API's download/extract endpoint:

```bash
# Download the latest release binary
curl -L -o /usr/local/bin/pmtiles \
  https://github.com/protomaps/go-pmtiles/releases/latest/download/pmtiles_linux_amd64
chmod +x /usr/local/bin/pmtiles
```

Or via `go install`:
```bash
go install github.com/protomaps/go-pmtiles/cmd/pmtiles@latest
```
