# SURF PHYSICS REMODEL PLAN — 2026-08-05

**AUTHORIZED — operator, 2026-08-05, in chat: "the plan is permission for the architectural
modifications." All trigger-list items enumerated in this plan are pre-approved; only NEW
architectural territory discovered mid-build (not described here) still stops and surfaces.**

**Operator mandate (2026-08-05, in chat, verbatim anchors):** "yes you need to remodel the energy
correctly" · "It is not showing breaks where breaks are occurring… nature is right, you are not…
it is most definitely a physics issue" · "make sure we are picking a transect that has identified
as producing the best surf" · "update the plan with what is needed to be done, make sure it is
granular and specific, so the design is done NOW, not during implementation. It needs to include
updates to documentation as well."

**Acceptance standard for the whole program (operator-set):** the drawn breaks match the webcam —
the outer-bar break AND the shorebreak — at the hour of comparison. Model self-tests never close a
round on their own; the reality gate does.

**Root causes this plan fixes (all three proven 2026-08-05, evidence in
EYEBALL-FIX-EXECUTION-SCRATCH and the three investigation closeouts):**
1. **All-or-nothing breaking.** The Round W breaking model triggers only when the representative
   height Hs exceeds γ·d. Real seas are a height distribution: the tallest waves break over the
   bar while Hs is still well below γ·d — the webcam shows exactly this, the model shows nothing.
   (Measured: Hs at the T48/T55 bar crest ≈ 0.52–0.55 m vs γ·d ≈ 1.55–1.67 m; nature still breaks
   its biggest waves there.) The pre-Round-W model carried a statistical breaking fraction; the
   Round W replacement silently dropped it.
2. **Spectrum-collapsing boundary.** Our handoff synthesizes ONE parametric peak from scalar WW3
   fields, discarding the real multi-train swell energy (C-81/C-83). Live effect measured: the
   model carries ~⅓ of the energy needed at the bar.
