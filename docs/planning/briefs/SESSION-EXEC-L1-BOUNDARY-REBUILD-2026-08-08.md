# SESSION SCRATCH / HANDOFF — L1-BOUNDARY-REBUILD-PLAN execution (2026-08-08 → 09)

**Read FIRST when resuming, with `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md`
(the plan — the 📍 CURRENT STATE table at its top, all phase markers, gate records,
decision log, and the G9-GL ruling block are current as of session-5 close) and
`docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` (authority).**

## ⏭ RESUME HERE — session 6 (written Sun 2026-08-09 ~5:15 PM PDT, session-5 close)

**Operator's closing instruction: "get the REST OF THE PLAN DONE."** That is the
session-6 mandate — execute every remaining item below, in order, under the standing
authorizations. The session-5 C3 coding freeze converts to EXECUTE-AS-RECORDED: the
operator's direction for C3 is complete and in the plan; build exactly that.

**Remaining work, in dispatch order (all briefs/designs already exist — do not
redesign):**

0. **Pre-flight:** marine repo HEAD must be `462b38f` clean; dashboard `8fff329`
   clean; meta pushed through session-5 close. Health:
   `ssh -F .local/ssh/config librewxr "curl -sk https://127.0.0.1:8780/health"` —
   status degraded ONLY by INV-11. FQDNs always. All session-5 agents/monitors are
   dead — nothing is in flight.
