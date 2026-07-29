# Phases F & D Resume Brief — 2026-07-29

**Role:** Coordinator for the Marine Model Restoration Plan. Continue with **Phase F → Gate F →
Phase D → Gate D** (the remaining plan). Read / verify / dispatch / QC / commit / push. Do NOT write
production code beyond mechanical <50-line fixes. Every agent report is a CLAIM to independently
re-verify (acceptance gate).

## Read first (originals, not summaries)
- `docs/planning/MARINE-MODEL-RESTORATION-PLAN.md` — **Phase F** (F1–F5, ~line 1603), **Gate F**,
  **Phase D** (D1, ~line 1758), **Gate D** (~line 1776). NOTE line 739: *Phase D runs LAST, after
  Gate F* — running D before F validates a chain F will change. Also read the plan's §0B (Phase F
  design authority + double-count trace) before any F task.
- `docs/planning/MARINE-MODEL-RESTORATION-CONCERNS.md` — **C-E05** and **C-E09 are the big ones and
  are exactly Phase F / Gate D work.** Also C-E06/07/08/02/01/03/04. (Committed `e38f017`, local, not
  pushed.)
- `rules/coordinator.md`, `rules/agents.md`, `rules/verification.md` — dispatch gate, acceptance gate,
  architectural block (mandatory agent-prompt section), adversarial independence, validate-against-reality.
- `docs/ARCHITECTURE.md`; `docs/manuals/API-MANUAL.md` + `PROVIDER-MANUAL.md`; `reference/clearskies-dev.md`.

## Current state (verified this session, 2026-07-28/29)
- **Marine service:** librewxr:8780, systemd `weewx-clearskies-marine`. Repo `weewx-clearskies-marine`
  at **`641b903`** (pushed + deployed). HB-only config live (`huntington-city-beach-pier`, real 35-pt
  OSM pier polygon). Config push tool: `C:/tmp/marine_payload.json` → POST `/config`.
- **Phase E deploy: DONE.** Grid geometry verified live: rotated L4 CGRID/NGRID agree (228.5°), 12,639
  cells (L1 567 / L2 5530 / L3 1406 / L4 5136), DIFFRACTION L4-only (smnum=27 correct for 10 m),
  OBSTACLE from the real 35-pt outline, DWR SPECOUT on L2 (full 73-row series), no `111320`
  pin-projection anywhere live. Gate E row 26 PASSES (blind-audit F2 "pin-projection still live" was a
  stale-`.pyc` FALSE finding — API `nearshore/` was pruned, C-49/C-60).
- **L4 convergence FIXED (C-E07, `641b903`):** L4 was 0%-valid (INPGRID BOTTOM emitted at the CGRID
  footprint, not enclosing the rotated CGRID) → silently fell back to L2. Fix = emit INPGRID BOTTOM at
  the `l4_coverage_domain()` enclosing box. **L4 now converges valid_fraction 100%**, and all 32
  transects select **rule 1 (L4 breaking depth ~1.5–1.7 m)** — verified via the `truncated_at_m` trace
  (Gate E row 9 now passes at the plumbing level).
- **BUT the OUTPUT is currently WORSE than the L2 path (C-E09 — the big open concern):** with L4 as the
  handoff source, period collapses to **8.1 s** (vs 17.5 s on the L2 path, vs 16–18 s reality), surf
  face **under-forecasts (~3.4 ft vs 4–6 ft observed)**, some transects zero out, and the swell is flat
  across all 67 forecast hours. **The D1 (1-D) model itself works well** — the L2→D1 path matched
  reality; the **L4→D1 per-transect spectral handoff plumbing is broken** (per-transect spectrum is
  read from ONE shared ~50 m diagnostic CURVE, not each transect's own L4 `TABLE PT*` stations).
- **Spectrum wrong (C-E05):** reality has 3 swell trains (18 s SSW, 16 s SSE, 10 s S); we publish
  1/empty (`spectralComponents=[]`, `multiSwell` zeros).

## The remaining plan
- **Phase F (F1–F5) — wind source term in the 1-D model.** F1 carry `is_wind_sea` through partition
  conversion (`swan_spectral.py`); F2 sample per-spot wind from `blended_wind` (the SAME field forcing
  SWAN) — refuse-don't-substitute; F3 depth-limited fetch-limited growth kernel (Young & Verhagen 1996)
  **gated on a known-answer test**; F4 grow the wind-sea partition along the 1-D run; F5 fallback
  synthesize a wind-sea partition when SWAN handed none over. **Phase F trips architectural trigger 1
  (formula) — the operator ALREADY approved it (plan §0B.4). Read §0B in full first.**
- **Gate F** — attributable against Gate E.
- **Phase D (D1)** — cold-start first hour; verify the whole chain.
- **Gate D** — absolute agreement with a real reference. **This is where C-E05 + C-E09 must be resolved
  and validated.**

## Critical: C-E05 + C-E09 are entangled with Phase F / Gate D — do not fix in isolation
- C-E09 fix = read each transect's OWN L4 `TABLE PT*` stations for the handoff spectrum (not the shared
  CURVE), fix the surfaced period quantity (8.1 s looks like a mean/TM01 or mis-read, not the swell
  peak), and stop transects zeroing when L4 is the source (they must not come out worse than the L2
  path). C-E05 fix = resolve the 3 swell components in the watershed partitioning.
