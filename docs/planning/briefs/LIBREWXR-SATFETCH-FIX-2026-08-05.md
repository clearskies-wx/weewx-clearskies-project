# LIBREWXR-SATFETCH-FIX — Round brief (2026-08-05)

## Round identity

- **Round:** LibreWXR satellite CPU-burn fix, single round
- **Date:** 2026-08-05
- **Lead:** coordinator (this session)
- **Teammates:** 1 implementation agent (Sonnet), 1 blind adversarial auditor (Sonnet, dispatched after acceptance)
- **Repo:** `c:\CODE\weather-belchertown\repos\librewxr`, branch `deploy/shaneburkhardt`, baseline HEAD `1c16b34`
- **Operator authorization:** operator approved "the fix with the additional follow ups" in chat 2026-08-05 after the investigation report. No push/deploy authorized yet.

## Background (investigation findings, coordinator-verified on the live container)

The `librewxr-librewxr-1` Docker container (LXC `librewxr`, 192.168.7.22) burns ~2 CPU cores
average, recurring after restart; first incident pinned 8 cores for ~24 h. Root cause chain,
verified from container logs and code:

1. **Retention/listing-window mismatch** (`src/librewxr/sources/satellite/_geo_base.py`,
   `_fetch_sync`, lines 173–207). `window_hours = (max_frames × cadence)//60 + 1` → for the
   24-frame 5-min GOES store, 3 hours ≈ 36 listed keys. Dedup is only `if unix_ts in
   self._frames` (the in-memory ring). The trim loop (lines 196–200) then evicts everything
   beyond the newest 24. Net effect: every poll re-downloads, re-decodes, and re-caches 12–23
   frames per family that are immediately evicted again. Log signature: "ingested N new
   frame(s)" with N climbing 12→23 each 5-min poll, resetting hourly. Healthy N is 1.
2. **Double full warms.** `data/fetcher.py:399-402`: each family's background fetch fires
   `warm_satellite()` when `new_frames` is truthy. Both GOES families ingest each cycle, so two
   full multi-family warms (~57–65 s each, threadpool-parallel) run concurrently every cycle,
   doing duplicate work.
3. **NaN→int32 cast warnings** (`_geo_base.py` `sample()`, lines 529–530). `x_ang`/`y_ang`
   contain NaN for points off the satellite disk; they are cast to int32 BEFORE the `visible`
   mask is applied → `RuntimeWarning: invalid value encountered in cast` twice per decode, and
   reliance on an undefined cast.

## Scope

### Files to create or modify (exhaustive allowlist)

1. `src/librewxr/sources/satellite/_geo_base.py` — fixes D1 and D3 only.
2. `src/librewxr/tiles/warmer.py` — fix D2 only.
3. `tests/test_satellite_goes.py` — add guards G1 and G3 (append; do not modify existing tests).
4. `tests/test_warmer_satellite.py` — NEW file, guard G2.
5. `.venv/` — you may create the repo-local venv per the repo's CLAUDE.md quick start
   (`python -m venv .venv; .venv\Scripts\pip install -e ".[dev]"`). Not committed
   (`.gitignore` covers it).

### Files NOT to touch (explicit exclusions)

- `data/fetcher.py` — the per-family warm trigger stays as-is; coalescing lives in the warmer.
- `warm_satellite_demand` in `warmer.py` — untouched.
- `sources/satellite/gmgsi/**`, `goes/**`, `himawari/**` — subclasses are untouched.
- `main.py`, `data_pipeline.py`, `config.py` — no config keys, no lifecycle changes.
- Any existing test — if an existing test fails against your change, STOP and report (stale-test
  block below).
- `docker-compose.yml`, `Dockerfile`, `pyproject.toml` — no dependency or deploy changes.

## Reading list (read BEFORE writing any code)

1. `repos/librewxr/CLAUDE.md` — "Project Structure", "Architecture Notes" (satellite +
   memory-management bullets), "Running Tests", "Development Conventions".
2. `repos/librewxr/src/librewxr/sources/satellite/_geo_base.py` — the whole class skeleton;
   closely: `__init__` (lines ~90–140), `_fetch_sync` (173–207), `_list_recent_keys` (209+),
   `sample()` (496–544), `_load_cached_frames` / snapshot state (643+).
3. `repos/librewxr/src/librewxr/tiles/warmer.py` — class docstring + `__init__` (17–60),
   `warm_satellite` (513 to end of method), `warm_satellite_demand` (363–511, to confirm you
   are NOT changing it).
