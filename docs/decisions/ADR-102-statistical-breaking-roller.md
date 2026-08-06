# ADR-102: Statistical Breaking Fraction (Q_b) and Roller Energy Balance Replace the Hard-Trigger DDD Cap

**Status:** Accepted. Design operator-approved 2026-08-05/06 (`docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md`
X-DESIGN, X-D1..X-D5, decision-register items 2/3/8/11(f)). Implementation landed marine repo
commits `bce8997` (X-D1/X-D2), `9b6a669` (X-D3), `2bb1cd1` (X-D4). This document is written during
the same task window as the code (X6), before the X7 reality gate has run — the gate's live-traffic
rows (webcam day, four-cycle zero-firing window, journal sweep) are still open; see "Acceptance
criteria" below for what is and is not yet checked off.
**Date:** 2026-08-06.
**Supersedes:** None as a separate ADR — this is the first ADR written for the breaking-dissipation
model itself. It documents the successor to the Round W DDD-with-hard-cap design (never itself the
subject of an ADR; described only in code comments/docstrings in `services/surf_1d_analytical.py`
prior to this document).
**Related:** ADR-093 (SWAN + SwellTrack nearshore model, the 1-D model's parent), ADR-095 (SWAN model
corrections), ADR-097 (beach profile endpoint — the zone-extent consumer).

## Context

The 1-D surf model ("SwellTrack", `weewx_clearskies_marine/services/surf_1d_analytical.py`) marches
wave height from the SWAN handoff to shore. Through Round W (2026-08-05) breaking was a **hard
trigger**: a wave was either fully unbroken or fully breaking based on a bare `H/d >= gamma`
ratio test, and post-breaking decay was clamped so the marched height could never exceed the raw
(pre-dissipation) input — `min(marched, hs_total)` in `apply_ddd_saturation`. This produced three
problems the operator's own conservation and webcam questions surfaced:

1. **No wave-height statistics.** Real wave fields are Rayleigh-distributed about Hrms; only a
   *fraction* of waves at a given point are actually breaking at any moment (Battjes & Janssen
   1978). The hard `H/d >= gamma` trigger treated the sea state as either 0% or 100% breaking,
   with no visibility into how "developed" a breaking zone was.
2. **No roller/whitewater accounting.** Energy removed from the organized wave by breaking simply
   vanished from the model's own books — nothing tracked where it went, so there was no way to
   answer "does this model conserve energy" and no physical driver for whitewater/impact-zone
   extent (that extent was instead read off an arbitrary `0.707 × Hs` height ratio).
3. **The cap was doing a job that shouldn't need doing.** `min(marched, hs_total)` silently
   enforced "the march never adds energy" — a property that, if the underlying dissipation term
   were correctly one-sided, would already be true by construction and would not need enforcing
   after the fact.

Round X (SURF-PHYSICS-REMODEL-PLAN-2026-08-05, X-DESIGN) replaces the hard trigger and the cap
with a statistical breaking-fraction state machine plus a roller-energy reservoir, operator-approved
2026-08-05/06.

## Options considered

| Option | Verdict |
|---|---|
| Keep the Round W hard `H/d >= gamma` trigger + `min(marched, hs_total)` cap | **Rejected.** No wave-height statistics, no energy-conservation answer, no whitewater-extent physics — exactly the three problems above. |
| Statistical breaking fraction Q_b (Battjes & Janssen 1978) driving onset/cessation, Q_b-weighted one-sided dissipation, roller-energy reservoir, cap deleted in favor of a proven-by-physics no-gain invariant | **Chosen and shipped** — X-DESIGN, this document. |
| A closed-form Q_b stand-in (`Qb = 1 - exp(-ratio**2)`) instead of the exact implicit relation | **Rejected, LC-22 (prior round).** Has a spurious floor: deep water never truly vanishes to zero dissipation. Not reopened by this round — the exact implicit solve was already the standing decision; X-D1 revives and reuses it. |

## Decision

**X-D1. Statistical breaking fraction replaces the hard trigger.**

Wave heights are Rayleigh-distributed about Hrms (`Hrms = Hs/√2`, existing convention). The
breaking fraction `Q_b` — the fraction of the wave population already breaking at a point — is the
*exact* implicit Battjes & Janssen (1978) solution of

