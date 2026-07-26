#!/usr/bin/env python3
"""Research only: what does NOAA gfswave ACTUALLY give us for Huntington?

Downloads a small NOMADS GRIB filter subset of the operational gfswave
global 0p16 wave product and prints every wave field at the point nearest
the SWAN L1 boundary, including the THREE swell partitions.

Writes nothing outside /tmp, installs nothing, touches no service.
"""
import subprocess
import sys

import eccodes

LAT, LON = 33.5, -118.5          # SWAN L1 boundary point offshore Huntington
CYCLE = sys.argv[1] if len(sys.argv) > 1 else "06"
DAY = sys.argv[2] if len(sys.argv) > 2 else "20260726"
FHOURS = ["f000", "f003", "f006"]

BASE = "https://nomads.ncep.noaa.gov/cgi-bin/filter_gfswave.pl"

WANT = ["SWELL", "SWPER", "SWDIR", "WVHGT", "WVPER", "WVDIR",
        "HTSGW", "PERPW", "DIRPW", "WIND", "WDIR"]


def fetch(fh: str) -> str | None:
    q = [f"file=gfswave.t{CYCLE}z.global.0p16.{fh}.grib2"]
    for v in WANT:
        q.append(f"var_{v}=on")
    # all sequence levels (swell partitions 1..3) plus surface
    q.append("all_lev=on")
    q.append("subregion=")
    q.append("leftlon=-120")
    q.append("rightlon=-117")
    q.append("toplat=35")
    q.append("bottomlat=32")
    q.append(f"dir=%2Fgfs.{DAY}%2F{CYCLE}%2Fwave%2Fgridded")
    url = BASE + "?" + "&".join(q)
    out = f"/tmp/gfswave_{CYCLE}_{fh}.grib2"
    r = subprocess.run(["curl", "-s", "--max-time", "90", "-o", out, url],
                       capture_output=True)
    if r.returncode != 0:
        print(f"  {fh}: curl failed rc={r.returncode}")
        return None
    import os
    sz = os.path.getsize(out) if os.path.exists(out) else 0
    if sz < 500:
        head = open(out, "rb").read()[:200]
        print(f"  {fh}: subset too small ({sz} B) -> {head!r}")
        return None
    print(f"  {fh}: {sz} bytes")
    return out


def dump(path: str, fh: str) -> None:
    print(f"\n--- {DAY} {CYCLE}z {fh} at nearest point to ({LAT}, {LON}) ---")
    rows = []
    with open(path, "rb") as f:
        while True:
            gid = eccodes.codes_grib_new_from_file(f)
            if gid is None:
                break
            try:
                name = eccodes.codes_get(gid, "shortName")
                try:
                    lev = eccodes.codes_get(gid, "level")
                except Exception:
                    lev = ""
                near = eccodes.codes_grib_find_nearest(gid, LAT, LON)[0]
                rows.append((name, lev, near.value, near.lat, near.lon))
            finally:
                eccodes.codes_release(gid)
    if not rows:
        print("  no GRIB messages decoded")
        return
    for name, lev, val, la, lo in rows:
        v = "null" if val is None else f"{val:10.3f}"
        print(f"  {name:<8} lev={lev:<3} {v}   @({la:.2f},{lo:.2f})")


print(f"gfswave {DAY} {CYCLE}z — downloading subsets")
for fh in FHOURS:
    p = fetch(fh)
    if p:
        dump(p, fh)
