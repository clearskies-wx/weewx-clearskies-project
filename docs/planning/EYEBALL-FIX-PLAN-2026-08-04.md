# EYEBALL FIX PLAN — 2026-08-04 (v2, execution plan)

**Opened:** 2026-08-04 (v1 investigation synthesis). **v2 rewrite:** 2026-08-04 per operator —
granular tasks, agent assignments, QC gates, design done IN THIS PLAN (agents implement, they do
not design). **Owner:** Coordinator.

**Companions:** [EYEBALL-FEEDBACK-2026-08-04.md](EYEBALL-FEEDBACK-2026-08-04.md) (13 logged
items) · [briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md](briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md)
(research + §7.2 binding variable inventory) ·
[ADR-101](../decisions/ADR-101-surf-score-geometric-mean.md) (Accepted 2026-08-04).

**⇒ ALL PHYSICS / SELECTION / HEAT-MAP WORK FROM 2026-08-05 ONWARD lives in
[SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md](SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md)** — rounds Y
(spectral boundary — the measured ⅓-energy starvation), X (statistical breaking + one-sided decay
+ roller + cap deletion, operator-ruled), Z (bar-aware sticky transect selection, fine-grid
shoreline anchor, heat-map orthophoto registration), plus the documentation catch-up debts
(DOC-0/DOC-1) and the S-5 direction-source change. This plan's own remaining items (inv-swell,
DQ-W1/W2, E3/E4 groundswell re-check) are subsumed there.

**Agent roster:** `clearskies-dashboard-dev` (React), `clearskies-api-dev` (API + marine Python),
`clearskies-test-author` (guards/known-answer), `clearskies-auditor` (blind adversarial),
`clearskies-docs-author` (manuals). Every implementation prompt carries the architectural-change
block per rules/agents.md; every round closes per rules/verification.md (three-layer:
guard / invariant / adversarial; coordinator visual sign-off; physical-plausibility check).

**QC protocol (all rounds):** (1) implementer delivers with self-run evidence; (2) test-author
lands guards SEPARATELY from the implementer; (3) blind auditor reviews without seeing the
implementer's claims; (4) coordinator walks the gate rows personally — grep checks run, screenshots
compared, live values checked against reality (Surfline/NDBC) before anything is called done;
(5) doc-code sync verified in the same round. Deploys ONLY via scripts
(`redeploy-weather-dev.sh`, `deploy-api.sh`); marine deploys to librewxr per
reference/clearskies-dev.md. Marine dead-code commit `47c8084` (aud-del3 DEPLOY-SAFE) rides the
first marine deploy.

---

## 0. Executive summary — three confirmed mechanisms (v1 investigation, unchanged)

| Mechanism | Items | Verdict |
|---|---|---|
| **M1 — Marine compute time vs API proxy 15 s timeout, + client never retries after an error.** All-transects profile route computes 25–30 s; proxy gives up at 15 s (`companion_proxy.py:142`) → heatmap can NEVER load (structural). Same busyness intermittently starves `/marine/{id}` → one 503 nulls wind + water temp together, and `useApiQuery` arms its refresh timer only on success → a failed fetch stays failed until reload. | 7, 8, 11, 12(water) | CONFIRMED (live replay + journal + code) |
| **M2 — "4 s period" is the wrong statistic displayed, not a model-input problem.** Headline read SWAN's Tm01 (whole-spectrum mean) while the correct partition decomposition (groundswell 15.6 s present) was served every hour. Inputs verified end-to-end; NDBC buoy corroborates our numbers. | 4, 12(period), 13 | CONFIRMED (live payload + buoy + code) |
| **M3 — Card content accreted through individually-authorized rulings never visually reviewed as a whole; score-bar /100 fill was repeat drift from the standing per-category ruling (ADR-096), never an operator ruling.** | 1, 5, 6 | CONFIRMED (git provenance) |

Scoring root cause (v2 addition): beyond M3's display drift, the scoring FORMULA itself was ruled
unfit (compensability defect, lost research basis) → rebuilt as ADR-101. Round S below implements
it.

---

## 1. DESIGN SPECIFICATIONS (LOCKED — agents implement these, they do not design)

### S-SPEC-1 — Surf score rebuild (ADR-101). THE design for Round S.

**Formula:** `score = 100 × size^w1 × shape^w2 × conditions^w3 × power^w4 × consistency^w5`,
factors internally 0–1.0, displayed 0–100 (rounded int). Default weights w =
0.25/0.25/0.20/0.20/0.10, normalized by sum at computation; admin-adjustable (system-wide).
Stars = score/20. Any factor 0 → score 0. Variable inventory: brief §7.2 is BINDING (an
inventoried variable ignored = defect; an un-inventoried variable read = single-use violation).

**Factor curves (exact defaults — carry existing calibrated tables where named):**

