#!/usr/bin/env python3
"""Directional analysis: boundary band spectra vs island-shadow occlusion.
Predict seam >11s transmission from actual B_S directional distribution +
ray-traced blocked azimuth sets. Also W-corridor directions and spin-up check.
READ-ONLY. Reuses /tmp/energy-ledger/ledger.py parser.
"""
import math, sys
import numpy as np
sys.path.insert(0, '/tmp/energy-ledger')
from ledger import scan_file, freq_widths, hs

BASE = '/var/lib/weewx-clearskies/swan/level1/'
X0, Y0 = 283660.41, 3604292.50
DX, DY = 1021.62, 988.61
NX, NY = 143, 170

vals = np.loadtxt(BASE + 'BOTTOM.txt').ravel()
grid = vals.reshape(NY, NX)

def depth_at(x, y):
    i = (x - X0) / DX; j = (y - Y0) / DY
    if i < -0.5 or j < -0.5 or i > NX - 0.5 or j > NY - 0.5:
        return None
    return float(grid[int(round(j)), int(round(i))])

STEP = 250.0
def trace_status(x0, y0, az_deg):
    az = math.radians(az_deg)
    ux, uy = math.sin(az), math.cos(az)
    x, y = x0, y0
    while True:
        x += ux * STEP; y += uy * STEP
        if y <= Y0: return 'S'
        if x <= X0: return 'W'
        d = depth_at(x, y)
        if d is None: return 'OUT'
        if d <= 0.0: return 'DRY'

# --- full spectral read at one time for one file ---
def read_spec(path, t_idx):
    out, locs = scan_file_full(path, t_idx)
    return out, locs

def scan_file_full(path, t_want):
    """Return (freqs, dirs, rows) for loc 0 at time index t_want."""
    from ledger import parse_header, read_block
    with open(path) as fh:
        locs, freqs, dirs = parse_header(fh)
        nf, nd = len(freqs), len(dirs)
        t = -1
        while True:
            line = fh.readline()
            if not line: return None
            t += 1
            blocks = []
            for li in range(len(locs)):
                blk = read_block(fh, nf, nd)
                blocks.append(blk)
            if t == t_want:
                return freqs, dirs, blocks, locs

def band_dir_stats(freqs, dirs, rows, flo, fhi):
    """Energy-weighted mean direction, spread, m0 for band; plus energy per dir bin."""
    dfs = freq_widths(freqs)
    dtheta = 360.0 / len(dirs)
    edir = np.zeros(len(dirs))
    for i, f in enumerate(freqs):
        if flo <= f < fhi:
            for j in range(len(dirs)):
                v = rows[i][j]
                if v > 0: edir[j] += v * dfs[i] * dtheta
    m0 = edir.sum()
    if m0 <= 0: return 0.0, None, None, edir
    rad = np.radians(dirs)
    sx = (edir * np.sin(rad)).sum() / m0
    cy = (edir * np.cos(rad)).sum() / m0
    mdir = math.degrees(math.atan2(sx, cy)) % 360
    r = math.hypot(sx, cy)
    spread = math.degrees(math.sqrt(2 * (1 - r)))
    return m0, mdir, spread, edir

SEAM_PTS = [(401202.50 + f * 7633.66, 3717506.20) for f in (0.0, 0.25, 0.5, 0.75, 1.0)]

# Blocked sets per seam point over 150..290
print('== computing blocked azimuth sets (150-290) per seam point ==')
blocked_sets = []
for (px, py) in SEAM_PTS:
    s = {}
    for az in range(150, 291):
        s[az] = trace_status(px, py, az)
    blocked_sets.append(s)
    dryaz = [a for a, st in s.items() if st == 'DRY']
    print('(%.0f,%.0f): DRY az: %s' % (px, py,
          ','.join(str(a) for a in dryaz) if dryaz else 'none'))

