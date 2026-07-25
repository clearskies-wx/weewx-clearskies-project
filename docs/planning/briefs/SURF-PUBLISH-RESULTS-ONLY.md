# Surf model: publish results, not working data

**Date:** 2026-07-25
**Status:** Approved by operator in chat. Implement as specified.
**Scope:** `weewx-clearskies-swan-swelltrack`, `weewx-clearskies-api`, `weewx-clearskies-dashboard`, meta repo docs.

---

## 1. The problem, measured

The SWAN service on `librewxr` publishes a per-spot payload that the API on the
`weewx` host downloads. Measured on the live cache (`/var/run/weewx-clearskies/swan/forecast_cache.json`,
one spot, cycle of 2026-07-25 19:28):

| Key | Size | Read by the API |
|---|---|---|
| `spectral.handoff_by_transect` | **21.51 MB** | one code path — the surf endpoint's recompute fallback |
| `swelltrack` | 2.02 MB | surf endpoint, every request |
| `forecast` | 0.56 MB | surf endpoint, every request |
| `spectral.energy` | 0.553 MB | beach-profile endpoint's local pipeline |
| `spectral.freqs_hz` + `dirs_deg` | 0.031 MB | beach-profile endpoint's local pipeline |
| `transect` | 0.172 MB | served (geometry) |
| `spectral.components` | 0.030 MB | swell display card + surf scoring |
| `spectral.handoff_depth_m` / `handoff_source_level` / `clamped` | 0.001 MB | served as `handoffDepthM` / `handoffSourceLevel` |
| **Total** | **24.88 MB** | |

The API re-downloads the whole payload **every 60 seconds**
(`_REMOTE_HEALTH_INTERVAL_S = 60`, `providers/nearshore/swan.py:613`), regardless of
whether the model produced anything new. The model cycle is ~25 minutes. That is
~36 GB/day of LAN transfer for a single spot, scaling linearly with spots.

Two further findings from tracing:

1. **`handoff_by_transect` has one consumer and it never fires.** The surf endpoint
   reads it only when a timestep is missing from the precomputed `swelltrack` cache.
   Live coverage measured at 67 forecast timesteps / 67 precomputed entries / 0 missing.
2. **When the recompute path does fire, the data round-trips.** The API downloads the
   spectra from the SWAN service (port 8767), then POSTs them back to the compute
   service (port 8770) on the same host — `compute_client.py:292` sends `specout_data`
   verbatim. The `weewx` host acts as a courier for data that starts and ends on `librewxr`.

## 2. Operator ruling (2026-07-25)

> "The only thing that the API needs is what would actually get called from an endpoint,
> it does not need all of the data that went into that."

> "You need to understand the model either works, or it doesn't... we have no 'good data'
> that is a fallback. […] these fallbacks are not fallbacks, they are smoke and mirrors
> that should never have existed. They were never discussed in planning, hide problems
> and produce bogus data."

Two rules follow, and they govern every decision in this brief:

- **The model host publishes answers. The API serves answers.** Model working data
  (raw spectra, per-transect spectra) never crosses the host boundary.
- **No recomputation on the API host in remote mode.** If the model did not produce an
  answer, the endpoint returns null and says so. It does not substitute, estimate, or
  recompute.

### What is NOT a fallback, and must be preserved

**Bundled single-host mode.** When `[swan] service_url` is unset, SWAN runs in-process on
the weewx host and there is no `librewxr`. Computing locally in that topology is not a
fallback — it *is* the model, and ARCHITECTURE.md documents it as the bundled operator
install. Every deletion in this brief targets the **remote-mode** path only. Do not remove
bundled-mode computation.

## 3. Target contract

### 3.1 `GET /surf/{spot_id}/forecast` — SWAN service → API

The **published view** drops the four heavy arrays from each `spectral` entry:

| Field | Published? |
|---|---|
| `time`, `components` | yes |
| `handoff_depth_m`, `handoff_source_level`, `clamped` | yes (0.001 MB, and they are served) |
| `energy`, `freqs_hz`, `dirs_deg`, `handoff_by_transect` | **no** |

`forecast`, `swelltrack`, `transect`, `run_time`, `hrrr_cycle_time` are unchanged.

Published size falls from **24.88 MB to ~2.8 MB**.

The SWAN service's **internal** `_forecast_cache` and the on-disk `forecast_cache.json`
keep the full data. The model host owns its working data and needs it to answer profile
requests, including after a restart. Trim at the serving boundary, not at the source.

### 3.2 `GET /surf/{spot_id}/profile?time=<ISO8601>` — NEW, SWAN service

Bearer auth, same secret as `/surf/{spot_id}/forecast`.

