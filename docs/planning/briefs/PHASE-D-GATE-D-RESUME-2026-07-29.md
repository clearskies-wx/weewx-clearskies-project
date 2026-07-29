# Phase D & Gate D Resume Brief — 2026-07-29 (post Gate F)

**Role:** Coordinator for the Marine Model Restoration Plan. Phase F and **Gate F are DONE** (this
session). Continue with **Phase D (D1) → Gate D** — the last of the plan — which is where the two big
open correctness defects **C-E05** and **C-E09** get fixed and the whole chain is validated against
reality. Read / verify / dispatch / QC / commit / push. Do NOT write production code beyond mechanical
<50-line fixes. Every agent report is a CLAIM to independently re-verify (acceptance gate).

## Confirm at session start
Two standing authorizations (operator-granted, in force last session — reconfirm they still hold):
1. **"Push and deploy as necessary for testing. Do not re-ask."**
2. **"Keep going unless there is a reason you need me."**
The one hard stop: any architectural change (7-trigger test) OUTSIDE what the plan pre-approves → STOP
and ask the operator. Never push without the operator having said "push" (covered by auth #1 for testing).

## Read first (originals, not summaries)
- `docs/planning/MARINE-MODEL-RESTORATION-PLAN.md` — **Phase D (D1, ~line 1758)**, **Gate D (~line 1776,
  12 rows)**, and note line 739 (Phase D runs LAST, after Gate F — now satisfied). Also §0A (grid rulings).
- `docs/planning/MARINE-MODEL-RESTORATION-CONCERNS.md` — **C-E09** (the big one: broken L4→D1 handoff
  plumbing) and **C-E05** (3 swell trains → 1). These two ARE the Gate D correctness work. Also read the
  new **C-E10 / C-E11** (pre-existing environmental noise on librewxr — NOT defects, do not chase).
- `rules/coordinator.md`, `rules/agents.md`, `rules/verification.md` — dispatch gate, acceptance gate,
  architectural block (mandatory agent-prompt section), adversarial independence, validate-against-reality.
- `docs/ARCHITECTURE.md` (SWAN section, SwellTrack/1D handoff, line ~106); `docs/manuals/API-MANUAL.md`
  §17/§18 (surf endpoint, multiSwell, handoff); `reference/clearskies-dev.md`.

## What landed this session (Phase F + Gate F — all pushed; marine HEAD `ccb727c`, deployed `5c830f5`)
- **F1** `7002ed1` — carry `is_wind_sea` through `swan_spectral.watershed_partitions_to_component_format()`
  (read by field, not index; inert in published payload). **F2** `6458d45` — sample per-spot wind from the
  SAME `blended_wind` field forcing SWAN (`swan.py:_sample_wind_at_point`, coastline anchor, refuse-not-
  substitute). **F3** `a802fdd` — `services/wind_sea_growth.py` finite-depth fetch-limited growth kernel
  (Young & Verhagen 1996 coefficients via **Karimpour & Chen 2016** eq 11a/11b + Table 1, operator-ruled
  acceptable). **F4** `466b1a0` (+`edfbe52`) — grow the flagged wind-sea partition's boundary Hs in
  `run_pipeline()` (onshore component only; swell partitions byte-identical). **F5** `d1b3583` — synthesize
  a wind-sea partition when SWAN handed none over + onshore wind (no double-count guard). **Row 11** `5c830f5`
  — publish `tideLevel` in the surf payload (refuse-not-substitute). Guards `16c778b/0536174/9d8af18/f91a891/
  caf473a/ccb727c`; quick-update fixture fix `1c5ddf1`; doc-drift `0eda6ab`. Parent repo: API-MANUAL
  `tideLevel` doc + concerns C-E10/C-E11 committed.
- **Gate F PASSED**: 11/11 rows evidenced (row 11 live `tideLevel=0.419`; magnitude 0.175–0.189 m; known-
  answer 5.5%), blind adversarial audit **6/6 PASS** + 1 LOW finding fixed.
- **Phase F does NOT fix the degraded live forecast** — that is C-E09/C-E05, i.e. THIS remaining work.

## The remaining plan (this session's job)
### Phase D — D1 (cold-start first hour)
The first output row of every run is the empty initial field (`Hsig 0.014 m`, `Tm01 1.6 s`, partitions
zero) and is published as forecast hour 0 — expected for a cold-started spectral model. `aa4553d` fixes the
hotstart. **⚠ Every deploy/restart invalidates the hotstart → the first cycle after it is necessarily a
cold start (empty hour 0), ONCE.** Evaluate D1 on the **second full cycle after the last restart**, when a
hotstart written by the new geometry exists. Only if hour 0 is STILL empty on that second cycle does
suppression get designed (and then, not before). A coordinator who reopens `aa4553d` on the first post-
deploy empty hour has made a sequencing error. (Invariant 9 `published_hour_has_nonempty_wave_field` fires
on the empty hour 0 — that firing is this same cold-start artifact, not a new defect.)

### C-E09 — broken L4→D1 handoff plumbing (HIGH, the big one)
After C-E07 the L4 grid converges (valid_fraction 100%) and all 32 transects select **rule 1 (L4)**
(`truncated_at_m` ~1.5–1.7 m), but the D1 output is **worse than the L2→D1 path**: period collapses to
~8–9 s (vs 17.5 s on L2, 16–18 s reality), surf face under-forecasts, transects zero out. Runtime tell
(trace T4B.3): the per-transect handoff **depth** is picked per transect at 10 m, but the **spectrum** (and
its watershed components) is read from ONE shared diagnostic CURVE at ~50 m nearest-station — NOT each
transect's own L4 `TABLE PT*` columns (which ARE emitted but not consumed). **Fix:** (1) read each
transect's own L4 `TABLE PT*` stations for the handoff spectrum; (2) fix the surfaced period quantity
(8.1 s looks like a mean/TM01 or mis-read, not the swell peak); (3) stop transects zeroing when L4 is the
source; (4) the L4-path output must **match or beat** the L2-path against reality before rule 1 is trusted.
The D1 (1-D) model itself WORKS — the L2→D1 path matched reality; do NOT break it. A stopgap of forcing the
L2→D1 handoff exists if needed while fixing the L4→D1 plumbing.

### C-E05 — watershed collapses 3 swell trains → 1 (HIGH)
Reality (Surfline LOTUS): **3 trains** — 18 s SSW 195°, 16 s SSE 168°, 10 s S 184°. We publish 1/empty
(`spectralComponents=[]`, `multiSwell` zeros; on 07-29 also flat/static across all 67 hours). The full 2-D
spectrum IS captured/stored (`spot.spectral`/`spectral_dwr`, `freqs_hz` present) — the **watershed
partitioning of that spectrum collapses the trains into one**. Runtime tell: "no PT* partitions available
for the L2 DWR baseline; components empty." **Fix:** resolve the DWR-baseline spectral watershed so it
returns the multiple trains present in the stored 2-D spectrum; **add a known-answer/guard test** that a
spectrum carrying ≥2 separated peaks partitions to ≥2 non-zero components; re-validate against a real
multi-train Surfline/NDBC read. Builds on F1's `is_wind_sea`-carrying conversion — coordinate so they don't
undo each other. C-E05 and C-E09 both feed D1's input — **fix together.**

### Gate D — validate the whole chain (12 rows, ~line 1776)
Absolute agreement with a real reference. **Row 3/4** surf height & swell partitions vs Surfline/Surf-
forecast (deltas stated). **Row 5** the westerly (6–8 s W) published in `multiSwell`. **Row 6** alongshore
variation real (spread across 32 transects; E6 `TRANSM 0.82` → ~20% lee deficit, not ~5%). **Row 11 (new,
Phase F)** locally-generated wind sea reaches published output — the end-to-end proof F1–F5 did anything,
**deferred here from Gate F on purpose** (needs the L4→D1 handoff working first). **Row 12** a no-structure
spot byte-identical to pre-Phase-E. **Known-answer for the whole thing:** the finished output must match
reality — **Surfline OBSERVED surf 4–6 ft, period 16–18 s, 3 swell trains** — before rule 1 is trusted.
Then blind `clearskies-auditor` (disprove on the deployed system), then `clearskies-docs-author` syncs
ARCHITECTURE/API-MANUAL/rules to what actually landed.

## Reality baseline (operator screenshots 2026-07-28/29 — ground truth; env clock is 2026 so live external
compare is limited, use these)
- **Surfline OBSERVED surf (face): 4–6 ft.** Swell (LOTUS): 1.9 ft @ 18 s SSW 195° + 1.9 ft @ 16 s SSE
  168° + 1.1 ft @ 10 s S 184° (THREE trains). Rating 1–2/10.