# Boundary S cells 3..9 at t=6: >11s band stats
print('\n== S-boundary cells t=6 (06Z): >11s (f<0.09) band ==')
print('cell x Hs_band mdir spread')
bnd = {}
for c in range(3, 10):
    path = BASE + 'B_S_%04d.txt' % c
    freqs, dirs, blocks, locs = scan_file_full(path, 6)
    rows = blocks[0]
    if rows is None or rows == 'NODATA':
        print('B_S_%04d NODATA/ZERO' % c); continue
    m0, mdir, spread, edir = band_dir_stats(freqs, dirs, rows, 0.0, 0.09)
    bnd[c] = (dirs, edir)
    print('B_S_%04d x=%.0f Hs=%.3f mdir=%.0f spread=%.0f' %
          (c, locs[0][0], hs(m0), mdir or -1, spread or -1))
    # directional histogram (energy fraction per 10 deg, 170-240)
    dt = 360.0 / len(dirs)
    hist = {}
    for j, d in enumerate(dirs):
        b = int(d // 10) * 10
        hist[b] = hist.get(b, 0.0) + edir[j]
    tot = sum(hist.values())
    tops = sorted(hist.items(), key=lambda kv: -kv[1])[:8]
    print('   top 10-deg sectors: ' + ', '.join('%d-%d:%.0f%%' % (b, b+10, v/tot*100)
          for b, v in sorted(tops)))

# Predicted geometric shadow transmission for each seam point,
# using B_S_0005 and B_S_0007 >11s directional distributions
print('\n== predicted shadow transmission (straight-ray, no refill) >11s ==')
for cell in (4, 5, 6, 7, 8):
    if cell not in bnd: continue
    dirs, edir = bnd[cell]
    tot = edir.sum()
    if tot <= 0: continue
    line = []
    for pi, (px, py) in enumerate(SEAM_PTS):
        s = blocked_sets[pi]
        passed = 0.0
        for j, d in enumerate(dirs):
            azi = int(round(d)) if 150 <= d <= 290 else None
            if azi is None:
                continue  # energy outside window can't reach seam from S/W anyway
            st = s.get(azi, 'OUT')
            if st in ('S', 'W'):
                passed += edir[j]
        line.append('%.0f%%' % (100 * (1 - passed / tot)))
    print('using B_S_%04d dist: predicted blocked E loss at seam pts W->E: %s'
          % (cell, '  '.join(line)))

# W-boundary cells: 5-11s band directions at t=6
print('\n== W-boundary cells t=6: 5-11s (0.09-0.2) band ==')
for c in range(3, 10):
    path = BASE + 'B_W_%04d.txt' % c
    r = scan_file_full(path, 6)
    if r is None: continue
    freqs, dirs, blocks, locs = r
    rows = blocks[0]
    if rows is None or rows == 'NODATA':
        print('B_W_%04d NODATA/ZERO' % c); continue
    m0, mdir, spread, edir = band_dir_stats(freqs, dirs, rows, 0.09, 0.2)
    m0s, mdirs, spreads, _ = band_dir_stats(freqs, dirs, rows, 0.0, 0.09)
    print('B_W_%04d y=%.0f 5-11s Hs=%.3f mdir=%s spread=%s | >11s Hs=%.3f mdir=%s' %
          (c, locs[0][1], hs(m0), '%.0f' % mdir if mdir else '-',
           '%.0f' % spread if spread else '-', hs(m0s), '%.0f' % mdirs if mdirs else '-'))

# Seam (nest S edge) points from actual nest_out: spin-up + band dirs t=5,6,7
import glob
nest_files = sorted(glob.glob(BASE + 'nest_out*'))
print('\n== nest_out files: %s ==' % [f.split('/')[-1] for f in nest_files])
if nest_files:
    nf_path = nest_files[-1]
    from ledger import parse_header
    with open(nf_path) as fh:
        locs, freqs, dirs = parse_header(fh)
    ys = [l[1] for l in locs]; ymin = min(ys)
    sidx = [i for i, l in enumerate(locs) if abs(l[1] - ymin) < 1.0]
    print('S-edge loc indices: %s' % sidx)
    from ledger import read_block
    dfs = freq_widths(freqs)
    dtheta = 360.0 / len(dirs)
    nfq, nd = len(freqs), len(dirs)
    with open(nf_path) as fh:
        locs, freqs, dirs = parse_header(fh)
        t = -1
        while True:
            line = fh.readline()
            if not line: break
            date = line.split()[0]
            t += 1
            for li in range(len(locs)):
                blk = read_block(fh, nfq, nd)
                if blk == 'EOF': break
                if t in (3, 4, 5, 6, 7, 8) and li in (sidx[0], sidx[len(sidx)//2], sidx[-1]):
                    if blk is None or blk == 'NODATA':
                        print('t=%d loc=%d %s: ZERO/NODATA' % (t, li, date)); continue
                    m0, mdir, spread, _ = band_dir_stats(freqs, dirs, blk, 0.0, 0.09)
                    m1, mdir1, _, _ = band_dir_stats(freqs, dirs, blk, 0.09, 0.2)
                    print('t=%d loc=%d (%.0f,%.0f) %s: >11s Hs=%.3f mdir=%s | 5-11s Hs=%.3f mdir=%s' %
                          (t, li, locs[li][0], locs[li][1], date, hs(m0),
                           '%.0f' % mdir if mdir else '-', hs(m1),
                           '%.0f' % mdir1 if mdir1 else '-'))
            if t >= 8: break
