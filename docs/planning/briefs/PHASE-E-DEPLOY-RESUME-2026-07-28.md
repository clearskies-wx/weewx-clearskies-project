# Phase E Deploy — RESUME BRIEF (2026-07-28, end of session)

**Purpose:** Resume the Phase-E live deploy + Gate E in a fresh session tomorrow. Everything needed
is here — agent context does NOT survive across sessions, so the fix agent must be **re-dispatched
fresh** with the (already-vetted) brief + approach recorded below.

**Role reminder:** I am the **coordinator** for the Marine Model Restoration Plan Phase E. I read /
verify / dispatch / QC / commit / push, but do NOT write production code beyond mechanical <50-line
fixes. Every agent report is a CLAIM to independently re-verify.

**Standing authorizations from the operator (still in force):** "Standing permission to push and
deploy as necessary for testing. Do not re-ask." "keep going unless there is a reason you need me."
Surface blocks; keep working unblocked items; only bring issues NOT already decided.

---

## STOP POINT (where we are right now)

- **Marine service is DEPLOYED and ONLINE on librewxr** (E0 disable reversed; `systemctl enabled` +
  active). Code = marine `b136f15`. `/health` 200, auth enforced.
- It is currently **fast-failing every SWAN cycle** because the per-spot bathymetric profile cache is
  missing/stale (the blocker below). This is **harmless** — it fast-fails via the migration guard +
  PCHIP refusal; it is NOT looping on the old 75-min grid.
- **The fix is scoped, operator-approved, and the agent's approach is vetted — but NOT YET CODED.**

---

## WHAT WORKED — Phase E validated live (do not re-litigate)

From the `POST /config` grid-sizing run on 2026-07-28 ~09:01 UTC:
- `deploy-marine.sh` succeeded end to end (pull b136f15, venv, import surface, unit enabled, restart,
  health/auth verified).
- **F1 projection lock**: `locked UTM zone 11 ... centroid longitude -118.0039, span 0.000 deg`.
- **F1 cold-start**: detected geometry change (L3 clusters), cleared stale hotstarts / run dirs /
  geometry markers, **signalled an immediate full run**.
- **Migration guard**: runner correctly refused the stale pre-F1 cache (`locked_utm_zone is None`).
- **L4 structure grid** sized from the real OSM pier polygon: `rotation=221°, dx=10.0 m, along=485 m,
  across=1083 m, L_tip=129.5 m, 5341 cells`.
- **L3 coarse nest**: `40 m, contains L4 with >=200 m clearance, 39×38 cells`.
- **E10 per-transect FINE→MEDIUM fallback** fired for transects 17–31 (they outrun the small L3 nest).
- **`swan_grid_sizing.json` regenerated** on disk: `locked_utm_zone: 11`, L3 res 40 m, 1 cluster,
  generated_at 2026-07-28T09:02:20Z.

---

## THE BLOCKER (root cause — confirmed by reading source + live logs)

The per-spot AND per-transect **bathymetric profiles** that feed the 1D SwellTrack (D1) model are
sampled at the **L3 SWAN grid resolution (now 40 m after E4)** instead of best native DEM resolution.
`interpolate_profile_pchip()` correctly refused the 40.2 m-spaced profile:
`ValueError: ... raw profile median native spacing 40.2m exceeds the plausible native CUDEM/DEM
resolution (15m ...). Refusing to interpolate garbage.` → per-spot profile cache NOT written → SWAN
runtime path blocked.

**Leak site:** `weewx_clearskies_marine/services/grid_sizing_chain.py`:
- `profile_grid = fine_grid or medium_grid`, where
  `fine_grid = download_bathymetry_for_level(cluster.grid, level=3)`.
- `cluster.grid.resolution_m` is 40 m (E4); `download_bathymetry_for_level` coarsens the DEM to that.
- Pre-E4, L3 was 10 m so profiles happened to pass. E4's 40 m rescope broke it.
- Open-beach (no-L3) spots (`cluster.grid is None`) silently use the 100 m MEDIUM grid — also wrong.
- Both consumers affected: per-spot extraction (~line 1106) and the per-transect fallback
  `_extract_transect_profile_with_source_fallback` (~lines 380–428). Only the per-spot one has the
  PCHIP guard, so it's the canary; per-transect degraded silently.

