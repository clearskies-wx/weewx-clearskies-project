#!/usr/bin/env python3
'''E8d: per-variant seam/46253 integration + e8d1 field map characterization.'''
import sys, math, glob
import numpy as np
sys.path.insert(0, '/tmp/e1e2')
from ledger import parse_header, read_block, freq_widths, hs, scan_file

X0, Y0 = 283660.41, 3604292.50
DX, DY = 1021.62, 988.61
NX, NY = 143, 170

def seam_and_buoy(base):
    nf_path = sorted(glob.glob(base + 'nest_out*'))[0]
    with open(nf_path) as fh:
        locs, freqs, dirs = parse_header(fh)
    ys = [l[1] for l in locs]; ymin = min(ys)
    sidx = sorted([i for i,l in enumerate(locs) if abs(l[1]-ymin) < 1.0], key=lambda i: locs[i][0])
    pick = [sidx[int(round(k*(len(sidx)-1)/6.0))] for k in range(7)]
    out, locs = scan_file(nf_path, {0}, set(pick))
    m0m = sum(out[(0,i)][1] for i in pick)/7
    band0 = sum(out[(0,i)][2][0] for i in pick)/7
    rng = (min(hs(out[(0,i)][1]) for i in pick), max(hs(out[(0,i)][1]) for i in pick))
    # buoy 46253 = loc 0 in buoy_spec
    with open(base + 'buoy_spec.dat') as fh:
        locs2, freqs2, dirs2 = parse_header(fh)
        dfs = freq_widths(freqs2); dth = 360.0/len(dirs2)
        fh.readline()
        blk = read_block(fh, len(freqs2), len(dirs2))
        if blk in (None, 'NODATA'):
            b253 = 0.0
        else:
            m0 = sum(v*dfs[i]*dth for i,row in enumerate(blk) for v in row if v > 0)
            b253 = hs(m0)
    return hs(m0m), hs(band0), rng, b253

for v in ['e8', 'e8d1', 'e8b2', 'e8b3']:
    try:
        tot, b0, rng, b253 = seam_and_buoy('/tmp/e1e2/%s/' % v)
        print('%-5s seam AGG=%.3f (>11s %.3f, pts %.3f-%.3f)  46253=%.3f' % (v, tot, b0, rng[0], rng[1], b253))
    except Exception as e:
        print('%-5s FAILED: %s' % (v, e))

# --- field map from e8d1 ---
vals = np.array(open("/tmp/e1e2/e8d1/hs_field.dat").read().split(), float)
assert vals.size == NX*NY, vals.size
F = vals.reshape(NY, NX)  # assume LAY3 = south row first (verify vs BOTTOM land)
B = np.loadtxt('/tmp/e1e2/e8/BOTTOM.txt').reshape(NY, NX)
land = B <= 0
exc = F <= -8.0
agree = (land & exc).sum() / max(land.sum(),1)
print('\norientation check: %.0f%% of BOTTOM land cells are exception in Hs field (south-first assumption)' % (100*agree))
if agree < 0.8:
    F = F[::-1]  # north-first fallback
    exc = F <= -8.0
    print('flipped to north-first: %.0f%%' % (100*(land & exc).sum()/land.sum()))

def hs_at(x, y):
    i = int(round((x-X0)/DX)); j = int(round((y-Y0)/DY))
    if 0 <= i < NX and 0 <= j < NY:
        v = F[j,i]
        return v if v > -8.0 else None
    return None

print('\n== transects: seam pt -> az 197 (toward source) -> S boundary, 5 km spacing ==')
for name, px in (('W', 401202.5), ('mid', 405070.2), ('E', 408836.2)):
    az = math.radians(197.0)
    ux, uy = math.sin(az), math.cos(az)
    samples = []
    s = 0.0
    x, y = px, 3717506.2
    while y > Y0 and x > X0:
        v = hs_at(x, y)
        samples.append('%.0fkm:%s' % (s/1000, ('%.2f' % v) if v is not None else 'dry'))
        x += ux*5000; y += uy*5000; s += 5000
    print('%s (x=%.0f): %s' % (name, px, '  '.join(samples)))

print('\n== coarse field (every 10th cell, rows N->S, cols W->E; -=land/exc) ==')
hdr = '      ' + ' '.join('%5.0f' % ((X0+i*DX)/1000) for i in range(0, NX, 10))
print(hdr)
for j in range(NY-1, -1, -10):
    row = []
    for i in range(0, NX, 10):
        v = F[j,i]
        row.append('%5.2f' % v if v > -8.0 else '    -')
    print('%5.0f %s' % ((Y0+j*DY)/1000, ' '.join(row)))
