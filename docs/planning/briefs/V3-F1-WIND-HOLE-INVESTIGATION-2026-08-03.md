# V3-F1 — Mid-forecast wind-coverage hole: read-only investigation report

> Produced by the read-only Explore agent dispatched 2026-08-03 (decision item 9,
> AUDIT-OPUS-WINDOW-2026-08-03.md). Saved verbatim by the coordinator. Facts + options only —
> remediation ruling is the operator's.

**Scope:** `repos/weewx-clearskies-marine` @ HEAD `a934e9f` (marine repo), superproject @ `214687c` (2026-08-03). No files modified. All citations are `path:line` at HEAD.

---

## 0. Executive summary (mechanism, fully pinned)

The lead's journal-derived mechanism is **confirmed by code read, and the arithmetic reproduces the audit's payload exactly**:

- HRRR is fetched with `max_forecast_hours=48` → `extended_only=True` → cycle snapped to the most recent 00/06/12/18Z with a **1-hour** availability lag (`hrrr.py:105`, `:641-666`). At 13:04Z this selects **12Z**.
- The per-forecast-hour loop (`hrrr.py:826-847`) `break`s on the first 404 **after f00** and then, at `hrrr.py:912-929`, **returns the partial cycle as a success**. Cycle fallback (`hrrr.py:806-807`) is only reached when **f00 itself** 404s. f00–f11 of 12Z existed → 12 grids returned, no fallback attempted, no error.
- GFS is fetched at its designed far window only: `_DEFAULT_HOURS_START = 48`, `_DEFAULT_HOURS_END = 72` (`gfs.py:102-103`), cycle = now − 4h30 snapped to 00/06/12/18Z (`gfs.py:108`, `:495-511`) → **06Z**, f048–f072 = Aug 4 06Z → Aug 5 06Z, "9 forecast hour(s)" as logged.
- `_stitch_wind()` (`swan_runner.py:2695-2816`) concatenates HRRR grids with GFS grids **strictly after HRRR's last valid_time** (`:2789-2793`), sorts and de-dups — **and performs no contiguity check of any kind**. Result: 12 HRRR grids (Aug 2 12Z–23Z) + 24 interpolated GFS grids (Aug 4 07Z–Aug 5 06Z) + f048 = **36 grids with a 30-slot hole**.
- The full run is a **quasi-stationary sequence** (`swan.py:3297-3298` → `stationary=True, stationary_sequence=True`), which emits **one `COMPUTE STAT` per entry of `valid_times`** (`swan_formats.py:2194-2196`). 36 wind grids → 36 COMPUTE steps → 36 output rows.
- The surf endpoint builds the served array from `sorted(_points_by_time.keys())` — the *observed* SWAN timestamps only (`endpoints/surf.py:841-848`, `:1093-1094`). **Nothing enumerates an expected hour grid, so missing hours are absent rather than null.**
- **36 grids → 36 served entries — exactly the "36-entry live payload" the auditor captured.** The chain is closed end to end.

---

## 1. The designed wind-window contract — where it is encoded

| Boundary | Location | Value |
|---|---|---|
| HRRR near/mid window | `providers/wind/hrrr.py:104` `_MAX_FORECAST_HOURS = 18`; call sites pass **48** (`service.py:341`, `swan.py:2440`) | f00–f48, hourly |
| HRRR "extended cycle" set | `hrrr.py:638` `_EXTENDED_CYCLE_HOURS = (0, 6, 12, 18)` | cycle-hour snap |
| HRRR availability lag | `hrrr.py:105` `_CYCLE_AVAILABILITY_LAG = timedelta(hours=1)` | 1 h |
| GFS far window | `gfs.py:102-104` `_DEFAULT_HOURS_START = 48`, `_DEFAULT_HOURS_END = 72`, `_GFS_HOUR_STEP = 3` | f048–f072, 3-hourly |
| GFS availability lag | `gfs.py:108` `timedelta(hours=4, minutes=30)` | 4.5 h |
| Blend/handoff point | `swan_runner.py:2695-2816` `_stitch_wind()`; handoff = "strictly after HRRR's last valid_time" (`:2789-2790`) | dynamic, not a constant |
| Doc statement | `PROVIDER-MANUAL.md:1863-1864` (input table), `:1821`, `:1893`, `:1911`, `:2558` | "HRRR 0–48, GFS 48–72" |
| ADR | `docs/decisions/ADR-094-hrrr-surf-wind-source.md:39` | same split |

**No configuration key exists for either window.** Both are module constants; the split is hard-coded in three independent places.

**Where is 12–47 h supposed to come from when the current HRRR cycle's extended files are not yet posted? Answer: nowhere. The design has no provision for it.** The contract assumes the selected extended HRRR cycle is *fully posted* (`PROVIDER-MANUAL.md:1816-1819` states extended cycles = "f00–f48 (49 grids)" as if atomic). The handoff point is *derived from whatever HRRR returned* rather than pinned at hour 48, so a short HRRR field silently moves the handoff to hour 11 and logs "coverage ends …" as an INFO success line (`swan_runner.py:2811-2815`).