| Factor | Curve |
|---|---|
| **size** | `breakingFaceHeight` through the EXISTING `_WAVE_HEIGHT_RANGES_FT` face-height table (values already 0–1; keep as-is), THEN × alignment multiplier (existing `_BEACH_ALIGNMENT_RANGES`: ≤15°→1.0, ≤30°→0.8, ≤45°→0.6, ≤60°→0.3, else 0.1) × exposure multiplier (existing: open→1.0, blocked→0.1). Face < 0.3 ft → 0.0 (flat). |
| **shape** | `0.6 × peel_score + 0.4 × breaker_score`, then jacking bonus `+0.05` if any `jackingFactors[].factor > 1.3` (cap 1.0). peel_score from `peelAngle`: ≥45° and ≤70° → 1.0; 30–45° → 0.7; 70–80° → 0.7; >80° → 0.5; 15–30° → 0.3; <15° → 0.05. breaker_score from Iribarren type: plunging 1.0, spilling 0.7, collapsing 0.4, surging 0.2, unavailable 0.5. **Component ruin clamp:** `peelAngle < 15°` → shape = min(blend, 0.10) (closeout). |
| **conditions** | `0.6 × wind_score + 0.25 × dspr_score + 0.15 × cross_score`. wind_score: existing brackets (glassy ≤5 mph → 1.0; offshore ≤10 → 1.0; offshore strong 0.7; cross-shore 0.8; onshore ≤10 → 0.7; onshore 10–20 → 0.5; onshore 20–25 → 0.3; no-data 0.5) — the old >1.0 bonuses (1.1/1.2) are capped at 1.0. dspr_score: existing DSPR buckets (<15°→1.0, 15–25→0.7, 25–35→0.4, ≥35→0.2, null 0.5). cross_score: existing (none 1.0, significant 0.4, null 0.5). **Component ruin clamp (blown out):** onshore ≥25 mph OR any direction ≥35 mph → conditions = 0.05. |
| **power** | `0.7 × period_score + 0.3 × energy_score` on the DOMINANT `multiSwell` partition (dominance rule = largest breaking face height, same as waveShapeClassification — D1 option (i); NEVER Tm01). period_score: existing period table capped at 1.0 (≤6 s→0.2, ≤8→0.4, ≤10→0.6, ≤12→0.8, ≤16→1.0, ≤18→0.9, >18→0.8). energy_score: dominant partition's share of total partition energy: ≥0.6→1.0, 0.4–0.6→0.8, <0.4→0.6. `multiSwell` null → power = 0.5 (neutral, flagged in logs). |
| **consistency** | `0.6 × timing_score + 0.4 × amplitude_score`. timing_score from `setTimingMinutes`: 3–10 min → 1.0; <3 → 0.8; 10–20 → 0.7; >20 → 0.5. amplitude_score from `setAmplitudeM`: ≥0.3 m → 1.0; 0.15–0.3 → 0.8; 0.05–0.15 → 0.6; <0.05 → 0.5. SurfBeat disabled/unavailable → FALLBACK: consistency = swellDominance mapped ≥0.8→0.9, 0.5–0.8→0.7, <0.5→0.4 (null → 0.5). |

**Null policy (uniform):** a null SUB-input takes its neutral listed above and stays in the blend;
a whole factor with no data takes 0.5; no exponent renormalization (simplest, consistent).
Time-of-day: the dead almanac block `endpoints/surf.py:876-886` is DELETED (D4).

**Worked examples (known-answer fixtures — Gate S row 1; computed from the curves above):**

| Scenario | size | shape | cond | power | cons | Score | Stars |
|---|---|---|---|---|---|---|---|
| Perfect day | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 100 | 5.0 |
| Balanced good day | 0.80 | 0.80 | 0.90 | 0.90 | 0.80 | 84 | 4.2 |
| Small clean day (1.5 ft, 14 s, glassy) | 0.30 | 0.80 | 0.95 | 0.60 | 0.70 | 60 | 3.0 |
| Clean closeout (6 ft, peel 8°) | 0.90 | 0.10 (clamp) | 0.90 | 0.80 | 0.80 | 50 | 2.5 |
| Blown-out epic (isolated worst case) | 0.90 | 0.70 | 0.05 (clamp) | 0.90 | 0.80 | 47 | 2.3 |
| Flat | 0.0 | — | — | — | — | 0 | 1 (floor) |

⚠ **Operator judgment row at Gate S:** closeout 50 and blown-out 47 are the geometric mean's
honest floor for a SINGLE ruined factor with everything else perfect. On real ruined days multiple
factors degrade together (onshore gale also wrecks shape via chop and power via windswell →
typical real blown-out ≈ 25–35). If the isolated-case numbers still read too generous at the gate,
the levers are: harsher clamps (0.02 → blown-out 39) or operator weight adjustment (admin). Decide
AT THE GATE with live examples, not by re-opening the design.

