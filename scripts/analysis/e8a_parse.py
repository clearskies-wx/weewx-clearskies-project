#!/usr/bin/env python3
import re
from collections import defaultdict
for d in ['e1','e2','e3','e7']:
    path = '/tmp/e1e2/%s/PRINT' % d
    rows = []
    inblk = False
    nblocks = 0
    for line in open(path):
        if 'Differences in wave height' in line:
            inblk = True; nblocks += 1; continue
        if not inblk: continue
        if re.match(r'\s*(Relative|Hs\[|ix\s+iy|-{5,})', line.strip()) or line.strip().startswith('-'):
            continue
        m = re.match(r'\s*(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.-]+)\s*$', line)
        if m:
            rows.append((int(m.group(1)), int(m.group(2)), float(m.group(4)), float(m.group(5))))
        else:
            inblk = False
    agg = defaultdict(lambda: [0,0.0,0.0])
    for ix,iy,inp,comp in rows:
        agg[(ix,iy)][0]+=1; agg[(ix,iy)][1]+=inp; agg[(ix,iy)][2]+=comp
    s_rows = sorted([k for k in agg if k[1]==1], key=lambda k:k[0])
    w_rows = sorted([k for k in agg if k[0]==1 and k[1]!=1], key=lambda k:k[1])
    other  = sorted([k for k in agg if k[0]!=1 and k[1]!=1])
    print('== %s: %d blocks, %d rows, %d distinct pts ==' % (d, nblocks, len(rows), len(agg)))
    for name, ks in (('S-side ix-run (iy=1)', s_rows), ('W-side iy-run (ix=1)', w_rows), ('interior/other', other)):
        if not ks: print(' %s: none' % name); continue
        print(' %s: %d pts' % (name, len(ks)))
        for k in ks:
            n,si,sc = agg[k]
            print('   ix=%3d iy=%3d n=%4d  input=%.3f  computed=%.3f  ratio=%.2f' % (k[0],k[1],n,si/n,sc/n,sc/si if si>0 else -1))
    print()
