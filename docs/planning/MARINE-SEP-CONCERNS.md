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
| ~~`providers/_common/datetime_utils.py`~~ | — | ~~marine providers~~ — **wrong, see correction below** |
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

**Correction 2026-07-25 — `datetime_utils.py` does NOT belong on that list.** The row above was
built from a whole-directory import survey. A per-file check by the Round 1 agent across every
marine provider, service, enrichment and config module found **zero** importers. `coops.py`'s
docstring names `to_utc_iso8601_from_offset` only to explain why it does *not* use it (CO-OPS
timestamps are naive-GMT, so it defines its own `_parse_gmt_naive_to_iso8601`) — which is
precisely what fooled the survey. Nothing is ported. Kept visible rather than deleted so the
next reader knows the question was asked and answered.

**Follow-up:** the plan's §0.6 line counts and the "~28,735 lines removed" total will not
match reality. Corrected counts recorded at QC Gate 5.

### C-01a — `nws_zones.py` is ported trimmed, not whole (DECIDED)

Two marine importers, not one: `nws_marine.py` (`get_wfo_for_zone`) and `nws_srf.py`
(`get_cwa`). But `discover_marine_zones()` and its apparatus (~430 of the file's 784 lines) is
called only from `endpoints/setup.py` — wizard-time zone discovery, which stays on the API.
Ported: `get_cwa`, `get_wfo_for_zone` and shared internals (~350 lines). Left behind: the
discovery apparatus, with a module-docstring note recording what was omitted and why, so it
does not read as lost. Grounds: `rules/coding.md` §3, no code without a current caller.

---

## C-20 — DEFECT, FIXED LEAD-DIRECT: the scaffold's `ProviderCapability` lost a field (CLOSED)

Found when the Phase 5 provider move became the first thing to import **real** providers
against the Phase 4 scaffold's `providers/_common/capability.py`. Five failed at import:

```
TypeError: ProviderCapability.__init__() got an unexpected keyword argument 'refresh_interval'
```

The scaffold dropped `refresh_interval` along with the radar-specific fields
(`tile_url_template`, `wms_*`, `caddy_prefix`, `bounds`, `nowcast_available`, `satellite_*`).
Dropping the radar fields was correct — they do not apply to a marine service. Dropping this
one was not: seven moved providers set it (NDBC, CO-OPS, NWS marine, NWS SRF, WaveWatch III,
HRRR, GFS).

**Seven affected, not five — and the two that are hidden matter most.** HRRR and GFS pass in
the local dev environment only because `eccodes` is absent, so they take the `CAPABILITY = None`
branch. On librewxr, where `eccodes` IS installed, both would construct the dataclass and fail.
`mypy` flags them at `hrrr.py:117` and `gfs.py:120` on the branch that runs with eccodes
present. This is a bug the dev environment masks and the model host would not.

**Fixed by restoring the field, not by stripping the kwarg from seven call sites.** The
direction matters. T4.2 states the marine provider pattern is identical to the API's, and the
API's dataclass has this field — so the scaffold diverged from its own stated contract, which
is a defect the coordinator may fix. Stripping `refresh_interval=` would have gone the other
way: removing a field those providers publish into `/capabilities` today, a data-contract
change across the host boundary (trigger 4) and not something to slip into a bulk move.

Commit `03f81db`. Verified by the coordinator: all 10 moved providers import clean;
`pytest tests/ -q` still 52 passed, 2 skipped.

---

## C-25 — alerts must be re-merged API-side too, and are NOT an inventory gap (DECIDED)

The Round 3 endpoint agent found that `endpoints/marine.py`'s `_fetch_active_alerts()` (list and
detail routes) and `endpoints/beach_safety.py`'s alert-filter section both call
`providers/alerts/nws.py`, which is absent from the marine repo. It proposed treating this as
another C-01-class inventory gap and porting the import in anticipation.

**That reading is wrong, and the plan settles it.** Alerts staying in the API is explicit and
unconditional, stated in four places the coordinator checked before answering:

- Plan **T1.1 item 7** — "alerts stay in the API … regardless of whether the marine service is
  installed."
