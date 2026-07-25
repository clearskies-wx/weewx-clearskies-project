# Marine Service Separation — Concerns Register

**Opened:** 2026-07-25
**Owner:** Coordinator
**Purpose:** One place for every item the coordinator is concerned about while executing
Phases 5–8 of `MARINE-SERVICE-SEPARATION-PLAN.md`. Non-blocking items are logged and
followed up later. Blocking items carry a recorded decision, its evidence, and the
documents consulted — per the operator's standing instruction not to chase rabbit holes.

**Status key:** OPEN = follow up later, no impact on current work. DECIDED = was blocking,
decision recorded below and work proceeded. CLOSED = resolved, evidence recorded.

---

## C-01 — Plan §0.6 module inventory is incomplete (DECIDED)

**Severity:** Blocking — the moved code does not import without these.

**Finding.** The plan's §0.6 inventory names 29 modules to move. The marine code actually
imports these additional API-internal modules, none of which appear in any phase's task list:

| Module | Lines | Imported by |
|---|---|---|
| `providers/_common/rate_limiter.py` | 83 | 8 marine provider modules |
| `providers/_common/nws_zones.py` | 783 | `nws_marine.py` |
| `providers/_common/datetime_utils.py` | — | marine providers |
| `models/responses.py` | 1,867 | 7 marine modules (marine subset only) |
| `units/conversion.py` | 158 | 3 marine modules |
| `metrics.py` | 174 | 2 marine modules |
| `services/swelltrack_cache.py` | 250 | surf pipeline |
| `services/surf_pipeline_timestep.py` | 297 | surf pipeline |

**Decision (coordinator, 2026-07-25).** Port each of these into the marine service as far as
the moved code requires, taking the marine-relevant subset where the module is shared (e.g.
`models/responses.py` — copy the marine response models, not the whole 1,867-line file).

**Why this is not an architectural change.** No component's responsibility moves. The plan
already rules that the marine service is standalone and owns everything marine
(ADR-099, ARCHITECTURE.md companion-service section); a standalone service that cannot
import its own code is not standalone. Trigger 2 asks whether a module's responsibility
changes — copying a shared utility so the new service is self-contained changes nothing about
what any piece is responsible for. The API keeps its own copies until Phase 6 deletes only the
marine-specific ones.

**Follow-up:** the plan's §0.6 line counts and the "~28,735 lines removed" total will not
match reality. Corrected counts recorded at QC Gate 5.

---

## C-02 — T5.9 understates its own scope by ~4,245 lines (DECIDED)

**Severity:** Blocking — affects how the work is broken down and how long Phase 5 takes.

**Finding.** §0.6 lists the five marine endpoint files (`surf.py` 1,317, `beach_profile.py` 881,
`marine.py` 1,040, `fishing.py` 510, `beach_safety.py` 497 = 4,245 lines) under
**"Delete — marine service serves it."** T5.9 then says, in one line, "implement all 6 data
endpoints with same response shapes." Those two statements describe the same work from
opposite ends: the behaviour in those 4,245 lines has to exist in the marine service before
the API's copies can be deleted in Phase 6.

**Decision (coordinator, 2026-07-25).** Treat T5.9 as an endpoint **port**, not a fresh
implementation. The endpoint logic moves; only the parts that are API-host concerns stay
behind (response envelope, unit conversion, `stationClock`/`freshness` — T6.2 keeps those on
the API, and ARCHITECTURE.md's "Layer Responsibilities" makes the API the single conversion
authority). The marine service serves SI units. T5.9 is split across more than one agent
because of its size.

**Why this is not an architectural change.** It is the plan's own stated intent, written in
two places that only look contradictory. Resolving a contradiction *within one document* by
taking the reading its own acceptance criteria support is explicitly permitted.

---

## C-03 — SURF-PUBLISH-RESULTS-ONLY prerequisite for T5.0 (CLOSED)

T5.0's ⚠ correction requires the publish-results-only round to be **live** before golden
fixtures are captured, or the fixtures freeze behaviour that round deliberately removed.

**Verified live, 2026-07-25, from the weewx host against librewxr:8767:**

```
GET https://192.168.7.22:8767/surf/huntington-city-beach-pier/forecast
http=200 bytes=2692265                       (2.69 MB — was 21.03 MB)
top keys:        ['forecast','hrrr_cycle_time','run_time','spectral','swelltrack','transect']
spectral[0]:     ['clamped','components','handoff_depth_m','handoff_source_level','time']
swelltrack:      dict, 67 entries
```

