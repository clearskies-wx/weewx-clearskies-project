# SW-1b — Score-card / current-conditions swell-selection regression (read-only investigation)

**Task:** SW-1b (SURF-PHYSICS-REMODEL-PLAN-2026-08-05, operator order 2026-08-06 + follow-up).
**Investigator:** read-only Sonnet agent. **Scope:** read-only everywhere, no fixes proposed beyond
naming the defect / regression / missing guard.

## Bottom line

The score-card text and the "Current Swell Conditions" period/direction do **not** read from
`multiSwell` (the ranked spectral partitions) at all. They read `SurfForecast.period` /
`.direction`, which are a straight pass-through of the **bulk TM01 mean period and mean direction
(MWD) of the total local spectrum** at a nearshore 1D-transect reference point — a completely
different physical quantity from "the dominant swell partition." TM01 (`m0/m1`) is pulled toward
whichever frequency band holds the spectral energy, so a locally-generated wind sea mixed into the
local spectrum drags the bulk mean period down even when a taller/more energetic groundswell
partition exists in the same spectrum. This is architecturally why the headline "touts the wind
swell" — it was never selecting a partition at all, correct or not.

A genuine dominant-partition selector for this exact purpose (`_effective_swell()`) existed and was
unit-tested from Phase 3 (commit `5be33fc`, 2026-07-16/17-ish) through **2026-07-18**, when it was
severed from its data feed (`ea47ed6`, same day) and then deleted outright forty minutes later
(`66c9634`, "Remove `_effective_swell()` NDBC override") — **three weeks before** the Round S
surf-scorer rebuild the task brief flagged as prime suspect. Round S (`2ef8191`..`bdf4db8`,
2026-08-05) is not the regression; it inherited the already-broken pass-through, and — per the
locked S-SPEC-1 design — deliberately restored a dominant-partition rule for the **Power scoring
factor only** ("D1"), never for the display text/current-conditions fields. The regression is real,
it predates Round S by ~2.5 weeks, and it has never been touched since.

---

## Q1 — Score-card text-forecast path (file:line hops)

| # | Hop | File:line | What happens |
|---|-----|-----------|--------------|
| 1 | Dashboard render | `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx:2059` | `{primary.conditionsText}` — Card 2 ("Surf Score" hero), rendered verbatim, no client-side logic |
| 2 | Dashboard `primary` selection | `SurfingTab.tsx:1875-1881` | `primary` = the `forecast[]` entry whose `time` is closest to `Date.now()` (not `forecast[0]`) |
| 3 | API field origin | `repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_enrichment.py:570-582` (`_enrich_surf_entry`) calling `_compose_surf_conditions_text()` at `:462-504` | Pure i18n template fill from `conditionsTextParts.{heightM, periodS, compass, swellSummaryKey}` + wind fields — **no partition logic here**, `periodS`/`heightM` used exactly as received from marine |
| 4 | Marine field build | `repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/surf_scorer.py:981-988` (`score_surf()`) | `conditions_text_parts = SurfConditionsTextParts(heightM=wave_height, periodS=wave_period, directionDeg=wave_direction, compass=_nearest_compass(wave_direction), ...)` — `wave_period`/`wave_direction` are **function parameters**, not derived from `multi_swell` inside this function |
| 5 | Marine call site | `repos/weewx-clearskies-marine/weewx_clearskies_marine/endpoints/surf.py:1322-1325` | `score_surf(wave_height=_swelltrack_face_m, wave_period=wave_period_pt, wave_direction=wave_direction_pt, ...)` |
| 6 | Source of `wave_period_pt`/`wave_direction_pt` | `surf.py:1115-1122` | `ref_point, _ = _select_reference_point(pts_at_time)` (imported from `services/surf_pipeline_timestep.py:124`); `wave_period_pt = float(ref_point.get("wavePeriod") or 0.0)`, `wave_direction_pt = float(ref_point.get("waveDirection") or 0.0)` |
| 7 | What `ref_point["wavePeriod"]` actually is | `services/swan_runner.py:2097` (and `:1903`, `:1173`) | `wavePeriod=round(tm01, 1)` — **SWAN TM01, the mean period (m0/m1) of the total local spectrum** at that 1D-transect point (nearshore, after refraction/shoaling), computed from the SWAN TABLE output. `waveDirection` is the paired mean wave direction (MWD), same row. |