**Wire contract v2 (`SurfScoringBreakdown` replaces the 3+3 shape — breaking change, trigger 4,
authorized by ADR-101):**

```
scoring: {
  size: int 0-100, shape: int 0-100, conditions: int 0-100,
  power: int 0-100, consistency: int 0-100,
  weights: {size, shape, conditions, power, consistency}  // effective normalized floats
}
```
Deleted fields: `waveHeight`, `wavePeriod`, `waveOrganization`, `organizationWind`,
`organizationSwellDominance`, `organizationDirectionalSpread`, `organizationCrossSwell`,
`beachAlignment`, `directionalExposure`, `timeOfDay`. `qualityStars`/`total` unchanged at the
`SurfForecast` level.

**Config (marine, via existing admin → API → marine `/config` path — never direct):** section
`[surf_scoring]`, keys `weight_size`, `weight_shape`, `weight_conditions`, `weight_power`,
`weight_consistency` (floats > 0; absent section = code defaults). Scorer normalizes by sum.

**Admin UI (stack):** "Surf Scoring Weights" section — five numeric fields pre-filled with current
values, live effective-% display (value ÷ sum), Reset-to-defaults button, reject ≤ 0. Help keys
`help.admin.surf_scoring.*` + Operator Manual section in the same round.

**Dashboard display:** Surf Score card: score + stars unchanged; FIVE bars (Size / Shape /
Conditions / Power / Consistency), each `fillPct = factor` (denominator 100), score-tier colors
per existing tokens; ADJUSTMENTS column and all signed rows DELETED. Scoring explainer modal
rewritten: five factors + one sentence — "The score is a weighted geometric mean of the five
factors — they average together, but one very poor factor sinks the whole score." i18n keys under
`surfing.scoringExplainer.*` updated (all locales).

### S-SPEC-2 — Current Swell card strip (item 6, RULED at eyeball)

Strip to the a49059d 2026-07-16 baseline (title + 3 stat tiles + component table + compass) +
KEEP the existing peel row (SurfingTab.tsx:2257). REMOVE: best-peak/average headline,
main-break-zone text, wave-shape row, SurfBeat section, **AND the shadow line + AT BREAK rows
(D2 RULED 2026-08-04, operator chat: "no user will know what the hell that is… these were
computed for other parts of the dashboard, NOT for the Current Swell conditions card").** Render
removal only — marine/API keep emitting `shadowFaceHeight`/`perPartitionBreaks` (D10.2 wire
contract untouched; they serve other dashboard consumers).

### S-SPEC-3 — Beach-profile break-point label collisions (item 9d, confirmed bug)

`BeachProfileChart.tsx:740-850`: break-point labels get the SAME background-rect treatment zone
labels already have (`:656-670` pattern — rounded rect, card-glass fill) + minimum horizontal
separation: labels closer than 56 px stagger vertically in 14 px steps (2-pass greedy from
seaward). No other visual changes (D5 owns the redesign).

> **AS SHIPPED (2026-08-04, supersedes the above):** stagger + background rects landed
> (`c39fe30`), then bounding-box collision + y-clamp (`8f035cd`) — but the algorithm still
> saturated at ≥5 clustered breaks (audit F1). Operator ruling in chat ("why are we wasting
> time on the old chart?"): the two colliding label rows (per-partition annotation +
> breaker-type text) were DELETED outright (`96f5478`, lead-direct) rather than iterated.
> The old chart keeps markers/zones only; all labeling design moves to the D5 redesign.

### S-SPEC-4 — Client resilience (items 7/8/12 client half)

`useApiQuery` (dashboard hook): on fetch error, schedule retry with exponential backoff 5 s → 10 →
20 → 40 → cap 60 s, and KEEP the normal refresh timer armed after first success. Marine hooks
(`useMarine*`): `pollInterval: 120` so a transient 503 self-heals. No contract change.

> **ERRATUM (caught at dispatch 2026-08-04):** this spec originally said `120_000` — wrong
> units. `useApiQuery`'s `pollInterval` takes SECONDS (×1000 internally at
> `useApiQuery.ts:307-308`); `120_000` would poll every 33 hours. Shipped value: `120`.

### S-SPEC-5 — Proxy timeout (mechanism M1)

`companion_proxy.py:142` `_PROXY_REQUEST_TIMEOUT_S`: 15 → 45. Constant tuning only. (Long-term
compute placement = D7, untouched.)

---

## 2. ROUNDS AND TASKS

### STATUS (as of 2026-08-05 ~11:15Z — detail + evidence in the execution scratch file; **OPERATOR: START AT [docs/planning/OPERATOR-REVIEW-PACKET-2026-08-05.md](OPERATOR-REVIEW-PACKET-2026-08-05.md)** — every decision waiting on you is itemized there)

