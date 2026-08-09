# SESSION SCRATCH / HANDOFF — L1-BOUNDARY-REBUILD-PLAN execution (2026-08-08 → 09)

**Read FIRST when resuming, with `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md`
(the plan — ALL phase checkboxes, gate records, decision log, and incident record are
current as of the session-3 checkpoint) and
`docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` (authority).**

## ⏭ RESUME HERE — exact next actions (2026-08-09 SESSION-3 CHECKPOINT, ~07:45Z)

**W6 CLOSED end-to-end. PHASE G CODE + GATE COMPLETE (G1–G8 ✅, Gate G blind audit
PASSED 0 findings, doc-sync committed). G-Accept (the live relocation deploy) is the
ONLY remaining G step and is the FIRST action next session.**

0. **Pre-flight:** verify marine service healthy post-incident (it was mid-recovery at
   checkpoint — last check: `status:failed / required input unavailable: wind` from the
   outage window; the 300s runner loop should have self-recovered. Confirm a clean
   publishing cycle BEFORE deploying anything). Verify marine repo clean at `eecfabc`.
   **Use FQDNs for every host check (librewxr.shaneburkhardt.com etc.) — new CLAUDE.md
   rule, operator-called violation.**
1. **G-Accept — the relocation deploy.** Marine local HEAD `eecfabc` is NOT pushed
   (pushed through `70d442f` only) — push, then `scripts/deploy-marine.sh` FROM META
   REPO ROOT. Full checklist = plan §G-Accept + these session addenda:
   - G7 live half: cold-start + forced full run observed (geometry signature includes
     L1 bbox — code half verified, grid_sizing_chain.py:309-331).
   - Sizing trace vs brief §4 S1 (~90×57 km, Catalina inside, boundary seaward of it)
     — INCLUDES the full ±15%/axis box check (G8 row-(e) deviation moved it here).
   - Boundary point count vs SWAN's 99-file-per-command cap (66 files pre-G; manual
     :1223). Reconstruction must adapt with no Phase-B code change (decoupling proof).
   - STOP conditions: SWAN RSS > 300 MB or cycle > 45 min.
   - Reality gate pre-declared: matched-hour headline vs cam + 46222 + 46253; a CHANGE
     is EXPECTED (islands modeled); W-NW-swell shadow window energy should DROP.
   - Post-deploy journal sweep for new WARNING/ERROR classes.
