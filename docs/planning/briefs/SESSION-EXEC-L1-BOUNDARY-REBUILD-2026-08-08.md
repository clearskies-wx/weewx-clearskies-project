# SESSION SCRATCH / HANDOFF — L1-BOUNDARY-REBUILD-PLAN execution (2026-08-08 → 09)

**Read FIRST when resuming, with `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md`
(the plan — ALL phase checkboxes, gate records, G9 design, decision log, and the Q5/Q6
closure blocks are current as of the session-4 checkpoint) and
`docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` (authority).**

## ⏭ RESUME HERE — exact next actions (2026-08-09 SESSION-4 CHECKPOINT, ~16:45Z)

**Phase G DEPLOYED and live (marine `eecfabc`, proc 08:22:05Z; new L1 93×132 publishing
all day, reality gates PASS). Operator ruled the box came out oversized (Q6): the 100 km
cap binds the BOX per axis, not the scan ray — task G9 (box-envelope clamp, FULLY
DESIGNED in the plan) fixes it. dev-phase-s agent was COMMISSIONED AND CODING S2+S3 at
checkpoint (scope-ack confirmed, all 6 findings ruled — see below; NO commits yet at
checkpoint: repo still `eecfabc` clean). Repo queue: S2/S3 close → G9 → S1+S4.**

0. **Pre-flight:** `git -C repos/weewx-clearskies-marine log --oneline -8` — look for
   "S2:"/"S3:" commits (the dev-phase-s agent may have finished after checkpoint; its
   closeout may be in the dead session's transcript — if commits exist but no closeout
   was QC'd, treat them as UNVERIFIED claims and run the acceptance gate from scratch:
   independent pytest, allowlist diff, spot-check). Marine service health via
   `ssh -F .local/ssh/config librewxr "curl -sk https://127.0.0.1:8780/health"` —
   expect status degraded ONLY by INV-11. FQDNs always.
1. **Close out / re-dispatch S2+S3.** If the agent died before finishing: re-dispatch
   `clearskies-api-dev` with the CORRECTED brief `briefs/L1-PHASE-S-DEV-BRIEF-2026-08-09.md`
   (S2+S3 ONLY; S1 is now a rewritten ladder design — see plan S1) + the six rulings in
   "S2/S3 rulings issued" below (they bind; re-state them in the dispatch). Then S4b
   test-author (wlevel/datum KATs), auditor at Gate S per plan. **S2+S4b deploy ships
   AFTER G9** (one functional change per deploy; G9 outranks — operator-ruled physics).
2. **G9 — box-size cap (operator ruling, urgent).** Full design + KAT spec + doc-sync
   list = plan §G9. Dispatch dev (swan_domain.py envelope clamp) + test (KATs h/i +
   row-(e) literal updates authorized same-commit). Then push + deploy + config re-push
   → sizing trace must show ≤100 km/axis (~91×100, S edge ≈33.18, north of SCI 33.03tip;
   Catalina S shore ≈33.30 stays inside). Re-run the G-Accept rows on the capped box
   (matched-hour + buoys + journal sweep + wall-clock; capture SWAN peak RSS — the one
   number never measured, threshold 300 MB, `ps -C swan -o rss=` sampled during L1).
   G-Accept then CLOSES (record in plan).
3. **S1 + S4a (currents ladder).** S1 design REWRITTEN in plan (P7 amended, operator
   "ok fine"): containment ladder OFS → STOFS-3D-Atl (East/Gulf/PR, total current,
   fetch its velocity netCDF — exact file pinned at implementation with one live shape
   check) → PacIOOS ROMS Hawaii (`roms_hiig` family, ERDDAP server already in §14.11)
   → RTOFS alone (direct NOMADS netCDF `rtofs_glo_2ds_n{NNN}_prog.nc`, non-tidal, loud
   log). NO summing anywhere; per-cycle selection. S4a KATs respecified (plan S4 row a/f).
4. Then **A, C1+Gate C, V** per plan order (R5 is closed — C1 is dispatchable).

## S2/S3 rulings issued (session 4, binding on the round — QC against these)
1. STOFS fetcher = WATER-LEVEL ONLY (`elevhtml` field); no velocity code, no stubs;
   docstring notes velocity is S1's question. (STOFS-2D has NO velocity — proven.)
2. Region tokens: `conus.west` (HB) / `hawaii` (HI);
   `stofs_2d_glo.t{00,06,12,18}z.{region}.f{NNN}.grib2`.
3. CO-OPS `datums` product lives on the Metadata API (`/mdapi/.../stations/{id}/datums.json`)
   — datagetter returns "no longer available" (put that error text in a comment).
   Additive product in coops.py; offset = datums[target]−datums[source] (station-local zero).
