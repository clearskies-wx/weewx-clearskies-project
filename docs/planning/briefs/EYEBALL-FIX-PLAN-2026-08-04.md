# EYEBALL FIX PLAN — 2026-08-04

Companion to [EYEBALL-FEEDBACK-2026-08-04.md](EYEBALL-FEEDBACK-2026-08-04.md) (13 logged items).
Six read-only investigations (inv-score, inv-swell, inv-swellcard, inv-current, inv-profile,
inv-heatmap) completed 2026-08-04 ~05:00Z; lead spot-checked load-bearing cites against HEAD
(fillPct :219, surf.py:876-886 Nones, surf.py:1111 ref_point wavePeriod, companion_proxy.py:142
timeout, selectTier/toggle/breaker-icon/zone code, a49059d provenance, peel row :2257).
Full agent briefs are in the session transcript; this plan is the actionable synthesis.

## 0. Executive summary — three real mechanisms explain 8 of 13 items

| Mechanism | Items | Verdict |
|---|---|---|
| **M1 — Marine compute time vs API proxy 15 s timeout (+ client never retries after an error).** The heatmap's all-transects profile route takes 25-30 s to compute (~143 transects, live-replayed twice: 200 OK/25-29 s direct, 503/15.03 s through API — deterministic). The proxy gives up at 15 s (`companion_proxy.py:142`), and since no request ever completes, the proxy cache never populates → heatmap can NEVER load (structural, not transient). The same marine busyness intermittently starves the `/marine/{id}` detail route (timeout at 03:52:29Z, recurring) → ONE 503 nulls windSpeed/windGust/windDirection AND waterTemp (both live in the same MarineBundle). Dashboard compounding defect: `useApiQuery` arms its refresh timer only on the success path, never on error, and the marine hooks have no pollInterval → a failed fetch stays failed until page reload (server recovered 04:13Z; an open tab would not). Wind Quality stayed "Onshore" because it comes from the separate, never-failed `/surf` forecast (HRRR wind) — a documented 2026-07-25 HELD ruling, not a bug. | 7, 8, 11, 12(water) | CONFIRMED (live replay + journal + code) |
| **M2 — The "4 s period" is the wrong statistic on display, NOT a model-input problem.** The headline and the 72-h Period row read `ref_point.wavePeriod` = SWAN's Tm01, a whole-spectrum MEAN (surf.py:1111; provenance documented at providers/nearshore/swan.py:13). The true partition decomposition (`multiSwell`) is computed, served, and correct EVERY hour — live payload shows groundswell 15.6 s/1.29 m present at hour 0 (and a 20 s component at hour 60) alongside wind_swell 4.5 s/1.84 m. Independent ground truth: NDBC 46253 (the buoy ~0.1 km from the spot) currently reports wind waves 2.6 ft EXCEEDING swell 1.0 ft @ 11.1 s, average period 4.8 s — our numbers track the real ocean; Surfline leads with the swell-only partition by convention. Input path checked end-to-end (WW3 spectra fetch, no frequency truncation; the every-cycle "one cycle behind" WW3 fallback is the designed H2.2 publish-latency behavior). **The operator's "inputs are broken" hypothesis is disproven with evidence; the defect is display selection.** | 4, 12(period), 13 | CONFIRMED (live payload + buoy + code) |
| **M3 — Card content accreted through individually-authorized text rulings that were never visually reviewed as a whole.** Current Swell card: original operator 2x2 baseline (a49059d, 2026-07-16: title + 3 stat tiles + component table + compass) → 12 sections today; every addition traces to a real plan task/ruling, but the plans' own closeouts say "operator visual eyeball remains the open tail." Score bars: fill /100 comes from a session-authored doc whose "(user-specified)" label the operator has now REPUDIATED ("That was not my ruling at all") — the per-category-max rule the operator just gave RESTORES the original ADR-096. | 1, 5, 6 | CONFIRMED (git provenance) |

Remaining items: 2/3 (score adjustments semantics — real design gaps, decisions below), 9/10 (beach
profile — one hard bug + design questions + one upstream data-shape question).

## 1. FIX ROUNDS (already authorized or pure bug — no further rulings needed)

**ROUND A — dashboard (weewx-clearskies-dashboard), one implementer + adversarial audit:**
- A1. Score bars fill to each category's own max (`ScoreBar` fillPct, SurfingTab.tsx:219) —
  RULED at eyeball (item 1). Same commit: fix DESIGN-MANUAL's self-contradiction (≈:1343 vs :1386)
  in favor of per-category (record: restores ADR-096; the /100 "SURF-1 normalization rule" text is
  removed as repudiated). Adjustments column bars left untouched pending D3.
- A2. Current Swell card strip to the a49059d baseline (+ keep the existing peel row) — RULED at
  eyeball (item 6: "strip the card back down… we can add peel"; peel is ALREADY rendered :2257,
  so "add" = keep). Remove: best-peak/average headline, main-break-zone text, wave-shape row,
  SurfBeat section. **EXCEPTION pending D2:** the shadow line + AT BREAK rows were restored to
  this card by the operator's own D10.2 ruling THIS WEEK — strip order vs D10.2 collision goes to
  the operator (D2) before those two sections are touched.
