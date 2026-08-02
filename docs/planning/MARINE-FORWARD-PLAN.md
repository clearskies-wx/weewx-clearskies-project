# Marine Forward Plan — consolidated live work (2026-08-02)

**Created:** 2026-08-02 (operator-approved consolidation, in chat)
**Status:** ACTIVE — this is the ONLY live marine planning document. Everything else in
`docs/planning/` marine-wise is archived history.
**Supersedes / consolidates:** the still-open remainders of three archived plans —
`docs/archive/MARINE-MODEL-RESTORATION-PLAN.md` (R4, R6, R9/R10 residuals),
`docs/archive/MARINE-GEOMETRY-MODEL-PLAN.md` (G1R.3, G5, G6, G7, Gate GR),
`docs/archive/MARINE-WORKING-MODEL-PLAN.md` (nothing directly — its survivors flowed through
the geometry plan's G7) — plus the deferred items from the 2026-08-01 surf-zone break-detection
rounds (`briefs/SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01.md`, Rounds 1–2 both DEPLOYED).

**Where we are (2026-08-02):** the model WORKS. Full 4-level SWAN nest converges (L4
valid_fraction 100%), 143 transects × all forecast hours resolve their own handoffs, the 1D layer
detects breaks at physically correct depths (including real double-breaks), publish + reality gate
PASS, and the BD-7 main-break-zone headline + BD-9 representative transect are live (marine
`732e87d`). This plan is hardening, validation, and the remaining geometry-automation features —
**not** model recovery.

**Standing process (operator mandates, carried forward):** implementation by a **Sonnet coding
agent**; **adversarial QC agent pass BEFORE the lead gate** on every round; doc-sync pass closes
every round (CLAUDE.md doc-code sync); architectural-change block per CLAUDE.md — the trigger
list binds every task here; local commits, push/deploy only on operator grant.

---

## H — Operational hardening

### H1 — No-publish paths must be loud and truthful *(was Restoration R4; Gate R row 5)*  ⬜
**Owner:** `clearskies-api-dev`. **Original task detail:** archived restoration plan §R4 — read it.
**Summary:** every path that ends a cycle publishing nothing must (1) log ONE ERROR naming the
reason, (2) set B3 `/health` `status != ok` with a `reasons` entry, (3) show on the admin status
page. Config-push viability failures surface via `/health` too. **Must not touch** the
serve-nothing-on-failure guard itself (G1R.0 stands). **Accept:** forced degraded cycle →
`degraded`/`failed` health, never silent `ok` + no-publish.

### H2 — WW3 fetch hygiene *(was Restoration R6)*  ⬜
**Owner:** `clearskies-api-dev`. **Original task detail:** archived restoration plan §R6.
**Summary:** exponential backoff + per-cycle retry cap on NOMADS station-spectra fetches
(403/404 hot-retry loops observed in the July 30–31 journals); a cycle running on cached
boundary data logs it and reflects it in `/health` `inputs.ww3_boundary` (age + available).
**Accept:** blocked NOMADS never hot-loops; staleness visible in `/health` without the journal.
**Note:** TC-10 (public Overpass API flakiness in the geography fetch, raise-no-fallback) is the
same failure class — fix or explicitly defer it in this task's closeout.

### H3 — Residual doc-truth sweep *(was Restoration R9+R10 residuals; Gate R row 8)*  ⬜
**Owner:** `clearskies-docs-author` (coordinator QC). The 2026-08-01 doc passes (meta `d4a71ca`,
`07bee6b`, `6f3c6c7`) covered most of R10's list. Remaining, from TC-24: (a) facing
method-of-record still described as isobath-gradient in `briefs/SURF-ZONE-MODEL-BRIEF.md` §2.6
and `briefs/STUDY-AREA-GEOMETRY-BRIEF.md` §1/§5 — correct to AD-1R (setup-time smoothed-shoreline
normal, operator-overridable), as supersession notes (briefs are records: annotate, don't
rewrite history); (b) TC-19's stale PROVIDER-MANUAL pier-TRANSM block vs AD-8 — verify current
state, fix if still stale; (c) verify `ARCHITECTURE.md` L1 margin figure matches code.
**Accept:** grep evidence pasted per item; no governing doc contradicts a ruling.

---

## V — Validation gates (some weather-dependent — they stay OPEN until the ocean cooperates)

### V1 — Gate GR: reality re-validation of the NEW headline *(was Geometry Gate GR + T3.1)*  ⬜
The headline definition changed 2026-08-01 (BD-7 main-break-zone upper-tail mean). Re-run the
matched-time reality comparison against the cam/Surfline **on the new headline field**
(`mainBreakZoneFaceHeight` → served `breakingFaceHeight`), comparison quantity chosen before
looking (`rules/verification.md`). Also re-assert: no flat output; a full 4-level run converges.
**Accept:** pasted matched-time comparison within stated tolerance, ≥1 real sea state.

### V2 — Standing weather-dependent gates  ⬜ (open until first qualifying day; non-blocking)
- **Multi-swell day** *(T2.3 residual + G7.3)*: validate the §11.3 combined-face metric + BD-7
  headline on a genuine multi-swell day; auditor CLAIM-2 check (dominant-by-energy divergence)
  same day.
- **HB double-break day** *(break-detection spec §4.1)*: first swell that puts an outer break
  ~mid-pier — verify cross-section (representative transect) and per-transect data show BOTH
  break zones, handoff seaward of the outer, headline from the bigger face. Check the break-zone
  merge behavior the same day (spec §6.4 — tune ONLY if zones fragment).
- **Larger-seas magnitude revalidation** *(G7.3)*: magnitude was validated at ~1 m swell only.

### V3 — Formal blind audit of the full served forecast *(G7.3, M1 closure)*  ⬜
One adversarial agent, briefed on the manuals only (not the session history), audits a live
served forecast end-to-end for internal consistency + reality agreement, and reports findings.

### V4 — Forecast window: 66 h vs 72 h *(TA-C16)*  ⬜
GFS staleness fallback shortens coverage honestly. Decide: accept + document the honest window,
or add a fill strategy. Small, operator-decision-shaped.

---

## G — Geometry remainder (extracted from the archived geometry plan)

### G1R.3 — Wizard facing flow *(AD-1R definition-time UX)*  ⬜
**Owner:** `clearskies-api-dev` + `clearskies-dashboard-dev`. **Original detail:** archived
geometry plan §PHASE G1R. **Summary:** `/geometry/facing` endpoint + API pass-through + apply
models + wizard pre-fill so the computed AD-1R facing shows at spot setup, operator-overridable.
Not urgent (the chain recomputes facing at config-push regardless) — UX completeness.

### G5 — Break-type from shoreline curvature → L3 trigger *(AD-5)* — ⬜ **EVALUATE FIRST**
**Operator framing (2026-08-02, chat):** the point of G5 is a better understanding of the shape
of the beach and how waves come in, to best align the grids and model the break-type. **Before
any code: an evaluation task** — does deriving point-break/headland/bay from measured shoreline
curvature still add value on top of what now works (AD-1R facing + AD-2 fan + shadow-envelope
L4)? Concretely: today L3 fires off the operator-typed `topographic_feature` config field; G5
would derive it from geometry and demote the config field to an override.
**Step 1 (coordinator + operator):** pick 2–3 real candidate spots (a point break, a bay) and
check whether the current pipeline mis-grids them without G5. If yes → implement per archived
§G5.1–G5.3 (KAT-gated, L3 emitter untouched — trigger-only change) **carefully, without
disturbing the working chain**; if no → close G5 as not-beneficial with the evidence.

### G6 — Two-stage setup geometry: OSM bootstrap → bathymetry refine *(AD-6, REWRITTEN in plain
terms 2026-08-02 — the archived plan's wording was impenetrable; this section supersedes it)*  ⬜

**The problem it solves (chicken-and-egg at setup/admin time):** to compute the study area,
facing, and grids you need bathymetry — but you can't know WHICH bathymetry tiles to download
until you know roughly where the coastline runs and which way the water faces. Today that
bootstrap is implicit/fragile.

**The design, in order:**
1. **Stage 1 — OSM bootstrap (cheap, instant):** from OpenStreetMap coastline + water-body data
   (already fetched by `geography.py`): trace the coastline, classify the water body, run the
   72-ray fetch fan, compute a provisional facing and study-area footprint. **Freeze L1** and
   the bathymetry **download footprint** from this.
2. **Stage 2 — bathymetry refine (authoritative):** with the bathymetry now downloaded for the
   Stage-1 footprint, recompute the real facing (AD-1R smoothed-shoreline normal), transects,
   L3/L4 — the same production chain that runs today.
3. **Self-check:** compare the Stage-1 OSM heading vs the Stage-2 bathymetry heading. Agreement
   → trust; divergence beyond threshold → WARN + flag for operator review at setup (catches bad
   OSM data or bad bathymetry before the model runs on it).
- **G6.3 — wizard polygon draw tool** *(the part the operator couldn't reconstruct — it is UI,
  not algorithm)*: the wizard's map today only lets the operator draw a **polyline** (the beach
  segment). This enables **closed-polygon drawing** in the same map (`L.Draw.Polygon` alongside
  the polyline, `templates/wizard/step_marine.html`), capturing the ring into the existing
  `_coordinates` field — so the operator can draw closed outlines (study-area boundary /
  structure rings) by hand where OSM tracing is wrong or missing. Round-trips through the
  existing apply contract (guarded by the T4.5 coord round-trip test).