**SELECTION RULE AS IMPLEMENTED:** none, with respect to partitions. `wave_period_pt`/`wave_direction_pt`
are a **bulk spectral moment** (TM01/MWD) at whichever transect point `_select_reference_point()`
picks (biggest-break-zone point, or nearest-10 m-depth point if no breaking) — a completely
different data source from `multiSwell`. It is not `partitions[0]`, not max-Hs, not max-energy —
it never looks at `multiSwell` at all. `score_surf()`'s own docstring at
`enrichment/surf_scorer.py:864-870` discloses this directly: *"wave_period: seconds; dominant period
(display/text only — Power's own period sub-input comes from the dominant multiSwell partition, not
this parameter, per D1)."*

## Q2 — Current Swell Conditions card path (file:line hops)

Card 3, "Current Swell Conditions," `SurfingTab.tsx:2092-2250`:

| Field on card | Source | File:line | Correct? |
|---|---|---|---|
| Period stat tile | `primary.period` | `SurfingTab.tsx:2120` → same `SurfForecast.period` as Q1 hop 4/5/6/7 above | **No** — same TM01 bulk-mean defect |
| Swell Height stat tile | `primary.swellHeight ?? primary.waveHeightAtBreak` | `SurfingTab.tsx:2118`; server side `entry["swellHeight"] = _dominant_hs_m` at `surf.py:1395` = `max(c["height"] for c in ts_spectral)` (max-Hs across `multiSwell`) | **Yes** — genuinely tracks the dominant `multiSwell` partition by height |
| "Dominant Direction" compass | `dominantDirection` = `dominantSwellDirection(swellComponents)` | `SurfingTab.tsx:1899` calling the helper at `:724-727`: `components.reduce((best,c)=> c.energy>best.energy?c:best).direction` (max-**energy** partition) | **Yes** — tracks dominant `multiSwell` partition, but note: by **energy**, not by height, a different tie-break rule than the height stat next to it uses (`_dominant_hs_m`, max-Hs) and than Power's own `_dominant_partition()` in `surf_scorer.py:697` (also max-Hs). Three different "dominant" conventions across the codebase; only the Period field ignores `multiSwell` altogether. |
| Swell component table (below) | `SwellBreakdown` component, `swellComponents` = `swellSourceEntry.multiSwell` | `SurfingTab.tsx:536-602`, sourced at `:1887-1897` | **Yes** — correctly ranked by energy, all partitions shown |

**Net effect on Card 3:** the Swell Height tile and the compass correctly reflect the dominant
`multiSwell` partition (by two slightly different rules); the Period tile sitting directly next to
Swell Height reflects an unrelated bulk quantity that need not correspond to either partition — an
internal inconsistency on the same card, and the direct cause of "4 seconds" appearing next to a
otherwise-correct-looking swell height number.

---

## Q3 — The prior fix (found)

**Commit:** `5be33fc` "feat(enrichment): add surf quality scoring processor (Phase 3, T3.3)" (API
repo, `weewx-clearskies-api`) — introduced `_effective_swell()`, live and tested through
`66c9634^`.

**Rule as implemented (`enrichment/surf_scorer.py`, pre-`66c9634`):**

```
def _effective_swell(wave_height, wave_period, wave_direction, spectral_components):
    """
      - primary swell (max-energy of spectral_components) > 75% of total energy
          -> use primary partition's own (height, period, direction) alone.
      - else secondary > 50% of primary's energy
          -> energy-weighted superposition: H = sqrt(H1^2+H2^2),
             T and D = energy-weighted means of the two partitions.
      - else (or < 2 components / no spectral data)
          -> fall back to caller-supplied (wave_height, wave_period, wave_direction)
             i.e. the bulk reference-point values.
    """
```