```
(1 - Q_b) / ln(Q_b) = -(Hrms / Hmax)²,   Hmax = γ·d,   γ = 0.73 (unchanged)
```

solved by bisection in `u = ln(Q_b)` space (`_solve_breaking_fraction()`,
`surf_1d_analytical.py:309-399`) — revived and reused as-is from a deprecated, zero-call-site
implementation (LC-22's "SAME solve" language; no changes to the solve itself). γ = 0.73 is the
SAME onset gamma used everywhere else in the module — X-D1 introduces no separate onset constant.

**Onset/cessation/re-break state machine** (`_ddd_breaking_march()`,
`surf_1d_analytical.py:645-964`, and its combined-profile counterpart `apply_ddd_saturation()`,
`:967-1221`):

- **Onset:** a breaking zone begins the first point where `Q_b` rises through
  `Q_B_VISIBLE = 0.05` (`:71`) while unbroken — 5% of the wave population breaking, chosen as the
  visible/webcam-meaningful threshold because a smooth `Q_b` never hits exactly zero offshore and
  needs a threshold to mark "breaking has become visible" rather than a vanishing statistical tail.
- **Primary break-point marker:** unlike the pre-Round-X onset-crossing marker, the published break
  point is the breaking zone's **local maximum of dissipation** (largest per-step loss in the
  marched state variable `y = H²·h^½`), tracked continuously while breaking and finalized at
  cessation or end-of-profile (`:864-926` in `_ddd_breaking_march`; one marker per bar, by
  construction of the per-zone tracking).
- **Cessation:** `Q_b` falls through `Q_B_CESSATION = 0.02` (`:79`) AND `H <= Γ·d` (the pre-existing
  DDD-stable-height test, retained as the AND term) together flip the state back to unbroken.
- **Reform floor:** shoreward of `_REFORM_FLOOR_DEPTH_M = 0.15` m (`:94`, operator ruling 3,
  decision-register item 3, closes DQ-W1: "no wave re-formation in depth < 15 cm"), a wave that has
  already ceased breaking once may never re-enter the breaking state machine — that water is swash,
  not surf. The profile's first-ever onset is never subject to this floor; only RE-onset after a
  prior cessation is (`can_reform` guard, `:877`/`:1109`). `_REFORM_FLOOR_DEPTH_M` is a distinct
  symbol from the pre-existing `_MIN_BREAK_DEPTH_M` (`:1364`) even though both are 0.15 m — the
  latter is a publication filter applied after the fact by `_find_break_points`; the former is a
  state-machine rule enforced during the march itself.

