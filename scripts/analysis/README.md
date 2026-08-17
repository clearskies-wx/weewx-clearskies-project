# scripts/analysis — energy-ledger scripts (provenance)

These 9 `.py` files are the Fixit-round energy-ledger scripts used during the E1/E2
(and later E3/E7/E8) marine-model experiment rounds (`scratch/BRIEF-ENERGY-LEDGER.md`,
`scratch/BRIEF-E1-E2-EXPERIMENTS.md`, `scratch/NOTES-E1E2-RESULTS.md`). They read SWAN
2D spectral ASCII files (boundary spectra, NESTOUT files) and integrate `Hs` totals and
per-band splits.

- **Original location:** `/tmp/e1e2` on `librewxr` (investigation scratch, per
  `scratch/BRIEF-ENERGY-LEDGER.md`'s scratch-confinement rule).
- **Mirrored to `scratch/energy-ledger-scripts/`:** 2026-08-15 (Marine Model Evolution
  Plan carry-over row C12).
- **Committed here:** DOC-W.4, 2026-08-17. Copied verbatim — no logic changes. Do not
  modify the computation in these files without a separate, explicitly-scoped task;
  changing an integration rule or a band edge is a physics/formula change (architectural
  block, `rules/agents.md`).

## Band edges (NAMED CONSTANTS)

`ledger.py`'s `BANDS = [(0.0, 0.09), (0.09, 0.2), (0.2, 99.0)]` — these are the plan's
NAMED CONSTANTS band edges in Hz: `< 0.09 Hz` (period > 11 s, groundswell), `0.09–0.2 Hz`
(5–11 s), `> 0.2 Hz` (< 5 s, wind sea). See
`docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md` `## NAMED CONSTANTS`.

## Log-spaced integration (mandatory)

The spectral frequency grid is logarithmic (constant `f[i+1]/f[i]` ratio, not a uniform
step). `ledger.py`'s `freq_widths()` computes the real per-bin `df` from the geometric
bin-edge relationship. **Uniform-`df` integration under-reads total energy by
approximately 5x** — this is the recorded trap from a previous session's parser bug
(`scratch/BRIEF-ENERGY-LEDGER.md` line 19: "A previous session's parser got this wrong
and under-read by 5x"). Any future modification to these scripts must preserve
log-spaced integration.

## Self-test

`selftest.py` runs a known-answer check against a small synthetic fixture in
`fixtures/` and exits 0 on match, 1 on mismatch. See that file's header comment for the
fixture's construction and its citation to the pinned recorded value.

```
python scripts/analysis/selftest.py
```