Its output (`eff_height, eff_period, eff_direction`) fed **everything downstream that matters
here**: `period_score = _score_wave_period(eff_period)`, `beach_alignment =
_beach_alignment(eff_direction, ...)`, `conditions_text = _compose_conditions_text(period_s=eff_period,
direction_deg=eff_direction, ...)`, and the top-level `SurfForecast(period=eff_period,
direction=eff_direction, ...)`. This is exactly the field chain traced in Q1/Q2 today. It was pinned
by two unit tests added in the same commit: `test_multi_swell_primary_dominant()` and
`test_multi_swell_superposition()`.

This is "the fix, corrected once" the operator remembers: when a real dominant (or superposable)
multi-swell system existed, the text and the current-conditions period/direction genuinely reflected
it, not the bulk mean.

## Q4 — The regression (found, two commits, both 2026-07-18, both predate Round S by ~2.5 weeks)

**Step 1 — `ea47ed6`** "feat(swan): T3.1–T3.5 cross-shore transect, spectral output, and
SPECOUT-driven multiSwell" (2026-07-18 00:37): introduces SWAN-SPECOUT-driven `multiSwell` as a
**separate, new** display field (`entry["multiSwell"] = [...]`), but the same commit explicitly
disconnects `_effective_swell()`'s only input: `score_surf(..., spectral_components=None, # T3.5:
NDBC spectral disconnected from scoring)`. `_effective_swell()` is never rewired to receive the new
SWAN `multiSwell`/`ts_spectral` data — it is simply starved, at the exact moment a working spectral
partition source became available.

**Step 2 — `66c9634`** "feat: Phase 4 — scoring restructure (3-factor + Organization composite)"
(2026-07-18 01:07, 40 minutes later): deletes `_effective_swell()` outright as dead code, commit
message: *"Remove `_effective_swell()` NDBC override."* Diff excerpt:

```diff
-    eff_height, eff_period, eff_direction = _effective_swell(
-        wave_height, wave_period, wave_direction, spectral_components
-    )
-
-    height_score = _score_wave_height(eff_height)
-    period_score = _score_wave_period(eff_period)
+    height_score = _score_wave_height(wave_height)
+    period_score = _score_wave_period(wave_period)
...
-    beach_alignment = _beach_alignment(eff_direction, spot_config.beach_facing_degrees)
+    beach_alignment = _beach_alignment(wave_direction, spot_config.beach_facing_degrees)
...
     conditions_text = _compose_conditions_text(
         height_ft=height_ft,
-        period_s=eff_period,
-        direction_deg=eff_direction,
+        period_s=wave_period,
+        direction_deg=wave_direction,
...
     return SurfForecast(
-        period=eff_period,
-        direction=eff_direction,
+        period=wave_period,
+        direction=wave_direction,
```

Same commit deletes the pinning tests (`test_multi_swell_primary_dominant`,
`test_multi_swell_superposition`), replacing them with tests for the new Organization sub-factors
(directional spread, cross-swell) that do **not** re-assert dominant-partition period/direction
selection anywhere.

**Net result from `66c9634` onward:** `wave_period`/`wave_direction` (the raw bulk reference-point
values, hop 6/7 in Q1) flow straight through to scoring, text, and the top-level fields, unconditionally.

**Round S is not the regression.** `76e8d9e` (marine repo, 2026-08-05, "wire the 5-component scorer
into the surf endpoint call site") is a pure reorder of the same `score_surf(wave_period=wave_period_pt,
wave_direction=wave_direction_pt, ...)` call — verified byte-identical to its pre-Round-S form via
`git show 76e8d9e`. `83f0205` (marine repo, 2026-07-26, "publish multiSwell from the deep-water
reference, not the SwellTrack handoff") also does not touch this path — it fixed *which* extraction
feeds `multiSwell`/`swellHeight`/`canonical_partitions`, not the `period`/`direction` fields, which
never read `multiSwell` in the first place. Round S's own S1c rework (`ae30eb1`) explicitly scoped a
dominant-partition rule ("D1") to the **Power** scoring factor only
(`enrichment/surf_scorer.py:56-66`, `:864-870`) and left the text/current-conditions fields on the
pre-existing (broken since `66c9634`) pass-through — Round S is a **missed opportunity to re-fix**,
not the fix's destroyer.

### Missing guard

No test in the current suite (`repos/weewx-clearskies-marine/tests/`) pins `SurfForecast.period`,
`SurfForecast.direction`, or `conditionsTextParts.periodS`/`directionDeg` against a known
multi-partition `multiSwell` fixture. `tests/test_swell_dominance_ratio.py` only pins
`conditionsTextParts.swellSummaryKey` (a coarse "clean/mixed/chop" label), never the numeric
period/direction that actually land in the visible text. `tests/test_surf_score_s1_geometric_mean_kat.py`
etc. pin the Power **factor score**, not the raw period value flowing into text/current-conditions.
The class of test that would have caught both the original 2026-07-18 regression and its 19-day
survival is a **known-answer integration test**: given a two-partition fixture (e.g. groundswell
0.48 m @ 13.4 s + wind_swell 0.22 m @ 5.8 s, groundswell dominant by height/energy) and a bulk
reference-point TM01/MWD deliberately set to a different value, assert `score_surf()`'s returned
`period`/`direction`/`conditionsTextParts.periodS`/`.directionDeg` equal the **dominant partition's**
period/direction, not the bulk value. No such test exists today, at any point since `66c9634` deleted
`test_multi_swell_primary_dominant()`.

---

## Live payload evidence (read-only, dev site, 2026-08-06 ~04:00Z)

`curl -sk https://weather-test.shaneburkhardt.com/api/v1/surf/huntington-city-beach-pier`, entry
nearest to now (`time: 2026-08-06T04:00:00Z`, station clock ≈ 2026-08-05T20:58 PT):

```
period: 3.6            direction: 247.5
conditionsText: "2-4 ft at 4 seconds from the W. Cross-onshore winds 7-12 kt. Wind chop dominates."
swellHeight: 1.8347158462475304   (= max-Hs multiSwell partition height, matches wind_swell below)

multiSwell:
  { height: 1.8347, period: 3.7887,  direction: 271.854, energy: 0.019545, classification: "wind_swell" }
  { height: 1.1479, period: 13.0578, direction: 200.565, energy: 0.007651, classification: "groundswell" }
```

Two things this confirms directly:

1. **`period`/`direction` (3.6 / 247.5) are not equal to either `multiSwell` partition's own
   period/direction** (3.79/271.9 for wind_swell, 13.06/200.6 for groundswell) — proving they are a
   separately-computed bulk quantity (TM01/MWD), not a literal partition read, exactly as the code
   trace shows.
2. **At this specific live hour, `multiSwell` itself ranks `wind_swell` above `groundswell`** by both
   height (1.83 m vs 1.15 m) and energy (0.0195 vs 0.0077) — i.e. even the correctly-multiSwell-sourced
   fields (`swellHeight`, the compass) would currently point at the wind swell too. This does not
   contradict the defect finding — the `period`/`direction` fields still ignore `multiSwell` entirely
   regardless of which partition wins — but it does mean this particular live snapshot cannot be used
   as a clean "groundswell should have won and didn't" demonstration; that comparison needs an hour
   where our own `multiSwell` ranks groundswell above wind_swell (per the task brief's cited
   2026-08-05T22:00Z YQ-1 measurement: groundswell 0.48 m @ 13.4 s vs wind_swell 0.22 m @ 5.8 s,
   groundswell clearly dominant by both height and energy there). SW-1a's separate finding — that our
   wind-sea partition height/energy may itself be inflated relative to what NDBC/Surfline resolve — is
   a candidate compounding factor and is explicitly out of SW-1b's scope.

---

## Adjacent, not duplicated

**S-5** (EYEBALL-FIX-PLAN, ruled 2026-08-05 option (b), not yet implemented, scheduled in Round X's
window per plan status table) is a **different** defect: it governs which direction reference feeds
the Size component's beach-alignment/exposure *scoring multiplier* (`_beach_alignment()`/
`_directional_filter()` in `surf_scorer.py`, non-displayed), currently the same top-level
`wave_direction` reference discussed here. S-5's fix (switching that scoring input to the dominant
partition direction) and SW-1b's fix (switching the **displayed** `period`/`direction`/
`conditionsText` to a dominant-partition rule) touch the same root data (`wave_direction`/
`wave_period` vs `multiSwell`) but different consumers and are not the same code change — per the
plan's own instruction, not duplicating S-5 here, only flagging the shared root.