`swelltrack` present; `energy`, `freqs_hz`, `dirs_deg`, `handoff_by_transect` absent.
Deployed commits: librewxr SWAN service `ca22432`, librewxr API `12f9ddc`, weewx API `12f9ddc`
— all equal to local `HEAD` and to origin. **Prerequisite met. Fixtures may be captured.**

---

## C-04 — Phase 4B tasks T4B.6 / T4B.7 / T4B.8 are unfinished (DECIDED)

**Severity:** Was blocking (the no-deferral rule vs. the operator's instruction to start at
Phase 5).

**Finding.** The plan records T4B.6 (wire distinct per-transect values), T4B.7 (ADR-093
Amendment 3), and T4B.8 (verify against a real swell) as NOT DONE. The operator's instruction
was to execute the remaining phases **starting with Phase 5**.

**Decision (coordinator, 2026-07-25).** Carry all three forward rather than skip them:

- **T4B.6** — its remote-mode call sites are exactly the code Phase 5 moves. Verifying that
  distinct per-transect handoff values survive the move is folded into Phase 5 acceptance, and
  the bundled-mode call sites are checked in the same pass. The task's own ⚠ correction warns
  that the original "5 call sites" criterion would make an agent re-add the deleted recompute
  path; agents are told the corrected criterion, not the original.
- **T4B.7** — a documentation task with no code dependency. Executed inside Phase 5's doc-sync
  commit.
- **T4B.8** — needs a real swell to arrive. The plan already states this is a genuine
  testability gap and ties it to T8.7. Runs at Phase 8 alongside the Surfline comparison.

Nothing is dropped; each has a named landing point.

---

## C-05 — `ocean_data_resolver.py` and `water_level_compositor.py` disposition (DECIDED)

**Finding.** Both are marine-adjacent, both appear in **no** phase task list. Importer census
run by the coordinator, 2026-07-25:

| Module | Lines | Importers |
|---|---|---|
| `services/ocean_data_resolver.py` | 298 | `endpoints/marine.py`, `endpoints/surf.py`, `endpoints/tides.py`, `models/responses.py`, `providers/ocean/erddap_ocean.py`, `services/cache_warmer.py` |
| `services/water_level_compositor.py` | 267 | `endpoints/tides.py` only |

**Decision.** Both move to the marine service. Every importer of either module is itself
something Phase 5 moves or Phase 6 deletes — `erddap_ocean.py` moves in T5.5, the four
endpoints move in T5.9, and `cache_warmer.py`'s marine entries are removed by T6.6. Nothing
non-marine depends on either. They are omissions from §0.6, not a design question.

---

## C-06 — `endpoints/tides.py` exists as its own file (DECIDED)

T6.5's note says "if tides are served by `endpoints/marine.py`, no separate `tides.py`
deletion is needed — verify before deleting." **Verified: it does exist**, 322 lines, with its
own imports (`marine_config`, `water_level_compositor`, `ocean_data_resolver`). Phase 5 ports
its behaviour; Phase 6 deletes it explicitly. Added to both task lists.

---

## C-09 — §0.6's endpoint line counts are understated by ~18% (OPEN)

Measured 2026-07-25 against the actual files, versus what §0.6 claims:

| File | §0.6 says | Actual |
|---|---|---|
| `endpoints/surf.py` | 1,317 | **1,415** |
| `endpoints/beach_profile.py` | 881 | **1,217** |
| `endpoints/marine.py` | 1,040 | 1,039 |
| `endpoints/fishing.py` | 510 | 510 |
| `endpoints/beach_safety.py` | 497 | 497 |
| `endpoints/tides.py` | not listed | **322** |
| **Total** | 4,245 | **5,000** |

The inventory was taken before Phase 4A/4B changed these files. Consequence is scheduling, not
correctness — T5.9 and T6.5 are larger than the plan budgets for. The "~28,735 lines removed
from the API" headline figure is likewise stale. Corrected totals recorded at QC Gate 5 rather
than chased now.

---

## C-07 — 15 pre-existing pytest fixture errors (OPEN)

`config requires 'inner_bbox'` — 15 errors in the API suite, `git blame` dates the line to
`46eb8839` (2026-07-17), before this round. Recorded at T4B.2 close. Not introduced by this
work; must not be counted as a Phase 5 regression, and must not be silently inherited by the
tests that move to the marine service.

---

## C-08 — Energy-closure measurement against a fresh run is still unmeasured (OPEN)

The T4B.2 close carries an explicit open QC item: the energy-closure figure (median 1.626)
was computed from a payload whose components predate the fix, so it cannot validate the fix.
`scripts/verify_partition_duplication.py` must be re-run against a fresh model run; closure
should be ≈1.0. The fix is deployed on librewxr, so a fresh run now exists — this is
measurable and is scheduled into Phase 8 verification.

---