2. **Phase S.** Briefs READY + COMMITTED: `briefs/L1-PHASE-S-DEV-BRIEF-2026-08-09.md`
   (dev, S1–S3) + `L1-PHASE-S4-TEST-BRIEF-2026-08-09.md` (test-author). A dev-phase-s
   agent completed reading + scope-ack this session then died at cutover — its scope-ack
   surfaced 3 items that MUST be resolved at/before re-dispatch (full text in the
   decision-log section below):
   (a) **RTOFS access route:** BOTH plan-named candidates are dead on NOAA's side
       (no filter_rtofs.pl CGI; OPeNDAP retired NOMADS-wide SCN25-81; PROVIDER-MANUAL
       §14.11 coastwatch ERDDAP rtofs datasets gone). LIVE route: direct NOMADS netCDF
       `pub/data/nccf/com/rtofs/prod/rtofs.YYYYMMDD/rtofs_glo_2ds_n{NNN}_prog.nc`
       (~155 MB/file, 3-hourly, xarray/netCDF4 — same family as ofs.py's own pattern).
       PROPOSED LEAD RULING (not yet issued): pin direct-NOMADS-netCDF; it is the only
       live route and the plan's bounded-pin intent was "whichever works after one live
       check." Issue formally at dispatch; PROVIDER-MANUAL §14.11 staleness is a
       separate doc-sync finding to fix in the S round.
   (b) **S3 needs `providers/tides/coops.py` on the dev allowlist** (no `datums`
       product support exists today). RULE: add coops.py to the S allowlist, additive
       product only, existing products untouched.
   (c) **Brief error, confirmed by code read:** `_write_wlevel_txt` (:2285) is the
       spatially-UNIFORM stamp; the spatially-varying writer ALREADY EXISTS as
       `_write_wlevel_grid_txt` (:2329-2352, takes grids list). S2 = feed STOFS fields
       to the EXISTING grid writer (wiring, not generalization). Correct the S dev
       brief §reading-list item 6 + design pt before re-dispatch.
   Bounded pin 2 (STOFS filenames) is CONFIRMED usable: region tokens are plainly
   `conus`, `hawaii` etc. (not "CONUS West"), 4 cycles/day live-verified.
   Two deploys: S1+S4a currents, then S2+S4b wlevel (S3 rides with S2 group).
3. Then **A, C1+Gate C, V** per plan order.

## Operator authorizations + prohibitions in force
- "As coordinator, you have permission to push/deploy as needed." (exercised this
  session for W6 + incident recovery)
- "Architectural changes called for within the plan are pre-approved" (register P1–P15;
  outside it → STOP and ask).
- "Work through the entire plan and only stop if there are architectural issues not
  foreseen in the plan."
- **⛔ ROUTER ACCESS: PERMISSION DENIED (operator, 2026-08-09, emphatic).** Never touch
  the MikroTik API/credentials. Diagnose networks passively (ping/tracert/FQDN) or via
  hosts we already have SSH to.
- **FQDNs, never raw IPv4** — now a CLAUDE.md always-applicable rule (this session).
- Standing: no AskUserQuestion; plain-English reports (operator bounced jargon twice on
  2026-08-09); scratch files maintained; no full pytest suite ever.

## Phase status

| Phase | Status | Notes |
|---|---|---|
| DOC | ✅ CLOSED (session 1) | ADR-104; blind audit 7/7. |
| W | ✅ **CLOSED incl. W6 (session 3)** | W1–W5 per Gate W (session 1); W6: eccodes key typo `LovInDegrees`→`LoVInDegrees` fixed `70d442f`, deployed 05:23Z, W6-Accept PASSED (WARNING 188→0; matched-cycle rotation −12.74° vs −12.75 predicted; reality gate +9%/−3% vs buoys). **Root-cause REFRAMED:** pre-fix rotation was a NO-OP (alpha=0 every fetch), not a bbox approximation — winds were never earth-rotated; W-Accept item 1's attribution superseded (decision log). |
| B | ✅ COMPLETE (session 2) | Deployed in `5cc28e8`; see plan records. |
| G | **CODE+GATE ✅ (session 3) — G-Accept deploy PENDING (next session's first action)** | G1–G6 marine `036a2ec`/`a1281b8`/`3f98613`/`e207d79`; G8 KATs `eecfabc` (12, falsifiability verified); Gate G blind audit 0 findings, all 8 rows live evidence; doc-sync committed (ARCHITECTURE bullet, ADR-100 amendment, ADR-104 D11 note). Two lead rulings mid-round: G4 angular-extent = span+one-5°-step (operator may override pre-deploy); G1 stale-test updated same-commit. G8 row-(e) ±15% box check moved to G-Accept (lead-approved deviation). |
| S | **Briefs ready; scope-ack done; 3 findings to resolve at re-dispatch (see RESUME #2)** | Agent died at cutover — fresh dispatch needed. |
| A | not started | |
| C | C2/C3 code done (session 2); C1 + Gate C after marine repo frees up | |
| V | not started | |

## INCIDENT (2026-08-09 06:46Z, RESOLVED 07:18Z) — read the plan's decision-log entry
librewxr (an **LXD CONTAINER on ratbert** — not a physical host) lost its IPv4:
unattended-upgrades restarted systemd-networkd Aug 1 06:47Z (openssl); the daemon
wedged silently (0 journal lines, no renewals); DHCP lease (LIFETIME 8 d) expired Aug 9
06:47Z to the minute → eth0 IPv4 gone → total TCP/ICMP death. Fix:
`systemctl restart systemd-networkd` in-container via `ssh ratbert "lxc exec librewxr ..."`.
NOT deploy-correlated (W6 ran a clean cycle 05:23→06:00:56 before it). CheckMK verified
green after. **Coordinator errors recorded in plan** (stale memory-pressure bias;
misread Windows ping — router "unreachable" replies count as received; raw-IP checks;
"physical host" assumption). **Incident follow-ups parked:** (1) DHCP-lease-age /
networkd-liveness monitoring; (2) per-minute failing `check_mk_agent` docker-exec spam
in librewxr journal (radar container plugin exec, wrong PATH); (3) SWAN stdin FD leak
(swan_runner.py:5474, surfbeat_runner.py:531 — real, minor, needs a small fix round).
**Investigation side-findings that stand:** LibreWXR repo has an hourly
auto-update cron pattern (`docker compose up -d --build`, opt-in sentinel) + NO buildkit
cache pruning anywhere (43 GB / 95 entries on the box); marine code cleared of any
host-network failure mechanism.

## Pre-flight facts (updated session 3)
- librewxr runs marine commit `70d442f` (proc start 05:23:23Z) — W6 live, G NOT deployed.
- Marine repo local HEAD `eecfabc`; **pushed only through `70d442f`** — push before deploy.
- Deploy: `scripts/deploy-marine.sh` FROM META REPO ROOT.
- Journal: sudo + unit `weewx-clearskies-marine`; container is on ratbert
  (`lxc exec librewxr` via ratbert works when SSH to the container is down).
- Marine service auth: token in `/etc/weewx-clearskies/marine/secrets.env` (NOT
  /etc/weewx-clearskies/secrets.env); surf endpoint is `/surf/{location_id}` (no
  /forecast suffix); port 8780 TLS.
- Full-cycle wall-clock baselines: 31m57s (R4) → 36-37.5m recent (B/W6 accepts).
- Known journal noise NOW: INV-11 (operator item), NDBC QuotaExhausted, L4-handoff
  target-depth class, check_mk_agent docker-exec spam (incident follow-up 2).
  **HRRR Lambert WARNING is GONE (W6) — its reappearance is a regression.**
- Tracked pre-existing marine test failures (decision log): double_break_transect55
  wave-reforms; wind_gatherer cold-start lastPollAt; wind_timeline_store
  disk-persistence; flaky h4_chunked_json heartbeat timing. Baseline selection counts:
  tests/services/ + 4 root files = 238 pass/3 fail; tests/test_island_autosizing.py +
  tests/services/ = 210 pass/3 fail.

## W6-Accept quick reference (full record in plan §W6)
Pre-deploy baseline (00Z cycle, `5cc28e8`): WIND.txt md5 `9d50a5e67e4b382796dc805a98792510`
(1,026,536 B, 03:17:19Z); served h0 break 0.8913 m / 12.66 s / 227.5°. Post: −12.74°
mean rotation (fixture = the same t04z cycle the live run consumed), groundswell
unchanged, wind swell +5.5°, combined deep Hs 0.87 m vs buoys 0.8/0.9.

## Parking lot (carried; unchanged from session 2 except as noted)
- Dashboard bundle-baseline methodology mismatch (ADR-033 amended Q2 — budget is
  guideline; baseline table reworded; the per-chunk methodology ruling itself still open).
- BeachProfileCardBody.test.tsx D6 2 tests fail pre-existing (dashboard).
- Orphaned `shadowedTransect` i18n key (dashboard).
- openapi-v1.yaml SurfForecast drift (needs own doc-sync round).
- PROVIDER-MANUAL §14.11 ERDDAP rtofs table stale vs live server (NEW, dev-phase-s
  scope-ack — fix inside Phase S round).
- SWAN 99-file BOUNDSPEC cap check at G-Accept (66 pre-G).
- Incident follow-ups 1–3 (see INCIDENT block).
- 3 pre-existing marine test failures + 1 flaky (see pre-flight facts).

## Agents at checkpoint
ALL DEAD/CLOSED: dev-w6 (closed, W6 done), dev-phase-g (closed), test-g8 (closed),
audit-gate-g (closed, 0 findings), inv-marine + inv-radar (investigation closed),
dev-phase-s (READ+SCOPE-ACK ONLY — no code ever written; re-dispatch fresh with the 3
resolutions from RESUME #2; its bounded-pin evidence is preserved above and in the plan).

## Decision log (session 3) — full text of rulings in the PLAN's decision log
- W6: scope-ack→code→accept full cycle; no-op-rotation reframing recorded; PROVIDER-
  MANUAL §14.14 incident note committed.
- G: two mid-round rulings (G4 angular-extent; G1 stale-test same-commit); G8 row-(c)
  strengthened to cross-commit literal pin; row-(e) deviation approved; Gate G closed.
- Incident: full arc recorded in plan; FQDN rule added to CLAUDE.md; router access
  DENIED (standing).
- Session ended at operator instruction after incident resolution + plan checkbox
  sync (operator caught W1–W5 and G rows unflipped — flip task rows AT gate close,
  not only the gate record, next time).
