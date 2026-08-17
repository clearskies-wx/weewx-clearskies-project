#!/usr/bin/env python3
"""March-loss research: S-corridor depth profile + island-shadow geometry.
READ-ONLY on model files; writes nothing outside stdout.
Grid: CGRID REG 283660.41 3604292.50 0. 145069.95 167074.31 142 169 (UTM 11N m)
BOTTOM: INPGRID 142x169 meshes -> 143x170 points, dx=1021.62 dy=988.61, IDLA=3
(file row 0 = SOUTH row, left->right = west->east), EXCEPTION -9999.
"""
import math
import numpy as np

BASE = '/var/lib/weewx-clearskies/swan/level1/'
X0, Y0 = 283660.41, 3604292.50
DX, DY = 1021.62, 988.61
NX, NY = 143, 170
G = 9.81
CB = 0.038  # FRICTION JON 0.038 m2 s-3

vals = np.loadtxt(BASE + 'BOTTOM.txt').ravel()
assert vals.size == NX * NY, vals.size
grid = vals.reshape(NY, NX)  # [j=south->north, i=west->east]

exc = grid <= -9998.0
neg = (grid < 0) & ~exc
wet = grid > 0
print('== BOTTOM.txt stats ==')
print('n=%d  exception(-9999)=%d  negative(non-exc)=%d  wet=%d' %
      (grid.size, exc.sum(), neg.sum(), wet.sum()))
print('wet depth min=%.1f max=%.1f  mean=%.1f' %
      (grid[wet].min(), grid[wet].max(), grid[wet].mean()))

def depth_at(x, y):
    """Nearest-point depth; None if outside grid."""
    i = (x - X0) / DX
    j = (y - Y0) / DY
    if i < -0.5 or j < -0.5 or i > NX - 0.5 or j > NY - 0.5:
        return None
    d = grid[int(round(j)), int(round(i))]
    return float(d)

def is_dry(d):
    return d is None or d <= 0.0

# Coarse dry-cell map to identify islands (every 4th cell), rows printed N->S
print('\n== dry-cell map (#=dry, .=wet, every 4th cell; top=N) ==')
for j in range(NY - 1, -1, -4):
    row = ''
    for i in range(0, NX, 4):
        d = grid[j, i]
        row += '#' if d <= 0 else '.'
    print('y=%7.0f %s' % (Y0 + j * DY, row))

# Dry-cell clusters -> island bounding boxes (simple flood fill)
from collections import deque
dry = grid <= 0
seen = np.zeros_like(dry, bool)
clusters = []
for j in range(NY):
    for i in range(NX):
        if dry[j, i] and not seen[j, i]:
            q = deque([(j, i)]); seen[j, i] = True; cells = []
            while q:
                a, b = q.popleft(); cells.append((a, b))
                for da, db in ((1,0),(-1,0),(0,1),(0,-1)):
                    na, nb = a+da, b+db
                    if 0 <= na < NY and 0 <= nb < NX and dry[na, nb] and not seen[na, nb]:
                        seen[na, nb] = True; q.append((na, nb))
            clusters.append(cells)
clusters.sort(key=len, reverse=True)
print('\n== dry clusters (islands/coast) ==')
for c in clusters[:6]:
    js = [a for a, b in c]; is_ = [b for a, b in c]
    print('cells=%5d  x[%7.0f..%7.0f]  y[%7.0f..%7.0f]' %
          (len(c), X0 + min(is_) * DX, X0 + max(is_) * DX,
           Y0 + min(js) * DY, Y0 + max(js) * DY))

# Seam points: nest S edge (NGRID inner 401202.50 3717506.20, 7633.66 x 8254.31)
NEST_X0, NEST_Y0, NEST_W = 401202.50, 3717506.20, 7633.66
seam_pts = [(NEST_X0 + f * NEST_W, NEST_Y0) for f in (0.0, 0.25, 0.5, 0.75, 1.0)]