Both `Q_B_VISIBLE` and `Q_B_CESSATION` are DESIGN CONSTANTS reviewed at the X gate with worked
examples (decision-register item 2: "these ship at exactly these values... changing any of them
later requires before/after evidence at a gate, never a casual edit") — not admin config.

**X-D2. Dissipation becomes Q_b-weighted and strictly one-sided.**

The Dally-Dean-Dalrymple (1985) post-breaking relaxation applies only to the breaking
sub-population, scaled by

```
Q_b_eff = min(1, Q_b / Q_B_VISIBLE)
```

(full DDD strength once `Q_b` reaches the visibility threshold), evaluated at the trailing
(already-computed) grid point. The governing equation

```
d(H²·h^½)/dx = -(K/h)·Q_b_eff·[H²·h^½ - Γ²·h^(5/2)]
```

keeps `K = _DDD_DECAY_K = 0.15` and `Γ = _DDD_STABLE_GAMMA = 0.40` (`:56`, `:47`) unchanged from
Round W. **One-sided:** the bracket `[H²·h^½ - Γ²·h^(5/2)]` is floored at zero before use
(`:897-905` per-partition march, `:1124-1132` combined-profile march) — where `H <= Γ·h` the step
is the exact identity on `y` (`y_i = y_prev`), not a fresh re-derivation. Energy never flows from
ocean to wave via this relaxation. The exact exponential-integrator closed form (Round W1b) is
retained for the `bracket > 0` branch; only the floor is new.

Worked consequence (X-K2 fixture, real Huntington Beach bathymetry, transect 55 — 261 points, bar
depth-minimum 1.545 m at 79.74 m offshore distance — `spot_profiles/huntington-city-beach-pier.json`,
`profiles_by_transect["55"]`):

| Bar-crest Hs (incl. tide, d ≈ 2.2 m) | Hrms/Hmax | Q_b | Published bar break? |
|---|---|---|---|
| ≈ 0.55 m | ≈ 0.24 | ≈ 3–5×10⁻³ | No — below `Q_B_VISIBLE` (honest: nature barely breaks there at that height) |
| ≈ 1.1 m | — | ≈ 0.08–0.15 | Yes — bar break published at the crest (79.7 ± 8 m), plus a distinct shorebreak |

**X-D3. Roller (post-breaking energy accounting from break to beach).**

A new tracked reservoir, roller energy density `E_r` (J/m²), carried at every grid point
(`_roller_energy_step()`, `surf_1d_analytical.py:535-642`, shared by both march functions),
independent of the Q_b state machine's own onset/cessation toggling — the roller persists and
decays through a later reformed (unbroken) stretch, matching how whitewater physically trails a
break shoreward. Balance:

```
d(2·E_r·c)/dx = D_br - D_r,     D_r = g·β_D·E_r/c,     β_D = _ROLLER_BETA_D = 0.10 (:105)
```

`c = L/T` via the existing dispersion solver (no new solve). `D_br` is exactly the organized-wave
energy removed by X-D2's dissipation step this same march step (`y_prev - y_i`, converted to a flux
rate via `F = E·Cg = 0.125·ρ·g^1.5·y` in the shallow-water regime, `:628`). `β_D = 0.10` is the same
numeric value as the deprecated `_roller_model()`'s own `beta_roller` default, carried forward even
though the balance FORM differs (coordinator ruling: X-D3's stated equation, `d(2·E_r·c)/dx`, wins
over `_roller_model()`'s own `dEr = (Dw-Dr)·dx/C` structure — a factor of 2 and a `c` multiply sit
on the tracked quantity, not the dissipation term, and `_roller_model()`'s own `D_r` carried an
extra leading factor of 2 that X-D3's `D_r = g·β_D·E_r/c` does not).

`E_r` drives whitewater/impact-zone extent (display/derived only — no new wire fields this round):
the impact/foam-zone boundary is the first point where `E_r` falls below
`_WHITEWATER_ER_FLOOR_FRACTION = 0.05` (`:114`) of its own local maximum within the zone, replacing
the previous `Hs <= 0.707 × Hs_break` criterion (`_classify_zones`, `surf_1d_analytical.py:1447-1558`,
and `_classify_zones_per_break`, `:1561-1691`, both gain an optional `er` parameter; `None` — any
caller not yet passing it — preserves the legacy 0.707×Hs criterion unchanged). Wired through
`endpoints/beach_profile.py` (`:731`, `tr.combined_roller_energy_profile` passed as `er=` to both
`_classify_zones` calls). `reform_trough`'s START point moves with this change (correction
2026-08-06, audit finding F3): `reform_trough` derives from `impact_end_idx`, which the E_r
criterion legitimately relocates relative to the legacy 0.707×Hs criterion (an ~80 m shift was
reproduced on a synthetic fixture) — an intended consequence of the approved extent change, not
a defect. The original claim here ("unaffected either way") was false and is corrected.