---

## 2. Fallback behaviour today — why nothing filled 12–47 h

**A prior-cycle fallback exists but is unreachable for this failure.**

`hrrr.py:802-807`: 3 attempts × 6 h step (extended). Parameters correct for the job (a 06Z cycle was available and would have covered the entire missing window). **The loop never got a second iteration** — `hrrr.py:832-847`: only an **f00** 404 reaches the next attempt; a later-hour 404 `break`s and `hrrr.py:912-929` returns the partial cycle as success.

**Cause classification:**
1. **Posted-cycle detection — PRIMARY.** "Posted" = f00 exists, not "all requested f-hours exist." A 25%-posted cycle is indistinguishable from a complete one.
2. **Window arithmetic — SECONDARY.** Fallback always restarts at f00 of the older cycle; no "fetch only f-hours whose *valid times* are missing" concept exists — coverage is expressed in forecast-hour space, never valid-time space.
3. **Fallback count exhausted — NOT a factor.** `attempt` stayed 0.

**Aggravating factors:**
- **Silent severity.** Truncation logged at DEBUG (`hrrr.py:841-846`); success line reports only a grid count at INFO (`:923-928`).
- **The 55-min HRRR cache does not save it.** Partial 12Z field cached under `(bbox, 12Z)`; runner loop skips while `cycle_id == last_hrrr_cycle` (`service.py:377-379`), advanced on the partial run (`service.py:494`). **Hole locked in ~6 h until the 18Z cycle.**
- **NEW (finding 13): the hourly stationary fill appears unreachable in production.** `service.py:341` always requests 48 h → `extended_only` always True → cycle always 00/06/12/18Z → `_is_extended_hrrr_cycle()` always True → `run_quick_update()` (only non-test caller `service.py:517`) never runs. Tests exercise it only by stubbing fetch(). If confirmed live: removes the hourly re-run that would have healed the hole, and is itself a C3-cadence concern.
- **GFS has the identical partial-success shape** (`gfs.py:643-661`, `:707-719`) — same hole class reachable from the far window.

---

## 3. Publish-with-hole policy — encoded intent vs. unhandled case

**Publishing a mid-forecast hole is an UNHANDLED CASE, not encoded "honest serving."** The encoded policy is C-77's refusal to publish a **shortened** forecast (`swan.py:2453-2494` → `record_no_publish("gfs_wind_failed", …)`; `PROVIDER-MANUAL.md:2573`; `rules/coding.md:32-38`) — and it is a **null-check** (`swan.py:2472`) that a 12-grid HRRR field passes.

Gaps: no wind-coverage/contiguity validation anywhere; `_stitch_wind()` gap-agnostic by construction (docstring asserts continuity it does not verify, `:2700-2706`); `/health` wind check is a not-None test (`service.py:432-434`); publish assembly iterates observed timestamps only — the existing per-timestep gap-reporting (`surf.py:605-615`, `endpoints/gap.py`) cannot see an ABSENT timestamp.

**Doc-code conflicts confirmed:** `DASHBOARD-MANUAL.md:1194` (chart "continuous across day boundaries"); `PROVIDER-MANUAL.md:1893` ("single continuous 72-hour wind input"); `API-MANUAL.md:1825`/`:3005` (72 hourly points / always multi-timestep); `PROVIDER-MANUAL.md:1841` (fallback description reads as the behavior we needed and did not get); `:1816-1819` (49-grid assumption unenforced); `:1845` (TTL 21600 documented vs `hrrr.py:101` = 3300).

---

## 3b. NEW, previously unreported: the hole also **time-shifts the far-window wind forcing**

`swan_formats.py:1522`: `wind_dt_hr = 1  # blended wind field is 1-hour cadence throughout` — emitted into `INPGRID WIND … NONSTAT {t_start} 1 HR {t_end}` (`:1698-1702`), with `t_start`/`t_end` from `valid_times[0]`/`[-1]` (`:1517-1518`). SWAN indexes WIND.txt blocks **positionally at uniform 1-hour cadence**, while `hrrr_to_swan_wind()` writes **one block per grid present** (`:344-397`) — 36 blocks for a declared 67-hour window.

By construction: block *k* is consumed at `t_start + k h`, so every GFS block is applied ~30 h **earlier than its valid time**, and the COMPUTE sequence runs past EOF. Same positional assumption governs WLEVEL and CURRENT (`:1708-1728`).

**Caveat:** code-read inference; SWAN's actual EOF/hold behavior unobserved. But the code's own asserted invariant is **provably violated** whenever `_stitch_wind()` returns a gapped field → served far-window entries are **suspect, not merely sparse**, until a run confirms otherwise. Independently fixable (derive cadence from actual valid_times, or refuse a non-uniform series) without touching cycle selection.