- Plan **QC Gate 1** — "Verify alerts are documented as staying in the API, not moving to the
  marine service."
- Plan **line 885** — "Alerts are a core feature, not a marine extension. **Alerts never move.**"
- **`ARCHITECTURE.md:140`** — "They are never moved to the marine service, regardless of whether
  the marine service is installed or configured. **This is unconditional.**"

So the module is absent **by design**. Porting the import would have created a non-import
blocker no future round could ever clear, because the module is never arriving — a permanent
lie in the code, and superficially indistinguishable from the fishing endpoint's *legitimate*
blocked imports, which point at modules that will exist once C-15 is answered.

**Disposition — same shape as C-24.** The marine service removes the alerts import and the
alert-fetch calls entirely. No stub, no placeholder. The API re-merges alerts into the proxied
response: it owns the unified alert system and produces exactly this data today. **Mandatory
Phase 6 companion-proxy task, alongside C-24.**

**Exactly what Phase 6 must restore — narrower than first assumed.** Traced against the API
source and the marine service's `models/responses.py`:

| Endpoint | Route | Field | Marine service now emits |
|---|---|---|---|
| `marine.py` — `_fetch_active_alerts()` defined 356-382, called once at 625 inside `_location_summary()` | **list** `GET /marine` | `MarineLocationSummary.activeAlerts` | `None` |
| `beach_safety.py` — fetch at 437-450, feeds line 475 | **detail** `GET /beach-safety/{id}` | `assessment["activeAlerts"]` (`list[str]`, non-nullable) | `[]` |

The marine **detail** route is unaffected — `MarineBundle` has no `activeAlerts` field at all, so
it never carried alerts. The beach-safety **list** route never fetched them either. Both changes
are value-only; names, shapes and nullability are unchanged, which is exactly why this needed
writing down rather than trusting a diff to reveal it.

---

## C-24 — station observations are lost from marine responses unless Phase 6 restores them (OPEN → mandatory Phase 6 task)

This is the resolution of C-14, and it is a real quality regression that must not be allowed to
stand silently.

**The trace** (Round 3 endpoint agent, two call sites, same pattern):
`endpoints/marine.py:556` in `_location_summary()` and `:844` in `get_marine_location()`:

```python
if is_station_served(location.id):
    with Session(get_engine()) as station_db:
        station_obs = _get_current_observation(station_db, registry)
    # wind/temp/pressure fields come from the operator's own hardware
else:
    # marine_weather_cache / forecast-provider fallback
```

**Outcome (a): this is API-owned data.** It reads the local weewx archive — which is why the
API co-locates with weewx in the first place (ADR-034). A marine service on librewxr has no
local archive to read. `is_station_served()` itself is a pure distance calculation against
config and ports fine; the DB-reading branch does not.

**Phase 5 disposition: the marine service omits the branch entirely** and always takes the
cache/forecast path. Giving it a database would be trigger 7 and would defeat the co-location
rationale.

**The regression that creates, stated plainly.** For any location within `dedup_radius_km` of
the station, these fields would stop coming from the operator's own instruments and start
coming from a forecast model:

| Route | Fields affected |
|---|---|
| list / card summary (`_location_summary()`) | `windSpeed`, `windDirection`, `airTemp` |
| detail (`get_marine_location()`) | `windSpeed`, `windDirection`, `windGust`, `airTemp`, `pressure` |

Field names, shapes and nullability are unchanged — so this is **not** trigger 4, and nothing
in the response would indicate the downgrade. An operator would see plausible wind at their own
beach, sourced from a model instead of their anemometer, with no signal that anything changed.
That is the "valid response, wrong answer" failure mode this plan exists to remove.

**Mandatory Phase 6 task — the companion proxy is not complete without it.** The API still has
the archive, still has `is_station_served()`, and already merges station data into marine
responses today. Restoring the merge after the proxy keeps the work on the same host, in the
same service, doing the same job — only the module inside the API changes. Restore exactly the
fields in the table above, at exactly those two response shapes.

---

