# Marine Forward Plan — consolidated live work (2026-08-02)

**Created:** 2026-08-02 (operator-approved consolidation, in chat). **Granularized same day**
(operator direction: line-level tasks, per-task agent assignments, per-phase adversarial QC
gates, briefs tied back in, zero regression tolerance).
**Status:** ACTIVE — this is the ONLY live marine planning document. Everything else marine-wise
in `docs/planning/` is archived history in `docs/archive/`.
**Supersedes / consolidates:** the open remainders of `docs/archive/MARINE-MODEL-RESTORATION-PLAN.md`
(R4, R6, R9/R10 residuals), `docs/archive/MARINE-GEOMETRY-MODEL-PLAN.md` (G1R.3, G5→pinned, G6,
G7, Gate GR), `docs/archive/MARINE-WORKING-MODEL-PLAN.md` (via the geometry plan's G7), and
`docs/archive/MARINE-SERVICE-SEPARATION-PLAN.md` (archived 2026-08-02, overtaken by events) —
plus the deferred items from the 2026-08-01 break-detection rounds
([briefs/SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01.md](briefs/SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01.md),
Rounds 1–2 DEPLOYED, marine `732e87d`).

**Where we are (2026-08-02):** the model WORKS. Full 4-level SWAN nest converges (L4
valid_fraction 100%), 143 transects × all forecast hours resolve their own handoffs, the 1D
layer detects breaks at physically correct depths (incl. real double-breaks), publish + reality
gate PASS, BD-7 main-break-zone headline + BD-9 representative transect live. This plan is
hardening, validation, and setup-automation — **not** model recovery.

---

## PRIME DIRECTIVE — two steps forward, ZERO steps back

Every regression of the past two weeks came from a change that touched more than its task named,
or shipped without a matched-time reality check. Therefore, binding on every task below:

1. **The working chain is OFF LIMITS unless a task names the exact file.** The frozen core:
   `swan_domain.py` (L4 shadow-envelope sizing, `4e79d21`), `transect_handoff.py` (BD-2
   selection + T2.2-PART-B depth rule), `surf_1d_analytical.py` (break engine),
   `swan_formats.py` emission grammar, `geography.py` ray fan, `shoreline_normal_bearing`
   (AD-1R), the convergence gate, the serve-nothing guard (G1R.0), hotstart mechanics. **No task
   in this plan authorizes touching ANY of these** unless its "Files" list says so explicitly.
2. **Baseline before, diff after.** Before any deploy: record facing, DWR Hs, valid_fraction,
   per-transect resolution count, publish size from the current cycle. After: diff them in the
   gate record. (rules/coordinator.md §7 deploy discipline.)
3. **One functional change per deploy.** Doc/test-only commits may ride along; two behavior
   changes never ship together.
4. **Reality gate on every deploy** (rules/verification.md): within one cycle, matched-time
   comparison vs NDBC 46222/Surfline/cam, quantity chosen before looking; plus publish-liveness
   (a publish or a health-visible refusal within one cycle).
5. **Stale tests:** a failing test that pins superseded behavior → STOP and surface; never bend
   code to a stale test; never delete a test without listing it in the closeout.
6. **Agent discipline:** every implementation task runs on a **Sonnet** `clearskies-api-dev` /
   `clearskies-dashboard-dev` / `clearskies-test-author` agent with a written brief; scope-ack
   before code; **adversarial `clearskies-auditor` pass BEFORE the lead gate** on every round;
   doc-sync closes every round (CLAUDE.md doc-code sync). Architectural-change trigger list
   (CLAUDE.md) binds everyone; the pre-approvals recorded per-task below are the ONLY ones.
7. **Line numbers in this plan are hints, not gospel.** First action of every implementation
   agent: verify the quoted file/function state. If the code does not match, STOP and report
   drift — do not hunt for "what was probably meant."

**Execution order:** Phase H → (D2 early, it is tiny and guards H1's test surface) → Phase D →
Phase V as weather/evidence allows → Phase G6 → Phase C. G1R.3 and pinned/parked items whenever
the operator says so. Phases are independent enough to interleave, but each phase's QC gate
closes before its next task round dispatches.

---

## PHASE H — Operational hardening — ✅ GATE H PASSED 8/8 (2026-08-02, independent auditor walk)

**Gate record:** every row either re-verified live by the auditor's own fresh command (rows
2,3,6,7,8) or backed by the auditor's own prior adversarial artifact (1,4,5) — zero rows on
implementer/coordinator word. Highlights: row 2 — drill ERROR + recovery re-grepped live,
and the 07:56 deploy-restart cycle-kill itself showed up as a recorded `swan_fatal` (SIGTERM)
in the H1 registry — the loudness machinery catching our own deploy interruption; row 7 —
SWAN-path baseline exact (143 transects / 216.4° / L4 valid_fraction 100.0% / accuracy
99.6%), C7 anomaly correctly not re-flagged; row 8 — proxy handshake-timeout count **25
pre-deploy (32 h window) vs 0 since**, plus the auditor's own 10/10 probe burst at 6.2-12.9
ms taken mid-SWAN-cycle. Disclosed residuals (H4 1.655 s unlocalized outlier, H5 cold-read,
decode-side holds, C7) are tracked tasks, not gate failures. Phase H tasks: H1 ✅ H2 ✅ H3 ✅
H4 🔶 (accept closed; H5 spun off) — phase CLOSED; H5 remains an open Phase-H-addendum task
audited at its own round.

### H1 — No-publish paths must be loud and truthful *(was Restoration R4; Gate R row 5)*  ✅ DONE 2026-08-02 — deployed + forced-degraded drill PASSED (second attempt, after the drill itself found and fixed a defect)
**Live acceptance record (2026-08-02):** Drill #1 (grid-sizing-cache rename + restart,
06:01Z): abort fired correctly (prefixed ERROR, last-good preserved) BUT the no-publish
reason was INVISIBLE in `/health` `reasons[]` — the H1.3 append sat after the failed
early-return, hiding the reason in exactly the fetch-failure shapes that matter. Fixed
lead-direct (marine `3d42088`: reasons collected before the early-return, `h1_reason_count`
guard preserves precedence; KAT extended with failed-with-reason visibility + the drill's
fetch-failure shape; falsifiability proven vs pre-fix code). Deployed alone (proc 06:51:43Z).
Drill #2 (06:52Z): `/health` = `failed` with `"no-publish: no_grid_sizing_cache …"` FIRST in
reasons; exactly 1 prefixed ERROR in journal; cache restored; recovery via retry-same-cycle.
ERROR-multiplicity ruling: one PREFIXED machine-readable ERROR per path (holds); pre-existing
callee-detail/runner-level ERROR classes kept (H1 not chartered to silence them). H1.4 admin
row: code-trace + live `/health` string verified; authenticated admin-page render = one-glance
operator check (page is login-gated; template renders `reasons[]` generically per the F2
trace). Gate H rows 1-3 evidence banked (audit + drill).
**Round record (2026-08-02):** marine `c768b18` + remediation `2491ada`; meta doc-sync
`d98c091` + `4e2acc2` (API-MANUAL §19.7). Adversarial audit round 1 FAIL (BLOCKER: GFS-wind
inline-refetch path uninstrumented, production-reachable; MAJOR: HRRR companion) → remediated →
re-audit PASS (4/4 mutations caught, full-function re-sweep: **13 instrumented no-publish
exits, no 14th**). Amendments to the spec as written, all lead-ruled + operator-visible:
(1) Files list gained `services/grid_sizing_chain.py` (narrow: detect + record only) because
the plan's own H1.3 "viability failure at config push" category lives there, and
`state.py` (the actual health store — `service.py` holds no state); (2) H1.4 satisfied by
H1.3 with ZERO stack-repo changes — the admin template already generically renders `/health`
`reasons[]` (trace: marine `/health` → API `setup.py:3082` pass-through → stack
`status.html`/`routes.py:3679`); (3) final slug list (13 sites, 11 slugs):
`no_grid_sizing_cache`, `hrrr_wind_failed`, `gfs_wind_failed`, `ww3_boundary_failed`,
`tide_fetch_failed`, `currents_fetch_failed`(×2), `bathymetry_failed`, `wave_setup_failed`,
`swan_fatal`(×2), `convergence_gate_failed`, `no_usable_handoff_timesteps`, plus per-cluster
`l3_viability_failed` in its own per-config-push registry (NOT cleared by cycle success —
clearing it on success would re-hide the R-DIAGNOSIS 11:16 shape); (4) spot_cfg-None per-spot
skip = WARNING only (config defect, not a runtime no-publish). Remaining for Accept: deploy +
forced-degraded live check + normal-cycle recovery (Gate H row 2).
**Owner:** `clearskies-api-dev` (Sonnet). **QC:** `clearskies-auditor` at Gate H.
**Origin/context:** archived restoration plan §R4; the 2026-07-31 11:51 abort (gate PASSED, zero
published entries, no ERROR naming why) is the motivating incident — its diagnosis is in the
archived plan §R-DIAGNOSIS.

**H1.1 — Enumerate every no-publish exit.** Read-only sub-task, report first, code second.
Trace `providers/nearshore/swan.py` `run_all_spots()` (the `spots_cached` counter: init ~`:3214`,
increment ~`:3347`, publish decision ~`:3354`) and list EVERY code path that ends a cycle with
`spots_cached == 0` or a spot skipped: convergence-gate failure (serve-nothing guard), zero
usable handoff timesteps, viability-test failure at config push, upstream fetch failure, SWAN
fatal. Deliverable: the list with file:line for each, in the scope-ack.
**H1.2 — One ERROR per no-publish path.** Each path from H1.1 logs exactly ONE
`logger.error("no-publish: <machine-readable reason> ...")` naming the path. No stack-trace spam,
no repeated per-transect errors.
**H1.3 — `/health` truthfulness.** `endpoints/health.py`: a cycle that published nothing sets
`status != ok` and appends a `reasons` entry carrying the H1.2 reason string + timestamp; a
config-push viability failure does the same (persisted so a later `/health` call still sees it,
not journal-only). Verify the existing B3 health contract in API-MANUAL before changing shape —
additive only; renaming/removing existing health fields is a data-contract change and is NOT
pre-approved.
**H1.4 — Admin status page.** Surface the same reason on the admin status page (B4). Additive
row only.
**Files (exhaustive):** `providers/nearshore/swan.py` (logging + health-report wiring ONLY — the
publish/cache DECISION logic and the convergence gate are frozen), `endpoints/health.py`,
`service.py` if the health state store lives there (name it in scope-ack), the admin status
template, `tests/` (new + existing health tests).
**MUST NOT TOUCH:** the serve-nothing-on-failure guard's decision (G1R.0 — a failed run still
publishes NOTHING; H1 only makes the silence loud); the convergence gate; anything in the
PRIME-DIRECTIVE frozen core.
**Known-answer tests:** (a) forced convergence-fail cycle → nothing published AND health
`degraded`/`failed` with the right reason AND one ERROR line (assert count == 1); (b) forced
viability failure at config push → same; (c) healthy cycle → `ok`, zero H1.2 ERRORs (guards
against the inverse regression).
**Accept:** all three KATs; live check = one forced degraded cycle on librewxr shows
health != ok + admin row + single ERROR, then a normal cycle returns to `ok`.