**Closure invariant — INVARIANT_11 (fire-only, `services/invariants.py:119`,
`"11:roller_closure_within_one_percent"`) — REDESIGNED 2026-08-06 (audit finding F2; marine
`20c2711`):** the original per-step self-check described in this ADR's first version was proven
tautological by the round's blind audit (it re-derived its answer from its own defining algebra;
a wrong β_D could never trip it). The shipped form is a PER-ZONE AGGREGATE two-method
cross-check (`_roller_zone_aggregate_closure_ratio`): within each breaking zone, the
production forward-Euler energy budget is compared against an independently-accumulated
semi-implicit trapezoidal budget (the same reference scheme the X-K3 KAT uses); residual
normalized by total dissipated energy; worst alarm-eligible zone must be `<= 0.01` (1%).
Scoping (decision-register 11(f)/(g)/(h) + participation floor, all measured-justified):
water's-edge floored steps excluded; the single regime-transition step at each zone's entry
AND exit excluded (both-endpoint discontinuity); stiffness-dominated steps excluded
(`k·ds >= 0.5` as phase speed dies); TWO-TIER alarm bar (re-audit hardening, marine `93096c1`):
zones with >= 25 checked steps alarm at 1%; shorter zones alarm at their own coarser 10% bar
(healthy short zones measured <= 1.5%, wrong-coefficient ~100% — an order of magnitude clear
each way; closes the re-audit's demonstrated short-zone hiding spot). The reference side also
declares its OWN copy of the fade coefficient (`_ROLLER_BETA_D_REFERENCE = 0.10`) so a careless
one-site edit to either constant trips the alarm; deliberate physics changes are a two-site
edit gated by register ruling 2 (closes the re-audit's shared-constant masking). Detection
power demonstrated before shipping: doubled β_D reads 11.8% vs 0.081% clean (~145×), and a
one-site-edit test pins the dual-constant behavior.
Known limitations recorded: near-terminal roller values are locally imprecise by construction
(stiff regime — harmless, E_r is draining to zero there); short bump-shaped zones (<25 steps)
are monitored but not alarm-eligible. Wired at both production sites (post-loop, per march).

**Floored-step scoping (decision-register item 11(f), a lead ruling under delegated authority):**
`D_r = g·β_D·E_r/c` diverges as the floored phase speed `c → 0` at the numerical depth floor
(`eps = 0.01`) — a numerical-floor artifact of the march's own guard rails, not march dishonesty. A
step is excluded from the closure-invariant accounting when *either* endpoint's depth or phase
speed is at or below its numerical floor: `depth_at_floor = d[i] <= eps or d[i-1] <= eps`,
`speed_at_floor = c[i] <= eps or c[i-1] <= eps` (`_ddd_breaking_march`, `:942-948`;
`apply_ddd_saturation`, `:1172-1178`, identical logic). **The 1% threshold itself is untouched by
this exclusion** — steps whose endpoints sit at the numerical depth/speed floor near the water's
edge are skipped (wording corrected 2026-08-06 per audit F4: this can be several consecutive
shoreward points, not literally one), so the alarm does not cry wolf every cycle on healthy runs.

**X-D4. The W1b cap is deleted; INVARIANT_12 replaces it.**

The `min(marched, hs_total[i])` clamp that used to sit at the end of `apply_ddd_saturation`'s
breaking branch is removed (marine `2bb1cd1`). **CORRECTION 2026-08-06 (audit finding F1; marine
`20c2711`):** this ADR's original claim — that with one-sided dissipation `marched > hs_total[i]`
is "mathematically impossible" — was DISPROVEN by the round's blind audit: once the state machine
enters BREAKING it stops reading the raw input, so a mid-breaking downward step in raw (e.g. a
structure-affected transect where an obstacle absorbs energy) left the marched value up to
~600 mm above raw. The shipped remedy: the BREAKING branch bounds the PUBLISHED value by the raw
input at each step (`marched = min(marched, hs_total[i])` post-relaxation, pre-publish) — the
design's own stated no-gain property enforced where the input itself drops, while the internal
relaxation trajectory and the roller's dissipation source remain uncapped (X-D3 contract
preserved). This differs from the deleted W1b cap in scope and role: the old cap silently
masked two-sided relaxation defects; the new bound never engages except when the input's own
energy ceiling falls below the decaying trajectory. Downstream consequence, stated plainly:
once the bound engages, subsequent steps' trajectory (and therefore roller dissipation) follows
the bounded height — intended physics (track the actual reduced wave); measured ~57% relative
E_r divergence at the shoreline vs a never-bounded counterfactual on the audit repro (the
original audit measured ~82% with a different normalization — reconciliation noted, both
figures say "substantial and intended"). **INVARIANT_12 is RETIRED** (re-audit finding F5,
register 11(i), marine `93096c1`): the enforced bound made the observer structurally unable to
fire — a decorative alarm. In its place, a WARNING-class log records each march where the bound
engaged (count + worst pre-bound excess) — expected on structure-crossing transects, never
gated to zero. This closes DQ-W3. `_ddd_breaking_march` (the per-partition march) has no raw-input reference to compare
against and does not carry INVARIANT_12 — only `apply_ddd_saturation` does, by construction (the
only function with both a raw and a marched value in hand).

**Explicit non-goal:** the SECOND, unrelated wave-height cap at
`surf_1d_pipeline.py:_combine_partition_faces_11_3` is NOT touched by this round (decision-register
item 8, D-5).

**15 cm reform floor** — see X-D1 above (`_REFORM_FLOOR_DEPTH_M`); listed again here because the
plan's own doc-delta table names it as a top-level Round X constant alongside the others.

## Consequences

- **Break-point semantics changed.** A break point is no longer a bare `H/d >= gamma` crossing; it
  is the local-maximum-dissipation point within a Q_b-defined breaking zone. Multi-bar profiles now
  get one distinct break point per bar by construction of the per-zone tracking, where the prior
  hard-trigger design under a saturation clamp could not distinguish a genuine reform from
  crossing-jitter (the exact gap Round Z's hysteresis retune had been working around).
- **Wire field names and payload shapes are unchanged.** Q_b and E_r ride on internal result
  objects only (`Analytical1DResult`, `TransectResult`, `PartitionBreakResult`) — no served-payload
  changes in this round (X-D5, D-6). See API-MANUAL.md §17-18's own delta for exactly which
  documented fields' *derivation* (not shape) changed.
- **Energy accounting is now answerable.** The closure invariant gives a concrete, checked answer
  to "does this model conserve energy" instead of an unmonitored assumption.
- **The cap's job is now proven, not enforced.** A regression that reintroduces energy gain in the
  DDD relaxation will now be caught by INVARIANT_12 firing in production logs/health, rather than
  silently absorbed by a clamp.
- **New named traps for future work** (carried in the plan's own dispatch packet, repeated here for
  the ADR record): the second, unrelated face-height cap at `surf_1d_pipeline.py`'s
  `_combine_partition_faces_11_3` remains untouched; the legacy `onset_indices=None` ratio-crossing
  branch of `_find_break_points` is unchanged (it has no live caller today — `run_1d_analytical`
  always passes the modeled `onset_indices`, `surf_1d_analytical.py:1966-1971` — but remains for any
  future caller with no modeled breaking state); `_MIN_BREAK_DEPTH_M`'s publication-filter role is
  unchanged and is a distinct symbol from `_REFORM_FLOOR_DEPTH_M` despite the identical 0.15 m value.
- **Deprecated functions remain deprecated.** `_battjes_janssen()` (`:402-488`) and `_roller_model()`
  (`:491-533`) are NOT the functions this round revives into production — `_ddd_breaking_march` /
  `apply_ddd_saturation` / `_roller_energy_step` are new/adapted call sites; the two deprecated
  functions still have zero call sites and are unchanged by this round.

## Acceptance criteria

Code-level (verified against marine repo commits `bce8997`/`9b6a669`/`2bb1cd1` by direct reading —
file:line citations above):

- [x] `Q_b` is solved from the exact implicit Battjes & Janssen relation, not a closed-form stand-in
      — `_solve_breaking_fraction()`, `surf_1d_analytical.py:309-399`.
- [x] Onset at `Q_b >= Q_B_VISIBLE (0.05)`, cessation at `Q_b < Q_B_CESSATION (0.02)` AND
      `H <= Γ·d`, re-onset forbidden below `_REFORM_FLOOR_DEPTH_M (0.15 m)` — `:864-926`
      (`_ddd_breaking_march`), `:1094-1157` (`apply_ddd_saturation`).
- [x] Dissipation step is `Q_b_eff`-weighted and one-sided (bracket floored at zero, identity step
      otherwise) — `:897-905`, `:1124-1132`.
- [x] Roller balance `d(2·E_r·c)/dx = D_br - D_r`, `D_r = g·β_D·E_r/c`, `β_D = 0.10` implemented and
      shared between both march functions — `_roller_energy_step()`, `:535-642`.
- [x] `E_r` drives whitewater/impact-zone extent (5% local-max floor) in
      `_classify_zones`/`_classify_zones_per_break`, wired through `beach_profile.py` —
      `surf_1d_analytical.py:1486-1496`, `:1612-1627`; `endpoints/beach_profile.py:731,751,762`.
- [x] `min(marched, hs_total)` cap is deleted from `apply_ddd_saturation` — confirmed absent by
      reading the function body, `:967-1221`; `git show 2bb1cd1` diff confirms the deletion.
- [x] INVARIANT_11 (roller closure, 1%, floored-step exclusion per register 11(f)) and INVARIANT_12
      (no-gain, marched ≤ raw + 1mm) registered and checked at their production call sites —
      `services/invariants.py:119,131`; call sites `surf_1d_analytical.py:955-962,1180-1195`.
- [x] X-K2 fixture ground truth (transect 55, bar depth-minimum 1.545 m at 79.74 m) matches the
      spot profile data referenced by the state machine's inputs — fixture identity confirmed live
      by X0 (`scratch/X0-FACT-PIN-2026-08-05.md`); the worked Hs=0.55m/1.1m rows above are the
      plan's own X-D2 worked-consequence text, reproduced verbatim in this ADR — **not independently
      re-run by this docs task**; X5's KAT and X7's gate are the numeric verification of record.

Reality-gate (X7, pre-stated in the plan, **NOT YET RUN as of this document**):

- [ ] Row 1 — webcam vs. published break agreement on the first ≥3 ft / ≥12 s groundswell day.
- [ ] Row 2 — zero firings of INVARIANT_11 across 4 consecutive cycles (INVARIANT_12 retired
  per register 11(i); F1 bound-engagement WARNING counts reported without a pass/fail bar).
- [ ] Row 3 — publish-liveness + journal sweep.

Checked at: this document's own drafting (2026-08-06), against marine repo HEAD (`2bb1cd1` and
descendants, meta repo commit at drafting time noted in the doc-sync closeout), by direct code
reading — not test output. The X7 gate (Lead) is the authoritative acceptance record for the
reality-gate rows; this ADR's code-level rows are what X6 (docs) could verify from source alone.

## Implementation guidance

- **Any future change to the breaking-fraction constants (γ, K, Γ, Q_B_VISIBLE, Q_B_CESSATION,
  β_D, the 0.15 m reform floor, the 0.05 whitewater floor fraction) requires before/after evidence
  at a gate** (decision-register item 2 — "these ship at exactly these values... never a casual
  edit"), not a routine tuning commit.
- **Do not reintroduce a hard clamp in place of INVARIANT_12.** The no-gain property is proven by
  X-D2's one-sided dissipation; a future change that needs a clamp again is signaling that the
  one-sidedness itself has broken, which is an architectural regression back toward the pre-Round-X
  design, not a routine fix.
- **The floored-step exclusion (register 11(f)) is scoped to the numerical floor only** — do not
  widen it to exclude more of the profile without a new register entry; doing so would mask
  genuine closure failures the invariant exists to catch.
- **`_battjes_janssen()` and `_roller_model()` remain dead code** (zero call sites) — this round did
  not reactivate them; do not treat their presence as evidence they are live.

## References

- Battjes, J.A. & Janssen, J.P.F.M. (1978), "Energy loss and set-up due to breaking of random
  waves," *Proc. 16th ICCE*, ASCE.
- Dally, W.R., Dean, R.G. & Dalrymple, R.A. (1985), "A Model for Breaker Decay on Beaches,"
  *Proc. 19th ICCE* / *JGR* (the pre-existing DDD relaxation this round re-weights, unchanged K/Γ).
- Svendsen, I.A. (1984), "Wave heights and set-up in a surf zone," *Coastal Engineering* 8
  (roller-model family `_ROLLER_BETA_D` is drawn from, per the deprecated `_roller_model()`'s own
  provenance comment).
- SWAN technical documentation eq. (2.65)/(2.66) — verification reference for the B-J `Dtot`/`Qb`
  forms, cited in `_solve_breaking_fraction()`'s and `_battjes_janssen()`'s own docstrings.
- Plan: `docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md`, ROUND X (X-DESIGN X-D1..X-D5,
  X tasks, X reality gate), decision-register items 2, 3, 8, 11(f).
- Dispatch packet: `docs/planning/briefs/X-DISPATCH-PACKET-2026-08-06.md`.
- Marine repo commits: `bce8997` (X-D1/X-D2), `9b6a669` (X-D3), `2bb1cd1` (X-D4).
- `docs/ARCHITECTURE.md` — marine breaking-model paragraph (this ADR's doc-delta counterpart).
- `docs/manuals/API-MANUAL.md` §17-18 — break-point/zone-extent field semantics (this ADR's other
  doc-delta counterpart).