1. **Close the S2 accept (no coding — evidence + one investigation).** Evidence
   already collected session 5 (record it in the plan's S-Accept block): STOFS ran as
   PRIMARY on the live cycle — journal 22:09:03Z "73 hourly water-level grid(s)...
   spatially-varying WLEVEL primary (P8 chain)", WLEVEL.txt written spatially-varying
   on ALL FOUR grids (91×100 / 75×82 / 51×46 / 49×169, 67 timesteps each), cycle
   published normally, no OOM. **OPEN ITEM blocking the accept row: the service
   process peaked ~2,973 MB during that cycle** (vs ~1.35 GB idle measured later).
   READ-ONLY investigation first: is the ~1.6 GB cycle delta attributable to S2's
   fetch path (it should be ~0.5 MB retained + transient decode) or pre-existing
   cycle behavior? Compare: sample service RSS through one full cycle while grepping
   which stage the peak lands in; check whether the pre-S2 deploys showed the same
   (no baseline exists — the honest method is stage-attribution on the live cycle).
   If S2's path holds full-grid buffers longer than one message decode, that is a
   defect → fix round (subset earlier / free sooner). If pre-existing, park it with
   evidence and close the accept.
2. **Gate S blind audit — wlevel half** (`clearskies-auditor`, adversarial, per plan
   §Gate S rows minus the currents rows): containment/bias-gate numbers recomputed
   from raw fetches, no-silent-fallback greps, mutation drill on a cut STOFS URL,
   Hawaii NAVD88 refusal, §14.13a doc-sync landed. Auditor sees design + expected
   numbers ONLY (never implementer work product).
3. **S1 + S4a — currents ladder round** (marine repo; briefs exist: plan §S1 as
   RE-AMENDED + §S4 rows a/c-g as re-respecified). HARD EDGES: NO RTOFS anywhere —
   ladder = regional OFS (containment) → STOFS-3D-Atl (East/Gulf/PR; velocity netCDF
   pinned from NCO inventory with one live shape check) → PacIOOS ROMS Hawaii
   (`roms_hiig`, ERDDAP) → **exhausted = REFUSE** (`CurrentCoverageError` →
   `currents_fetch_failed`, message names bbox + declined rungs). No summing;
   per-cycle selection; output shape identical to `fetch_surface_currents` so
   `_write_current_txt` is untouched. Scope-ack MANDATORY and ENFORCED (a session-5
   dev skipped it — do not let that repeat). Then S1+S4a single-change deploy +
   S-Accept currents rows (HB stays on WCOFS — selection INFO line; smoke the other
   rungs config-time from librewxr incl. the refusal on an uncovered bbox).
4. **V3 evidence collection (can start immediately, parallel):** 5 consecutive
   NORMAL cycles on the capped box — wall-clock ≤45 min hard/≤40 target, SWAN peak
   RSS ≤ **400 MB** (operator raised from 300, session 5), boundary volume + read
   time in B-Accept envelope. Watcher hygiene: absolute `-F` ssh-config path
   (a session-5 monitor died silently on a relative path), test pattern first,
   bounded timeout.
5. **Phase A** (A1 marine `/config` source report; A2 admin panel + L1-override
   field + help keys) per plan §A1/§A2; Gate A.
6. **Phase C remainder:** C1 (server aggregates + card; plan §C1 design is decided —
   eligibility rule, min/max heights, energy-weighted period, additive fields only)
   — its server half is marine-repo `endpoints/surf.py`, so it queues behind S1's
   round on that repo. **C3 REDO per the recorded requirements** (plan §C3, binding):
   ONE physically-correct ground→chart transform from the transects' REAL
   coordinates driving heatmap rows, BOTH axes (y in alongshore DISTANCE, not
   indices), imagery placement, and the 50 m ground-distance buffer; acceptance
   verified against GROUND TRUTH (pier's real coordinates project onto its rendered
   pixels; transect 0 south of the pier; beach in frame; a known ground distance —
   the pier's ~500 m — measures true on both scales). Never validate the chart
   against its own arithmetic. If the dashboard payload lacks real per-transect
   coordinates, STOP and surface (API gap). Then Gate C (both cards, screenshots in
   gate record).
7. **Phase V close:** V1/V2 (swell-event reality rows — need matching weather; may
   remain open), V3 (from item 4), V4 blind auditor walk of all gate evidence. Plan
   closes when V1–V4 recorded.

**NOT part of this plan's remaining work:** the Great Lakes implementation. The GL
rulings are RECORDED (plan §G9-GL + decision log: D-GL-1 no lake L1, boundary feeds
L2; D-GL-2 boundary product chosen by ACCURACY, pinned by live comparison at
implementation; D-GL-3 L2 outer edge = 30 m contour OR deepest-locally-available).
Implementation is a separate future operator-ordered round; the work-list is
`briefs/G9-GL-RESEARCH-REDO-2026-08-09.md` §Q4's dependency list.

## Session-5 outcomes (evidence in the plan's decision log + section records)
- S2/S3 code round re-run from scratch and closed (`5d9d88b`/`9cbb915`); S4b closed
  (32 KATs, `e9ef833..c5e9383`).
- G9 coded (`353c34e` + membership-fix `91b6e2d`), tested
  (5 KATs `3065289` incl. east-facing pin), deployed; **the lead gate caught a real
  defect** (positional `_offshore_sides` unpacking — would have moved the coast edge
  on east-facing coasts).
- **INCIDENT:** first deploy (`3065289`, G9+S2 two-change) OOM-crash-looped — S2's
  fetcher held 73 full-region grids as nested Python lists (~7 GB). Rolled back same
  session (`439aa7c`, surgical: S2 + its 3 test commits only). **S2 re-landed
  memory-safe** (`462b38f`: subset-at-extraction + float32, ~0.5 MB retained, memory
  KAT mutation-proven) and deployed single-change. Bias gate PASS −0.044 m (25 pairs
  vs CO-OPS 9410660) — carries forward, do NOT re-run.
- **G9 verified live on the capped box:** 93×101 cells / 9,393; lat 33.1797..34.0806
  (N-S = 100.0 km exactly at cap; S edge north of SCI 33.03; Catalina 33.30 inside);
  lon −118.7598..−117.7725 (E-W 91.3 km unchanged); boundary 194 points (S=93,
  W=101); G7 guard cleared state + forced full run; reality gate PASS (combined deep
  Hs 0.64 m vs buoys 0.8/0.9 = −20/−23% inside ±25%; shadow retained 0.35 m @259°);
  journal sweep clean (the high-volume L4-clamp WARNING proven PRE-EXISTING: 5,670
  hits in the pre-deploy window). Cold-start cycle 48m40s (cold caveat; steady-state
  = V3's job). SWAN peak RSS measured for the first time: 335 MB.
- **Phase G CLOSED** (operator raised the RSS budget to 400 MB; V3 row updated).
- C2 accept PASSED (partition-0-only train, card-consistent). **C3 accept REVOKED by
  operator screenshot review** (ortho misplaced/no beach; y-axis must be DISTANCE;
  buffer void) — two prior rounds fixed symptoms inside a broken frame; requirements +
  ground-truth acceptance now recorded in plan §C3; the one surviving row is
  overlay-removal.
- **Operator rulings session 5:** RTOFS-alone rung REMOVED from the S1 ladder
  (exhausted = REFUSE — "missing information... garbage data"); RSS budget 300→400;
  GL architecture ruled (D-GL-1/2/3 above) after a research redo on the operator's
  depth-envelope reframe (first research rejected as wrong-question).
- Repos: marine pushed through `462b38f`; dashboard through `8fff329` (deployed to
  weather-dev); meta pushed through session close.

## Authorizations + prohibitions in force
- "As coordinator, you have permission to push/deploy as needed." (exercised
  repeatedly session 5). **Push the meta repo at EVERY checkpoint** — batching it to
  session end made progress invisible to the operator (session-5 failure).
- "Architectural changes called for within the plan are pre-approved" (register
  P1–P15 as amended; outside it → STOP and ask). The GL rulings + RTOFS removal +
  C3 redesign are operator-ruled.
- "Work through the entire plan and only stop if there are architectural issues not
  foreseen in the plan." + the closing mandate above.
- Q5-class data-source research is the COORDINATOR'S job, not an operator question.
- ⛔ ROUTER ACCESS: PERMISSION DENIED (standing). FQDNs, never raw IPv4.
- Standing: no AskUserQuestion; plain English (define every term); NO full pytest
  suite ever; scratch files maintained.
- **NEVER present an unverified diagnosis to the operator as fact** — session 5's
  worst moment was explaining invisible progress with an unchecked guess ("not
  pushed") when the operator reads LOCAL files. Ask what they're looking at.
- **Operator-facing times in PDT** (server logs are UTC — convert; "tonight" at
  3 PM local reads as a bot that doesn't know what time it is).
- **No "fallbacks" that substitute missing physics for real data** (the RTOFS
  lesson): a source that lacks required content is not a fallback, it is garbage
  data — refuse loudly instead. Generalize this instinct.
- **Status markers update at the moment state changes** — plan section headings,
  the 📍 CURRENT STATE table, and this file must never disagree (operator caught
  hours-stale headings twice in session 5).

## Live facts (verified at session-5 close)
- librewxr: marine `462b38f` (proc 22:04:28Z), capped L1 live and publishing; STOFS
  wlevel primary; S3 present-but-inert (Hawaii-gated). Idle service RSS ~1.35 GB;
  cycle peak ~2.97 GB observed once (OPEN question, item 1 above).
- Budgets: cycle ≤45 min hard; SWAN peak RSS ≤400 MB (`omp_num_threads=6` is an
  operator ruling — do not touch).
- Marine pytest baseline at `462b38f`: selection `tests/test_island_autosizing.py
  tests/services/ tests/test_coops_fetch_datums.py tests/test_stofs_wlevel_provider.py
  tests/test_swan_wlevel_chain_fallback.py` = **249 pass / 3 tracked pre-existing
  fail** (double-listing tests/services files inflates counts — dedupe: never list a
  file AND its parent dir). The 3: test_double_break_transect55_kat wave_reforms,
  test_wind_gatherer cold-start reconcile, test_wind_timeline_store round-trip.
- Dashboard vitest (HeatMapCard) 46/46 at `8fff329` — will churn in the C3 redo
  (stale-test rule: the footprint-model tests get REPLACED in the same commit).
- Config re-push mechanic + deploy script: unchanged (see plan G-Accept record;
  `scripts/deploy-marine.sh` from meta root; sizing chain ~3 min background — do NOT
  re-push config while a cycle is mid-WW3-fetch: the chain's smoke test shares the
  NOMADS rate limiter and aborts cleanly but wastes a cycle wait; session-5 hit
  this — wait for `run_in_progress:false` first).
- Known journal noise (unchanged): INV-11 only /health reason; NDBC QuotaExhausted;
  L4-clamp/SUBSTITUTION classes pre-existing; check_mk spam; HRRR Lambert WARNING
  gone (reappearance = regression).

## Parking lot (carried)
- **Service cycle-RSS ~3 GB attribution** (item 1 above — blocks S2 accept row).
- Heatmap streak rows + white gap band near southern transects (recorded at C3
  evidence; may be model-side, look after C3 redo).
- coastwatch ERDDAP rtofs datasets gone → water-temp chain deep fallback silently
  dead (§14.11 flag) — own fix round.
- Dashboard bundle per-chunk methodology ruling (open); BeachProfileCardBody D6 2
  pre-existing fails; orphaned `shadowedTransect` i18n key; openapi SurfForecast
  drift (own doc-sync round).
- Incident follow-ups 1–3 (DHCP/networkd monitoring; check_mk spam; SWAN stdin FD
  leak swan_runner.py:5474 + surfbeat_runner.py:531).
- 3 pre-existing marine test failures + 1 flaky; smart-L3 viability at HB (~229 m
  short, coarse-nest fallback) — known disposition item.

## Agents at session-5 close
All dead (dev-phase-s, test-s4b, dev-g9, test-g9, dev-s2-reland, dev-c3-fix,
dev-c3-geo [recalled before any code], c23-evidence, research-gl-*). All monitors
dead. Nothing in flight; repos clean at the HEADs above.

## Process lessons this session (already applied above, listed for the record)
1. Two-change deploys: the OOM incident vindicated one-change-per-deploy —
   attribution was fast ONLY because the changes' journal signatures were disjoint.
2. Resource-scale blind spot: KATs on tiny fixtures + a big-RAM workstation bias
   gate cannot see a 7 GB production footprint — production-shaped memory KATs are
   now mandatory for data fetchers (S2 re-land has the pattern).
3. Acceptance must compare against GROUND TRUTH, not the artifact's own arithmetic
   (C3 revocation; rules/verification.md "validate against reality" applies to UI
   geometry too).
4. Watchers: absolute paths, validated patterns, bounded timeouts (one silent
   monitor + one 8-test-count confusion this session).
5. Scope-ack is not optional — one dev skipped it and only the acceptance gate
   caught the risk after the fact; enforce before any code.
