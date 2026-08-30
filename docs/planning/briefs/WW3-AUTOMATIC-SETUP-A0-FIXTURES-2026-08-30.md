# WW3 Automatic Setup Parity — A0 Locked Fixtures

**Companion to:** `WW3-AUTOMATIC-SETUP-A0-GATES-2026-08-30.md`
**Status:** results-free fixture/record specification. Values below are locked inputs and expected structural relations, not prototype output.

## 1. Common conventions

- Synthetic coordinates use a local Cartesian plane, origin at southwest, one unit per cell. A cell `Cxy` occupies `[x,x+1] × [y,y+1]`; its perimeter position is named by its cell centre.
- `W`, `L`, and `H` mean water fraction `1`, `0`, and `0.5`, respectively. Wet means fraction `>0` for the fixture occupancy gate; this is not a new production threshold.
- Synthetic depth field is fixed at `-20.000 m` for every synthetic cell in C0/C1/C2. It is model-datum-normalized by fixture declaration and never replaced by OSM or a fine DEM.
- The obstruction value for C2 is exactly `1-tau`; `tau` is the locked horizontal water-area fraction. `FLAGTR=2` is an occupancy/transmission representation only, not diffraction.
- Perimeter lists are clockwise from the southwest corner and de-duplicate a corner shared by two sides. `N/E/S/W` in a fixture name describes geometry only, not a candidate policy.
- Every synthetic OSM ocean segment is directed so land is left and water is right. Every synthetic lake is a closed multipolygon with outer rings and inner island holes explicitly listed.

## 2. Rotational and Myrtle occupancy fixtures

### F-R90-0: base coast and rotations

Grid: `4 × 4`; land polygon: `(0,3) (4,3) (4,4) (0,4) (0,3)`; all unlisted area is water.

```text
y=3  L L L L
y=2  W W W W
y=1  W W W W
y=0  W W W W
     0 1 2 3   x
```

Expected wet perimeter cells: `C00,C10,C20,C30,C31,C32,C22,C12,C02,C01,C00` represented once in the ordered set as `C00,C10,C20,C30,C31,C32,C22,C12,C02,C01`. Expected dry perimeter cells: `C03,C13,C23,C33`.

The three additional fixtures are exact rotations about `(2,2)`: F-R90-90 maps `(x,y)→(3-y,x)`; F-R90-180 maps `(x,y)→(3-x,3-y)`; F-R90-270 maps `(x,y)→(y,3-x)`. Their occupancy polygons, wet/dry perimeter sets, point order, O mapping and H curve must be the transformed base fixture exactly. The fixed-S/W and unrotated-output mutations are required failures.

### F-MB: Myrtle-Beach-shaped three-wet-side, partial-east case

Grid: `5 × 4`. Water-fraction matrix, north to south:

```text
y=3  L L L L L
y=2  W W W W H
y=1  W W W W W
y=0  W W W W W
     0 1 2 3 4   x
```

Occupancy polygons are the union of unit-water cells plus the west half of `C42` (`[4,4.5] × [2,3]`); land is the complement in `[0,5] × [0,4]`. Expected wet perimeter order: `C00,C10,C20,C30,C40,C41,C42,C32,C22,C12,C02,C01`. Expected dry perimeter cells: `C03,C13,C23,C33,C43`. This is exactly three wet sides—south, east, west—with a partial-water east cell. The upper, dry side may not be inferred wet from a full rectangular H curve, and the partial east cell may not be excluded as a whole side.

Locked topology diagram (occupancy only; it does not select H1/H2/H3):

```text
        N: L L L L L
W: W  +-----------------+  H: L/H/W
   W  |                 |  H: L/H/W
   W  |                 |  H: L/H/W
        +-----------------+
        S: W W W W W
```

## 3. Island, headland, cove, and disconnected-segment fixtures

### F-IHC-I: island with an explicit hole

Grid: `5 × 5`. Ocean outer ring is `(0,0) (5,0) (5,5) (0,5) (0,0)`. Island hole is `(2,2) (3,2) (3,3) (2,3) (2,2)`, yielding `C22=L`; every other cell is `W`. Expected wet perimeter order: `C00,C10,C20,C30,C40,C41,C42,C43,C44,C34,C24,C14,C04,C03,C02,C01`. The omitted/unfinished inner ring mutation must refuse snapshot topology before derivation.

### F-IHC-H: partial headland

Grid: `5 × 5`. Land polygon: `(4,1) (5,1) (5,4) (4.5,4) (4.5,3) (4,3) (4,1)`. This fixes `C41=L`, `C42=L`, `C43=H`; all remaining cells are `W`. Expected wet perimeter order: `C00,C10,C20,C30,C40,C43,C44,C34,C24,C14,C04,C03,C02,C01`. The water fraction of `C43` is exactly one half; island/headland geometry must not add a directional obstruction map.

### F-IHC-C: cove

Grid: `5 × 5`. Water polygon: `(1,0) (4,0) (4,3) (3,3) (3,2) (2,2) (2,3) (1,3) (1,0)`; all outside is land. Expected wet perimeter cells: `C10,C20,C30` only. The fixture is a refusal control for any candidate that makes an unsupported perimeter segment active.

### F-DS: disconnected wet segments

Grid: `6 × 4`. Water-fraction matrix, north to south:

```text
y=3  L L L L L L
y=2  W W L L W W
y=1  W W L L W W
y=0  W W L L W W
     0 1 2 3 4 5   x
```

