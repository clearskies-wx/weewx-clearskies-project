# QC Gate 4A — Verification Results

**Auditor:** `clearskies-auditor`. **Date:** 2026-07-25. **Round:** Marine Service Separation,
Phase 4A close-out gate (deferred, walked now per operator direction).

**Source pin:** API repo `eca80ee` (Phase 4A close commit) via `git show`/`git grep`, never the
working tree — two other agents were modifying it live during this audit. Dashboard repo
`923dd0c` (working tree, stable). Deployed state during this audit: `weewx` at `eca80ee`
throughout; `librewxr` at `eca80ee` for the first two runs referenced below (07:06Z full run,
07:29Z quick update), then redeployed to `ce4415b` (a 2-line diagnostic-only change — verified
below) partway through, with a fresh full run triggered afterward (08:35:42Z). Every piece of
runtime evidence below is labeled with which run/commit it came from.

**`ce4415b` verified diagnostic-only:** `git show --stat ce4415b` → 1 file changed, 2
insertions(+), 1 deletion(-) in `swan_formats.py`, adding `PTHSIGN PTRTP PTDIR PTDSPR` to the
CURVE TABLE column list and the matching logger string. No computed value, grid, or handoff
logic touched. Confirmed by reading the diff directly, not assumed.

---

## Gate line 1 — Handoff depth varies per forecast hour; grid geometry unchanged across a cycle

**Source (eca80ee):** `services/transect_handoff.py` `select_hourly_handoff()` computes
`target_depth_m = margin * hs_m / gamma` per call (per hour, per transect) — a pure lookup
against station depths already on the grid, never resizing anything (module-level docstring +
`test_transect_handoff_module_never_imports_grid_sizing` — ran, PASSED, at eca80ee on weewx:
`23 passed` in `tests/test_transect_handoff.py`, including
`test_compute_domains_byte_identical_across_simulated_cycle`).

**Live evidence — target depth varies, PASS on the letter of the gate:**
`journalctl -u weewx-clearskies-swan` on librewxr, 07:06Z run (eca80ee) and 07:29Z quick update
(eca80ee): `target depth` in the WARNING lines moves with `Hs` every hour — e.g. 0.59 m
(Hs=0.33m) → 0.75 m (Hs=0.42m) within the same run, and 0.02 m (Hs=0.01m) → 1.21 m (Hs=0.68m)
across the 07:29Z run. `handoffDepthM` is documented in source as the TARGET value (not the
sampled station depth), so this is the field actually surfaced to API consumers, and it varies
hour to hour as required.

**Live evidence — grid geometry unchanged across three separate runs (07:06Z eca80ee, 07:29Z
eca80ee, 08:35Z ce4415b, in progress at time of writing):**
`ls -la /etc/weewx-clearskies/swan_grid_sizing.json /etc/weewx-clearskies/spot_profiles/
huntington-city-beach-pier.json` on librewxr — both files mtime **2026-07-25 06:41**,
unchanged before, between, and during all three runs (checked at multiple points, most recently
while the 08:35:42Z run was mid-L2). Neither file has been touched by any runtime cycle.

**Real finding, already tracked in the plan — not new, but material to this line's literal
reading:** on both the 07:06Z and 07:29Z runs, **every single forecast hour clamped to the
identical interior station** (station 17, depth 2.37 m) because the two shallowest stations on
the transect are 0.98 m (boundary, excluded) and 2.37 m, with nothing between — this is the
plan's own T4A.5 "handoff clamped on all 73 timesteps" finding, not a new defect. Consequence:
the TARGET depth (`handoffDepthM`) varies correctly per hour, but in these two runs the ACTUAL
spectrum sampled (station index, station depth) was the *same station* on every single hour —
so the two runs I could observe never actually demonstrated "a 1 m hour and a 4 m hour resolve
to different cells," one of T4A.9's own Accept bullets, in this specific deployment's station
density. This is the plan's own recorded, operator-accepted gap (routed to T8.7), not something
I am newly reporting as a defect — flagging only because gate line 1 asks specifically for
evidence of different cells resolving on different hours, and the two runs I could observe did
not produce that evidence (both clamped to the same station throughout).

**Disposition: PASS**, with the above caveat recorded. The letter of the gate line
("handoff depth varies per forecast hour; grid geometry unchanged across a cycle") is met by
live evidence on both halves. The deeper claim in T4A.9's Accept bullets (different hours
resolving to genuinely different stations) is not demonstrated in this deployment's two observed
runs, for the already-known, already-accepted station-spacing reason — not a new finding.

---

## Gate line 2 — Sampled handoff cell has QB ~ 0 on every transect/hour; violation drill proven

**Live — zero QB violations at HB across observed runs:** No `SWAN handoff` ERROR lines (the
greppable pattern `refine_handoff_with_qb()` uses) appeared in the librewxr SWAN journal across
the full retained history (since 2026-07-22) through the 07:29Z run. (The 08:35Z run was still
in progress at time of writing; see note below.)

