#!/usr/bin/env python3
'''Seam band ledger + buoy-point analysis for one experiment dir (e1|e2).
Reuses /tmp/e1e2/ledger.py (log-df integrator, ratio-based freq_widths).'''
import sys, math, glob
sys.path.insert(0, '/tmp/e1e2')
from ledger import parse_header, read_block, freq_widths, hs, scan_file

d = sys.argv[1]
base = '/tmp/e1e2/%s/' % d
BUOYS = ['46253/CDIP213', 'CDIP092/46222', '46256/CDIP215', 'seam-mid']

def band_stats(rows, freqs, dirs, dfs, dtheta, flo, fhi):
    m0 = 0.0; sx = 0.0; cy = 0.0
    for i, f in enumerate(freqs):
        if not (flo <= f < fhi): continue
        for j, dd in enumerate(dirs):
            v = rows[i][j]
            if v > 0:
                e = v * dfs[i] * dtheta
                m0 += e
                r = math.radians(dd)
                sx += e * math.sin(r); cy += e * math.cos(r)
    mdir = (math.degrees(math.atan2(sx, cy)) % 360) if m0 > 0 else None
    return m0, mdir

# --- seam ledger: same 7 S-edge points ---
nf_path = sorted(glob.glob(base + 'nest_out*'))[0]
with open(nf_path) as fh:
    locs, freqs, dirs = parse_header(fh)
ys = [l[1] for l in locs]; ymin = min(ys)
sidx = sorted([i for i,l in enumerate(locs) if abs(l[1]-ymin) < 1.0], key=lambda i: locs[i][0])
pick = [sidx[int(round(k*(len(sidx)-1)/6.0))] for k in range(7)]
out, locs = scan_file(nf_path, {5,6,7}, set(pick))
print('== %s seam (7 S-edge pts) ==' % d)
print('loc x t Hs_tot Hs_gt11s Hs_5-11s Hs_lt5s')
for t in (5,6,7):
    for i in pick:
        dt, m0, mb = out[(t,i)]
        print('%3d %.0f %s %.3f %.3f %.3f %.3f' % (i, locs[i][0], dt, hs(m0), hs(mb[0]), hs(mb[1]), hs(mb[2])))
    m0m = sum(out[(t,i)][1] for i in pick)/7
    mbm = [sum(out[(t,i)][2][b] for i in pick)/7 for b in range(3)]
    print('t=%d AGG(mean-E): tot=%.3f >11s=%.3f 5-11s=%.3f <5s=%.3f' % (t, hs(m0m), hs(mbm[0]), hs(mbm[1]), hs(mbm[2])))

# --- buoy points: full spectra, Hs + mean dir per band ---
print('\n== %s buoy points ==' % d)
bp = base + 'buoy_spec.dat'
with open(bp) as fh:
    locs, freqs, dirs = parse_header(fh)
    dfs = freq_widths(freqs); dtheta = 360.0/len(dirs)
    nf, nd = len(freqs), len(dirs)
    print('locs:', [(round(x,0), round(y,0)) for x,y in locs])
    print('name t Hs_tot mdir_tot | Hs_gt11s mdir | Hs_5-11s mdir | Hs_lt5s')
    t = -1
    while True:
        line = fh.readline()
        if not line: break
        date = line.split()[0]
        t += 1
        for li in range(len(locs)):
            blk = read_block(fh, nf, nd)
            if blk == 'EOF': break
            if t in (5,6,7):
                if blk is None or blk == 'NODATA':
                    print('%s t=%d %s ZERO/NODATA' % (BUOYS[li], t, date)); continue
                m0t, mdt = band_stats(blk, freqs, dirs, dfs, dtheta, 0.0, 99.0)
                m0a, mda = band_stats(blk, freqs, dirs, dfs, dtheta, 0.0, 0.09)
                m0b, mdb = band_stats(blk, freqs, dirs, dfs, dtheta, 0.09, 0.2)
                m0c, _ = band_stats(blk, freqs, dirs, dfs, dtheta, 0.2, 99.0)
                fm = lambda v: '%.0f' % v if v is not None else '-'
                print('%s t=%d %s Hs=%.3f dir=%s | %.3f %s | %.3f %s | %.3f' %
                      (BUOYS[li], t, date, hs(m0t), fm(mdt), hs(m0a), fm(mda), hs(m0b), fm(mdb), hs(m0c)))
        if t >= 7: break