4. `repos/librewxr/src/librewxr/data/fetcher.py` lines 360–403 — the trigger you must NOT change.
5. `repos/librewxr/tests/test_satellite_goes.py` — existing fixture patterns (synthetic grids,
   mocked S3), `pytestmark` convention.
6. `rules/coding.md` §"Treat your own output as untrusted", §"No dead code", §4 "Self-review
   before declaring done" (in `c:\CODE\weather-belchertown\rules\coding.md`).

## Pre-round verification (lead's evidence)

- `git status` clean, `deploy/shaneburkhardt` == `origin/deploy/shaneburkhardt` at `1c16b34`
  (verified 2026-08-05 in this session, transcript in chat).
- No local `.venv` exists yet (checked).
- Live-container evidence for the defect: log lines pasted in chat (ingested 13–14/poll/family;
  two 57–65 s warms per cycle; RuntimeWarning pairs at `_geo_base.py:529-530`).

## Per-deliverable spec (lead calls — implement exactly this)

### D1 — retention-window trim in `_fetch_sync`

After `keys = self._list_recent_keys(fs, window_start, now)` and its empty-check, and BEFORE the
ingest loop, keep only the newest `max_frames` keys:

```python
keys = sorted(keys)[-self._max_frames :]
```

Rationale (comment-worthy, one line): any key beyond the newest `max_frames` would be evicted by
the trim loop immediately after ingest; downloading it is pure waste. The generous listing window
is still needed to refill the store after restarts/gaps — do NOT shrink `window_hours`.
`_list_recent_keys` returns `list[tuple[int, str]]`; tuple sort (ts asc) is the intended order.

Edge cases that must keep working: store empty at startup (all newest-24 download); store
partially full after a gap; duplicate timestamps across keys (dict assignment dedups — unchanged).

### D2 — single-flight satellite warm with trailing rerun in `TileWarmer`

- Rename the existing `warm_satellite` body (lines 513–end) to `_warm_satellite_once` (private,
  same body, unchanged).
- Add instance state in `__init__`: `self._satellite_warm_running: bool = False` and
  `self._satellite_warm_rerun: bool = False`.
- New public `warm_satellite` (same name/signature, so `fetcher.py` needs no change):

```python
async def warm_satellite(self) -> None:
    if self._satellite_warm_running:
        self._satellite_warm_rerun = True
        return
    self._satellite_warm_running = True
    try:
        while True:
            self._satellite_warm_rerun = False
            await self._warm_satellite_once()
            if not self._satellite_warm_rerun:
                break
    finally:
        self._satellite_warm_running = False
```

Docstring on the wrapper: one short paragraph — concurrent calls coalesce; a call arriving
mid-warm schedules exactly one trailing pass so frames ingested by the second family after the
first pass indexed its grids are still warmed (the trailing pass is mostly cache-skips).
Single-threaded asyncio: plain bools are safe, no lock needed.

### D3 — NaN-safe casts in `sample()`

Move the `visible` computation ABOVE the casts and cast NaN-suppressed arrays; `in_bounds` keeps
using `visible`:

```python
visible = ~(np.isnan(x_ang) | np.isnan(y_ang))
x_safe = np.where(visible, x_ang, 0.0)
y_safe = np.where(visible, y_ang, 0.0)
col = ((x_safe - self._x_vec[0]) / x_step).astype(np.int32)
row = ((self._y_vec[0] - y_safe) / y_step).astype(np.int32)
```

Output must be bit-identical for all inputs (invisible points were already masked to 0 via
`in_bounds` → `np.where`). This removes the undefined NaN→int32 cast, not just the warning.

### Guards (implementing side; each must FAIL against baseline `1c16b34`)

