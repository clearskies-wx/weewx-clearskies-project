"""Does decompose_spectrum() produce independent swells, or duplicates?

Runs OUR function on real preserved spectra and measures two things that
settle it without needing a real swell and without touching the PT* parser:

  1. Energy closure: sum(component m0) / total spectrum m0.
     >1 means the same energy is being counted into several components.
  2. Pairwise separation: how far apart the reported components actually are
     in direction and period. Near-identical pairs are duplicates, not swells.
"""
import json
import sys

sys.path.insert(0, "/home/ubuntu/repos/weewx-clearskies-api")
from weewx_clearskies_api.services.swan_spectral import decompose_spectrum

d = json.load(open("/tmp/pub.json"))
entries = d["spectral"]

print(f"timesteps available: {len(entries)}")
print()

rows = []
for e in entries:
    freqs = e.get("freqs_hz") or []
    dirs = e.get("dirs_deg") or []
    energy = e.get("energy") or []
    if not freqs or not dirs or not energy:
        continue

    nf, nd = len(freqs), len(dirs)
    df = [0.0] * nf
    for i in range(nf):
        if i == 0:
            df[i] = freqs[1] - freqs[0]
        elif i == nf - 1:
            df[i] = freqs[-1] - freqs[-2]
        else:
            df[i] = (freqs[i + 1] - freqs[i - 1]) / 2.0
    dd = [0.0] * nd
    for j in range(nd):
        if j == 0:
            dd[j] = abs(dirs[1] - dirs[0])
        elif j == nd - 1:
            dd[j] = abs(dirs[-1] - dirs[-2])
        else:
            dd[j] = abs(dirs[j + 1] - dirs[j - 1]) / 2.0

    total_m0 = sum(
        energy[i][j] * df[i] * dd[j]
        for i in range(nf)
        for j in range(nd)
        if energy[i][j] > 0
    )
    if total_m0 <= 0:
        continue
    hs_total = 4.0 * (total_m0 ** 0.5)

    comps = decompose_spectrum(freqs, dirs, energy)
    if not comps:
        continue

    sum_m0 = sum((c["height"] / 4.0) ** 2 for c in comps)
    closure = sum_m0 / total_m0

    # closest pair, in direction and in period
    min_sep = None
    min_pair = None
    for a in range(len(comps)):
        for b in range(a + 1, len(comps)):
            da = abs(comps[a]["direction"] - comps[b]["direction"]) % 360.0
            da = min(da, 360.0 - da)
            if min_sep is None or da < min_sep:
                min_sep = da
                min_pair = (comps[a], comps[b])

    rows.append(
        {
            "time": e.get("time"),
            "hs_total": hs_total,
            "n": len(comps),
            "closure": closure,
            "min_sep": min_sep,
            "min_pair": min_pair,
            "comps": comps,
        }
    )

print(f"timesteps with a usable spectrum and >=1 component: {len(rows)}")
print()

# --- headline: energy closure ---
cl = sorted(r["closure"] for r in rows)
multi = [r for r in rows if r["n"] > 1]
print("ENERGY CLOSURE  sum(component m0) / total m0")
print("  1.00 = perfect. >1.00 = the same energy counted more than once.")
print(f"  all timesteps (n={len(cl)}):   min {cl[0]:.3f}   median {cl[len(cl)//2]:.3f}   max {cl[-1]:.3f}")
if multi:
    cm = sorted(r["closure"] for r in multi)
    print(f"  multi-component only (n={len(cm)}): min {cm[0]:.3f}   median {cm[len(cm)//2]:.3f}   max {cm[-1]:.3f}")
    over = sum(1 for r in multi if r["closure"] > 1.05)
    print(f"  multi-component timesteps exceeding 105% of available energy: {over}/{len(multi)}")
print()

# --- component counts ---
from collections import Counter
print("COMPONENT COUNT distribution:", dict(sorted(Counter(r["n"] for r in rows).items())))
print()

# --- duplicate check ---
if multi:
    seps = sorted(r["min_sep"] for r in multi)
    print("CLOSEST-PAIR DIRECTION SEPARATION, multi-component timesteps")
    print(f"  min {seps[0]:.1f}deg   median {seps[len(seps)//2]:.1f}deg   max {seps[-1]:.1f}deg")
    within80 = sum(1 for s in seps if s < 80.0)
    print(f"  pairs closer than the 80deg integration window: {within80}/{len(seps)}")
    print()

# --- worst offender, shown in full ---
if multi:
    worst = max(multi, key=lambda r: r["closure"])
    print("WORST ENERGY CLOSURE — full component list")
    print(f"  time={worst['time']}  spectrum Hs={worst['hs_total']:.4f} m  closure={worst['closure']:.3f}")
    for c in worst["comps"]:
        print(
            f"    hs={c['height']:.4f} m  tp={c['period']:.1f} s  dir={c['direction']:.1f} deg  [{c['classification']}]"
        )
    print()

# --- richest timestep ---
richest = max(rows, key=lambda r: r["n"])
print("MOST COMPONENTS FOUND — full component list")
print(f"  time={richest['time']}  spectrum Hs={richest['hs_total']:.4f} m  n={richest['n']}  closure={richest['closure']:.3f}")
for c in richest["comps"]:
    print(
        f"    hs={c['height']:.4f} m  tp={c['period']:.1f} s  dir={c['direction']:.1f} deg  [{c['classification']}]"
    )