- A3. Beach-profile break-point label collisions (item 9d) — confirmed bug (zero collision logic,
  BeachProfileChart.tsx:740-850, while zone labels already get background rects :656-670). Fix:
  same background-rect treatment + min-x-separation stagger.
- A4. Client resilience (items 7/8/12 client half): arm the retry/backoff in `useApiQuery`'s error
  path (today it only schedules refresh on success) and/or give the marine hooks a pollInterval,
  so a transient 503 self-heals without a page reload. Methodology, no contract change.

**ROUND B — API (weewx-clearskies-api), small:**
- B1. Raise `_PROXY_REQUEST_TIMEOUT_S` (companion_proxy.py:142) 15 s → 45 s so the 25-30 s profile
  route can complete at all; unblocks the heatmap immediately. Tuning of an existing constant.
  (Long-term compute placement is D7 — not this round.)
- B2. Tracked perf item (no code this round): marine contention — a 25-30 s profile computation
  appears able to starve concurrent `/marine/{id}` requests into timeout (03:52:29Z incident +
  lead's own probe raced an investigator's profile replay and got an empty payload). Measure
  before touching.

**ROUND C — marine serialization (weewx-clearskies-marine), gated on D1:** headline/table
period+direction sourcing change per whichever convention the operator picks.

Deploy note: marine `47c8084` (dead-code deletions, aud-del3 DEPLOY-SAFE) rides whichever marine
deploy happens first.

## 2. OPERATOR DECISION QUEUE (to be presented ONE AT A TIME, in this order)

- **D1 (biggest UX payoff): which period represents the surf?** Options: (i) dominant partition by
  the same rule waveShapeClassification already uses (largest breaking face height) — RECOMMENDED,
  one consistent "dominant" concept everywhere, matches Surfline's swell-led convention; (ii)
  largest-energy partition; (iii) keep Tm01 but relabel honestly ("mixed sea state") and show top
  partitions in the sentence. Direction row follows the same choice.
- **D2: strip-order vs D10.2 collision** — shadow line + AT BREAK rows on Current Swell: keep on
  the stripped card / relocate (e.g. into Beach Profile card area) / drop entirely.
- **D3: adjustments display** — they are percentage cuts of the running subtotal (no max exists by
  design). Options: (i) no bars for adjustments, just signed values + one-line explainer; (ii)
  display-only nominal denominator; (iii) restructure scoring so adjustments become fixed point
  pools — trigger 1, formula change, largest option.
- **D4: Time of Day is structurally dead** (inputs hardcoded None since C-47, 2026-07-25). Options:
  (i) wire the existing almanac fetch through (reopens C-47 scope; plumbing, no new formula);
  (ii) remove the row from the card until wired.
- **D5: Beach profile design set** (items 9a/b/c/e/f/h): y-axis positive-space scale, x-extent
  tier ladder vs real surf-zone extent, wet/dry visual distinction, "Show wave shapes" toggle
  naming vs always-on breaker icons, overall element reduction (~45-55 SVG elements today).
  Options enumerated in inv-profile's brief; needs the operator's picks, likely with mockups.
- **D6: zones per break** (item 10) — upstream emits ONE impact/foam zone pair anchored to the
  outermost break by design (`_classify_zones`, surf_1d_analytical.py:514-578); per-break zones =
  data-contract shape change (trigger 4). Yes/no.
- **D7: heatmap long-term** — leave synchronous-but-slower (B1 timeout covers it) vs precompute/
  cache the all-transects payload on a schedule (triggers 5/6). B1 makes this non-urgent.
- **D8: Exposure adjustment** — live code, possibly legitimately 0 forever for an open beach; lead
  to run one live check of the spot's fan-derived sector map, then: leave / hide row / investigate
  derivation.

## 3. OPEN VERIFICATION TAILS

- Lead live-check of the spot's `directional_exposure` sector map (feeds D8).
- Beach-profile near-shore "flat slab": real berm vs fallback-profile artifact — needs one live
  payload check with the spot id (inv-profile lacked it).
- inv-swell NOTE: WW3 "one cycle behind" fallback fired on 9/9 recent cycles (designed behavior,
  but worth a one-time check that it is never 2+ cycles stale at serve time).
- Screenshots: operator to save the session's images as files; bind to feedback-log rows.
- Process lesson to surface (NOT auto-ruled): a doc label "(user-specified)" is not an operator
  ruling — the /100 bar rule incident. Operator decides if it gets written into rules.

## 4. WHAT THIS PLAN DOES NOT TOUCH

Wind §5 migration (step-1 gate still observing, step 2 queued behind it), C1-C6 50 m round,
spacing slider round, F2b admin-sends-all round — all previously queued, unchanged by this plan.
