---
status: Archived — consolidated into PROVIDER-MANUAL.md, API-MANUAL.md
date: 2026-07-09
archived: 2026-07-09
deciders: shane
---

# ADR-087: NDBC spectral wave data consumption

## Context

NDBC buoys report two levels of wave data:

1. **Standard meteorological** (`.txt`): Significant wave height (Hs), dominant period (DPD), average period (APD), mean wave direction (MWD). One composite number per parameter — the statistical summary of the entire wave field.
2. **Spectral** (`.swden` + `.swdir`): Full wave energy spectrum across 46 frequency bands (0.02–0.485 Hz), with direction at each frequency. This reveals the underlying structure of the wave field.

Standard met Hs alone cannot distinguish a clean 15-second groundswell (excellent surf) from a messy mix of 8-second wind chop (poor surf despite the same height number). The two produce identical Hs but completely different ocean conditions. Spectral data is how experienced surfers, marine forecasters, and the NWS distinguish these cases.

The pre-Clear-Skies Phase I extension consumed only standard met data. Adding spectral data is a significant capability upgrade.

Not all NDBC buoys have wave sensors — some are atmospheric-only (C-MAN stations). Among those with wave sensors, spectral data availability varies. The provider must handle stations with and without spectral capability.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Standard met only (Hs, Tp, direction) | Simplest. Works for all stations with wave sensors. | Cannot distinguish swell systems. Surf quality scoring limited to composite values. NWS forecasters consider this insufficient for surf assessment. |
| Spectral data when available, standard met fallback | Best quality where available, graceful degradation elsewhere. | More complex parsing. Spectral decomposition algorithm needed. |
| Require spectral data for surf spots | Highest quality for surf. | Excludes stations without spectral sensors. Operator may not have a nearby spectral-capable buoy. |

## Decision

Parse NDBC spectral wave density (`.swden`) and spectral wave direction (`.swdir`) files in addition to standard meteorological (`.txt`). When spectral data is available, decompose the spectrum into individual swell systems. When unavailable, fall back to standard met composite values.

### Spectral decomposition

The `.swden` file contains energy density (m²/Hz) at 46 frequency bands. The `.swdir` file contains mean direction (degrees) at each band. Decomposition into swell systems:

1. **Find spectral peaks:** Identify local maxima in the energy density spectrum (energy at frequency f is greater than both neighbors).
2. **Partition energy:** Assign each frequency band to the nearest peak. A partition boundary is the frequency with minimum energy between two adjacent peaks.
3. **Compute per-system parameters:**
   - Significant wave height: Hs = 4√m₀, where m₀ = ∫S(f)df over the partition's frequency range
   - Peak period: Tp = 1/fp, where fp is the frequency of the peak energy in this partition
   - Mean direction: Energy-weighted average of `.swdir` values across the partition's bands
   - Energy fraction: This partition's m₀ / total m₀ (indicates dominance)

4. **Minimum energy threshold:** Peaks with energy < 5% of the dominant peak's energy are noise, not swell systems. Discard them.
5. **Maximum systems:** Cap at 4 swell systems. If more peaks are detected, merge the weakest into adjacent systems.

### Canonical model

`SpectralWaveComponent`:
- `height` (float, group_wave_height) — Hs for this swell system
- `period` (float, group_wave_period) — peak period
- `direction` (float, degrees true north) — mean wave direction
- `energy` (float, m²) — zeroth moment of this partition
- `frequency_range` (tuple[float, float]) — Hz bounds of this partition
- `classification` (str) — `"groundswell"` (period ≥ 12s), `"swell"` (8–12s), `"wind_swell"` (< 8s)

### Integration with surf scoring

The surf quality scorer (Phase 3) uses spectral components to:
- Score swell dominance more accurately (energy ratio, not just height ratio)
- Apply the beach angle alignment filter per-component (a NW swell may miss a south-facing beach while a SW swell hits it)
- Assess multi-swell interference (compatible swells combine; opposing swells create confused seas)

## Consequences

- **New canonical model:** `SpectralWaveComponent` added to `models/responses.py`.
- **NDBC provider fetches 3 files per station** instead of 1 (`.txt`, `.swden`, `.swdir`). Three HTTP requests per station per update cycle. Cache TTL 60 min for all three.
- **Station capability differentiation:** The NDBC provider must track which stations have spectral sensors. `activestations.xml` contains sensor metadata. Stations without wave sensors or without spectral capability return standard met only.
- **Surf scoring quality improves** — multi-swell detection and per-component directional filtering are the primary quality gains.
- **Marine observation display** — the dashboard marine page can show "Primary swell: 5ft @ 14s from SSW" and "Secondary swell: 2ft @ 8s from W" instead of just "Significant wave height: 5ft".

## Acceptance criteria

- [ ] NDBC provider parses `.swden` file (46 frequency bands of energy density)
- [ ] NDBC provider parses `.swdir` file (46 frequency bands of direction)
- [ ] Spectral decomposition identifies 1–4 swell systems from spectral data
- [ ] Each system has height, period, direction, energy, and classification
- [ ] Peaks below 5% of dominant peak energy are discarded
- [ ] Provider returns standard met composite values when spectral files are unavailable or empty (graceful fallback)
- [ ] `SpectralWaveComponent` model validates and serializes correctly
- [ ] Station discovery differentiates wave-capable from atmospheric-only stations

## Implementation guidance

- **Spectral parsing:** In `providers/buoy/ndbc.py`. Fetch `.swden` and `.swdir` for each configured station. Both files have the same 46-column frequency layout. Parse the most recent observation row from each.
- **Peak detection:** Simple local-maximum scan on the energy array. No scipy dependency — this is 46 values, not a signal processing problem.
- **Energy integration:** Trapezoidal rule over the partition's frequency bands. m₀ = Σ(S(f) × Δf) across the partition.
- **Direction weighting:** For each partition, mean_direction = atan2(Σ(S(f)×sin(dir(f))×Δf), Σ(S(f)×cos(dir(f))×Δf)). Energy-weighted circular mean — standard for directional wave spectra.
- **Classification thresholds:** ≥ 12s = groundswell, 8–12s = swell, < 8s = wind_swell. These are standard NWS thresholds.
- **Out of scope:** ADCP current data (`.adcp` files) — different data type, not part of this decision.

## References

- NDBC wave measurement FAQ: [ndbc.noaa.gov/faq/wavecalc.shtml](https://www.ndbc.noaa.gov/faq/wavecalc.shtml)
- NDBC realtime data format: [ndbc.noaa.gov/faq/rt_data_access.shtml](https://www.ndbc.noaa.gov/faq/rt_data_access.shtml)
- Chawla et al. 2013 — WaveWatch III spectral partitioning
- Hanson & Phillips 2001 — WaveSEP swell delineation algorithm
- Related ADRs: ADR-083 (buoy domain), ADR-084 (NWPS supplementation uses spectral data for swell dominance)
- Research: `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` §1, §5.3, §7.3
- Research: `docs/planning/briefs/MARINE-DATA-AUDIT-BRIEF.md` §1 (NDBC data model)
