# SURF PHYSICS REMODEL PLAN — 2026-08-05, REWRITTEN 2026-08-06

**STATUS: APPROVED — operator, 2026-08-06, in chat ("ok approved"), superseding the voided
2026-08-05 approval of the pre-rewrite text.** D-1 through D-7 are adopted as the lead
recommendations stated in each item (per the same approval; the operator may override any D-item
in chat at any time — an override lands in the decision register). This file was REWRITTEN IN
PLACE on operator order ("ONE PLAN! ONE PLAN ONLY!") — there is no other plan document. Every factual claim below either
survived independent re-verification against the code at marine `d74c578` and live librewxr data,
or is marked as an open DECIDE item. Audit evidence (per-claim verdicts, commands attached):
`scratch/Y0-FACT-PIN-2026-08-05.md`, `scratch/YQ-1-ENERGY-DEFICIT-2026-08-05.md`,
`scratch/X0-FACT-PIN-2026-08-05.md`, `scratch/Z-PREMISE-AUDIT-2026-08-06.md`,
`scratch/MEM-1-OOM-INVESTIGATION-2026-08-05.md`.

(Process notes, on record: an execution false-start before the original approval occurred
2026-08-05 — two agents dispatched and stopped on operator order; no files or commits resulted.
The original plan's Round Y named a collapse site deleted 2026-07-26, ten days before drafting,
contradicting ARCHITECTURE.md — the round built on it was struck in this rewrite.)

**Operator mandate (2026-08-05, in chat, verbatim anchors):** "yes you need to remodel the energy
correctly" · "It is not showing breaks where breaks are occurring… nature is right, you are not…
it is most definitely a physics issue" · "make sure we are picking a transect that has identified
as producing the best surf" · "update the plan with what is needed to be done, make sure it is
granular and specific, so the design is done NOW, not during implementation. It needs to include
updates to documentation as well."

**Acceptance standard for the whole program (operator-set, unchanged):** the drawn breaks match
the webcam — the outer-bar break AND the shorebreak — at the hour of comparison. Model self-tests
never close a round on their own; the reality gate does.

## Root causes (as verified 2026-08-06)

1. **All-or-nothing breaking — VERIFIED at HEAD.** The Round W breaking model triggers only when
   Hs exceeds γ·d (hard trigger; `_ddd_breaking_march`, X0 table). Real seas are a height
   distribution: the tallest waves break over the bar while Hs is still well below γ·d — the
   webcam shows breaking the model never draws. The pre-Round-W model carried a statistical
   breaking fraction; Round W1 (`e048494`) dropped it — the code survives in-file as deprecated
   dead functions (`_solve_breaking_fraction`, `_battjes_janssen`, `_roller_model`;
   `surf_1d_analytical.py:236-449`). **Round X restores it.**
2. **[STRUCK 2026-08-06 — the original root cause #2 ("spectrum-collapsing boundary",
   `ww3_to_swan_boundary()`) was STALE at drafting.** That function was deleted 2026-07-26
   (`5fe77af`); a real multi-station 2-D spectral boundary (BOUNDSPEC VARIABLE FILE from NOAA
   gfswave station spectra) has been live since. YQ-1's healthy-cycle energy chain (buoy 0.6 m/13 s
   → handoff ≈0.5 m → breaking face 0.7–0.95 m) shows ordinary shoaling, not starvation; the "⅓
   energy" figure has no locatable measurement. **No boundary remodel round exists in this plan.**
   The one real, confirmed handoff defect found in its place is task H-1 below.]
3. **Selection/anchoring defects — VERIFIED at HEAD, one instance reproduced live.** The published
   "best" transect is a face-height statistic that wanders the ~1.6 km fan hour-to-hour with zero
   bathymetric awareness (the "index 27 while bar transects 48/55 sit unpublished" pattern
   reproduces in the current forecast cache); the shared per-spot shoreline anchor is computed on
   the COARSE grid (`grid_sizing_chain.py:1485-1488`), landing ~50–70 m seaward of true shore
   (top-level profile depth at distance 0 = 2.822 m, reproduced bit-for-bit). **Round Z fixes
   both.**

**Newly confirmed defects (2026-08-06, not in the original plan):**
- **OOM kill-loop (production outage).** librewxr is an LXC container with a 6 GB memory cap; the
  marine service loads the on-disk forecast cache monolithically at every startup
  (`providers/nearshore/swan.py:1482-1539`) and that cache grew 24 MB → 223 MB in 10 days (the
  "transect" entries persist full 162-transect 1 m-resolution arrays per timestep,
  `surf_1d_pipeline.py:2347`). Process peaks ~3.2 GB; the host kernel OOM-kills it mid-run every
  ~7 minutes (continuous since 2026-08-05 22:17Z). **Task M-0.**