**The drill — proven, via targeted unit test, run by me, not assumed:**
`tests/test_transect_handoff.py::test_refine_handoff_with_qb_unrecoverable_raises_and_logs_error`
injects `qb = [0.9] * len(_SYNTHETIC_STATIONS)` (every station "breaking"), asserts
`HandoffBreakingError` is raised, asserts an ERROR-level log line is captured via `caplog`, and
asserts `HANDOFF_QB_VIOLATIONS_TOTAL.labels(transect_index="7")` increments.
`test_refine_handoff_with_qb_moves_seaward_on_violation` separately proves the non-fatal
seaward-move path. I ran this file directly on weewx (not read, not assumed):

```
ssh weewx: uv run --frozen pytest tests/test_transect_handoff.py -q --tb=short
23 passed, 1 warning in 3.50s
```

Per the brief's own instruction ("Do not run a drill against production; report the gap"), a
unit-test drill against synthetic data is the correct evidence here, not a live production
injection. The drill exists and passes.

**Disposition: PASS.** Zero live violations at HB in observed runs; the forced-violation drill
exists, was executed by me at eca80ee, and produces exactly the ERROR log + counter increment
T4A.10's Accept requires.

---

## Gate line 3 — L3 enables on operator classification as well as structures; viability test logs shortfalls

