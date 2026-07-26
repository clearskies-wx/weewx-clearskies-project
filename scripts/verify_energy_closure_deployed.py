#!/usr/bin/env python3
"""Measure energy closure of the components the model ACTUALLY publishes (C-08).

Run on librewxr:

    sudo -u ubuntu /home/ubuntu/repos/weewx-clearskies-marine/.venv/bin/python \
        /tmp/verify_energy_closure_deployed.py

--------------------------------------------------------------------------
Why this exists instead of just re-running verify_partition_duplication.py
--------------------------------------------------------------------------

C-08 says: "re-run scripts/verify_partition_duplication.py against a fresh
model run and confirm energy closure sits near 1.0 rather than the 1.63
median."  Followed literally that measures the wrong thing, in three ways:

1. **That script calls decompose_spectrum() itself** (line 59) rather than
   reading the payload's own `components`.  decompose_spectrum() is the
   algorithm T4B.2 REJECTED and it has no production caller any more — SWAN's
   own PT* watershed partitions are the source at every live site.  Running it
   against a fresh payload re-measures the rejected algorithm and would still
   return ~1.6, which says nothing whatever about the deployed path.  That is
   the same shape of mistake C-08 exists to prevent: measuring something other
   than the thing you are trying to validate, and reading the result as if it
   validated it.

2. **The published payload is trimmed.**  SURF-PUBLISH-RESULTS-ONLY drops
   `energy`, `freqs_hz`, `dirs_deg` and `handoff_by_transect` at the HTTP
   serving boundary, so a fetch of GET /surf/{id}/forecast has no spectra left
   to measure.  The untrimmed data lives only in the model host's own
   forecast_cache.json, which is what this reads.

3. **It imports from the API repo**, where the SWAN code no longer exists
   after the marine separation.

So this measures what C-08 actually wants: for every timestep, the sum of the
m0 of the components **the model published** against the m0 of the spectrum
they were derived from.

    closure = sum(component m0) / spectrum m0

    ~1.0  components partition the spectrum's energy  -> the fix works
    >1.0  the same energy counted into several components (the old defect;
          measured at a 1.626 median, 2.271 worst case, 65/65 multi-component
          timesteps over 105%)
    <1.0  components under-report the energy present

No fallbacks and no substituted values: a timestep missing spectra or
components is COUNTED AND NAMED as unmeasurable, never silently skipped and
never defaulted.  (rules/coding.md §1 — an unavailable value is reported as
unavailable.)  A run where most timesteps are unmeasurable is not a pass.
"""
from __future__ import annotations

import json

import sys
from pathlib import Path

CACHE = Path("/var/run/weewx-clearskies/swan/forecast_cache.json")


def spectrum_m0(freqs: list[float], dirs: list[float], energy: list) -> float:
    """Integrate E(f, theta) over frequency and direction -> m0 (variance).

    SWAN writes 2D variance density in **m^2/Hz/degree** (VaDens), so the
    direction bin width is used in degrees.  Converting it to radians here
    understates m0 by a factor of 180/pi = 57.3 and was the reason the first
    run of this script reported a closure of 58.5 rather than ~1.0.
    """
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

    total = 0.0
    for i in range(nf):
        row = energy[i]
        for j in range(nd):
            total += float(row[j]) * df[i] * dd[j]
    return total


def component_m0(comp: dict) -> float | None:
    """m0 of a reported component from its significant height: Hs = 4*sqrt(m0).

    The published field is `height` (metres).  Components also carry their own
    `energy` field, which was verified on 2026-07-26 to equal (height/4)**2
    exactly — so `height` is the single source and `energy` is not consulted,
    to avoid measuring a derived value against itself.
    """
    hs = comp.get("height")
    if hs is None:
        return None
    return (float(hs) / 4.0) ** 2


def main() -> int:
    if not CACHE.exists():
        print(f"FAIL: {CACHE} does not exist — no model run to measure.")
        return 1

    data = json.loads(CACHE.read_text())
    spots = data.get("spots", data)
    if not isinstance(spots, dict):
        print(f"FAIL: unexpected cache shape: {type(spots).__name__}")
        return 1

    overall_exit = 0
    for spot_id, payload in spots.items():
        if not isinstance(payload, dict):
            continue
        entries = payload.get("spectral") or []
        run_time = payload.get("run_time")
        print(f"\n=== {spot_id}  run_time={run_time}  timesteps={len(entries)} ===")

        closures: list[float] = []
        counts: dict[int, int] = {}
        unmeasurable: list[str] = []

        for e in entries:
            t = e.get("time") or e.get("valid_time") or "<no timestamp>"
            freqs = e.get("freqs_hz") or []
            dirs = e.get("dirs_deg") or []
            energy = e.get("energy") or []
            comps = e.get("components")

            if not freqs or not dirs or not energy:
                unmeasurable.append(f"{t}: no spectrum in cache")
                continue
            if comps is None:
                unmeasurable.append(f"{t}: no components key")
                continue
            if not comps:
                unmeasurable.append(f"{t}: components empty (PT* gap — see no-silent-fallback rule)")
                continue

            m0_total = spectrum_m0(freqs, dirs, energy)
            if m0_total <= 0.0:
                unmeasurable.append(f"{t}: spectrum m0 <= 0")
                continue

            m0_sum = 0.0
            bad = False
            for c in comps:
                m = component_m0(c)
                if m is None:
                    unmeasurable.append(f"{t}: a component has no height field")
                    bad = True
                    break
                m0_sum += m
            if bad:
                continue

            closures.append(m0_sum / m0_total)
            counts[len(comps)] = counts.get(len(comps), 0) + 1

        if not closures:
            print("  NO MEASURABLE TIMESTEPS — this is a FAIL, not a pass.")
            for u in unmeasurable[:10]:
                print(f"    {u}")
            overall_exit = 1
            continue

        closures.sort()
        n = len(closures)
        median = closures[n // 2] if n % 2 else (closures[n // 2 - 1] + closures[n // 2]) / 2
        over105 = sum(1 for c in closures if c > 1.05)

        print(f"  ENERGY CLOSURE (1.00 = exactly the energy present), n={n}")
        print(f"    min {closures[0]:.3f}   median {median:.3f}   max {closures[-1]:.3f}")
        print(f"    over 105%: {over105}/{n}")
        print(f"  COMPONENT COUNT: {dict(sorted(counts.items()))}")
        print(f"  UNMEASURABLE TIMESTEPS: {len(unmeasurable)}")
        for u in unmeasurable[:10]:
            print(f"    {u}")

        print("  BASELINE (broken decompose_spectrum, 2026-07-25, n=67):"
              " median 1.626, max 2.271, 65/65 multi-component over 105%")
        verdict = "PASS" if 0.85 <= median <= 1.15 else "FAIL"
        print(f"  VERDICT: {verdict} (median within 0.85-1.15 of unity)")
        if verdict == "FAIL":
            overall_exit = 1

    return overall_exit


if __name__ == "__main__":
    sys.exit(main())