- Phase F touches the SAME partition/wind machinery (`swan_spectral.py` watershed, `is_wind_sea`,
  per-spot wind). Sequence and coordinate so F and the C-E05/C-E09 fixes don't undo each other.
- **Gate D known-answer:** the finished L4-path output must **match or beat** the L2-path output
  against reality (Surfline **4–6 ft surf**, **16–18 s**, **3 swell trains**) before rule 1 is trusted.
  Validate against reality, NOT the model's own output. The D1 model works — don't break it.

## Reality baseline (operator-provided screenshots, 2026-07-28/29 — use as ground truth)
- **Surfline OBSERVED surf (face): 4–6 ft.** Swell (LOTUS): 1.9 ft @ 18 s SSW 195° + 1.9 ft @ 16 s SSE
  168° + 1.1 ft @ 10 s S 184° (THREE trains). Rating 1–2/10.
- **surf-forecast reports SWELL heights only** (~3.5 ft SSW 16–17 s) — NOT surf/face. Do NOT compare
  our surf-face to surf-forecast's swell (that error was made and corrected this session).
- Environment clock is 2026 and GRIB inputs are future-dated → live external reality compare is limited;
  the operator's screenshots are the baseline.

## Rules / posture
- **Delegation:** dispatch impl / test / audit as SEPARATE agents; the auditor is BLIND to impl+test
  work product (design + expected numbers only). Re-verify EVERY agent claim yourself before accepting
  (this session: the blind auditor's F1 was real, its F2 was a stale-`.pyc` false positive; an impl
  agent correctly found a different root cause than the brief theorized — both caught by re-verifying).
- **Architectural block:** mechanical 7-trigger test in every impl-agent prompt. Phase F formula work
  is pre-approved; ANY other architectural change → STOP and ask the operator (coordinator cannot
  approve architectural changes).
- **Git:** never push without the operator typing "push". Agents: no push/pull/fetch/rebase/merge;
  local edit + commit only; never edit/commit on a container. Deploy flow: local edit → local commit →
  coordinator pushes → deploy script pulls.
- **Deploy:** `scripts/deploy-marine.sh`. Config push: scp `marine_payload.json` → POST `/config`.
- **SSH (from project root):** `ssh -F .local/ssh/config librewxr` (marine), `... weewx` (API). Read-only
  on containers.
- **Tests:** `python -m pytest -q` from `repos/weewx-clearskies-marine`, TARGETED files only, never the
  full suite. Probe scripts in the session scratchdir with `PYTHONPATH=$(pwd)`.

## Standing authorizations (confirm still in force at session start)
- "Standing permission to push and deploy as necessary for testing. Do not re-ask." (in force this session)
- "Keep going unless there is a reason you need me."

## Access facts
- Marine artifacts under `/etc/weewx-clearskies/` (`marine/marine.conf`, `swan_grid_sizing.json`,
  `swan_bathymetry_L3_*/L4_*.json`, `spot_profiles/`, `secrets.env`) and `/var/run/weewx-clearskies/swan/`
  (`level{1,2,3_0,4_0}/INPUT`+`BOTTOM.txt`+`TABLE_*`, `forecast_cache.json`, `*_hotstart.dat`).
- Surf API: `GET https://localhost:8780/surf/huntington-city-beach-pier` (Bearer `MARINE_SERVICE_SECRET`).
- Trace: `/var/log/weewx-clearskies/marine-trace-YYYYMMDD.jsonl` (`profile_to_1d` rows carry
  `truncated_at_m` = per-transect handoff depth — the rule-1-vs-rule-3 tell).

## Gate E carry-over (optional, low priority)
- Not-yet-walked rows pending natural cycles: warm-run cadence (rows 7/20), hourly-fill L3+L4 (row 13),
  invariant-6 short-grid (row 15). Cosmetic: `swan_runner.py:4607-4614` drops `length_m` in the
  StructureConfig reconstruction (`pier(0m)` label) and `compute_spot_transects` runs at the runtime
  path without a `bathymetry_profile_fn` (tip depth logs 0.0) — logs lie, no functional effect. C-E08
  (L4 INPGRID WIND non-coverage, LOW/negligible). C-E01/C-E03 (Bolsa Chica, when brought online).