STEP = 250.0
def trace(x0, y0, az_deg):
    """Back-trace along azimuth (toward source). Returns (status, dist, hit, profile)
    status: 'S' reached S boundary, 'W' reached W boundary, 'DRY' hit land,
    'E'/'N' left elsewhere. profile: list of (dist, depth) every step."""
    az = math.radians(az_deg)
    ux, uy = math.sin(az), math.cos(az)
    x, y, s = x0, y0, 0.0
    prof = []
    while True:
        x += ux * STEP; y += uy * STEP; s += STEP
        if y <= Y0:
            return 'S', s, (x, y), prof
        if x <= X0:
            return 'W', s, (x, y), prof
        d = depth_at(x, y)
        if d is None:
            return 'OUT', s, (x, y), prof
        if d <= 0.0:
            return 'DRY', s, (x, y), prof
        prof.append((s, d))

print('\n== island-shadow geometry: seam S-edge points, back-azimuths 185..220 ==')
print('point (x,y)      blocked azimuths (dry-hit) | 197-211 window blocked frac')
for (px, py) in seam_pts:
    blocked = []
    for az in range(185, 221):
        st, dist, hit, _ = trace(px, py, az)
        if st == 'DRY':
            blocked.append((az, dist, hit))
    w = [b for b in blocked if 197 <= b[0] <= 211]
    frac = len(w) / 15.0
    bl = ','.join('%d(%.0fkm@%.0f,%.0f)' % (a, d/1000, h[0], h[1]) for a, d, h in blocked) or 'none'
    print('(%.0f,%.0f)  %s | %.0f%%' % (px, py, bl, frac * 100))

# Depth profiles + friction transmission along central rays
print('\n== S-corridor depth profile + JONSWAP friction transmission ==')
PERIODS = [16.0, 14.0, 12.0, 10.0, 8.0, 6.0]

def wavenumber(T, d):
    om = 2 * math.pi / T
    k = om * om / G  # deep guess
    for _ in range(60):
        t = math.tanh(k * d)
        f = G * k * t - om * om
        df = G * t + G * k * d * (1 - t * t)
        k -= f / df
    return k

mid = seam_pts[2]
for az in (197, 204, 211):
    st, dist, hit, prof = trace(mid[0], mid[1], az)
    if st != 'S':
        print('az %d: status %s at %.1f km — no full corridor' % (az, st, dist/1000))
        continue
    depths = np.array([d for _, d in prof])
    L = dist / 1000
    print('\n-- az %d: seam->S-boundary %.1f km, %d samples --' % (az, L, len(depths)))
    print('depth min=%.0f max=%.0f mean=%.0f median=%.0f' %
          (depths.min(), depths.max(), depths.mean(), np.median(depths)))
    for thr in (30, 50, 75, 100, 150, 200, 300):
        f = (depths < thr).mean()
        print('  frac path d<%3dm: %5.1f%% (%.1f km)' % (thr, f*100, f*L))
    # depth every 10 km from seam
    marks = ['%.0f' % prof[int(k*1000/STEP)][1] for k in range(0, int(L), 10)
             if int(k*1000/STEP) < len(prof)]
    print('  depth @0,10,20,...km from seam: %s' % ' '.join(marks))
    # friction transmission boundary->seam per period
    out = []
    for T in PERIODS:
        om = 2 * math.pi / T
        integ = 0.0
        for _, d in prof:
            k = wavenumber(T, d)
            kd = k * d
            if kd > 25:
                continue
            sh = math.sinh(kd)
            cg = 0.5 * (1 + 2*kd/math.sinh(2*kd)) * om / k
            integ += (CB * om*om / (G*G * sh*sh)) / cg * STEP
        out.append('T=%.0fs: %.4f (-%.1f%%E)' % (T, math.exp(-integ), (1-math.exp(-integ))*100))
    print('  friction E-transmission: ' + '; '.join(out))

# Also: full-window blocked fraction using energy-weighting hint: report per-azimuth
print('\n== per-azimuth corridor status from mid seam point ==')
for az in range(190, 216):
    st, dist, hit, prof = trace(mid[0], mid[1], az)
    dmin = min((d for _, d in prof), default=float('nan'))
    print('az %3d: %-4s dist=%6.1f km  min-depth=%s' %
          (az, st, dist/1000, ('%.0f' % dmin) if prof else '-'))