- **Silent whole-hour handoff collapse ("mechanism B").** On ~12% of hours in one clean cycle (0%
  on most healthy cycles; far denser during the OOM loop), the entire 162-transect set silently
  bulk-falls-back to a single scalar wave. The trigger is an unlogged early-exit among three
  candidate `continue` points in `swan_runner.py:908-1011` — no WARNING, no health signal.
  **Task H-1.** (Collapsed hours would also corrupt Round X's reality-gate evidence — hence H-1
  precedes X's gate.)

## DECIDE — the seven decisions (ALL RULED — operator "ok approved", 2026-08-06)

Plain-English record of what each decision was and what was chosen. **Nothing here is still
open** — this section stays only so the record of the choices is readable. (Register item 8
holds the same rulings in summary form.)

- **D-1 — the crashing service.** The service kept getting killed for using too much memory,
  traced to a saved-forecast file that had bloated to 223 MB and gets loaded whole at startup.
  Options were: (a) immediately move the bloated file out of the way and restart — instant
  relief, one forecast gap until the next run rebuilds it; (b) the real fix — stop the service
  from saving the enormous raw wave data that made the file that big (it saves a trimmed file
  now, about 17 MB); (c) just give the machine more memory. **Chosen: (a) right away AND (b)
  as the real fix. Both are built and running; the four-clean-cycles proof (task M-0) is what
  remains.**

- **D-2 — the order of the work.** Fix stability first (M-0), then add warning log lines at
  the places where the model silently gives up (H-1), then fix the breaking-wave physics
  (Round X), then
  fix which part of the beach the site shows (Round Z). Reason: there's no point polishing
  physics on a service that's crashing, and the webcam comparison only proves anything once
  hours aren't being silently corrupted. **Chosen: yes, that order.**

- **D-3 — what happens when the offshore wave data is bad.** When too few trustworthy
  offshore data stations are available, the service refuses to produce a forecast for that
  run rather than inventing a stand-in. No backup tiers, ever. This was already the
  operator's July 26 ruling; the ask here was only to confirm it still stands. **Chosen:
  confirmed. It stands.**

- **D-4 — approving the logging work.** Writing warning lines into the log at the
  silent-failure spots (H-1) — they are log entries, not alarms (operator correction
  2026-08-06) — was new work not in the original plan, so it needed an explicit yes before
  being built. **Chosen: approved as written.**

- **D-5 — a second, look-alike height cap.** The code has two similar-looking caps on wave
  height. Round X deletes one of them (the one proven to cause wrong results). The other does
  a different job — limiting a wave's face height by the water depth it breaks in — and
  nothing was found wrong with it. **Chosen: leave the second cap alone. Written down as an
  explicit "do not touch" so nobody 'fixes' it in passing.**

- **D-6 — one more file on Round X's allowed-files list.** The pre-work investigation proved
  the surf-zone drawing (where the whitewater and impact zones start and end) actually
  happens in a different file than the plan assumed, so that file (the beach-profile page
  code) had to join the short list of files Round X is allowed to edit. **Chosen: approved.**

- **D-7 — what to call the chosen beach line on the site.** The old plan wanted a technical
  label for the measurement line the site displays; the operator had already ruled (Aug 2)
  that site visitors won't understand jargon like that. Options were: no label at all, or a
  plain-language one such as "Surf shown at the sandbar, about 260 ft south of the pier".
  **RE-RULED 2026-08-06: NO label at all.** The operator killed the label entirely — site
  visitors don't care where on the beach the measurement comes from. The selection fix
  ships invisibly, and the Z-gate wording-approval step is dropped. (Supersedes the
  original "plain-language label" choice.)

## Task M-0 — service stability (FIRST; per D-1 ruling)

Execute the D-1 remediation. Accept: service publishes; `/health` = ok; **4 consecutive OOM-free
cycles** (ratbert `dmesg` clean for the marine cgroup — raw output pasted); post-deploy journal
sweep (pre/post ERROR/WARNING class counts). No other task's deploy or reality gate may run
before M-0 closes.

## Task H-1 — handoff-collapse instrumentation and fix (per D-3/D-4; before X's reality gate)

1. Each of the three silent exit points in `swan_runner.py:908-1011` gets a WARNING naming the
   hour, the cause, and the transect count affected.
2. `/health` gains a flag when any hour's bulk-fallback exceeds a threshold count (design
   constant, reviewed at the H-1 gate — not admin config).
3. Verify a boundary refusal (D-3) is distinctly named in `/health`; add the reason string only
   if missing.
4. Once instrumented cycles pin the trigger, fix it — the fix returns to the operator first if it
   trips any architectural trigger.
(Considered and dropped with the struck boundary round: the boundary conservation invariant —
revive only on evidence.)

Accept: forced-collapse test fires the flag; instrumentation visible in journal on real cycles;
across 4 consecutive healthy cycles every bulk-fallback hour is accounted for by a logged cause.
Adversarial brief: "Prove an hour can still collapse to bulk-fallback without the new flag firing;
force each exit path independently."

## Task SW-1 — swell fidelity + score-card swell text (operator order 2026-08-06, in chat, with screenshots)

**Operator mandate (verbatim anchors):** "figure out why you are still not getting the swell
correct … their swells and our swells do not match up, yet they both pull from the same source
that we do to begin with" · "your text surf forecast on the surf score card is wrong, as it is
not selecting the correct swell at all and it touting the wind swell at 4 seconds."

**Reference numbers pinned at order time (hour ≈ 2026-08-06 03:00–06:00Z / Wed Aug 5 evening
PDT, Huntington), transcribed from the operator's screenshots BEFORE examining our own output
(rules/verification.md — pick the comparison before looking):**
- Surfline (LOTUS + Smart Cam): swells **1.2 ft @ 12 s S 185° · 1.1 ft @ 9 s S 178° ·
  1.1 ft @ 6 s W 271°**; observed surf **2–3 ft (thigh to waist)**.
- surf-forecast.com (Wed 8–11 PM cols): Swell 1 **1.5 ft @ 14 s SW**; Swell 2 **0.5–1 ft @
  11–12 s SSW** (one col 1 ft @ 4 s W); Swell 3 **0.5 ft @ 9 s S**; wind waves 1–1.5 ft @ 5 s W.
- Our chain, YQ-1's clean-cycle measurement (2026-08-05T22:00Z): handoff partitions
  **groundswell 0.48 m (1.6 ft) @ 13.4 s + wind_swell 0.22 m (0.7 ft) @ 5.8 s** — TWO
  partitions where both externals resolve THREE swell trains including a distinct ~9 s
  mid-period swell.

