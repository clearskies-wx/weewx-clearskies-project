import sys, math

BANDS = [(0.0, 0.09), (0.09, 0.2), (0.2, 99.0)]

def parse_header(fh):
    """Read SWAN 2D spectral file header. Returns (locs, freqs, dirs)."""
    line = fh.readline()
    assert line.startswith('SWAN'), line
    # skip comments
    line = fh.readline()
    while line.startswith('$'):
        line = fh.readline()
    assert line.startswith('TIME'), line
    fh.readline()  # time coding option
    line = fh.readline()
    assert line.startswith('LOCATIONS') or line.startswith('LONLAT'), line
    nloc = int(fh.readline().split()[0])
    locs = []
    for _ in range(nloc):
        p = fh.readline().split()
        locs.append((float(p[0]), float(p[1])))
    line = fh.readline()
    assert line.startswith('AFREQ') or line.startswith('RFREQ'), line
    nf = int(fh.readline().split()[0])
    freqs = [float(fh.readline().split()[0]) for _ in range(nf)]
    line = fh.readline()
    assert line.startswith('NDIR') or line.startswith('CDIR'), line
    nd = int(fh.readline().split()[0])
    dirs = [float(fh.readline().split()[0]) for _ in range(nd)]
    line = fh.readline()
    assert line.startswith('QUANT'), line
    fh.readline()          # number of quantities (1)
    fh.readline()          # VaDens
    fh.readline()          # unit
    fh.readline()          # exception value
    return locs, freqs, dirs

def freq_widths(freqs):
    """Per-bin df for a logarithmic grid: geometric bin edges."""
    r = (freqs[-1] / freqs[0]) ** (1.0 / (len(freqs) - 1))
    sr = math.sqrt(r)
    return [f * (sr - 1.0 / sr) for f in freqs]

def read_block(fh, nf, nd):
    """Read one location block at one time. Returns list of nf rows x nd floats, or None."""
    line = fh.readline()
    if not line:
        return 'EOF'
    key = line.split()[0]
    if key == 'ZERO':
        return None
    if key == 'NODATA':
        return 'NODATA'
    assert key == 'FACTOR', line
    factor = float(fh.readline().split()[0])
    need = nf * nd
    vals = []
    while len(vals) < need:
        vals.extend(fh.readline().split())
    assert len(vals) == need, (len(vals), need)
    return [[float(v) * factor for v in vals[i*nd:(i+1)*nd]] for i in range(nf)]

def integrate(rows, freqs, dfs, dtheta):
    """Return (m0_total, m0_per_band). rows[i] = densities m2/Hz/deg over dirs."""
    m0 = 0.0
    mb = [0.0] * len(BANDS)
    for i, f in enumerate(freqs):
        s = sum(v for v in rows[i] if v > 0.0) * dtheta * dfs[i]
        m0 += s
        for bi, (lo, hi) in enumerate(BANDS):
            if lo <= f < hi:
                mb[bi] += s
                break
    return m0, mb

def hs(m0):
    return 4.0 * math.sqrt(m0) if m0 > 0 else 0.0

def scan_file(path, want_times, want_locs=None):
    """want_times: set of time indices. want_locs: set of loc indices or None=all.
    Returns dict (t_idx, loc_idx) -> (date, m0, mb), plus locs list."""
    out = {}
    with open(path) as fh:
        locs, freqs, dirs = parse_header(fh)
        dfs = freq_widths(freqs)
        dtheta = 360.0 / len(dirs)
        nf, nd = len(freqs), len(dirs)
        tmax = max(want_times)
        t = -1
        while True:
            line = fh.readline()
            if not line:
                break
            date = line.split()[0]
            t += 1
            for li in range(len(locs)):
                blk = read_block(fh, nf, nd)
                if blk == 'EOF':
                    break
                if t in want_times and (want_locs is None or li in want_locs):
                    if blk is None:
                        out[(t, li)] = (date, 0.0, [0.0]*len(BANDS))
                    elif blk == 'NODATA':
                        out[(t, li)] = (date, None, None)
                    else:
                        m0, mb = integrate(blk, freqs, dfs, dtheta)
                        out[(t, li)] = (date, m0, mb)
            if t >= tmax:
                break
    return out, locs

if __name__ == '__main__':
    mode = sys.argv[1]
    base = '/var/lib/weewx-clearskies/swan/level1/'
    if mode == 'boundary':
        side = sys.argv[2]  # S or W
        times = {0, 5, 6, 7}
        print('cell  x  y  ' + '  '.join('Hs@t%d' % t for t in sorted(times)))
        for c in range(11):
            path = base + 'B_%s_%04d.txt' % (side, c)
            out, locs = scan_file(path, times)
            row = ['B_%s_%04d' % (side, c), '%.0f' % locs[0][0], '%.0f' % locs[0][1]]
            for t in sorted(times):
                d, m0, mb = out[(t, 0)]
                row.append('%.3f' % hs(m0) if m0 is not None else 'NODATA')
            print('  '.join(row))
    elif mode == 'nest':
        times = {5, 6, 7}
        loc_idx = [int(x) for x in sys.argv[2].split(',')]
        out, locs = scan_file(base + 'nest_out_20260814.000000.dat', times, set(loc_idx))
        print('loc  x  y  time  Hs_tot  Hs_lt0.09  Hs_0.09-0.2  Hs_gt0.2')
        for li in loc_idx:
            for t in sorted(times):
                d, m0, mb = out[(t, li)]
                if m0 is None:
                    print('%d  %.1f  %.1f  %s  NODATA' % (li, locs[li][0], locs[li][1], d))
                else:
                    print('%d  %.1f  %.1f  %s  %.3f  %.3f  %.3f  %.3f' %
                          (li, locs[li][0], locs[li][1], d, hs(m0), hs(mb[0]), hs(mb[1]), hs(mb[2])))
    elif mode == 'locs':
        # just print the perimeter point list with indices
        with open(base + 'nest_out_20260814.000000.dat') as fh:
            locs, freqs, dirs = parse_header(fh)
        xs = [l[0] for l in locs]; ys = [l[1] for l in locs]
        print('nloc=%d  xmin=%.1f xmax=%.1f ymin=%.1f ymax=%.1f' %
              (len(locs), min(xs), max(xs), min(ys), max(ys)))
        for i, (x, y) in enumerate(locs):
            edge = []
            if abs(y - min(ys)) < 1: edge.append('S')
            if abs(y - max(ys)) < 1: edge.append('N')
            if abs(x - min(xs)) < 1: edge.append('W')
            if abs(x - max(xs)) < 1: edge.append('E')
            print('%3d  %.1f  %.1f  %s' % (i, x, y, '/'.join(edge)))