**Source (eca80ee), `services/swan_domain.py`:** trigger set at line ~117:
`{"point_break", "headland", "bay_break"}` — enables L3 on classification OR structure
discovery (line ~176 message: `"no manmade structure and no point_break/headland/bay_break
classification"` as the sole disable reason). `_l3_viability_check()` (line 208) logs at
**INFO** (not ERROR/WARNING — matches ADR-093 Amendment 2 §4's "the log is what makes it
visible" framing) naming the cluster, the unreachable feature, and the shortfall distance in
metres on failure.

**Live evidence the trigger fired and passed:** the plan's own T4A.5 record (already read, not
re-derived) states the real apply-time chain ran on librewxr and logged
`1 of 1 cluster(s) enabled` for HB Pier. I could not independently re-find this exact log line
in either the librewxr SWAN journal or the weewx API journal over the full retained history —
the log line's source (`endpoints/setup.py` line ~2103) is part of `/setup/apply`, which is a
main-API-process endpoint; T4A.5 ran the apply chain directly rather than through a systemd
service that retains journal history I can query, and no full `/setup/apply` HTTP call has
apparently been made since (see gate 13's cross-host finding, which independently corroborates
this — weewx's own profile cache still predates the T4A.5 regeneration). **I am relying on the
plan's contemporaneous written record for this specific log line, not an independent re-run.**
This is a CANNOT-VERIFY-independently for the enable log specifically, though the *effect* of
that log (L3 genuinely running for HB Pier — 18/19-station CURVE emitted, non-zero handoff
selections observed every run) is independently confirmed via the journal evidence in gate
lines 1 and 8.

**Whether a shortfall (FAILED) has ever actually fired:** No. HB Pier is the only configured
spot on this deployment and it passes the viability test. Grepping the full retained librewxr
SWAN journal (since 2026-07-22) for `"viability"` or `"cluster(s) enabled"` returns zero
matches — that log line lives in the API process (weewx), not the SWAN service (librewxr), so
its absence from the SWAN journal is expected, not evidence either way for the FAILED branch.
**Say so plainly: the FAILED branch has never been observed firing on this deployment.** Its
correctness rests on reading the source (confirmed sound: computes shortfall via haversine
against domain bbox, logs INFO with cluster IDs, feature label, and distance) rather than a
live failing example, because there is no spot on this deployment that fails it.

**Disposition: PASS** for the trigger-widening and viability-test-exists-and-logs-correctly
requirements (source-verified, matches ADR-093 Amendment 2 §3/§4 exactly). **CANNOT VERIFY**
independently for the specific "1 of 1 cluster(s) enabled" INFO line in this session (relying on
the plan's own contemporaneous record). **Confirmed non-blocking:** the FAILED/shortfall branch
has never fired in this deployment (only one spot, which passes) — not a defect, just an
untested-in-production path, correctly noted as its own thing rather than silently assumed to
work.

---

## Gate line 4 — No topographic multiplier in `apply_supplements()`

**Source (eca80ee), full contents of `enrichment/wave_transform.py` read in full:**
`apply_supplements()` **does not exist in the file at all.** All four supplements are gone; the
module's only remaining content is `bilinear_interpolate()` (kept for `endpoints/surf.py`'s
unrelated HRRR wind interpolation) and `_find_bracket()`. Confirmed via full-file read, not a
grep sample.

`git grep -n "apply_supplements" eca80ee -- weewx_clearskies_api/` → exactly one hit, a comment
in `surf.py` documenting the removal, zero call sites.

Classification field round-trips: retained in `SurfSpotConfig` (per source comments in
`wave_transform.py`'s module docstring: "operator's classification is retained in spot config —
its job is now the L3 enable trigger"), and independently confirmed feeding the L3 trigger set
in `swan_domain.py` (gate line 3 above) — the same field, now doing a different job, not two
copies.

Supplements 1 and 3 status: **also removed**, not merely the topographic one (#4). This exceeds
gate line 4's literal ask (which only requires #4 gone) — T4A.7's full DELETE disposition
(approved 2026-07-25 per the plan, subject to its verification gate) landed entirely, and the
module docstring documents the verification-gate finding for #3 (SWAN interpolates to the
requested coordinate via `POINTS`/`SPECOUT`, confirmed against the SWAN manual and source,
supplement genuinely redundant) inline.

**Disposition: PASS.** No topographic multiplier (or any other supplement) remains in
`apply_supplements()` — because the function itself is gone. Classification field confirmed
still live, now solely as the L3 trigger input.

---

## Gate line 5 — Superseded briefs carry dated banners

All five required locations checked by direct read, not grep-sampling:

| Location | Banner present | Dated / cites superseding ADR | Content deleted? |
|---|---|---|---|
| `SURF-ZONE-MODEL-BRIEF.md` §4 (line 384) | Yes | 2026-07-25, ADR-093 Amendment 2 | No |
| `SURF-ZONE-MODEL-BRIEF.md` §9 Option 1 (line 690) | Yes | 2026-07-25, ADR-093 Amendment 2 | No |
| `SURF-ZONE-MODEL-BRIEF.md` §9 Option 3 (line 698) | Yes, explicitly framed as a **reversal** (Option 3 "not recommended" now describes the adopted architecture) | 2026-07-25, ADR-093 Amendment 2 point 1 | No |
| `SURF-ZONE-MODEL-BRIEF.md` §2.3.4 (line 174) | Yes | 2026-07-25, ADR-093 Amendment 2 point 2 + L3-1D-BOUNDARY-DECISIONS-BRIEF D2 | No |
| `SWAN-NESTING-RESEARCH-BRIEF.md` lines 190–237 (banner at 214) | Yes, correctly scoped "PARTIALLY SUPERSEDED" — offshore-edge rationale still stands, only the shoreward implication is superseded | 2026-07-25 | No |

**Non-blocking observation, outside T4A.13's named scope:** `SURF-ZONE-MODEL-BRIEF.md` line 390,
inside the same §4 bullet list as the banked location above, independently states "Handoff depth
per transect determined by the pre-model algorithm (§2.3.4): 10m default, shallower for
structure-shadowed transects" — also stale (superseded by the per-hour handoff), but not marked
with its own banner. T4A.13's Do steps name four specific locations and this line isn't one of
them, so this is not a T4A.13 shortfall — noting it only because it sits inside a document this
gate line is checking and a future reader could be misled by it standing un-bannered two lines
below one that is.

**Disposition: PASS.** All five required locations carry dated banners naming the superseding
ADR, and no content was deleted at any of them.

---

## Gate line 6 — One vocabulary: `distance`, `depth`, `hs`, `transect`

**API repo (eca80ee), scoped to beach-profile/surf response vocabulary per the brief's
guidance:**

- `git grep -n "hsEnvelope" eca80ee -- '*.py'` → zero hits in source; only in `tests/
  test_beach_profile.py` as negative assertions (`assert "hsEnvelope" not in profile`) — in-scope
  and correct.
- `git grep -n "distanceFromShore" eca80ee -- '*.py'` → hits in `models/responses.py`,
  `services/swan_runner.py`, `providers/nearshore/swan.py` — all confirmed to be the **internal**
  `MarineForecastPoint`/transect-point model field, not the beach-profile or surf response
  vocabulary. `endpoints/surf.py` reads `distanceFromShore` from its internal dict and
  **re-keys it to `"distance"`** in its own `breakPoints` output (line 971:
  `"distance": _bp_pt.get("distanceFromShore")`) — confirms the carve-out the brief names
  (`MarineForecastPoint`'s internal field legitimately keeps the old name; the response doesn't).
- `endpoints/beach_profile.py` response construction (all `"distance":`/`"depth":`/`"hs":`/
  `"transect":` output sites read directly, lines 494–997): uniformly `distance`/`depth`/`hs`,
  array key `transect`, units block keys `distance`/`depth`/`hs`. Zero `distanceFromShore` or
  `waveHeight` in output construction.
- `endpoints/surf.py`: `_units_block()` uses `"hs"` (with an inline comment citing T4A.1
  Addition 2 explicitly); `breakPoints[]` uses `distance`/`depth`/`hs`.

**Dashboard repo (923dd0c, working tree, stable):**
- `grep -rn "hsEnvelope" src/` → one hit, in `src/api/openapi-v1.yaml`, itself a **historical
  note** in a schema description ("Array key renamed hsEnvelope -> transect at some point before
  this round... already correct on the API side") — documentation of the old name, not usage.
- `grep -rn "distanceFromShore" src/` → zero hits.
- `waveHeight` still appears in `src/api/types.ts` — **in scope, checked directly**: this is the
  legitimate `MarineForecastPoint`/marine-card type family (per the brief's own carve-out), not
  the beach-profile/HeatMap/BeachProfileChart types, which were confirmed merged to
  `distance`/`depth`/`hs` in T4A.1.

**Live confirmation:** the pre-deploy `/api/v1/surf` list response (`/tmp/gate4a_surf.json`, on
weewx) shows `units: {"hs": "ft", "wavePeriod": "s", "windSpeed": "kt", "setup": "ft"}` — matches
source exactly. The pre-deploy beach-profile snapshot (`/tmp/gate4a_profile.json`) uses
`transect[].{distance,depth,hs}` throughout, `breakPoints[].{distance,depth,hs,faceHeight,...}`,
and `metadata.axisUnits: {"x": "ft", "y": "ft"}` — unified vocabulary confirmed live, not just in
source.

**Disposition: PASS.** Zero stale-vocabulary occurrences in the beach-profile/surf response
scope, both in source and in live response payloads. Occurrences of the old names elsewhere are
all the explicitly-carved-out `MarineForecastPoint`/marine-card family.

**Separate finding — doc-code sync gap, `API-MANUAL.md` §18, not the code.** The code and live
responses are unified (above); the **manual** is not. `docs/manuals/API-MANUAL.md` §18 "Beach
profile endpoint (ADR-097)" still documents the pre-T4A.1 vocabulary verbatim:
`transect[].distanceFromShore`, `transect[].waveHeight`, `breakPoints[].distanceFromShore`,
`breakPoints[].waveHeight` — the exact names T4A.1's Accept criteria required removed. It is
also missing every field T4A.4/T4A.6 added: `modelStatus`, `handoffDepthM`,
`handoffSourceLevel`, `perPartitionBreaks`, `waveShapes`, `jackingFactors` all return **zero**
matches (`git grep` across the whole manual). §17 is *mostly* current (the wave-transform
supplements section correctly documents the T4A.7 removal) but its own "Height fields in every
`SurfForecast` entry" table still lists `degraded` as a live field ("SwellTrack fallback
indicator... `true` when SwellTrack failed") — the same stale field gate line 9 found is
entirely absent from the deployed code (zero occurrences, confirmed above). §18 is the more
extensively stale section — confirmed by reading both sections in full, not sampling. Per
`rules/coding.md` §11 ("When a code change affects manual rules, update the manual in the same
commit") and CLAUDE.md's Doc-code sync rule, this should have landed in the same commit(s) as
T4A.1/T4A.4/T4A.6 and did not. **Non-blocking for this gate's 14 lines** (none of them assert
manual accuracy directly), but a real, citable finding: the next agent reading §18 to understand
the beach-profile contract will build against a contract that stopped being true this round.

---

## Gate line 7 — Dashboard BeachProfileChart and HeatMapCard render without errors

**IN PROGRESS — not yet dispositioned.** First screenshot attempt was taken while librewxr was
saturated (SWAN run in progress at 434% CPU, LibreWXR Docker container independently at 749% CPU
across 173 threads, load average 219) and the surf detail fetch never completed — the tab showed
"Loading surf conditions…" indefinitely. **This is discarded as evidence for line 7 per the
lead's explicit direction** — a stuck loading state under host saturation is not evidence the
chart/card components are broken; it is evidence the data never arrived. Route required
Playwright (`/marine` has no location-level URL param — `useState`, not a route param, confirmed
by reading `src/routes/marine.tsx` — so a plain headless-Edge URL screenshot cannot reach the tab
without simulating clicks).

Will re-take once the host is quiet, per instruction, and disposition based on the clean render.

---

## Gate line 8 — SwellTrack produces non-zero face heights at HB

**Live evidence, `/tmp/gate4a_surf_loc.json` (per-location detail snapshot, captured 01:26
local / 08:26Z, **on a quiet host, 5 minutes before the 08:35Z SWAN run started** — confirmed by
the lead's own measurement that this exact call took >120s and returned the full body before any
contention began):**

- 67 forecast entries. `breakingFaceHeight` non-zero in **66 of 67** — values ranging ~4.1–5.5
  (display unit ft, `surfHeightDisplay: "face"`).
- The one zero entry (`forecast[0]`, `time: 2026-07-25T06:00:00Z`) has `modelStatus:
  "no_breaking"` — the model ran and found genuinely flat water at that specific hour, which is
  the *correct* T4A.4 behavior for a flat timestep, not a failure. `modelStatus` counts across
  the 67 entries: `{"ok": 66, "no_breaking": 1}` — zero `"unavailable"`.
- Per the lead's context: actual sea state this cycle was small (~3 ft, confirmed independently
  via the `Ssurf`-column investigation below: max Hs 0.9165 m across the 07:29Z TABLE), so small
  face heights are the physically correct answer here, not a degraded result. Contrast case
  (2026-07-23 incident: 0.01 m served during a documented 6–8 ft Beach Hazards Statement) does
  not apply — conditions here genuinely were small.

**Disposition: PASS.** Non-zero face heights confirmed live, on a quiet-host measurement, across
66 of 67 forecast hours, with the one zero explained by a correctly-classified flat timestep.

---

## Gate line 9 — Surf endpoint: `degraded=false`, face heights from SwellTrack

**The gate's own field name is stale — confirmed, not assumed.** `git grep -n "degraded"
eca80ee -- weewx_clearskies_api/endpoints/surf.py` → **zero occurrences of any kind** (not `=false`,
not a residual key, nothing). T4A.4's Accept explicitly replaces the boolean `degraded` with
`modelStatus` (`"ok" | "no_breaking" | "unavailable" | "degraded_bulk"`), and the plan's own
T4A.5 record already flagged this exact staleness ("the response has no `degraded` field;
`modelStatus` is the live equivalent and the criterion's field name is stale"). **This is a
finding about the gate, worth recording explicitly per the brief's own instruction, not a fresh
discovery:** gate line 9 as literally written is unmeasurable — there is no `degraded` field to
be `false`.

**Equivalent criterion, live-verified:** `/tmp/gate4a_surf_loc.json` (quiet-host, pre-contention
snapshot) — `modelStatus` counts `{"ok": 66, "no_breaking": 1}`, zero `"unavailable"` and zero
`"degraded_bulk"`. `nearshoreModel: "SWAN + SwellTrack"`.

**Face heights from SwellTrack, not SWAN CURVE — source-verified:**
`git grep -n "hsig_to_face_height" eca80ee -- weewx_clearskies_api/endpoints/surf.py` → **zero
matches.** `score_surf()` (line 1206) receives `wave_height=_swelltrack_face_m`, which is
`_pipeline_result.best_peak_face_height_m if _model_status != "unavailable" else None` (lines
1190–1194) — SwellTrack's own output, never a K-G/Caldwell formula value, and explicitly `None`
(not a formula guess) on model failure.

**Disposition: PASS on the equivalent criterion** (`modelStatus` confirms no degradation, face
heights confirmed from SwellTrack by source and matched against live non-formula values).
**The gate line's literal field name (`degraded`) is a FAIL/unmeasurable-as-written** — recorded
as a finding about the gate itself, not the implementation, per the brief's instruction that this
is worth more than a manufactured PASS.

---

## Gate line 10 — Beach profile endpoint returns full transect data with variable-resolution envelope

**Live evidence, `/tmp/gate4a_profile.json` (pre-deploy snapshot, eca80ee):**

- **628 points**, ordered offshore → shore (`distance` descending from 3091 m to 4.9 m).
- **Spacing: uniform ~1.5 m (4.92–4.925 ft) across the entire profile — not variable.** Checked
  every one of the 627 inter-point diffs, not a sample: min diff -4.925, max diff -4.921 (unit:
  ft, since `axisUnits.x = "ft"`; converts to ~1.5 m, matching the plan's own T4A.5 record of
  "629 points, uniform 1.5 m spacing" almost exactly — off by one point, consistent with the
  same underlying data a day-plus later).
- **Point count exceeds the >200 threshold; spacing does NOT match "1–2 m near shore, wider
  offshore."** This is the plan's own already-recorded T4A.5 deviation — `fine_zone_max_depth`
  (12.3 m, driven by `structure_zone_depth`) exceeds the profile's deepest sample (10.2 m), so
  the entire profile lies inside the fine zone and the coarse/approach zones never begin. Cause
  is arithmetic given the real inputs, not a code defect — already recorded, operator-accepted
  ("worth noting that the criterion... no longer describes the reachable outcome here").
  **Not re-reporting as new; recording because the gate line literally asks for it and the
  literal answer is FAIL on the "variable-resolution" half.**

- `metadata.handoffDepthM: 3.97`, `metadata.handoffSourceLevel: "L3"` — present, per T4A.6 item
  (g)/F2. Only one transect's data was in this particular snapshot's top-level `metadata`; I did
  not have a multi-transect capture to independently verify whether these are identical across
  all 32 transects. Per the brief's explicit note, **this is expected to be identical across
  transects today** (the Phase 4B defect — one CURVE per spot, replicated across all transects,
  not yet fixed) — **recording as the pre-4B baseline, not as a new finding**, consistent with
  the brief's instruction.

- `metadata.verticalDatum: null`. **This traces to a confirmed, distinct defect** — see the
  "Cross-host profile cache divergence" finding below. F3's code is verified correct
  (`_read_vertical_datum()` returns real value or null, never a hardcoded literal), but the field
  does not reach the live response on this deployment.

**Disposition: PASS** on point count (628 ≫ 200) and full transect data (breakPoints,
waveShapes, jackingFactors, surfZones, perPartitionBreaks, metadata all present and populated
per T4A.6's item a–g). **FAIL on the letter of "variable-resolution"** — spacing is uniform, for
the already-recorded, operator-accepted T4A.5 reason (not a new finding). `verticalDatum: null`
recorded as a distinct, newly-confirmed cross-host defect (below), not folded into T4A.5's
already-accepted spacing deviation.

---

## Gate line 11 — Surf scorer uses SwellTrack face height

**Source (eca80ee), `endpoints/surf.py` lines 1186–1225, read directly:**
`score_surf(wave_height=_swelltrack_face_m, ...)` where `_swelltrack_face_m =
_pipeline_result.best_peak_face_height_m if _model_status != "unavailable" and
_pipeline_result is not None else None` — SwellTrack's own `best_peak_face_height_m`, never
`face_height_m` from the removed SWAN CURVE K-G/Caldwell path. `spectral_components=None` is
explicitly passed (comment: "NDBC spectral data is NOT passed to the scorer... Scoring uses SWAN
values only").

**Disposition: PASS.** Confirmed by direct source read of the exact call site and its input
derivation, not inferred from the function name.

---

## Gate line 12 — CUDEM downloads at apply time, not runtime

**Source (eca80ee):** `download_bathymetry_for_level(domain, level, *, allow_download=True)` in
`providers/nearshore/swan.py`, with the docstring stating the runtime path passes
`allow_download=False`, "a missing cache is an ERROR + empty grid, never a download — the
apply-time chain (`endpoints/setup.py`) is the only caller that downloads." Verified both call
sites directly:
- `_run_all_spots_locked()`'s full-run path → `download_all_bathymetry(domains,
  allow_download=False)` (line 1708).
- `run_quick_update()`'s hourly path → `download_bathymetry_for_level(cluster.grid, level=3,
  allow_download=False)` (line 2073–2075).
- `endpoints/setup.py` apply handler → `download_bathymetry_for_level(level1, level=1)` /
  `(level2, level=2)` / `(cluster.grid, level=3)` (lines 2000, 2044, 2118) — default
  `allow_download=True`, the only caller that downloads.

**Live evidence, since the eca80ee deploy restart (2026-07-25 06:38:47Z) through the 07:13:30Z
run:** every SWAN runtime cycle logs `CUDEM L1/L2/L3: cached bathymetry datum=NAVD88
source=ncei_regional` — **"cached", never "downloaded" or "via OPeNDAP"** — zero download log
lines in this window. (Older Jul 22 log lines showing `"downloaded and cached bidirectional
CUDEM profile... (50 points...)"` and `"using NCEI ... via OPeNDAP"` are from **before** this
round's code landed — confirmed by the systemd restart boundary at 06:38:47Z — and reflect the
old 50-point pre-PCHIP runtime-download behavior T4A.3 replaced; not evidence of a current
regression.)

**Disposition: PASS.** Source confirms the `allow_download=False`/`True` split exactly as
claimed; live logs confirm zero downloads across every runtime cycle since this round's code
deployed, with only cache-read log lines.

---

## Gate line 13 — Profiles persist across restarts

**Disk evidence, librewxr (the host that actually reads these for SWAN + compute):**
- `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` — 27,265 bytes, mtime
  2026-07-25 06:41, contains `vertical_datum: "NAVD88"`, `contour_15m_distance_m`,
  `contour_30m_distance_m`, `fine_zone_max_depth`, `structure_zone_depth`, `max_hs_m`, `gamma`,
  `generated_at`, `profile` (629-point array) — matches T4A.5's record exactly.
- `/etc/weewx-clearskies/swan_grid_sizing.json` — 671 bytes, same mtime.
- `/etc/weewx-clearskies/swan_bathymetry_{L1,L2,L3_f3b62a2e}.json` — all present, L1/L2 dated
  2026-07-22, L3 (current cluster hash) dated 2026-07-25 06:41.

**Read-on-startup, not only written — confirmed live, not inferred:** the librewxr SWAN service
restarted at 06:38:47Z (T4A.5/eca80ee deploy) and logged, within 5 seconds of start:
`"SWAN: restored forecast cache from disk (saved 2026-07-25T01:40:24.474522+00:00, 1 spots)"`
followed by `"SWAN runner: pre-populated spot 'huntington-city-beach-pier' from cache
(run_time=2026-07-25T01:08:12Z)"`. This is exactly the `rules/coding.md` §1 pattern ("On
startup: load from disk → populate cache → serve immediately"). `swan_grid_sizing.json` and the
per-spot profile are read directly per-request rather than cached in memory at all (no
"loaded grid sizing" startup log line found, and `_read_vertical_datum()` in `beach_profile.py`
opens and parses the file fresh on every call) — this exceeds rather than falls short of the
persistence rule (no stale-in-memory-cache risk for these fields at all, at the cost of a disk
read per request).

**BLOCKER-eligible finding — cross-host profile cache divergence (new, confirmed independently,
not the lead's word taken):**

Two physically separate copies of the same cache path exist on two different hosts and have
diverged:

| Host | Path | Size | mtime | Has `vertical_datum`? |
|---|---|---|---|---|
| **librewxr** | `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` | 27,265 B | 2026-07-25 06:41 | Yes — `NAVD88` |
| **weewx** | `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` | 2,147 B | **2026-07-22 23:51** | No — key absent entirely |

Confirmed via `sudo cat` on weewx (the `claude` user has no direct read access; needed `sudo`).
weewx's copy predates T4A.2/T4A.3 landing — its schema has only `coastline_lat, coastline_lon,
profile, source`, none of T4A.3's added fields (`vertical_datum`, contour distances,
`structure_zone_depth`, `fine_zone_max_depth`, `max_hs_m`, `gamma`).

**Traced the code path directly, not inferred:** `endpoints/beach_profile.py`
`_read_vertical_datum()` (line 126) reads `_PROFILE_CACHE_DIR / f"{location_id}.json"` via a
**pure local filesystem read** (`cache_path.read_text(...)`) — no HTTP, no compute-host
involvement. `git grep -n "_PROFILE_CACHE_DIR" eca80ee -- weewx_clearskies_api/
endpoints/beach_profile.py` shows exactly one use site: this function. `endpoints/beach_profile.py`
executes as part of the main API process, confirmed on **weewx** (ARCHITECTURE.md's
current-deployment note: SWAN/compute split to librewxr, main API stays on weewx, port 8765).

Meanwhile the 628-point transect **does** reach the response correctly, because it is fetched via
`_remote_swelltrack(_compute_host, ...)` — an HTTP call to `surf_compute_host`, confirmed
configured in the live `api.conf [providers]` on weewx as `https://192.168.7.22:8770`
(librewxr's IP). The remote compute service, running on librewxr, uses **librewxr's own**
(fresh, correct) local profile copy to run the pipeline and ships the result back over HTTP.

**This produces two disjoint provenances for two fields in the same API response:**
`verticalDatum` (stale local read on weewx, returns null) and the transect geometry (fresh
remote fetch from librewxr, correct) — confirmed by reading the exact call sites, not inferred
from behavior.

**I looked for, and did not find, a cross-host sync mechanism** (checked `endpoints/setup.py`'s
apply handler for any push/replicate step to a remote compute host, `ARCHITECTURE.md`,
`PROVIDER-MANUAL.md`'s librewxr section) — no such mechanism appears in what I read. This does
**not** prove none exists; I am recording the absence-in-what-I-checked, not a definitive
absence, per the operating rule that a missing thing found by not finding it needs to be phrased
as a gap in verification, not a proven negative. The lead is taking this specific question
(does a normal `/setup/apply` run on weewx correctly propagate outputs to the separate librewxr
host where SWAN/compute actually read them) to the operator directly, as an architectural
question neither of us has authority to resolve.

**Distinct from the already-accepted gap.** `P4A-AUDIT-FINDINGS.md`'s accepted gap 3 ("HB's two
vertical datums, one grid") is about datum **reconciliation** when multiple DEM tiles disagree,
and explicitly assumes the datum reaches the response ("so the condition is visible rather than
silently wrong"). This finding is that the datum does **not** reach the response at all right
now — a delivery failure, not a reconciliation gap. Recording separately; not folding one into
the other.

**Disposition:** Persistence-to-disk and read-on-startup are confirmed **PASS** for the host
that actually runs SWAN/compute (librewxr). **The cross-host divergence is a real, newly
confirmed finding, BLOCKER-eligible** — `verticalDatum` (an explicit T4A.6/F3 deliverable) does
not reach the live response on this deployment, for a reason (stale host-local cache, never
refreshed by a full production apply) distinct from the already-accepted gap. Whether this is
architectural (routed to the operator by the lead) or an operational fix (re-run `/setup/apply`
properly) is not mine to resolve — recording the evidence, not the remediation.

---

## Gate line 14 — Auditor: zero unresolved findings

**F1, F2, F3 — verified genuinely closed in the deployed code (not just commit messages), each
by direct source read at eca80ee:**

- **F1** (L3 shoreward edge sized from feature coverage instead of the breaking-depth
  criterion): `swan_domain.py` `l3_shoreward_edge_depth_m()` returns
  `_FINE_ZONE_SHOALING_MARGIN * _MIN_DESIGN_HS_M / _GAMMA` (≈1.78 m) — the ADR's own literal
  formula. **Closed.**
- **F2** (`handoffDepthM`/`handoffSourceLevel` never wired to the pipeline call sites):
  `_handoff_by_transect` built once and passed at all three `beach_profile.py` call sites
  (`_run_pipeline`/`_remote_swelltrack`, lines 910, 926, 938). **Closed.**
- **F3** (`verticalDatum` hardcoded `"NAVD88"`): `_read_vertical_datum()` reads the real cached
  value and returns `null` (not a fabricated literal) when absent. **The code fix itself is
  genuinely closed and correct** — but see gate line 13's cross-host finding: on this
  deployment the field the code correctly tries to read is not present on the host that reads
  it, so the *live delivery* of F3's fix is broken for a reason distinct from the code fix
  itself. **Do not read this as F3's code being unclosed — it is a deployment-state gap
  discovered downstream of a closed code fix.**

**New findings surfaced by this audit round, not previously tracked anywhere:**

1. **`DISSURF`/`Ssurf` header-token mismatch — `breakingDissipation` always null.**
   Verified independently at eca80ee: both `_parse_table_output` (~line 355) and
   `_parse_transect_table` (~line 557) in `swan_runner.py` do
   `col_idx.get("DISSURF") or col_idx.get("DISS")`. The real SWAN TABLE header (read directly
   from `/var/run/weewx-clearskies/swan/level3_0/TABLE_1.txt` on librewxr, 07:29Z run) is
   `Time Xp Yp Hsig Hswell Tm01 Dir Depth Qb Ssurf Dspr` — uppercased to `SSURF`, matching
   neither lookup key. `i_dissurf` is always `None`; `breakingDissipation` is always null on
   every point of every run. **QB is unaffected** (`col_idx.get("QB")` matches `"Qb"` → `"QB"`
   exactly) — the field T4A.10's assertion actually depends on parses correctly, confirmed.
   **Origin:** `git log -S "DISSURF" eca80ee -- swan_runner.py` → one commit, `ea47ed6`
   ("T3.1–T3.5 cross-shore transect..."), a Phase 3 commit — **pre-existing, not a Phase 4A
   regression.** **Test coverage:** `git grep -rn "breakingDissipation\|dissurf" eca80ee --
   tests/` → zero hits, explaining why it was never caught. Secondary, currently-moot bug in the
   same lines: `col_idx.get(X) or col_idx.get(Y)` treats a legitimate column index of `0` as
   falsy.
   **Severity: non-blocking, MEDIUM.** `breakingDissipation` is a diagnostic field; ADR-095
   Amendment 1 makes SwellTrack's own `H/d = gamma` crossing the primary break-point authority,
   with SWAN's QB retained as diagnostic only — QB parses correctly, so no gate line's
   underlying claim is affected. This is the same silent-null failure shape
   `rules/coding.md` §1 names ("a forgotten field means the data exists in the backing store but
   is invisible to consumers") even though the mechanism here is a header-token mismatch rather
   than a copy omission.

2. **`SWAN_LAST_RUN_VALID_FRACTION` pinned to 0.0 for L1 and L2 on every successful run, and a
   self-contradicting pair of log lines about the same value.**
   Verified independently at eca80ee, `swan_runner.py` ~2650–2802: L1/L2 produce no per-spot
   TABLE output by architecture (`table_files` glob is structurally always empty for those two
   levels — confirmed by reading the file-collection logic, not just the comment), so
   `valid_fraction` is always `None` for L1/L2. Three lines apply **opposite defaults to the
   same `None`**: the unconditional "log all metrics" INFO line defaults `None`→`100.0` (line
   ~2758); the Prometheus gauge-set two lines later defaults the same `None`→`0.0` (line
   ~2785–2786); the "convergence OK" summary log then uses that `0.0` value (line ~2797–2802),
   contradicting the INFO line four lines above it about the identical run. Same
   opposite-default pattern on `accuracy_pct` (0.0 vs 100.0 defaults at the two log sites).
   **Live confirmation, a second and independent occurrence:** the 08:35:42Z run (`ce4415b`)
   produced the identical contradictory pair live: `"...accuracy=0.0%,...valid_fraction=100.0%"`
   immediately followed by `"...OK...accuracy=100.0%, valid_fraction=0.0%..."` — same run, same
   level, two irreconcilable numbers.
   **Origin:** `git log -S "SWAN_LAST_RUN_VALID_FRACTION" eca80ee -- swan_runner.py` → one
   commit, `ac73ab2`, dated **2026-07-19 16:26:24 -0700** — four days before Phase 4A's own
   origin (2026-07-23). **Pre-existing, not a Phase 4A regression.**
   **Test coverage:** `git grep -rln "SWAN_LAST_RUN_VALID_FRACTION" eca80ee -- tests/` → zero
   hits. A broader grep for "convergence" only matches two unrelated 1D-analytical-model test
   files (a different meaning of the word — Battjes-Janssen roller-model convergence).
   **Severity: non-blocking for Gate 4A specifically** — none of the 14 gate lines assert
   anything about this metric or the convergence gate; the gate is scoped to the SwellTrack
   pipeline + vocabulary unification. **But materially worse in kind than the `Ssurf` bug**: a
   silently *wrong* exported metric (0.0% on every healthy L1/L2 run, permanently) actively
   misleads an operator who alerts on it, where the `Ssurf` bug merely withholds a diagnostic.
   An operator alerting on `SWAN_LAST_RUN_VALID_FRACTION{level="level1"}` would either page
   constantly on every healthy run, or have already silenced the alert — in which case it is
   also dead for L3, the level where the metric actually carries meaning.

3. **Cross-host profile cache divergence** — see gate line 13 above in full. Not duplicating
   here; flagged as BLOCKER-eligible for line 13/F3's live delivery, and noted again here because
   gate line 14 explicitly asks whether anything new surfaced.

**Disposition: NOT a clean PASS.** F1 and F2 are genuinely closed, both in code and in live
behavior. F3 is closed in code but its live delivery is broken by a newly-discovered,
independently-confirmed cross-host cache divergence — a distinct defect from the already-accepted
gap 3. Two further pre-existing (not Phase 4A) defects surfaced (`DISSURF`/`Ssurf`,
`SWAN_LAST_RUN_VALID_FRACTION`), both non-blocking for this gate's own scope but real and now
recorded for the first time anywhere.

---

*(Gate lines 7, 8 revisited, 9, 10 to be finalized after a clean-host retest per the lead's
instruction — see addendum below once available.)*
