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

## PHASE H — Operational hardening

### H1 — No-publish paths must be loud and truthful *(was Restoration R4; Gate R row 5)*  🔶 CODE-COMPLETE + AUDITED (2026-08-02) — live check pending deploy
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

### H2 — Upstream fetch hygiene: WW3/NOMADS (+ same-class audit) *(was Restoration R6)*  🔶 CODE-COMPLETE + AUDITED (2026-08-02) — live check (≥2 cycles) pending deploy
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

### D5 — Dashboard surf re-wiring, part 2: heatmap + vertical section back to live  ⬜
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

### V3 — Formal blind audit of the served forecast  ⬜
**Owner:** `clearskies-auditor` (fresh instance, briefed on MANUALS ONLY — no session history,
no this-plan access; that blindness is the point). Audits one live served forecast end-to-end
for internal consistency + reality agreement; findings ranked. Anything it finds that the
manuals can't explain is, definitionally, either a defect or doc drift — both are deliverables.
This is also the backstop for anything the archived separation plan left genuinely unfinished.

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

### C1 — Concerns sweep  ⬜
**Owner:** `Explore`-type read-only agent produces the evidence; coordinator writes dispositions;
operator rules the OPERATOR-DECISION rows. Triage every still-OPEN entry in
`archive/MARINE-WORKING-MODEL-CONCERNS.md` (TA-C21 — invariant-3 rescope, operator decision,
note BD-8 made the flag metadata-only; TA-C22(b) transect-31 PT* gap) and
`archive/MARINE-GEOMETRY-MODEL-CONCERNS.md` (TC-1..TC-20; TC-10→H2, TC-19→H3) and the
restoration concerns' C-E survivors (C-E01/03/04/08/10/11/12, D7 parked-to-cutover).
**Accept:** one report; every entry CLOSED-with-evidence / CARRIED-to-named-task /
OPERATOR-DECISION. Reference for TA-C21: [briefs/T4.4-SHADOW-DIAGNOSIS-2026-07-30.md](briefs/T4.4-SHADOW-DIAGNOSIS-2026-07-30.md).

### C2 — D6a re-verify *(G7.1)*  ⬜ — `clearskies-api-dev`: the `grid_sizing_chain`
StructureConfig-vs-dict bug's old cite is stale; grep-relocate; if found → failing-first guard
test + fix; if gone → close with the grep evidence. Files: `services/grid_sizing_chain.py` +
one test file. Nothing else.

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

### ⛔ QC GATE C — assigned: `clearskies-auditor`
C1's report spot-audited (pick 3 CLOSED rows, independently re-verify); C2/C3 rounds get the
standard adversarial pass (falsifiable KATs, allowlist diff, baseline diff).

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