**Operator autonomy grant (2026-08-05 ~08:05Z, in chat):** "please continue autonomously
for as much as you can, including D5, D6 and completion of Round S." Two operator gates
still stand and are QUEUED for operator return (not skipped): the Round W reality-gate
worked-examples review, and the ADR-101 worked-examples review before Round S merges.

| Round / item | Status | Evidence |
|---|---|---|
| **Round A** (A1 bars, A2 card strip, A3 labels, A4 resilience, A-T guards, A-Q audit) | **CLOSED 2026-08-04** | dashboard `a35373d`/`ca0689e`/`c39fe30`+`8f035cd`+`96f5478`/`0debd2a`; guards `963d311`/`6a8c6a2`; 27/27 canonical; Gate A walked; deployed weather-dev `96f5478` |
| **Round B** (B1 proxy timeout 45 s, B2 contention numbers) | **CLOSED 2026-08-04** | api `d818461` deployed; Gate B walked (honest marginality recorded — 45 s is marginal under co-tenant load; D7 precompute is the real fix, normal order) |
| **Round P** — beach-profile unification (mid-session authorized round: side-run deletion + zones/shapes/jacking from pipeline + tideLevel/waterlineDistance/beachElevation) | **CLOSED 2026-08-05** | marine `4e0ff18`+`8c2def8` deployed (proc start 03:14:25Z); api `ac96064` deployed; live checks pass (zones anchor exactly to published breaks; waterline math exact in m and ft); guards `7ee5a3c`/`1d6c9b0`/`541644d`, 67 pass local + canonical librewxr; blind audit: main claim COULD NOT DISPROVE (5 rule-outs); reality gate: period/direction/class PASS, Hs leg indicts pre-deploy state (accepted, coordinator disposition); doc sync in API-MANUAL |
| **D5** — beach-profile card redesign | **DEPLOYED 2026-08-05 (dashboard `f85505b` on weather-dev; D5.1 rebuild + D5.2 zero-width skip + D6 per-break default + D7s heat-map median-5 smoothing; manuals synced `1b060b0`); operator visual review queued (packet §2)** (mockup approved by operator: "overall it looks so much better... much more readable" + "4. yes") | brief ROUND-D5-BEACH-PROFILE-CARD-BRIEF-2026-08-05.md dispatched to dashboard dev: D5.1 card rebuild to iteration-3 mockup, D5.2 zero-width band skip, D6 per-break zones default-on (no toggle; aggregate fallback), D7s heat-map median-5 display smoothing (operator standing want). Payload SHAPE already live from Round Z; Round W changes values only |
| **Round Z** — surf-zone truthing (marine) | **CLOSED 2026-08-05** | Z0 hotstart read fix (first-ever warm start proven 05:26:05Z) + Z5 stamp-ordering fix; Z1 foam→waterline live (foam 9.29 m vs waterline 9.30 m); Z2 detection rework, gate-retuned δ=0.05 / Hs floor 0.10 per audit F1/F2 + 162-transect sensitivity scan; Z3 perBreakZones + Z4 ft conversion live; marine `36fab04` + api `c99f6d5` deployed; canonical 35 pass; audit 3 findings all remediated/dispositioned; API-MANUAL synced `149133b`. Known limitation: post-breaking reform physics (inv-wave-reform in flight, operator-ordered) |
| **D6** — per-break zones (contract y/n) | **YES (operator 2026-08-05)** | implemented as Round Z task Z3 (`perBreakZones` additive field; aggregate `surfZones` retained) |
| **Round W** — real post-breaking physics (operator-ordered: "real physics and not fake clamping") | **DEPLOYED + REALITY GATE WALKED 2026-08-05 (E1/E2/E5 PASS; E3/E4 deferred to next groundswell); operator webcam review + DQ-W1..W3 QUEUED (packet §2/§5)** | W1/W2/W3 = marine `e048494`/`71f6bff`/`c09a78c` (local, not yet pushed): DDD march (Γ=0.40, K=0.15) replaces B-J+roller+both clamps; invariant WARNING instead of clamp; detection from modeled onsets (legacy hysteresis preserved for None path). Acceptance gate PASS: lead-independent pytest identical to dev tail (2 failed / 804 passed — both dispositioned: one superseded clamp-monotonicity pin, one PRE-EXISTING Round-P stale wiring pin, both to test-author T-W7); allowlist diff exact; clamp/call-site greps clean; KATs: closed-form shelf <0.5%, synthetic two-bar → real reform (min ratio 0.252) + 2 onsets, real transect single onset ~98 ft (carry-in E6 for reality gate). Guards brief ROUND-W-GUARDS-BRIEF-2026-08-05.md (in flight); blind audit in flight. THEN: deploy → canonical pytest → journal sweep → reality gate with PRE-STATED bands E1–E6 (recorded in scratch BEFORE deploy) → operator worked-examples review (QUEUED) | |
| **inv-wave-reform** | **DONE 2026-08-05** | mechanism + payoff quantified; superseded by the operator's Round W ruling (physics ordered regardless) |
| **Radar container CPU (operator repaired)** | **WATCHING** | post-repair: radar 64% CPU (was 211%/795%); load avg still ~9 — re-check after rebuild settles; open finding if load stays high with no process accounting for it |
| **Round S** — surf score rebuild (ADR-101/S-SPEC-1) | **ALL 5 LEGS COMPLETE + GUARDED 2026-08-05 ~14:20Z; blind audit running; AWAITING OPERATOR GATE (packet §4)** | marine 13 local commits (scorer S1..S1d conformed to S-SPEC-1 + 6 guard commits, suite 881/0 lead-verified); api/dashboard/stack round-s-scoring branches lead-accepted; worked examples 4-exact/2-within-1pt of the spec table (its per-component targets proven curve-unreachable = illustrative); NOTHING deployed — merge+deploy gated on operator worked-examples review |