3. **Selection/anchoring defects.** The published "best" transect is a face-height statistic that
   wanders the full ~1.6 km fan hour-to-hour with zero bathymetric awareness (was index 27 while
   the bar transects 48/55 sat unpublished); and the shared per-spot shoreline anchor is located
   on the COARSE grid, landing ~50–70 m seaward of true shore (the "9 ft of water at the
   shoreline" defect the operator caught).

**Round order:** Y (boundary energy) → X (breaking-energy remodel) → Z (selection/anchoring).
Y first because every downstream physics test is meaningless while the model is starved to ⅓
energy. Docs ship IN the same round/commit as the code they describe (doc-code sync rule) — never
as a trailing round.

---

## ROUND Y — Boundary spectrum integrity (feed the model the ocean's real energy)

### Y-DESIGN (final unless the operator overrules at the Y gate)

**Y-D1. Boundary construction becomes spectral, three-tier by data availability:**
1. **Tier 1 (preferred): full WW3 directional spectrum.** The `ww3_spectrum` provider already
   fetches NOAA spectral products (it is fetching tonight — journal shows it live). When a valid
   spectrum for the boundary point/cycle exists, write it to SWAN as a 2-D spectral boundary file
   (SWAN `BOUNDSPEC … VARIABLE FILE` family — command syntax verified against the local manual
   `docs/reference/swan-user-manual.txt` §4.5 before dispatch; NO web lookups).
2. **Tier 2 (fallback): per-partition superposition.** From WW3 partitioned scalars (each
   partition's Hs_i, Tp_i, dir_i, spread_i): build one JONSWAP (peak-enhancement 3.3) ×
   cosᵐ directional distribution PER PARTITION and SUM them into the 2-D boundary spectrum.
   m from spread_i via the standard cosᵐ⇄spread relation (manual §2.6.3 band: swell narrow,
   wind sea broad). This preserves every train's energy at its own period and direction.
3. **Tier 3 (last resort): today's single-peak synthesis**, retained ONLY as an explicit degraded
   mode that logs a WARNING naming the tier and sets a `boundary_degraded` flag surfaced by
   /health. Never silent.

**Y-D2. Conservation contract at the boundary:** total energy of the written boundary spectrum
equals the WW3 source total within 2% (Tier 1) / 5% (Tier 2). This is a fire-only invariant
(alarm, not control), plus a KAT (below).

**Y-D3. No re-tuning anywhere downstream.** Gamma, Γ, K, curves, weights: untouched in Round Y.
If bigger honest inputs expose downstream misbehavior, that is a FINDING for Round X — not a
licence to tune in Y.

**Y-D4. Code anchors** (the collapse site is `ww3_to_swan_boundary()` per the C-81/C-83
postmortem; exact file:line, the current SWAN boundary command in use (TPAR vs SPEC), and the
`ww3_spectrum` provider's actual product coverage are pinned by a read-only Sonnet fact-pin task
**Y0** whose output completes the per-file allowlist BEFORE the build brief is issued — the
dispatch gate's "design to file and line" is satisfied by Y-D1..D3 + Y0's anchor table).

### Y tasks

| # | Task | Owner | Accept criteria |
|---|---|---|---|
| Y0 | Fact-pin: boundary path file:line table; current SWAN boundary command per level; ww3_spectrum provider products, coverage, staleness rules; boundary point(s) used | Sonnet (read-only) | Table in scratch, every claim file:line-cited |
| Y1 | Implement Y-D1 tiers 1–3 + Y-D2 invariant | Sonnet dev | KATs Y-K1..K3 pass; tier WARNING/flag on forced fallback |
| Y2 | Tests (KATs below + tier-fallback unit tests), each proven to FAIL pre-change | Sonnet test-author | Fail-pre-change transcript per KAT |
| Y3 | Docs (see table at bottom): PROVIDER-MANUAL ww3_spectrum section; ARCHITECTURE marine data-flow; swan-commands-extract boundary commands; ADR-102 authored | Sonnet docs + lead review | Doc-code sync checklist all green |
| Y4 | Blind adversarial audit (auditor sees design + code, never dev tests/commits) | Sonnet auditor | "Could not disprove" + named rule-outs, or findings remediated |
| Y5 | Deploy + reality gate | Lead | Gate rows below, raw output pasted |

### Y known-answer tests (mandatory, independent implementations)
- **Y-K1:** synthetic 2-partition WW3 fixture (1.0 m/14 s/210° + 0.4 m/6 s/250°) → boundary file
  total energy = analytic sum within 2%; each partition's peak present at its own (f,θ) within one
  bin. Reference computed by an independent integration, not the implementation's own code.
- **Y-K2:** Tier-2 JONSWAP+cosᵐ builder vs an independently coded JONSWAP (different author,
  different code path — the `test_surf_1d_dispersion.py` pattern).
- **Y-K3:** Tier-3 forced → flag set, WARNING logged, output equals today's behavior bit-for-bit
  (regression pin for the degraded mode).

### Y reality gate (tolerances pre-stated NOW)
- **Row 1:** handoff Hs at the 3.27 m handoff (T48/T55) vs NDBC 46222-derived shoaled estimate:
  within ±25%. (Today's value 0.47–0.51 m is the "before" record.)
- **Row 2:** dominant partition period at handoff = buoy dominant period ±1.5 s (kills the
  "4 s everywhere" symptom).
- **Row 3:** publish-liveness + journal sweep per rules/verification.md §marine-deploy.

---

## ROUND X — Breaking-energy remodel (statistical breaking, one-sided decay, roller, cap deleted)

### X-DESIGN (final unless the operator overrules at the X gate)

**X-D1. Statistical breaking fraction (restores wave-height statistics).**
- Wave heights are Rayleigh-distributed about Hrms (Hrms = Hs/√2, existing convention).
- Breaking fraction Q_b from the Battjes–Janssen implicit relation
  `(1 − Q_b)/ln(Q_b) = −(Hrms/H_max)²` with `H_max = γ·d`, γ = 0.73 **unchanged**.
  Solved by iteration (Brent), the SAME solve this repo carried pre-Round-W (LC-22 operator
  ruling already classifies this iterative solve as methodology).
- **Break-onset semantics replace the hard trigger:** a breaking zone begins where Q_b rises
  through `Q_B_VISIBLE = 0.05` (5% of waves breaking — visible, webcam-meaningful) and a PRIMARY
  break point is marked at the local maximum of dissipation within that zone. Cessation when
  Q_b falls through `Q_B_CESSATION = 0.02` AND H < Γ·d (existing cessation retained as the AND
  term). Re-break = a new rise through Q_B_VISIBLE after a cessation (multi-bar profiles get one
  break point per bar — the distinct-onset guarantee). **Re-formation is FORBIDDEN in depth
  < 0.15 m** (operator ruling 3, closes DQ-W1): shoreward of the 15 cm contour a ceased wave
  never re-enters the breaking state machine — that water is swash, not surf.
- Both constants are DESIGN CONSTANTS reviewed at the X gate with worked examples; they are not
  admin config.

**X-D2. Dissipation becomes Q_b-weighted and strictly one-sided.**
- The DDD relaxation applies to the breaking sub-population only:
  `d(H²·h^½)/dx = −(K/h)·Q_b_eff·[H²·h^½ − Γ²·h^(5/2)]` with K = 0.15, Γ = 0.40 unchanged, and
  `Q_b_eff = Q_b / Q_B_VISIBLE` capped at 1 (full DDD strength once breaking is fully developed).
- **One-sided:** the bracket is floored at zero — where H < Γ·h the dissipation term is exactly 0.
  Energy NEVER flows from ocean to wave. The exponential-integrator step keeps its exact form but
  is applied only when the bracket is positive; otherwise the step is identity.
- Worked consequence (record as X-K2 fixture): today's measured case — Hs 0.55 m over the T55 bar
  crest (d≈2.2 m incl. tide) → Hrms/Hmax ≈ 0.24 → Q_b ≈ 3–5×10⁻³ → below Q_B_VISIBLE → still no
  DRAWN bar break at ⅓ energy (honest), but with Round Y restoring realistic energy
  (Hs ≈ 1.0–1.2 m at the bar) → Q_b ≈ 0.08–0.15 → bar break PUBLISHED at the crest. The pair of
  rounds, not either alone, is what puts the break at 260 ft.

**X-D3. Roller (energy accounting from break to beach).**
- New tracked reservoir per transect march: roller energy E_r with balance
  `d(2·E_r·c)/dx = D_br − D_r`, `D_r = g·β_D·E_r/c`, β_D = 0.10 (Svendsen-family standard;
  design constant). D_br is exactly the organized-wave energy removed by X-D2 — every joule
  removed enters E_r; E_r decays shoreward to turbulence (leaves the tracked system only through
  D_r).
- E_r drives (display/derived only — NO new wire fields in this round): whitewater band extent
  (band ends where E_r < 5% of its local maximum) and impact-zone intensity. The re-formed wave in
  the trough grows ONLY from unbroken residual energy (physics: the roller does not reorganize
  into swell); what the roller adds is honest whitewater geometry and closure accounting.
- **Closure invariant (fire-only):** at every march step,
  `E_organized_in = E_organized_out + ΔE_roller + ∫D_r` within 1% — the "losing track of energy"
  alarm the operator's conservation question demands.

**X-D4. The W1b cap is DELETED.** `min(marched, hs_total)` in `apply_ddd_saturation`
(surf_1d_analytical.py, function spans :615–749 pre-round; re-anchor at dispatch) is removed.
With X-D2 one-sided, marched > raw is mathematically impossible; a fire-only invariant
(`marched ≤ raw + 1 mm`) proves it in production instead of enforcing it. DQ-W3 closes with this.

**X-D5. Files (allowlist skeleton — exact line anchors re-pinned at dispatch pre-flight):**
- `weewx_clearskies_marine/services/surf_1d_analytical.py` — `_ddd_breaking_march` (state machine
  → Q_b semantics, one-sided step), new `_breaking_fraction()` (B-J solve), roller march,
  `apply_ddd_saturation` (cap deletion + invariant), `_find_break_points` (Q_b-based
  onset/cessation markers).
- `weewx_clearskies_marine/services/surf_1d_pipeline.py` — plumb Q_b/roller outputs to zones;
  no wire changes.
- `weewx_clearskies_marine/services/invariants.py` — two new fire-only invariants (closure,
  no-gain).
- Tests: `tests/services/test_breaking_fraction_kat.py` (new), `test_roller_closure_kat.py`
  (new), updates to the Round W guard tests that pin the hard-onset semantics (each update listed
  and justified in the closeout; stale-test block applies).

### X known-answer tests (mandatory)
- **X-K1:** `_breaking_fraction()` vs an independent Brent solve of the B-J relation (numeric
  table: Hrms/Hmax ∈ {0.3, 0.5, 0.7, 0.85, 1.0} → Q_b reference values) — independent
  implementation, not a rearrangement.
- **X-K2:** the T55 bar fixture (real bathymetry from
  `spot_profiles/huntington-city-beach-pier.json`, profiles_by_transect["55"]): at Hs=0.55 m no
  published bar break; at Hs=1.1 m a bar break at 79.7 ± 8 m AND a distinct shorebreak — the
  double-break the heat map currently never shows.
- **X-K3:** roller closure on an analytic monotone slope: organized loss = roller gain + turbulent
  loss to 1% (independent trapezoid integration as reference).
- **X-K4:** one-sidedness: adversarial profile (bar–deep-trough–bar); assert H never increases
  across any march step beyond shoaling/refraction's own physics (no relaxation-driven growth).
- Every KAT's fail-pre-change transcript recorded (X-K2's double-break row MUST fail against
  current HEAD).

### X tasks

| # | Task | Owner | Accept criteria |
|---|---|---|---|
| X0 | Fact-pin: re-anchor every X-D5 file:line on current HEAD; inventory all Round-W guard tests pinning hard-onset semantics | Sonnet (read-only) | Anchor + test-inventory tables, file:line-cited |
| X1 | `_breaking_fraction()` (B-J Q_b, Brent) + Q_b-based onset/cessation/re-break state machine incl. 15 cm reform floor | Sonnet dev | X-K1 passes; X-K2 fixture rows |
| X2 | One-sided Q_b-weighted dissipation (exact integrator, identity step when bracket ≤ 0) | Sonnet dev | X-K4 passes |
| X3 | Roller march + closure accounting; whitewater/impact extents derived from E_r | Sonnet dev | X-K3 passes; zone extents change only via E_r |
| X4 | Delete W1b cap; add the two fire-only invariants | Sonnet dev | Cap gone; invariants registered + logged |
| X5 | Tests: X-K1..K4 + state-machine unit tests + updates to superseded Round-W guards (each listed/justified) | Sonnet test-author | Fail-pre-change transcript per KAT |
| X6 | Docs per table below + ADR-102 | Sonnet docs | Doc-sync checklist green |
| X7 | **X-QC gate** (below) then deploy + reality gate | Lead | All gate rows pass, raw output pasted |

### X reality gate (pre-stated)
- **Row 1 (the operator's standard):** on the first day with Surfline-reported groundswell ≥ 3 ft
  / ≥ 12 s: webcam shows bar-zone breaking ⇔ card + heat map show an outer break within ±40 ft of
  the bar crest, same hour, screenshot beside payload. FAIL either direction (drawn-but-absent,
  absent-but-visible) = round stays open.
- **Row 2:** zero firings of the two new invariants across 4 consecutive cycles.
- **Row 3:** publish-liveness + journal sweep.

---

## ROUND Z — Selection & anchoring (the picture shows the surf that matters)

### Z-DESIGN

**Z-D1. Bar-aware, surf-first transect selection** *(replaces the pure face-height statistic —
[DECIDE at Z gate: option (a) below is the lead recommendation; option (b) "always nearest the
spot pin" is the fallback if the operator prefers determinism]).*
- (a) Within `_compute_main_break_zone()`'s winning zone, the representative becomes the transect
  maximizing `surf_display_score = 2·(has ≥2 published breaks) + 1·(outermost breaker_type ==
  plunging) + face_height/zone_max_face`; ties → nearest the spot pin (`MarineLocation.lat/lon`
  projected to the segment). Anchors: `surf_1d_pipeline.py` `_compute_main_break_zone()`
  (:1281–1467 pre-round) BD-9 block; `endpoints/beach_profile.py` `_select_best_transect()`
  (:357–377).
- **Stickiness:** the selected index persists across hours unless the new winner beats the
  incumbent's score by >20% — kills the hour-to-hour wander the operator caught.
- The served payload's `transectIndex` is already on the wire; the dashboard card labels the
  displayed transect ("Line N of 162, x ft from pier") — one i18n string, 13 locales.

**Z-D2. Shared shoreline anchor on the FINE grid, rolled out by full spot re-establishment
(decision-register ruling 6).** Two parts:
1. **The fix:** `grid_sizing_chain.py:1485-1488` computes the per-spot coastline anchor with
   `find_shoreline_from_grid(coarse_grid, …)`; change to the fine grid (`bathymetry.py:1338-1380`
   same function, fine input — the per-transect path at `grid_sizing_chain.py:2168-2171` already
   does exactly this). Accept: rebuilt anchor within 15 m of the median of the 162 per-transect
   anchors; top-level "profile" depth at distance 0 ≤ 0.5 m (was 2.822 m).
2. **The rollout mechanism — `reestablish_spot(spot_id)`:** delete EVERY persisted artifact of
   the spot (spot_profiles JSON, grid-sizing caches, bathymetry-derived per-spot caches,
   transect/anchor data, all hotstart files, the spot's forecast-cache entries), then rebuild
   from configuration exactly as a newly-created spot would be. No incremental invalidation, no
   surviving files — operator ruling: "we need to treat it as deleting the old surf spot and
   re-establishing it… too many instances where something OLD is carried over." This routine is
   permanent infrastructure: every future spot-geometry redefinition goes through it (config UI
   wiring for that is the same next phase as the sampling-marker override).
   `_clear_stale_swan_run_state()` survives only as an internal step of the teardown. Grid
   extents after re-establishment are whatever the corrected inputs produce — no
   stop-and-ask tolerance (pre-authorized, ruling 6); the before/after grid diff is pasted in
   the gate record.

**Z-D3. Heat-map double-break truthfulness.** With X live, verify `HeatMapCard` renders both
break bands (it consumes the published zones; expected: no code change — this is a verification
task, promoted to a fix task only on failure).

**Z-D4. Heat-map orthophoto registration (operator, 2026-08-05, with screenshot).** Defect: the
aerial imagery under the surf-height heat map is drawn north-up, while the heat-map data field is
in the shore-local transect frame (alongshore × cross-shore, rotated to the operator-drawn
segment's bearing) — so the pier and shoreline in the photo do not lie under the data that
describes them. **Ruling: the DATA frame is authoritative; the imagery conforms to it, never the
reverse.** Design: register the imagery to the transect frame with an affine transform (rotate +
uniform scale + translate) derived from two geographic control points whose positions are exact
in BOTH frames — the segment start and end (lat/lon → imagery pixel via the imagery's own
georeference; lat/lon → data-frame coordinates via the existing segment geometry). Apply
client-side as a canvas/CSS matrix transform on the imagery layer only (data layers untouched);
imagery is clipped to the data extent after transform so no unregistered margins show. Scale
check: one control-distance (segment length in meters) must measure identically on both layers
within 1% — that number is a Z-gate row. Fact-pin in Z0: where the imagery comes from (asset vs
tile fetch), its georeference metadata, and `HeatMapCard`'s current layer stack — exact file:line
table before the build brief.

### Z tasks: Z0 fact-pin (selection call sites + heat map layer stack/georeference + zone
consumption), Z1 (Z-D1), Z2 (Z-D2), Z3 (Z-D3 verify), Z3b (Z-D4 imagery registration),
Z4 tests (selection unit tests incl. stickiness hysteresis; anchor accept numbers as a KAT
against the fine grid; imagery-registration control-point test with a fixed fixture), Z5 docs,
Z6 blind audit, Z7 deploy + reality gate (gate rows: displayed transect is bar-transect on a
bar-break day; anchor numbers pasted; pier in imagery lies under pier-adjacent transects —
operator screenshot check; segment-length scale agreement ≤1%).

---

## DOCUMENTATION — exact deltas (each ships in its round's code commit; none deferred)

| Doc | Round | Delta |
|---|---|---|
| `docs/decisions/ADR-102-statistical-breaking-roller.md` (NEW) | X | The X-DESIGN verbatim: Q_b relation, constants (γ 0.73, Γ 0.40, K 0.15, Q_B_VISIBLE 0.05, Q_B_CESSATION 0.02, β_D 0.10), one-sidedness, roller balance, cap deletion, closure invariants, worked X-K2 example. Status Accepted on operator gate pass. |
| `docs/decisions/ADR-103-spectral-boundary.md` (NEW) | Y | Three-tier boundary design, conservation contract, degraded-mode flag. |
| `docs/ARCHITECTURE.md` | Y, X, Z | Marine data-flow: WW3 spectral boundary tiers (Y); breaking model description → statistical Q_b + roller, cap removed (X); transect-selection + stickiness, fine-grid anchor (Z). |
| `docs/manuals/PROVIDER-MANUAL.md` | Y | `ww3_spectrum` products, tiers, staleness/fallback semantics, `boundary_degraded` health flag. |
| `docs/reference/swan-commands-extract.md` | Y | The boundary command actually emitted per level, before/after. |
| `docs/manuals/API-MANUAL.md` | X, Z | §17–18: break-point semantics (Q_b-based onset, one point per bar), whitewater/impact-zone derivation from roller (X); `transectIndex` display contract + stickiness note (Z). |
| `docs/manuals/DASHBOARD-MANUAL.md` | Z (+ catch-up NOW) | **Catch-up debt from tonight's shipped display fixes (dry-beach 50 ft cap, caption line removed, still-water/waterline text labels removed, foam zones removed, negative x-ticks) — task DOC-0, lands with this plan's first commit**; then Z: transect label + heat-map imagery registration (data-frame-authoritative rule, control-point transform). |
| `docs/manuals/DESIGN-MANUAL.md` | Z (+ catch-up NOW) | Same catch-up (beach-profile card anatomy); Z: transect label pattern. |
| `docs/manuals/OPERATIONS-MANUAL.md` | Y | New health reasons (`boundary_degraded`), invariant names and what firing means. |
| Operator Manual + `help.admin.surf_scoring.*` | catch-up NOW | **Outstanding Gate-S debt: "Surf Score Weights" operator-manual section + ARCHITECTURE route inventory (`/admin/surf-scoring`) — task DOC-1, lands before Round Y dispatch.** |
| `docs/planning/EYEBALL-FIX-PLAN-2026-08-04.md` | NOW | STATUS points here for all physics work; S-5 code change (dominant-partition direction, ruled 2026-08-05) scheduled as task DOC-2/S-5 in Round Y's window (small, marine repo now unfrozen). |

## QC GATES — one per round; a round is CLOSED only when every row of its gate passes

**Gate template (identical rows for Y-QC, X-QC, Z-QC; a round that skips a row is not closed):**

| Row | Check | Evidence required |
|---|---|---|
| 1 | Scope walkthrough | Every brief in-scope item DONE (commit hash) / DEFERRED (tracked) / else round stays open; `git show --stat` diffed against the allowlist |
| 2 | Guards + KATs | Lead independently re-runs the round's targeted tests from a fresh shell (never trusts agent counts); every KAT's fail-pre-change transcript on record |
| 3 | **Blind adversarial audit** | A separate Sonnet auditor briefed to DISPROVE the round's claims; sees the design (this plan + brief) and the code — NEVER the dev's tests, commits, or report. Passes only with "could not disprove" PLUS a named list of what it ruled out and how; every finding lead-synthesized (accept/push-back/defer) and remediations re-audited |
| 4 | Doc-code sync | The round's doc-delta table rows all landed in the SAME commits as their code; lead spot-opens one doc claim against the code |
| 5 | Deploy discipline | deploy script only; running commit + process start-time recorded; post-deploy journal sweep for new ERROR/WARNING classes (pre/post counts pasted) |
| 6 | Reality gate | The round's pre-stated reality rows, raw output pasted beside the external reference; tolerances as written in this plan, never restated after seeing numbers |

**Per-round adversarial briefs (what row 3's auditor is told to break):**
- **Y-QC:** "Prove the boundary loses or invents energy: force each tier, integrate the written
  spectra independently, hunt a partition that vanishes, a direction/period bin shift, a silent
  tier-3 fallback, a stale-spectrum reuse across cycles."
- **X-QC:** "Prove energy is created or lost untracked: adversarial bathymetries (bar–trough–bar,
  knife-edge crests, the 15 cm floor boundary); prove Q_b wrong against your own independent
  solve; prove a second bar can still be swallowed; prove the deleted cap was hiding something
  that now publishes garbage; prove the roller books energy twice or never."
- **Z-QC:** "Prove something OLD survives `reestablish_spot()` — enumerate every file the marine
  service can persist for a spot, re-establish, then find ANY artifact with a pre-teardown
  timestamp (operator ruling 6 is the claim under attack). Prove the selection flaps hour-to-hour
  despite stickiness; prove the imagery transform is off by more than 1% scale or misregisters
  the pier."

## Standing process (applies to every round above)
- Dispatch gate: allowlist, design-to-file-and-line (this document + the round's fact-pin table),
  prohibition list, live check with expected numbers — written in the round brief before any agent
  starts. Mandatory blocks (git, architectural, stale-test) verbatim in every brief.
- Sonnet for all delegated work; the lead re-runs every claim before accepting it.
- Never the full test suite — targeted files only.
- One functional change per deploy; reality gate rows pasted raw.
- Any trigger-list hit not described in this operator-approved plan → STOP and surface.

## Decision register for this plan — ALL RULED, operator 2026-08-05 (nothing open)
1. **Z-D1 = option (a)** (quality-scored sticky selection) as the DEFAULT, **plus a next-phase
   operator override**: a per-spot "sampling marker" the operator can pin at a specific location
   (e.g., HB: expert surfers' spot ~100 yards south of the pier) that overrides the algorithm and
   forces the displayed/sample transect. NOT built in this plan — recorded as the first item of
   the next phase; Z-D1's implementation must not preclude it (selection function takes an
   optional override index so the marker becomes a config lookup later).
2. **Constants approved as shipped defaults** (Q_B_VISIBLE 0.05, Q_B_CESSATION 0.02, β_D 0.10,
   stickiness 20%, anchor accept 15 m / 0.5 m). Tuning later only with gate evidence.
3. **Ankle-deep reform block approved** — no wave re-formation in depth < 15 cm (folded into
   X-D1 cessation/re-break semantics; closes DQ-W1).
4. **configobj approved** as a declared dev/test dependency (task M-1: add to pyproject dev
   extra, install on librewxr venv, un-exclude the test).
5. Round W's separate webcam sign-off item is dissolved into Round X's webcam gate (Row 1) —
   one visual standard, checked once, there.
6. **Spot lifecycle ruling (supersedes Z-D2's incremental approach): NO grid "adjustments."
   Redefining a surf spot = DELETE the old spot and RE-ESTABLISH it fresh** — all persisted
   artifacts destroyed (spot_profiles JSON, grid sizing caches, bathymetry-derived caches,
   transect/anchor data, hotstarts, forecast cache entries for the spot), then rebuilt from
   configuration as if newly created. Rationale (operator): "There has just been too many
   instances where something OLD is carried over." Z2 therefore implements a
   `reestablish_spot(spot_id)` teardown-and-rebuild routine, uses it to roll out the fine-grid
   anchor fix, and it becomes THE mechanism for every future spot-geometry change (the partial
   `_clear_stale_swan_run_state()` invalidation is subsumed — it remains only as the internal
   final step of teardown). Grid extents after re-establishment are whatever the corrected
   inputs produce — no tolerance gate, but the before/after grid diff is still pasted in the
   gate record. OPERATIONS-MANUAL documents the lifecycle; ARCHITECTURE.md states the rule.