**SW-1a (read-only investigation):** why don't our published swells match? Compare, for
matching valid hours: (i) our published deep-water-reference partitions (`multiSwell`, L2 @
the 15 m contour) vs the pinned externals; (ii) the RAW gfswave station spectra our L1
boundary actually ingested that cycle (46222/46253/46256 .spec files / their parsed forms) —
does the ~9 s train exist in our INPUT? If yes, find where it dies (L1→L2 nesting, the DWR
SPECOUT extraction, or SWAN watershed partitioning at the DWR point — the one leg YQ-1
explicitly never instrumented is L1→L2→L3 nesting, §Q3(b)); if no, the loss is upstream
(station selection / spectral ingest). Also compare direction: our groundswell direction vs
S 178–185°. Deliverable: scratch fact table, file:line + raw numbers, no code changes.
**SW-1b (defect-site pin):** locate the surf score card's text-forecast swell-selection code
(repo/file/line), state the rule it implements today, and why it selects the 4–6 s wind swell.
Note adjacency: EYEBALL-FIX-PLAN S-5 (dominant-partition direction, ruled 2026-08-05,
scheduled in X's window) — SW-1b's fix likely rides the same window; do not duplicate S-5.
**SW-1b scope extension (operator, 2026-08-06, follow-up in chat):** the SAME wrong-swell
selection appears on the CURRENT swell conditions display, and the operator states this "WAS
CORRECTED ONCE BUT HAS APPARENTLY REGRESSED." SW-1b must therefore also: (i) cover the
current-conditions swell display's selection path, (ii) find the PRIOR fix in git history
(likely candidates: the spectral_dwr/spectral channel separation `83f0205`, or a
dominant-partition selection fix), and (iii) identify which commit regressed it (prime
suspect window: the Round S surf-scorer rebuild `2ef8191..bdf4db8`, 2026-08-05). A regression
of a previously-fixed behavior also means a MISSING GUARD — SW-1b names the test that should
have pinned the fix and did not.
**Disposition:** findings return to the operator with proposed fix scope and which round
carries each fix. No fix ships from SW-1 itself. SW-1a's answer may adjust Round X's premise
set (X consumes the boundary/DWR chain it describes) — surfaced before X dispatch if so.

## Task SW-2 — forecast-card wave data from NOAA's raw files (operator ruling, register item 10)

*(Added to the plan 2026-08-06 when the operator ruled it in chat; the full ruling text lives
in decision-register item 10. This section exists so the task is findable in the task list,
not only inside the register.)*

**What it is, plainly:** the provider that fills the marine forecast cards was found reading a
third-party convenience feed (University of Hawaii's ERDDAP republication) that carries only
blended summary numbers. The operator ruled: wave-forecast data comes from NOAA's own raw
wave-model files (GRIB format, from NOAA's NOMADS server), parsed by us, including NOAA's
separate swell-1/2/3 breakdown; the third-party feed is deleted outright; no fallback sources
ever; when NOAA's newest run isn't posted yet, wait and check back — never reprocess an older
run (the forecast already on the site stays up while waiting).

**Status: CODE COMPLETE 2026-08-06** — marine repo commit `b924c90` (provider rewritten to
NOMADS GRIB2, ERDDAP deleted, swell-1/2/3 fields added, wait-and-poll cycle discipline,
refuse-on-failure at the endpoints; 14 targeted tests; PROVIDER-MANUAL §14.3 updated in the
same window). Deploys with the post-gate deploy train. Follow-ups tracked in the execution
scratch: dashboard rendering of the new swell-2/3 fields; a missing-value sentinel fix in the
shared GRIB helper for other callers.

## ROUND X — Breaking-energy remodel (statistical breaking, one-sided decay, roller, cap deleted)

### X-DESIGN (final unless the operator overrules at the X gate)

**X-D1. Statistical breaking fraction (restores wave-height statistics).**
- Wave heights are Rayleigh-distributed about Hrms (Hrms = Hs/√2, existing convention).
- Breaking fraction Q_b from the Battjes–Janssen implicit relation
  `(1 − Q_b)/ln(Q_b) = −(Hrms/H_max)²` with `H_max = γ·d`, γ = 0.73 **unchanged**.
  Solved by iteration (Brent), the SAME solve this repo carried pre-Round-W (LC-22 operator
  ruling already classifies this iterative solve as methodology). **Implementation route
  (coordinator ruling, per this plan's own "SAME solve" language): revive and adapt the
  deprecated in-file implementations** (`_solve_breaking_fraction()` :236-316,
  `_battjes_janssen()` :319-405, `_roller_model()` :408-449 — dead since Round W1, zero live call
  sites) rather than writing fresh code.
- **Break-onset semantics replace the hard trigger:** a breaking zone begins where Q_b rises
  through `Q_B_VISIBLE = 0.05` (5% of waves breaking — visible, webcam-meaningful) and a PRIMARY
  break point is marked at the local maximum of dissipation within that zone. Cessation when
  Q_b falls through `Q_B_CESSATION = 0.02` AND H < Γ·d (existing cessation retained as the AND
  term). Re-break = a new rise through Q_B_VISIBLE after a cessation (multi-bar profiles get one
  break point per bar — the distinct-onset guarantee). **Re-formation is FORBIDDEN in depth
  < 0.15 m** (operator ruling 3, closes DQ-W1): shoreward of the 15 cm contour a ceased wave
  never re-enters the breaking state machine — that water is swash, not surf. (Today's
  `_MIN_BREAK_DEPTH_M = 0.15` is only a publication filter — this state-machine rule is new code.)
- Both constants are DESIGN CONSTANTS reviewed at the X gate with worked examples; they are not
  admin config.

**X-D2. Dissipation becomes Q_b-weighted and strictly one-sided.**
- The DDD relaxation applies to the breaking sub-population only:
  `d(H²·h^½)/dx = −(K/h)·Q_b_eff·[H²·h^½ − Γ²·h^(5/2)]` with K = 0.15, Γ = 0.40 unchanged, and
  `Q_b_eff = Q_b / Q_B_VISIBLE` capped at 1 (full DDD strength once breaking is fully developed).
- **One-sided:** the bracket is floored at zero — where H < Γ·h the dissipation term is exactly 0.
  Energy NEVER flows from ocean to wave. The exponential-integrator step keeps its exact form but
  is applied only when the bracket is positive; otherwise the step is identity.
- Worked consequence (X-K2 fixture; energy premise corrected 2026-08-06): at today's measured
  small-surf bar-crest Hs ≈ 0.55 m (d ≈ 2.2 m incl. tide) → Hrms/Hmax ≈ 0.24 → Q_b ≈ 3–5×10⁻³ →
  below Q_B_VISIBLE → no DRAWN bar break (honest — nature barely breaks there on such hours);
  at Hs ≈ 1.1 m over the bar → Q_b ≈ 0.08–0.15 → bar break PUBLISHED at the crest. The healthy
  energy chain (YQ-1) already delivers realistic Hs at the bar — X alone is expected to put the
  break at the bar on real swell days; the webcam gate (Row 1) decides.

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
(`surf_1d_analytical.py:615-749`, anchor CONFIRMED at `d74c578` by X0) is removed. With X-D2
one-sided, marched > raw is mathematically impossible; a fire-only invariant
(`marched ≤ raw + 1 mm`) proves it in production instead of enforcing it. DQ-W3 closes with this.
**Explicit non-goal (per D-5 recommendation): the face-height depth cap at
`surf_1d_pipeline.py:754` is NOT touched.**

**X-D5. Files (allowlist — corrected 2026-08-06 per X0; line anchors re-pinned at dispatch
pre-flight):**
- `weewx_clearskies_marine/services/surf_1d_analytical.py` — `_ddd_breaking_march` (state machine
  → Q_b semantics, one-sided step), revived `_breaking_fraction()` (B-J solve), roller march,
  `apply_ddd_saturation` (cap deletion + invariant), `_find_break_points` (Q_b-based
  onset/cessation markers).
- `weewx_clearskies_marine/services/surf_1d_pipeline.py` — carry Q_b/roller outputs on the
  internal result objects (TransectResult/PartitionBreakResult fields; NOT served-payload wire
  changes).
- `weewx_clearskies_marine/endpoints/beach_profile.py` — zone-extent construction consumes E_r
  (per D-6; the actual `_classify_zones*` call site).
- `weewx_clearskies_marine/services/invariants.py` — two new fire-only invariants (closure,
  no-gain).
- Tests: `tests/services/test_breaking_fraction_kat.py` (new), `test_roller_closure_kat.py`
  (new), updates to the Round W guard tests pinning hard-onset semantics — inventory of all 9
  files/~30 tests with supersede/keep/uncertain buckets is in `scratch/X0-FACT-PIN-2026-08-05.md`;
  each update listed and justified in the closeout; stale-test block applies.

### X known-answer tests (mandatory, independent implementations)
- **X-K1:** revived `_breaking_fraction()` vs an independent Brent solve of the B-J relation
  (numeric table: Hrms/Hmax ∈ {0.3, 0.5, 0.7, 0.85, 1.0} → Q_b reference values) — independent
  implementation, not a rearrangement.
- **X-K2:** the T55 bar fixture (real bathymetry from
  `spot_profiles/huntington-city-beach-pier.json`, profiles_by_transect["55"] — confirmed live
  and readable on librewxr, 261 points, bar depth-minimum 1.545 m at 79.74 m): at Hs=0.55 m no
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
| X0 | Fact-pin | **DONE 2026-08-06** — `scratch/X0-FACT-PIN-2026-08-05.md`, lead-verified | Anchor + test-inventory tables, file:line-cited |
| X1 | Revive/adapt `_breaking_fraction()` (B-J Q_b, Brent) + Q_b-based onset/cessation/re-break state machine incl. 15 cm reform floor | Sonnet dev | X-K1 passes; X-K2 fixture rows |
| X2 | One-sided Q_b-weighted dissipation (exact integrator, identity step when bracket ≤ 0) | Sonnet dev | X-K4 passes |
| X3 | Roller march (revive `_roller_model` basis) + closure accounting; whitewater/impact extents derived from E_r through beach_profile.py | Sonnet dev | X-K3 passes; zone extents change only via E_r |
| X4 | Delete W1b cap; add the two fire-only invariants | Sonnet dev | Cap gone; invariants registered + logged |
| X5 | Tests: X-K1..K4 + state-machine unit tests + dispositions for every Round-W guard in X0's inventory (each listed/justified) | Sonnet test-author | Fail-pre-change transcript per KAT |
| X6 | Docs per table below + ADR-102 | Sonnet docs | Doc-sync checklist green |
| X7 | **X-QC gate** (below) then deploy + reality gate | Lead | All gate rows pass, raw output pasted |

### X reality gate (pre-stated)
- **Row 1 (the operator's standard):** on the first day with Surfline-reported groundswell ≥ 3 ft
  / ≥ 12 s: webcam shows bar-zone breaking ⇔ card + heat map show an outer break within ±40 ft of
  the bar crest, same hour, screenshot beside payload. FAIL either direction (drawn-but-absent,
  absent-but-visible) = round stays open. (Gate hours must be H-1-clean: no bulk-fallback flag.)
- **Row 2:** zero firings of the two new invariants across 4 consecutive cycles.
- **Row 3:** publish-liveness + journal sweep per rules/verification.md §marine-deploy.

## ROUND Z — Selection & anchoring (the picture shows the surf that matters)

### Z-DESIGN

**Z-D1. Bar-aware, surf-first transect selection** *(replaces the pure face-height statistic;
option (a) quality-scored sticky selection is RULED — decision-register item 1).*
- Within `_compute_main_break_zone()`'s winning zone (`surf_1d_pipeline.py:1281-1467` BD-9 block —
  anchors CONFIRMED at `d74c578`), the representative becomes the transect maximizing
  `surf_display_score = 2·(has ≥2 published breaks) + 1·(outermost breaker_type == plunging) +
  face_height/zone_max_face`; ties → nearest the spot pin (`MarineLocation.lat/lon` projected to
  the segment). Also anchored: `endpoints/beach_profile.py` `_select_best_transect()` (:357-377).
- **Stickiness:** the selected index persists across hours unless the new winner beats the
  incumbent's score by >20% — kills the hour-to-hour wander the operator caught (reproduced live:
  "index 27" pattern in the current forecast cache).
- The selection function takes an optional override index so the next-phase per-spot "sampling
  marker" (decision-register item 1) becomes a config lookup later — nothing here may preclude it.
- Card labeling per **D-7** (the original "Line N of 162" label conflicted with the operator's
  2026-08-02 pulled-label ruling and is struck).

**Z-D2. Shared shoreline anchor on the FINE grid, rolled out by full spot re-establishment
(decision-register ruling 6).** Two parts:
1. **The fix:** `grid_sizing_chain.py:1485-1488` computes the per-spot coastline anchor with
   `find_shoreline_from_grid(coarse_grid, …)`; change to the fine grid (`bathymetry.py:1338-1380`
   same function, fine input — the per-transect path at `grid_sizing_chain.py:2168-2171` already
   does exactly this; all anchors CONFIRMED at `d74c578`). Accept: rebuilt anchor within 15 m of
   the median of the 162 per-transect anchors; top-level "profile" depth at distance 0 ≤ 0.5 m
   (was 2.822 m, reproduced live).
2. **The rollout mechanism — `reestablish_spot(spot_id)`:** delete EVERY persisted artifact of
   the spot, then rebuild from configuration exactly as a newly-created spot would be. No
   incremental invalidation, no surviving files (operator ruling 6: "too many instances where
   something OLD is carried over"). **Teardown list (EXPANDED 2026-08-06 per Z-premise audit —
   the original list missed five live artifact classes):** spot_profiles JSON; grid-sizing
   caches; bathymetry-derived per-spot caches **including every co-existing hash-keyed
   generation** (`swan_bathymetry_{L1,L2,L3_*,L4_*,PROFILE_*}*.json` — multiple generations
   verified live, nothing replaced in place); transect/anchor data; all hotstart files; the
   spot's forecast-cache entries; **grid-identity hash markers** (`*_bbox_hash.txt`,
   `*_geom_hash.txt`); **leftover `swan-precleanup-*` snapshot dirs**; the two
   undetermined-ownership files flagged in the audit (Z0 resolves ownership pre-dispatch;
   unresolvable → surfaced). This routine is permanent infrastructure: every future
   spot-geometry redefinition goes through it (config-UI wiring is next-phase with the sampling
   marker). `_clear_stale_swan_run_state()` survives only as an internal step of the teardown.
   Grid extents after re-establishment are whatever the corrected inputs produce — no
   stop-and-ask tolerance (pre-authorized, ruling 6); the before/after grid diff is pasted in
   the gate record.

**Z-D3. Heat-map double-break truthfulness.** With X live, verify `HeatMapCard` renders both
break bands (it consumes the published zones; expected: no code change — this is a verification
task, promoted to a fix task only on failure).

**Z-D4. Heat-map orthophoto registration (operator, 2026-08-05, with screenshot; premise
CONFIRMED nearly verbatim by `HeatMapCard.tsx:176-197`'s own comments).** The aerial imagery is
drawn north-up while the heat-map data field is in the shore-local transect frame. **Ruling: the
DATA frame is authoritative; the imagery conforms to it, never the reverse.** Design: register the
imagery to the transect frame with an affine transform (rotate + uniform scale + translate)
derived from two geographic control points exact in BOTH frames — the segment start and end
(lat/lon → imagery pixel via the imagery's own georeference; lat/lon → data-frame coordinates via
the existing segment geometry). Apply client-side as a canvas/CSS matrix transform on the imagery
layer only (data layers untouched); imagery clipped to the data extent after transform. Scale
check: the segment length must measure identically on both layers within 1% — that number is a
Z-gate row. Z0 fact-pins the imagery source (asset vs tile fetch), its georeference metadata, and
`HeatMapCard`'s layer stack before the build brief.

### Z tasks
Z0 fact-pin (selection call sites + heat-map layer stack/georeference + zone consumption +
teardown-artifact ownership; seeded by `scratch/Z-PREMISE-AUDIT-2026-08-06.md`, re-pinned at
then-HEAD), Z1 (Z-D1), Z2 (Z-D2), Z3 (Z-D3 verify), Z3b (Z-D4 imagery registration), Z4 tests
(selection unit tests incl. stickiness hysteresis; anchor accept numbers as a KAT against the
fine grid; imagery-registration control-point test with a fixed fixture), Z5 docs, Z6 blind
audit, Z7 deploy + reality gate (gate rows: displayed transect is a bar-transect on a bar-break
day; anchor numbers pasted; pier in imagery lies under pier-adjacent transects — operator
screenshot check; segment-length scale agreement ≤1%).

## DOCUMENTATION — exact deltas (each ships in its task's code commit; none deferred)

| Doc | Task | Delta | Status |
|---|---|---|---|
| `docs/decisions/ADR-102-statistical-breaking-roller.md` (NEW) | X | The X-DESIGN verbatim: Q_b relation, constants (γ 0.73, Γ 0.40, K 0.15, Q_B_VISIBLE 0.05, Q_B_CESSATION 0.02, β_D 0.10), one-sidedness, roller balance, cap deletion, closure invariants, worked X-K2 example. Status Accepted on operator gate pass. | Open |
| `docs/decisions/ADR-103-spectral-boundary.md` | H-1 | REWRITTEN from the original plan's version: documents the boundary design that ACTUALLY exists (multi-station BOUNDSPEC, station selection, refuse-don't-degrade per D-3) — NOT the struck three-tier design. | Open |
| `docs/ARCHITECTURE.md` | H-1, X, Z | H-1: handoff-collapse instrumentation + health flag; X: breaking model → statistical Q_b + roller, cap removed; Z: transect selection + stickiness, fine-grid anchor, `reestablish_spot` lifecycle rule. | Open |
| `docs/manuals/PROVIDER-MANUAL.md` | H-1 | Bulk-fallback semantics, new WARNING classes, health flag meaning. | Open |
| `docs/manuals/API-MANUAL.md` | X, Z | §17–18: break-point semantics (Q_b-based onset, one point per bar), whitewater/impact-zone derivation from roller (X); `transectIndex` display contract + stickiness note (Z). | Open |
| `docs/manuals/DASHBOARD-MANUAL.md` | Z | Label per D-7 + heat-map imagery registration (data-frame-authoritative rule, control-point transform). | Open (catch-up DOC-0 **DONE** `e5a94e1`) |
| `docs/manuals/DESIGN-MANUAL.md` | Z | Label pattern per D-7. | Open (catch-up **DONE** `e5a94e1`) |
| `docs/manuals/OPERATIONS-MANUAL.md` | M-0, H-1 | M-0: cache lifecycle per D-1(b); H-1: new health reasons, invariant names and what firing means. | Open |
| Operator Manual + `help.admin.surf_scoring.*` | — | **DONE** (DOC-1: stack `940047f`, meta `86b9d4e`). | Done |
| ~~`docs/reference/swan-commands-extract.md`~~ | — | Row struck: file FROZEN as pure manual extract (operator ruling 2026-08-06, `caf49e8`); never carries project usage. | Struck |
| `docs/planning/EYEBALL-FIX-PLAN-2026-08-04.md` | X window | STATUS points here for all physics work; S-5 code change (dominant-partition direction, ruled 2026-08-05) scheduled in X's window (small, marine repo unfrozen). | Open |

Completed pre-round work, on record: DOC-0 (`e5a94e1`), DOC-1 (`940047f`/`86b9d4e`), M-1
configobj (`d74c578`, test passes on librewxr: 2 passed).

## QC GATES — one per round; a round is CLOSED only when every row of its gate passes

**Gate template (identical rows for X-QC and Z-QC; H-1 and M-0 use their own accept criteria
above plus rows 4–6; a round that skips a row is not closed):**

| Row | Check | Evidence required |
|---|---|---|
| 1 | Scope walkthrough | Every brief in-scope item DONE (commit hash) / DEFERRED (tracked) / else round stays open; `git show --stat` diffed against the allowlist |
| 2 | Guards + KATs | Lead independently re-runs the round's targeted tests from a fresh shell (never trusts agent counts); every KAT's fail-pre-change transcript on record |
| 3 | **Blind adversarial audit** | A separate Sonnet auditor briefed to DISPROVE the round's claims; sees the design (this plan + brief) and the code — NEVER the dev's tests, commits, or report. Passes only with "could not disprove" PLUS a named list of what it ruled out and how; every finding lead-synthesized (accept/push-back/defer) and remediations re-audited |
| 4 | Doc-code sync | The round's doc-delta table rows all landed in the SAME commits as their code; lead spot-opens one doc claim against the code |
| 5 | Deploy discipline | deploy script only; running commit + process start-time recorded; post-deploy journal sweep for new ERROR/WARNING classes (pre/post counts pasted) |
| 6 | Reality gate | The round's pre-stated reality rows, raw output pasted beside the external reference; tolerances as written in this plan, never restated after seeing numbers |

**Per-round adversarial briefs (what row 3's auditor is told to break):**
- **H-1:** "Prove an hour can still collapse to bulk-fallback without the new flag firing; force
  each of the three exit paths independently; prove a boundary refusal can pass unnamed in
  /health."
- **X-QC:** "Prove energy is created or lost untracked: adversarial bathymetries (bar–trough–bar,
  knife-edge crests, the 15 cm floor boundary); prove Q_b wrong against your own independent
  solve; prove a second bar can still be swallowed; prove the deleted cap was hiding something
  that now publishes garbage; prove the roller books energy twice or never."
- **Z-QC:** "Prove something OLD survives `reestablish_spot()` — enumerate every file the marine
  service can persist for a spot, re-establish, then find ANY artifact with a pre-teardown
  timestamp (operator ruling 6 is the claim under attack; the expanded teardown list is the
  surface). Prove the selection flaps hour-to-hour despite stickiness; prove the imagery
  transform is off by more than 1% scale or misregisters the pier."

## Standing process (applies to every task above)
- Dispatch gate: allowlist, design-to-file-and-line (this document + the task's fact-pin table),
  prohibition list, live check with expected numbers — written in the brief before any agent
  starts. Mandatory blocks (git, architectural, stale-test) verbatim in every brief.
- Sonnet for all delegated work; the lead re-runs every claim before accepting it.
- Never the full test suite — targeted files only. One functional change per deploy; reality
  gate rows pasted raw.
- Any trigger-list hit not described in this operator-approved plan → STOP and surface.
- Pending process items (NOT rules until the operator says so): plan claims carry file:line at a
  named commit verified at drafting; coordinator reads (not greps) ARCHITECTURE's relevant
  section at dispatch.

## Decision register

Written in plain English by operator order (2026-08-06). Technical names appear only in
parentheses so each ruling can be traced to the code and tasks it governs.

**This register is the permanent RECORD of rulings already made** — it exists so decisions
don't get lost between sessions and compactions. Nothing in it is a new question for the
operator unless explicitly marked **OPEN QUESTION**.

**From the 2026-08-05 approval (these rulings stand on their own, independent of the plan
sections that were later struck):**

1. **Which stretch of beach the site shows.** The site will automatically pick the measurement
   line (out of the 162 lines we compute across the beach) that has the best real surf on it,
   and it will stick with its pick instead of jumping around hour to hour. **How it sticks
   (added 2026-08-06, answering the operator's question):** once a line is picked, the
   display keeps it unless another line's surf becomes at least 20% better (the switching
   threshold in item 2). Small hour-to-hour differences never move the pick — it changes
   only when the beach genuinely shifts, and the exact stick-with-it mechanics are what
   Round Z builds and demonstrates at its gate. Separately, in a
   FUTURE phase, the operator gets a way to pin the display to one chosen place on the beach
   (for example, the well-known surfers' peak about 100 yards south of the Huntington pier),
   which overrides the automatic pick. That pin is NOT built in this plan — but today's code
   must be written so it can be added later without rework (the picker accepts an optional
   "use this line instead" input; task Z-D1).

2. **The tuning numbers are approved as shipped (a record, not a question).** This entry
   simply writes down the exact dial settings the plan ships with, so any later drift is
   visible against this list: breaking waves count as "visible" when 5% of waves are
   breaking; breaking counts as "stopped" at 2%; whitewater fades at rate 0.10; a new beach
   line must be 20% better before the display switches to it; and the shoreline position
   must land within 15 m, in water shallower than 0.5 m. These ship at exactly these
   values. Changing any of them later requires before/after evidence at a gate, never a
   casual edit.

3. **No fake waves in ankle-deep water.** Once a wave has broken and died out, the model may
   never "re-form" it in water shallower than 15 centimeters — that thin water is wash on the
   sand, not surf, and drawing new waves there was wrong. (Folded into Round X's breaking
   rules.)

4. **A small developer tool was approved and installed.** (The `configobj` library, used only
   for tests — done, commit `d74c578`.)

5. **One webcam check, not two.** The older plan had its own "compare against the webcam"
   sign-off; that is merged into Round X's webcam gate so the visual standard is checked once,
   in one place.

6. **Redefining a surf spot means starting it over, never patching it.** When a spot's
   geometry changes, every saved file that belongs to it is deleted and the spot is rebuilt
   from its configuration exactly as if it were brand new. No partial updates, no reused grid
   files. Operator's reason, quoted: "There has just been too many instances where something
   OLD is carried over." Round Z builds this teardown-and-rebuild routine
   (`reestablish_spot`), and it becomes the only way spot geometry ever changes from now on.
   Whatever grid sizes the rebuilt inputs produce are accepted as-is, but the before/after
   comparison is pasted into the gate record for review.

**Added 2026-08-06 (operator, in chat):**

7. **The SWAN manual extract is frozen.** The file holding copied-out pages of the official
   wave-model manual (`docs/reference/swan-commands-extract.md`) is a pure reference copy. It
   may not be edited without the operator's direct say-so, and nothing about OUR use of the
   model may ever be written into it — our usage lives in the project manuals. (Executed,
   commit `caf49e8`.)

8. **All seven open decisions were approved as recommended ("ok approved").** In plain terms:
   fix the crashing service first by moving the oversized cache file aside immediately AND
   building the real fix that keeps the file small (D-1); do the work in the order stability →
   silent-failure alarms → breaking physics → display/selection (D-2, the order M-0 → H-1 →
   X → Z); when the offshore wave data isn't good enough, the service refuses to run rather
   than substituting something worse — no backup tiers (D-3); the silent-failure alarm work is
   approved as written (D-4); a second, unrelated wave-height cap stays untouched in Round X
   (D-5); one more file joins Round X's allowed-files list because that's where the work
   actually lives (D-6); the beach line the site shows gets NO label at all — the operator
   re-ruled 2026-08-06 that visitors don't care where on the beach the measurement comes
   from, so the selection fix ships invisibly and no wording approval is needed at the
   Round Z gate (D-7, re-ruled — originally a plain-language label). Anything the operator
   says in chat later overrides this register and gets recorded here.

9. **"Figure out why the swells are still wrong" (operator order, with Surfline and
   surf-forecast screenshots).** Two complaints: our published swells don't match what
   Surfline and surf-forecast show for the same hour, and the surf score card's text (plus,
   per a follow-up, the current-conditions display) headlines the wrong swell — the short
   choppy wind swell instead of the real groundswell. Task SW-1 investigates both immediately;
   any fix comes back to the operator for approval before it ships. The comparison numbers
   from the screenshots were written down BEFORE our own output was examined, so the test
   can't be bent to match.

10. **Wave-forecast data comes from NOAA's raw files that we parse ourselves — never from
    third-party convenience feeds.** Operator's words: "WW3 data should be coming to us in
    grib files that we have to parse. They should not be coming from erddap" and "WW3 SHOULD
    NEVER EVER FALLBACK TO CRAP SOURCES." What triggered it: the provider that fills the
    marine forecast display cards was found to be reading a University-of-Hawaii convenience
    feed (PacIOOS ERDDAP) that serves only summary numbers — no wave spectrum — because
    NOAA's own convenience feed had once been unreachable and the code was pointed elsewhere
    instead of at the raw files. The wave model's own input was checked and is NOT affected —
    it reads NOAA's full raw station spectra directly (verified live 2026-08-06). Task SW-2
    rewrites the display provider to download NOAA's raw wave-model files (GRIB format, from
    NOAA's NOMADS server) and parse them in-house — including NOAA's separate swell-1/2/3
    breakdown, so the display finally shows multiple swells. The third-party feed is deleted
    outright; if NOAA's files can't be fetched, the provider says so and serves nothing,
    rather than quietly using something worse.

    **Ruled 2026-08-06 (operator): the old-batch reuse is DEAD for the forecast cards.**
    When NOAA's newest batch isn't published yet, the provider does NOT process the older
    batch — it waits and checks back until the new batch appears, then processes that.
    Operator's words: "it should wait to do the processing until it has been published,
    which means waiting and checking back. We operate on NOAA's timeline, not our
    timeline. Why would we use the old data, when the new data may then come out 10
    minutes later?" The forecast already on the site (built from the last batch that WAS
    published and processed) simply stays up while we wait — waiting never blanks the
    display. This is binding SW-2 design.

    **OPEN QUESTION (one word needed):** does this also change the wave model's own
    boundary download? Today that download always uses NOAA's newest PUBLISHED run — it
    never skips a newer published run, and the hourly rerun picks each new run up as soon
    as NOAA posts it (the "retry older cycles" code is only how it finds the newest one
    NOAA has actually posted). Making it "wait" instead would pause new surf forecasts for
    the 3.5–5 hours after every NOAA run time — that's how long NOAA takes to post, so
    roughly 60% of all hours — with nothing newer existing to wait for. Recommendation:
    the boundary stays as-is, because it already lives on NOAA's timeline. Say "boundary
    waits too" to override.

11. **Everything currently waiting on the operator, in one place (added 2026-08-06 after
    the operator was surprised by an unrecorded question — every open item and every
    standing lead-call now lives HERE, updated as they open and close).**

    **OPEN QUESTIONS — nothing ships on these without your word:**
    - **(a) RULED 2026-08-06 (operator): NO infrastructure change.** "It was always
      working fine before... That is not my problem that is your problem. It is apparent
      you are holding information that does not have to be held in memory... There is no
      reason you should be even anywhere NEAR the 6GB cap even with the radar piece."
      The cap stays, the radar stays; the marine service's memory footprint is a
      REGRESSION and reducing it is in-scope M-0 work: find what is being held that
      doesn't need holding, and stop holding it. M0b (dead spectral fields) was the
      first cut; the hunt continues (MEM-3) until the service fits with wide margin.
    - **(b) RULED 2026-08-06 (operator): "yes, do both, and then finish everything in
      the plan."** The checking tests (X5) are authorized and dispatched; when they pass
      and the Round X gate closes, everything ships. The card rewiring (item 13) is
      authorized to build. Full completion of the plan's remaining rounds (Z2 onward,
      gates, deploys) is authorized — open items surface only if NEW architectural
      territory appears. The one standing recommendation not explicitly overruled —
      item (d), the wave model does NOT sit idle waiting on NOAA — stands as
      recommended.
    - **(c) RESOLVED 2026-08-06 — the operator was right: NOAA's GRIB files carry all
      the swells.** Live check at Huntington (lead, against NOAA's own file): swells of
      12.4 s, 14.2 s, AND 9.2 s all present, plus the wind chop, all separate. The
      earlier "NOAA doesn't have it" finding applied only to a DIFFERENT NOAA product
      (the per-station spectrum files the wave model reads at its offshore edge), not to
      these files. The rewritten card provider reads exactly these files, so the cards
      get the full picture once it ships. The same check exposed one real defect: the
      grid square nearest the pier is blanked-out land in NOAA's file, and the provider
      as first written would have served blanks there — a fix (use the nearest square
      that actually has ocean data) is in progress (SW-2b). Whether the wave model's own
      offshore-edge input also needs a better source is being investigated with this new
      evidence; no decision needed from the operator right now.
    - **(NEW, 2026-08-06) OPEN QUESTION — what do boating/fishing locations show once the
      separate pull dies?** Some configured marine locations are boating- or fishing-only
      points with no surf spot — the wave model does not cover them, so there is no
      "model's own data" for them. Today their wave numbers (the boating tab's forecast
      chart, the landing-page wave height) come from the separate NOAA map-file pull that
      ruling 13 retires. Options: (i) keep the map-file source ONLY for these no-model
      locations — where the model doesn't run, there is no model truth to disagree with
      (recommendation); (ii) show buoy observations only, no forecast; (iii) drop wave
      data for them entirely. Surf spots are unaffected either way — they get the model's
      own numbers. Building the surf-spot side now; this fork only gates the final
      deletion of the old provider.
    - **(NEW, 2026-08-06) OPEN QUESTION — the aerial-photo alignment fix (Z-D4) cannot be
      built as designed; pick a path.** The investigation (Z3b fact-pin) proved the
      approved design's assumptions are wrong in the code: the two alignment reference
      points it needs don't exist anywhere in the dashboard's data; the heat-map's
      vertical axis is just a row number with no real-world spacing (so the "lengths
      agree within 1%" check has nothing to measure); the beach lines fan out radially
      from one center rather than lying along a straight segment; and the imagery
      service provides no georeference. Options: (i) build it RIGHT — add the few
      missing geometry fields to the API response (an additive data-contract change) and
      register the imagery to the fan's real geometry (recommendation; it is the only
      path that actually delivers the operator's "the imagery conforms to the data"
      ruling); (ii) defer the imagery alignment to a later phase and leave the photo
      layer as-is (visibly misaligned); (iii) hide the photo layer under the heat map
      until (i) can be done (honest but loses the imagery). Say (i)/(ii)/(iii).
    - **(d) Should the wave model sit and wait when NOAA is late?** The wave model — the
      physics engine that computes the surf forecast — needs offshore wave data to start
      each run. Today it always uses the newest data NOAA has actually posted, and never
      ignores newer data. The question: when NOAA is late posting (they take 3.5–5 hours
      after each run time), should the model sit idle waiting instead of running with
      the newest posted data? Waiting would stop surf updates for most of every day,
      and there is nothing newer to wait for during that window. Recommendation: leave
      it alone. Say "boundary waits too" only if you want the waiting behavior anyway.

    **STANDING LEAD RULINGS — made under delegated authority, in force now, say the word
    to overrule:**
    - **(e) SW-2 cold-start exception:** when the provider starts with NO processed
      forecast at all, it fetches the newest run NOAA has already published (bounded
      search back through at most 3 runs) instead of showing empty cards for hours; once
      any run has succeeded, the strict wait-and-check-back rule governs forever after.
      *(Covered by ruling 12 below — the service decides what it serves; stands unless
      specifically overruled.)*
    - **(f) Whitewater self-check scoping (Round X):** the energy-balance self-check
      skips any march step whose endpoints sit at the numerical depth or wave-speed
      floor near the water's edge (wording corrected 2026-08-06 per audit finding F4 —
      this can be several consecutive shoreward points, not literally one) — the 1%
      accuracy bar itself is untouched. Without this the alarm would cry wolf every
      cycle on healthy runs.
    - **(g) Whitewater self-check scoping, part 2 (2026-08-06, audit-remediation F2):**
      the rebuilt energy-balance self-check (which now cross-checks two independent
      numerical methods so a wrong coefficient actually trips it — audit finding F2)
      compares the two methods PER BREAKING ZONE IN AGGREGATE, not step-by-step
      (final form, 2026-08-06, after a fourth measured stop). History, recorded
      honestly: the per-step comparison failed four ways in sequence — the switch-on
      step (excluded), its multi-step settling tail (a ratio-based exclusion was tried
      and WITHDRAWN: measured relative forcing change falls under 10% one step after
      onset while the residual stays over 1% for several more, so the ratio tracks
      nothing useful), and the stiff shoreline tail (excluded, (h)). The offline
      known-answer test had already proven the AGGREGATE form of the same two-method
      comparison agrees within 1% on these exact fixtures — so the production check
      now uses that proven form: both methods' energy budgets are accumulated across
      each breaking zone (skipping only the water's-edge floor (f), the stiff terminal
      (h), and the single switch-on step), and the alarm compares the totals. One
      diluted transient step cannot fake a wrong coefficient, and a wrong coefficient
      shifts EVERY step so the aggregate trips decisively (demonstrated with a
      deliberately-wrong coefficient before shipping). The 1% bar is untouched.
    - **(h) Whitewater self-check scoping, part 3 (2026-08-06, second F2 stop):** in the
      last few steps before the shoreline the whitewater drain term grows without bound
      as wave speed dies (a "stiff" equation, in numerical-methods terms), so the
      production scheme's own per-step error grows smoothly there and the two-method
      comparison reports that scheme divergence — on perfectly healthy physics — well
      before the water's-edge floor of (f) engages. The check therefore also skips
      steps whose dimensionless stiffness number (drain coefficient × step size)
      exceeds a fixed round threshold — the standard criterion for "this step size
      can't follow this equation here." The dev picks the round value (0.5 or 1.0) that
      cleanly separates the stiff terminal steps from the healthy interior on the
      existing fixtures, reports the margin, and STOPS if no round value separates
      cleanly. Honest side-note recorded with this ruling: this means the whitewater
      numbers in the last couple of steps before the sand are locally imprecise by
      construction; harmless in practice (the whitewater is dying to zero there anyway,
      and the zone boundaries are decided by the healthy interior), and noted as a known
      limitation in the round's decision record. The 1% bar is untouched.

13. **ONE source of offshore truth (operator, 2026-08-06, in chat — RULED, supersedes the
    two-feed arrangement).** Operator's words: "EVERYTHING WE NEED IS IN OUR GOD DAMNED
    MODELS, WHAT THE FUCK ARE WE PULLING SEPARATE INFORMATION FOR?" The offshore wave data
    the wave model ingests IS the offshore wave data the cards report. There is no second,
    separate NOAA download for display. The card provider's separate pull (including the
    SW-2 rewrite of it) is to be retired and the cards fed from the model's own ingested
    data. **[Updated 2026-08-06: the stop was lifted by ruling 11(b) ("yes, do both, and
    then finish everything in the plan"). The ingestion-defect premise was then DISPROVED
    by measurement (ING-1's energy ledger: <0.03% loss end-to-end; the model was never
    underfed — the "missing" 9-second swell is a labeling/partitioning phenomenon, not
    lost energy). The ONE-SOURCE-OF-TRUTH goal of this ruling stands on its own and is
    being built. Implementation per the RW-0 fact-pin: for surf spots the cards read the
    wave model's OWN computed swell breakdown — SWAN's built-in partitioning is already
    running in production for other purposes, so no new physics is invented and the cards
    cannot disagree with the model. One fork is open for the operator: what non-surf
    marine locations (boating/fishing points the model doesn't cover) should show — see
    item 11's open question.]**

12. **The display layer is source-blind; the marine service/API owns the data (operator,
    2026-08-06, in chat).** Operator's words: "The forecast cards should not care or have
    knowledge about what data they are getting, they ask for data, the API delivers the
    data. it is up to the marine service/API to determine what it should be serving. The
    cadence for processing NOAA data should not change, the cards should not care or know
    about the data. They should ask for break height, we deliver break height." Standing
    principle for ALL current and future work: sourcing, cadence, freshness, and
    what-to-serve decisions live entirely in the marine service/API; the dashboard/cards
    never embed source knowledge or timing logic. (SW-2 as shipped conforms: no dashboard
    code was touched; the served forecast cadence is unchanged; the 10-minute
    publication-poll is internal to the service.)