## C-23 — `directional_exposure`'s wire shape is undetermined until T6.4 (OPEN → pin at T6.4)

Found by the coordinator's line-by-line diff of `marine_config.py` against the API's copy —
the one substantive item among 24 otherwise cosmetic hunks.

In the API, `configobj` turns `N:false, NE:false, …` into a **list of `"DIR:bool"` strings**.
In the marine service the config arrives as JSON, where the natural shape is a **dict**
(`{"N": false, "NE": false, …}`). The ported parser now accepts **both**.

That tolerance is defensible — the adaptation cannot work without at least one of the two, and
which one the API actually sends is not yet decided, because **T6.4 (config push) has not been
written.** But it means one of the two branches is currently speculative, and
`rules/coding.md` §3 is against carrying code with no caller.

**Not resolved now — deliberately.** Pinning it requires knowing what T6.4 serialises, and
guessing would just be a second guess to unwind later.

**Action at T6.4:** decide the wire shape once, make the API's push emit exactly that, then
either delete the parser's unused branch or make it the primary. Whichever way it goes, the
config payload's shape is a contract crossing the API↔marine boundary and must be written down
in `API-MANUAL.md` §19.5 rather than left implicit in a parser's tolerance.

**Everything else in the diff was clean:** the `configobj` → `Mapping[str, Any]` change, the
api.conf INI examples rewritten as JSON payload examples, two line wraps, one nested-`if`
combine. No field name, default, nullability or unit changed anywhere.

---

## C-21 — the moved providers still identify themselves as the API to NOAA (OPEN → Phase 5 close)

Found during the T5.1–T5.5 move, correctly reported rather than silently fixed (the agent's
mandate was "rewrite import paths and nothing else", and these are string literals, not
dotted import paths):

- **User-Agent headers** in `ndbc.py`, `coops.py`, `nws_marine.py`, `nws_srf.py`,
  `wavewatch.py`, `erddap_ocean.py` read `weewx-clearskies-api/{version} (...)`. **These go
  out over the wire to NOAA on every request.** NWS asks for a self-identifying User-Agent with
  contact details; after separation the requests come from the marine service, and the header
  should say so.
- **Install-instruction strings** in `hrrr.py` and `gfs.py`'s `RuntimeError` still say
  `pip install 'weewx-clearskies-api[nearshore]'` — wrong package for an operator to be told
  to install.

**Decision: fix at Phase 5 close, in its own commit, not inside a move commit.** Doing it now
would bury a wire-visible behaviour change in a 7,000-line port where no reviewer would see it.
Doing it never leaves the marine service lying to NOAA about who it is. Not architectural —
no contract between our components changes, and the package name in an error message is plainly
a defect once the package is renamed.

---

## C-22 — ERDDAP dataset `rtofs_2d` has been retired upstream (OPEN)

Found by live fetch during the move: `erddap_ocean.py`'s `rtofs_2d`
(`ncepRtofsG2DFore3hrlyProg`) now returns **404 "Currently unknown datasetID"** from ERDDAP.
An upstream rename or retirement, not a defect in our code — and it is **live in production
today**, since the API runs the same module.

Not fixed during the move (faithful-port rule). Needs a replacement dataset id or explicit
removal. Recorded here so it is not mistaken for something Phase 5 broke.

Same category, same module family: `nws_srf.py`'s period-label parser does not recognise
`"THIS AFTERNOON THROUGH SUNDAY"`, seen live in zone CAZ552. It logs a WARNING and skips the
block rather than crashing — graceful, documented, and a real coverage gap.

---

## C-19 — `i18n.py` and `services/almanac.py` are held, not ported (DECIDED)

Two general (non-marine) API modules that moved enrichment code reaches into:

- `i18n.py` — needed by `surf_scorer.py` and `fishing_scorer.py`; drags in `babel`.
- `services/almanac.py` — `solunar.py:47` imports **private** helpers from it
  (`_phase_name_from_angle`, `_station_local_window`, `_to_utc_z`, `get_ts_eph`); drags in
  `skyfield`. On no phase's move list.