- **G1 (retention)** in `tests/test_satellite_goes.py`, marker `sources`: a `GeoSatSource`
  (or minimal concrete subclass, following the file's existing synthetic patterns) with
  `max_frames=4`; monkeypatch `_list_recent_keys` to return 10 `(ts, key)` tuples (ascending),
  monkeypatch `_download_and_decode` to a call-counting stub returning a small uint8 array;
  pre-populate `self._frames` with the newest 4 timestamps. Call `_fetch_sync`. Assert the
  download stub was called 0 times and the store still holds exactly the newest 4.
  Pre-change behavior: 6 downloads → the assert fails. Also assert: with an EMPTY store, the
  stub is called exactly 4 times (newest 4 only) — pre-change: 10.
- **G2 (single-flight)** in new `tests/test_warmer_satellite.py`, marker `tiles`: build a
  `TileWarmer` with minimal mocks; monkeypatch `_warm_satellite_once` with a coroutine that
  increments a running-counter, records its max concurrency, `await asyncio.sleep(0.02)`,
  decrements, and counts total invocations. `asyncio.gather` three concurrent
  `warm_satellite()` calls. Assert total invocations == 2 (one live + one trailing) and max
  concurrency == 1. Declare in the closeout: this guard fails pre-change with `AttributeError`
  (no `_warm_satellite_once`) — a mechanics pin, declared as such per rules/verification.md.
- **G3 (NaN cast)** in `tests/test_satellite_goes.py`, marker `sources`: reuse the file's
  synthetic-grid `sample()` pattern; input lat/lon arrays containing both on-disk and off-disk
  (NaN-projecting) points, e.g. the antipode of the sub-satellite longitude. Run under
  `warnings.catch_warnings()` + `simplefilter("error", RuntimeWarning)`. Assert no raise AND
  the visible points' sampled values equal the same call's values computed without the filter
  (or a hand-picked expected array). Pre-change: raises RuntimeWarning → fails.

## Verification command (run before closeout, from repo root)

```
.venv\Scripts\python -m pytest tests/test_satellite_goes.py tests/test_warmer_satellite.py -q
```

Expected: all pass, 0 failed. Do NOT run the full pytest suite.

Additionally run the pre-change falsification transcript: `git stash` your source edits (NOT the
test files), run the same command, record G1/G3 failing (and G2's AttributeError), `git stash pop`.
Include both transcripts in the closeout. If stash/pop feels risky, instead run falsification
FIRST: write tests, run (must fail), then implement.
Preferred order: tests first, watch them fail, then implement — no stash needed.

## Deliverable definition

Two commits on local `deploy/shaneburkhardt` (NOT pushed):
1. `fix(satellite): skip out-of-retention keys; single-flight warms; NaN-safe sample cast` —
   the two source files.
2. `test(satellite): guards for retention trim, warm coalescing, NaN-safe sample` — the tests.

Closeout report via SendMessage: files touched, pytest transcript (pass), falsification
transcript (pre-change fails), every guard/warning that fired during work, any test you modified
or deleted (expected: none), and confirmation the working tree is otherwise clean.

## Mandatory blocks

**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
`git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`,
`git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via
SendMessage. Do not resolve it yourself.

**Container ban:** You must NOT SSH anywhere. All work is on the local machine in
`c:\CODE\weather-belchertown\repos\librewxr`. No container reads are needed for this task.

**Architectural changes — STOP, do not proceed.** You may not make an architectural change. If
your task requires one, STOP and report via SendMessage — do not implement it, do not work around
it, do not pick an option.

A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or
   criterion inside one. This does NOT cover changing how the same equation is solved. Test: does
   it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the first
   is architectural.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units crossing
   a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.

These do NOT authorize you: "my task's acceptance criteria are unreachable without it" (then your
task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a finding
to report, not permission to change code). You MAY still: resolve a contradiction between two
statements inside the same document by taking the reading its own examples support (and say so);
apply a rule already written in the rules files; fix code that diverges from its own stated contract.

Note: the operator explicitly approved D1–D3 in chat on 2026-08-05; implementing them as
specified is not an unauthorized change. Deviating from the spec is.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change,
STOP and report it via SendMessage — do not modify code to make it pass, and do not delete it on
your own authority. A behavior change and its test updates land in the same commit, per your
task's design; a test you were not told to touch that fails against your change is a finding.
Your closeout report must list every test you modified or deleted, with the reason, and every
guard, invariant, or viability check that fired during your work — including ones you believe are
unrelated or pre-existing.

## Scope ack (required before any code)

SendMessage the lead one paragraph: what you will deliver, what you will NOT touch, and the exact
verification command you will run. Wait for confirmation before writing code.

## Open questions protocol

Any ambiguity → SendMessage the lead. Do not resolve unilaterally. Known non-questions: the spec
snippets above are lead calls; implement them as written unless they fail to compile/pass, in
which case report the exact failure.

## Parking lot (tracked deferrals)

- **P1 (found 2026-08-05, pre-round):** `tests/test_satellite_goes.py` has 6 PRE-EXISTING
  failures at baseline `1c16b34`, verified independently by the lead (own run: 6 failed /
  19 passed): 3× `satellite_provider` MagicMock-settings failures (`goes/__init__.py:147`,
  `goes_max_frames` attr), 1× `test_ir_warm_maps_to_low_uint8` stale vs the 340 K IR-range
  commit `2dcaa98`, 2× `TestBBOXCrop` stale vs BBOX-overlap rework `0bd6a99`/`2a7acb7`.
  These are stale tests pinning drifted behavior — disposition (update vs delete) is the
  operator's, NOT this round's. This round's acceptance criterion is amended to: the same 6
  failures and only those; 19 baseline passes still pass; G1/G3 added and passing;
  `test_warmer_satellite.py` all passing. Itemized transcripts, no bare "0 failed" claims.

## ROUND 2 — stale-test repair (added 2026-08-05 after operator ruling "fix everything, if there are stale tests, fix those too")

Round 1 (D1/D2/D3 + guards) ACCEPTED by lead at commits `25d8f96` + `ad22279`: independent
re-run 6 failed / 22 passed matching closeout; commit stats match allowlist; diff spot-checked.

Full-suite inventory (lead-run, 2026-08-05, local Windows venv, 83.56 s):
**19 failed / 1093 passed.** Lead diagnosis of all 19, with dispositions:

### Allowlist (round 2 — TEST FILES ONLY, no source file may be touched)

1. `tests/test_satellite_goes.py` — R2-T1 (3 tests), R2-T2 (1), R2-T3 (2)
2. `tests/test_satellite_himawari.py` — R2-T1 (3 tests), R2-T2 (1)
3. `tests/test_geostationary.py` — R2-T4 (1 test) + R2-T4b (new KAT)
4. `tests/test_gmgsi_composite_renderer.py` — R2-T5 (2 tests)
5. `tests/test_fetcher.py` — R2-T6 (1 test, skipif)
6. `tests/test_hrrr_grid.py`, `tests/test_hrrr_alaska_grid.py`, `tests/test_icon_eu_grid.py`,
   `tests/test_dmi_dini_grid.py`, `tests/test_wrf_smn_grid.py` — R2-T6 (5 tests, skipif)

### Dispositions (lead calls)

**R2-T1 — provider-selection mock fixtures (6 tests, goes + himawari).** Cause: providers now
read per-source max-frames config (`goes/__init__.py:147` and himawari equivalent) via
`getattr(settings, "<attr>", 0)`; a bare `MagicMock()` returns a Mock for the attr and
`> 0` raises TypeError. Fix: in each failing test, set the real integer attrs the provider
reads (read the provider source for exact names; set to `0` to exercise the documented default
path). Minimal diff — do not restructure the tests or add `spec=`.

**R2-T2 — IR warm-scene mapping (2 tests).** Cause: commit `2dcaa98` extended the IR encode
ceiling to 340 K per the NOAA ABI spec; tests still pin 320 K → 0. Fix: read the current
encode constants in source; assert the CURRENT ceiling input maps to 0, and additionally
assert the 320 K input maps to its hand-computed value from the current formula constants
(hardcode the literal so future drift fails loudly; show the arithmetic in a comment).

**R2-T3 — BBOXCrop synthetic scan-angle vectors (2 tests).** Cause: the fixtures' x_vec
(−0.10…+0.02 rad) was built under the OLD (wrong) sign convention; the corrected ABI
convention is x increases EASTWARD, so SoCal from GOES-18 (−137°W) projects to x ≈ +0.03…+0.06
— outside the fixture, giving a degenerate crop and (correctly) `_crop_computed = False`.
Production code is CORRECT; only the fixtures change. Fix: run `geo_forward` for the tests'
bbox corners once (throwaway), report the corner values in the closeout, and choose an x_vec
linspace that covers them with room such that the existing assertions (crop_h/crop_w < 500,
> 0) hold — lead's starting suggestion: `np.linspace(-0.02, 0.13, 2500)` (span 0.15 rad →
~16.7k cols/rad → SoCal bbox+margin ≈ 465 cols < 500). Keep y_vec if it already covers the
corners. You may choose the span (mechanical); you may NOT change any assertion. If the
assertions cannot hold with a physically-plausible grid, STOP and report.

**R2-T4 — forward-projection sign test (1 test).** Cause: same convention fix (`0bd6a99`).
Fix: rename to `test_east_of_subsatellite_gives_positive_x`, assert `x > 0`, comment citing
the GOES-R ABI fixed-grid convention (x scan angle increases eastward; e.g. GOES-East CONUS
documented x extent −0.101332…+0.038612 rad — west negative, east positive). Review the whole
`TestForwardProjection` class for sibling tests pinning the old convention that pass only
coincidentally; report anything found, change only what's on the failure list without a
further lead ruling.

**R2-T4b — geo_forward known-answer test (1 NEW test, same file).** Per rules/verification.md
KAT mandate for numerical kernels as they are touched: add a test computing the scan angle for
one known point (e.g. 33.0°N, −117.5°W from GOES-18 at −137°W) with an INDEPENDENT spherical
approximation implemented inside the test (great-circle → scan-angle math, no code shared with
`geo_forward`), asserting agreement within 15% relative tolerance plus matching signs. This
catches sign flips and gross scale errors while tolerating the spherical-vs-ellipsoidal gap.
Declare it a non-falsifiable-vs-pre-change pin (new test, kernel unchanged this round).

**R2-T5 — GMGSI below-threshold transparency (2 tests).** Cause: commit `38fcbfe`
deliberately lowered the cloud threshold, so the fixtures' "below threshold" values now sit
above it (observed alpha 0.34–0.81). Fix: read the current threshold constant in
`tiles/satellite_renderer.py`; move the fixture inputs below the CURRENT threshold; assert
transparency there AND add one input just above the threshold asserting alpha > 0
(hand-computed expected, comment showing arithmetic).

**R2-T6 — Windows memmap-locking artifacts (6 tests: 5× snow eviction + 1× fetcher
carry-forward). NOT stale, NOT production bugs.** Cause: numpy memmap holds an open handle;
Windows cannot `unlink`/`os.replace` a mapped file (verified: `PermissionError WinError 5` at
`store.py:68`; eviction leaves `.dat` in place). Production runtime is Linux-only (Docker).
Fix: `@pytest.mark.skipif(sys.platform == "win32", reason="numpy memmap file locking: Windows
cannot unlink/replace mapped files; production runtime is Linux-only (Docker)")` on exactly
these 6 tests. Do NOT weaken any assertion; do NOT touch source. Linux verification of these
6 is a deploy-phase lead task (tracked below).

### Round-2 prohibitions

- NO source file changes of any kind. If a test cannot be honestly fixed without a source
  change, STOP and report — that would mean the lead's diagnosis is wrong.
- No assertion may be weakened or deleted. Every fixed test pins CURRENT intended behavior
  with hand-computed expected values (arithmetic in comments).
- Do not touch the 22 currently-passing tests in the round-1 files, nor any passing test anywhere.
- Git/container/architectural blocks from round 1 apply unchanged.

### Round-2 verification command

```
.venv\Scripts\python -m pytest tests/test_satellite_goes.py tests/test_satellite_himawari.py tests/test_geostationary.py tests/test_gmgsi_composite_renderer.py tests/test_fetcher.py tests/test_hrrr_grid.py tests/test_hrrr_alaska_grid.py tests/test_icon_eu_grid.py tests/test_dmi_dini_grid.py tests/test_wrf_smn_grid.py -q
```

Expected: 0 failed, 6 skipped (the R2-T6 set, Windows only), everything else passed.
Itemize the 6 skips by name. Lead will additionally run the FULL suite at acceptance
(expected: 0 failed / 6 skipped / ~1107 passed).

### Round-2 deliverable

One commit on local `deploy/shaneburkhardt` (NOT pushed):
`test: repair stale satellite/renderer tests, skip Windows memmap artifacts`
Closeout via SendMessage: per-disposition summary, geo_forward corner values (R2-T3), the
constants read for R2-T2/T5 with the hand arithmetic, sibling-test findings (R2-T4), full
verification transcript, confirmation zero source files and zero passing tests touched.

### Deferred to deploy phase (lead tasks, tracked)

- Linux verification of the 6 R2-T6 tests on the librewxr LXC checkout (post-push).
- Live check per round 1's Post-acceptance section.

## Verification evidence — round close (2026-08-05, lead-run)

- Round 1 (D1/D2/D3 + guards): commits `25d8f96` + `ad22279`. Lead independent pytest:
  6 failed / 22 passed (the 6 = P1 pre-existing, itemized), matching closeout. Allowlist diff
  clean. D1/D2/D3 diffs spot-checked against spec.
- Round 2 (stale-test repair): commit `7ea4674`. Lead independent FULL suite:
  1107 passed / 6 skipped / 0 failed (was 19 failed / 1093 passed). `git diff -- src/` empty.
  10 test files exactly per allowlist. KAT + sign-fix diff spot-checked.
- Blind adversarial audit (agent never shown implementer tests/commits/closeouts):
  - C1 **DISPROVEN** — trim by tuple count could drop a distinct newer timestamp when a
    republished same-ts key consumed a slot (reproduced against real code). ACCEPTED.
  - C2, C3, C4, Phase-2 — COULD-NOT-DISPROVE, with named rule-outs (5-way concurrency,
    exception safety, rename orphan sweep; 60k-point bit-identical fuzz; unskipped
    reproduction of 2/6 Windows artifacts; KAT proven to catch sign flip AND axis swap;
    no weakened assertions).
  - Remediation `60ffa81` (lead-direct, dedupe first-key-per-timestamp before trim + C2
    docstring disclosure + guard test falsified pre-fix on the exact drop scenario).
    Auditor re-ran its own 7 cases unmodified: 7/7 PASS; tie-break proven identical to
    baseline semantics; no new defect. Verdict: COULD-NOT-DISPROVE.
  - Post-remediation full suite: **1108 passed / 6 skipped / 0 failed** at `60ffa81`.
- Doc-code sync: fork CLAUDE.md warmer + ingest lines updated (`9b34775`, pushed).
- Push: `1c16b34..60ffa81` then `..9b34775` to origin (operator authorized in chat).
- Deploy: image `librewxr-bbox:latest` rebuilt from `/opt/librewxr/src` (git-archive of
  `60ffa81`; old tree kept at `/opt/librewxr/src.old` for rollback); `docker compose up -d`
  05:23:34Z; `/health` 200. NOTE: deploy also carries `1c16b34` (alerts event-end filter,
  pushed 2026-07-21 but never image-rebuilt — the running image had been at `2a7acb7`
  since 2026-07-13).
- Linux verification of the 6 Windows-skipped tests on the LXC (throwaway venv, deployed
  tree): **6 passed in 1.05s** — skipif diagnosis proven on the canonical platform.
- Live checks (defect signatures, container logs post-05:23Z):
  - Ingest: GOES-18/19 "ingested 2 new frame(s)" first poll, "1 new frame(s)" next
    (baseline pre-fix same night: 12–23/poll/family, monotonic hourly ramp). FIXED.
  - Cast warnings: zero `invalid value encountered` lines post-restart (was 2/decode). FIXED.
  - Warm coalescing: single "multi-family mode" start for the 05:30 burst; GOES-19's
    trigger 8 s later coalesced (no second concurrent start). First post-restart warm is a
    one-time full-cache rebuild (~10 min, expected — tile cache is in-memory).
  - CPU: lifetime avg 68.8% at 15.5 min uptime INCLUDING initial backfill + first full warm
    (pre-fix same-day: 162–211% steady climb; first incident 795% pinned).

## Parking lot (post-round)

- **P2:** default multi-satellite disk-overlap path (ADR-079) has no direct provider test
  (contribution count for a mid-CONUS bbox). Found in round 2; not added per scope ruling.
- **P3 (pre-existing, inherited from baseline):** on a NOAA same-timestamp republish, the
  lexicographically-smallest (earliest-created) key wins the slot — the store keeps the
  preliminary product over the reprocessed final, indefinitely for that timestamp. Auditor
  confirmed identical at baseline `1c16b34`; not a remediation defect.
- **P4:** the radar stack has no deploy script and no CI — `1c16b34` sat pushed-but-undeployed
  for 2 weeks, and 19 stale test failures accumulated unnoticed across 5+ commits of drift.
  Recommend `scripts/deploy-librewxr.sh` (mirroring this round's manual procedure) if the
  operator wants it.

## Post-acceptance (lead-run, not the implementer's job)

- Lead independently re-runs pytest, diffs commits vs allowlist, spot-checks D1 in the file.
- Blind adversarial auditor (separate agent, never shown the implementer's tests/commits/report)
  attempts to disprove the three claims.
- Push + deploy to the librewxr LXC (container restart) happens ONLY on explicit operator
  authorization — not part of this round's agent work.
- Live check (post-deploy, lead-run): `sudo docker logs librewxr-librewxr-1 --since 30m` →
  "ingested" ≤ 2 per family per poll (was 12–23); exactly one "Satellite warm" completion per
  trigger burst (was two overlapping); zero `RuntimeWarning ... cast` lines (was 2/decode);
  `ps` lifetime %CPU of `python -m librewxr.main` well under 100% after ≥30 min uptime (was ~200%).
