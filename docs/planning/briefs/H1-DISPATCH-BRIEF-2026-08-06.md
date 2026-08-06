# H-1 DISPATCH BRIEF — handoff-collapse instrumentation (SURF-PHYSICS-REMODEL-PLAN task H-1)

Drafted 2026-08-06 by the coordinator while M-0 cycles accumulate. Dispatch AFTER the D-1b dev
commit lands (repo serialization). Deploy AFTER M-0 closes (plan: "No other task's deploy or
reality gate may run before M-0 closes"). Approved scope: plan H-1 items 1–3 + register ruling 8
(D-4). Item 4 (the fix) is a SEPARATE later dispatch once instrumented cycles pin the trigger.

## Round identity
H-1, 2026-08-06, lead = coordinator (Opus), dev = Sonnet (clearskies-api-dev profile), tests =
Sonnet test-author, auditor = separate blind Sonnet at the H-1 gate. Repo:
`repos/weewx-clearskies-marine`, HEAD to be re-pinned at dispatch pre-flight.

## Count correction (lead-verified 2026-08-06 at d74c578)
The plan says "three silent exit points in swan_runner.py:908-1011". There are FOUR
(YQ-1 concurs; lead re-read the code directly):
1. `:909-910` — `hs_this_hour is None` → `continue` — cause slug `no_hs_proxy`
2. `:957-976` — `HandoffBreakingError` → `continue` (TRACE-only today) — `breaking_zone_exhausted`
3. `:978-979` — `selection.station_index is None` → `continue` — `no_station_selected`
4. `:1010-1011` — `curve_idx is None` → `continue` — `no_curve_match`
All four are instrumented. Same approved scope (the plan's own language is "an unlogged
early-exit among … candidate `continue` points"); count noted for the gate record.

## Design (coordinator-ruled, to file and line)

### 1. Cause collection — `services/swan_runner.py`
- `_select_l3_handoff_position_and_spectrum()` (def :715, per-timestep loop :904-1011) gains an
  optional mutable out-param `exit_causes_out: dict[str, str] | None = None` (time_iso →
  cause-slug). Each of the four exits above records its slug before `continue`. No behavior
  change otherwise; return value unchanged.
- Caller loop (:6102-6178): pass a fresh dict per transect; accumulate into
  `_h1_missing: dict[str, dict[str, int]]` (time_iso → cause-slug → transect count).
- After the carrier build (:6200-6215), for each time in the union of carrier times AND of
  `_h1_missing` keys: `affected = n_transects − len(_tb for that hour)` (n_transects =
  `len(_spot_transects)`). If affected > 0 → ONE WARNING per hour (never per transect):
  `"H-1 handoff-collapse: spot %r @ %s — %d/%d transect(s) have no per-transect handoff entry
  this hour (silent-exit causes: %s)"` with the per-cause counts dict. (Log-volume pattern per
  the BD precedent at :895-898 — aggregate, never per-(transect,hour).)

### 2. Health flag — authoritative counter at the PIPELINE site
- `services/surf_1d_pipeline.py` `_run_pipeline_per_transect()` (:1513-1597): count the
  `if not parts:` bulk-fallback branch (:1577) per call (one call = one timestep). This is the
  authoritative bulk-fallback ground truth — it catches BOTH mechanism (A) (entry present,
  `components=[]`) and mechanism (B) (entry absent) collapses.
- New module design constants (top of surf_1d_pipeline.py, near existing constants; documented
  as DESIGN CONSTANTS reviewed at the H-1 gate, NOT admin config):
  `_H1_BULK_FALLBACK_MIN_COUNT = 8`, `_H1_BULK_FALLBACK_MIN_FRACTION = 0.25`.
  Flag fires when `fallback_count >= max(_H1_BULK_FALLBACK_MIN_COUNT,
  ceil(_H1_BULK_FALLBACK_MIN_FRACTION * n_transects))`.
  Rationale for gate review: observed collapse events are 154–162/162 (95–100%); healthy hours
  are 0–2; 25%-with-floor-8 has wide margin both directions and stays meaningful at the
  32-transect beach_profile spot config (flag at 8).
- Recording is gated to the PRECOMPUTE path only (new keyword-only param
  `record_health_flag: bool = False`, set True only at the SWAN-cycle precompute call sites in
  `providers/nearshore/swan.py` — locate via the `_precompute_swelltrack_for_spot` chain).
  Request-time on-demand pipeline runs must NOT write cycle state.

### 3. State registry — `state.py`
New registry, rebuild-per-cycle shape (same pattern as `_l3_viability_failures` :166/:213-240):
- `_bulk_fallback_hours: dict[str, dict]` keyed `f"{spot_id}@{time_iso}"` →
  `{"count": int, "n_transects": int, "recorded_at": iso}`.
- `record_bulk_fallback_hour(spot_id, time_iso, count, n_transects)`,
  `reset_bulk_fallback_state()`, `get_bulk_fallback_state()`.
- `reset_bulk_fallback_state()` is called once at the start of each cycle's per-spot publish
  pass in `providers/nearshore/swan.py` `_run_all_spots_locked()` AND the quick-update
  equivalent (`_run_quick_update_locked`) — so a clean cycle clears stale flags, mirroring the
  registry's documented rebuild-per-pass semantics.

### 4. Health surfacing — `endpoints/health.py`
After the `facing_divergences` block (:207-211), BEFORE `h1_reason_count = len(reasons)` (:212)
so the flag floors status at `degraded` and stays visible in every non-ok status:
- ≤3 flagged hours → one reason each:
  `f"bulk_fallback: {key} {count}/{n_transects} transects"`.
- >3 flagged hours → single summary reason naming total flagged-hour count and the worst hour.

### 5. Boundary-refusal distinct naming (plan item 3) — `providers/nearshore/swan.py`
Today `:2656-2723` catches `except Exception` and records slug `ww3_boundary_failed` for BOTH a
network failure and a D-3 `BoundaryNotViableError` refusal. Add a NARROWER except clause first:
`except BoundaryNotViableError as exc:` → `state.record_no_publish("ww3_boundary_refused",
f"D-3 refusal — {exc}")` + the same ERROR log shape + `record_input(..., available=False)` +
re-raise. The generic handler stays as-is. Import `BoundaryNotViableError` from
`services.ww3_station_selection` (as `grid_sizing_chain.py:126` already does). This is the
"add the reason string only if missing" case — the refusal is currently NOT distinctly named.

### Tests (test-author, separate commit, same round)
- Forced-collapse: `_run_pipeline_per_transect` fed a timestep where every transect has empty
  parts (with `record_health_flag=True`) → registry entry present, count == n_transects;
  below-threshold case → no entry.
- Four exit-path tests on `_select_l3_handoff_position_and_spectrum` — force each exit
  independently (fixtures per cause), assert `exit_causes_out` records the right slug and the
  entry is absent from the return. (These mirror the H-1 adversarial brief.)
- health.py: flagged registry → reason string present, status floors at degraded; empty → absent.
- Boundary refusal: `BoundaryNotViableError` raised → no_publish slug `ww3_boundary_refused`;
  generic exception → `ww3_boundary_failed`.
- Stale-test sweep: grep tests/ for pins on `ww3_boundary_failed` covering the refusal case —
  update in the SAME commit if any pin the old conflated slug (list each in closeout).

### Docs (SAME commit as the dev code commit — doc-delta table rows)
- `docs/ARCHITECTURE.md` — marine handoff model callout: add H-1 instrumentation + health flag
  (one short bullet under the ⚓ MARINE HANDOFF MODEL block).
- `docs/manuals/PROVIDER-MANUAL.md` — bulk-fallback semantics, the new WARNING class text, the
  four cause slugs, flag meaning + threshold constants.
- `docs/manuals/OPERATIONS-MANUAL.md` — new health reasons (`bulk_fallback: …`,
  `no-publish: ww3_boundary_refused …`), what firing means, what to check.
- `docs/decisions/ADR-103-spectral-boundary.md` — REWRITE (docs-author, own commit, catch-up
  doc for already-shipped behavior): documents the boundary design that ACTUALLY exists
  (multi-station BOUNDSPEC VARIABLE FILE, station selection criterion, refuse-don't-degrade
  per D-3, the new distinct refusal slug) — NOT the struck three-tier design.

## Scope
IN: the five file surfaces above + tests + the three doc files.
OUT / NAMED TRAPS: do NOT touch the four exits' control flow (they still `continue`); do NOT
add a fallback of any kind (D-3: refuse stands, no tiers); do NOT fix whatever the collapse
trigger turns out to be (item 4 = later dispatch, returns to operator if architectural); do NOT
touch `_select_l3_handoff_position_and_spectrum`'s selection logic, BD-1/BD-2 constraint logic,
or `refine_handoff_with_qb`; do NOT touch swan-commands-extract.md (FROZEN); no config keys —
thresholds are module constants; do NOT run the full test suite (targeted files only); no edits
on librewxr.

## Live check (post-deploy, after M-0 closes)
- `curl -sk https://127.0.0.1:8780/health` → parses; on a clean cycle NO `bulk_fallback` reason.
- Journal over one full cycle: zero `H-1 handoff-collapse` WARNINGs on a clean cycle, or each
  collapsed hour has exactly one WARNING naming causes; expected n_transects = 162.
- Accept (plan): forced-collapse test fires the flag; instrumentation visible on real cycles;
  across 4 consecutive healthy cycles every bulk-fallback hour is accounted for by a logged cause.

## Adversarial brief (gate row 3, from the plan)
"Prove an hour can still collapse to bulk-fallback without the new flag firing; force each of
the exit paths independently; prove a boundary refusal can pass unnamed in /health."