### H2 — Upstream fetch hygiene: WW3/NOMADS (+ same-class audit) *(was Restoration R6)*  ✅ DONE 2026-08-02 — deployed + BOTH live cycles verified (incl. a natural NOMADS storm)
**Live acceptance record (2026-08-02):** Cycle #1 (04:05Z, deployed `498b6a8`, natural 00z
not-yet-published storm): exactly 12 attempts across 4 stations (3/station cap HELD), ONE
aggregated WARNING verbatim ("WW3 20260802 00z ocean spectra unavailable after 12 attempt(s)
across 4 station(s); proceeding on 20260801 18z"), cycle completed on the 18z fallback
04:48Z. Cycle #2 (06:06→06:50Z, healthy path): zero 4xx, zero WARNING, zero extra calls.
`/health` `inputs.ww3_boundary.age_s` visible live (2649 s post-cycle). No hot loop in
either cycle. Gate H rows 4-5 evidence = audit (mutations+storm probe) + these two cycles.
**Round record (2026-08-02):** marine `498b6a8` (2 files: `services/ww3_station_selection.py`
+ new `tests/services/test_ww3_fetch_backoff.py`, 14 KATs). Adversarial audit PASS first pass
(3/3 mutations caught incl. retry-count pinning by 3 independent assertions; auditor wrote its
own multi-fallback storm probe — exactly ONE WARNING under a full 3-cycle storm; pure
sleep-substitution verified against pre-commit code; config-time variant untouched).
**Corrections to this section's original text, established by H2.1 evidence:**
(1) the fetch does NOT live in `providers/marine/wavewatch.py` (that is a separate, untouched
PacIOOS bulk-forecast module) — the real chain is `services/ww3_spectrum.py` (NOMADS HTTP GET)
→ `services/ww3_station_selection.py` (retry wrapper) → `providers/_common/http.py` (shared
client; its 4xx-never-retry is load-bearing global behavior and was not changed);
(2) the "per-cycle retry cap" ALREADY existed (3 attempts/station × `_MAX_CYCLE_FALLBACKS=3`
model-cycle fallbacks, both pre-existing and unchanged) — the Jul 30–31 "hot loop" (144
bounded 404s) was fixed-interval burstiness, and this round changed retry SPACING only
(exponential base 2.0 s × 2.0, cap 30 s, jitter ±25%) + ONE aggregated fallback WARNING;
(3) H2.3 was PRE-SATISFIED: all four `/health` inputs (incl. `ww3_boundary` and `wind`)
already carry `available`+`age_s` live — zero code, closed as a verification row;
(4) H2.4 Overpass: DEFERRED with reasoning (already behind the shared client's backoff; no
multi-candidate not-yet-published condition exists to wrap). Remaining for Accept: deploy
(own deploy slot, after H1's live verification) + ≥2-cycle journal check + boundary age
visible (Gate H rows 4–5 code evidence banked via audit).
**Owner:** `clearskies-api-dev` (Sonnet). **QC:** `clearskies-auditor` at Gate H.
**Origin/context:** archived restoration plan §R6; hot 403/404 retry loops in the Jul 30–31
journals; brief: [briefs/WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md](briefs/WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md)
(what the boundary fetch does and why it matters).

**H2.1 — Locate + instrument.** The WW3 station-spectra fetch lives in
`providers/marine/wavewatch.py` / the boundary-fetch path of `providers/nearshore/swan.py`
(verify which does the NOMADS HTTP calls; `providers/_common/http.py` is the shared client).
Report current retry behavior with journal evidence before changing it.
**H2.2 — Backoff + cap.** Exponential backoff with jitter + a per-cycle retry cap on NOMADS
spectra fetches. A cycle that exhausts the cap proceeds on cached boundary data (existing
behavior) and LOGS it at WARNING once.
**H2.3 — Staleness visible.** `/health` `inputs.ww3_boundary` gains `age_s` + `available`
(additive). Same for the GFS/HRRR wind fetches ONLY IF they share the same helper — do not
refactor separate fetch paths to unify them (that is a rewire, not in scope).
**H2.4 — TC-10 disposition.** Overpass (OSM geography fetch) is the same failure class but runs
at SETUP, not per-cycle. In closeout: either apply the same backoff via the shared helper (if
it already flows through `_common/http.py`) or write one paragraph deferring it with the reason.
Do NOT build an Overpass mirror/fallback — that is new architecture (trigger 7).
**Files (exhaustive):** the fetch module(s) named in H2.1 scope-ack, `providers/_common/http.py`
(only if the backoff naturally lives in the shared client), `endpoints/health.py` (additive
fields), tests.
**MUST NOT TOUCH:** boundary CONTENT processing (`ww3_spectrum_to_swan_boundary()` is
byte-faithful, T3.0-verified — see [briefs/T3.0-BOUNDARY-GROUNDTRUTH-2026-07-30.md](briefs/T3.0-BOUNDARY-GROUNDTRUTH-2026-07-30.md));
BOUNDSPEC emission (R5 fixed it; frozen); cache fallback semantics.
**Known-answer tests:** mocked 403 storm → call count ≤ cap, backoff intervals grow, cycle
completes on cache with one WARNING; healthy fetch → zero extra calls, no WARNING.
**Accept:** KATs + live journal over ≥2 cycles shows no hot loop; `/health` shows boundary age.

### H3 — Residual doc-truth sweep *(was Restoration R9+R10 residuals; Gate R row 8)*  ✅ DONE 2026-08-02 (meta `40a557c`; Gate H row 6 re-grep pending at phase gate)
**Round record:** (a) 3 dated supersession notes (SURF-ZONE §2.6 ×1, STUDY-AREA §1+§5 ×2),
originals byte-identical; (b) TC-19 CONFIRMED stale — PROVIDER-MANUAL carried a second,
contradictory pier-TRANSM block (0.95 + a 5-row TRANSM-range table) — DELETED and replaced
with an AD-8/§14.15 pointer per lead ruling (manuals are living guidance, not records;
grep `TRANSM 0.95|0.8` 1→0, range values 5→0); (c) ARCHITECTURE.md L1 offshore margin 15 km
→ **10 km** per `swan_domain.py:1131` (`offshore_km = shelf_dist_km + 10.0`), cited inline;
separate lateral `level1_margin_km=5.0` correctly left alone; (d) V4 honest-window line added
to API-MANUAL §17 (~:2499, `honestly shortened` 0→1). Lead verified all four greps
independently.
**Owner:** `clearskies-docs-author` (Sonnet). **QC:** `clearskies-auditor` at Gate H (doc rows).
**Scope (exhaustive list, from TC-24):**
(a) [briefs/SURF-ZONE-MODEL-BRIEF.md](briefs/SURF-ZONE-MODEL-BRIEF.md) §2.6 and
[briefs/STUDY-AREA-GEOMETRY-BRIEF.md](briefs/STUDY-AREA-GEOMETRY-BRIEF.md) §1/§5 still describe
the facing as isobath-gradient — add dated SUPERSESSION notes pointing to AD-1R (ADR-093
Amendment 5): setup-time smoothed-shoreline normal, operator-overridable. Briefs are records —
annotate, never rewrite the original text.
(b) TC-19: PROVIDER-MANUAL pier-TRANSM block vs AD-8 — verify current state at `732e87d` (the
§14.15 rewrites may have fixed it), fix if still stale.
(c) `ARCHITECTURE.md` L1 margin figure vs code (`+10 km` vs `+15 km`, TC-24 item 3).
**MUST NOT TOUCH:** code; the archived plans (their banners are final); decision-log history.
**Accept:** one commit, grep evidence pasted per item (the stale phrase count going to the
annotated count), coordinator QC before push.

### H4 — Marine event-loop stalls break the API proxy (the "dashboard surf is broken" defect)  ⬜
**Owner:** `clearskies-api-dev` (Sonnet), marine repo (+ API repo timeout knob if ruled in).
**QC:** `clearskies-auditor` at Gate H. **Sequencing (operator, 2026-08-02): model correctness
first — this ships after H1/H2 unless the operator pulls it forward. It GATES D4/D5 live
verification.**
**Evidence (2026-08-02, coordinator-diagnosed live):** the dashboard's surf pages 503 because
the API's companion proxy times out on the **TLS handshake** to the marine service
(`weewx-clearskies-api` journal: `Companion proxy: request to
https://192.168.7.22:8780/surf/... failed: _ssl.c:983: The handshake operation timed out`,
then `HTTP 503 ... marine service is unreachable`). Ruled OUT by measurement: network path
(TCP connects; 1472-byte DF pings pass; 8/8 probes handshake in 7–16 ms when the service is
idle), the SWAN binary (563% CPU during a probe run — handshakes still fast; it is a
subprocess), dashboard-side regressions (zero marine-component commits since 07-25). Ruled IN:
failures cluster exactly when the marine service's PYTHON side handles the ~206 MB forecast
cache (end-of-cycle publish serialization 01:51–02:01Z; large `/surf` reads 02:05–02:07Z) —
the single-process async service blocks its event loop for tens of seconds, TLS accepts starve,
the proxy's handshake timeout fires. Broken "this past week" because the cache grew ~10× with
full-length bands + 143-transect payloads.
**Design options (coordinator + operator pick at dispatch — moving where serialization runs
inside the same service is methodology; adding a worker/process is trigger 5, needs explicit
approval):** (a) stream/offload the big JSON serialization+file I/O to a thread
(`asyncio.to_thread`) at the publish and read paths; (b) incremental/chunked cache read on
request paths; (c) raise the API proxy's connect/handshake timeout (mitigation only, hides the
stall); (d) API-side response caching for `/surf` (already partially exists per the 503 detail
"no cached response is available" — investigate why the cache was empty).
**MUST NOT TOUCH:** cache CONTENT/shape; publish decision logic; the SWAN runner.
**Accept:** during an end-of-cycle publish AND a concurrent large `/surf` read, 10/10 probe
handshakes from weewx complete < 1 s; dashboard surf page loads live; zero proxy handshake
timeouts across ≥2 full cycles.

### H4 — status 2026-08-02: 🔶 DEPLOYED (`1f7374a`+`277b223`, proc 07:56Z) + accept SUBSTANTIALLY PASSED, two tracked residuals
**Live accept evidence:** read-path storm 20/20 handshakes 5.5-15.2 ms DURING 6 concurrent
large reads (incl. one 33 s cold /surf) — pre-fix this combination was the 503 storm;
publish-window storm 59/60 ≤27 ms with ONE 1.655 s outlier (localization pending: re-probe
next publish window with per-probe timestamps); dashboard chain live: profile-all via proxy
200/4.7 s/2.1 MB, /surf warm 200/0.46 s ×3. Audit PASS-WITH-FINDINGS (worktree byte-identity
both directions; stride-sleep necessity unproven by tests — kept as cheap insurance, live
numbers decisive). Residuals tracked: H5 (cold /surf), decode-side monolithic loads (ruled
out of scope; re-examine only if the 1.655 s outlier localizes to it).

### H5 — Cold /surf read exceeds proxy timeout once per cycle *(NEW 2026-08-02, found at H4 live accept)*  ⛔ OPERATOR DECISION (Stage 1 ✅ done)
**Owner:** `clearskies-api-dev` (Sonnet), investigation-first. **QC:** auditor at Gate H
addendum. **Defect:** the FIRST `/surf/{id}` after each forecast publish takes ~33 s → the API
companion proxy's 15 s read timeout → one 503 per cycle until a retry warms it (then 0.46 s).
Distinct mechanism from H4's handshake starvation (handshakes stay <30 ms throughout).

**H5 Stage 1 ✅ DONE 2026-08-02 (`l4-rewrite`, measurement-only, no edits). The task's
original hypothesis was WRONG — corrected by measurement:**
- Swelltrack/deep-structure deserialization is CHEAP: `swan.fetch()` is a single in-process
  cache lookup (no I/O, no JSON parse); live cache file (112.68 MB) has 100% swelltrack
  coverage for all 36 distinct forecast timestamps (zero fallback misses); the ~1.3 s
  `_load_forecast_cache_from_disk` decode runs once per PROCESS (startup), not per publish.
- **Actual root cause: surf.py's own HRRR wind fetch** (`endpoints/surf.py:658` →
  `providers/wind/hrrr.py`). On cache miss it downloads 19 sequential GRIB2 files (f00–f18,
  `_MAX_FORECAST_HOURS=18`) with `time.sleep(0.55)` NOMADS pacing between each. Cache key
  includes `cycle_time` (TTL 55 min) → every new HRRR cycle is a GUARANTEED first-request
  miss; and a new HRRR cycle is the SAME event that triggers each SWAN publish (causal
  correlation, two different cache keys — SWAN's own extended-cycle fetch does NOT warm
  surf.py's key). Live-measured from librewxr against real NOMADS: ~1.14 s/fetch × 19 ≈
  **21.7 s network+pacing alone** (GRIB2 parse/rotation unmeasured — the ~10 s gap to 33 s).
- H4-(d) proxy factors: companion proxy success-only caching CONFIRMED
  (`companion_proxy.py:466-558`, `cache.set` only on 200; stale-fallback served if a prior
  200 survived); shared-LRU eviction risk REAL under default `MemoryCache`
  (one process-wide TTLCache(1000) shared by ALL providers+proxy routes — stale fallback can
  be evicted early); dashboard query-param variance RULED OUT for `/surf/{id}` (zero params;
  note `/surf/{id}/profile` IS fragmented by two `transect_index` variants — adjacent,
  out of scope). Open items: (a) parse-cost gap unmeasured; (b) librewxr API host
  Redis-vs-MemoryCache unverified; (c) no live cold-miss capture (cycle timing 2 min–2h43).
**⛔ OPERATOR DECISION (2026-08-02, lead ruling on the agent's own flag):** the recommended
minimal fix — warm surf.py's HRRR cache key from the runner's post-publish step (same
function, same params/key as the request path; best-effort; needs byte-identical-key KAT +
called-once KAT + publish-never-blocked KAT) — is ARCHITECTURAL under triggers 5 (moves the
fetch's lifecycle stage: request-time → publish-time) and 6 (adds a publish-event trigger
for work that today runs only on client demand). The plan's own "warm at publish time"
candidate text is lead-written and does not authorize. Alternatives all trip triggers too
(reuse SWAN's wind data = data contract; cut forecast hours/bbox = fidelity criterion).
Known risks if approved: publish-path duration (+~20-30 s if synchronous; wants
fire-and-forget), bbox/key drift (the KAT above), NOMADS rate-limiter contention with
SWAN's own fetch.
**✅ OPERATOR APPROVED 2026-08-02 (chat: "h5 approve change")** — the publish-time HRRR
warming design is authorized as scoped above (same function, same params/key as
`endpoints/surf.py:658`'s request-time call; best-effort/never blocks or fails a publish;
must not delay the next cycle's start — non-blocking placement is a Stage-2 design
requirement, not an option). Required KATs stand: byte-identical-cache-key,
warmed-then-first-request-does-not-refetch, publish-never-blocked-by-warming-failure.
Stage 2 dispatches to `l4-rewrite` after its C2 round closes.

**✅ DEPLOYED 2026-08-02 19:26:23Z (marine `169b911`, clean window after the 19:25:05Z
cycle completion; /health+/manifest 200, auth enforced). Reality gate: warming thread
fired 7 s after startup (t18z f00... chain live), no new ERROR class (only the known
NOMADS not-yet-posted 404s), Lambert WARNING pre-existing (472 hits pre-deploy). Observed
live: the warming chain and SWAN's own extended chain fetch the same early files
concurrently at startup — the recorded LOW single-flight residual, bounded by the shared
rate limiter, accepted. Definitive post-hourly-rollover /surf timing check scheduled
(20:03Z watcher).**
**LIVE ACCEPT NUMBERS (20:03Z rollover probe + follow-up):** warm steady-state /surf =
**0.60 s** (was 0.46 s pre-H5 — unchanged class). The 20:03Z probe deliberately landed
inside the post-rollover warming window and hit the KNOWN no-single-flight race: the
request ran its own cold chain concurrently with the warming thread (t19z f00-f07 each
fetched ×2, rate-limiter interleaved) → **18.45 s** (was ~33 s). Honest residual exposure,
quantified: after each hourly key roll there is up to ~5 min until the next runner wake
(nothing warm yet) plus the ~30 s warming duration; a client request landing in that
window still pays a slow (~18-33 s) read and can exceed the proxy's 15 s timeout —
mitigated in practice by the proxy's 1800 s success-cache + stale-fallback (a user-visible
503 needs a poll in the gap AND an evicted stale entry). **Optional follow-up for
operator (NOT dispatched):** a single-flight guard (request-time fetch joins an in-flight
warming fetch for the same key instead of re-fetching) would remove the double-fetch and
the slow racing read; provider-behavior change → needs a nod. Accept-closed as deployed
otherwise.
**Stage 2 ✅ IMPLEMENTED 2026-08-02, marine `53b25d3` + remediation/Stage-3 `169b911`:**
`bbox_for_location()` shared helper in hrrr.py; surf.py:652-657 refactored onto it
(byte-identical); `_warm_hrrr_cache_for_locations()` + fire-and-forget daemon thread after
the full-cycle "complete" log (full-cycle branch only); 8/8 new KATs
(tests/test_h5_hrrr_publish_warming.py) covering all 3 required classes; 157-test
regression sweep green; adversarial audit in flight.
**⛔ NEW OPERATOR ITEM — partial coverage (mandatory verification finding, code-cited):**
surf.py's HRRR cache key rolls on WALL-CLOCK HOUR boundaries
(`_compute_hrrr_cycle(datetime.now(UTC))`, hrrr.py:641-666/771/803) — independent of
publish events. Full-cycle-only warming therefore fixes the post-publish 503 but NOT the
hour-boundary rollovers between publishes (publish gaps observed 2 min–2h43m): those first
requests still pay the full ~22-33 s cold fetch. Options for operator: (a) accept as-is
(reduces, does not eliminate, the 503s); (b) extend warming to every runner wake
(~5-min loop tick or the stationary-fill branch — a new trigger/cadence, architectural,
needs approval); (c) something else (e.g. pin the request-path key to the published cycle —
data-selection change, also architectural). Agent correctly held rather than deciding.
**✅ OPERATOR RULED 2026-08-02 (chat: "h5 b is fine"): option (b) approved** — warming
moves to every runner wake (~5-min tick, fire-and-forget unchanged; cache hit makes idle
ticks cheap — the fetch only actually fires when the hourly key rolls or TTL lapses).
Stage 3 dispatched with the audit's MAJOR remediation (wiring KAT). Audit record: PASS-
WITH-FINDINGS — 0 functional defects across 9 mutations; MAJOR = wiring-KAT gap
(remediation in flight); LOW residual RECORDED, no fix: no single-flight guard on
overlapping warming threads (rate-limiter-bounded, non-blocking; slightly more relevant at
5-min cadence, still acceptable — revisit only if NOMADS traffic becomes a concern).
Process note: the auditor deleted the stray untracked `test_claim2.py` during hygiene —
against the standing "never commit/delete" note; contents were an ad-hoc probe, loss
accepted, noted for the record.
**MUST NOT TOUCH (carries to Stage 2):** cache file shape, publish decisions, H4's
chunked encoder.

### ⛔ QC GATE H — assigned: `clearskies-auditor` (adversarial), BEFORE the lead gate
| # | Element | Evidence the auditor must independently produce |
|---|---|---|
| 1 | H1 KATs falsifiable | mutate each no-publish reason path in a scratch copy → test fails |
| 2 | No silent no-publish remains | force an H1.1-listed path live → health != ok + single ERROR |
| 3 | Serve-nothing guard untouched | diff of `4e79d21`-frozen files empty; G1R.0 test suite green |
| 4 | H2 cap holds under attack | mock a permanent 403 → bounded calls, cycle completes on cache |
| 5 | No fetch-content change | boundary bytes identical pre/post H2 on a recorded fixture |
| 6 | H3 claims true | re-grep every H3 item; no governing doc contradicts a ruling |
| 7 | Baseline diff clean | pre/post deploy baseline numbers (directive #2) within noise |
| 8 | H4 stall fix holds under load | auditor reproduces the failure recipe (probe storm during end-of-cycle publish + concurrent large `/surf` read) → 10/10 handshakes < 1 s |
**Charter:** assume the implementer cut corners; hunt can't-fail assertions (the Round-1 F1
pattern — a green test pinning a defective value); verify allowlists vs `git show --stat`.

---

## PHASE D — Small high-value fixes from the break-detection rounds

### D2 — Repair `test_serve_nothing_on_failure.py` (2 pre-existing failures) — **DO FIRST**  ⬜
**Owner:** `clearskies-test-author` (Sonnet). **QC:** auditor at Gate D.
The two failures (`AttributeError: 'SimpleNamespace' object has no attribute
'open_water_bearing_deg'`, broken since `51543b1`) mean the serve-nothing GUARD — load-bearing
for H1 — currently has dead tests. Fix the FIXTURE (add the missing field with a realistic
value; check for other fields added since) so the guard's tests run again.
**Files:** `tests/test_serve_nothing_on_failure.py` ONLY. **MUST NOT TOUCH:** the guard code
itself — if the repaired tests then FAIL against production code, STOP and surface (that would
mean the guard regressed unnoticed; do not "fix" either side without a ruling).
**Accept:** 9/9 in that file green at HEAD, zero production-code changes in the diff.

### D1 — Delete dead `_transect_band_depths()`  ⬜ (operator sign-off to dispatch — it is a
deletion round)
**Owner:** `clearskies-api-dev` (Sonnet). **QC:** auditor at Gate D.
Dead in production since the full-length-band rewrite (Round 1, `03b33e1`); deletion blocked by
`tests/test_swan_l4_intersection.py` imports. **Change:** delete the function from
`services/swan_runner.py`; update the importing tests to exercise the live band path (or delete
only the cases that exist purely to call the dead function — classify each in the scope-ack,
same discipline as R8). **MUST NOT TOUCH:** the live band-building code (`_TRANSECT_BAND_*`
constants, sentinel, grid-bbox clip — Round-1 frozen). **Accept:** grep shows zero references;
full targeted suite green; production run byte-identical (baseline diff, directive #2).

### D4 — Dashboard surf re-wiring, part 1: contract re-reconciliation + BD-7/BD-9 fields  ⬜
**(BLOCKED for live verification on H4 — code + tests can land first against fixtures.)**
**Owner:** `clearskies-dashboard-dev` (Sonnet). **QC:** auditor at Gate D.
**Investigation findings (2026-08-02, coordinator — the operator's memory is right):** the
piping EXISTS and was NOT reverted — zero dashboard marine-component commits since 07-25; the
surf pages consume `/surf/{id}`, `/surf/{id}/profile`, `/surf/{id}/profile?transect_index=all`
(`src/api/client.ts:457-494`), and `src/api/types.ts` already carries
`bestPeakFaceHeight`/`spotAverageFaceHeight`/`openTransectCount` (the 07-25 T4A.6
reconciliation). What broke is (a) transport — H4's proxy 503s — and (b) the marine payload
moving on under a frozen dashboard: everything shipped server-side 07-26→08-01 (HAT profiles,
R-phase, break-detection Rounds 1–2) landed after the dashboard's last reconciliation.
**D4.1 — contract re-reconciliation audit (read-only, report first):** diff
`src/api/types.ts` + `src/api/openapi-v1.yaml` against API-MANUAL @ marine `732e87d` for the
three surf endpoints. Known deltas to confirm and list: the 5 new BD-7/BD-9 fields
(`mainBreakZoneFaceHeight`, `mainBreakZoneStartIndex`/`EndIndex`,
`mainBreakZoneQualifyingCount`, `representativeTransectIndex`); `breakingFaceHeight` semantics
(now headline-fed); **TA-C19: `distanceFromShore` may be NEGATIVE since the HAT landward
extension (2026-07-30) — `types.ts` has no such field/handling and the profile charts may
assume ≥0** (prime suspect for vertical-section breakage beyond transport); any
`breakingFraction`/zones/`primaryBreak` deltas from Rounds 1–2. Deliverable: the delta table in
the scope-ack.
**D4.2 — type + rendering updates from D4.1's table:** additive types; zone context shown where
face height is shown ("main break zone: transects S–E, N qualifying" — presentation per
DESIGN-MANUAL tokens; no new dependencies, trigger 7); negative-`distanceFromShore` handled
wherever profile distances render.
**D4.3 (verify-only):** confirm the cross-section transect choice needs NO dashboard change
(BD-9 representative-transect selection is server-side in `beach_profile.py`) — evidence in
closeout, don't "fix" it.
**MUST NOT TOUCH:** API repo; marine repo; any non-surf dashboard page; the fetch layer
(`client.ts` endpoints are correct — H4 owns transport).
**Null-safety:** all new fields nullable (old caches) — render nothing, never `NaN`/`undefined`.
**Accept:** KATs against recorded current-shape fixtures (incl. a negative-`distanceFromShore`
profile and an old pre-Round-2 payload); axe-core pass; live render after H4 lands.

### D5 — Dashboard surf re-wiring, part 2: heatmap + vertical section back to live  ✅ DONE 2026-08-02 (dashboard `fe0b8e9`+`6bc0573` DEPLOYED to weather-dev; meta `54553ae`) — operator visual eyeball pending
**Round record:** D5.1 = EMPTY breakage list, evidence-backed, pinned with live-fixture tests
(real transect-4 double-break; negative distances now 143/143 transects — D4's axis fix
load-bearing). D5.2 = BD-7/9 overlays (purple gutter band + representative triangle + legend
+ sr-only/desc pairing). D5.3 = DASHBOARD-MANUAL "no heatmap" falsehood corrected as-built.
Audit round 1 PASS-WITH-FINDINGS: MAJOR value-vs-position overlay geometry (SVG used /surf
index VALUES as /profile array POSITIONS — diverges from the value-comparing sr-only table
whenever marine filters a failed transect; right-by-accident on contiguous data) + MINOR
unconditional font-weight breaking byte-identity. Remediation `6bc0573`: membership-based
positions (SVG+table agree BY CONSTRUCTION), conditional font-weight; re-audit PASS (gap-KAT
independently reproduced; mutation shows the exact 15px/1-row bug signature; byte-identity
proven vs TRUE pre-D5 baseline). Accepted LOW nuance: "partial-overlap-bands" test name
overstates solo coverage; class fully pinned by zero-overlap + gap-KAT siblings. 18/18 +
42/42 + tsc/build clean; axe = exactly the 2 known D9 dl violations, zero new.
**(Corrected 2026-08-02 — these products EXIST; the earlier "does not exist" note was wrong,
based on a DASHBOARD-MANUAL statement now known stale. Operator confirmed both were
implemented; verified in code.)**
**Owner:** `clearskies-dashboard-dev` (Sonnet). **QC:** auditor at Gate D. **Blocked on H4 for
live data; fixture work can start.**
**What exists (verified 2026-08-02):** `src/components/marine/tabs/HeatMapCard.tsx` — the
birdseye view (SVG grid, X = cross-shore, Y = transect index, colour = Hs) **already
double-break-aware** (`splitBreakPoints()` sorts outer/inner at `:153`); fed by
`/surf/{id}/profile?transect_index=all`. `src/components/marine/tabs/BeachProfileChart.tsx` +
`BeachProfileCardBody.tsx` — the vertical cross-section (impact/foam/reform zones per the
beach_profile payload). Both stale-frozen since 07-25, not reverted.
**D5.1 — re-wire verification (after D4.1's delta table):** replay a CURRENT recorded
`transect_index=all` payload through HeatMapCard and a current single-transect payload through
BeachProfileChart; list every render breakage (candidates: negative `distanceFromShore` axis
handling, zone-shape changes, `breakingFraction` nullability — `df60297` handled undefined,
verify against current). Fix render-side only.
**D5.2 — BD-7/BD-9 overlays (small, additive):** heatmap gains the main-break-zone band
markers (rows S–E from `mainBreakZoneStartIndex/EndIndex`) and a representative-transect row
marker; cross-section header states it renders the representative transect. Per DESIGN-MANUAL.
**D5.3 — DASHBOARD-MANUAL correction (doc-sync, same round):** the manual's "no heatmap
exists" claim is FALSE — correct it to describe HeatMapCard + BeachProfileChart as-built (this
is the H3-class doc-truth fix that misled this very plan).
**MUST NOT TOUCH:** marine/API repos; the data contract; non-surf pages.
**Accept:** both products render current live data end-to-end after H4; double-break fixture
shows two break markers in both views; manual corrected.

### D8 — Peel-direction chevron re-wire *(NEW 2026-08-02, found by D4.1's contract audit)*  ✅ **CLOSED 2026-08-02 (combined round with D9)**
**Round record:** dashboard `d667c7c` (5 files, +214/-34) + meta `9bec177` (API-MANUAL
peelClassification suffix truth + new peelDirection row). Chevron re-wired to the lead
decision table (closeout gates OFF first regardless of direction; right→›, left→‹,
a_frame→‹›, null/unrecognized→none) with sr-only i18n phrases; folded-in one-line
`_a_frame` fix in the 72h-row abbreviation; types.ts/openapi corrected to as-built
(13-value classification enum, closed peelDirection enum + nullable). ADVERSARIAL AUDIT
PASS 0 findings (auditor independently: closeout+right/left constructions, 13-value
arithmetic vs pipeline source, union-fallout grep [1 consumer], runtime-tolerance mutation,
dl DOM inspection, Tailwind Preflight margin proof, 3/3 mutations incl. own glyph-swap, 6
axe scenarios 0 violations). Lead gate: tsc clean, 16/16, build clean, stat matches.
DEPLOYED weather-dev (bundle index-C5xzLiyY.js, HTTP 200, config service active).
**Owner:** `clearskies-dashboard-dev` (Sonnet). **QC:** auditor at Gate D.
**Defect (PREMISE CORRECTED 2026-08-02, lead source-read + live query):** the original
finding said served `peelClassification` values are plain — that was a sampling artifact
(the D4 capture was all-closeout hours, and closeout is ALWAYS plain). Server truth
(`surf_1d_pipeline.py:750-786` + golden fixture + live 36/36 `closeout`+`a_frame`):
classification IS direction-suffixed (`fast_a_frame`, `fast_right`, `good_left`, …) when
direction is determined and class ≠ closeout; plain base when direction undetermined.
So the `.includes('right'/'left')` chevron is dead only for `a_frame` (and, correctly,
closeout) — still a real defect, narrower than first stated. `peelDirection`
(`right|left|a_frame|null`) is computed independently and served even on closeout hours
(the pipeline docstring claiming "always None for closeout" was false — doc-only fix,
marine `1967a74`). API-MANUAL:2526 stale twice over (plain-only values, no peelDirection
row) — corrected in this round's doc-sync. D4's types.ts "plain, undirected" comment gets
re-corrected here too.
**Sequencing:** D4 Stage 2 lands the CONTRACT half (adds `peelDirection` to types.ts+openapi,
corrects the stale `peelClassification` doc comment). This task is the RENDER half only:
re-wire the chevron to consume `peelDirection`, with a per-value rendering decision table
(incl. `a_frame`) written by the lead at dispatch. **MUST NOT TOUCH:** anything beyond the
chevron block + its test. Blocked on D4 Stage 2 landing.

### D9 — SurfingTab definition-list a11y structure fix *(NEW 2026-08-02, found by D4's first-ever axe scan of this markup)*  ✅ **CLOSED 2026-08-02 — same round/commit as D8 (`d667c7c`)**
3-stats block restructured to 3 mini-`<dl>`s (outer dl→div grid preserved, icon a sibling,
each dl = exactly dt+dd). Axe: the 2 known definition-list/dlitem serious violations → 0;
0 total across 6 scenarios (auditor-verified incl. own missing-data scenario). Visual
byte-identity proven via Tailwind v4 Preflight universal margin reset. See D8 record.
**Owner:** `clearskies-dashboard-dev` (Sonnet). **QC:** auditor at Gate D (axe re-scan row).
**Defect (pre-existing, WCAG 1.3.1 serious ×2):** SurfingTab.tsx "T6.1: 3 stats" block
(`<dl class="grid grid-cols-3 ...">`, ~:2229) nests each `<dt>`/`<dd>` two `<div>` levels deep
— axe: `definition-list` + `dlitem` violations. Never caught before because no tab-level test
file existed until D4 created SurfingTab.test.tsx. The sibling flex-row pattern elsewhere in
the file (4 other sites) is NOT in a `<dl>` and is not affected. **Fix:** restructure this ONE
block so dt/dd associate correctly (direct children, or `<div role="presentation">`-free
grouping per axe's allowed content model) with zero visual regression (grid classes preserved).
**MUST NOT TOUCH:** anything beyond this block + its test. **Accept:** axe scan of SurfingTab
render = 0 violations; visual snapshot/build unchanged; targeted vitest green.

### D10 — Phantom SurfForecast fields = three silently-dead dashboard features *(NEW 2026-08-02, D4-audit MINOR finding, lead-escalated after cross-repo greps)*  ⬜
**Owner:** investigation = `Explore`/read-only agent (API-repo git history); disposition =
OPERATOR DECISION; any code = its own scoped round. **QC:** auditor at the owning gate.
**Finding chain:** D4's audit flagged `partitionBreakInfo`, `shadowFaceHeight`,
`waveShapeClassification` as having no live evidence (67-entry capture) and no API-MANUAL
doc. Lead greps 2026-08-02: ZERO occurrences in the ENTIRE marine repo AND the API repo —
the server has never (currently) emitted these names. BUT the dashboard carries null-guarded
RENDER code for all three (`SurfingTab.tsx:1483` wave-shape chip, `:2154-2180` shadow face
height, `:2350+` per-partition break rows) — three features that silently never render, the
same failure class as D8's chevron. Origin claims in types.ts: T7.2b/T7.3 era. The marine
service DOES serve a documented `perPartitionBreaks` (types.ts:1880's own comment calls it
"related but separate").
**D10.1 ✅ DONE 2026-08-02 (Explore agent, full-graph `git grep` across every ref of both
server repos):** NONE of the three was EVER server-side — but they are NOT dead speculation.
`docs/archive/SURF-1D-IMPLEMENTATION-PLAN.md:1443` records all of them (T7 closeout) as an
explicit "Deferred / awaiting API" list of 8 SurfForecast fields, of which the API
subsequently implemented SIX (API `eef56fd` T4.4 → marine `fa1c482` T5.9, live today).
These are the unfinished stragglers of a documented catch-up — same symptom class as D8's
chevron, OPPOSITE disposition evidence. Per-field: `partitionBreakInfo` = dashboard `c021bc3`
(T5.4, mis-targeted at T5.2 which put the data on beach-profile as `perPartitionBreaks` —
types.ts:1880's "related but separate" documents an accident, and openapi:3664's "populated
by surf.py" is false); `shadowFaceHeight` = `292216e` T7.3 (aggregate over
`is_structure_affected` transects — data at surf.py:1197 call site today);
`waveShapeClassification` = `292216e` T7.2b (peel+Iribarren live on PipelineResult, but
Stokes/cnoidal `WaveShape.regime` is NOT — real plumbing + the 4-way cut points were never
implemented anywhere).
**D10.2 (OPERATOR DECISION — three rulings needed, investigator recommends RESTORE for all):**
1. `partitionBreakInfo`: restore by emitting the EXISTING `perPartitionBreaks` shape on
   SurfForecast and re-pointing the dashboard type at it (kills the duplicate schema —
   investigator-preferred), or build the dashboard's bespoke shape? (Data-contract choice.)
2. `shadowFaceHeight`: is a non-headline shadow AGGREGATE a legitimate consumer of
   `is_structure_affected` under BD-8's metadata-only demotion? (Investigator: yes — BD-8
   removed headline aggregation roles; this is a secondary readout.)
3. `waveShapeClassification`: authorize as a REAL scoped round (regime threading + coding the
   4-way classification cut points from SURF-1D-IMPLEMENTATION-PLAN.md:1227-1234 — those
   thresholds are new formula criteria, trigger 1, and need explicit approval), or defer/pin?
**MUST NOT TOUCH until ruled:** the three render blocks, the type/openapi entries.
**Doc fixes queued for the D10 round (from investigation):** openapi:3664 false claim,
openapi:3295 wrong date, this section's original T7.2b/T7.3-only origin attribution
(partitionBreakInfo is T5.4).

### D11 — Test-order pollution: tide-level tests leak state into health tests *(NEW 2026-08-02, found during H4, confirmed pre-existing via git-stash baseline)*  ✅ DONE 2026-08-02 (marine `92c2743`)
**Round record:** root cause = `services/invariants.py` module-level firing counters never
reset between test files (its `reset_invariants_for_tests()` existed but was uncalled);
health's degraded-floor read them. Fix: 3-line conftest wiring into the existing autouse
reset fixture. Falsifiability: 2-file repro failed pre-fix (2F/12P); post-fix 4-file H1 set
45/45 in BOTH orders (lead re-ran both independently). Zero production code touched.
**Owner:** `clearskies-test-author` (Sonnet). **QC:** auditor at Gate D.
**Defect:** running `tests/test_surf_tide_level.py` BEFORE `tests/test_no_publish_reasons.py`
or `tests/test_health.py` in one pytest session → 3 spurious failures (`assert 'degraded' ==
'ok'`); each file green in isolation. Likely a missing autouse state-reset fixture (marine
`state.py` module-level registries persist across test files). **Fix:** shared reset fixture
(conftest-level autouse or equivalent) so file order never matters; prove by running the
polluting order green. **MUST NOT TOUCH:** production code; assertions of existing tests.
**Accept:** the previously-failing order passes; full combined run of the 4 files green both
orders.

### ⛔ QC GATE D — assigned: `clearskies-auditor`
| # | Element | Evidence |
|---|---|---|
| 1 | D2 zero production-code diff | `git show --stat` = one test file |
| 2 | D1 truly dead code | pre-deletion grep proves no live caller; post run byte-identical |
| 3 | D4 null-safety | replay an OLD (pre-Round-2) cached payload through the dashboard → clean |
| 4 | No API-repo drift | marine repo HEAD unchanged by D4/D5 work |

---

## PHASE V — Validation gates (evidence collection; weather-dependent rows stay OPEN)

**Owner:** coordinator runs V1/V2/V4 measurement; V3 is an agent. **QC:** V-rows are themselves
the QC — each requires pasted numbers, matched-time, quantity chosen before looking
(rules/verification.md). Method reference for matched-time ground-truthing:
[briefs/T3.0-BOUNDARY-GROUNDTRUTH-2026-07-30.md](briefs/T3.0-BOUNDARY-GROUNDTRUTH-2026-07-30.md).

### V1 — Gate GR: reality re-validation of the NEW headline  ⬜
The headline changed 2026-08-01 (BD-7 upper-tail zone mean). At the next ordinary conditions:
paste served `breakingFaceHeight` (+ zone fields) beside the contemporaneous cam/Surfline at
matched hour; tolerance stated BEFORE looking; also confirm headline sits between
`spotAverageFaceHeight` and `bestPeakFaceHeight` (INVARIANT_10 live check) and zone width ≥5.
Closes C6 (T1.3) with the same evidence. **Accept:** within tolerance at ≥1 real sea state.

### V2 — Standing weather-dependent gates  ⬜ (non-blocking; close each at first qualifying day)
- **Multi-swell day:** §11.3 combined-face + BD-7 headline validated vs reality; auditor CLAIM-2
  (dominant-by-energy divergence) same day. *(T2.3 residual, G7.3.)*
- **HB double-break day** (outer break ~mid-pier, spec §4.1): per-transect data + representative
  cross-section show BOTH zones; handoff seaward of the outer (log evidence); headline from the
  bigger face; merge-threshold behavior observed (tune ONLY if zones fragment, spec §6.4).
- **Larger-seas magnitude revalidation** (validated at ~1 m only so far).

### V3 — Formal blind audit of the served forecast  ✅ **RUN 2026-08-02 — 7 findings, triaged below; follow-up tasks V3-F1/F2/F4/F7 + doc batch**
**Owner:** `clearskies-auditor` (fresh instance, briefed on MANUALS ONLY — no session history,
no this-plan access; that blindness is the point). Audits one live served forecast end-to-end
for internal consistency + reality agreement; findings ranked. Anything it finds that the
manuals can't explain is, definitionally, either a defect or doc drift — both are deliverables.
This is also the backstop for anything the archived separation plan left genuinely unfinished.

**RESULT (fresh `v3-blind-auditor`, 36-entry live payload, saved to scratchpad
surf.json/profile.json):** PASSED a substantial invariant set (additive scoring identity
36/36; ÷1.27/×0.5 breaker formulas exact; headline/best-peak/average ordering 36/36;
SWAN-vs-NDBC frequencyRange convention; profile transectIndex 32 == representativeTransectIndex;
/health coherent; NDBC 46222 Hs within pre-stated ±30% [0.72 vs 0.91 m]; Surfline band match).
**7 findings, lead-triaged:**
| # | Sev | Finding | Lead triage |
|---|---|---|---|
| F1 | BLOCKER | 32 h hole mid-forecast (Aug 3 00Z→Aug 4 06Z absent, not null-padded) | REAL + mechanism pinned by lead journal read: GFS wind fetched ONLY f048-f072 of the 06Z cycle (its designed far-window, "9 forecast hour(s)" 13:04:49Z) while HRRR (near/mid window) hit NOMADS 404s — t12z files past f11 not yet posted at 13:04Z → wind coverage 0-11 h + 48-72 h, hole = unfetched 12-47 h. Cycle published anyway. → **V3-F1 task** |
| F2 | MAJOR | swellDominance bimodal {0.2, 0.6} ≠ documented energy ratio (true ratios 0.38-0.54); propagates ×7.5 into score | REAL discrepancy vs manual — code-read needed (binned score vs ratio?) → **V3-F2 task** |
| F3 | MAJOR | Undocumented served fields: top-level `waterTemp`, per-entry `peelDirection` | peelDirection: KNOWN, D8 doc-sync landed meta `9bec177` same day (auditor read pre-commit manual); §18 table may still lack it. waterTemp: genuine doc gap → **doc batch** |
| F4 | MAJOR | `forecast[].breakPoints` null 36/36 while waves actively break + /profile serves real break points | Likely dead legacy single-transect QB path (pre-SwellTrack); needs disposition (populate-vs-document-vs-remove is operator territory if contract changes) → **V3-F4 task** |
| F5 | MINOR | `metadata.verticalDatum` = "LMSL" live vs manual "always null" | Doc drift (claim predates a fix) → **doc batch** |
| F6 | NOTE | Two waterTemps differ 4.7 °C in one payload (resolver 24.7 vs SRF hand-typed 20.0) | Explained by documented provenance; fold provenance note into waterTemp doc → **doc batch** |
| F7 | NOTE | organizationWind 16.5 > documented 15-pt cap (6/36, all "glassy"); additive identity intact | Likely undocumented glassy bonus; code-read then doc fix (or defect report) → **V3-F7 task** |
**Lead-added F8 (journal read, same session):** NDBC provider 404s repeating every ~5 min
since ~14:11Z (station realtime file) — not V3-flagged, needs a look (station file moved/
retired vs transient). Folded into V3-F2/F4/F7 investigation round.

### V3-F1 — Mid-forecast wind-coverage hole  ⬜ (investigation → likely OPERATOR for any fix)
Marine: establish the wind-window design (HRRR near + GFS f048+ far — where is the 12-47 h
mid-window supposed to come from when HRRR extended files aren't posted yet?), whether a
prior-fully-posted HRRR cycle fallback exists/should exist (cycle-selection change would be
ARCHITECTURAL — investigation reports, operator decides), and whether publishing with a
mid-hole is intended "honest serving" (then manuals + dashboard chart continuity must say
so: DASHBOARD-MANUAL claims "continuous across day boundaries") or a defect.

### V3-F2/F4/F7 (+F8) — Scoring/legacy-path code-read  ✅ **INVESTIGATED 2026-08-02 (Explore agent + lead live checks) — dispositions below**
**F2 (swellDominance): DOC DRIFT ×2, code is deliberate.** `_swell_dominance()`
(surf_scorer.py:355-374) computes the energy ratio then BUCKETS it: >0.8→1.0, ≥0.5→0.6,
else→0.2 (0.5 no-data default) — only the bucket is served. And the ratio itself is
"all partitions with period >10 s / total", NOT "primary/total" as API-MANUAL:2049 claims.
`organizationSwellDominance = swellDominance × 7.5` (0.25 weight × 30). **Disposition:
doc-batch corrects manual + API-repo responses.py:1672 comment to as-built. If the
operator would rather serve the true ratio, that's a formula change — say so in chat.**
**F4 (breakPoints): ALIVE-BUT-STARVED + doc drift; reconciliation = OPERATOR.** The QB
peak-picker (surf_pipeline_timestep.py:149-169, threshold 0.25) runs on SWAN CURVE points
— but the SWAN domain's shoreward edge is ~1.78 m (design contour; HB CURVE spans
3.40–15.8 m), so at today's Hs≈0.35-0.7 m QB≈0 everywhere seaward of the real break →
permanently null except big-swell days. No commit killed it (unchanged since `fa1c482`).
/profile's breakPoints = DIFFERENT producer (SwellTrack 1D pipeline, continues to shore,
richer schema) — same field name, two unrelated producers. **Disposition: doc-batch fixes
the manual's null-cause list (add "SWAN domain terminates seaward of the small-swell break
line"); whether /surf should serve the pipeline's break points instead (contract change,
trigger 4) is an OPERATOR decision — flagged.**
**✅ OPERATOR RULED 2026-08-02 (chat): use the 1D model.** "Once the handoff happens we
should be using the better 1D model for actually generating data" — /surf's breakPoints
re-sources from the SwellTrack 1D pipeline. → **NEW TASK V3-F4-IMPL below.** Lead-proposed
contract (minimal ripple): populate from the REPRESENTATIVE transect's pipeline break
points (same transect /profile renders), keep the existing wire shape
`{distance, depth, hs}` (map faceHeight→hs? NO — hs stays Hs at the break point; schema
additions only if the operator asks); update API-MANUAL row + null-cause list in the same
round. The legacy SWAN-CURVE QB picker path retires from this field.
**F7 (organizationWind): DOC DRIFT, code deliberate.** Glassy wind score = 1.1
(surf_scorer.py:212, ×15 = 16.5); offshore-light = 1.2 (max 18.0). Scorer docstring
anticipates >nominal-max multipliers. ADR-096's "15% effective" table and API-MANUAL:2073
"0–~15" are wrong as written; true range 0–18. **Disposition: doc-batch.** CAVEAT
(recorded): waveOrganization rounds to 0 dp while sub-factors round to 1 dp independently
— the additive identity is not guaranteed by construction (can drift ~0.2-0.3); held 36/36
today by luck. Track as a NOTE, not a defect, unless the operator wants construction-true.
**F8 (NDBC 404s): ROOT CAUSE CONFIRMED BY LEAD LIVE PROBE — case-sensitivity.** The
huntington-harbor location's `ndbc_station_ids` is stored lowercase `['prjc1']`; NDBC's
file server is case-sensitive: `realtime2/prjc1.txt` → 404, `PRJC1.txt` → 200 (probed
2026-08-02). Compounded by a code defect: `fetch()`'s 404 propagates BEFORE any cache
write (ndbc.py:959-983) → no negative caching → every ~5-min dashboard poll re-404s.
**Disposition: (i) config fix — uppercase the station ID (operator or wizard re-push;
also check whether wizard DISCOVERY stored it lowercase — if so that's a wizard bug to
fix); (ii) proposed small code hardening — normalize station IDs to uppercase at config
parse (matches NDBC's documented ID format) ± negative-cache the 404; BOTH are behavior
changes on a provider → operator nod requested.**

### V3-doc-batch — API-MANUAL corrections from V3  ✅ **DONE 2026-08-02 (doc-sync, 8 items)**
Meta commit `3c084ec` (items 1-7; landed under the lead's commit via a benign staged-file
sweep — all items verified complete, ledger in closeout) + API repo `f10e8ce` (item 8,
pushed): swellDominance bucketed truth (+API-repo comment), organizationWind 0-18 truth +
waveOrganization rounding-identity note, breakPoints null-cause + dual-producer interim
text (superseded when V3-F4-IMPL lands), verticalDatum as-built, waterTemp §16+§18 +
provenance, §18 gains all three peel rows, clearskies-dev.md services table → unified
marine service :8780, TC-2/TC-3 archive headers restored + TC-12/13 numbering note.
**Flagged follow-up (new doc task, not yet dispatched):** repo-directory listings in
clearskies-dev.md (~:98-129) + ARCHITECTURE.md "Current deployment" paragraph still
describe the superseded split swan/compute topology — dedicated verified doc round.

### V4 — Forecast window 66 h vs 72 h *(TA-C16)*  ✅ **CLOSED — operator ruled 2026-08-02:
accept as-is.** The honest shorter window when the newest GFS cycle is unpublished is correct
behavior, not a defect. One residual: H3's doc sweep adds a line to API-MANUAL stating the
window is "up to 72 h, honestly shortened when the newest GFS cycle is not yet published."

---

## PHASE G6 — Two-stage setup geometry: OSM bootstrap → bathymetry refine *(AD-6, rewritten)*

**Why (operator, 2026-08-02):** solves the setup-time chicken-and-egg — you can't know which
bathymetry tiles to download until you know roughly where the coast runs and which way the
water faces. Stage 1 = cheap OSM answer; Stage 2 = authoritative bathymetry answer; self-check
catches bad inputs at setup, before the model runs on them.
**Design references:** [briefs/STUDY-AREA-GEOMETRY-BRIEF.md](briefs/STUDY-AREA-GEOMETRY-BRIEF.md)
(study-area geometry model; read WITH its H3 supersession notes), archived geometry plan §AD-6
(history), ADR-100 (geography subsystem), ADR-093 Amendment 5 (AD-1R facing — Stage 2's method,
FROZEN, not re-derived here).

### G6.1 — Stage wiring in the sizing chain  ⬜
**Owner:** `clearskies-api-dev` (Sonnet). **QC:** auditor at Gate G6.
**Current state to verify first:** `services/grid_sizing_chain.py` — establish (read-only
report) the CURRENT order of: geography fan (`geography.py`), L1 sizing, bathymetry
availability checks, AD-1R facing, transects, L3/L4. Name where the bathymetry download
footprint is decided today.
**Change:** enforce the two-stage order as an explicit chain structure: Stage 1 (OSM coastline
+ water-body classification + 72-ray fan + provisional facing → freeze L1 + download
footprint) then Stage 2 (bathymetry-derived AD-1R facing, transects, L3/L4 from the Stage-1
footprint). This is an ORDERING/wiring change of existing steps — creating new computation or
changing any formula inside a step is NOT in scope and NOT pre-approved.
**MUST NOT TOUCH:** the AD-1R facing math; the fan math; L1/L3/L4 sizing formulas; SWAN
emission. **Accept (KAT):** chain-order test proves L1 params are fixed before any bathymetry
read; Stage 2 provably consumes the Stage-1 footprint (assert on the passed bbox).

### G6.2 — OSM-vs-bathymetry heading self-check  ⬜
**Owner:** `clearskies-test-author` (Sonnet), after G6.1.
**Change:** at config-push, compare Stage-1 provisional facing vs Stage-2 AD-1R facing; |Δ| >
threshold → WARN + persisted flag surfaced in `/health` (additive field) and the wizard/admin.
Threshold: reuse TC-8's existing 30° diagnostic constant — introducing a NEW constant is an
architectural trigger; if 30° proves wrong, surface to operator.
**Accept (KAT):** synthetic agreeing pair → no flag; synthetic divergent pair (>30°) → WARN +
flag; flag visible in `/health` fixture test.

### G6.3 — Wizard polygon draw tool *(confirmed 2026-08-02: UI feature — closed-polygon drawing)*  ⬜
**Owner:** `clearskies-dashboard-dev` (Sonnet; stack repo).
**Current state:** wizard map draws polyline only (`templates/wizard/step_marine.html`,
`polygon:false` ~`:1287`, `L.Draw.Polyline` ~`:1456` — verify, cites from 2026-07-30).
**Change:** enable `L.Draw.Polygon` alongside the polyline; captured ring goes into the existing
`_coordinates` hidden field, SAME `[lon,lat]` JSON-string contract (T4.5 round-trip guard is
the regression net — run it). Purpose: operator hand-draws closed outlines (study area /
structure rings) where OSM tracing is wrong or missing.
**MUST NOT TOUCH:** the apply/config contract shape (the JSON-string encoding decided at E13 is
frozen); the polyline flow. **Accept:** polygon draw → apply → marine config round-trips
byte-faithfully (T4.5 test extended with a polygon case); polyline flow byte-identical.
**Wizard/admin parity (operator, 2026-08-02):** the polygon draw tool must be available in
BOTH the wizard map step and the corresponding admin panel editing surface — scope-ack must
name both call sites (or the shared component both render).

### ⛔ QC GATE G6 — assigned: `clearskies-auditor`
| # | Element | Evidence |
|---|---|---|
| 1 | Stage order real, not cosmetic | trace a config push on librewxr: download footprint decided before any bathymetry read (journal) |
| 2 | No formula drift | AD-1R facing + fan outputs byte-identical pre/post G6.1 on the HB fixture |
| 3 | Self-check falsifiable | mutate the divergent-pair fixture → test fails |
| 4 | Polygon contract safe | T4.5 round-trip green incl. polygon; polyline path diff empty |
| 5 | Full-nest regression | one full 4-level run post-deploy: valid_fraction / resolution counts match baseline |

---

## PHASE C — Carry-forwards (small; mostly verify-then-close)

### C1 — Concerns sweep  ✅ **EVIDENCE + DISPOSITIONS 2026-08-02 (Explore sweep `c1-concerns-sweep`, coordinator dispositions below; OPERATOR rows await chat)**
**Owner:** `Explore`-type read-only agent produces the evidence; coordinator writes dispositions;
operator rules the OPERATOR-DECISION rows. Reference for TA-C21:
[briefs/T4.4-SHADOW-DIAGNOSIS-2026-07-30.md](briefs/T4.4-SHADOW-DIAGNOSIS-2026-07-30.md).
Full evidence (file:line for every claim) in the sweep agent's report, session 2026-08-02.

**Working-model concerns (TA-C*):**
| Entry | Disposition |
|---|---|
| TA-C21 | CLOSED-with-evidence: rescope ALREADY LANDED (`6a8c18e`+`2597011`, G4.6) — invariant 3 now fires only on unevaluable structures, KAT-guarded. **OPERATOR paper-trail residual:** confirm G4.6's rescope WAS the criterion change you meant to sign off (code is done either way). |
| TA-C22(a) | CARRIED → C4 (unchanged code, ruled thresholds ready). |
| TA-C22(b) | Code path unchanged, but plausibly SUPERSEDED by `2087fc1`+`4e79d21` (no-L4-intersection now routes to L2 instead of empty components). Needs ONE live-cache observation to close — lead action at next convenient cycle. |
| TA-C20 | CLOSED: both residuals implemented (T2.2 PART B truncation-follows-advanced-sample; T2.3 §11.3 combined metric verbatim). Larger-seas validation caveat → carried in V2. |
| TA-C19 | CLOSED: dashboard D4.2 (`xMin = Math.min(0, ...)`, comment cites TA-C19). |
| TA-C18 | CLOSED: ADR-093 Amendment 4 implemented (signed subaerial + HAT landward stop + shortfall guard) + manual. Live full-tide-cycle sanity → carried in V2-adjacent observation. |
| TA-C16 | CLOSED: `a68215d` monotonicity + operator V4 ruling (accept-as-is); doc line landed via H3. |
| TA-C15 | CLOSED: wizard+admin DO send coordinates (routes.py:2972-2983, step_marine.html, admin/marine.html) + API decode `9d1c10a`. Live api.conf durability unverified — minor. |
| TA-C14 | **STILL-OPEN (real):** forced-full-run on unchanged HRRR cycle still silently no-ops as success (service.py:363/:461-468 clears signal on clean return; 4 DEBUG bare-returns in `_run_all_spots_locked` :2308-2331). → NEW TASK C8 below. |
| TA-C12 | STILL-OPEN as filed (convergence-gate pooling; single-spot HB can't bite; R7.2 narrowed L4 to PT_ tables). Keep parked; revisit at multi-spot. |
| TA-C11b | CLOSED: header/token match proven statically + real valid_fraction values recorded. |
| TA-C06 | #3 CLOSED (norm_end positive-completion check, self-citing); #2 stays open-deferred (low reachability, acknowledged). |
| TA-C05 | Unconditioned follow-on; trigger (sub-task F collapse) never occurred. Keep parked. |
| TA-C04 | SUPERSEDED (target doc archived). |
| TA-C08 | Informational; trace is gated off in prod. Parked. |
| TA-C03 | reference/clearskies-dev.md port drift — folded into the next doc-batch (verify 8767/8770 vs 8780 and fix). |
| TA-C01 | CLOSED: M1PASS converged artifact exists (close condition met). |

**Geometry concerns (TC-1..20):** TC-6 SUPERSEDED (`73df829` deleted isobath ray-fit);
TC-7/TC-15 CLOSED (G1.6 + G3 write-back + C7 `cbcfbb1`); TC-16 CLOSED (re-verified);
TC-18 SUPERSEDED (`4e79d21` removed exposure from L4 sizing); TC-19 CLOSED (H3 `40a557c`);
TC-9/TC-14/TC-8/TC-5/TC-11/TC-20 STILL-OPEN-low/trivial (parked, as filed; TC-11
docstring-only); TC-10 mitigation landed (timeout+5 retries), mirror/self-host decision
open → stays with H2.4 disposition; TC-4 parked pending any G2.4 (Great Lakes) dispatch.
**File-integrity finding:** TC-2/TC-3 lost their `##` headers in a past edit (two orphaned
`**What:**` blocks inside TC-4's section, :90-99); TC-12 exists only as a cross-reference;
TC-13 absent entirely. → doc-batch repairs the archive file's headers (content preserved).
**TC-17 → RESOLVED BY LEAD LIVE CHECK 2026-08-02:** deployed marine.conf has NO
`directional_exposure` key for either location — the operator's E/SE/S/SW override is
absent, fan-derived in force. **OPERATOR: re-add the override or accept fan-derived?**

**Restoration C-E survivors + D7:** C-E01 partially superseded (AD-1R + persisted-key
override; pre-chain `_perpendicular_bearing` +90° fallback remains; Bolsa live check
deferred until Bolsa deploys); C-E03 STILL-OPEN (no transect-count cap; **OPERATOR:
spacing value before any Bolsa deploy**); C-E04 parked (efficiency-only, as downgraded);
C-E08 STILL-OPEN-low (L4 INPGRID WIND coverage — needs with/without comparison before any
fix, as filed); C-E10 = C7a (same env-var/firewall decision, already OPERATOR-pending);
C-E11 premise-contested (C-E12 says clock is real, C-E11 says future-dated — **OPERATOR:
settle the clock question**, no code action either way yet); C-E12 partially resolved
(option (b) ruled out by T3.0 byte-faithful proof; residual = the 2-D freq×dir watershed
check, parked); D7 parked-to-cutover (confirmed no length/quality gate at the store site —
policy question intact for Phase 5).

### V3-F4-IMPL — /surf breakPoints re-sourced to the 1D pipeline  ✅ **CLOSED 2026-08-02 — deployed + live-verified**
**Round record:** marine `f925d77` (surf.py sourcing block + `_break_points_for_representative_transect()`
helper, strict index match, all-partitions seaward-first, wire shape {distance, depth, hs}
unchanged; 10 KATs incl. end-to-end cache-hit path + mutation check) + meta `2a284ec`
(API-MANUAL rewrite + pre-existing waveHeight→hs doc error fixed). AUDIT PASS-WITH-FINDINGS:
0 functional defects; /profile point-set agreement proven by shared-fixture SET equality
(the operator's intent, by construction); 2 LOW doc notes (null-semantics third-disjunct
precision — fold into next doc pass; commit-msg §-slip). Lead gate: independent 28/28.
DEPLOYED 20:17:00Z, reality gate: **55/55 live entries serve pipeline break points** (was
null 36/36 forever; rep idx 35, e.g. {9.84 m, 0.78 m depth, 0.57 m Hs} + inner break
{1.25 m, 0.44 m, 0.32 m} — outer+inner bars now visible on the wire).
**Owner:** `clearskies-api-dev` (Sonnet). **QC:** auditor before lead gate.
Per the operator ruling in §V3-F2/F4/F7: `forecast[].breakPoints` populates from the
SwellTrack 1D pipeline's REPRESENTATIVE transect break points (the same transect /profile
renders — consistency by construction), replacing the starved legacy SWAN-CURVE QB picker
for this field. Wire shape UNCHANGED (`{distance, depth, hs}` — map the pipeline break
point's distance/depth/Hs; no schema additions this round). Null only when the pipeline
produced no break points for the representative transect that hour. Same round: API-MANUAL
row rewrite (producer, null semantics — supersedes the doc-batch's interim null-cause
text), KATs (populated-at-ordinary-conditions is the headline acceptance — the old path
was null 36/36 at Hs≈0.5 m; new path must serve the same break points /profile shows).
**MUST NOT TOUCH:** /profile's own producer; the pipeline itself; select_reference_point's
OTHER consumers (reference-point choice stays as-is — only the breakPoints field re-sources).

### C9 — Re-add HB directional_exposure override + explicit override labeling  ⬜ *(OPERATOR-APPROVED 2026-08-02)*
**Ruling (chat):** "we should add back in the direction override BUT we need to be clear
that these are overrides." Two halves:
**(a) Config re-add (ops action, lead):** restore HB's operator-set override
`directional_exposure = E/SE/S/SW` (stripped by the Gate-G3 live test, TC-17) to the
deployed marine config via config push; verify `directional_exposure_is_override=true`
honored and the serve-time directional filter reflects it.
**(b) UI labeling (stack repo, wizard/admin PARITY rule applies):** the exposure field in
BOTH wizard step_marine and admin marine must be clearly labeled as an OVERRIDE of the
fan-derived (measured) exposure — states: "Auto (measured coastline fan)" vs "Manual
override"; show which is in effect; help content keys (`help.wizard.*`/`help.admin.*`) +
Operator Manual per doc-code sync. No behavior change to the fan default (G3.3 stands:
fan-derived is the default; the override is optional and honored if present).
`clearskies-api-dev`, small scoped round: a forced full run that inner-no-ops (4 DEBUG
bare-returns in `_run_all_spots_locked`, swan.py:2308-2331) currently clears
`force_full_run_signal` and reads as success. Fix per the original entry's option list
(make the no-op loud and/or not clear the signal) + KAT asserting a forced run on an
unchanged cycle actually executes or fails loudly. Dispatch after H5 deploys.

### C2 — D6a re-verify *(G7.1)*  ✅ **CLOSED 2026-08-02 (branch: GONE — already fixed)**
`l4-rewrite` grep-relocation + lead spot-check: D6a WAS the real bug and was fixed
2026-07-28 by marine `29eb499` ("iterate StructureConfig.coordinates as attribute, not dict
.get()" — the study-area bbox block iterated `spot_cfg.structures` with
`_struct.get("coordinates", [])` on dataclass objects). Fix confirmed still in place at
HEAD (grid_sizing_chain.py:1821-1822, attribute access; lead re-read). The archived cite
"grid_sizing_chain.py:1270" is stale from post-fix insertions (H1's
`_record_l3_viability_failures` + 1787b6a/5524e1f/38f93ac); current :1270 is unrelated
shoreline-strip bathymetry content. Full consistency sweep: exactly 2 raw structure-access
sites in the file (attr at :1822 on StructureConfig; `.get` at :2122 on the dict-shaped
`build_obstacle_structures()` output) — the two shapes never cross; every consumer typed
and accessed to match (swan.py:1143-1179, swan_domain.py:336-380, bathymetry.py:2105-2169,
transect_handoff.py:298-316 all verified). `_record_l3_viability_failures` (H1-gated)
touches no structure fields directly — no STOP needed. Zero code changes; repo clean.
Evidence banks to Gate C.

### C3 — Cadence/performance lever *(G7.4; approved + gate-cleared 2026-07-30)*  ⬜
**Owner:** `clearskies-api-dev`. Hourly 0–24 then ~6-hourly to 72 (~52% fewer solves,
~41→~25 min). Producer-only: `swan_formats.py` compute-list + TABLE output schedule — a VALUE
change, no command-grammar change (SWAN syntax appendix rules apply; local manual
`docs/reference/swan-user-manual.txt` is the only SWAN reference). Pre-verified 2026-07-30: the
whole chain is timestamp-driven — re-confirm in scope-ack (grep consumers for uniform-spacing
assumptions). **MUST NOT TOUCH:** hotstart mechanics, convergence gate, anything per-grid.
**Accept:** KAT on the emitted compute list; full run wall-clock measured before/after; all
V1-style baseline numbers unchanged at the shared hours.

### C4 — modelStatus grading *(G7.5 / TA-C22(a))*  ⬜ — **UNBLOCKED: threshold rule
operator-APPROVED 2026-08-02 (chat, "yes unblock") — ready to dispatch as a normal scoped round**
**What "fallback" means here — VERIFIED in code, and it is NOT grid routing:** a transect's
handoff level (L4 vs L3 vs L2, `handoff_source_level`) is legitimate routing — a transect that
doesn't intersect an L4 grid is SUPPOSED to use L2; never counted as degradation (operator
reaffirmed 2026-08-02). The fallback C4 grades is the **bulk-parameter fallback**
(`surf_1d_pipeline.py:1314-1332`): a transect with NO measured per-transect spectral partitions
(PT*) at its handoff point that hour runs the 1D model on three bulk scalars (Hs/Tp/Dir)
instead of its real measured spectrum — a genuine measured→approximation degradation, logged
per-transect ("bulk-falling-back for THIS transect only").
**The defect:** today even ONE bulk-fallback transect sets `degraded=True` for the whole result
(`:1655`) → the entire spot-hour serves `modelStatus="degraded_bulk"`. 1 of 143 transects on
scalars should not brand the whole hour degraded.
**RULED rule (operator-approved 2026-08-02):** `ok` = 0 bulk-fallback transects; `partial` =
≥1 but <25% AND no main-break-zone qualifying transect among them; `degraded_bulk` = ≥25% OR
any qualifying-zone transect on bulk scalars (the headline is built from those transects, so
their degradation degrades the headline's trustworthiness). Then a normal scoped round
(`endpoints/surf.py` `_determine_model_status` + pipeline bookkeeping + KATs; wire semantics
change → API-MANUAL same round).

### C7 — Bimodal beach_facing + non-surf endpoint anomalies *(NEW 2026-08-02, found during H4 live accept)*  ⬜
**Owner:** `clearskies-api-dev` (Sonnet) investigation-first. **QC:** auditor at Gate C.
**Evidence (coordinator, 2026-08-02):** `compute_spot_transects` logs BOTH
`beach_facing=216.4°/29 structure-affected/114 open` (every SWAN-cycle line, all day, matches
prior days) AND `beach_facing=240.0°/25/118` (interleaved, sometimes duplicated same-ms lines
= concurrent second computation). 240.0 count: Jul 30/31 = 0, Aug 1 = 0, first hit Aug 2
00:33:24Z under PID 2358409 (pre-Phase-H process, commit `732e87d` era) — NOT caused by
today's deploys. One 240.0 hit at 05:25:26 same-second with `HTTP 502 /fishing/...` +
`CLEARSKIES_MARINE_API_URL is not set` (that ERROR class: 11 hits on Aug 1, also
pre-existing). Hypothesis to verify, not assume: a non-surf endpoint path (fishing /
beach-safety) computes its own transects using the operator-typed config facing (240.0)
instead of the AD-1R derived value (216.4), and began firing ~00:33Z Aug 2 (what changed —
config push? first request? cache expiry?). **Scope:** find the 240.0 caller + its facing
source (file:line); why it started Aug 2; whether any SERVED value consumes the 240.0
transects; the CLEARSKIES_MARINE_API_URL unset + fishing-502 chain. Report first; fixes are
their own scoped round. SWAN/surf path confirmed unaffected (216.4 stable through all
deploys).
**INVESTIGATION ✅ DONE 2026-08-02 (l4-rewrite, read-only). Findings:**
(1) 240.0° = the segment-perpendicular FALLBACK (`marine_config.py:527-533`,
`beach_facing_source="fallback_segment_perp"` — no `beach_facing_degrees` key in
marine.conf). The AD-1R 216.4° correction is applied by grid_sizing_chain via the setter,
IN-MEMORY ONLY (deliberate: "config is operator-owned; only the wizard rewrites the stored
key", marine_config.py:643-646) — the SWAN runner's long-lived config object keeps it;
`endpoints/surf.py:764` + `beach_profile.py:995` fresh-parse config PER REQUEST
(`_resolve_marine_config`, deliberate "until a config-push invalidation hook" per its own
docstring) and always recompute 240.0.
(2) Started 00:33Z Aug 2 because /beach-profile had never been requested in journal
retention (dashboard 503-dark since ~Jul 26); first-request event (Round-2's own live
verification), not a state change.
(3) **WRONG DATA IS SERVED:** beach-profile responses — ALWAYS (no cache-hit path);
`/surf`'s SurfBeat fields (`setTimingMinutes`/`setAmplitudeM`/`igWaveHeightM`) — ALWAYS
(gated on surfbeat_enabled only); headline metrics — only on SWAN-cache MISS (cache-hit path
serves the correct 216.4° precompute). Frequency shielded by the API proxy's 1800 s cache.
(4) `CLEARSKIES_MARINE_API_URL`: never set on librewxr (neither env file); C-47 (`5b52ede`,
Jul 25) added hard-require consumers (station-wind + fishing solunar → 502); INDEPENDENT of
the facing anomaly (same-second hits were one page load's parallel fetches). CONFIG.md:52
actively misleads ("unset is normal/silent" — pre-C-47 truth).
**→ C7a (small scoped round, ready):** set `CLEARSKIES_MARINE_API_URL` in
`/etc/weewx-clearskies/marine/network.env` (correct URL value to be confirmed against
api_client.py's expectations at dispatch) + CONFIG.md correction (two unset behaviors).
**→ C7b (OPERATOR DECISION — facing-divergence fix shape):** (a) persist AD-1R value into
marine.conf — conflicts with the operator-owned-config boundary (G1R.3's domain); (b) config
invalidation hook / share runner's corrected object — trigger-5-adjacent; (c) thread the
persisted per-transect `transect_bearings` (grid_sizing_chain) into the endpoints'
compute_spot_transects call — same computation, better input, likely non-architectural,
NEEDS a design-first data-availability check. **Lead recommendation: (c) design-first; fall
back to an (a)/(b) ruling only if (c)'s data isn't reachable without a new persisted field.**
**C7b ✅ FIXED + DEPLOYED 2026-08-02** (marine `cbcfbb1`+`b5a4d01`, proc 09:41:05Z): option
(c) — persisted `transect_bearings` (already in spot_profiles/{id}.json, 143 entries
216.2-221.6° live-verified) threaded into both endpoints; beach_profile also gained the
scalar correction it never had (shared helper). Audit PASS (4 mutations caught incl. the
module-global-coupling probe; fallback path proven byte-identical vs pre-change worktree).
LIVE: beach_profile request now logs `beach_facing=216.4°/29/114` (was 240.0°/25/118 on
every request). 12 KATs + 119-test regression subset green.
**C7a — UNBLOCKED 2026-08-02, ready to dispatch (queued behind V3-F4-IMPL, same repo):**
(1) **Firewall FIXED by operator** (librewxr 192.168.7.22 added to `weather-api-src`
addr-list 12:23; rule 58 `weather-api-src`→`weather-api-dst`:8765 covers it). Lead
verified: TCP connect 2 ms; API answers HTTPS with problem+json; correct base path is
`/api/v1` (`/api/v1/current` → 200).
(2) **Remaining blocker found: TLS.** API cert is self-signed `CN=clearskies-api`, NO
SANs → httpx default verification fails for any hostname. Deployed precedent for exactly
this: api.conf `marine_verify_tls = false` (API→marine direction, §19.2 secure-default
pattern).
(3) **✅ OPERATOR APPROVED 2026-08-02 (chat: "a"): mirror the pattern.** Scoped round:
new env key `CLEARSKIES_MARINE_API_VERIFY_TLS` (default `"true"` = secure; `"false"`
honored) wired into BOTH API-talking call sites (`services/api_client.py:get_json` and
`config/__init__.py:fetch_config_from_api`), KAT-pinned both values + default; then lead
deploy-time: set `CLEARSKIES_MARINE_API_URL=https://192.168.2.121:8765/api/v1` +
`CLEARSKIES_MARINE_API_VERIFY_TLS=false` in `/etc/weewx-clearskies/marine/network.env`,
restart (cycle-window discipline), verify solunar/station-wind 502s cease. CONFIG.md +
OPERATIONS-MANUAL document the new key same round.

### ⛔ QC GATE C — assigned: `clearskies-auditor`
C1's report spot-audited (pick 3 CLOSED rows, independently re-verify); C2/C3 rounds get the
standard adversarial pass (falsifiable KATs, allowlist diff, baseline diff).

---

## PHASE LM — Landmark spatial context for the heatmap *(operator-requested 2026-08-02, in chat — supplements D5 and G6.3)*

**Why (operator):** the heatmap has no scale or landmarks — users can't tell where on the
beach it represents. Two anchors fix that: identified shoreward structures (the HB pier)
rendered as a labeled line, and operator-drawn non-structural markers (e.g. a guard tower)
rendered as labeled markers. **Contract authorization:** the additive `landmarks` payload
field (trigger 4) and the non-structural marker config key (trigger 7) were explicitly
requested/approved by the operator 2026-08-02 in chat. **Hard rule: landmarks are
DISPLAY-ONLY — nothing in this phase may feed SWAN, the 1D model, transect selection, or any
physics path. Markers are not structures; they emit no OBSTACLE, affect no flag.**

### LM-1 — Marine: landmark projection + additive payload  ⬜
**Owner:** `clearskies-api-dev` (Sonnet, marine repo). **QC:** auditor (standard adversarial
round). **Blocked on:** nothing (structures already in config; marker config may land later —
design for both kinds now, structures first).
**Change:** at config push, project each configured structure (and, once LM-3 exists, each
non-structural marker) from its geographic geometry into the transect frame: alongshore span
→ inclusive transect index range; cross-shore span → distance range in the SAME
distance-from-reference metres the profile payload uses (negatives allowed landward, HAT
convention). Serve as an additive top-level `landmarks` array on the
`/surf/{id}/profile?transect_index=all` response (and nowhere else):
`{label, kind: "structure"|"marker", transectStartIndex, transectEndIndex, distanceMinM,
distanceMaxM}`. Label for structures = the structure's configured name/type (e.g.
"Huntington Beach Pier"). Old-cache tolerance: absent key = no landmarks (never raise).
**Files (verify at dispatch):** the transect-frame owner (`services/swan_formats.py`
`compute_spot_transects` region — VALUES/metadata only, zero emission-grammar changes) or a
new small `services/landmarks.py` (preferred — keeps swan_formats untouched); the profile
endpoint serializer; cache codec if the projection is cached; tests.
**MUST NOT TOUCH:** OBSTACLE emission, `is_structure_affected` production, transect
generation itself, anything in the frozen core beyond read-only imports.
**KATs:** (a) synthetic pier polyline perpendicular to a known transect frame → exact
expected index range + distance range; (b) structure fully outside the frame → no landmark,
no error; (c) old cached payload without `landmarks` → endpoint serves absent key cleanly;
(d) projection is byte-stable across two identical config pushes.
**Accept:** live `transect_index=all` payload for HB carries the pier landmark with plausible
bounds (spot-check vs the 29 structure-affected transect indices); zero diff in every other
payload field (baseline diff).

### LM-2 — Dashboard: heatmap landmark overlay + alongshore scale *(supplements D5)*  ⬜
**Owner:** `clearskies-dashboard-dev` (Sonnet). **QC:** auditor at Gate D (axe row included).
**Blocked on:** LM-1 deployed (fixture work can start from LM-1's KAT fixtures).
**Change (HeatMapCard only):** (a) render each `landmarks[]` entry as a labeled line — the
centerline of its (transect-range × distance-range) box along the box's long axis; label
text beside it, i18n'd, `aria-label`ed, DESIGN-MANUAL tokens, no new dependencies; (b) add
the alongshore scale: Y-axis ticks in metres (transect index × the served spacing — use the
real per-spot spacing from the payload if present, else 10 m constant with a code comment),
plus end labels derived from the transect frame's endpoint bearing (e.g. "NW end"/"SE end");
(c) null-safety: no `landmarks` key (old cache) → render exactly today's chart.
**MUST NOT TOUCH:** the Hs colour mapping, `splitBreakPoints()`, BeachProfileChart (landmark
overlay is heatmap-only this round), the fetch layer.
**KATs:** fixture with the HB pier landmark → line + label at the expected rows/columns
(assert coordinates in-canvas); fixture without `landmarks` → byte-identical render to
pre-change snapshot; axe pass on the new markup.
**Accept:** live render post-H4 shows the pier line + label + metre scale; operator
eyeball-confirms the pier lands where the real pier is.

### LM-3 — Wizard: non-structural labeled markers *(supplements G6.3; blocked on G6.3)*  ⬜
**Owner:** `clearskies-dashboard-dev` (Sonnet, stack repo). **QC:** auditor at Gate G6.
**Change:** extend G6.3's polygon/draw tool with a "marker" mode: operator draws a small
polygon (or drops a point) + REQUIRED label field → persisted in marine config under a NEW
`landmark_markers` key (same `[lon,lat]` JSON-string encoding contract as E13 — do not
invent a new encoding), applied via the existing apply flow. Markers are display-only
metadata: the apply path must NOT create structures, OBSTACLE lines, or any model input.
LM-1's projection picks them up on the next config push.
**Wizard/admin parity (operator, 2026-08-02 in chat — binding on this task AND general):**
the marker draw/label/edit capability must work in BOTH the setup wizard AND the admin panel
— not wizard-only. The same rule applies to every setup-time function this plan adds or
touches (G6.3's polygon draw included): any capability offered at setup must be reachable
post-setup from admin. Where the wizard and admin already share an implementation surface,
reuse it; where they don't, the task's scope includes both surfaces. (Doc-sync: record this
parity principle in the OPERATIONS-MANUAL wizard/admin section at this task's round close —
verify first whether it is already stated there.)
**MUST NOT TOUCH:** the structure/study-area draw flows (G6.3's polygon contract frozen once
landed); anything that feeds the model.
**KATs:** T4.5-style round-trip: draw marker + label → apply → marine config carries it
byte-faithfully → re-open wizard shows it; apply with markers present produces ZERO diff in
every SWAN input file (the display-only guarantee, asserted).
**Accept:** operator draws a guard-tower marker on the dev wizard, it round-trips, and (with
LM-1/LM-2 live) appears labeled on the heatmap.

**Sequencing:** LM-1 → LM-2 (pier + scale ship first — most of the user value); LM-3 lands
with/after G6.3, then markers flow through the same LM-1/LM-2 path with zero further work.

---

## PINNED (operator-ruled, not scheduled — do NOT dispatch)

- **G5 — break-type from shoreline curvature → L3 trigger** *(AD-5)* — **PINNED 2026-08-02
  (operator, in chat):** the 72-ray fan + AD-1R facing likely solved most of what G5 was for
  (orientation/exposure understanding of the beach). **Operator clarification (same day): L3 and
  L4 are inseparable — whenever L4 exists, L3 MUST exist as the L2→L3 step-down that keeps
  SWAN's nesting grid ratios; there is no standalone "should L3 exist" decision on a structure
  spot.** The trigger question G5 addressed therefore only applies to the STRUCTURELESS
  curved-shore case (a point break / headland / bay with no L4, where the fine nest would be
  wanted for the shore shape alone) — and that case still reads the operator-typed
  `topographic_feature` config field, which is acceptable for now. Revisit ONLY if a real
  structureless spot mis-grids on setup (that event un-pins it; then: evaluation first, per the
  archived plan's §G5.1–G5.3, trigger-only change, L3 emitter untouched).
- **G1R.3 — wizard facing pre-fill flow** *(AD-1R UX)* — not urgent (the chain recomputes facing
  at config-push regardless). Bundle with G6.3's wizard work if the operator wants it then.
- **D3 — tmpfs peak headroom** *(known limitation, recorded)*: `_check_convergence` reads all
  TABLE_PT before the unlink loop → peak ~170 MB/cycle unchanged by parse-and-delete. No action
  unless a bigger config trips the box.
- **D7 — publish policy** — parked to cutover (Phase 5 of the Clear Skies plan).
- **C5 — Track-B sign-off designs** *(T4.2 bathymetry injection; T4.3 dynamic coefficients)* —
  **PINNED 2026-08-02 (operator, in chat): add later only if ever needed** (a spot with a
  submerged breakwater / DAM-crest structure). Each requires an operator-signed design doc
  BEFORE any code (standing gate). References:
  [briefs/BATHYMETRY-STRUCTURES-BEST-PRACTICES-2026-07-29.md](briefs/BATHYMETRY-STRUCTURES-BEST-PRACTICES-2026-07-29.md),
  [briefs/SWAN-OBSTACLE-BEST-PRACTICES-2026-07-29.md](briefs/SWAN-OBSTACLE-BEST-PRACTICES-2026-07-29.md).

---

## Closed-with-evidence at consolidation (2026-08-02) — do not reopen

| Item | Evidence |
| --- | --- |
| **T2.2 PART B** (QB seaward move didn't advance `handoff_depth_m`) | Fixed marine `4e0a0ba`; rule extended to the BD-2 constraint path in `ea62e85` |
| **Phase F wind-sea 1D term (F1–F5)** | Implemented 2026-07-28 (`7002ed1`, `a802fdd`, `466b1a0`, `d1b3583`), wired in `surf_1d_pipeline.py`, KATs green 2026-08-01; operator ruled keep-as-done 2026-08-02 |
| **R5 BOUNDSPEC `[len]` units** | Deployed `5581b0a`, measured on librewxr 2026-08-01 |
| **R8 test audit** | `TEST-INVENTORY.md` in the MARINE repo (`5874578`), 58 tests classified; stale KAT removed `cb0fe57` |
| **TC-21 / TC-23** (L4 coverage vs handoff envelope) | L4 transect-shadow-envelope rewrite `4e79d21`; valid_fraction 100% live 2026-08-01 |
| **Gate R rows 1–4, 6, 7** | Final record in `archive/MARINE-MODEL-RESTORATION-PLAN.md` §QC GATE R |
| **Break-detection Rounds 1–2** (BD-1/2/4 + bands; BD-7/9 + BD-8 retirement) | Marine `03b33e1..b60ef92`, `9719db1`+`732e87d`, both deployed; docs meta `07bee6b`, `6f3c6c7` |
| **Marine service separation** | Unified service live on librewxr:8780 (ADR-099, `deploy-marine.sh`); plan archived 2026-08-02 as overtaken |

## Decision log

- **2026-08-02 (autonomy grant + H4 pick).** Operator, in chat: "ok continue autonomously
  with plan implementation." Under that grant, with the coordinator's recommendation twice
  surfaced without objection: H4 proceeds as option (a) same-service serialization offload
  (to_thread for GIL-releasing I/O + chunked-yield for GIL-bound encode, decided by Stage-1
  measurement) + the (d) API-side cache investigation (read-only this round); option (c)
  timeout raise rejected as stall-hiding. H1's forced-degraded live drill proceeds via
  temporary grid-sizing-cache rename on librewxr (reversible, one cycle attempt), sequenced
  AFTER the next natural cycle completes so H2's two-cycle evidence stays clean. Phase LM
  added same day (landmarks; operator-authorized contract additions) with wizard/admin parity
  binding on LM-3/G6.3 and recorded as a general setup-function requirement.

- **2026-08-02 (execution, round H1+D2) — D2 closed; H1 code-complete + audited.** D2: marine
  `e8646d2`, fixture-only (one kwarg), serve-nothing suite 2F/7P → 9/9, lead-verified
  independently; Gate-D row-1 evidence banked. H1: Sonnet implementer (scope-ack with full
  no-publish enumeration first) → adversarial audit FAIL (found the uninstrumented
  production-reachable GFS-wind refetch abort — the exact silent-abort class H1 targets) →
  remediation `2491ada` → re-audit PASS with a 13-exit full-function re-sweep. Lead rulings
  during the round are recorded in §H1's round record: grid_sizing_chain.py allowlist
  extension (plan-internal contradiction resolved in favor of H1.3's own spec + KAT (b)),
  H1.4 satisfied-by-H1.3 (admin template renders reasons[] generically), health precedence =
  floor-at-degraded/never-downgrade-failed, two separately-cleared registries. The 02:30Z
  routine cycle (pre-deploy baseline) was clean: main_zone on all timesteps, headline ≤
  best_peak, zero bulk-fallbacks, zero ERRORs.

- **2026-08-02 — Plan created.** Operator approved the three-plan triage in chat: working-model
  archived (fully superseded); restoration status-corrected (Phase F/R5 markers were stale) and
  archived with Gate R substantively passed; geometry plan closed with G4/AD-4 superseded and
  remainder extracted here. Operator rulings same session: Phase F stays wired (done, not
  revisited); G6 rewritten in plain terms (this file's §G6 supersedes the archived AD-6/G6
  wording); G6.3 confirmed as the wizard polygon draw tool.
- **2026-08-02 (final) — V4 closed, C4 ruled + unblocked.** Operator: V4 accept-as-is (honest
  shorter window is correct behavior; doc line via H3). C4 threshold rule APPROVED after the
  fallback definition was clarified (bulk-parameter fallback only — L4/L3/L2 handoff routing is
  legitimate selection, never graded as degradation): ok = 0 bulk-fallback; partial = <25% and
  no main-break-zone qualifying transect; degraded_bulk = ≥25% or any qualifying transect.
- **2026-08-02 (later still) — D4/D5 investigation + H4 added + C5 pinned.** Operator flagged
  that the dashboard heatmap/vertical-section WERE implemented and surf is currently broken.
  Coordinator live-diagnosed: (1) dashboard NOT reverted (no marine-component commits since
  07-25; old piping intact in types.ts/client.ts); (2) the break is the API companion proxy's
  TLS handshake timing out against the marine service during its big-JSON event-loop stalls
  (206 MB cache publish/reads) — new task H4 with the full evidence chain (TCP/MTU/SWAN-binary
  ruled out by measurement); (3) HeatMapCard is already double-break-aware; D5's "product does
  not exist" note was wrong (stale DASHBOARD-MANUAL claim — correction folded into D5.3);
  (4) TA-C19 (negative distanceFromShore) never reached the dashboard — named prime suspect for
  vertical-section render breakage, folded into D4.1/D5.1; (5) C5 pinned per operator.
- **2026-08-02 (later) — Granularized + G5 pinned + separation plan archived.** Operator: (1)
  G5 pinned — the ray fan + AD-1R facing likely solved most of its purpose; only the L3-trigger
  residue remains, acceptable until a real spot mis-grids; (2) `MARINE-SERVICE-SEPARATION-PLAN.md`
  archived as overtaken (too old to triage; V3 blind audit + C1 sweep are the backstop for any
  genuinely-missing pieces); (3) plan rewritten to granular per-task specs with agent
  assignments, per-phase adversarial QC gates (`clearskies-auditor`), brief cross-references,
  and the PRIME-DIRECTIVE anti-regression rules (frozen-core list, baseline-diff, one change
  per deploy, reality gate per deploy).
