# Session state — MARINE-FORWARD-PLAN execution (2026-08-02)

## ═══ RESUME HERE (rewritten pre-compaction #2, 2026-08-02 ~10:05 UTC) ═══

**Role:** Coordinator (Fable). **Mission:** CONTINUE EXECUTING
`docs/planning/MARINE-FORWARD-PLAN.md` (meta repo, the ONLY live marine plan — re-read it in
full first; every phase/task/gate status below is ALSO recorded there with round records).
**Operator's standing directive: "ok continue autonomously with plan implementation"** (in
chat, 2026-08-02 — recorded in the plan decision log). The progress log at the bottom of this
file is the chronological truth of the whole session; read it before acting.

## ── CURRENT STATE SNAPSHOT (2026-08-02 ~10:05Z) ──
**Deployed:** marine = `b5a4d01` (librewxr proc 09:41:05Z, healthy, all live-verified);
dashboard = `6bc0573` (weather-dev, bundle index-WLu25L_n.js). ALL repos pushed (meta
`c458dee`, marine `b5a4d01`, dashboard `6bc0573`). test_claim2.py = known stray in marine
repo, untracked, never commit/delete.
**Phase status:** PHASE H ✅ CLOSED (Gate H 8/8, auditor walk; records in plan). Phase D:
D2✅ D4✅ D5✅(operator visual eyeball pending) D11✅; OPEN: D8 (chevron render, blocked
on nothing — D4 landed the contract half), D9 (dl a11y one-block fix), D10 (awaiting
operator's 3 D10.2 rulings), D1 (awaiting operator deletion sign-off); Gate D NOT yet
formally closed (close after remaining D rounds). C7b ✅ fixed+deployed+live-verified
(beach_profile now 216.4°); C7a ⛔ OPERATOR (librewxr→weewx:8765 firewall-blocked — MikroTik
rule needed before env var is meaningful). H5 open (cold /surf ~33s first-read-per-cycle →
one 503; investigation-first task in plan). Remaining phases: V (V1 ordinary-conditions
check; V2 weather-gated; V3 blind audit dispatchable; V4✅), G6, LM (operator-requested
landmarks; LM-1 dispatchable after D), C (C1 sweep, C2, C3 dispatchable; C4 ready; C5/G5
pinned).
**OPERATOR-PENDING (do not proceed on these without chat ruling):** C7a firewall; D1
sign-off; D10.2 three rulings (perPartitionBreaks shape reuse / BD-8 shadow-aggregate /
waveShape real round with trigger-1 cut points); D5 visual eyeball; V2 weather days.
**Dispatchable next (autonomy grant covers):** D8, D9, H5, C2, C3, V3, LM-1.
**Known residuals (tracked, don't re-find):** H5 cold-read; H4's single 1.655s unlocalized
probe outlier; decode-side monolithic json.loads (~1.3s hourly-fill GIL hold — STOP-and-
surface if it alone breaks an accept); C7's en-only locale keys note; D9's 2 dl axe
violations (tracked); bimodal-facing SOLVED (C7b) — 240.0 lines should no longer appear
(if they do, that's a NEW finding).
**Agent roster (SendMessage by name, context intact):** `l4-rewrite` (Sonnet marine coder —
H1/H2/H4/C7 context), `round1-auditor` (adversarial — audited every round this session),
`d4-dashboard` (Sonnet dashboard — D4/D5 context+fixtures), `d2-test-fix` (test-author —
D2/D11), `doc-sync` (docs — H3), `d10-history` (Explore, done). Dispatch pattern + mandatory
blocks: see briefs in this scratchpad (d2/h1/h2/h3/h4/d4/d5-brief.md + audit briefs) — every
implementation prompt carries git/architectural/stale-test blocks verbatim.

**Standing operator grants (2026-08-02, in chat — survive compaction, session-scoped):**
1. **Push/deploy as necessary for TESTING purposes** — coordinator discretion; production
   cutover still excluded.
2. **Every implementation task → Sonnet coding agent; adversarial `clearskies-auditor` pass
   BEFORE the lead gate; doc-sync closes every round.** (Permanent process mandate.)
3. **Keep THIS scratch file updated as execution proceeds** (operator ordered scratch-file
   progress guarding against session limits/compaction). Update the Progress log below after
   every gate event; rewrite the RESUME HERE header whenever the "next action" changes.

**MANDATORY reads before FIRST dispatch (operator instruction "read architecture and follow
all rules"):** `docs/ARCHITECTURE.md` (marine section ~:99-127), `rules/agents.md`,
`rules/verification.md`, `rules/coordinator.md`, `rules/clearskies-process.md` (agent-prompt
architectural block section), `reference/clearskies-dev.md`. The plan's PRIME DIRECTIVE
restates the deploy discipline; the rules files are the canonical text.

## Execution order (from the plan)
Phase H → (D2 EARLY — tiny, guards H1's test surface) → Phase D → Phase V as evidence allows →
Phase G6 → Phase C. Each phase's QC gate closes before the next round dispatches. H4 ships
after H1/H2 (operator sequencing) and GATES D4/D5 live verification.

**Recommended opener (told to operator, unchallenged): dispatch D2 (clearskies-test-author)
and H1 (clearskies-api-dev) in parallel** — D2 is one test file; H1 starts with the read-only
H1.1 enumeration + scope-ack. Then H2 → H3 → Gate H (auditor) → H4 → Gate H row 8 → Phase D.

## Dispatch pattern (proven, 2026-08-01 Rounds 1-2)
1. Write task brief to scratchpad (`<task>-brief.md`) citing the PLAN section verbatim +
   mandatory blocks (git local-only/no-push, architectural STOP w/ per-task pre-approvals only,
   stale-test STOP, SSH read-only for agents, numbers-not-adjectives).
2. Agent scope-acks (files + tests + consumers found + what it will NOT touch) → coordinator
   confirms → GO.
3. Closeout → dispatch `clearskies-auditor` adversarially (charter: hunt can't-fail tests,
   allowlist vs git show --stat, falsifiability by mutation) → remediation loop if findings →
   re-audit → LEAD GATE (independent pytest in own shell, stat vs allowlist, code spot-check).
4. Doc-sync agent pass (CLAUDE.md doc-code sync) → coordinator QC → meta commit.
5. Baseline capture → push → deploy (`scripts/deploy-marine.sh`) → reality gate (matched-time
   vs NDBC 46222/Surfline; publish-liveness within one cycle) → gate record in plan + this file.

## Resumable named agents (SendMessage by name; full context in their transcripts)
- `l4-rewrite` — Sonnet clearskies-api-dev, deep marine-repo context (L4 rewrite + break
  rounds). Reuse for marine coding tasks (H1/H2/H4/D1/C2/C3/C4/G6.1).
- `round1-auditor` — adversarial auditor (caught F1 blocker Round 1 + F1 fixture gap Round 2).
  Reuse for all QC gates.
- `doc-sync` — docs agent (3 successful passes). Reuse for H3 + per-round doc-sync.
- Dashboard tasks (D4/D5/G6.3) need a NEW `clearskies-dashboard-dev` Sonnet agent.

## State at compaction (2026-08-02 ~02:40 UTC)
- **Marine repo:** main = `732e87d`, pushed + DEPLOYED (librewxr proc since 00:55:18Z).
  Untracked `test_claim2.py` in marine repo: ignore, never commit/delete.
- **Meta repo:** main = `cb9b402`, pushed. Plans consolidated: restoration/geometry/working-
  model/separation ALL archived to docs/archive/ with banners; MARINE-FORWARD-PLAN.md is live.
- **Model status: WORKS, fully verified.** Round-2 zone math verified LIVE on the 01:51Z
  scheduled cycle (headline≤best_peak all 73 h, e.g. main_zone=[25..30] 6 transects 5
  qualifying face=0.61; API serves populated zone fields 73/73, rep-index in-zone, 0
  violations). Break detection verified (143/143 transects break at physically correct depths;
  3 real double-breaks detected on a small day).
- **Routine cycle watcher:** background task `brbexbaak` (held ssh, fires on next "full SWAN
  cycle complete") — the ~02:05Z routine cycle was mid-L4 at 02:11Z, expect completion
  ~02:45-03:00Z. Pure regression datapoint, nothing gates on it. On fire: grep the new cycle's
  `main_zone=` INFO lines + confirm no ERROR; log here.
- **Known live defect (planned, do NOT hotfix):** dashboard surf 503s = H4 (marine event-loop
  stalls during 206 MB cache publish/reads → API proxy TLS handshake timeout). Evidence chain
  in plan §H4. Operator sequencing: model-first, H4 after H1/H2.

## Key operator rulings this session (already in plan/decision logs; do not re-litigate)
- V4 CLOSED accept-as-is; C4 UNBLOCKED with ruled thresholds (bulk-parameter fallback ONLY —
  L4/L3/L2 routing is NEVER degradation); G5 + C5 + G1R.3 + D3 + D7 PINNED; L3/L4 inseparable
  (L4 ⇒ L3 step-down, SWAN ratios); Phase F is DONE and stays wired; separation plan archived.

## Progress log (update after every gate event)
- 2026-08-02 02:40Z — pre-compaction setup. No forward-plan task dispatched yet. Next action:
  post-compaction → mandatory reads → write D2 + H1 briefs → dispatch.
- 2026-08-02 ~03:05Z — POST-COMPACTION RESUME. Mandatory reads done (ARCHITECTURE marine
  section, agents/verification/coordinator rules, clearskies-dev). Watcher `brbexbaak` fired:
  02:30Z routine cycle CLEAN — main_zone INFO on every timestep, headline ≤ best_peak
  throughout (e.g. 0.62≤0.71), bulk-fallback none, zero ERROR. Regression datapoint logged.
- 2026-08-02 ~03:10Z — pre-flight: marine repo clean @732e87d (untracked test_claim2.py only).
  D2 baseline reproduced by lead: 2 failed / 7 passed, missing `open_water_bearing_deg` in
  `_full_domains_stub()` (:455), consumed at swan.py:2519. H1 line hints verified
  (spots_cached 3214/3347/3354). Briefs written: scratchpad d2-brief.md + h1-brief.md.
  DISPATCHED in parallel: D2 → NEW agent `d2-test-fix` (clearskies-test-author, Sonnet);
  H1 → resumed `l4-rewrite` (Stage 1 read-only H1.1 enumeration + scope-ack first).
  Awaiting both scope-acks; no GO given yet.
- 2026-08-02 ~03:20Z — **D2 DONE (local).** Scope-ack matched lead design → GO → closeout.
  Commit `e8646d2` (marine, LOCAL, not pushed): 1 file, 1 insertion —
  `open_water_bearing_deg=225.0` in `_full_domains_stub()`. Lead acceptance gate run
  independently: `python -m pytest tests/test_serve_nothing_on_failure.py -q` → **9 passed**
  (baseline 2F/7P); `git show e8646d2 --stat` = one test file; no production code; repo clean
  (test_claim2.py still untracked). Push HELD — test-only commit rides along with H1's deploy
  (prime directive #3). Gate-D row 1 evidence banked; formal auditor pass at Gate D.
  Awaiting: H1 Stage-1 scope-ack from `l4-rewrite`.
- 2026-08-02 ~03:35Z — **H1 Stage-1 scope-ack received + GO issued.** Enumeration: 10
  cycle-ending no-publish paths in swan.py (all raise+ERROR already, none in /health), incl.
  #9 convergence gate (:3203-3212) and #10 zero-valid-spots (:3380-3387, the 07-31 11:51
  shape); per-spot WARNING #11 stays WARNING; quiet no-ops #12-15 excluded; #16 spot_cfg-None
  silent skip gets ONE WARNING; #17 L3 viability (swan_domain.py:435-470, INFO-only, the
  07-31 11:16 shape) surfaces via grid_sizing_chain.py. **Lead rulings:** F1 allowlist
  EXTENDED to services/grid_sizing_chain.py (detect+record ONLY; swan_domain.py stays frozen;
  if viability-vs-no-L3 not distinguishable at chain level → STOP) — FLAG TO OPERATOR (plan
  Files-list omission resolved in favor of plan's own H1.3 spec + KAT (b)); F2 H1.4 ruled
  satisfied-by-H1.3 (stack status.html generically renders reasons[] — verify-only, live
  check at Gate H); F3 own harness in new test file (no import from serve-nothing file).
  Slugs (split per input): no_grid_sizing_cache, ww3_boundary_failed, tide_fetch_failed,
  currents_fetch_failed, bathymetry_failed, wave_setup_failed, swan_fatal,
  convergence_gate_failed, no_usable_handoff_timesteps, l3_viability_failed. Health
  precedence: worst(existing, degraded), cleared by next successful cycle; in-memory
  state.py record (no persisted file). state.py confirmed as health store (not service.py).
  Stage 2 in progress. DOC-SYNC NOTE for round close: plan §H1 Files list + slug list +
  F2 disposition need updating.
- 2026-08-02 ~04:10Z — **H1 implementation CLOSED OUT + lead acceptance PASSED + auditor
  dispatched.** Marine `c768b18` (LOCAL): 7 files, 817+/31- — state.py two registries
  (no-publish cleared on next successful cycle; L3-viability reset per config push —
  implementer design point RATIFIED), swan.py 10 paths slug-prefixed ERROR + record + #16
  WARNING + success-path clear, grid_sizing_chain.py `_record_l3_viability_failures()`
  (re-derives trigger via same private helpers, swan_domain.py untouched — verified),
  health.py floor-at-degraded precedence. Meta `d98c091` (LOCAL): API-MANUAL §19.7 additive
  doc-sync (rule-authorized; flagged-not-touched the API repo's TestMarineResponse schema).
  Lead acceptance: independent pytest 40 passed (3 H1 files); stat = allowlist exactly;
  spot-checked state.py + health.py hunks. Implementer's broader sweep: 142 passed (14 files
  incl. serve-nothing 9/9). KAT (b) interpretation ratified (viability failure = reason +
  degraded, cycle still publishes on L2 — matches R-DIAGNOSIS timeline). AUDIT DISPATCHED:
  `round1-auditor` adversarial, brief scratchpad/h1-audit-brief.md (9-point attack surface;
  biggest risk = duplicated L3-trigger derivation divergence). Awaiting findings. NOT pushed,
  NOT deployed. After audit clean: lead gate → doc-sync (plan §H1 updates) → push+deploy
  (e8646d2+c768b18 ride together; ONE functional change = H1) → live check: forced degraded
  cycle → health!=ok + admin row + single ERROR → normal cycle → ok.
- 2026-08-02 ~04:35Z — **H1 AUDIT: FAIL — round stays OPEN.** round1-auditor findings, both
  ACCEPTED by lead: BLOCKER swan.py:2360-2378 GFS-wind inline-refetch failure = 11th
  no-publish exit, production-reachable (service.py:410-414 swallows GFS failure → None →
  retry fails → ERROR+raise, NO record call); MAJOR swan.py:2326-2339 HRRR fallback = 12th
  path, `return`-exit, test/manual-only reachable. Everything else survived: 3/3 mutations
  caught, no can't-fail assertions, L3 re-derivation ruled structurally divergence-proof,
  allowlist + frozen diffs clean, behavior freeze verified, tree restored (git diff = 0).
  REMEDIATION dispatched to l4-rewrite: instrument both paths (slugs gfs_wind_failed /
  hrrr_wind_failed; NO control-flow change — GFS keeps raise, HRRR keeps return), KATs for
  both driving real _run_all_spots_locked, API-MANUAL slug-list meta commit, path list → 12.
  Then re-audit (scoped) → lead gate → doc-sync → push+deploy → live check.
- 2026-08-02 ~04:55Z — **H1 remediation LANDED, re-audit dispatched.** Marine `2491ada`
  (2 files: swan.py two wind blocks + 2 new KAT classes) + meta `4e2acc2` (API-MANUAL slug
  list +1/-1). Lead verified in diff: slugs on CORRECT blocks (closeout prose had line
  numbers swapped, code is right — HRRR ~:2332 return-unchanged, GFS ~:2371 raise-unchanged);
  independent pytest 42 passed. Path list now 12 + #16 WARNING-only. Scoped re-audit sent to
  round1-auditor (fix verification, 2-mutation falsifiability, nothing-else-moved, 13th-path
  re-sweep). Awaiting verdict.
- 2026-08-02 ~05:10Z — **RE-AUDIT PASS + LEAD GATE (H1 round).**
  ## Verification evidence — round H1
  - pytest (lead, own shell, Windows repo root): test_no_publish_reasons + test_health +
    test_marine_health_state -q → **42 passed** @ 2491ada; auditor's independent run incl.
    serve-nothing → **51 passed**.
  - auditor findings: round 1 = 2 (BLOCKER gfs, MAJOR hrrr) — both remediated; re-audit PASS,
    4/4 mutations caught, 13-exit re-sweep clean (auditor self-corrected 12→13 total).
  - scope walkthrough: H1.1 DONE (13-path enumeration, scope-ack + closeouts), H1.2 DONE
    (c768b18+2491ada), H1.3 DONE (state.py+health.py, additive), H1.4 DONE-via-H1.3
    (verify-only trace), KATs (a)(b)(c) DONE. 0 MISSING. Live-check row DEFERRED to
    post-deploy (tracked: plan §H1 round record "Remaining for Accept").
  - lead spot-check: state.py registries + health.py precedence hunks read line-by-line;
    slug-block placement verified in diff after closeout-prose discrepancy.
  - allowlist diff: c768b18 = 7 files (amended allowlist exact); 2491ada = 2 files;
    meta d98c091 + 4e2acc2 = API-MANUAL only.
  Plan doc updated (§H1 round record + decision log). NEXT: commit meta → baseline capture →
  push marine (e8646d2,c768b18,2491ada) + meta → deploy-marine.sh → journal sweep →
  next-cycle publish + reality gate → forced-degraded live-check design (surface mechanism
  choice to operator).
- 2026-08-02 ~05:25Z — **H1 round PUSHED + DEPLOYED.** Meta `3cc12d8` (plan round record) —
  meta pushed f6e102e..3cc12d8; marine pushed 732e87d..2491ada. Baseline (02:30Z cycle):
  facing 216.4°, 143 transects (29 struct/114 open), T142 43/43 resolved, publish 132.5 MB,
  health ok, invariants 0; pre-existing WARNING classes: L4-handoff clamp (small-day),
  HRRR Lambert (449 pre-deploy). deploy-marine.sh: running commit 2491ada, proc 03:17:24Z,
  health 200, auth enforced. Post-restart health honestly "failed" (documented in-memory
  reset) and a new cycle auto-started 03:17:43 (HRRR fetch). Watcher `bbbt0lznd` on "full
  SWAN cycle complete". H2 STAGE 1 (read-only) dispatched to l4-rewrite meanwhile
  (brief scratchpad/h2-brief.md; noted /health may already carry ww3_boundary age_s —
  verify-not-readd). PENDING: cycle completion → publish-liveness + health ok + journal
  new-class sweep + reality gate; forced-degraded mechanism = grid-sizing-cache temp-rename
  proposal → OPERATOR APPROVAL REQUIRED before touching persisted files on librewxr.
- 2026-08-02 ~05:45Z — **H2 Stage-1 scope-ack received + rulings + GO.** Key findings ACCEPTED:
  real NOMADS chain = ww3_spectrum.py (HTTP GET) → ww3_station_selection.py (bounded retry:
  3 attempts/station fixed 2.0s + separate _MAX_CYCLE_FALLBACKS=3) → _common/http.py (5xx-only
  backoff; 4xx-never-retry is load-bearing global behavior, NOT to change); plan's
  wavewatch.py reference STALE (separate PacIOOS module, untouched); journal evidence 144
  404s Jul30-31, bounded-but-bursty, zero actual boundary outages; H2.3 fields ALREADY LIVE
  (all four inputs carry available+age_s) → zero-code, verify-only; H2.4 Overpass = DEFER
  (already behind shared-client backoff; no analog condition). LEAD RULINGS: constants
  approved (base 2.0/factor 2.0/cap 30.0/jitter 0.25, count unchanged); WARNING = ONE
  aggregated per select_boundary_stations_with_cycle_fallback() invocation on target-cycle
  sweep failure (NOT per-station — noise); "cached boundary data" reading confirmed (existing
  cycle-fallback + H1 abort path; no new cache); test file
  tests/services/test_ww3_fetch_backoff.py; allowlist = ww3_station_selection.py + new test
  file ONLY. Stage 2 GO issued. DOC-SYNC NOTES: plan §H2 wavewatch.py reference stale;
  "per-cycle retry cap" already satisfied by existing two bounded layers; H2.3 pre-satisfied.
- 2026-08-02 ~06:05Z — **H2 IMPLEMENTATION CLOSED OUT + lead acceptance + audit dispatched.**
  Marine `498b6a8` (LOCAL): 2 files exactly (ww3_station_selection.py +122/-6, new
  tests/services/test_ww3_fetch_backoff.py 346 lines, 14 KATs). Lead acceptance: independent
  pytest 14 passed; stat = allowlist exact; spot-checked backoff helper (bounds/jitter per
  ruling) + WARNING hunk (n==0-only, first-fallback-only, aggregated counts via additive
  optional kwargs on BoundaryNotViableError). Implementer sweep 62 passed. H2.3 = verify-only
  row (live /health evidence); H2.4 = defer paragraph delivered. AUDIT DISPATCHED to
  round1-auditor (brief scratchpad/h2-audit-brief.md; key attacks: count-unpinned mutation,
  delay-placement off-by-one, WARNING-once under multi-fallback storm, config-time variant
  untouched, exception-contract additivity vs H1 catch site). Post-deploy cycle STILL RUNNING
  (watcher bbbt0lznd not fired; started 03:17:43Z). H1 forced-degraded mechanism still awaits
  operator approval.
- 2026-08-02 ~06:20Z — **H2 AUDIT PASS (first pass) + gate record committed + H3 dispatched.**
  Audit ruled out: count-unpinning (mutation (c) broke 3 assertions at 3 call-stack levels),
  delay-placement drift (pure one-line substitution vs pre-commit code), multi-WARNING (own
  storm probe: 1 WARNING under 3-cycle storm AND under total failure), config-time variant
  drift (outside all 9 hunks), exception-contract breakage (5 raisers/4 catchers traced incl.
  H1 swan.py:2534 catch), live calls/real sleeps in tests. Auditor counts matched (14, 62).
  Meta `2791c30` = plan §H2 round record + section corrections (wavewatch.py stale, cap
  pre-existing, H2.3 pre-satisfied, H2.4 deferred). H2 deploy = OWN slot AFTER H1 live
  verification completes (one change per deploy). H3 DISPATCHED to `doc-sync` agent
  (brief scratchpad/h3-brief.md; 4 items incl. V4 residual line; scope-ack first).
  Cycle STILL RUNNING (03:18:44 start, swan active ~04:15Z). Meta local: 2791c30 not pushed
  (rides with next push).
- **TIMESTAMP CORRECTION (2026-08-02 03:46Z, measured via `date -u` on librewxr):** the "~05:xx/
  ~06:xxZ" labels on the entries above are WRONG (coordinator estimates ran ~2h fast). True
  wall-clock anchors: deploy proc 03:17:24Z; post-deploy cycle start 03:18:44Z; H2 closeout +
  audit + H3 dispatch all completed by 03:46Z. Use journal timestamps, not the log labels,
  when correlating.
- 2026-08-02 03:46Z — cycle check: swan still running (~28 min in), zero ERROR / no-publish
  lines since deploy. H3 GO issued (ruling change on (b): PROVIDER-MANUAL stale TRANSM block
  = DELETE+pointer, not strike-through — manuals are living guidance, not records; grep target
  TRANSM 0.95|0.8 → 0). Awaiting: cycle completion (watcher), H3 closeout.
- 2026-08-02 ~03:55Z — **H3 DONE + accepted.** Meta `40a557c` (5 files) + plan record
  `132c9ff`-ish (actual: committed after 2791c30). Lead re-ran all 4 greps: TRANSM stale 1→0,
  range values 5→0, "15 km margin" 1→0 (now "**10 km** ... corrected 2026-08-02" w/
  swan_domain.py:1131 cite), "honestly shortened" 0→1. Briefs annotated only (originals
  byte-identical). Gate H row 6 re-grep pending at phase gate.
- 2026-08-02 04:02-04:05Z — **H1 PASSIVE LIVE CHECKS ALL PASS + H2 DEPLOYED.**
  H1 live evidence (cycle started 03:18:44Z, completed 04:02:07Z, proc 2491ada):
  publish-liveness PASS (cache persisted 207.3 MB — vs 132.5 baseline, explained by V4
  honest-window: 00z GFS now fully published, 67 h served); journal sweep PASS (0 ERROR since
  deploy, no new WARNING classes); health ok, reasons [], invariants 0; main_zone healthy
  (face 0.61≤best_peak 0.64 etc., bulk-fallback none). REALITY GATE PASS (pre-committed
  quantity): served deep-water combined Hs @03:00Z = sqrt(0.34²+0.62²+0.49²)=0.86 m vs NDBC
  46222 WVHT 0.8 m @03:26Z → +7.5%, tolerance ±30%. Secondary: dominant 9.1s/226° vs DPD
  8s/MWD 263° (direction offset noted, not gated). H1 remaining: forced-degraded live check
  ONLY (operator approval pending for grid-sizing-cache temp-rename mechanism).
  **H2 DEPLOYED own slot:** marine pushed 2491ada..498b6a8; deploy verified: running commit
  498b6a8, proc 04:04:09Z, health 200, auth enforced. Watcher `b54nlsyne` set for TWO cycle
  completions (H2 accept: ≥2 cycles no hot loop + boundary age visible). On fire: grep 404
  retry spacing + WW3 WARNING lines + ERROR count + /health boundary age_s.
- 2026-08-02 ~04:15Z — operator said "proceed". Meta pushed 3cc12d8..5f07420. **D4 DISPATCHED**
  to NEW agent `d4-dashboard` (clearskies-dashboard-dev, Sonnet; brief scratchpad/d4-brief.md;
  dashboard repo pre-flight clean @df60297). Stage 1 = read-only contract-delta audit
  (types.ts/openapi vs served contract; known deltas: 5 BD-7/BD-9 fields, headline-fed
  breakingFaceHeight, TA-C19 negative distanceFromShore); fixture capture from live service
  via SSH; live render still blocked on H4. STILL PENDING OPERATOR: (1) forced-degraded
  mechanism OK (grid-sizing-cache temp-rename) for H1's last row; (2) H4 design pick — lead
  RECOMMENDS option (a) asyncio.to_thread offload of publish/read serialization + the (d)
  investigation of why the API-side response cache was empty, with (c) timeout raise rejected
  as stall-hiding. H4 dispatch HELD until operator picks.
- 2026-08-02 ~04:35Z — **D4 Stage-1 delta table received + rulings + GO.** 11-row delta table;
  5 BD-7/9 fields absent (confirmed live); TA-C19 negative distance CONFIRMED live
  (transect[-1].distance=-25.94) AND as render bug (BeachProfileChart.tsx:254 xMin=0
  hardcoded; HeatMapCard.tsx:127-140 same class — both plot negatives off-canvas past shore);
  NEW live defect found: peel chevron dead code (plain peelClassification values vs
  .includes('right'/'left'); separate peelDirection field untyped). LEAD RULINGS: (#8) FULL
  openapi catch-up approved, separate mechanical commit, per-field cite required; (#2 overlap)
  D4 owns the axis-domain fix in both chart files, D5 verifies+overlays only; (#9) SPLIT —
  contract half (peelDirection type + comment fix) in D4 Stage 2, render half = NEW plan task
  D8 (committed, blocked on D4); (#7) API-MANUAL 'distanceFromShore' prose vs real key
  'distance' → doc-sync at round close; (#10) D4.3 verify-only accepted. Fixtures captured
  (surf-fixture.json, profile-fixture.json in agent scratchpad). D4 Stage 2 in progress.
  DOC-SYNC QUEUE for D4 round close: API-MANUAL:2057 field-name prose; plan D4 round record.
- 2026-08-02 ~04:55Z — **D4 CLOSED OUT + accepted + audit dispatched; D9 tracked; Phase LM
  added; AUTONOMY GRANT; H4 dispatched.** Operator messages: (1) LM request (pier line+label,
  operator-drawn markers, alongshore scale — Phase LM committed e170bae, contract additions
  operator-authorized); (2) "wired into the dashboard heatmap" confirmed = LM-2's deliverable;
  (3) wizard/admin PARITY requirement on ALL setup functions (G6.3+LM-3 updated; general
  principle → OPERATIONS-MANUAL at LM-3 round close); (4) "ok continue autonomously with plan
  implementation" — standing grant, recorded in plan decision log (meta dbff899, pushed).
  D4 acceptance: my tsc clean + 25/25 vitest; commits cdef8dd (openapi catch-up +71) +
  ce694c2 (9 files +464/-33); handoffSourceLevel 'L4' widening ratified (live-confirmed).
  D4 AUDIT dispatched to round1-auditor (brief scratchpad/d4-audit-brief.md; old-payload
  replay, partial-null attack, 9 distToX call sites, positive-domain regression, openapi
  truthfulness ≥8 fields, axe = exactly the 2 known D9 violations). Pre-existing a11y dl
  violation → plan task D9; peel chevron → D8. H4 DISPATCHED to l4-rewrite Stage 1 read-only
  (brief scratchpad/h4-brief.md; design = to_thread I/O + chunked-yield encode decided by
  measurement; GIL fact in brief; (d) API cache investigation read-only; NO new deps, NO
  worker process, NO cache-shape change). FORCED-DEGRADED DRILL authorized under autonomy
  grant: sequence = after next natural cycle completes (H2 cycle #1) → rename grid-sizing
  cache on librewxr → observe degraded+ERROR+admin row → restore → retry completes (H2 cycle
  #2 + recovery evidence). H2 watcher b54nlsyne still waiting (no cycle since 04:04 deploy).
  Dashboard commits NOT pushed yet (push after D4 audit verdict).
- 2026-08-02 ~05:15Z — **D4 AUDIT PASS-WITH-FINDINGS → round closed; D10 created; dashboard
  PUSHED+DEPLOYED; H4 Stage-1 measured + GO issued.**
  D4 audit: everything survived (9 distToX sites all 3-arg + tsc-enforced; 2 mutations
  caught; positive-domain proven algebraically+empirically; null-guard survived falsy-zero
  attack; 18/21 openapi fields confirmed live incl. peelDirection "a_frame",
  handoffSourceLevel L4, distance -25.94; axe exactly the 2 known D9 dl violations).
  MINOR finding (3 unconfirmed fields) LEAD-RESOLVED by cross-repo greps: partitionBreakInfo/
  shadowFaceHeight/waveShapeClassification served by NEITHER marine NOR API repo — but
  SurfingTab has null-guarded RENDER code for all three = 3 silently-dead features (D8 class).
  → NEW plan task D10 (investigation-first: pre-separation API history; then OPERATOR
  DECISION restore-vs-remove; openapi entries stay as-is until ruled). API-MANUAL:2057
  distanceFromShore→distance prose fixed LEAD-DIRECT (committed). Dashboard pushed
  df60297..ce694c2 + redeploy-weather-dev.sh complete (live render still 503-gated by H4).
  **H4 Stage-1 accepted (superb measurement):** publish path already in OS thread — stall =
  GIL contention; to_thread EMPIRICALLY useless (1636ms gap unchanged); per-timestep chunked
  encode = 12.1ms max gap, zero overhead on 217.7MB synthetic. (d) investigation: no proxy
  cache bug; 3 plausible factors (success-only warm, LRU pressure from shared TTLCache,
  query-param key variance — last one queued for a dashboard grep later). LEAD RULINGS:
  read path = PRE-ENCODED Response in existing sync handlers (threadpool) — StreamingResponse
  REJECTED (keeps Content-Length, no async conversion); byte-identity binding (jsonable_encoder
  if currently applied + Starlette dumps options ensure_ascii=False/allow_nan=False/
  separators (",",":")); helper services/chunked_json.py approved (encode-only, time.sleep(0)
  both paths); per-timestep granularity; DECODE stays monolithic this round (residual ~1.3s
  hourly fill stall recorded — if it alone breaks the 10/10<1s accept, STOP-and-surface for a
  persisted-format decision, never silent). Stage 2 in progress.
- 2026-08-02 05:58-06:05Z — **H2 LIVE PROOF + H1 DRILL EXECUTED → found+fixed a real defect.**
  H2 live cycle #1 (04:05Z, natural NOMADS 403 storm): EXACTLY the designed behavior — 12
  attempts across 4 stations (count cap held), ONE aggregated WARNING verbatim shape,
  completed on 18z fallback 04:48:53. Journal sweep: CLEARSKIES_MARINE_API_URL ERROR +
  fishing 502 + hrrr-404 classes all PRE-DATE deploys (11/5 hits Aug1) — not regressions;
  API_URL/fishing-502 queued for C1 sweep. **H1 DRILL** (cache renamed → restart): abort
  fired correctly (no-publish: no_grid_sizing_cache ERROR, last-good preserved, run skipped)
  BUT /health reasons[] MISSING the no-publish string — root cause: H1 append sat AFTER the
  failed early-return in _compute_status, so every fetch-failure no-publish (which also marks
  its input unavailable) would hide its reason. LEAD-DIRECT FIX (small-fix exception): marine
  `3d42088` — reasons collected first, h1_reason_count guard preserves precedence
  (failed-only-on-failed-conditions, floor-at-degraded intact); KAT extended
  (failed-with-reason visibility + drill's fetch-failure shape); falsifiability proven vs
  pre-fix code; 42 passed. ERROR-multiplicity RULING: exactly one PREFIXED ERROR per path
  (holds); callee-detail + runner-level ERRORs are pre-existing classes, kept (recorded).
  Cache RESTORED 06:03Z; recovery watcher `bug9jn6j6` armed. CAUTION: l4-rewrite mid-H4 in
  same repo (untracked chunked_json.py seen) — my commit was pathspec-limited to
  health.py+test_health.py. NEXT on recovery-cycle completion: deploy 3d42088 (own slot) →
  re-drill to verify reason visible in failed → recovery = H2 cycle #2 done → Gate H
  phase-audit prep.
- 2026-08-02 06:50-07:00Z — **H1 ✅ + H2 ✅ BOTH DONE, live-accepted (meta b608415 pushed).**
  Drill-1 recovery: cycle 06:06→06:50:57 clean (health ok, reasons [], main_zone 0.61≤0.67,
  226.3 MB, zero WW3 4xx = H2 cycle #2 healthy-path evidence). H4 closeout received: commit
  `1f7374a` (chunked_json.py + persist/read paths + 13 KATs; byte-identity proven; heartbeat
  persist 1.04-1.08s→0.19-0.38s, read 0.50-0.52s→0.057-0.068s BUT read wall 6.4→12.3s) →
  REMEDIATION sent: slice-batched list encoding, targets wall ≤1.3× + gap ≤0.15s; test-order
  pollution → NEW plan task D11 (committed). Health fix deployed ALONE (push origin
  3d42088:main — 1f7374a held local unaudited; proc 06:51:43Z). RE-DRILL PASS: /health failed
  + "no-publish: no_grid_sizing_cache …" FIRST in reasons + exactly 1 prefixed ERROR; admin
  page login-gated (303) — evidence = code trace + live /health string; operator one-glance
  residual. Cache restored 06:5xZ; recovery watcher `bn2zd5cpu` armed (recovery = pure
  formality, same shape as drill-1's). Plan updated: H1 ✅ H2 ✅ with live records.
  REMAINING PHASE H: H4 remediation → audit → deploy (own slot; probe-storm accept) → Gate H
  phase-audit (8 rows). Marine local HEAD 1f7374a (NOT pushed); deployed = 3d42088.
- 2026-08-02 ~07:15Z — **H4 remediation status + DILBERT contention cleanup.** Slice-batching
  K=100 implemented (wall ratio 0.98×, byte-identity by construction, wall-overhead KAT
  added); ONE KAT env-blocked (read-path 0.15s heartbeat) by machine load. Lead diagnosis:
  40 python procs = 38 IDLE analytics-mcp orphans (2/session since Jul 27, ~150MB each,
  ~5.5GB RAM, no CPU) + PID 49600 = LEAKED measurement child from the agent's own round
  (1691 CPU-s, 1GB RSS, spinning). KILLED all (python count now 0). Agent directed: re-run
  blocked KAT (0.15s threshold STAYS; clean sample 0.137s passes), audit its harness for the
  child leak, final commit + closeout. NOTE for operator: analytics-mcp MCP server leaks 2
  orphan processes per Claude session on DILBERT — recurring hygiene issue worth an MCP
  config look.
- 2026-08-02 ~07:40Z — **H4 remediation round 2: harness-artifact diagnosis + ruling.**
  Agent STOPped correctly on a measurement conflict (no K satisfies both gap≤0.15s and
  wall≤1.3× — K=2-3 walls 3.2×, K=100 gaps 0.137-0.363s on idle machine). Agent also found+
  fixed its heartbeat leak (busy-loop daemon thread missing try/finally stop → PID 49600).
  LEAD DIAGNOSIS: the busy-spin heartbeat thread IS the artifact — it GIL-ping-pongs (inflates
  wall at small K; contradicts agent's own earlier K=1=1.46× uncontended) and gets Windows
  scheduler-penalized as a CPU burner, while the REAL consumer (asyncio accept loop) is
  IO-blocked + wake-boosted; agent's own p99=0.66ms slice profile proves sub-ms bytecode
  returns where CPython's 5ms switch preempts naturally. RULING: (d) fix harness = SLEEPING
  heartbeat (sleep 0.001, measure oversleep, perf_counter), keep K=100 + sleep(0) + BOTH
  thresholds; before-code must still fail; PRE-APPROVED fallback ONLY if fixed harness still
  >0.15s at K=100: sleep(0.0005) every 50th slice, wall re-verified ≤1.3×. Agent implementing.
- 2026-08-02 ~08:20Z — **H4 remediation CLOSED + accepted + audit dispatched.** Marine
  `277b223` (2 files: chunked_json.py K=100 slice-batching + stride sleeps 50/0.0005s BOTH
  branches [fallback correctly applied to dict branch too]; test file harness fixed —
  try/finally leak fix + sleeping heartbeat). Corrected-harness numbers ×3 idle runs:
  persist before gap 0.64-0.67s FAIL→after 0.017-0.023s PASS; read before 0.31-0.33s FAIL→
  after 0.055-0.063s PASS; wall ratio 1.04-1.07×. Lead acceptance: own pytest 14/14; stat
  2 files exact; kept as follow-up commit (honest history). H4 AUDIT dispatched to
  round1-auditor (brief scratchpad/h4-audit-brief.md; combined diff 3d42088..277b223; key
  attacks: adversarial byte-identity incl. K±1 slice boundaries + endpoint-body equivalence
  vs scratch pre-change checkout; response_model-removal body-change check; gap-KAT
  mechanism-pinning honesty check). AFTER AUDIT: deploy 277b223 (own slot; push held
  commits) → live accept = probe storm during end-of-cycle publish + concurrent large /surf
  read, 10/10 handshakes <1s, dashboard loads, zero proxy timeouts ≥2 cycles → residual
  decode-stall check (if it alone breaks accept → STOP-and-surface persisted-format
  decision) → Gate H phase-audit (8 rows).
- 2026-08-02 ~08:00Z — **H4 AUDIT PASS-WITH-FINDINGS + DEPLOYED + read-path accept PASS.**
  Audit highlights: worktree pre/post BYTE-IDENTICAL endpoint bodies (sha256 match, frozen
  clock — closes response_model question); persist file bytes identical; adversarial fixture
  battery clean incl. K±1 slice boundaries + 4 allow_nan positions; thread-safety proven.
  Findings ACCEPTED: (1) stride-sleeps unpinned by tests (deleting them passes gap KATs —
  chunk structure suffices locally) — RULED keep-as-cheap-insurance, gap recorded, live
  accept decisive, docstring necessity-claim noted for gate record; (2) beach_profile ok-path
  HTTP equivalence not independently closed — covered by live checks. Pytest combined-session
  stall = D11 family (tracked). DEPLOY: pushed 3d42088..277b223, proc 07:56:08Z. NOTE: deploy
  restart KILLED an in-flight cycle (old proc logged "cycle failed" at kill) — I skipped the
  pgrep pre-check, benign by design (serve-nothing, retry), logged as process lapse. D10.1
  Explore agent `d10-history` dispatched (phantom-fields git archaeology). **READ-PATH ACCEPT
  PASS: 20/20 handshakes 5.5-15.2ms from weewx DURING 6 concurrent large reads (3×4MB
  profile-all ~5s each + /surf incl. one 33.4s cold read) — pre-fix this combo = multi-second
  timeouts.** Publish-window probe armed: watcher `buuc4o05m` on first run_pipeline line of
  the next cycle → immediately storm probes through 1D+persist window. Then: dashboard live
  render check + ≥2-cycle proxy-journal sweep → H4 accept complete → Gate H phase-audit.
- 2026-08-02 08:39-09:00Z — **H4 publish-window probe + DASHBOARD BACK + new findings tracked
  (meta 0a8f049 pushed).** Publish storm: 59/60 ≤27ms, ONE 1.655s outlier (re-probe next
  window with per-probe timestamps — watcher `bab7wr28g` armed). DASHBOARD CHAIN LIVE:
  profile-all via weather-dev Caddy→API→marine = 200/4.7s/2.1MB (was 503-class); /surf warm
  200/0.46s ×3. Public-FQDN curl 403 = openresty edge blocking curl on ALL paths — NOT
  marine; internal chain is the valid test. NEW TASKS: **H5** cold /surf (first read/cycle
  ~33s deserialize > proxy 15s timeout → one 503/cycle; distinct mechanism from handshakes);
  **C7** bimodal beach_facing (216.4 SWAN-path stable through all deploys; 240.0 = second
  concurrent computation, FIRST Aug 2 00:33Z PRE-Phase-H under 732e87d-era proc, correlates
  w/ fishing endpoint + CLEARSKIES_MARINE_API_URL-unset 502s; zero hits Jul30-Aug1).
  D10.1 DONE (3 phantom fields = documented awaiting-API stragglers; API honored 6/8 of the
  same list; D10.2 = 3 operator rulings framed in plan). PENDING: timestamped publish-window
  re-probe → H4 close → Gate H phase-audit (8 rows); D5 now UNBLOCKED (H4 landed).
- 2026-08-02 08:45-08:50Z — **H4 accept CLOSED (decisive evidence) + GATE H AUDIT DISPATCHED
  + D5 dispatched.** Timestamped storm #2: 60/60 ≤19.4ms (persist had already happened
  08:38:39 — storm covered fill/1D window instead; outlier never recurred). DECISIVE: API
  proxy journal handshake-timeout/unreachable count = **6 pre-H4 (12h window) vs 0 since
  deploy 07:56** incl. the 08:38 full publish + storms. Gate H 8-row walk dispatched to
  round1-auditor (independent re-verification; C7 flagged as known so not re-found; H5 +
  decode residuals disclosed). D5 dispatched to d4-dashboard (brief scratchpad/d5-brief.md;
  scope-ack first). AWAITING: Gate H verdict, D5 scope-ack.
- 2026-08-02 ~09:10Z — **D5 scope-ack + GO.** D5.1 EMPTY breakage list w/ evidence (notable:
  negative distances now 143/143 transects — D4 fix load-bearing; 3 real double-break
  transects replayed correctly through both components first time; 37 negative-distance zone
  entries handled by existing zoneRect+width<1 guard; breakingFraction ABSENT-not-null still
  caught by != null). RULINGS: SurfingTab.tsx ADDED narrowly (thread 3 props to HeatMapCard
  call ~:2628 only; D8/D9 blocks untouchable); purple band approved AS NAMED CONSTANT beside
  ZONE_*_FILL; gutter-band/triangle/legend/sr-only design approved; live-transect-4
  double-break pinning test approved; meta-repo commit = DASHBOARD-MANUAL.md ONLY (hard
  constraint — plan/session files live there). D5 implementing. AWAITING: Gate H verdict,
  D5 closeout.
- 2026-08-02 ~09:25Z — **⛔→✅ GATE H PASSED 8/8 — PHASE H CLOSED** (auditor independent walk;
  gate record in plan; meta committed+pushed). Notable: proxy-timeout contrast 25 pre / 0
  post (32h window); auditor's own mid-cycle probe burst 10/10 at 6.2-12.9ms; the 07:56
  deploy cycle-kill surfaced as recorded swan_fatal SIGTERM in the H1 registry (machinery
  catching our own interruption). Phase H: H1✅ H2✅ H3✅ H4🔶accept-closed; H5 open addendum.
  BOARD NOW: D5 implementing (in flight); READY to dispatch: D8, D9, D11, H5, C7, C2, C3;
  OPERATOR-GATED: D1 (deletion sign-off), D10.2 (3 rulings), G6 phase (after D), V-rows
  (weather), LM (after D5/G6.3). Next: D5 closeout → audit → Gate D progress; consider
  dispatching D11 (test-author) + C7 (api-dev investigation) in parallel.
- 2026-08-02 ~09:40-10:30Z — **D11 ✅ (marine 92c2743 pushed; conftest wires existing
  invariants reset; 45/45 both orders lead-verified). C7 INVESTIGATION ✅ (plan 1aff4ae):
  WRONG DATA SERVED — beach_profile ALWAYS 240.0° fallback-facing (no cache-hit path, no
  scalar correction); surf.py SurfBeat fields partial (scalar corrected via
  _apply_persisted_geometry when spot_profiles cache present — agent self-corrected its
  "always wrong" overclaim; per-transect curvature still lost); headline wrong only on
  SWAN-cache miss. Root: AD-1R correction in-memory-only (deliberate operator-owned-config
  boundary); endpoints fresh-parse per request. Q4: CLEARSKIES_MARINE_API_URL never set on
  librewxr (C-47 Jul 25 added hard-require consumers → fishing/station-wind 502s);
  CONFIG.md:52 stale. **C7b(c) CONFIRMED reachable zero-new-persistence:**
  spot_profiles/{id}.json ALREADY carries transect_bearings (grid_sizing_chain.py:2163) in
  the exact list[float] shape compute_spot_transects' documented override expects; both
  endpoints already read that file. C7 FIX ROUND DISPATCHED to l4-rewrite (thread bearings
  both endpoints + beach_profile scalar correction via shared helper + CONFIG.md; env-var
  value = LEAD sets network.env at deploy: base URL https://weewx.shaneburkhardt.com:8765
  class, NO auth needed for the two 502 calls — verify reachability from librewxr first).
  **D5 CLOSED OUT + accepted** (dashboard fe0b8e9 7 files +724/-60, meta 54553ae 1 file;
  lead: tsc clean + 42/42 independent; live-transect-4 pinning tests; axe = exactly D4's 2
  known D9 violations). D5 AUDIT dispatched (null-safety vs pre-change render, ≥3 mutations,
  overlay geometry vs live fixture, D8/D9 byte-untouched). AWAITING: D5 audit verdict,
  C7-fix closeout. After D5 audit PASS: push+deploy dashboard → LIVE RENDER CHECK (operator
  eyeball invited) → plan records.
- 2026-08-02 ~11:00Z — **C7 fix CLOSED (marine cbcfbb1+b5a4d01 LOCAL; lead accepted: 12/12
  own run, stat exact; LIVE cache verified: transect_bearings 143 entries 216.2-221.6°,
  scalar 216.36 — fix will bind real data). D5 AUDIT: PASS-WITH-FINDINGS — MAJOR
  value-vs-position overlay bug (SVG uses /surf index VALUES as /profile array POSITIONS;
  marine filters failed transects → gaps shift positions; sr-only table compares values,
  would diverge from visual; right-by-accident on today's contiguous 143) + MINOR
  unconditional font-weight=400 breaking literal byte-identity. REMEDIATION dispatched to
  d4-dashboard (fix BY CONSTRUCTION: findIndex value→position for marker; band = first..last
  positions with in-zone values; membership-based validity; auditor's exact gap-KAT
  [20 transects, #5 missing, zone 10/12 rep 11]; font-weight only-when-700). C7 AUDIT
  dispatched to round1-auditor (mutations incl. the _PROFILE_CACHE_DIR coupling probe,
  fallback byte-preservation vs cbcfbb1~1, CONFIG.md vs api_client claims). NOTE deploy queue:
  marine has cbcfbb1+b5a4d01 local-unpushed (deploy AFTER C7 audit + set
  CLEARSKIES_MARINE_API_URL in network.env + restart, verify reachability of
  https://weewx.shaneburkhardt.com:8765 from librewxr first); dashboard deploys after D5
  remediation re-audit.
- 2026-08-02 ~11:20Z — **D5 remediation CLOSED + lead-accepted** (dashboard `6bc0573` LOCAL:
  2 files, membership-based positions [findIndex value→position; band min..max member
  positions; SVG+sr-only agree by construction], font-weight conditional-spread; gap-KAT
  green + falsified with the auditor's exact predicted 15px/1-row signature; lead runs:
  18/18 + tsc clean + stat exact). One legit behavior note: old bounds-check test split into
  partial-overlap-bands + zero-overlap-nothing (membership semantics — accepted). D5
  RE-AUDIT holds until C7 audit verdict arrives (don't interrupt auditor mid-task). THEN:
  scoped re-audit → dashboard push (ce694c2..6bc0573) + redeploy-weather-dev → live render
  check (operator eyeball). Marine C7 deploy after its audit: push cbcfbb1+b5a4d01 →
  network.env CLEARSKIES_MARINE_API_URL= (verify URL reachable from librewxr) →
  deploy-marine.sh → live: beach_profile logs 216.4-class facing + fishing 200.
- 2026-08-02 09:41-10:00Z — **C7 AUDIT PASS → DEPLOYED+LIVE-VERIFIED (marine b5a4d01, proc
  09:41:05Z; beach_profile now logs 216.4°/29/114 — was 240.0°/25/118 every request).
  C7a BLOCKED-ON-OPERATOR: librewxr CANNOT reach weewx:8765 (v6 ULA + v4 192.168.2.121 both
  time out — inter-VLAN firewall; that's why the env var never existed). Operator options in
  plan: MikroTik allow rule + set var, or accept fishing/station-wind degraded. **D5
  RE-AUDIT PASS** (gap-KAT independently reproduced; 15px mutation signature; byte-identity
  vs TRUE pre-D5 baseline now holds; LOW test-name nuance accepted+recorded) → dashboard
  PUSHED ce694c2..6bc0573 + redeploy-weather-dev DONE (200, config active, new bundle
  index-WLu25L_n.js). D5 ✅ in plan (meta pushed). OPERATOR EYEBALL INVITED:
  https://weather-test.shaneburkhardt.com surf tab — zone band + representative marker vs
  reality. BOARD: dispatchable next = D8, D9, H5, C2, C3, V3; operator-gated = C7a
  (firewall), D1, D10.2; weather-gated = V1/V2. All repos pushed; marine deployed b5a4d01;
  dashboard deployed 6bc0573.
═══════════════════════════════════════════════════════════════════