**Existing ruling this aligns with:** D7 ("FINE-tier native ~10 m at HB … never sampled finer than
the source"), quoted in the `_extract_transect_profile_with_source_fallback` docstring.

---

## OPERATOR RULINGS (verbatim — quote in commit + docs; the 2nd SUPERSEDES the 10 m idea)

1. "No the fine resolution should still be the BEST resolution available."
   "It should not be tied to L3, as the D1 model wants the best resolution possible, and L3 may not
   exist."
2. (rejecting a fixed 10 m target) "the profile resolution target should not be 10, 10 is the best we
   can get for Huntington Beach, but other areas can get 3m resolution. As the D1 grid uses finer
   resolution than 10m, we want to get the 3m resolution if it is available."

**Decision: TRUE absolute-native.** Profile bathymetry = the finest native the best source provides at
that location (3 m where available, ~10.3 m at HB), decoupled from L3's 40 m grid, working with or
without L3. NOT capped at 10 m.

---

## THE FIX — vetted agent approach (re-dispatch fresh tomorrow with THIS spec)

Agent `profile-bathy-fix` produced this on re-ack; I reviewed it and it is sound. Implement exactly
this (or re-dispatch an agent briefed to it). Marine repo, `main` branch. Commit, do NOT push until
verified.

**Files to edit:**
1. `weewx_clearskies_marine/providers/nearshore/swan.py`
   - Add optional param: `download_bathymetry_for_level(domain, level, *, allow_download=True,
     cache_path_override=None, margin_resolution_m: float | None = None)`.
   - `margin_resolution_m=None` (default) → margin derived from `domain.resolution_m` exactly as
     today (byte-identical for L1/L2/L3/L4 callers — nothing else changes).
   - When set (only the new profile call passes it): the coverage margin (`margin_deg_lat/lon` and
     thus requested bbox) derives from `margin_resolution_m`, while the **coarsen target** fed to the
     source functions stays `domain.resolution_m`. Implement via
     `_margin_res = margin_resolution_m if margin_resolution_m is not None else domain.resolution_m`
     used in the two `margin_deg` lines + the `_covers()` "cells" wording; the source-call coarsen
     target (`_try_ncei_regional`/`_try_crm`/etc., all pass `domain.resolution_m`) is UNTOUCHED.
   - Add `profile_bathymetry_cache_path(domain)` → new `swan_bathymetry_PROFILE_{hash}.json`, hash
     keyed on **bbox AND resolution** (distinct from the bbox-only L3 cache hash to avoid collision).
2. `weewx_clearskies_marine/services/grid_sizing_chain.py`
   - Constants: `_PROFILE_MIN_RESOLUTION_M = 3.0` (finest we request; downsample-only coarsen → true
     native everywhere ≥3 m; NOT a 10 m cap). `_PROFILE_MARGIN_RESOLUTION_M = 30.0` (coverage-margin
     basis only; 2× the 15 m PCHIP ceiling → ≥1 native cell for any source ≤15 m; ≥ the old 40 m L3
     margin guarantee).
   - Restructure the FINE profile block so profile bathymetry is downloaded at the 3 m floor over the
     profile extent, decoupled from `cluster.grid`'s 40 m, for BOTH cases:
     - **L3 exists:** build a `GridDomain` with cluster.grid's SAME bbox but
       `resolution_m=_PROFILE_MIN_RESOLUTION_M`; download via profile cache override + `margin_
       resolution_m=_PROFILE_MARGIN_RESOLUTION_M`.
     - **L3 is None (open-beach):** compute a profile-coverage bbox from the cluster's spot rays
       (coastline anchor + segment endpoints + their offshore endpoints via `point_along_bearing(…,
       max_distance_m)` + small margin) and download at the same 3 m floor. Replaces today's 100 m
       MEDIUM fallback.
   - Both consumers use this native `fine_grid`: per-spot `extract_native_profile_from_grid` (~1106)
     and per-transect `_extract_transect_profile_with_source_fallback(fine_grid, medium_grid, …)`
     (MEDIUM stays ONLY as the pre-existing E10 coverage-shortfall fallback).
3. Tests: new `tests/test_profile_native_resolution.py` — three-layer known-answer:
   - (a) ~3 m fixture source → per-spot profile sampled ~3 m, NOT 10 m, NOT 40 m (this is the test
     that separates "true native" from the rejected 10 m cap).
   - (b) ~10.3 m HB-like source → ~10.3 m native, PCHIP accepts.
   - (c) no-L3 open-beach spot → native, not 100 m MEDIUM.
   - (d) full suite green.
4. Doc-sync (META repo, separate commit): `docs/manuals/PROVIDER-MANUAL.md` §14.7 cache-paths table
   (add the PROFILE cache row) + a sentence in §14.7/§14.15 that the 1-D profile bathymetry is
   sampled at best-native (down to 3 m) resolution, independent of L3's 40 m computational grid. Also
   record the operator ruling where ADR discipline requires (ADR-093 amendment or plan decision-log —
   coordinator places this).

**C-90 preservation (the delicate part — verify in review):** `_covers()` stays unchanged; a source
must span the WHOLE domain or be rejected → next source → RuntimeError; no partial/fabricated grid.
Margin ≥ one native cell of the chosen source. A ~90 m CRM-only location: 30 m margin < 90 m native →
CRM rejected (same as old 40 m L3 path) → no fine profile → correct (no fabrication).

**Scope boundaries — do NOT touch:** `_L3_RESOLUTION_M` (40 m), L4 fixed 10 m, the bathymetry SWAN
computes on, any physics/gamma/breaking/handoff formula, the PCHIP 15 m guard threshold, the cached
`spot_profiles/{id}.json` and `swan_grid_sizing.json` payload shapes (`profile`,
`profiles_by_transect`).

**Test runner:** marine repo uses bare `python` (CPython 3.14.2 / pytest 9.0.3, no venv). From
`repos/weewx-clearskies-marine`: `python -m pytest -q`.

---

## RESUME STEPS (tomorrow, in order)

1. **Re-dispatch the fix agent** (fresh — context is gone) with the brief above. Gate the scope-ack
   (it should match the vetted approach). Include the mandatory architectural-change block + git-no-
   push + reading list (see the original brief structure in this session's history / rules/agents.md).
   Alternatively, given the spec is fully concrete, implement per spec + have a review agent audit.
2. **Verify** (coordinator, independently): `python -m pytest -q` green with real counts; `git show
   --stat` = only the allowlisted files; **read the margin-split diff to confirm C-90 intact**; run
   the (a) 3 m known-answer test and confirm it fails pre-fix / passes post-fix.
3. **Push** the marine fix (standing permission) so librewxr can pull it.
4. **Re-deploy code**: `bash scripts/deploy-marine.sh` (pulls latest marine, rebuilds, restarts).
5. **Re-push config** (regenerate grid sizing + profiles with the new native download):
   ```bash
   scp -F .local/ssh/config -q C:/tmp/marine_payload.json librewxr:/tmp/marine_payload.json
   ssh -F .local/ssh/config librewxr "TOKEN=\$(sudo grep '^MARINE_SERVICE_SECRET=' /etc/weewx-clearskies/marine/secrets.env | cut -d= -f2-); curl -sk -X POST https://localhost:8780/config -H \"Authorization: Bearer \$TOKEN\" -H 'Content-Type: application/json' --data @/tmp/marine_payload.json -w '\nHTTP %{http_code}\n'"
   ```
   (`C:/tmp/marine_payload.json` already holds the full config with the real 35-pt OSM pier polygon
   injected as `coordinates`. If it's gone: rebuild — Overpass way **45074900** "Huntington Beach
   Pier", `[out:json]; way(45074900); out geom;` with a User-Agent header; inject as `[lon,lat]`
   pairs into `marine.locations['huntington-city-beach-pier'].surf.structures['0'].coordinates`;
   base config is the live `/etc/weewx-clearskies/marine/marine.conf`.)
6. **Watch** grid-sizing regenerate (this time the per-spot PCHIP should PASS — profile at native
   ~10.3 m, not 40 m), the spot_profile rewrite (mtime updates), then the first FULL SWAN run
   complete + publish. Log grep tags: `grid sizing chain|PCHIP|profile|complete|run.*complete|
   published|ERROR`. Confirm no 75-min blowup (the whole point of Phase E).
7. **Walk Gate E** — the 27-row live validation table in `MARINE-MODEL-RESTORATION-PLAN.md`
   (+ adversarial). Owed items to close: E6 row 11, E11 item 2, E12 timeout value.

---

## KEY FACTS / ACCESS

- **SSH:** `ssh -F .local/ssh/config librewxr "<cmd>"` (direct). `sudo` for root reads. From project
  root (relative `.local/ssh/config`).
- **Deploy script:** `scripts/deploy-marine.sh` (pull→venv→imports→unit→restart→verify; enables the
  service). `--skip-pull`, `--no-restart`, `--show-secret` flags exist.
- **Marine service:** librewxr:8780, systemd `weewx-clearskies-marine`, user ubuntu, work dir
  `/var/run/weewx-clearskies/swan/`, config `/etc/weewx-clearskies/marine/marine.conf`, bathymetry
  caches + `swan_grid_sizing.json` + `spot_profiles/` under `/etc/weewx-clearskies/`.
- **Config re-push trigger:** `POST /config` (Bearer `MARINE_SERVICE_SECRET`) persists + schedules
  `run_grid_sizing_chain` when ≥1 surf spot. The wizard/admin UI is currently BROKEN (operator: fix
  later; use manual config push for now) — that's why we POST the hand-built payload directly.
- **Spot:** `huntington-city-beach-pier` (surf) + `huntington-harbor` (marine/fishing, no surf).
- **Working payload file:** `C:/tmp/marine_payload.json` (durable; c:\tmp is an additional working
  dir). Raw OSM: `C:/tmp/pier_osm.json`.

## SESSION LEDGER (2026-07-28)

- Meta repo pushed: `66f7292` (governing-doc drift fix: ARCHITECTURE/API-MANUAL/PROVIDER-MANUAL/
  ADR-093 Amendment 3 — L1→L4 grid model, DIFFRACTION→L4, 15 m-edge retirement), `e85c4fb`
  (API-MANUAL two-tier schedule → E8 hourly-fill sync). Both accepted + verified.
- **No marine code changes yet this session** — the profile-bathymetry fix is the first, not yet
  written.
- Deploy performed: `deploy-marine.sh` (b136f15 online), manual config push with OSM coords, grid
  sizing ran (geometry good, profile PCHIP failed → blocker).