**Decision: do not port either during Phase 5's bulk move.** Both are blocked on a dependency
that is already with the operator, and reaching across a module's private surface is a coupling
worth deciding deliberately rather than replicating on autopilot inside a 20,000-line move.
They land in a follow-up round once C-15 resolves; the import lines in the ported files already
point at `weewx_clearskies_marine.*` so that round is mechanical.

`FishingForecast` and `SolunarTimes` (`models/responses.py:1686` and `:1716`) are a different
matter — pure model copies with no dependency — and were authorised into the enrichment agent's
scope, conditional on being self-contained.

**Also settled here:** `marine_config.py` needs **no** `configobj` dependency. It uses the type
only as a hint; every operation is generic dict access. Dropping the import and widening the
hint to `Mapping[str, Any]` is a faithful port that happens to shed a dependency, with zero
change to the parsed config shape.

---

## C-17 — `surf_pipeline_timestep.py` depends on a module the plan deletes (DECIDED)

Raised by the Round 2 physics agent; verified by the coordinator at
`services/surf_pipeline_timestep.py:30-32`, used at lines 228 and 253. It imports
`ComputeServiceError` and `remote_swelltrack` from `services/compute_client.py` — which §0.6
puts on the **delete** list as "client for the broken half-service."

The module implements a remote-vs-in-process cascade: try the compute host, fall back to
computing in-process. **In the marine service there is no remote compute host — the marine
service is the host** — so the remote branch has no meaning there.

**Decision.** Remove it from Round 2's physics set and hand it to Round 3 together with
`providers/nearshore/swan.py`. It is the same question as C-11's orchestration-half /
client-half split, and two modules with one question between them should be decided once, by
whoever is building the run loop, rather than twice by two agents who cannot see each other's
work. Round 2's physics set is therefore **13 modules, not 14**.

---

## C-18 — hardcoded filesystem paths in the moved physics modules (CLOSED — no change needed)

**Resolved 2026-07-25 by checking the model host instead of reasoning about it.** The paths are
not weewx-specific; they are already correct on librewxr, because the model already runs there.

```
$ ssh librewxr 'ls -ld /var/run/weewx-clearskies/swan ...'
drwxr-xr-x 6 ubuntu ubuntu 220 Jul 25 23:20 /var/run/weewx-clearskies/swan
/etc/weewx-clearskies/great_lakes            No such file or directory
/etc/weewx-clearskies/operator_bathymetry    No such file or directory
$ ssh librewxr 'sudo ls /etc/weewx-clearskies/'
api.conf  compute  secrets.env  spot_profiles  swan  swan_bathymetry_L1.json
swan_bathymetry_L2.json  swan_bathymetry_L3_*.json  swan_grid_sizing.json
```

- `/var/run/weewx-clearskies/swan` (`swan_runner.py:2055`, `surfbeat_runner.py:78`) **exists on
  librewxr and is in active use** — owned by `ubuntu`, modified the same day. The SWAN service
  already runs the same code there.
- `/etc/weewx-clearskies/great_lakes` and `/etc/weewx-clearskies/operator_bathymetry`
  (`bathymetry_resolver.py:82`, `:915`) exist on **neither** host. They are optional caches
  created on demand — a SoCal spot needs no Great Lakes bathymetry — so their absence is the
  normal state, not a gap the move creates.

**Decision: change nothing.** Rewriting these into config keys would be trigger 7 (adds config
keys) for zero benefit, and "fix the issue, not the architecture" applies. The agent was right
to flag and not touch them; the answer just turned out to be that there was nothing to fix.
Confirmed separately that the SWAN binary path is config-injected at `swan_runner.py:1659`.

---

## ~~C-18 (original text)~~ — superseded by the block above

Found by the Round 2 physics agent while tracing imports; flagged and deliberately not changed,
which was the right call — these are triggers 5 and 7 (where computation happens, which files
are persisted).

- `services/swan_runner.py:2055` and `services/surfbeat_runner.py:78` — `/var/run/weewx-clearskies/swan`
- `services/bathymetry_resolver.py` — `/etc/weewx-clearskies/great_lakes`,
  `/etc/weewx-clearskies/operator_bathymetry`