- Exact-match lookup of `time` against the full internal spectral data.
- Runs the 1D pipeline for that one timestep, on the model host.
- Returns the `PipelineResult` in **SI units**, using the same serialization the compute
  service already uses for `POST /compute/swelltrack` responses. One wire format, not two.
- When the timestep is absent or the pipeline yields nothing: HTTP 503 with a structured
  body. Do not invent a result.

**Unit conversion and response shaping stay on the API.** The API is the single conversion
authority (ARCHITECTURE.md, "Layer Responsibilities"). The SWAN service returns SI; the API
converts and shapes.

### 3.3 `POST /report/gap` — NEW, SWAN service

Bearer auth. Body: `{spot_id, valid_time, endpoint, run_time}`. Returns 204.

Logs one WARNING per distinct `(spot_id, valid_time, endpoint, run_time)` so every model
failure lands in the model's own log, in one place. Deduplicate in memory with a bounded
structure — a dashboard on a refresh loop must not be able to flood the log or grow the
process without limit.

### 3.4 API host — polling

Compare `last_run` from `GET /health` against the `run_time` on the locally cached entry
for that spot. Fetch the forecast **only** when they differ, or when there is no cached
entry at all (the last-good cache has a 7-day TTL and can expire).

Effect: ~2.8 MB once per ~25 minutes instead of 24.88 MB every 60 seconds.
**~36 GB/day → ~0.16 GB/day** for one spot.

### 3.5 API host — no recomputation in remote mode

- **Surf endpoint:** when a timestep is missing or malformed in the `swelltrack` cache,
  that timestep is `modelStatus: "unavailable"`. Log a WARNING and report the gap. Delete
  the recompute branch.
- **Beach-profile endpoint:** query the SWAN service (§3.2), convert units, shape the
  response. Delete the local pipeline invocation and the compute-service round trip.

### 3.6 Null semantics on the beach-profile endpoint

Today a missing profile raises HTTP 404. That reads as "wrong URL" when the truth is
"the model has no answer for that hour."

- **Model has no answer for the requested hour** → HTTP 200, null profile payload, explicit
  unavailable status mirroring the surf endpoint's existing `modelStatus` vocabulary.
- **Spot not configured / no transects / unknown location** → stays HTTP 404. That is a
  configuration error, not a model gap, and the two must stay distinguishable.

## 4. Acceptance criteria

1. Published payload for one spot measures **< 3.5 MB** (from 24.88 MB).
2. No key removed from the published payload is read by any code path that runs on the
   weewx host in remote mode. Prove it by grep, not by assertion.
3. No field currently present in a `GET /api/v1/surf/*` or `GET /api/v1/surf/*/profile`
   response disappears or changes type, except the documented 404 → 200-with-null change
   in §3.6.
4. The forecast download is skipped when `run_time` is unchanged; verified from logs.
5. Bundled single-host mode (no `[swan] service_url`) still computes locally and is
   covered by an existing or new test.
6. ARCHITECTURE.md and every affected manual updated (see §5.4).

## 5. Work breakdown

### 5.1 `weewx-clearskies-swan-swelltrack`
`weewx_clearskies_swan/service.py` — trim the published view (§3.1), add `/surf/{spot_id}/profile`
(§3.2), add `/report/gap` (§3.3), update the module docstring's endpoint list.

### 5.2 `weewx-clearskies-api`
- `weewx_clearskies_api/providers/nearshore/swan.py` — conditional fetch (§3.4).
- `weewx_clearskies_api/endpoints/surf.py` — delete the recompute branch (§3.5).
- `weewx_clearskies_api/endpoints/beach_profile.py` — query the model host, delete the
  local pipeline (§3.5), null semantics (§3.6).

### 5.3 `weewx-clearskies-dashboard`
Render the beach-profile unavailable state instead of an error tile (§3.6).

### 5.4 Meta repo docs
`docs/ARCHITECTURE.md` (SWAN nearshore section, compute offloading paragraph),
`docs/manuals/API-MANUAL.md` (surf + profile endpoint contract, null semantics),
`docs/manuals/PROVIDER-MANUAL.md` (nearshore provider remote-mode fetch behaviour).
Check `OPERATIONS-MANUAL.md` and `DASHBOARD-MANUAL.md` and state explicitly whether each
needs a change.

## 6. Known adjacent issues — NOT in scope

- The SWAN service's own precompute POSTs to the compute service on the same host
  (`providers/nearshore/swan.py:1526` → port 8770 on librewxr). Wasteful, but internal to
  the model host and generates no LAN traffic.
- `omp_num_threads = 16` is stale in the weewx host's `/etc/weewx-clearskies/api.conf`.
  Harmless (SWAN does not run there) but misleading.
- The ~1,260 unattributed `run_pipeline` calls are plausibly explained by the pre-precompute
  behaviour (67 timesteps × ~19 surf requests). Not confirmed; tracked separately.