- **surf-forecast reports SWELL heights only** (~3.5 ft SSW 16–17 s) — NOT surf/face. Do NOT compare our
  surf-face to surf-forecast's swell (that error was made and corrected).

## Rules / posture
- **Delegation:** impl / test / audit as SEPARATE agents; the auditor is BLIND to impl+test work product
  (design + expected numbers only, told to disprove). Re-verify EVERY agent claim yourself (independent
  re-run, allowlist diff, spot-check a design element in the file).
- **Architectural block:** the 7-trigger block verbatim in every impl-agent prompt. The C-E05/C-E09 fixes
  read each transect's own L4 PT* stations and fix the surfaced period — verify whether that is *fixing a
  broken consumer within the existing handoff contract* (methodology, OK) vs *moving the handoff point /
  changing what feeds D1* (architectural, STOP). If a fix would change the handoff boundary/contract, STOP
  and ask. The D2 clean-boundary handoff (SWAN stops at 15 m; 1-D starts there) is deliberate — don't move it.
- **Git:** never push without "push" (auth #1 covers testing). Agents: local edit+commit only, no
  push/pull/fetch/rebase/merge; never edit/commit on a container. Deploy flow: local edit → local commit →
  coordinator pushes → deploy script pulls.
- **Validate against reality, not model output.** A conservation/energy-closure check cannot detect a
  missing swell train. Pick the comparison quantity (surf FACE 4–6 ft; three train periods) before looking
  at numbers. Flat-across-hours output is a defect signal. Total-right-distribution-wrong is the hard mode.

## Access facts / operational gotchas (learned this session — save time)
- **SSH MUST run from the repo root** `c:\CODE\weather-belchertown` (relative `.local/ssh/config`). Do NOT
  `cd` into `repos/weewx-clearskies-marine` before an `ssh` call or the config isn't found.
  `ssh -F .local/ssh/config librewxr "<cmd>"` (marine). `... weewx` (API). Read-only on containers.
- **Bearer secret is NOT in secrets.env** (that only has `SURF_COMPUTE_SECRET`). Read it from the running
  process env: ``sudo bash -c 'PID=$(systemctl show -p MainPID --value weewx-clearskies-marine); tr "\0"
  "\n" < /proc/$PID/environ | grep "^MARINE_SERVICE_SECRET=" | cut -d= -f2-'``. Surf endpoint:
  `GET https://localhost:8780/surf/huntington-city-beach-pier` with `Authorization: Bearer <that>`.
- **`/surf` is SLOW post-restart** (C-E10 API-URL-unset 502 + C-E11 OFS 404 add latency per request) — use
  `curl --max-time 150`+; short timeouts return `HTTP 000` (not a real failure). `/health` is fast.
- **Run cadence:** full run (`run_all_spots`, new `lastRunTime`) fires only on **extended HRRR cycles
  00/06/12/18Z**, or when a geometry-changing `POST /config` sets `force_full_run_signal` (service.py
  ~197–217). Intervening cycles → `run_quick_update` (still full L1–L4 + 1D). A plain deploy/restart does
  NOT auto-run a full cycle — it restores the disk cache and serves it. To force a fresh cycle: config push
  (`scp C:/tmp/marine_payload.json librewxr:/tmp/ ; POST /config`) or wait for the next 00/06/12/18Z.
- **pytest is NOT in the deployed venv** — for deployed-system checks use plain-python probes:
  `sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-marine && PYTHONPATH=. .venv/bin/python - <<PY ... PY'`.
- **Deploy:** `scripts/deploy-marine.sh` (pulls, builds, restarts, verifies /health). Cold-start cycle
  ~10–15 min; the deploy command itself may exceed the 120s tool timeout and finish in background.
- Trace (enabled, `CLEARSKIES_MARINE_DEBUG_TRACE=1`): `/var/log/weewx-clearskies/marine-trace-YYYYMMDD.jsonl`.
  `profile_to_1d` rows carry `truncated_at_m` (rule-1-vs-3 tell). Marine artifacts under
  `/etc/weewx-clearskies/` and `/var/run/weewx-clearskies/swan/`.
- Config: HB-only live (`huntington-city-beach-pier`, real 35-pt OSM pier polygon in `marine_payload.json`).
  The admin/wizard UI drops structure coordinates on save (C-E02) — use the manual config push, not the UI.

## Sequencing recommendation
1. Trigger a full cycle (config push) so a hotstart-based run exists; wait a second full cycle for **D1**.
2. **C-E09 + C-E05 together** (they both feed D1's spectrum): diagnose the per-transect L4 `TABLE PT*`
   consumption + the watershed collapse from the live trace FIRST (understand before editing — the C-E07
   history shows the first hypothesis can be a red herring), then dispatch impl/test/blind-audit.
3. Walk **Gate D** against the reality baseline; blind audit; docs-author sync. Do not declare a row passed
   without pasted live output; a single-partition publish where the buoy resolves several is C-E05 recurring.