These assume the API host's filesystem layout. The marine service runs on librewxr with its own
layout, and T8.5 explicitly removes several of these paths from the weewx host. Round 3 owns
the resolution; the full list with line numbers comes out of the physics agent's closeout.

Confirmed **not** an issue: the SWAN binary location. `swan_runner.py` takes it from
caller-supplied config with no hardcoded path in the module, so T5.6's "SWAN runner can locate
the SWAN binary" criterion survives a pure port unchanged.

---

## C-16 — two ocean providers have no `CAPABILITY` declaration (OPEN → resolve at QC Gate 5)

Raised by the Round 2 provider agent, verified by the coordinator against the API source:

| Module | `CAPABILITY` | `PROVIDER_ID` |
|---|---|---|
| `providers/ocean/ofs.py` | **0** | 1 |
| `providers/ocean/erddap_ocean.py` | **0** | 1 |
| `providers/buoy/ndbc.py` | 1 | 1 |

So it is not a convention the repo simply does not use — `ndbc.py` has one. `PROVIDER-MANUAL`
§14.10/§14.11 describe capabilities these two should declare. Both are reached only through
`services/ocean_data_resolver.py` rather than being dispatch-registered, which is the likely
reason nobody noticed.

**QC Gate 5 checks "every provider has a CAPABILITY" and will flag these two. That is the
correct outcome** — the gate is working.

**Ruling: port faithfully, do not add one during the move.** It is a pre-existing API gap, not
something the move creates, and fixing it inside a 7,000-line port makes it invisible at audit.
More importantly, `CAPABILITY` feeds what the service advertises to the API's `/capabilities`
endpoint — adding one changes the capability surface crossing the host boundary, which is
trigger 4 and belongs to the operator, not the coordinator. Carried to QC Gate 5 as a known
exception, named explicitly rather than absorbed into a pass.

---

## C-13 — §0.6's enrichment section misses three modules (OPEN → folded into T5.9)

Raised by the Round 1 agent, verified by the coordinator against `endpoints/fishing.py:60-62`.
§0.6 lists three enrichment modules to move (`breaker_height`, `surf_scorer`, `wave_transform`).
`endpoints/fishing.py` additionally imports **`enrichment/fishing_scorer.py`**,
**`enrichment/fishing_species.py`** and **`enrichment/solunar.py`**. Same class of omission as
C-01. They move with the fishing endpoint in T5.9; the `FishingForecast` / `SolunarTimes`
response models move with them.

---

## C-14 — `endpoints/marine.py` imports `db/session.py` (OPEN)

`endpoints/marine.py:98` does `from weewx_clearskies_api.db.session import get_engine`. The
marine service has **no database layer** and no access to the weewx archive — the API
co-locates with weewx precisely because it reads that archive locally (ADR-034). Whatever this
engine is used for either (a) stays on the API and the marine service returns SI data the API
merges, or (b) is a genuine coupling that needs an operator decision.

**Not resolved now** — it needs the T5.9 agent to trace the actual call sites first, which is
cheaper than guessing. Flagged here so it is not discovered halfway through the endpoint port.
If it turns out the marine service would need its own DB dependency, that is trigger 7 and
goes to the operator, not to the coordinator.

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

## ⛔ C-15 — BLOCKING, AWAITING OPERATOR: three dependencies the marine service needs

**Status:** escalated to the operator 2026-07-25. Deliberately batched into **one** question
rather than three — the answer is very likely the same for all three, and three separate
escalations is the churn the operator asked to avoid. All other work proceeds.

### The full set

