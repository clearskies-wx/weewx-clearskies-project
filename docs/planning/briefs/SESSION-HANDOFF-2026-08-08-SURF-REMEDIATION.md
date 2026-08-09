# SESSION HANDOFF — Surf Remediation execution, 2026-08-08 (pre-compaction save)

**Read this FIRST after compaction, together with
`docs/planning/SURF-REMEDIATION-PLAN-2026-08-08.md` (the ACTIVE plan — every gate record,
ruling, and finding of this session is already written into it in full detail). This file
exists so the coordinator can answer the operator's pending-decision replies without
re-deriving anything.**

## Deployed state (all verified live this session)

| Repo | HEAD = deployed | What shipped today |
|---|---|---|
| marine (`repos/weewx-clearskies-marine`, runs on librewxr) | `b3f8092` (proc start 08:43:13Z) | `b503b4a` R1 cache codec fix → `3a16e1f` R1b pooled true-extremes min/max → `6aee246` R1b guard test → `1d012f6` R4 disk relocation → `fdf7afc` R2 Qb-only cessation + zone guards → `b3f8092` R2 audit-F1 zone scoping |
| meta (`c:\CODE\weather-belchertown`) | `245e47b` committed (deploy script R4 bootstrap+migration, manuals) | NOT yet pushed to its remote (meta pushes were never requested; local commit only) |
| dashboard / api | unchanged today (`43a8ceb` / `d6d6bc0`) | — |