4. DEM entries hand-authored WITH catalogue URLs: Maui lahaina_13 + Big Island
   hilo/kawaihae/keauhou_13 + the 5 PR DEMs (arecibo/fajardo/guayama/mayaguez/ponce).
5. S3 branch: catch existing DatumConversionError, gate on REGION_HAWAII + tidal source
   datum, fall to CO-OPS-datums offsets; NAVD88/geodetic re-raises. Offsets fetched ONCE
   at config push, CACHED (no per-cycle datums calls).
6. Time matching nearest-within-2h; source selection PER-CYCLE — any STOFS timestep gap
   = whole-cycle STOFS failure → loud CO-OPS-uniform fallback; refuse only if both fail.

## Operator authorizations + prohibitions in force
- "As coordinator, you have permission to push/deploy as needed." (exercised: G-Accept
  deploy session 4)
- "Architectural changes called for within the plan are pre-approved" (register P1–P15
  incl. amended P7; outside it → STOP and ask). G9 + P7 ladder are operator-ruled.
- "Work through the entire plan and only stop if there are architectural issues not
  foreseen in the plan."
- **Q5-class questions (data-source routes/mechanics) are the COORDINATOR'S research, not
  operator questions** (operator, 2026-08-09, emphatic: "That is supposed to be your
  research, DO IT"). Only true register/trigger items go to the operator.
- ⛔ ROUTER ACCESS: PERMISSION DENIED (standing). FQDNs, never raw IPv4 (CLAUDE.md).
- Standing: no AskUserQuestion; plain-English reports; scratch files maintained; no full
  pytest suite ever.
- **Process burn from session 4 (do not repeat):** a background watcher with a
  `--since` window that started AFTER the target log line + no fallback timeout idled
  the session ~7 h. Every watcher: test the pattern against an existing line first, AND
  give every wait a bounded timeout that re-checks regardless.

## Phase status

| Phase | Status | Notes |
|---|---|---|
| DOC | ✅ CLOSED (session 1) | ADR-104; blind audit 7/7. |
| W | ✅ CLOSED incl. W6 (session 3) | See plan records. |
| B | ✅ COMPLETE (session 2) | Deployed `5cc28e8`. |
| G | **DEPLOYED session 4 (`eecfabc` live 08:22:05Z) — G-Accept 4 rows PASS, closes after G9** | New L1 93×132 publishing; Q6 ruled: cap binds BOX per axis → G9 (designed, queued behind S2/S3). L3-viability guard that fired at config push = PRE-EXISTING (identical line 2026-08-03 pre-G, ~235 m vs ~229 m — smart-L3 open item, not a G regression). 99-file BOUNDSPEC cap NOT enforced by 41.51AB (132 files ran; §14.15 measured deviation recorded). Reality gate PASS: combined deep Hs 0.636 m vs 46222/46253 0.8 m (−20.5%, inside ±25%); W-NW wind swell 0.65→0.34 m @275°→264° (shadow works); matched-hour headline +8…+29.5% (period-dominance shift, explained). Cycle 35m56s; L1 14m24s. RSS never measured — capture at G9 accept. |
| G9 | **DESIGNED (plan §G9) — dispatch after S2/S3 round closes** | Operator ruling: envelope clamp ≤100 km/axis, offshore edges pull in, coast side fixed; nonstationary REJECTED. |
| S | **S2+S3 IN FLIGHT at checkpoint (dev-phase-s coding, 6 rulings issued, no commits yet); S1 REWRITTEN to ladder (P7 amended, approved); S4a respecified** | Deploy order: (S2+S4b after G9), S1+S4a last. Q5 closed: RTOFS = direct NOMADS netCDF. |
| A | not started | |
| C | C2/C3 code done (session 2); C1 + Gate C dispatchable (R5 closed) | |
| V | not started | V3 note: 5-cycle wall-clock window starts AFTER G9 lands (current box is temporary). |

## Session-4 G-Accept / live facts
- librewxr runs marine `eecfabc` (proc 08:22:05Z), new L1 LIVE: bbox lon
  −118.7598..−117.7725 / lat 32.8994..34.0806 (93×132 @1 km, 12,276 cells), L2 76×83
  (sized; runner logs 75×82), L3 51×46 coarse-nest fallback (smart-L3 viability failed
  ~229 m — PRE-EXISTING class), L4 51×169. Boundary 225 points (S=93, W=132 files),
  44.9 MB. G7 cold-start guard fired correctly 08:56:33Z (state cleared, forced full run).
- Pre-deploy baseline archived in session-4 scratchpad (surf payload JSON + boundary
  inventory + WIND md5 `4c6ad285…`); post payload likewise (`g_accept_baseline_surf.json`
  / `g_accept_post_surf.json`) — scratchpad is session-scoped, so numbers that matter
  are IN the plan's G-Accept record; re-fetch fresh payloads rather than hunting files.
- Config push mechanic (needed for G9): re-push the persisted config verbatim —
  `sudo cat /etc/weewx-clearskies/marine/marine.conf | curl -sk -X POST -H "Authorization:
  Bearer $TOKEN" -H 'Content-Type: application/json' --data-binary @- https://127.0.0.1:8780/config`
  (token: `sudo sed -n 's/^MARINE_SERVICE_SECRET=//p' /etc/weewx-clearskies/marine/secrets.env`).
  Sizing chain runs in background ~3 min; look for "Marine grid sizing chain: L1 sized".
- Deploy: `scripts/deploy-marine.sh` FROM META REPO ROOT (prints commit + proc start).
- Known journal noise: INV-11 (only /health reason), NDBC QuotaExhausted, L4-handoff
  target-depth class = the compute_spot_transect SUBSTITUTION warnings (326/cycle,
  pre-existing), check_mk docker-exec spam. HRRR Lambert WARNING still GONE (W6) —
  reappearance = regression.
- Full-cycle wall-clock: 35m56s on the oversized box (13:04:23→13:40:19); pre-G 30m11s;
  expect ~32-33m after G9.
- Tracked pre-existing marine test failures unchanged (3 + 1 flaky; see plan decision log
  2026-08-09 entry). Baseline: tests/test_island_autosizing.py + tests/services/ =
  210 pass / 3 fail at eecfabc.

## Doc-sync state (session 4 — COMMITTED, meta `c767794` + earlier)
ADR-104: D2 amendment (box-cap ruling) + D9 amendment (ladder). PROVIDER-MANUAL:
§14.10a rewritten (ladder + direct-NOMADS route + composite-death evidence), §14.13a
(no-velocity, conus.west tokens, grid-writer wiring correction), §14.15 (+99-file-cap
measured deviation), §14.11 (2 coastwatch rtofs rows flagged STALE — **side-finding:
water-temp chain's rtofs_3d deep fallback is silently dead; needs its own fix round**,
parking lot). ARCHITECTURE.md: input-chain bullet (ladder) + L1-sizing bullet (cap
semantics, "lands with G9" tag). Tags come off at the implementing deploys (G9 / S1).
**Meta repo is NOT pushed this session — push at operator instruction or next natural
push point; marine IS pushed through `eecfabc`.**

## Parking lot (carried)
- Dashboard bundle per-chunk methodology ruling (open); BeachProfileCardBody D6 2
  pre-existing fails; orphaned `shadowedTransect` i18n key; openapi-v1.yaml SurfForecast
  drift (own doc-sync round).
- **NEW: coastwatch ERDDAP rtofs datasets gone → water-temperature chain deep fallback
  (erddap_ocean rtofs_3d) silently unavailable — needs its own fix round** (flagged in
  §14.11).
- Incident follow-ups 1–3 (DHCP/networkd monitoring; check_mk spam; SWAN stdin FD leak
  swan_runner.py:5474 + surfbeat_runner.py:531).
- 3 pre-existing marine test failures + 1 flaky.
- Smart-L3 viability failing at HB (~229-235 m short, falls back to coarse nest) — the
  known smart-L3 disposition item; surfaced again at G-Accept, unchanged by G.

## Agents at checkpoint
- **dev-phase-s: ALIVE AND CODING S2+S3 at checkpoint** (scope-ack confirmed 6 rulings,
  no commits yet). A new session cannot reach the old session's agent — check the repo
  for its commits; if incomplete, re-dispatch fresh (corrected brief + the 6 rulings).
- All others dead/closed (dev-w6, dev-phase-g, test-g8, audit-gate-g, inv-*).
- Session-4 monitors (RSS watcher, sizing watcher) die with the session — re-arm at G9.

## Decision log (session 4) — full text in the PLAN's decision log
- G-Accept run: 4 rows PASS; L3-guard pre-existence proven; 99-file cap measured-tolerated.
- Q6 ruled: cap binds BOX (per-ray reading was a misencoding); b3 nonstationary rejected;
  G9 created + designed.
- Q5 closed (delegated): RTOFS = direct NOMADS netCDF; STOFS-2D-no-velocity proven;
  P7 composite → ladder (operator "ok fine"); S1/S4 rewritten; full doc-sync committed.
- Phase-S scope-ack findings: coops.py allowlisted (additive datums via Metadata API);
  S2 = wiring into existing `_write_wlevel_grid_txt`; 6 dispatch rulings issued.
- Process: session idled ~7 h on a mis-windowed watcher (--since after the line, no
  timeout) — watcher hygiene rule added above.