| Dependency | Needed by | Import form | API pins |
|---|---|---|---|
| `prometheus-client` | `services/swan_runner.py:40`, `services/transect_handoff.py:61` | unguarded | `==0.25.0` |
| `scipy` | `services/surf_1d_analytical.py:19` (`ellipj`, `ellipk` — cnoidal wave theory), `enrichment/bathymetry.py:59` (`PchipInterpolator` — the PCHIP profile from T4A.2) | unguarded | `==1.18.0` |
| `shapely` | `services/shelf_boundary.py:20-21` (`Point`, `shape`, `nearest_points` — GSFM shelf-distance polygon query) | unguarded | `>=2.0` |
| `babel` | `enrichment/surf_scorer.py:60` and `enrichment/fishing_scorer.py:76` import `i18n`, which imports `babel.numbers.format_decimal` at `i18n.py:24` | unguarded | `==2.18.0` |
| `pyyaml` | `enrichment/fishing_species.py:49` — loads `data/species.yaml` at import time | unguarded | `>=6.0` |
| `skyfield` | `enrichment/solunar.py:42-44` (`almanac`, `wgs84`, `ecliptic_frame`) | unguarded | `>=1.48` |

All five import sites verified by the coordinator in the source, not taken from an agent
report. All are **unguarded** — no `try/except ImportError` to fall back on. Every one of these
modules is on the Phase 5 move list, so the move cannot route around any of them.

**Not affected, deliberately:** `rasterio` and `coastalmodeling_vdatum` in
`bathymetry_resolver.py` are already `try/except ImportError`-guarded in the source. Preserving
that is a faithful port, not a new dependency ask. Untouched.

**Standing instruction to every agent while this is open:** port the import lines faithfully
and **write no shim, stub, no-op class, or `try/except ImportError` wrapper** where the source
has none. Wrapping an unguarded import to make a module load is the same silent-failure trap as
a metrics shim — and worse for `scipy`, where a missing `PchipInterpolator` would turn into a
beach profile that quietly stops being generated rather than an error anyone sees. A module that
fails loudly at import is the correct, honest state until the operator rules.

**Consequence, tracked:** 5 of the 13 physics modules will not import until this resolves.
Named individually at closeout, never absorbed into a pass.

**Why it is blocking and why the coordinator did not decide it.** Adding a pip dependency is
**trigger 7** on the architectural-change list. Neither the agent nor the coordinator may
approve it. The agent stopped correctly; the coordinator escalated rather than recording a
"lead call."

**The facts, verified by the coordinator independently of the agent's report:**

- `weewx_clearskies_api/metrics.py:23` imports `prometheus_client`.
- `services/swan_runner.py:40` imports `SWAN_CONVERGENCE_FAILURES_TOTAL` and
  `SWAN_LAST_RUN_VALID_FRACTION` from it.
- `services/transect_handoff.py:61` imports `HANDOFF_QB_VIOLATIONS_TOTAL` from it.
- `repos/weewx-clearskies-marine/pyproject.toml` contains **zero** prometheus references.
- The API pins `prometheus-client==0.25.0`.

Both `swan_runner.py` and `transect_handoff.py` are on the Phase 5 move list, so this is
unavoidable — it is not a question the move can route around.

**Options, with costs:**

| Option | Cost |
|---|---|
| **(a) Add `prometheus-client==0.25.0` to the marine service, port the 3 marine metric definitions + `metrics_response()`** | One pure-Python dependency, already vetted and pinned in the sibling repo. Observability behaves identically after the move. |
| (b) No-op shim keeping the symbol names, no dependency | Zero dependency cost, but the metrics silently stop existing. Nothing fails; the numbers just never arrive. This is the exact "valid response, wrong answer" failure mode the plan was written to remove. |
| (c) Strip the metric calls from `swan_runner.py` / `transect_handoff.py` | Honest but it deletes convergence-failure and QB-violation observability from the model host — the host where those failures actually happen. Also edits physics-module call sites during a move that is supposed to be faithful. |

**Coordinator's recommendation: (a).** It is what the API already does; ADR-031 governs
observability for this stack; the plan's own premise is that the marine service has "the same
architectural DNA as the API"; and `prometheus-client` is pure Python with no system libraries,
so it costs nothing at install time. (b) is disqualified on principle — silent loss of signal.
(c) trades a dependency for a blind spot on the one host where SWAN convergence failures occur.

**Not being done while this is open:** `metrics.py` is not written in any form. In particular
no shim — an absent module fails loudly at import, a shim fails silently forever.