**Gates PASSED (records in plan):** R1+R1b (surf range live: 73/73 hours non-null,
headline +1.2–1.6%, per-transect cross-check passed, dashboard API serves "2.50–3.06 ft");
R4 (tmpfs 3.9 GB → 28 MB, host available memory 1–1.5 → 3.9 GB, cycle FASTER on disk
31m57s vs 35m baseline, old `/run/weewx-clearskies/swan` tree DELETED; residual 28 MB
`swan-precleanup-20260726T083936Z` left, Round Z teardown scope).
**R2: deployed + live-verified except two open rows** — (1) the WEBCAM reality row
(first daylight low-tide hour: cam beside chart, outer break AND shorebreak both ways,
screenshot beside payload — operator's standard, FAIL either direction keeps round open);
(2) the D-R6 ruling below (zone display semantics). Evidence banked: 46/46 tests on
librewxr at b3f8092; blind audit verified core physics incl. the served combined path,
found+killed F1 (zone overlap, remediated `b3f8092`, auditor re-verified 3 ways);
first post-R2 cycle (08:47→09:17:53Z) serves cessation+re-breaks (outer plunging 116 m
at tide −0.835, staircase of re-breaks shoreward), headline stable 0.92–0.94 m.

## OPEN OPERATOR DECISIONS (the operator will answer these — full context so a one-word reply is actionable)

- **D-R5 — trace-swell floor for the range MIN** (plan, Gate R1+R1b block). Sunday
  2026-08-10T00Z serves min 0.21 / max 1.43 m = "0.7–4.7 ft" because a 0.18 m 22 s
  forerunner pools with the real 14.8 s swell. Options: (a) leave honest true min;
  **(b) RECOMMENDED: partition's faces pool only if its peak face ≥ 25% of pool max**
  (Sunday → "3.3–4.7 ft"); (c) min from dominant partition only. If ruled: small dev
  round in `surf_1d_pipeline.py` (both `_pooled_faces` sites, R1b blocks ~:2352-2408 and
  ~:3430-3499) + guard-test update + audit + deploy.
- **D-R6 — zone/break display source with multi-swell breaks** (plan, R2 live-accept
  block). Zone classifier + served breakPoints consume the INTERLEAVED both-swells break
  list → duplicate break pairs ~2 m apart (116/114 m), aggregate impact zone collapses to
  a 1 m sliver (break_points[1] is the OTHER swell's outer break), 12 markers served,
  INV-13 fired 240×/cycle on these degenerate pairs. Options: **(a) RECOMMENDED: zones +
  served break list from the DOMINANT partition only** (consistent with operator-ruled
  WC-D3 dominant-break chart filter); (b) cluster cross-partition breaks within a grid
  step; (c) leave as-is. Implementation site if (a): `endpoints/beach_profile.py` break
  collection + its `_classify_zones` call (~:736-747), and `endpoints/surf.py`
  `_break_points_for_representative_transect()` (:496-557). Needs a small ruled round.
- **Radar container restart timing** — memory now exists (3.9 GB available). Operator
  says when; restart command owner: ratbert LXD (`ssh ratbert` + lxc, or wherever
  `librewxr.main` radar container lives — VERIFY before acting, it was "stopped due to
  memory contention" per WC-D3 handoff).
- **INV-11 redesign item** (plan, Gate R4 event + audit F2, joined): pre-existing since
  Round X deploy 08-06, ~200k ERROR lines/day (08-07: 207,499), always
  `comparison_starved` (zone fragments with zero included closure steps); post-R2 rate
  −41% (19,923 → 11,768 per precompute window) but still huge, and the check is
  structurally blind exactly at cessation boundaries. Needs its own ruled task
  (rate-limit / severity / root-cause redesign). Recommendation deferred until operator
  asks; do NOT slip into another round.
- **Low-tide re-break staircase** (flagged, not a decision yet): at tide −0.8 the model
  serves ~5 tiny re-breaks (0.13–0.29 m faces in 0.2–0.4 m water) down the inner shelf.
  Physically arguable on a drained low-tide terrace; the webcam row judges. If cam says
  wrong: escalation order in the plan's R2 gate (bathymetry CLEARED by D-R4 → shoaling
  chain → Q_B_VISIBLE dial, operator-ruled only).

## Remaining plan work

- **R3 (fixed chart windows) — NOT STARTED.** Design in plan Phase R3 (rewritten for the
  operator's stepped-fixed-window semantics: preset ladder 150/300/500 m, per-spot
  assignment at establishment, landward 30 m; Huntington = 150 m RULED, "140" was
  operator typo, corrected in chat). Files: dashboard `BeachProfileChart.tsx` (delete
  `selectTier` :144-161 + tiers :315-317), marine `beach_profile.py` metadata + config
  keys, api types. Owner: clearskies-dashboard-dev + api-dev; gates as written.
- **Standing obligations** (plan records): compound-sea headline re-measurement (first
  hour with partitions within 3 s/45°/>50% energy — aud-F1 of R1b); flat-hour
  zero-qualifying live example; webcam row (above); R2 doc-sync deltas (ARCHITECTURE/
  PROVIDER-MANUAL/API-MANUAL rows in the plan's DOCUMENTATION table are still OPEN — R2
  code shipped without its doc rows; close them before calling R2's gate fully shut).

## Process facts the next context must not lose

- **Operator authorizations in force (recorded in plan decision log):** standing
  push/deploy grant ("permission to push/deploy, as coordinator, as necessary for
  testing"); "the plan itself serves as permission for architectural changes if they are
  spelled out in the plan"; NO AskUserQuestion tool ever (CLAUDE.md); plain-English
  reports (no technobabble — define terms).
- **Working pattern that operator endorsed via rules:** Sonnet agents with full briefs
  (mandatory git/architectural/stale-test blocks verbatim), scope-ack before code,
  tests-first with fail-pre-change transcripts captured on librewxr against deployed
  pre-change code, blind adversarial audit before lead gate, lead independently re-runs
  everything, one functional change per deploy, deploy via `scripts/deploy-marine.sh`
  FROM THE META REPO ROOT (ran it from marine repo twice by mistake — push succeeds,
  deploy silently doesn't run).
- **librewxr access:** `ssh -F .local/ssh/config librewxr`; journal needs sudo; secret:
  `sudo grep ^MARINE_SERVICE_SECRET= /etc/weewx-clearskies/marine/secrets.env|cut -d= -f2`;
  endpoints `https://127.0.0.1:8780/surf/huntington-city-beach-pier[/profile]` (Bearer);
  tests: `sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-marine && .venv/bin/python -m pytest <files> -q'`;
  never run pytest during a SWAN cycle (`pgrep -x swan`); "pgrep -x swan idle" does NOT
  mean the python service isn't mid-cycle — check journal for "SWAN: starting" without
  "full SWAN cycle complete".
- **SWAN work root is now `/var/lib/weewx-clearskies/swan`** (constant `SWAN_WORK_ROOT`
  in `services/swan_paths.py`, env override `CLEARSKIES_SWAN_WORK_ROOT`).
  `/var/run/weewx-clearskies` survives ONLY for the API loop.sock — never remove.
- **Known journal noise classes (pre-existing, don't count as new in sweeps):** HRRR
  4xx 404 not-yet-posted spam; NDBC QuotaExhausted tracebacks; INV-11 comparison_starved;
  1.5·γ·d runaway WARNING on the terrace at ~7.5 m.
- **Audit-day context:** this entire session was the same-day execution of the plan
  born from the morning's six-issue audit (WC-D3 handoff). Issues 2/3 were tide-hour
  comparison artifacts (endpoints agree; bathymetry shelf REAL per Scripps HB06 surveys
  — surf-zone width 88–122 m brackets the model's ~90 m outer break); Issue 1 was the
  cache codec (fixed); Issues 4/5 the unreachable cessation (fixed); Issue 6 the
  data-driven axis (R3 pending); memory the tmpfs (fixed).

## Immediate next actions when resuming

1. Whatever the operator just answered (D-R5 / D-R6 / radar / INV-11 / webcam verdict):
   the full option text is above — dispatch the corresponding small ruled round with the
   standard brief pattern.
2. Close R2's doc-sync rows (doc deltas table) — overdue, code is deployed.
3. Then R3 build.
4. Webcam row at first daylight low tide (operator supplies the screenshot or asks for
   the comparison; ~15:00–17:00Z is afternoon PDT daylight; low tide hour from
   tidePredictions in the surf payload).