**Parking lot (pre-existing findings, tracked for future rounds — none block Round P):**
1a. **Hotstart follow-up — stamp semantics (found live 2026-08-05 after Z0 deployed):**
   the read fix works (journal now parses the stamp: "stamped 20260807.180000 !=
   requested start 20260805.000000" — a line impossible pre-Z0), but SWAN stamps a
   hotfile with the END of the preceding compute (= the forecast-horizon end under our
   all-stationary sequence), while the runner compares against the next cycle's START.
   Those can never match ⇒ cross-cycle warm start never engages even with a working
   reader. What the comparison SHOULD accept (any stamp ≥ requested start? per-timestep
   hotfiles? same-cycle-only warm start by design?) is a SWAN-run-semantics decision —
   OPERATOR ruling needed before anyone "fixes" it.
1. **SWAN hotstart chronic cold-start — ROOT CAUSE FOUND (audit 2026-08-05):**
   `swan_runner.py` `_read_hotfile_timestamp()` reads only the first 4096 bytes, but the
   hotfile "date and time" record sits AFTER the LOCATIONS coordinate block at byte offsets
   32,885–258,389 in all 4 live level hotfiles → token=None 100% of the time → every level
   cold-starts every cycle (223 journal hits since Jul 28; wasted compute; ~40 min of
   degraded all-transect bulk-fallback after every restart; likely source of the inflated
   pre-deploy partition Hs the reality gate caught). Companion finding: the existing
   `tests/services/test_hotstart_timestamp.py` fixture writes the date line first in a tiny
   synthetic file — it can never reproduce the failure, so the suite stays green while the
   defect fires in production. Fix (read window / scan-to-record + honest test fixture) is
   methodology, not architecture — recommend its own small round soon.
2. **`surf.py:389-423` `_compute_median_bathy_profile` feeds SurfBeat land points** (audit,
   quantified live: all 162 transects include land, median domain starts 47.71 m onto dry
   beach; the downstream 0.01 m clamp turns real dune into a flat near-zero-depth "canal",
   wasting SurfBeat grid resolution and mis-placing the shoreward Hs_ig station). Violates
   the consumer's own "depths must be positive" contract — fix is contract-restoring.
3. **`transect_index=best` docstring drift** (beach_profile.py:856-857 still describes the
   pre-BD-9 "highest-face-height open transect" selection; live default returned a
   structure-affected transect via BD-9's representative index). Doc-code sync fix.
4. **jackingFactors on the default transect is legitimately empty** (audit: detection works —
   14/162 transects carry real bar factors 1.04–1.11; default transect 14 has zero local
   depth minima). No defect; recorded so nobody "fixes" it.
5. **Radar co-tenant container re-pinning CPU** (librewxr-librewxr-1; operator investigating).
6. **Proxy 503 at 45 s on uncached keys under co-tenant load** — stands until D7 precompute.
7. **→ PROMOTED TO ROUND Z (operator rulings 2026-08-05: "1. yes. 2. yes."):**
   (a) foam zone extends to the tide-aware waterline — APPROVED criterion change;
   (b) break-detection rework APPROVED — with the operator's domain correction folded in:
   **HB is notorious for its double break; it is rare for there NOT to be one** (operator
   2026-08-05). So Z2 is NOT "suppress inner breaks": it is (i) kill the saturated-profile
   jitter artifact via crossing hysteresis, AND (ii) make the REAL inner shorebreak
   detectable (current `depths[i] > 0.3 m` filter excludes the shallow band where HB's
   shorebreak actually breaks). Specific constants (hysteresis δ, revised depth floor) are
   design details presented at the Round Z gate with worked examples.
   **INV-WAVE-REFORM RESULTS (2026-08-05, read-only investigation, full report in agent
   closeout):** mechanism confirmed — TWO unconditional ceilings pin Hs at γ·d
   (surf_1d_analytical.py:1029-1030 kernel clamp; surf_1d_pipeline.py:649-658 combine
   clamp), and the clamp is load-bearing (raw Battjes-Janssen+roller output diverges
   up to 37 m without it; SWAN manual :4117 corroborates). The published fix
   (Dally-Dean-Dalrymple 1985 stable-height relaxation, Γ≈0.35-0.4, K≈0.15
   literature-recall NOT primary-verified) was prototyped read-only over the real 162
   transects: **payoff only 6-9/162 transects at K=0.15 (0 at K=0.075, 15-19 at
   K=0.30)** — because the CUDEM profiles' trough relief (0.03-0.3 m) is too subtle for
   waves to back off below even Γ·d. Cost side: 5 functions/2 files, 2 new physics
   constants, both clamps redone, reshapes face-height/zones/jacking on EVERY transect.
   **RETRACTED (operator correction 2026-08-05): the coordinator's "CUDEM is stale,
   sandbars migrated" explanation was speculation stated as likelihood — the operator
   confirms the double break at these positions is LONG-STANDING and precedes the
   bathymetry data; it is a persistent feature, not recent sandbar migration. What
   remains established: our transect profiles show only 0.03-0.3 m of relief in the
   100-300 ft-off-waterline band while reality reliably double-breaks there. The CAUSE
   of that data-vs-persistent-feature discrepancy is UNESTABLISHED (candidates include
   surf-zone smoothing inherent in the CUDEM compilation or our transect
   interpolation — to be settled by the inv-break-geometry measurement, not assumed).** Operator decision pending.
   **OPERATOR RULING 2026-08-05 (chat): implement the REAL physics — "You will make the
   changes to our model to promote real physics and not fake clamping... I have asked
   more than once that this be done correctly and all time, I find fake clamps,
   bandaids and duct tape." Bathymetry-first recommendation REJECTED; the
   Dally-Dean-Dalrymple stable-height treatment replaces the clamps. This is the
   explicit trigger-1 approval. STANDING DIRECTIVE captured for the rules files at
   round close: correct physics over clamps/bandaids, project-wide. → ROUND W
   (wave-reform physics) opens; bathymetry check remains queued separately in
   inv-break-geometry (not a substitute).**
   **ROUND W GROUND TRUTH (operator 2026-08-05, with the operator's own error bars):**
   real seaward break ≈300 ft and second break ≈100 ft from the waterline; the double
   break is a LONG-STANDING persistent feature; the model's published outer-break
   position is approximately correct per operator eyeball. **Measurement provenance
   (operator caveat, same date): these are ESTIMATES from visual orthophotography of
   UNKNOWN DATE, measured from the waterline VISIBLE IN THE PHOTO — not the official
   zero line and not a known tide state.** Gate consequences, adjusted accordingly:
   (1) treat 300/100 ft as APPROXIMATIONS sufficient to judge whether the model is
   approximately right (operator 2026-08-05): two distinct breaks; outer roughly 3× the
   inner's waterline distance; reform gap of order 200 ft; both well seaward of the
   sand. **The coordinator's "±100 ft photo-waterline uncertainty from tide" claim is
   STRUCK (operator correction ×2, 2026-08-05): it was fabricated reasoning (assumed
   tide swing, assumed linearity, assumed the model profile matches the real beach
   face) presented as fact, followed by a deflection blaming the profile data. No
   uncertainty figure is on record for the orthophoto measurements beyond the
   operator's own words: they are approximations, good enough to judge whether the
   model is approximate or not.**
   (2) The SHARP instrument for exact positions remains a matched-time webcam
   observation at known tide (inv-break-geometry's method); use that at the Round W
   gate for the precise comparison, with the orthophoto numbers as the coarse prior.
   (3) Waterline-relative conversion still applies (waterline-relative = published
   distance − waterlineDistance).
   Original finding text follows for the record.
   **Break geometry vs reality (operator webcam ground truth, 2026-08-05 01:27Z Duke's cam):**
   real surf shows foam running to the sand and the outer break out near a pier bumpout;
   payload shows foam ending at 137 ft and breaks at 206/222 ft. Three mechanisms found:
   (a) **foam-zone end is a classifier threshold, not physics** — `_classify_zones`
   (surf_1d_analytical.py:564) ends foam where bore Hs < 0.3 m or depth < 0.2 m, while the
   model's own Hs profile is depth-saturated (Hs = 0.73·d) continuously from the outer
   break to the waterline, i.e. the physics already says whitewater-to-the-sand; extending
   the zone to the waterline is a criterion change (trigger 1) — OPERATOR DECISION;
   (b) **the 206-ft "inner break" + reform trough is a detection artifact** — crossing
   detection (:519-526) re-fires on numeric jitter around γ on a saturated profile; the Hs
   data shows no actual reform (monotonic, ratio pinned at γ). Fix = crossing hysteresis /
   saturated-region suppression — touches detection criteria, OPERATOR DECISION; the
   detector also can't register the real shorebreak (min-depth 0.3 m / min-Hs 0.15 m
   filters exclude the last ~90 ft);
   (c) **outer-break cross-shore distance — calibration check, NO defect asserted**
   (operator 2026-08-05: "I am not saying the 222ft is wrong, that may be correct... 222
   feet may be close"): real outer break observed near the gift-shop bumpout (Kite
   Connection, on-pier); its station distance isn't in public listings — measure from the
   pier's mapped deck polygon (OSM) to the tide-aware waterline at a matched hour and
   compare to the published break distance. INVESTIGATION (inv-break-geometry), verify-
   not-fix. Confound noted: cam frame 01:27Z vs model timestep 04:00Z (different tide).

### ROUND A — dashboard quick fixes (before Round S; A1 is an interim fix Round S supersedes)

| Task | Spec | Files/loci | Agent | Acceptance (grep-checkable where possible) |
|---|---|---|---|---|
| A1 | Score bars fill per-category (standing ADR-096; interim until S4) | `SurfingTab.tsx:219` `ScoreBar` fillPct; DESIGN-MANUAL:1343 SURF-1 text deleted | dashboard-dev | fillPct divides by the factor's own max. FAIL: any `/100` denominator on component bars; FAIL: "SURF-1" appears in DESIGN-MANUAL |
| A2 | Swell card strip per S-SPEC-2 | SurfingTab.tsx Current Swell card block | dashboard-dev | Removed sections absent from JSX; peel row + D2-exception rows present. FAIL: SurfBeat/wave-shape/best-peak markup remains |
| A3 | Label collisions per S-SPEC-3 (as-shipped: label rows deleted per operator ruling — see S-SPEC-3 AS SHIPPED note) | `BeachProfileChart.tsx` | dashboard-dev + lead-direct `96f5478` | Zero label overlap by construction (annotation + breaker-type rows removed); markers/zones intact |
| A4 | Client resilience per S-SPEC-4 | `useApiQuery` hook + marine hooks | dashboard-dev | Error path schedules retry (test: mock 503 → recovers without reload). FAIL: retry only on success path |
| A-T | Guards for A1–A4 | dashboard tests | test-author | fillPct regression test (denominator = category max); useApiQuery 503-recovery test |
| A-Q | Blind audit + visual sign-off | — | auditor + coordinator | Gate A below |

### ROUND B — API (parallel with Round A)

| Task | Spec | Files/loci | Agent | Acceptance |
|---|---|---|---|---|
| B1 | Timeout per S-SPEC-5 | `companion_proxy.py:142` | api-dev | Constant = 45; heatmap loads live (was structurally impossible) |
| B2 | Marine contention measurement (NO code) | journal + timing log review | coordinator | Numbers recorded here; decision only if `/marine/{id}` starvation persists post-B1 |

### ROUND S — surf score rebuild (ADR-101; after Rounds A/B deploy)

| Task | Spec | Repo/files | Agent | Acceptance |
|---|---|---|---|---|
| S1 | Scorer rewrite per S-SPEC-1: five factor functions + geometric aggregation + clamps + null policy + weights from config; DELETE old adjustment/organization scoring and `surf.py:876-886` dead almanac block | marine: `enrichment/surf_scorer.py`, `endpoints/surf.py`, config loader | api-dev | All six worked examples reproduce EXACTLY (known-answer). FAIL: any Tm01 read in scoring; FAIL: any variable outside brief §7.2 inventory read by the scorer |
| S2 | Wire contract v2 per S-SPEC-1 (marine serialization + API model passthrough) | marine models + API `SurfScoringBreakdown` | api-dev | Old 10 fields gone from live payload; new 6 present; OpenAPI updated |
| S3 | Config: `[surf_scoring]` weights through admin → API → marine `/config`; Pydantic apply models accept the new fields (wizard↔API apply-contract rule) | API setup endpoint + marine config | api-dev | Round-trip: admin save → marine config file → scorer uses values; absent section → defaults |
| S4 | Surf Score card v2 + explainer modal per S-SPEC-1 display spec | dashboard: SurfingTab score card | dashboard-dev | Five bars, no adjustments column, no signed rows; explainer text updated in ALL locale files. FAIL: `beachAlignment`/`directionalExposure`/`timeOfDay` referenced anywhere in dashboard src |
| S5 | Admin weights section per S-SPEC-1 + help keys + Operator Manual | stack: admin template + i18n | dashboard-dev (stack HTMX) | Fields pre-filled, effective-%, reset works, ≤0 rejected; `help.admin.surf_scoring.*` present |
| S6 | Known-answer + guards: worked-example fixtures; single-use grep audit; bar-denominator regression; "≥2 spectral peaks → ≥2 partitions" stays green | marine + dashboard tests | test-author | All fixtures byte-exact; guards land in separate commit from S1 |
| S7 | Docs same-round: API-MANUAL §SurfScoringBreakdown rewrite; DESIGN-MANUAL scoring sections; ADR-096 annotated (formula superseded by ADR-101, bar rule survives); brief marked implemented | docs | docs-author | Doc-code sync gate row passes |
| S-Q | Blind audit + Gate S walk | — | auditor + coordinator | Gate S below |

**Deploy order:** marine + API together (contract moves in lockstep; `47c8084` rides) →
dashboard → stack. API restart wait ≥ 120 s before verification (cache warmer).

---

## 3. QC GATES (coordinator walks personally; evidence recorded per row)

**GATE A (dashboard round):**
1. A1 fillPct grep + rendered screenshot: component bars visibly per-category.
2. A2 side-by-side: stripped card vs a49059d baseline screenshot; D2-exception rows intact.
3. A3 screenshot with ≥3 break points: zero label overlap.
4. A4 live test: kill marine service 30 s mid-session → tab self-heals without reload.
5. Doc-code sync: DESIGN-MANUAL matches shipped card.

**GATE B:** heatmap loads end-to-end live (< 45 s, 200); `/marine/{id}` healthy during a
profile compute (B2 numbers recorded).

**GATE S (scoring):**
1. **Worked-examples review (operator, MANDATORY per ADR-101):** the six fixture rows + three
   LIVE days (current forecast) presented with factor values; operator judges against intuition +
   Surfline before merge is accepted. The closeout-50/blown-out-47 judgment row decided here.
2. Known-answer suite green; fixtures byte-exact vs S-SPEC-1 table.
3. Single-use audit: scorer reads exactly the brief §7.2 inventory (grep list attached to audit).
4. Wire: live payload shows v2 contract; dashboard renders five bars from it.
5. Weights round-trip: change a weight in admin → live score shifts accordingly; reset restores.
6. Physical plausibility: our score vs Surfline rating for the spot, 3 consecutive days —
   direction of movement agrees (not magnitude; different scales).
7. Visual sign-off: card + modal screenshots vs DESIGN-MANUAL text.
8. Doc-code sync: API-MANUAL/DESIGN-MANUAL/Operator Manual/help keys all match shipped behavior.

---

## 4. REMAINING OPERATOR DECISION QUEUE (one at a time, in order)

- **D5:** beach profile design set (items 9a/b/c/e/f/h) — design DIRECTION approved 2026-08-04
  (chart ends at the tide-aware waterline, visible shoaling sea surface, double break drawn,
  sleek redesign; operator: "yes this is what I was expecting"). Data prerequisites shipped in
  Round P (unified zones/shapes + tideLevel/waterlineDistance/beachElevation live 2026-08-05).
  REMAINING: operator sign-off on the mockup rebuilt from the live unified payload, then the
  dashboard implementation round.
- **D6:** zones per break (item 10) — contract shape change, yes/no. Operator 2026-08-04:
  re-present AFTER unified data exists — that precondition is now met.

RESOLVED (recorded): D1, D3, D4, D8-display → ADR-101 (Accepted 2026-08-04). **D2 → strip both
rows from the Current Swell card (operator 2026-08-04; render-only removal, wire fields stay —
folded into S-SPEC-2, no exception remains).** **D7 → RULED 2026-08-04 (operator chat: "Yes the
D7 is the proper fix and needs done, but does not need accelerated"): heatmap long-term =
PRECOMPUTE, executed in normal plan order, not accelerated; B1's 45 s timeout stands until then.**
D8's fan-derived sector-map live check remains in §5.

## 5. OPEN VERIFICATION TAILS

- Live check of the spot's `directional_exposure` sector map (D8 QA; also feeds S1's exposure
  modifier correctness).
- Beach-profile near-shore "flat slab": real berm vs fallback-profile artifact (one live payload
  check with the spot id).
- WW3 "one cycle behind" fallback: confirm never 2+ cycles stale at serve time.
- Screenshots: operator to save session images as files; bind to feedback-log rows.
- Process lessons (§3 of v1, NOT auto-ruled — operator decides if written into rules): (a) a doc
  label "(user-specified)" is not an operator ruling; a manual section cannot "supersede" an ADR
  without operator approval; (b) the /100 bar fill regressed against the standing ruling more
  than once → ruled-and-corrected behaviors need regression guards (A-T/S6 implement the guard
  for this instance).

## 6. WHAT THIS PLAN DOES NOT TOUCH

Wind §5 migration (step-1 gate observing, step 2 queued), C1–C6 50 m round, spacing slider round,
F2b admin-sends-all round, marine forward plan items (C-E05/E09/E12 spectral chain) — all
previously queued, unchanged. Pinned: per-spot tide windows (operator 2026-08-04, brief §7.2).