**Accept:** stage order enforced (L1 frozen after Stage 1; Stage 2 uses Stage-1's footprint);
self-check flags a synthetic divergent pair; polygon round-trips.

---

## C — Carry-forwards (small, mostly verify-then-close)

### C1 — Concerns sweep  ⬜
Triage the still-OPEN entries in the two archived concerns files against current code, one
closeout report: `archive/MARINE-WORKING-MODEL-CONCERNS.md` — **TA-C21** (invariant-3 rescope:
operator decision — options (a) alongshore-span condition / (b) downgrade to INFO / (c) leave;
note BD-8 retirement made the flag metadata-only, which may change the operator's preference),
**TA-C22(b)** (transect-31 PT* gap root-cause; TA-C22(a) is C4 below); `archive/
MARINE-GEOMETRY-MODEL-CONCERNS.md` — TC-1..TC-20 (many likely closed by events; TC-10 is H2's,
TC-19 is H3's), and the restoration concerns' surviving C-E items (C-E01/03/04/08/10/11/12, D7
parked-to-cutover). **Accept:** every entry gets CLOSED-with-evidence / CARRIED-to-named-task /
OPERATOR-DECISION, in one report.

### C2 — D6a re-verify *(G7.1)*  ⬜ — the `grid_sizing_chain` StructureConfig-vs-dict type bug:
old cite is stale; re-locate by grep; fix with a failing-first guard test, or confirm gone and
close.

### C3 — Cadence/performance lever *(G7.4, approved + gate-cleared 2026-07-30)*  ⬜ — hourly
0–24 then ~6-hourly to 72 (~52% fewer solves, ~41→~25 min). Producer-only (`swan_formats.py`
compute list + TABLE schedule). Chain is timestamp-driven (verified 2026-07-30) — re-confirm at
implementation. Worth doing now that magnitude is validated.

### C4 — modelStatus grading *(G7.5 / TA-C22(a); data-contract change pre-approved via the
geometry plan)*  ⬜ — pinned rule: `ok` = 0 transects fall back; `partial` = ≥1 but <25% and not
the best-peak transect; `degraded_bulk` = ≥25% OR the best-peak transect. **Check interaction
with BD-7 first:** "best-peak transect" should likely read "any main-break-zone qualifying
transect" now — surface the delta to the operator before coding.

### C5 — Track-B sign-off designs *(T4.2 bathymetry injection; T4.3 dynamic coefficients)*  ⬜ —
each needs an operator-signed design before any code (standing gates from the working-model
plan). Parked until a spot needs them (submerged breakwater / DAM crest cases).

### C6 — T1.3 re-verify C-E07 + curve-clip at more sea states  ⬜ — folds naturally into V1/V2
evidence collection; close it there.

---

## D — Deferred items from the 2026-08-01 break-detection rounds

### D1 — `_transect_band_depths()` deletion  ⬜ — dead in production since the full-length-band
rewrite; deletion blocked by `tests/test_swan_l4_intersection.py` imports. Needs its own scoped
round (update the importing tests in the same commit). Operator sign-off to dispatch.

### D2 — `test_serve_nothing_on_failure.py` — 2 pre-existing failures  ⬜ — stale fixture missing
`open_water_bearing_deg` (broken since `51543b1`). The GUARD it tests (serve-nothing) is live and
important — fix the fixture so the guard's tests actually run. Small, high-value.

### D3 — tmpfs peak headroom *(known limitation, recorded)* — `_check_convergence` reads all
TABLE_PT files before the parse-and-delete loop, so peak tmpfs is unchanged by the unlink
(~170 MB/cycle at full-length bands). No action unless a bigger config trips the box; noted here
so nobody rediscovers it.

### D4 — Dashboard adoption of the BD-7/BD-9 wire fields  ⬜
**Owner:** `clearskies-dashboard-dev`. The API now serves `mainBreakZoneFaceHeight`,
`mainBreakZoneStartIndex`/`EndIndex`, `mainBreakZoneQualifyingCount`,
`representativeTransectIndex` (API-MANUAL updated 2026-08-01) — the dashboard does not yet
consume them. Scope: surface the zone context where face height is shown; the beach-profile
cross-section already follows the representative transect server-side (no dashboard change
needed there — verify).

### D5 — Birdseye break heatmap *(spec BD-6 — product does not exist yet)*  ⬜
DASHBOARD-MANUAL confirms no heatmap exists. The data contract (`per_transect` with break
points/zones per transect) is complete and live. Design + build the alongshore × cross-shore
break-zone view (the "where are the best breaks along the beach" product the operator has
described repeatedly). Needs a design pass before implementation; coordinate with D4.

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

## Decision log

- **2026-08-02 — Plan created.** Operator approved the three-plan triage in chat: working-model
  archived (fully superseded); restoration status-corrected (Phase F/R5 markers were stale) and
  archived with Gate R substantively passed; geometry plan closed with G4/AD-4 superseded and
  remainder extracted here. Operator rulings same session: Phase F stays wired (done, not
  revisited); G5 gets an evaluate-benefit-first gate; G6 rewritten in plain terms (this file's
  §G6 supersedes the archived AD-6/G6 wording); G6.3 confirmed as the wizard polygon draw tool.
