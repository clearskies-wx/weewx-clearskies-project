# PARKED — GOES-18/19 satellite seam over New Mexico (2026-08-08)

**Status:** Diagnosed, remediation designed, deliberately deferred by operator ("put a pin in
this"). No approval given for any code change. Both steps below are physics-formula changes —
**operator approval required in chat before implementing** (architectural trigger 1).

## Symptom

Visible seam in the satellite layer: vertical line near 106°W bisecting New Mexico, then a
diagonal running SW from below Albuquerque toward Nuevo Casas Grandes. Clouds truncate,
appear, or vanish at the line.

## Diagnosis (verified 2026-08-08, live measurements)

- The seam is **GOES-18's native CONUS scan-sector eastern edge** — measured from the cached
  grid (`/data/goes18/IR/grid_meta.npz`, inverse-projected): 103.8°W @ 39.9°N → 106.2°W @
  35.7°N → 108.0°W @ 31.8°N → 109.3°W @ 28.1°N. Matches the observed line exactly.
- East of the edge, `render_multi_satellite_tile` (repos/librewxr,
  `src/librewxr/tiles/satellite_renderer.py`) fills per-pixel from GOES-19 (covers to ~128°W).
- Frame timestamp sets of both satellites are identical (time offset ruled out).
- Clouds truncate because the two satellites displace cloud tops in opposite directions
  (parallax, ~15–25 km for tall anvils at these slant angles) and differ in limb brightness.
- Not caused by the 2026-08-08 memory work. Seam exists since multi-satellite compositing
  (fork commits e4b22cc → 8773e53, Aug 5–7). Before that, the area east of GOES-18's edge had
  NO satellite data (transparent) — the fill made an invisible absence visible.
- Prior art warning: per-pixel *blending* was tried and reverted (fork commit e4b22cc) — hot
  desert ground encoded as 0 was treated as no-data and GOES-19 bled through as white
  splotches. Do not reintroduce naive blending.

## Best practice (researched; operator briefed)

Operational mosaics (NASA/NCEP-CPC MERGIR, NOAA GMGSI) **correct then hard-switch — never
blend**:

1. **Limb correction** — zenith-angle-dependent brightness correction per satellite
   (Elmer et al. 2019, JTECH; Janowiak-style). Kills the gray-level step at the seam.
2. **Parallax re-navigation** — sample each satellite as if targets sit at a constant ~10 km
   height; clouds land at true positions from both views. Trade-off: clear-sky ground features
   (coastline) shift ~8–12 km (4–6 px) against the basemap. Half-measure: assume 5 km.
3. Per-pixel single-satellite selection by smallest viewing zenith angle (we approximate this
   today per-tile + gap fill).

NOAA's own GeoColor CONUS composite ships with a hard seam at ~100°W — doing nothing is
defensible.

## Effort estimates (from 2026-08-08 session)

- Step 1: ~1 day (one-time per-satellite correction table, one vectorized add per frame at
  ingest, KAT + before/after seam render). Recommended first, alone.
- Step 2: ~2–3 days (elevated-point forward projection + KAT against independent
  implementation + visual validation + pick height constant). Only if truncation still
  bothers after step 1; carries the coastline-shift trade-off.

## Re-entry checklist

1. Get operator approval for step 1 (formula change).
2. Implement in repos/librewxr fork; deploy via scripts/deploy-librewxr.sh; verify on a
   stormy day with cells on the seam (screenshot before/after).
3. Decide on step 2 only after step 1 is judged.