---

## 4. Remediation options with CLAUDE.md trigger classification

*(No option picked. Trigger list: CLAUDE.md 7-item table.)*

### (a) Prior-fully-posted-HRRR-cycle fallback for the extended window
Make "posted" mean "posted through the requested horizon" at `hrrr.py:832-847`; else step back 6 h.
- **Trigger 3 — ARCHITECTURAL (plan already flags it);** also trigger 6 if effective run cadence changes.
- Ripples: (i) nothing trims past hours — an older cycle publishes already-elapsed hours unless trimming is added (itself trigger 4); (ii) `last_hrrr_cycle` / `_build_run_marker_key()` (`swan.py:1313-1325`) / 6-h dedup all keyed on HRRR cycle string; (iii) cost: full probe = up to 49 NOMADS requests × 0.55 s ≈ 27 s per rejected cycle.
- Adjacent precedent: operator's 2026-08-03 display-side ruling ("no reason they cannot get the old data") — same instinct; whether it extends to model input is the operator's call.

### (b) Widen GFS coverage into the mid window when HRRR is short
`gfs.fetch(hours_start=<first uncovered hour>, hours_end=72)` when HRRR falls short.
- **Trigger 3 — ARCHITECTURAL** (moves the HRRR→GFS handoff point; changes documented 3 km vs 25 km wind-resolution boundary). Trigger-1 adjacent (`_DEFAULT_HOURS_START` is the criterion selecting which physics forces hours 12–47). Cheapest; silently downgrades nearshore wind resolution the manual promises at 3 km.

### (c) Delay / refuse publish on a mid-hole
Contiguity gate before run/cache-write → `record_no_publish("wind_coverage_gap", …)`, preserve last-good, retry next interval.
- **Not architectural by the mechanical test** as a pure defect fix (code obeys its own stated contract — C-77, `rules/coding.md:32-38`; CLAUDE.md permits contract-conformance fixes). Caveats that could flip it: new no-publish reason slug on `/health` (**trigger 4**); retry behavior (**trigger 6**). Without a retry mechanism converts a 30-h hole into up to 6 h on last-good cache — the documented preference (`PROVIDER-MANUAL.md:1986` "stale SWAN data is always preferred to no data").

### (d) Null-pad + document "honest serving"
- **Trigger 4 — ARCHITECTURAL (data contract);** trigger 7 if new field/config key. Tension: `rules/coding.md:56-59` — documented substitution wants an ADR, not a manual edit.

### (e) Doc-only sub-batch (independent, no trigger)
Correct `PROVIDER-MANUAL.md:1841`, `:1845`, `:1893`, `DASHBOARD-MANUAL.md:1194`, `API-MANUAL.md:1825`/`:3005`.

### (f) Fix the `wind_dt_hr` cadence assertion (orthogonal, survives any of a–d)
Derive declared cadence from actual valid_times, or refuse a non-uniform series, at `swan_formats.py:1522`. Arguably pure defect fix (code contradicts its own inline invariant); trigger-3-adjacent only if it changes how wind projects onto the model clock.

---

## 5. Facts established vs. options awaiting operator ruling

### Facts established (code-verified at HEAD)
1. Wind-window split encoded in module constants only; no config key; no single source of truth; three docs restate it.
2. **No provision exists for the 12–47 h window when the current HRRR extended cycle is partially posted.** Handoff point derived, not pinned.
3. **Prior-cycle fallback exists, parameters correct, but gated on f00 alone**; partial cycle returns as success. Root cause = posted-cycle detection + forecast-hour-space arithmetic. Fallback exhaustion not a factor.
4. Truncation at DEBUG; success line reports only a grid count at INFO.
5. **Hole persists ~6 h** (cycle-keyed skip + advanced marker + 55-min TTL cannot re-trigger).
6. **No wind-coverage validation anywhere**; `/health` wind check is not-None; stayed green.
7. **Mid-hole publish is unhandled, not intended** — C-77 is a null-check a partial field passes.
8. **Publish path never null-pads**; absent timestamps invisible to gap-reporting.
9. Doc-code conflicts as listed in §3.
10. **Arithmetic reproduces the audit exactly** (36 grids → 36 COMPUTE → 36-entry payload, hole Aug 3 00Z → Aug 4 06Z).
11. **GFS carries the identical partial-success defect.**
12. **§3b wind-forcing time-shift** — far-window entries suspect, not merely sparse (needs run confirmation).
13. **Hourly stationary fill appears unreachable in production** (always-extended cycles) — C3-cadence concern.

### Awaiting operator ruling
- (a) fully-posted-cycle fallback — trigger 3 (+6) + ripples; (b) widen GFS — trigger 3; (c) refuse publish on mid-hole — contract-conformance + trigger-4 slug; (d) null-pad — trigger 4 (+7), wants an ADR; (e) doc batch — no trigger, safe now; (f) cadence assertion fix — orthogonal, survives any choice.