---

## C-12 — the beach-profile "unavailable" state is unreachable by request (DECIDED)

**Finding** (raised by the T5.0 agent, independently verified by the coordinator against
`endpoints/beach_profile.py:745`). `GET /api/v1/surf/{id}/profile` takes `location_id` and
`transect_index` only — **there is no time selector**. The handler always picks `closest_time`
internally. So the §3.6 `modelStatus: "unavailable"` branch cannot be triggered by any request,
and with the live system currently answering 67/67 timesteps there is no naturally occurring gap
to capture either.

This is not a contract defect — 404-vs-200 behaves correctly. It is a **testability** gap: the
contract T5.0's correction most wants regression cover for is the one that cannot be captured
live.

**Decision.** `golden_surf_profile_unavailable.json` is built deterministically from
`_unavailable_profile_response()` (API repo `12f9ddc`) wrapped in the real captured envelope,
and is marked in `tests/fixtures/README.md` as synthetic-from-source rather than a live capture,
with a note that it cannot be re-captured live and why. The alternative — shipping without it —
would leave the 200-with-null contract uncovered, which is exactly how a later agent "restores"
the 404 that SURF-PUBLISH-RESULTS-ONLY deliberately removed.

**Follow-up for Phase 5's audit:** T5.9's port must preserve the unavailable branch. Note that
the marine service's own model-host profile endpoint *does* take `?time=` (per
`SURF-PUBLISH-RESULTS-ONLY.md` §3.2), so on that side the state IS reachable and can be tested
for real. The manifest-facing endpoint keeps the no-time signature.

---

## C-10 — after T6.6 deletes `providers/nearshore/`, who reports model gaps? (OPEN)

T5.9's correction requires `POST /report/gap` on the marine service so every model gap lands in
the model's own log. The **client** for it lives today in the API at
`providers/nearshore/swan.py` (`report_gap()`, `_gap_report_worker()`, line 1277+) — a file
**T6.6 deletes**. The generic companion proxy (T6.1) is the natural owner of the replacement
client, but no task assigns it.

**Impact:** none on Phase 5. Must be resolved inside Phase 6 or the gap reporter POSTs into a
void — and because it is deliberately fire-and-forget, that failure would be silent. Folded
into the T6.1 brief when Phase 6 is dispatched.

---

## C-11 — the marine service does not carry SWAN's remote-mode client half (DECIDED)

**Finding.** `providers/nearshore/swan.py` (2,307 lines) is two things in one file: model
**orchestration** (`run_all_spots`, `_run_all_spots_locked`, `run_quick_update`, bathymetry
download, obstacle building) and a **remote-mode client** that talks to a model host over HTTP
(`configure_remote_mode`, `_remote_health_loop`, `is_remote_mode`, `fetch_profile`,
`report_gap`). The marine service **is** the model host, so the client half has no meaning there.

**Decision.** The marine service carries the orchestration half only. The API keeps its whole
copy until Phase 6 deletes it, so nothing is lost at any point, and the generic companion proxy
replaces the client half (see C-10).

**Why this is not an architectural change.** §0.6's own disposition row for this file reads
"SWAN orchestration (**rewritten as internal pipeline in marine service**)" — the split is the
plan's stated design, not an inference from a stale document, and ARCHITECTURE.md independently
describes the marine service as the model host. No responsibility moves: the marine service
runs the model, which is what the orchestration half does.

**Related structural finding, recorded so Phase 5 does not rediscover it.** The existing
standalone SWAN service (`weewx-clearskies-swan-swelltrack`, 710 lines in `service.py`) is a
thin wrapper that imports the physics from the installed `weewx_clearskies_api` package — its
systemd unit runs `python -m weewx_clearskies_swan` out of the **API's** virtualenv. Its
`_swan_runner_loop()`, its `/surf/{spot_id}/profile` handler, and its `/report/gap` handler are
the closest working reference for what the marine service's run loop and model-host endpoints
must do. T5.9 ports from there as well as from the API — it is not a fresh design.

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