Expected wet perimeter segments are `A=(C00,C10,C11,C12,C02,C01)` and `B=(C40,C50,C51,C52,C42,C41)`. There is no legal hidden segment between `C12` and `C42`, and no implicit last-to-first connection. H must record native-binary evidence for a one-curve representation or refuse for an operator decision.

```text
segment A:  C02 -- C12        C42 -- C52 :segment B
            |     |          |     |
            C01   C11        C41   C51
            |     |          |     |
            C00 -- C10        C40 -- C50
```

## 4. Real OSM snapshot fixtures

All requests use the existing configured absolute Overpass timeout of **25 s**. A frozen response is accepted only with request text, bbox, UTC capture time, HTTP status, complete relation/way/node closure, and SHA-256. A clipped result must carry the query bbox and a clipping flag; clipping that removes a required outer-ring segment or island hole is `REFUSE: incomplete OSM geometry`.

| ID | Exact bbox `(west,south,east,north)` | Required OSM layer/tags | Expected snapshot assertion |
| --- | --- | --- | --- |
| R-HB | `(-118.350000,33.500000,-117.800000,33.950000)` | ocean: `way["natural"="coastline"]`; directed land-left/water-right | at least one complete directed coastline way intersects the bbox; no conversion to an unbounded land polygon |
| R-MB | `(-79.200000,33.450000,-78.500000,34.000000)` | ocean: `way["natural"="coastline"]`; directed land-left/water-right | at least one complete directed coastline way intersects the bbox; no SoCal CRM or alternative occupancy source is queried |
| R-SUP | `(-91.000000,46.400000,-87.800000,48.300000)` | lake: `relation["natural"="water"]["water"="lake"]["type"="multipolygon"]["tidal"="no"]` | selected relation has `name=Lake Superior`, a closed outer ring, and all returned inner rings retained |
| R-MIHU | `(-88.200000,42.300000,-82.000000,46.400000)` | same lake relation selector | selected relation names are `Lake Michigan` and/or `Lake Huron`; each selected relation has a closed outer ring and retained inner rings |
| R-ERIE | `(-83.700000,41.200000,-78.500000,42.900000)` | same lake relation selector | selected relation has `name=Lake Erie`, a closed outer ring, and retained inner rings |
| R-ONT | `(-79.900000,43.000000,-76.100000,44.200000)` | same lake relation selector | selected relation has `name=Lake Ontario`, a closed outer ring, and retained inner rings |

Great Lakes keep the Great Lakes physical model regime. Their occupancy query must use the required `natural=water`, `water=lake`, `type=multipolygon`, `tidal=no` relation contract; a `natural=coastline` request, missing relation, missing member way, unclosed ring, missing inner island, malformed member role, snapshot hash mismatch, or geometry that cannot be clipped without losing a required ring is a refusal. The selected relation ID is recorded from the frozen snapshot; no worker may select an alternate relation by visual preference.

## 5. D-axis exact comparison record

This synthetic diagnostic fixture is the only A0 D comparison basis. The H transfer consists only of its separately declared boundary points and contains none of the following records.

| ID | Longitude | Latitude | Depth token | Role |
| --- | --- | --- | --- | --- |
| `B46222` | `-118.092000` | `33.618000` | `-50.000` | buoy diagnostic |
| `B46253` | `-118.183000` | `33.655000` | `-50.000` | buoy diagnostic |
| `SEAM00` | `-118.120000` | `33.650000` | `-20.000` | seam diagnostic |
| `DREF00` | `-118.250000` | `33.700000` | `-200.000` | deep-reference diagnostic |

Time axis tokens: `20260830 000000`, `20260830 010000`. Frequency tokens: `0.05000`, `0.10000`. Direction tokens: `0.0`, `90.0`, `180.0`, `270.0`. The canonical printed energy token sequence for every point/time is exactly `0.010000 0.020000 0.030000 0.040000 0.050000 0.060000 0.070000 0.080000`, frequency-major then direction-major. The prototype compares literal point ID, coordinate token, depth token, time token, spectral axes and this sequence for every retained diagnostic record. It may not select another point, coordinate, time, axis, or energy token after output is read.

## 6. H command/origin fixtures

The synthetic Cartesian L2 origin is longitude `0.000000`, latitude `0.000000`. The only baseline formatted command record is:

```text
BOUNDNEST3 WW3 'ww3_l2_transfer.ww3' FREE CLOSED 0.000000 0.000000
```

`UNFORMATTED` with that same formatted transfer filename is a locked format-mismatch mutation, not an alternative baseline. Locked origin mutations are: omitted `[xgc] [ygc]`; stale `0.100000 0.000000`; swapped `0.000000 0.100000`; and coordinate-order inversion. For R-HB, the frozen Cartesian origin tokens are longitude `-118.350000`, latitude `33.500000`; the corresponding swapped mutation is `33.500000 -118.350000`. The prototype must declare the selected H topology keyword before native execution; it may not alter the origin/order tokens to make a candidate appear acceptable.

## 7. Locked structural/resource checks

- OSM snapshot/query topology is verified before any fraction operation: source request, tags, complete rings/ways/nodes, land/water orientation, island holes, bbox clipping metadata, normalized coordinates, and SHA-256.
- Local fraction derivation ceiling: **≤30 s**, incremental RSS **≤512 MiB**, swap growth **0**.
- Any extra `ww3_outp` pass ceiling: **≤10 s**, incremental RSS **≤128 MiB**, swap growth **0**.
- A malformed/missing/incomplete OSM snapshot refuses. There is no occupancy-source fallback.
- All real-case output and all native-binary behavior remains `[NOT RUN]` until the separately owned prototype phase.
