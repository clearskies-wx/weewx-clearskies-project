import sys
sys.path.insert(0, '/tmp/energy-ledger')
from ledger import scan_file, hs
base = '/var/lib/weewx-clearskies/swan/level1/'
times = {1, 2, 3}
print('cell  time  Hs_tot  Hs_lt0.09  Hs_0.09-0.2  Hs_gt0.2')
for c in range(11):
    out, locs = scan_file(base + 'B_W_%04d.txt' % c, times)
    for t in sorted(times):
        d, m0, mb = out[(t, 0)]
        print('B_W_%04d  %s  %.3f  %.3f  %.3f  %.3f' % (c, d, hs(m0), hs(mb[0]), hs(mb[1]), hs(mb[2])))
