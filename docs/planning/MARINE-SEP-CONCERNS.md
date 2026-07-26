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

## C-27 — DISSOLVED BY OPERATOR RULING: solunar leaves the marine service entirely (DECIDED)

**Ruling (operator, in chat, 2026-07-25).** Solunar is not a marine function. The API already
computes it — `endpoints/almanac.py:904` serves `GET /almanac/solunar`, backed by
`enrichment/solunar.py` and `services/almanac.py`, using the station timezone and elevation the
API already owns. There must not be two implementations of the same computation, and there must
not be a second call for it.

So the question below — *where does the marine service get station timezone and elevation?* — was
the wrong question. The answer is that the marine service never needed them, because it should
never have been computing solunar. The three options weighed below are all moot; the config push
carries neither field.

**Executed in Phase 6:** the marine service deletes its ported `solunar.py` and `almanac.py`
copies and drops `skyfield`; `endpoints/fishing.py` stops calling `compute_almanac()`; the API
recomposes the solunar fields into the proxied fishing response using the machinery it already
has. **Coordinator error recorded honestly:** this was escalated to the operator when it should
have been answered by reading the manuals, which document API ownership of almanac and solunar.

### Original finding, kept for the trace

**Superseded.** Found by the Round 3 endpoint agent:

Found by the Round 3 endpoint agent; **not previously flagged by anyone.**

`endpoints/fishing.py` calls `compute_almanac(station_tz=…, alt_m=…)` to build sunrise/sunset
day boundaries for solunar periods. In the API those come from `services/station.py`'s
`get_station_info()` — weewx-host configuration. **The marine service has no equivalent:
`MarineLocation` carries no timezone and no elevation field.**

The agent used the function's own literal defaults (`station_tz="UTC"`, `alt_m=0.0`) with an
inline comment rather than inventing a value — the right call. But `compute_almanac()`'s own
docstring says defaulting to UTC is "wrong for EDT/PDT etc.", so **day boundaries will be wrong
for every operator outside UTC** once C-19 unblocks the module.

**This one cannot be fixed by an API-side re-merge, unlike C-24 and C-25.** Those restore a
*field* after the fact. This feeds a *computation* inside the marine service — the day boundary
determines which solunar periods are generated at all, so there is nothing to merge back.

| Option | Cost |
|---|---|
| **(a) The config push carries station timezone and elevation** | Adds config keys — trigger 7. But the push payload is being defined at T6.4 anyway (see C-23), so it is the natural place to settle it, and the API already has both values. |
| (b) Marine service derives the timezone from the location's lat/lon | A new dependency (trigger 7) and a new failure mode, to re-derive something the API already knows. |
| (c) Leave it at UTC | Silently wrong sunrise/sunset day boundaries for every non-UTC operator. Not recommended. |

Coordinator's recommendation: **(a)**, decided together with C-23 when T6.4 defines the config
payload, so the payload's shape is settled once rather than twice.

---

## C-26 — DECIDED BY OPERATOR RULING: thresholds are canonical, never display-unit (DECIDED)

**Ruling (operator, in chat, 2026-07-25).** Everything works in canonical units regardless of the
operator's display preference, and the API converts to whatever the operator asked for. A
threshold table calibrated in a display unit is wrong by design — the question is not *which
unit should we compare in*, it is *why does a `_FT` constant exist at all*. This is doctrine
already written down in `ARCHITECTURE.md` §Layer Responsibilities (the API is the single
conversion authority) and `API-MANUAL.md:1332`, which names this exact class of defect.

**Executed in Phase 6, and broader than this one site.** `_SURGE_THRESHOLDS_FT` becomes canonical
metre constants derived by exact conversion, so no classification criterion changes. The same
sweep covers `beach_safety.py`'s `_COMFORT_*_MIN_F` water-comfort thresholds and
`fishing_scorer.score_fishing()`'s Fahrenheit species profiles — both of which existed only to be
fed by a `_convert_unit()` call inside a service that is supposed to emit SI. Those conversion
calls disappear rather than being redirected. After the sweep the marine service contains zero
display-unit conversions; the only permitted calls into `units/conversion.py` are provider ingest
normalisations from an upstream unit into SI.

**Coordinator error recorded honestly:** escalated as a units question when the doctrine already
answered it, and the audit's related finding (C-32) was passed along as a "spot-check" instead of
being recognised as the same defect class.

### Original finding, kept for the trace

**Superseded — the fix is canonical constants, not a better-placed conversion.**

**Status:** escalated to the operator 2026-07-25. Not blocking Phase 5 — the port inherits the
bug faithfully, which is correct. But it needs a decision before Phase 8 deploys.

**The defect**, verified by the coordinator in `services/water_level_compositor.py`:

```python
_SURGE_THRESHOLDS_FT = {"minor": 0.15, "moderate": 0.5, "major": 1.0}   # line 37
...
residual_ft = _meters_to_target(current_residual_m, target_unit)        # line 101
result["stormSurgeLevel"] = _classify_surge(abs(residual_ft), residual_ft)  # line 111
...
def _classify_surge(abs_residual_ft: float, signed_residual_ft: float) -> str | None:  # line 260
    if abs_residual_ft < _SURGE_THRESHOLDS_FT["minor"]: ...
```

`residual_ft` is named for feet but holds **whatever `target_unit` is**. Nothing checks the
unit. In metre mode the classifier under-triggers by a factor of 3.28 — the correct metre
thresholds would be ≈0.046 / 0.152 / 0.305 m. A 0.20 m residual returns `"elevated"` when it
should be `"significant"`.

**Phase 5 escalates this from a preset-specific bug to a universal one.** Today it affects only
METRIC/METRICWX installations, because imperial presets pass `target_unit="foot"` and land on
the right numbers by luck. **`stormSurgeLevel` is a label, not a number** — it is computed once
and the API's unit conversion does not touch strings. Since the marine service always works in
SI, after separation **every** installation gets the metre-mode classification, including the
imperial ones that are correct today.

**Why the port must inherit it rather than dodge it:** the ported `tides.py` has to call
`compute_composite(target_unit="meter")`. Passing `"foot"` to sidestep the bug would leak a
display unit into canonical output and get double-converted by T6.2. Inheriting faithfully is
the correct behaviour for the move.

**Why neither the agent nor the coordinator fixed it.** The values in `_SURGE_THRESHOLDS_FT` are
a classification criterion in a physical model — trigger 1. There is a reasonable argument that
correcting the comparison is a pure defect fix: it changes no threshold value and only makes the
code do what its own variable names say. **That argument is exactly the reasoning that has gone
wrong on this project before**, and it is not the coordinator's call to make unilaterally.

**Options:**

| Option | Effect |
|---|---|
| **(a) Convert the residual to feet before classifying** | Thresholds keep their declared values and meaning; the comparison happens in the units the constants are named for. Fixes metric installs today and prevents the universal regression. Smallest change. |
| (b) Add metre thresholds and select on `target_unit` | Same outcome, more surface; two threshold tables to keep in step. |
| (c) Leave it | Every installation gets under-triggered storm-surge labels after Phase 5. Not recommended. |

Coordinator's recommendation: **(a)**, in its own commit, applied to **both** repos (the API's
copy is live today), with a test pinning a metre-mode residual to the correct label.

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

**The surf endpoint hits the same seam — third endpoint, same branch.** Named by the Round 3b
agent for the t=0 wind lookup in `surf.py`:

| Route | Field | Effect |
|---|---|---|
| surf detail/list, **t=0 entry only** | `forecast[].windSource` | reports `"forecast_provider"` where it should report `"station"` |
| surf detail/list, **t=0 entry only** | `forecast[0].windQuality`, `forecast[0].scoring.organizationWind`, and every wind-derived field inside `score_surf()`'s output | computed from `marine_weather_cache` instead of station hardware |

Entries at t>0 are unaffected — those always used HRRR, never station hardware, in the API
source too.

**Mandatory Phase 6 task — the companion proxy is not complete without it.** The API still has
the archive, still has `is_station_served()`, and already merges station data into marine
responses today. Restoring the merge after the proxy keeps the work on the same host, in the
same service, doing the same job — only the module inside the API changes. Restore exactly the
fields in the tables above, at exactly those response shapes.

**Note the harder sub-case:** `windSource` is a *provenance* field. Restoring the wind value
without restoring `windSource` would leave the response asserting the wrong origin for a correct
number — and restoring `windSource` alone would assert station provenance for a forecast value.
They must be restored together, and the wind-derived scoring fields recomputed, not patched.

---

## C-29 — `conditionsText` bakes units into a string the API cannot convert (OPEN → T6.2)

Found by the Round 3b agent while porting `surf.py`, and it is a genuine hole in the layer
split rather than a porting artefact.

The API converts **numbers**. `conditionsText` is a human-readable sentence composed inside
`score_surf()` with the unit values already interpolated into it. The marine service now calls
`score_surf(height_unit="meter", wind_unit="meter_per_second")` — correct for SI output — so the
sentence comes out in metres and metres per second, and **there is nothing the API's unit
conversion can do about it.** An imperial operator would see converted numbers everywhere and a
metric sentence.

Same family as C-26: the layer split converts numeric fields cleanly, and silently fails to
reach anything expressed as a **string** — a label, a sentence, a headline.

### DECIDED 2026-07-25 — operator directed this be fixed. Composition moves to the API.

**Units are only half the problem, and the other half settles the design.** Reading
`_compose_conditions_text()` (`enrichment/surf_scorer.py:482-534`) and its call site at `:729`:

```python
wave_part = i18n.t("surf.conditions.wave_summary", locale).format(
    range=_format_range(height_low, height_high, locale),
    unit=height_unit_label,
    period=i18n.format_number(period_s, 0, locale),
    compass=compass,
)
```

The sentence depends on **three** presentation inputs: the operator's display **units**, the
operator's **locale**, and locale-aware **number formatting**. The marine service has none of
them. It has no locale config either — `i18n.get_active_locale()` reads API-side operator
configuration. So composing this text on the model host was never going to be right; it would
have produced English metric sentences for a French imperial operator.

The same applies to the sibling label fields resolved through `i18n.t()` in the same function:
`quality` (`surf.quality.{stars}`) and `windQuality` (`surf.wind_quality.{key}`), and to
`fishing_scorer.py`'s equivalents.

**Decision: presentation is the API's job — all three axes of it.** `ARCHITECTURE.md`'s "Layer
Responsibilities" already makes the API the single unit-conversion authority; locale resolution
and text composition belong in the same layer for the same reason. The marine service emits
**semantic keys and SI numbers**; the API resolves keys to localised labels, converts the
numbers, and composes the sentence.

Concretely:

- Marine service returns the *ingredients* — SI height, period, direction, SI wind speed, the
  wind-quality **key**, the quality **key**, and the swell-dominance score.
- The API composes `conditionsText` and resolves `quality` / `windQuality` after conversion, in
  the operator's locale. `_compose_conditions_text()` moves there essentially unchanged — it
  already takes display values and unit labels as parameters, so it needs no rework, only
  relocation.
- The dashboard's response is **byte-identical** to today. Nothing user-visible changes; the
  work simply happens where the inputs exist.

**Consequence worth noting:** this removes the marine service's reason to carry `i18n` and
`babel` at all, unless something else needs them. Check at implementation time rather than
assuming.

### Sweep done by the coordinator, 2026-07-25 — the surface is exactly two files

Grepped `i18n.t(` / `i18n.format_number` / `get_active_locale` across all six moved endpoint
modules and the moved enrichment modules. **The six endpoint files contain zero i18n usage.**
Everything localised is produced inside two scorers:

| File | Produces |
|---|---|
| `enrichment/surf_scorer.py` | `conditionsText` (composed from height + unit label + period + compass + wind label + wind range + swell summary), the `quality` label (`surf.quality.{stars}`), the `windQuality` label (`surf.wind_quality.{key}`), and the `surf.conditions.unavailable` string |
| `enrichment/fishing_scorer.py` | `conditionsText`, the species-status label (`fishing.species_status.{key}`), and the period label (`fishing.period.{key}`) |

Also inside `surf_scorer.py`: two `i18n.format_number()` calls, which are locale-aware number
formatting and move with the rest.

**That bounds the fix tightly.** Both scorers return semantic keys and SI numbers; the API
resolves the keys and composes the sentences after conversion. No endpoint module changes shape
beyond passing the keys through. The `_compose_conditions_text()` helper relocates unchanged.

---

## C-28 — the tides port drops a duplicate CO-OPS fetch (OPEN → auditor must confirm)

The Round 3 endpoint agent reports that `endpoints/tides.py` in the API makes **two identical
CO-OPS calls**: one for display-unit values and a second for the compositor's raw-metre values.
Since the marine service never converts, its port makes **one** call serving both.

The reasoning is sound and the saving is real — one fewer round trip to CO-OPS per request. But
this is the only place in Phase 5 where a port deliberately changed the number of upstream calls
rather than only rewriting imports, so it should not pass on reasoning alone.

**Explicitly assigned to the Phase 5 adversarial audit:** confirm that the single fetch returns
the same data both former call sites consumed, and that no caller depended on the second call's
separate cache entry or its timing. If it does not hold, it is a defect introduced by the move —
the one candidate this phase has.

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

## C-15 — CLOSED. It should never have been raised at all.

**Closed 2026-07-25.** The operator approved the dependencies and Round 4 landed them (`5695f0a`):
`[nearshore]` gained scipy 1.18.0, shapely >=2.0, prometheus-client 0.25.0; core gained babel
2.18.0, pyyaml >=6.0, skyfield >=1.48. All 25 previously-blocked modules import; all 15 routes
register; nothing is stubbed or shimmed.

### The coordinator was wrong to raise this, and the reason matters

**Operator ruling, 2026-07-25:** these modules were named in the plan's Phase 5 move list. Moving a
module moves the module — including the imports it has always had. A dependency that travels with
code the plan explicitly directs you to move is **not a new dependency**; it is the same dependency
at its new address. Trigger 7 covers *adding* a dependency to a service — deciding it needs
something it did not need before. It does not cover carrying an existing one along with the code
that requires it.

Treating it as trigger 7 produced the worst of both worlds: eight modules sat unimportable, three
routers went unregistered, and the operator was asked to authorise something the plan had already
authorised by naming the files. **The escalation itself was the defect.**

The registered "escalate and wait, do not self-approve" decision below is preserved as the record of
a wrong call, not as guidance. Do not use it as precedent.

### Original text, superseded — kept only for the trace

**~~BLOCKING, AWAITING OPERATOR~~:** three dependencies the marine service needs

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

**Consequence, tracked:** 8 modules will not import until this resolves (5 physics on `metrics`
/`scipy`, `surf_scorer` and `fishing_scorer` on `babel` via `i18n`, `solunar` on `skyfield`),
plus `endpoints/fishing.py`, `endpoints/surf.py` and `endpoints/beach_profile.py` downstream.
Named individually at closeout, never absorbed into a pass.

### Coordinator's registered decision while this stays unanswered (2026-07-25)

The operator's standing instruction for this round is that a blocking item should be resolved by
consulting the documentation, the plan and the briefs, with the decision registered here. The
documents do point one way: plan **T4.5** already says the `[nearshore]` extra "adds
SWAN-specific dependencies", and `scipy` and `shapely` are exactly that; **ADR-031** governs
observability for this stack; and `ARCHITECTURE.md` describes the marine service as carrying the
same provider-module pattern as the API.

**The coordinator is nonetheless NOT self-approving these, and that is deliberate.** Adding a
dependency is trigger 7, the standing architectural block says the coordinator has no authority
to approve one either, and "a governing document says so" is one of the two excuses that rule
names explicitly as insufficient. Reading T4.5 as pre-authorisation would be precisely that
excuse. The decision registered here is therefore: **escalate and wait, do not self-approve.**

**What proceeds meanwhile, so nothing idles behind it:** every module is ported faithfully with
its real imports; the run loop, the endpoints and the router wiring are complete; Phase 6's
companion proxy and Phase 7's wizard work are independent of this and can run in full. What
cannot proceed is executing the pipeline end-to-end, and any claim that Phase 5 has closed.

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

---

## C-30 — the marine manifest omits all five list routes (DECIDED)

Found by the coordinator opening Phase 6, comparing `endpoints/manifest.py`'s `_ENDPOINTS`
against the routes the API actually serves today.

The API exposes **eleven** marine routes: `/surf`, `/surf/{id}`, `/surf/{id}/profile`,
`/marine`, `/marine/{id}`, `/tides`, `/tides/{id}`, `/fishing`, `/fishing/{id}`,
`/beach-safety`, `/beach-safety/{id}`. The marine service **registers** all eleven (Round 4
route table). Its `/manifest` advertises **six** — every detail route plus the profile, and
**not one list route**.

The proxy mounts what the manifest advertises. T6.5 then deletes the API's copies. So after
Phase 6 the five list routes would 404 — the endpoints that populate every marine card on the
dashboard. Nothing would report an error; the routes would simply cease to exist.

**Decision: complete `_ENDPOINTS` with the five list entries.** Not architectural — the routes
already exist and already serve; the manifest is an inventory of them that was written in Phase 4
before the endpoints were ported, and has been stale since Round 4 registered them. No
responsibility moves and no shape changes. TTLs mirror each family's detail entry.

**Rule for the future, worth stating once:** the manifest is the *only* channel by which a route
reaches the dashboard after Phase 6. A route registered on the marine service but absent from the
manifest is invisible. Any later route addition must land in both places in the same commit.

---

## C-31 — the marine dispatch registry still contains only the Phase 4 scaffold stub (OPEN → Phase 6 remediation)

Phase 5 adversarial audit finding F1. Not previously tracked by anyone.

`providers/_common/dispatch.py`'s `MARINE_PROVIDER_MODULES` contains exactly one entry at
Phase 5 close: `{("_scaffold", "stub"): _stub}`. **None** of the ten real ported providers
(ndbc, coops, nws_marine, nws_srf, wavewatch, hrrr, gfs, ofs, erddap_ocean, swan) was ever
registered.

Three documents say this should already have happened:

- `providers/_stub.py` line 1 — "Scaffold-only stub provider — **DELETED in Phase 5**… this
  module and its dispatch registry entry are deleted in the same Phase 5 change that starts
  moving real provider modules in."
- `dispatch.py`'s own docstring — same claim, and it lists the ten providers that should
  replace the stub.
- `PROVIDER-MANUAL.md:2253` (§15.2) — "The marine service maintains its own
  `MARINE_PROVIDER_MODULES` dispatch registry… populated at import time exactly as the API's
  registry is." It is not populated.

**Not live-breaking today**, which is why nothing caught it: the endpoints import provider
modules directly and nothing calls `get_provider_module()`. QC Gate 5's "all providers load"
check exercises direct imports, so it passes without touching the registry.

**Disposition: remediate in Phase 6, before QC Gate 6.** Register the ten real providers,
delete `_stub.py` and its entry. Not architectural — this is code diverging from its own
stated contract in three places, which the standing block explicitly permits fixing. The
alternative (documenting the registry as deferred) is worse: it leaves a scaffold placeholder
registered as a provider in a service about to be deployed.

---

## C-32 — audit finding F2: the two `_convert_unit()` calls are internal, not a layer-split leak (CLOSED)

Phase 5 audit flagged `endpoints/fishing.py:304` and `endpoints/beach_safety.py:314` as
possible SI-only violations and asked the coordinator to trace where the Fahrenheit value goes.
Traced 2026-07-25:

- `fishing.py` — `water_temp_f` is passed only to `score_fishing(water_temp_f=…)` at `:401`.
  Fahrenheit is that function's own input contract; the species temperature profiles are
  authored in °F.
- `beach_safety.py` — `water_temp_f` is passed only to `classify_water_comfort()` at `:318`,
  whose thresholds (`_COMFORT_*_MIN_F`) are Fahrenheit constants.
- **Neither value reaches a response.** Both endpoints emit `"waterTemp": water_temp_c` —
  Celsius — at `beach_safety.py:284` and `:350`, byte-identical to the API original's `:375`
  and `:467`.

No leak, no deviation from the source. The layer split holds. F2 closed with no change.

---

## C-33 — API-MANUAL §19.7 documents a 60-second marine health poll that no task implements (OPEN → Phase 8)

Flagged by the T6.1 agent rather than guessed at, which was correct.

`API-MANUAL.md` §19.7 describes the API polling `GET {marine_service_url}/health` every 60 seconds.
T6.1's Do list contains no such poll — it specifies a manifest fetch at startup, a 5-minute manifest
refresh, and a 5-minute retry when the service was unreachable at startup. Nothing polls health.

Same shape as the Phase 4 audit's F5 (a documented mechanism belonging to no task). Two possible
resolutions and the choice is not the coordinator's: implement the poll (adds a cadence — trigger 6)
or correct the manual to describe the manifest-refresh cadence that actually exists. **Not chased
now.** Carried to Phase 8, where deployment will show whether anything actually depends on a health
signal separate from the manifest refresh.

---

## C-34 — the T6.1 proxy uses sync handlers with a blocking HTTP client (CLOSED — correct as built)

Recorded because it looks wrong at a glance and will be re-raised otherwise.

The proxy's route handlers are `def`, not `async def`, because `_fetch_upstream()` uses a blocking
`httpx.Client`. That pairing is correct: FastAPI runs sync handlers in a threadpool, so a blocking
call inside one costs a worker thread. An `async def` handler making a blocking call would stall the
event loop for every in-flight request for the duration of the marine round trip. The agent found
this itself and fixed it in `335daa9` before reporting. Matches the API's existing convention —
`ARCHITECTURE.md` records the API as using sync handlers throughout.

---

## C-35 — the manifest's `capabilities` shape differs between the manual and the code (OPEN → T6.3 close)

Found by the T6.2/T6.3 agent while implementing capability merging.

`API-MANUAL.md` §19.1's example manifest shows `capabilities` as a list of **objects**
(`{id, displayName, requiresConfig}`). The marine service's implemented
`endpoints/manifest.py` returns a flat **`list[str]`** — and the plan's own example manifest
(line 2328) agrees with the code: `"capabilities": ["surf", "tides", "marine_weather",
"fishing", "beach_safety"]`.

So the manual is the outlier, and two of three sources agree on the string list. The agent is
implementing against the real shape and flagging rather than changing either side, which is
right — the manifest's shape is a contract crossing the host boundary (trigger 4) and is not
an implementer's call.

**Disposition: correct the manual at T6.3 close**, not the code. Two sources against one, and
the API's `/capabilities` response already has its own richer `CapabilityDeclaration` type for
display metadata — the manifest does not need to carry it. If a later phase wants display
names in the manifest, that is a contract change and goes to the operator.

---

## C-36 — API-MANUAL §19.3's envelope example does not match the API's actual envelope (DECIDED — manual corrected)

Third instance today of an illustrative JSON block in a manual disagreeing with the code it
illustrates. Found by the T6.2 agent, surfaced rather than silently diverged from.

§19.3 showed each converted field wrapped as `{"value": 4.6, "label": "ft", "formatted": "4.6"}`
inside `data`. The API's actual envelope — `units/response_conversion.py:8-9`, implemented at
`:153` (Shape 2) and `:203` (Shape 2b) — puts **raw scalars** in `data` and a flat
`{fieldName: label}` block in a top-level `units` key. That is what `/current`, `/archive`,
`/forecast` and the marine endpoints being replaced all emit today, and what the dashboard
consumes.

**Decision: the implementation is right, the example was wrong, the manual is corrected.**
Adopting the example's shape would have introduced a new response shape on exactly the routes
being migrated — a data-contract change across the dashboard boundary (trigger 4) arrived at by
following an illustration. The dashboard's marine cards would have broken at Phase 8 with no
change on their side to explain it.

**Pattern worth naming, now that it has happened three times in one phase** (C-35 manifest
`capabilities`, `OPERATIONS-MANUAL`'s config-recovery text, and this): when a manual's example
JSON conflicts with the implementation plus a second corroborating source, the example is the
outlier and gets corrected. An example is not a contract. The contract is the code plus whatever
the plan and the other manuals independently agree on.

---

## C-37 — `currentResidual` is a second C-29: a baked unit string AND an unconvertible value (OPEN → re-merge round)

Found by the coordinator following up the T6.2 agent's flag that it could not verify
`currentResidual`'s shape. Read at `services/water_level_compositor.py:115-126`:

```python
result["currentResidual"] = {
    "value": round(residual_display, 2),
    "quality": residual_quality,
    "source": "coops_observed",
    "description": f"{sign}{residual_display:.2f} {_unit_label(target_unit)} vs prediction",
}
```

Two defects, both of the family this phase exists to remove:

1. **`value` is a bare key with no unit group**, so the proxy's converter leaves it alone. The
   marine service emits metres; an imperial operator gets a metre number sitting beside converted
   feet everywhere else in the same response, with nothing marking it.
2. **`description` bakes the unit into a sentence** — `"+0.23 meter vs prediction"` — which the
   API's numeric conversion cannot reach. Identical in kind to C-29's `conditionsText`.

**C-29's sweep missed it**, and the reason is worth recording: that sweep grepped for `i18n.t(` /
`i18n.format_number` / `get_active_locale`. This string is a plain f-string with no i18n at all, so
it did not match. **The C-29 rule is therefore broader than the C-29 sweep**: any *string* composed
from a numeric value behind the API is unconvertible, whether or not it goes through i18n.

**Disposition: fold into the C-24/C-25/C-29 re-merge round.** The marine service returns the
ingredients (`valueM`, `quality`, `source`); the API converts and composes. Also re-run the sweep
for f-string and `%`-format composition of numeric values across the marine service, not just i18n
calls.

---

## C-38 — the proxy converts `assessment.waterTemp`, which the live API leaves raw (OPEN → Phase 8 verification)

Reported by the T6.2 agent rather than silently absorbed, which was right.

The new proxy converter is route-agnostic: it converts a field by name wherever that name appears.
`endpoints/beach_safety.py:467` in the **live** API leaves `assessment.waterTemp` unconverted today,
while converting the same-named field elsewhere. So after Phase 6 that field starts arriving in the
operator's display units where today it arrives raw.

This is a **behaviour change that fixes a live bug**, not a regression — but it is still a change,
and it is exactly the kind that surfaces as "the beach-safety card now reads 64 where it read 18."
A route-agnostic proxy genuinely cannot special-case one route's field to stay broken.

**Disposition: keep the conversion, verify at Phase 8** against the dashboard's beach-safety card
to confirm nothing downstream hardcodes the raw value. Named here so it is not mistaken for a
proxy defect when someone notices the number move.

---

## C-39 — `i18n.py`, `locales/` and the `babel` pin are now unreferenced in the marine service (DECIDED → deletion round)

Consequence of C-29's marine half (`cc2be6a`), anticipated in C-29's own text and now measured.

After the scorers stopped composing text, **zero modules in the marine service import
`weewx_clearskies_marine.i18n` or `babel`** — verified by grep plus a cold import of both scorers,
which previously failed on the babel-blocked i18n import. `i18n.py` and `locales/` remain in the
tree with no caller, and `babel` remains pinned in `pyproject.toml`.

`rules/coding.md` §3 is against carrying code with no caller. But **removing a dependency is
trigger 7 in plain terms**, and having just been corrected for over-triggering on C-15, the
coordinator is not going to under-trigger in the opposite direction on the same day by deleting a
pinned dependency unasked.

**Decision (operator, 2026-07-25): remove it in the deletion round**, alongside T6.5-T6.8. Delete
`weewx_clearskies_marine/i18n.py`, the marine service's `locales/` directory, and the `babel` pin in
`pyproject.toml`.

**Precondition, and it is not optional:** the API's own locale catalogue must be confirmed to contain
every key the marine service now emits — `surf.quality.*`, `surf.wind_quality.*`, `surf.conditions.*`,
`fishing.period.*`, `fishing.species_status.*` — **before** the marine copy is deleted. A key that
resolves on one side and not the other renders a literal key string into the response instead of a
sentence: a failure that looks like data rather than like an error. That check is assigned to the
API-side re-merge agent and its result gates this deletion.

**Note for whoever executes it:** the API keeps its own `i18n.py` and locale catalogue, which is
where the keys now resolve. The marine service's copy is the redundant one. Confirm the API's
catalogue contains every key the marine service emits *before* deleting the marine copy — that check
is assigned to the API-side re-merge agent.

---

## C-40 — T6.7 deletes the marine config schema that T6.4/T6.4b require (DECIDED — schema stays in the API)

**Severity:** would have broken the API at import. Caught by the deletion agent at its halt condition
rather than by a failing import after the fact.

**The contradiction, inside one phase.** T6.7 lists `config/marine_config.py` for deletion. T6.4 and
T6.4b — landed hours earlier in the same phase — require the API to validate, serve and push marine
config. `endpoints/setup.py` (4,827 lines, on no deletion list) imports `MarineConfig`,
`load_marine_config` and the `_VALID_*` vocabulary constants and uses them in four places: the
apply-time `MarineSurfSpotApplyConfig` validator, `_run_marine_apply_chain()`, `current_config()`,
and the `marine_compute_estimate()` endpoint. Deleting the module breaks `import
weewx_clearskies_api.app` outright.

**Decision (coordinator, 2026-07-25): the schema stays in the API.** Resolving a contradiction
between two statements in one plan by taking the reading its own acceptance criteria support is
explicitly permitted, and the criteria are unambiguous here:

- T6.4b's acceptance criterion is `GET /setup/marine/config` returning the marine config subset.
  You cannot serve what you cannot model.
- The API owns the wizard. **Phase 7 is titled "Wizard/Admin Updates"** and is entirely about marine
  configuration in the config UI.
- ADR-099 — cited by T6.4b itself — makes the API the single source of truth for operator config.

**The distinction Phase 6 is actually drawing:** the API sheds marine **computation**, not the marine
**config schema**. Operator configuration is API territory; wave physics is not. §0.6's inventory
lumped the two together because it was built by listing files with "marine" in the path.

**What is deleted from `setup.py`:** only `_run_marine_apply_chain()`'s obstacle-structure building,
grid sizing and bathymetry/CUDEM prep — the parts calling physics modules T6.7 removes. **Gated on
confirming the marine service does the equivalent on config receipt** (C-11 records it carrying
SWAN's orchestration half including bathymetry download and obstacle building). If it does not, the
deletion stops: removing a responsibility with no new home is the silent-loss failure mode this plan
exists to prevent.

### QC Gate 6 — named exception

The gate's grep lists `marine_config` among terms that must return zero matches in the API. It will
now legitimately match `config/marine_config.py` and `endpoints/setup.py`. **This is an expected,
named exception, not a gate failure** — same handling as C-16 received at QC Gate 5. The gate's
intent is zero marine *physics* in the API; the term list was written before anyone noticed the
config schema had to stay. Exact remaining hits are recorded at the gate walk.

---

## C-41 — DECIDED BY OPERATOR: the grid-sizing chain is a marine function and moves (DECIDED)

**Ruling (operator, 2026-07-25):** *"There is NO REASON that SWAN should be depending upon the API for
this — is this not purely an internal SWAN function?"* It is. The chain's inputs are the operator's
surf-spot configuration; its outputs (`swan_grid_sizing.json`, `spot_profiles/{id}.json`) are read by
exactly one consumer, SWAN. Nothing else in the API touches them.

It sat in the API only for historical reasons: SWAN used to run **inside** the API, so "at apply time"
and "in the API" were the same place. T4A.3 moved it from SWAN runtime to apply time — that changed
*when* it runs, not *whose job* it is. The coordinator escalated this as an open architectural
question when the ownership was never actually in doubt.

**Executed:** the marine service runs the grid-sizing and bathymetry chain **on config receipt**
(`POST /config`) — the post-separation equivalent of the apply-time trigger, and a trigger that
already exists. Every module it needs (`swan.py`, `swan_domain.py`, `bathymetry.py`) moved in Phase 5;
only the wiring was missing, and the marine service's `endpoints/config.py` still described itself as
a "Phase 4 scaffold". The API's copies are deleted with the rest of the wave physics, unblocking the
held cluster, `compute_client.py`, the `surf_compute_*` keys and the `[nearshore]` extra.

**To verify during implementation:** the chain needs the operator-confirmed coastal structures (the
Overpass discovery results) as an input. Those are operator configuration and belong in the config
push payload — confirm they are in it and extend the payload if not.

### Original escalation, superseded

**~~AWAITING OPERATOR~~:** the apply-time grid-sizing chain belongs to no task

Found by the deletion agent at its second halt condition, after being told to verify before cutting.
Verified independently by the coordinator.

**What the chain is.** `endpoints/setup.py`'s `_run_marine_apply_chain()` runs at `POST /setup/apply`
as a `BackgroundTasks` job: sizes L1 from GSFM shelf data, downloads COARSE bathymetry, finds the
30 m contour, sizes L2, downloads MEDIUM, finds the 15 m contour, sizes L3 (trigger + viability
test), downloads FINE per cluster, extracts the native transect and PCHIP-interpolates it. It writes
`/etc/weewx-clearskies/swan_grid_sizing.json` and `spot_profiles/{spot_id}.json`.

**It is not dead code, and the failure mode if deleted is silent.** The marine service's
`load_grid_sizing_cache()` reads that file and has **no fallback** — on a miss it logs ERROR and
returns `None`, with "SWAN cannot run without it. Run /setup/apply to generate it." Deleting the
producer removes SWAN's ability to run at all, surfacing only as a runtime ERROR pointing back at an
endpoint that no longer does anything.

**The two statements that disagree:**

| Source | Says |
|---|---|
| `ARCHITECTURE.md:100` "(target — pending ADR-099)" | SWAN moves entirely into the marine service; **"the API contains zero SWAN code in the target architecture."** → the chain moves. |
| The marine service's own `load_grid_sizing_cache()` docstring, written in Phase 5 | Names the API's `_run_marine_apply_chain()` as the producer, and duplicates the path constant "because the two live in different repos post-separation." → the chain stays. |

No task in any phase moves it. A requirement belonging to no task — the same shape as the Phase 4
audit's F5, which became T6.4b.

**The fact that decides it, and the reason this cannot be deferred to Phase 8.** The chain works today
only because the API is *also* deployed on librewxr, so the file it writes is on the same filesystem
as the SWAN runtime that reads it. **T8.5 removes the librewxr API.** After that, a cache written by
the weewx-host API is on the wrong host entirely. The current arrangement is not merely untidy
post-separation — it stops working.

**Options:**

| Option | Cost |
|---|---|
| **(a) The chain moves to the marine service, triggered on config receipt (`POST /config`)** | All three modules it needs (`swan.py`, `swan_domain.py`, `bathymetry.py`) are **already in the marine repo** from Phase 5 — only the wiring is missing, and the marine service's `endpoints/config.py` still describes itself as a "Phase 4 scaffold". Adds a trigger (trigger 6) and moves where a computation happens (trigger 5). Matches ARCHITECTURE's stated target. |
| (b) The chain stays in the API and ships its artifacts inside the config-push payload | Keeps CUDEM download and SWAN grid sizing in the API — contradicts "zero SWAN code in the API", and the `[nearshore]` extra and its dependencies must stay in the API permanently. |
| (c) Leave as-is | Works only while the API is deployed on librewxr. T8.5 breaks it. Not viable. |

Coordinator's recommendation: **(a)**. The code is already where it needs to be; what is missing is
one trigger. Held pending the operator: `providers/nearshore/swan.py`, `services/swan_domain.py`,
`enrichment/bathymetry.py`, `_run_marine_apply_chain()`, and the `[nearshore]` pip extra are all
excluded from the Phase 6 deletion until this resolves.

---

## C-42 — DECIDED BY OPERATOR: the API proxies wizard discovery to the marine service (DECIDED)

**Ruling (operator, 2026-07-25):** *"The wizard never communicates with the marine service at all. The
only thing communicating with the marine service is the API. If the wizard needs something from the
marine service it communicates through the API. You need to build a pass-through in the API for these
types of queries."*

So neither option the coordinator offered was right. The wizard keeps calling the API exactly as it
does today — no dashboard change. The API stops **importing** marine provider modules and instead
**proxies** the query to the marine service, which owns the marine data.

**Executed:**
- The marine service exposes discovery endpoints for the four questions the wizard asks: nearby NDBC
  buoy stations, nearby CO-OPS tide stations, the covering OFS model, and GRIB availability.
- The API's existing wizard endpoints keep their paths and response shapes and are re-implemented as
  pass-throughs.
- `providers/{buoy,tides,marine,ocean}/` are then deleted from the API along with `wind/`.

**Consequence to handle honestly:** wizard discovery now requires a reachable marine service. When it
is unreachable the wizard must say so plainly — not return an empty station list, which reads as
"there are no buoys near you" and is the exact "valid response, wrong answer" failure this plan
exists to remove.

### Original escalation, superseded

**~~AWAITING OPERATOR~~:** the wizard's discovery helpers import four marine provider modules

Found by the deletion agent while wiring T6.6's registry removal. Same shape as C-40 and C-41 —
a third place where "everything marine moves" meets "the API owns the wizard."

`endpoints/setup.py` imports from four of T6.6's five non-nearshore provider directories,
independent of the apply chain:

| Import | Used for |
|---|---|
| `providers.ocean.ofs.find_ofs_model` | wizard OFS-model lookup (`:1104`, `:4217`, `:4220`) |
| `providers.buoy.ndbc.discover_stations` | "nearby buoy stations" wizard helper (`:3302`, `:4234`) |
| `providers.tides.coops.discover_stations` | "nearby tide stations" wizard helper (`:3302`, `:4250`) |
| `providers.marine.grib_processor` | GRIB-availability check for a wizard error message (`~:3102-3119`) |

Only `providers/wind/` is free of setup.py imports and is being deleted this round.

**Why this is not simply C-40 again.** C-40 was about a config *schema* — plainly operator
configuration, plainly the API's. These are provider modules that call NOAA endpoints. They sit
exactly on the line: the *question they answer* is a configuration question ("which stations are near
this location?"), but the *way they answer it* is marine provider code, which the plan's headline
says the API contains none of.

**Two readings, and they resolve the same way C-41 does:**

- Wizard-time discovery is operator configuration → the four modules stay in the API, and the plan's
  "zero marine provider modules" criterion gains a named exception for discovery helpers.
- The API contains no marine provider code → the wizard asks the marine service, which needs
  discovery endpoints it does not have (trigger 7), and Phase 7 gains that work.

**Bundled with C-41 deliberately** rather than escalated separately. Both are the same question —
*does wizard-time marine support code live in the API or behind the marine service?* — and answering
them together avoids settling one in a way that contradicts the other. Held out of the Phase 6
deletion meanwhile: `providers/buoy/`, `providers/tides/`, `providers/marine/`, `providers/ocean/`
and their dispatch registry rows.

---

## C-43 — `surf.conditions.unavailable` is untranslated in 12 of 13 locales (OPEN → i18n round, not Phase 6)

Found by the deletion agent running C-39's all-locales precondition. Verified by the coordinator.

`surf.conditions.unavailable` ("Surf forecast unavailable — model data incomplete.") exists in
`en.json` and is **absent from all 12 other locale files** — de, es, fil, fr, it, ja, nl, pt-BR,
pt-PT, ru, zh-CN, zh-TW. The other 49 marine-emitted keys are present in all 13.

**Pre-existing, and not caused by anything in this separation.** The marine service's locale files are
a byte-level copy of the API's: a flattened key-set diff of `fr.json` shows **zero** keys present in
the marine copy and missing from the API's. The gap is identical on both sides and predates Phase 5.

**Consequence for C-39: none.** The precondition on that deletion existed to prevent losing
translations that lived only in the marine copy. There are none. C-39 proceeds.

**Consequence for operators: a non-English operator whose model has no result for an hour sees an
English sentence** (or the raw key, depending on the i18n fallback) where every other string on the
card is localised. Small, real, and cheap to fix — one string, twelve files.

**Disposition: an i18n round, not Phase 6.** Recorded so it is not lost now that the check that found
it has been satisfied and will not run again.

---

## C-44 — `totalWaterLevelForecast[].residual` reaches the dashboard in raw metres (OPEN → fix with the audit batch)

Phase 6 audit finding, HIGH. A **new** instance of the C-37 defect class, found by looking for it
rather than by it being reported.

`services/water_level_compositor.py` emits `totalWaterLevelForecast[].residual` in canonical metres —
correct, that is what C-26's fix made it do. But nothing converts it on the way out:

- `marine_response_conversion.py`'s `_FIELD_GROUPS` has no `residual` key, so the generic walker
  passes it through.
- `marine_enrichment.py`'s `_walk_current_residual` only fires on dicts carrying `valueM` + `quality`
  — the standalone `currentResidual` object. It never visits `totalWaterLevelForecast` entries.

So `residual` sits in raw metres **inside the same object as** `height`, which is correctly converted
to the operator's display unit. An imperial operator gets feet and metres side by side in one array
entry, with nothing marking which is which.

**Why the earlier passes missed it:** C-37 was found by chasing `currentResidual`'s baked unit string,
and the fix was scoped to that object. The forecast array carries a second residual under a different
key and never came up. Both the T6.2 field inventory and the C-37 fix were reasoning about the fields
they were looking at, not sweeping for the dimension.

**Fix (with the audit's finding batch): add `residual` to `_FIELD_GROUPS` as `group_water_level`,
path-anchored** to `totalWaterLevelForecast` so a same-named field elsewhere cannot be converted
against the wrong group. Verify no other array entry in any marine response carries a bare
physical-dimension key the walker does not know.

**Standing lesson:** the converter's field table is an allow-list, and a field absent from it fails
**silently and plausibly**. Every response array needs checking against the table, not just the
top-level objects someone happened to trace.

---

## C-45 — dependency audit results: two fixed, two carried (CLOSED for Phase 6)

Full AST-based import audit of the marine service (every `Import`/`ImportFrom` node in every module,
diffed against `pyproject.toml`) run after `defusedxml` was found missing by accident. 20 third-party
imports found; 16 already correctly declared.

**Fixed in `430532a`:**

| Package | Where | Why it mattered |
|---|---|---|
| `defusedxml==0.7.1` | `providers/buoy/ndbc.py:104`, unconditional, unguarded | **A clean install could not import the NDBC provider at all.** Never caught because the marine service has never been installed clean. Pin copied from the API. |
| `coastalmodeling-vdatum>=0.1` | `services/bathymetry_resolver.py:504`, guarded | Never fatal — falls back to the VDatum REST API. But undeclared meant every `[nearshore]` install silently took the REST path instead of the offline-first datum conversion. |

**Carried, not fixed — undeclared in *both* repos, so there is no pin to copy and no evidence the
port caused it:**

- **`rasterio`** — `services/bathymetry_resolver.py:55-56`, guarded; Great Lakes DEM path only,
  degrades with a log line. The module's own comment already says "NOT currently in dependencies
  (added separately)". Pre-existing in the API too. Someone must decide whether the Great Lakes path
  is supported; until then it is honestly optional.
- **`pygrib`** — guarded fallback behind `eccodes`, which is declared and is the working primary.
  Reads as optional by design, not a gap.

**Also confirmed clean:** `starlette` is imported directly and declared nowhere, in both repos —
relied on transitively through `fastapi`'s pin. Existing convention, left alone. And no core-path
module imports a `[nearshore]`-only package at module level: `endpoints/surf.py` and
`beach_profile.py` both import `providers.nearshore.swan` lazily inside functions, so `create_app()`
never requires the heavy extras at startup even though both routers register unconditionally.

---

## C-46 — `MARINE_PROVIDER_MODULES` is populated but has no consumer (OPEN → Phase 7/8)

Adjacent finding from the same audit, correctly flagged rather than acted on.

C-31 populated the marine dispatch registry with the ten real providers and deleted the scaffold stub,
because three documents said Phase 5 would do exactly that. **But the registry still has zero
importers** — nothing calls `get_provider_module()`. The endpoints import provider modules directly.

So `rules/coding.md` §3 ("no code without a current caller") is unsatisfied in the other direction
now: the registry is correct, documented in `PROVIDER-MANUAL` §15.2, and unused.

**Not chased now.** The likely consumer is the manifest's `compute_capabilities()`, which currently
derives capabilities from pushed config rather than from the provider registry — the API's own
`/capabilities` works from its registry. Wiring that is Phase 7/8 work, not a Phase 6 deletion
question. Recorded so the next round finds it rather than rediscovering it.

---

## C-47 — DECIDED BY OPERATOR: the marine service queries the API for data the API owns (DECIDED)

**Ruling (operator, 2026-07-25):** if the marine service needs station wind, or solunar, **it queries
the API** — like any other Clear Skies service. This resolves C-24's surf t=0 question and the
fishing/solunar coupling in one line, and both were escalated when they should not have been.

**This is the other half of the add-on invariant, and the coordinator kept missing it.**
`ARCHITECTURE.md`'s invariant says every component reaches the marine service *through the API*. That
is about traffic **inbound** to the marine service. **Outbound** is the mirror image: the API owns
station data, almanac and solunar, so the marine service asks the API for them. The API is the hub in
both directions. Nothing else was ever needed.

The channel already exists — `CLEARSKIES_MARINE_API_URL` plus `MARINE_SERVICE_SECRET`, built at
T6.4b for config recovery.

### What this settles

**Surf wind at t=0 (was C-24's open fork).** The marine service fetches the current station
observation from the API and scores with it. `score_surf()` stays in one place, runs once, with the
right inputs; `windSource` reports `"station"` truthfully because the value genuinely is the
station's. Both rejected options — recomputing API-side (duplicating the scoring formula across two
services) and patching only the wind fields (a self-contradictory response) — existed only because
the coordinator never considered that the marine service could simply ask.

**Fishing solunar (was C-27 / the C-41-adjacent coupling).** `score_fishing()` consumes solunar
intensity, the major/minor period flags and almanac sunrise/sunset — 31.25% of `overallScore`. The
marine service fetches those from the API's existing `/almanac/solunar` and almanac data rather than
computing them. Its ported `enrichment/solunar.py` and `services/almanac.py` are deleted and
`skyfield` dropped, which is what the operator directed earlier today; the coupling that appeared to
block it was never a blocker, only a missing call.

**Station timezone and elevation (C-27's original question) stay dissolved.** The marine service does
not need them, because it no longer computes anything that requires them.

### Required behaviour

Unreachable API means **no answer, stated as such** — never a silently substituted default. A UTC
fallback for sunrise/sunset, or forecast wind quietly labelled `"station"`, is precisely the
"valid response, wrong answer" failure this plan exists to remove.

---

## C-48 — two more wizard endpoints compute marine physics in the API (OPEN → Phase 7)

Surfaced by the deletion agent, correctly not resolved unilaterally. Same class as C-42, but not
covered by its four pinned imports, so it stopped rather than extending its own mandate.

| Endpoint | Imports | Purpose |
|---|---|---|
| `GET /setup/marine/compute-estimate` | `services/swan_domain.compute_domains` | wizard's before/after compute-cost display |
| `GET /setup/marine/coverage` | `services/bathymetry_resolver.find_best_dem` / `is_great_lake` | wizard's bathymetry-coverage panel |

These are why `swan_domain.py`, `shelf_boundary.py`, `bathymetry_resolver.py` and
`enrichment/bathymetry.py` survive in the API after Phase 6 — they are the last four marine-physics
modules left, and only these two wizard endpoints hold them.

**No new decision is needed; the pattern is settled.** `ARCHITECTURE.md`'s invariant and the C-42
ruling both say it: the wizard asks the API, the API proxies to the marine service. Both endpoints
become pass-throughs, the marine service exposes the two computations (it already has every module),
and the four modules leave the API.

**Deliberately routed to Phase 7, not squeezed into Phase 6.** Phase 7 is the wizard phase; these are
wizard endpoints; and the marine side needs two new endpoints, which is real work rather than a
deletion. Recorded here as named Phase 7 tasks so the modules are not mistaken for a Phase 6 miss.

**Live bug found in passing, pre-existing:** `marine_compute_estimate` calls `get_settings()` without
importing it — a `NameError` at runtime, confirmed present before this round via `git show`. The
endpoint cannot currently work. Fix it when the endpoint is reworked.

---

## C-49 — leftovers from the compute-service removal (OPEN → Phase 7/8)

Two loose ends the deletion agent named rather than cutting, both correct to leave.

- **`POST /setup/providers/test-compute` is orphaned.** It tested connectivity using
  `surf_compute_host`/secret, which T6.8 removed from `ApplyRequest` and `CurrentConfigResponse`.
  The endpoint still exists but the wizard has no field left to populate it. Removing an endpoint is
  trigger 7 and was not in the agent's mandate. **Phase 7** — the wizard's marine connection test
  should target `marine_service_url` instead, which T7 covers anyway.
- **The `[marine]` pyproject extra is partly orphaned.** `eccodes` now has zero importers in the API;
  `xarray` and `netCDF4` are still needed by the retained `bathymetry_resolver.py`. So the extra
  cannot be dropped wholesale, and `eccodes` alone can be pruned — but only after C-48 removes
  `bathymetry_resolver.py`, at which point the whole extra may go. **Sequence it after C-48**, not
  before, or the pruning has to be done twice.

---

## C-50 — a docstring asserted the opposite of the code and caused a live double-conversion (CLOSED)

Found and fixed inside the C-44 sweep (`ee25fdb`), and worth recording as a pattern rather than an
incident.

`marine_enrichment.py`'s docstring stated that `conditionsTextParts.heightM` was **outside**
`marine_response_conversion.py`'s `_FIELD_GROUPS` and therefore arrived unconverted, so the module
converted it itself. `heightM` **is** in the table (`group_wave_height`). The value arrived already
converted to display units and was converted a second time — so an imperial operator's surf sentence
carried a wave height wrong by a factor of 3.28, while every number around it was right.

`API-MANUAL.md` repeated the same false claim, because the manual was written from the docstring.

**The pattern:** a comment asserting what another module does is a claim that is never checked by
anything. Three separate readers — the implementer, the auditor, and the manual — trusted this one.
It survived because the sentence it corrupted is prose, so no schema, type or test could contradict
it, and it looked plausible in every review. **Trust the measured behaviour, not the comment**, and
prefer asserting cross-module facts in code (or not at all) over asserting them in prose.

---

## C-51 — `is_station_served()` always returns False, so the station-wind restoration is dead in practice (OPEN → close in Phase 6)

Found by the C-47 agent after wiring the t=0 station-wind fetch exactly as instructed, and flagged
rather than papered over.

`services/marine_location_resolver.py`'s `is_station_served()` reads distances populated by
`resolve_station_distances()`. **Nothing in the marine service ever calls
`resolve_station_distances()`**, and `MarineConfig` carries no `station_lat` / `station_lon` to call
it with. So `is_station_served()` returns `False` for every location, and the new station-wind branch
in `surf.py` — and the equivalent restoration path generally — never executes.

The wiring is correct against the interface; the interface is simply never initialised. This is the
last piece of C-24 and without it the whole station-observation restoration is a branch that cannot
run: dead code by `rules/coding.md` §3, and a silently missing feature rather than a visible failure.

**Disposition: close it inside Phase 6.** Shipping a phase whose headline restoration is unreachable
is worse than the extra hour. Two small halves:

1. **API** — the config push payload gains the station's latitude and longitude. They are operator
   configuration and the API already holds them (`services/station.py`). Same serializer as T6.4, so
   push and pull cannot drift.
2. **Marine** — `MarineConfig` parses them, and `resolve_station_distances()` is called at config
   load with the station coordinates and the configured `dedup_radius_km`.

**This is not C-27 returning.** C-27 asked for station *timezone and elevation* to feed a solunar
computation that has since left the marine service entirely. This is station *coordinates* to answer
a pure distance question — "is this location close enough to the station that the operator's own
instruments are the better source?" — which is exactly what `is_station_served()` exists to decide
and cannot decide without them.

**Also noted, not fixed:** `surf.py` has a separate, pre-existing time-of-day almanac need that
remains unwired. It could reuse the same solunar fetch in a later round. Left alone deliberately —
outside C-47's two authorised fetches.

---

## C-52 — Test Connection cannot validate the shared secret against `/health` alone (DECIDED)

Found by the coordinator while pinning the T7.3 contract at Phase 7 dispatch.

T7.3 specifies the wizard's Test Connection as `POST /setup/providers/test-marine` →
`GET {marine_service_url}/health`. But `/health` is one of exactly two auth-exempt routes on the
marine service (`auth.py:12-15`; the other is `/manifest`). So the probe the plan names proves
reachability and nothing about `MARINE_SERVICE_SECRET`. The endpoint it replaces
(`/setup/providers/test-compute`) **did** send its secret and did validate it — so following T7.3
literally would be a quiet downgrade in what the button tells the operator, and a wrong secret
would pass the test and then fail on the first real request.

**Decision (coordinator, 2026-07-25): keep `/health` as the primary probe exactly as T7.3 says,
and add a second probe against an existing authenticated route** —
`GET {url}/discovery/grib-availability`, which is bearer-authenticated and costs an
`importlib.util.find_spec` call. A 401 there is reported to the operator as a rejected secret
rather than being absorbed into a generic success.

**Why this is not an architectural change.** No endpoint, config key, dependency or contract is
added — an existing route is called by an existing client for its status code. Trigger 7 is about
*adding* an endpoint; this adds none. The alternative — a purpose-built authenticated no-op health
route on the marine service — *would* be trigger 7 and was deliberately not taken.

**Recorded honestly as a compromise, not a clean design.** Using a discovery route as an auth
probe is a workaround. If Phase 8 wants a proper authenticated liveness route, that is a trigger-7
question for the operator, not something to slip in here.

---

## C-53 — the marine repo's manifest test pins a 6-entry inventory against 15 real entries (OPEN → fixed in Phase 7 R1a)

`tests/test_manifest.py:21-58` declares `_EXPECTED_ENDPOINTS` as a 6-entry specimen and asserts
both equality against `_ENDPOINTS` and `len(endpoints) == 6` (lines 71-78 and 156). `_ENDPOINTS`
has held **15** entries since C-30 completed the manifest (5 list routes) and C-42 added the four
`/discovery/*` routes. Neither round updated the test.

**Pre-existing, not caused by Phase 7** — but Phase 7 R1a adds two more entries and would trip it,
so it is corrected there as part of keeping an assertion honest with the change that touches it.
Recorded because it is the second time a manifest change has outrun its test, and the manifest is
the only channel by which a route reaches the dashboard (C-30's standing rule).

---

## C-54 — DECIDED BY OPERATOR: the API answers the SWAN question by asking the marine service (DECIDED)

**Ruling (operator, in chat, 2026-07-25):** *"You work it just like any other query to the API — the
API needs to handle the query. The API will know whether SWAN is installed as it will have to have
registered with the API."*

Option (a). The marine service exposes `GET /discovery/swan-check`; the API's
`/setup/marine/swan-check` becomes a pass-through and drops its local `shutil.which("swan")`. The
API-facing path, parameters and response shape do not change, so the three wizard call sites
(`wizard/routes.py:3126`, `:3637`, `:3698`) and any admin consumer keep working untouched. Error
policy is a hard 503 on an unreachable marine service — never "SWAN not installed", which would
replace one wrong answer with another. The host CPU core count in the response must describe the
**marine service** host, since that is the host that runs SWAN.

**The escalation was the defect, and the reason is worth recording — it is the third time.**

This question was already answered by the C-42 ruling and by `ARCHITECTURE.md`'s add-on invariant:
a component that needs marine data asks the API, and the API fronts the marine service. Two
instances of that exact pattern had landed **the same morning** (C-48's compute-estimate and
bathymetry-coverage). The coordinator nevertheless framed it as an open architectural question on
the grounds that answering it needs a third marine endpoint, and that adding an endpoint is trigger
7 outside C-48's authorisation.

That framing was wrong in the same way C-15 and C-26 were wrong. **Trigger 7 governs deciding that a
service needs a new interface — a design choice. It does not govern applying an already-ruled
pattern to the next instance of the same question.** Counting endpoints is not the test; whether the
responsibility is already settled is the test. It was settled, twice over.

There is a second miss underneath the first: the coordinator never asked *how the API would know*,
and the answer was structural rather than a matter of adding a probe. **The marine service registers
with the API** — manifest at startup, refreshed every five minutes, plus `/health`. The registration
channel already exists and is the thing that makes this a routine query rather than a new
capability.

**Cost of the error:** operator time and patience, for a question the project's own documents had
answered before it was asked. Same lesson as the units and ownership doctrine already recorded in
`rules/clearskies-process.md`: escalating a documented answer is not caution, it is a failure to
read.

### Original escalation, superseded

**~~AWAITING OPERATOR~~:** `GET /setup/marine/swan-check` probes for the SWAN binary on the wrong host

Found by the coordinator's Phase 7 survey of `endpoints/setup.py`. **Not covered by C-42's four
pinned imports and not covered by C-48's two endpoints**, so no existing ruling reaches it.

`/setup/marine/swan-check` (`endpoints/setup.py:2871`) answers the wizard's "is SWAN installed?"
question with a **local `shutil.which("swan")`** on the API host. After the separation SWAN runs on
the marine service host, and `reference/clearskies-dev.md` records the binary at
`/usr/local/bin/swan` on librewxr while the API runs on weewx. On a correct deployment this
endpoint therefore reports *SWAN is not installed* to an operator whose SWAN is installed and
running — a valid HTTP 200 carrying the wrong answer, which is the exact failure class this plan
exists to remove.

**Why it is not being fixed inside Phase 7 unilaterally.** The C-42 pattern says plainly what the
shape of the fix is — the API proxies the question to the marine service, which is the host that
can answer it. But the marine service has no endpoint that answers it, and **adding one is trigger
7**. C-48's operator-settled authorisation is explicitly scoped to two endpoints
(compute-estimate, bathymetry-coverage); stretching it to a third would be the coordinator
extending its own mandate, which is what C-48's own text praises the deletion agent for refusing
to do.

**Options:**

| Option | Cost |
|---|---|
| **(a) Marine service exposes a SWAN-availability check; the API proxies it** | One more endpoint (trigger 7), same shape as C-48's two. ~~The marine service already knows its SWAN binary path from config.~~ **Correction, 2026-07-25:** it does not — the path is the hardcoded `_DEFAULT_SWAN_BINARY` constant in `providers/nearshore/swan.py`, not a config key. Caught by the implementing agent, which reused that constant rather than adding config surface to make the coordinator's claim true. The option was right; this supporting sentence was wrong. Matches the settled pattern and makes the wizard truthful. |
| (b) Delete the check from the wizard | Removes an endpoint (also trigger 7) and removes a genuinely useful setup-time signal. |
| (c) Leave it | The wizard keeps telling correctly-deployed operators that SWAN is missing. Not recommended. |

Coordinator's recommendation: **(a)**, sequenced into Phase 7 alongside C-48 if the operator
authorises it, since the marine-side work is a near-copy of what R1a is already building.

---

## C-55 — four more `/setup/marine/*` endpoints answer marine questions inside the API (OPEN → Phase 8 assessment)

Same survey, lower severity than C-54 — recorded so the next round does not rediscover them and so
QC Gate 7's "zero marine code in the API" reading is not overclaimed.

| Endpoint | What it uses locally | Assessment |
|---|---|---|
| `/setup/marine/species` and `/setup/marine/species-database` | the ported species data set | Reference data, not computation or a provider fetch. Plausibly fine where it is. |
| `/setup/marine/discover-structures` | Overpass / OpenStreetMap | Not a marine *provider* module — it queries OSM, which the API queries for non-marine purposes too. Needs a reading, not an assumption. |
| `/setup/marine/bathymetry/upload` | `rasterio` file validation | Survives the C-48 deletion because it validates an uploaded file rather than resolving a DEM. But it is the sole remaining reason `rasterio` is reachable in the API, and it accepts bathymetry — data only the marine service consumes. |

**Not chased in Phase 7.** None of them produces a wrong answer today, unlike C-54. The question
each raises — *is answering this the API's job or the marine service's?* — is the same one C-40,
C-41, C-42 and C-48 each answered separately, and it deserves one assessment rather than a fifth
individual escalation. Carried to Phase 8.

---

## C-69 — the locale catalogues carry 62 keys of pre-existing drift (OPEN → tracked, not Phase 7's)

Surfaced when the coordinator independently checked the R4 locale pass. The docs agent reported key
counts as *"consistent (en=1370, non-en=1352)"*. All twelve non-English files do agree with each
other — but they do not agree with `en.json`, and the raw count understated it: the real shape is
**40 keys present in `en.json` and absent from every other locale, plus 22 keys present in every
other locale and absent from `en.json`.** 62 keys out of step, not an 18-key gap.

**Triaged against the Phase 7 baseline rather than guessed at** (`git show f8beb34:…` vs
`ac35196:…`, full key-set flattening on both):

| | `en` | `de` (representative) | missing vs `en` | extra vs `en` |
|---|---|---|---|---|
| Baseline `f8beb34` (Phase 7 start) | 1356 | 1336 | **42** | **22** |
| After R4 `ac35196` | 1370 | 1352 | **40** | **22** |

**Introduced by this phase: 0 missing, 0 extra. Fixed by this phase: 2.** The round added 39 strings
and 3 help keys to all 13 locales symmetrically and pruned 28 from all 13 symmetrically. The drift is
inherited and the round slightly reduced it.

**What the 40 English-only keys are:** field help text for DNS provider tokens, TLS certificate
paths, ACME/Let's Encrypt settings, logo uploads, Google Analytics, webcam URLs, seismic page
settings, sky-classification thresholds, and database credentials. **None is marine.** They are
`ConfigField.help_text` strings that were added to `en.json` over time without a locale sync — a
different failure mode from the wizard/admin chrome this phase touched.

**Why it is recorded rather than fixed here.** Translating 40 help strings into 12 languages, and
adjudicating 22 orphans that may be legitimately dead, is its own round with its own review. Folding
it into a marine-separation phase would bury it. Under the false-claim protocol, pre-existing
failures do not block a round that introduced none — and this one introduced none.

**Standing lesson.** "Consistent" is not a parity check. Twelve files can agree perfectly with each
other and all be wrong against the source of truth. The check that matters is **set difference in
both directions against `en.json`**, and it must be reported as two numbers, not one. The agent's own
work was clean; only the word describing it was wrong, which is exactly the kind of claim independent
verification exists to catch.

### Second dimension, added 2026-07-26 — key parity was measuring the wrong thing

The R7 agent noticed that the four SWAN strings it was replacing **held English text as their value
in all twelve non-English locales.** They had never been translated. A key-presence check cannot see
that: the key exists, so it reads as present and correct. The 40/22 figures above therefore
understate the gap, and the coordinator had been reporting them as the health metric.

Measured (`locale_value == en_value`, raw, no filtering for legitimately-identical values such as
`SWAN`, `HRRR`, package names and pure-symbol strings — so these are an **upper bound**). Run by the
agent and independently reproduced by the coordinator; raw counts matched exactly:

| Locale | Untranslated | Locale | Untranslated |
|---|---|---|---|
| `zh-CN` | 302 | `de` | 337 |
| `zh-TW` | 302 | `nl` | 336 |
| `ja` | 309 | `it` | 332 |
| `ru` | 311 | `fr` | 326 |
| `es` | 317 | `pt-BR` | 326 |
| `pt-PT` | 321 | **`fil`** | **644** |

**Eleven locales cluster at 302–337 untranslated keys (~23–25%). `fil.json` is an outlier at 644
(~48%) — roughly double every other locale.** That ratio is robust even though the absolute numbers
are inflated by legitimate identical values, because the inflation applies equally to all twelve.

**This changes the size of the remediation round.** A round scoped as "sync the locales" against the
40/22 key figures would be sized wrong by an order of magnitude, and would further mis-size Filipino
by a factor of two against its siblings.

**A methodology trap worth recording, because it produced a plausible wrong answer.** The agent's
first estimate ("~75% translated") came from testing `value != key`. That is unreliable here:
`en.json` has **150 keys whose value differs from the key itself** — legacy keys carrying updated
English copy, e.g. the key `"AQI regional scale for Aeris"` now holding
`"AQI regional scale for Vaisala Xweather"`. On those 150, `value != key` reports "translated" for
untranslated text. The correct test is `locale_value == en_value`. The agent found and corrected this
in its own working and said so, which is why the final figure can be trusted; it coincidentally
landed near the right answer for the wrong reason.

Those 150 stale keys are themselves a finding for the remediation round: a key whose text no longer
matches its value is a rename that was never propagated.

---

## C-68 — the marine service has no installation documentation of its own (OPEN → Phase 8, with T8.1)

Surfaced sideways during the Phase 7 R4 Operator Manual pass. The docs agent, correcting the SWAN
install instructions, proposed pointing the operator at "the marine service documentation" — and the
coordinator checked whether that documentation exists. **It does not.**

The `weewx-clearskies-marine` repo contains `README.md`, `LICENSE`, `pyproject.toml` and
`.gitignore`. No `docs/` directory. The README has zero mentions of `pip`, the `nearshore` extra,
eccodes, or the SWAN binary. Every other Clear Skies repo carries install and config documentation;
this one does not, because it was scaffolded in Phase 4 and has been growing code ever since.

**Why it matters now.** Phase 7 moved the *operator-facing* consequences of the separation into the
manuals: eccodes, SWAN, and the GRIB2 stack are now described as belonging to the marine service
host. Those passages can state the facts (verified from `pyproject.toml`: package
`weewx-clearskies-marine`, extra `nearshore`, eccodes system library first, SWAN binary on PATH on
that host) — but there is no per-repo document to hand the operator for anything deeper.

**Not a Phase 7 item and deliberately not absorbed.** Phase 7 is the wizard phase, and writing a new
repo's documentation set is not a translation or an Operator Manual correction. It sequences
naturally with **T8.1**, which creates `scripts/deploy-marine.sh` and stands the service up on
librewxr — that is the task that will establish the install steps this document would record.

**Standing note for whoever takes it:** the facts are already verified and written down here and in
`OPERATIONS-MANUAL.md`; the gap is a document, not a discovery.

---

## C-67 — the config UI has been sending an apply key the API renamed away (CLOSED — fixed at QC Gate 7, stack `e85e174`)

**The most serious defect found in Phase 7, and it predates Phase 7 entirely.** Write path found by
the Phase 7 adversarial audit (F1, HIGH) under plan audit item 7; read path found by the coordinator
when verifying the finding.

**Cause.** API commit `0685121` ("Phase 0+1 — SWAN corrections ADRs, doc updates, TruShore→SWAN
rename") renamed `ApplyRequest.trushore: TrushoreApplyConfig` to `swan: SwanApplyConfig`. The config
UI was never updated. Both directions of the contract have been broken since.

**Write path — hard failure, nothing saved.** `ApplyRequest` is `extra="forbid"`, so an unknown key
is rejected outright:

| Site | Sent | API expects |
|---|---|---|
| `wizard/routes.py:4171` | `api_payload["trushore"]` | `swan` |
| `admin/routes.py:3115` | `apply_payload["trushore"]` | `swan` |

`/setup/apply` returned 422 and **nothing in the payload was written** — not the SWAN settings, not
the marine locations, not any other section travelling in the same request. The wizard site fires
whenever marine is enabled and at least one location carries a `surf` activity. That is the exact
configuration this plan exists to make work.

**Read path — a valid response carrying the wrong answer.** `/setup/current-config` emits the section
under `swan` (`_serialize_swan_section`, `setup.py:1640`). Three admin sites read `trushore`, each
resolving to `{}`:

`admin/routes.py:2988`, `:3133`, `:3141` — so the admin TruShore page rendered **defaults on top of
whatever the operator had actually saved**, silently, with no error anywhere.

**Why it survived this long.** The payload *fields* were always correct — `omp_num_threads`,
`outer_grid_resolution_km`, `inner_nest_resolution_m` match `SwanApplyConfig` exactly. Only the
enclosing key was wrong. Every inspection that looked at field names found them right. This is the
third instance of the same class in this project (`marine_alert_radius_miles`, `nwps_wfo`, now this),
and the first where the mismatch was the *section* key rather than a leaf field.

**Not architectural.** The API's model and API-MANUAL are the contract and are untouched; the config
UI was the side diverging from it. `rules/clearskies-process.md` §"Wizard ↔ API apply contract sync"
mandates this fix, and "code that diverges from its own stated contract" is explicitly inside what
may be fixed without escalation. Internal `trushore_*` state attributes and form field names are left
alone — they never cross the API boundary.

**Standing lesson.** Plan audit item 7 says "Pydantic model sync — no 422 errors." Walking the leaf
fields is not enough: **the key the payload is filed under is part of the contract too.** A renamed
section key looks identical to a correct one at every level below it.

---

## C-66 — C-54 moved where the SWAN answer comes from; the copy explaining it stayed behind (OPEN → fix before QC Gate 7 closes)

Found by the coordinator's own QC Gate 7 walk, 2026-07-25. Not reported by any agent — the R3 agent
was scoped to the endpoint and the templates were nobody's assignment.

**What C-54 changed.** `GET /setup/marine/swan-check` used to run `shutil.which("swan")` in the API
process. After C-54 (API `3fcdf8b`, marine `ee61174`) it is a pass-through to the marine service's
`/discovery/swan-check`, so `available`, `version`, `path` and `cpu_cores` now describe **the marine
service host** — a different machine in any split deployment.

**What did not change.** Both surfaces render that result next to prose that still assumes the old
answer. Verified by reading the files, not inferred:

| Site | Text | Why it is now wrong |
|---|---|---|
| `templates/wizard/step_trushore.html:27` | "…not installed **on this host**." | `swan_info` describes the marine host, not this one. |
| `templates/wizard/step_trushore.html:28` | "install SWAN and the `clearskies[nearshore]` Python extra, then **restart the setup wizard**" | `[nearshore]` was deleted from the API in Phase 6 and does not exist. Restarting the wizard would not change a binary on another host; the marine service is what would need restarting. |
| `templates/wizard/step_trushore.html:33`, `:41` | `pip install clearskies[nearshore]` (twice, in the copyable install block) | Same nonexistent extra, in the block an operator is most likely to paste. |
| `templates/admin/trushore.html:72` | "Install SWAN to enable nearshore wave modeling." | Silent on *where*, which is the whole point after C-54. |
| `wizard/state.py:264` | comment: "Shown only when the `[nearshore]` pip extra is detected (swan-check passes)" | swan-check no longer detects a pip extra at all. |

**Consequence, stated concretely.** An operator running the marine service on a second host — the
topology this entire plan exists to support — is told SWAN is missing "on this host", handed a
`pip install` for an extra that no longer exists, and told to restart the wrong process. Every
instruction points at the wrong machine. This is a valid-looking response carrying the wrong answer,
the exact failure mode the plan was written to remove.

**Same shape as C-65, and that is the point.** C-65 was a freeze that was lifted on one surface and
not the other. This is a responsibility that moved hosts while the text explaining it stayed put.
The standing lesson generalises: **when a change moves where an answer comes from, every surface that
explains that answer moves with it** — not just the call sites that fetch it. The R3 close verified
the three wizard and five admin *call sites* and stopped there.

**Not architectural.** Nothing here changes a formula, module, boundary, data contract, computation
location, cadence, or dependency. `swan-check`'s path and response shape are untouched. This is
user-facing prose being corrected to describe what the code already does — and per CLAUDE.md
§"Doc-code sync", it is mandatory, not optional.

**Sequencing (coordinator, 2026-07-25):** the fix is held until the R4 locale pass finishes. These
are translatable strings, and changing them mid-pass would strand a freshly rebuilt catalogue against
strings that no longer exist. Fix the templates, then add the replacement strings, in that order, in
one locale pass rather than two.

---

## C-65 — Phase 7 broke the admin's TruShore save, and the coordinator's freeze is why (CLOSED — fixed in R2b)

**The only regression Phase 7 introduced.** Found by the coordinator running the repo-wide greps at
R2 close rather than by any agent report — the admin agent had been told this area was frozen, so it
correctly never looked.

R1b removed `service_url` from `SwanApplyConfig`, which uses `extra="forbid"` (T7.2, API-MANUAL
§19.2). `admin/routes.py:3092` still sent `"service_url"` in that section. **The admin's TruShore
Save therefore 422s** — a break created by this phase, not inherited, and precisely the failure the
"Wizard ↔ API apply contract sync" rule exists to catch: the API model and a caller drifted apart,
invisible to every unit test because it only fires on the real HTTP path.

**Root cause is a coordination error, not an agent error.** The coordinator froze
`templates/admin/trushore.html` and its routes in the admin agent's brief while C-58 was open, then
decided C-58 and dispatched **only the wizard half**, never lifting the freeze. Both agents did
exactly as instructed; the instruction was incomplete. The admin agent additionally flagged the
concurrent working-tree changes it saw and changed nothing — the correct response — which is why the
gap stayed a gap rather than becoming a collision.

**Fixed in R2b** by applying the same C-58 ruling to the admin surface: the deployment-mode radio,
the service-URL field, the `"service_url"` emission and the orphaned
`POST /admin/trushore/test-service` route all go; every other TruShore/SWAN field stays.

**Standing lesson.** A freeze placed on one surface while a decision is pending must be **lifted
explicitly on every surface it covered** when the decision lands. A ruling dispatched to one of two
surfaces is not a ruling applied — and the half left behind is the half nobody is looking at,
because it was declared out of scope. Pair every "frozen pending X" instruction with the list of
surfaces to revisit when X resolves.

---

## C-64 — the admin has no equivalent of the wizard's blank-URL guard (CLOSED 2026-07-26 — see the C-64 closure entry below; residual gap split out as C-75)

Raised by the Phase 7 admin agent, which correctly declined to invent one.

C-57 closed the wizard's hole: enable marine features with no marine service URL and the operator now
gets an error instead of silence. **The admin has the same hole and no fix.** An operator who adds
marine locations through the admin section with `marine_service_url` unconfigured gets marine
locations that no marine service will ever serve, and nothing says so.

**Deliberately not fixed in Phase 7.** T7.4 is scoped to the wizard's files in the plan. More
substantively, the wizard's guard keys off `state.marine_enabled` — wizard **session** state that has
no admin counterpart, because the admin edits marine locations in a separate section from the marine
connection. Building an admin equivalent needs a rule for what "enabled" means there, which is a
design question, not a port of the wizard's check.

**Note the asymmetry this leaves**: after Phase 7, the wizard path is guarded and the admin path is
not, so the same misconfiguration is caught or silent depending on which screen the operator used.
That is worth closing, and it is worth closing deliberately rather than by copying a check that does
not fit.

**Sharpened 2026-07-25 by the Phase 7 adversarial audit (F2, MEDIUM) — the consequence is worse than
this entry originally described, but the routing does not change.** The audit traced what actually
happens when an operator clears the field on the admin Marine Service page and saves:

`marine_url = str(form.get("marine_service_url", "")).strip()` yields `""`, which goes into the apply
payload as an empty string. `ApplyRequest.marine_service_url` is `str | None = None`, and Pydantic
accepts `""` as a valid `str` — so there is **no 422 to catch it**. The API writes
`marine_service_url = ` to `api.conf`, and every later marine request fails against an empty URL.
Nothing warns the operator at save time. So this is not only "no guard when adding locations": an
operator can *disconnect the marine service entirely* by clearing a field, and the UI reports success.

**Still routed to Phase 8, for the original reason.** A real guard needs a definition of what
"enabled" means on the admin surface, which has no wizard-session equivalent — a design question, not
a port of the wizard's check.

**One cheap half is separable, and Phase 8 should consider it first:** normalising `""` to `None`
before building the payload requires no definition of "enabled" at all. `ApplyRequest` already treats
`None` as "not configured", so an empty field would mean what the operator plainly intends instead of
persisting a URL that cannot resolve. Recorded as an option, not a decision — it changes what is
persisted, so it belongs to whoever takes C-64, not to Phase 7.

---

## C-63 — the same-host URL literal now exists twice, by design (CLOSED 2026-07-26 — see the C-63 closure entry below)

`https://localhost:8780` is defined in `wizard/routes.py` and again in `admin/routes.py`.

**This duplication is deliberate and was flagged rather than committed silently.** `admin/routes.py`
states twice in its own source that it keeps local copies rather than importing from the wizard
router, so neither router has a module-scope import dependency on the other. The Phase 7 admin agent
followed that house rule and named the wizard as the twin in a comment — the right call over quietly
breaking the file's stated convention.

**The risk is real but small:** two literals for one URL will eventually disagree, and the failure
would be an admin "same host" checkbox filling in a different port from the wizard's. Consolidating
them into a shared constants module is a follow-up, not something to bolt onto the wizard phase.

---

## C-62 — the admin's marine save path has never worked (CLOSED — fixed in Phase 7 R2)

Found by the Phase 7 admin agent while reading the section it was about to replace, before writing
any code. Two defects, both pre-dating this phase.

1. **`compute_save()` sent a two-key body as the entire `/setup/apply` payload.** `ApplyRequest`
   declares `database` with no default and `model_config = ConfigDict(extra="forbid")`, so
   `{"surf_compute_host": …, "surf_compute_secret": …}` **422s on both counts** — a missing required
   section and two unknown fields. It failed this way before Phase 7 touched anything.
2. **It also violated `admin/routes.py`'s own module-level "NOTE on write path" (`:1858`)**, which
   states that `database`, `station`, `column_mapping` and `column_units` are always-rewritten fields
   that must be re-sent faithfully from a freshly fetched current-config — exactly as the
   marine-locations section's `_build_marine_apply_payload()` already does. The admin compute section
   (added as Phase 5 audit finding F1) shipped without it.

**Fixed in place rather than carried forward or logged-and-deferred.** The section's save path is
being rewritten wholesale by T7.5; delivering a replacement whose Save button 422s would not be
delivering T7.5. Reusing the existing in-file always-rewritten block adds no field, key or endpoint
beyond LC-P7-3's three, and "code diverging from its own stated contract" is explicitly inside what
may be fixed without escalation — the contract here is written in the same file, twelve hundred lines
above the violation.

**Recorded in the commit message as pre-existing**, so a later reader diffing this does not conclude
Phase 7 broke it or invented a fix for a problem that never existed.

**Worth noting how it survived:** the admin Test button was visibly broken, and the Save button was
invisibly broken. Only one of them gets clicked during a demo.

---

## C-61 — 19 Phase-4 brief files were deleted from the meta repo working tree mid-session (CLOSED — restored, nothing lost)

**Found by the coordinator, not reported by any agent**, while running the routine post-round
`git status` on the meta repo during Phase 7 Round 1.

Nineteen files were missing from disk, all of them `docs/planning/briefs/P4*.md` — the entire
Phase 4 / 4A / 4B round-brief set, including three the plan **actively cites**:
`P4A-QC-GATE-4A-RESULTS.md`, `P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md` and
`P4A-AUDIT-FINDINGS.md`. Deletions were unstaged and uncommitted.

**They were present at Phase 7 pre-flight** — the coordinator's pre-flight `git status` on the meta
repo showed a clean tree — so the loss happened during this session, not before it.

**Restored** with `git checkout -- docs/planning/briefs/`; 39 briefs back, working tree otherwise
clean. **Nothing was lost and nothing was ever committed as deleted.**

**Two things went right and are worth recording, because they are why this was harmless:**

1. Both agents that committed to the meta repo this round (`84a27fd`, `6d4bb29`) staged **named
   files**. Had either used `git add -A` or `git commit -a`, the 19 deletions would have ridden
   along inside a doc-sync commit, and the plan would now cite three briefs that no longer exist.
   The house rule against blanket staging is exactly what contained this.
2. The coordinator runs `git status` on every repo at every round close rather than only checking
   the commits an agent reports. The agent reports were all accurate; the damage was not in any of
   them.

**Cause not determined, and not guessed at.** Two candidates, neither confirmed: a stray filesystem
operation by one of the four agents (none reported one, and none was asked to touch `briefs/`), or
a Nextcloud replication artefact — this repo replicates through Nextcloud, and an alphabetically
contiguous `P4*` block disappearing at once has the shape of a partial sync as much as of a
deliberate cleanup. Reading the agent transcripts to settle it would cost more than the answer is
worth now that the files are back.

**Standing lesson, and the reason this entry exists at all:** the round-close check must be
`git status` on the **whole repo**, never just `git log` of the commits an agent names. An agent
reporting its own work accurately says nothing about what else moved in the tree. A deletion is the
one class of damage that looks like nothing at all in a commit list.

---

## C-60 — the `[marine]` prune left two deploy-readiness loose ends (OPEN → before Phase 8 deploy)

Both surfaced by the C-49 prune in Phase 7 R1b. Neither is a defect in the prune, which is
well-evidenced (zero source importers of `eccodes`, `xarray` or `netCDF4` anywhere in the API,
verified independently by the coordinator — the only remaining hits are a stale `__pycache__`
`.pyc` for the already-deleted `grib_processor.py`).

1. **`uv.lock` was not regenerated.** `pyproject.toml` lost an extra; the lock file still describes
   the old dependency set. The agent correctly declined to hand-edit it — regenerating needs a live
   `uv lock` against PyPI. ~~But `deploy-api.sh` and the documented test invocations use
   `uv run --frozen`, which is precisely the mode that fails when the lock and the manifest
   disagree.~~ **Regenerate before Phase 8's deploy, not during it.**

   **CLOSED 2026-07-25 — API `0a514f2`.** Regenerated with `uv` 0.11.32. Pure prune: 11 packages
   removed (`attrs`, `cfgrib`, `cftime`, `coastalmodeling-vdatum`, `eccodes`, `findlibs`,
   `h5netcdf`, `netcdf4`, `pyproj`, `shapely`, `xarray`), zero added, zero version changes to any
   retained package, 72 packages resolving. Evidence:

   ```
   uv lock --check   before: error: The lockfile at `uv.lock` needs to be updated  (exit 1)
   uv lock --check   after:  Resolved 72 packages                                  (exit 0)
   ```

   ⚠ **Correction to this concern as originally filed — the stated mechanism was wrong.**
   `scripts/deploy-api.sh` does **not** run `uv run --frozen`, or any `uv` command at all. It runs
   `git pull --ff-only` as `ubuntu`, restarts the systemd unit, waits, and curls the health port —
   it never touches dependencies. Verified by reading the script (`grep -i 'uv\|frozen'` returns
   only two prose mentions of "uvicorn"). The real blast radius was: `uv run --frozen`, which
   `reference/clearskies-dev.md:303-312` prescribes as the way to run pytest on the weewx host, and
   `uv sync --frozen`, which `scripts/deploy-compute.sh` uses — and which has a recorded history of
   pruning a host's venv (P4A-AUDIT-FINDINGS.md:90). So the fix was genuinely needed and the
   urgency was real, but it would have broken **verification**, not the deploy. Recorded because a
   concern that names the wrong failing component sends the next reader to the wrong file.
2. **`Dockerfile` cited ADR-085 for the `libeccodes-dev` / `libeccodes0` system packages**, which
   were installed solely to serve the `[marine]` extra. Removing them was required — leaving the
   build pointing at a now-nonexistent extra would have failed outright — and the evidence supports
   it, since GRIB2 processing moved to the marine service. ~~But **ADR-085 now describes a dependency
   the API no longer has.** That is an ADR-status question…~~

   **RESOLVED 2026-07-25 — there is no ADR-status question, and no operator decision is needed.**
   ADR-085 is **already archived**: `status: Archived — consolidated into OPERATIONS-MANUAL.md`,
   archived 2026-07-09. Under `rules/clearskies-process.md` §"All ADRs follow the manual
   consolidation lifecycle", an archived ADR is a historical record of *why* a decision was made and
   is **not** restated to match current state — "the archived ADR explains why; the manual is where
   you follow it." Nothing about ADR-085 needs to change.

   **What the question actually pointed at is live doc-code drift in the manuals**, which is
   mandatory under CLAUDE.md §"Doc-code sync" and was created by this phase's own commits:

   | Document | Location | Defect |
   |---|---|---|
   | `OPERATIONS-MANUAL.md` | §"eccodes native dependency (marine feature)" (~161-193) | Tells the operator eccodes is an **API** dependency, that the **API** Dockerfile bakes in `libeccodes-dev`, and to run `pip install weewx-clearskies-api[marine]`. All three false. The platform install table points at the wrong host. |
   | `ARCHITECTURE.md` | ~695 | Same eccodes claim, in a blockquote. |
   | `ARCHITECTURE.md` | ~689 | Presents `services/bathymetry_resolver.py` as a live API service. Deleted from the API this phase. |
   | `API-MANUAL.md` | ~2833-2850 | Presents `providers/marine/grib_processor.py` as the API's GRIB reader, with its eccodes/pygrib backends. Deleted from the API. |

   Routed to R5 as documentation work. **ADR-099 is deliberately excluded** — it is still
   `status: Proposed`, so every `(target — pending ADR-099 acceptance)` annotation in
   `ARCHITECTURE.md` is *correct* and must survive untouched. Removing them is contingent on
   operator approval per Phase 1 T1.1 item 9, which has not happened.

---

## C-59 — `rasterio` is imported by a live API endpoint and declared nowhere (OPEN → Phase 8, with C-55)

Found by the Phase 7 R1b agent during the `[marine]` prune census and correctly flagged rather than
fixed; verified independently by the coordinator at `endpoints/setup.py:4384`.

`POST /setup/marine/bathymetry/upload` lazily imports `rasterio` to validate an uploaded GeoTIFF.
`rasterio` appears in **no** extra in `pyproject.toml`, and the endpoint's own error message tells
the operator to *"add to `[nearshore]` extra"* — an extra Phase 6 deleted from this repo. So the
guidance points at something that cannot be done.

**Pre-existing and orthogonal to C-49** — a different library from the three being pruned, and
undeclared before this round began. Not fixed because declaring a dependency is trigger 7 and
outside Phase 7's authorisation.

**Sequence it with C-55**, which asks whether this endpoint belongs in the API at all. If the answer
is that it moves to the marine service, the dependency question moves with it and never needs
answering here. Deciding the dependency first would risk declaring a package into a repo that is
about to stop needing it.

**Reaffirmed 2026-07-25 at QC Gate 7 — sequencing unchanged, with one separable part named.**
The concern has two halves and only one of them is blocked on C-55:

- *The dependency question* — should `rasterio` be declared, and in which repo — genuinely waits for
  C-55. Declaring it is trigger 7, and doing so into a repo that may be about to shed the endpoint
  is the wrong order. Unchanged.
- *The error message* is separable and is not blocked on anything. `endpoints/setup.py:4370-4371`
  tells the operator to "Install rasterio (add to `[nearshore]` extra)" — an extra Phase 6 deleted,
  so the instruction cannot be followed regardless of how C-55 lands. This is the **same defect
  class as C-66**: install guidance naming a component that no longer exists. Noted here so the
  Phase 8 assessment fixes both halves rather than only the interesting one; if C-55 concludes the
  endpoint moves, the message travels with it and is corrected there instead.

Neither half is a Phase 7 item. Recorded rather than absorbed.

---

## C-58 — DECIDED BY COORDINATOR: the stranded deployment-mode control is deleted with the URL (DECIDED)

**Decision (coordinator, 2026-07-25): option (a).** Delete the "Deployment mode" fieldset,
`trushore_deployment_mode`, the orphaned `POST /wizard/trushore/test-service` route, and the
`service_url` emission in `build_trushore_payload`, together with the URL field itself. T7.2's
"single URL field" criterion is then genuinely met.

**This should not have been escalated, and CLAUDE.md answers it directly.** Its own
architecture-vs-methodology table has the row:

> Removing code that provably never executes — **Methodology** — *Nothing was being done; nothing
> stops being done.*

That is exactly this case, and the "provably" was already established by measurement rather than
assumed: the radio's `onchange` handlers toggle the service-URL row **and nothing else**, and
`build_trushore_payload` consults the mode **only** to decide whether to emit `service_url`. Once
T7.2 removes that field — which the plan directs and API-MANUAL §19.2 independently states — the
control has no effect on the UI and no effect on the written config. It is inert, and removing inert
code is methodology. `rules/coding.md` §3 (no code without a current caller) is a rule already
written down, and applying a written rule is explicitly inside what may be done without asking.

**Why the coordinator got it wrong:** it pattern-matched "delete a component" to trigger 2 and to the
Phase 4A `wave_transform.apply_supplements()` incident, without applying the test that distinguishes
them. In that incident a component with **live behaviour** was deleted — a responsibility
disappeared. Here nothing is being done in the first place, because the thing the control existed to
reveal is gone. **Trigger 2 asks whether a responsibility moves or vanishes. A control whose only
responsibility was revealing a deleted field has no responsibility left to lose.**

Recorded because this is the second escalation in one session that the project's own documents
already answered (see C-54), and both were over-triggering, not under-triggering. Over-triggering
has a real cost and is not the safe default it feels like — the same conclusion `rules/clearskies-process.md`
already draws from C-15.

**Not covered by this decision, and deliberately so:** every other field on the TruShore step — SWAN
grid bbox, nested-grid resolutions, OMP thread count, the per-spot breaker and display settings — is
live and untouched. Only the deployment-mode control and the URL it revealed are removed.

### Original escalation, superseded

**~~AWAITING OPERATOR~~ — the stranded control**

**Severity:** blocks T7.2's "single URL field" acceptance criterion. Nothing else.

Found by the Phase 7 wizard agent at its halt condition, correctly refused rather than decided.

T7.2 folds the TruShore/SWAN `service_url` into `marine_service_url`. But that field is not
standalone. `templates/wizard/step_trushore.html:86-128` carries a **"Deployment mode" radio group**
(`trushore_deployment_mode` = bundled | separated) whose only effect is to show or hide the Service
URL row; `config_writer.build_trushore_payload` uses the mode only to decide whether to emit
`service_url`. Remove the URL and the radio becomes a control that does nothing, and the wizard's
`POST /wizard/trushore/test-service` (`routes.py:3718-3765`) is orphaned with it.

**The step is not emptied** — SWAN grid bbox, nested-grid resolutions, OMP thread count and the
per-spot breaker/display settings all remain and are untouched.

**Why the coordinator is not ruling on it.** Deleting the fieldset, its state field and its route is
trigger 2 — a component disposition. The standing block says the coordinator has no authority to
approve one either, and this project has a recorded incident (Phase 4A, `wave_transform.apply_supplements()`)
where a coordinator ruled "rewire" and then "delete" on exactly this shape of question and it counted
as a violation. Not repeating it.

**The substantive point, offered as input rather than as a decision.** Post-separation the question
"is SWAN bundled or on another host?" no longer has meaning in the wizard's terms: the API contains
zero SWAN code, so SWAN is always in the marine service, and "same host" versus "another host" is
exactly what T7.2's new **Same host checkbox** on the marine service URL expresses. The deployment
radio and the checkbox are two controls asking one question.

| Option | Cost |
|---|---|
| **(a) Delete the deployment-mode fieldset, `trushore_deployment_mode` state, and the orphaned `test-service` route with the URL field** | T7.2's criterion is met. One control for one question. Trigger 2. |
| (b) Leave them this round | A radio button that changes nothing, and a second URL field, so T7.2 closes with a named exception rather than a pass. |
| (c) Keep the radio, repoint it at the marine URL | Two controls for the same question, permanently. Not recommended. |

Coordinator's recommendation: **(a)**. Held meanwhile — `step_trushore.html` and
`build_trushore_payload` are untouched, and the wizard round reports T7.2 as **not met**, not as
done.

---

## C-57 — T7.4's validation could not fire on the path an operator actually takes (DECIDED)

Found by the Phase 7 wizard agent while implementing T7.4. It is a real hole in the task as written,
not a porting artefact.

T7.4 requires an error when the marine service URL is blank and marine features are enabled. The
signal for "marine features enabled" is `WizardState.marine_enabled` (`state.py:218`), set by the
**marine step, which is step 13**. The URL lives on the **providers step, which is step 8**. On a
straight first pass `marine_enabled` is still `False` when the operator submits providers, so a
blank URL passes, and the operator meets the error only if they navigate backwards — which nothing
prompts them to do.

As written, T7.4 would have shipped as a validation rule that cannot fire on the normal path. That is
worse than no rule, because the gate reads as covered.

**Decision (coordinator, 2026-07-25): validate on the marine step as well.** When the operator sets
`marine_enabled` true and `marine_service_url` is blank, the marine step re-renders with the error.

**Why this is not scope expansion.** It is the only place T7.4's own acceptance criterion can be
enforced, and enforcing a criterion the plan already states is explicitly permitted. The agent used
the existing `marine_enabled` signal rather than inventing a flag, which is what the brief asked for.

**Not done, deliberately:** no apply-time backstop in the API's `ApplyRequest`. That would mean
rejecting applies for a wizard-side omission — a different decision with a different blast radius,
and not one T7.4 asks for.

---

## C-56 — C-46 is routed to Phase 8, not Phase 7 (DECIDED)

C-46 (`MARINE_PROVIDER_MODULES` populated but with no consumer) was routed "Phase 7/8". Settling
it here: **Phase 8.**

The plausible consumer is the manifest's `compute_capabilities()`, which today derives the
advertised capability list from the pushed config (`manifest.py:167-185`). Rewiring it to derive
from the provider registry changes where the capability surface crossing the API↔marine boundary
comes from — a contract question, and one with no wizard content at all. Phase 7 is the wizard
phase. Recorded rather than absorbed into a pass.

---

## C-70 — the marine service and the old SWAN service share one working directory (DECIDED — sequencing, not architecture)

Found by the coordinator opening Phase 8, while measuring librewxr for T8.1b — before any deploy,
which is the point at which it was still cheap.

**Finding.** The marine service's moved SWAN code writes to exactly the paths the old standalone
SWAN service on port 8767 writes to *right now*, because the code was moved verbatim and its path
constants travelled with it:

| Path | Written by marine service | Written by old 8767 service |
|---|---|---|
| `/var/run/weewx-clearskies/swan/` (work dirs `level1/ level2/ level3_0/`) | `swan_runner.py:2055`, `providers/nearshore/swan.py:1027,2117`, `surfbeat_runner.py:78` | yes — live, 585 MB on disk |
| `/var/run/weewx-clearskies/swan/forecast_cache.json` | `providers/nearshore/swan.py:197` | yes — 24.7 MB, rewritten each cycle |
| `{level1,level2,level3_N}_hotstart.dat` | same dir | yes — `level2_hotstart.dat` 31.6 MB |
| `/etc/weewx-clearskies/swan_bathymetry_L*.json`, `spot_profiles/`, `swan_grid_sizing.json` | `providers/nearshore/swan.py:169-192` | yes |

Two processes running SWAN cycles against one working directory would interleave INPUT file
writes, overwrite each other's hotstart state, and race on `forecast_cache.json`. Hotstart
corruption is the serious one: each cycle starts from the previous cycle's wave field, so a
corrupted hotstart poisons subsequent runs rather than failing loudly once.

**This is not an architectural finding and was not escalated.** The paths are the moved code's own
pre-existing paths — `rules/clearskies-process.md` §"Moving a module moves its dependencies"
applies directly: they exist because the code has always used them, they travel with it, and after
T8.4 disables the old service the marine service is their sole owner, which is the end state the
plan already authorises. Nothing's responsibility moves. The only question is operational: do not
run two SWAN cycles against one directory during the overlap window.

**Decision (coordinator).** **Stop — not disable — the old `weewx-clearskies-swan` and
`weewx-clearskies-compute` units after the API is repointed to port 8780 and before the marine
service's first model cycle.**

This is consistent with the plan's own rollback design rather than a departure from it. T8.4's
prerequisite is that **T8.6 (E2E) must pass before the old services are *disabled***, because they
are the rollback path. A `systemctl stop` leaves both units `enabled`; rollback stays one
`systemctl start` away, and `/etc/weewx-clearskies/api.conf` is backed up before T8.2b rewrites it.
T8.4 still runs where the plan puts it, after E2E, and is what makes the removal permanent.

**It also resolves T8.1b's memory question in the same action** — the 8767 service's 366 MB
resident cache and the 8770 service's 27 MB are freed exactly when the marine service starts
needing headroom for its own cache and a SWAN binary. Peak projected marine footprint is ~450 MB
against 1,355 MB available; running both stacks' caches and both SWAN binaries concurrently is what
would have been tight, and this avoids it.

**Resulting Phase 8 order** (T8.6-before-T8.4/T8.5 preserved exactly):

1. T8.1b — assessment. *(done)*
2. T8.1 — marine service up on 8780 with **no config pushed**: it serves `/health` + `/manifest`
   only and the runner loop idles, so it touches none of the shared paths. Old services untouched.
3. T8.2 / T8.2b — API deployed and repointed to `marine_service_url`. Nothing reads 8767 any more.
4. **Stop (reversible) the 8767 and 8770 units.** ← this decision
5. Push marine config → grid-sizing chain → first SWAN cycle, sole owner of the working directory.
6. T8.3 — dashboard + config UI.
7. T8.6 — E2E verification.
8. T8.4 (disable, permanent) / T8.4b (archive repo) / T8.5 (weewx filesystem cleanup).

**Adjacent fact recorded while here, not acted on.** The shipped unit
`packaging/weewx-clearskies-marine.service` specifies `User=clearskies`. That user does not exist
on librewxr, where both existing Clear Skies units run as `ubuntu` and every file under
`/etc/weewx-clearskies/` and `/var/run/weewx-clearskies/` is `ubuntu`-owned. The deploy uses
`User=ubuntu` to match the host. Creating a `clearskies` user would require re-owning those trees,
which CLAUDE.md §"Filesystem permissions on containers" forbids and which would break the old
services mid-transition. This belongs in the install documentation C-68 asks for: the shipped unit
states a default, and a host where Clear Skies already runs as another user matches that user.

---

## C-71 — T8.2b's "remove the `[swan]` section" would silently discard the operator's `omp_num_threads` ruling (DECIDED — named gate exception, C-40 precedent)

Found by the coordinator opening T8.2b, tracing what the API's marine config push actually carries
before rewriting `api.conf`. The C-67 lesson applied deliberately: walk the payload against the
model, not the field list.

**What T8.2b says.** *"1. Remove `[swan]` section."* Accept criterion: *"`api.conf` has
`marine_service_url`, no `[swan]`, no `surf_compute_host`."* The Part B QA table repeats it as
`grep -E "swan|surf_compute" api.conf` → *"No matches."*

**What `[swan]` actually carries.** Four keys, of two entirely different kinds:

| Key | Kind | Superseded by `marine_service_url`? |
|---|---|---|
| `service_url` | connection | **Yes** — this is what T7.2 replaced |
| `verify_tls` | connection | **Yes** |
| `omp_num_threads` | SWAN model tuning | **No** |
| `outer_grid_resolution_km`, `inner_nest_resolution_m` | SWAN model tuning | **No** |

The model-tuning keys are not legacy residue. They are operator-facing settings written by the
config UI (`templates/admin/trushore.html:146`, `templates/wizard/step_trushore.html:152`
-> `setup.py:1948` `cfg["swan"]["omp_num_threads"]`), and the API pushes them to the marine service:
`_build_marine_service_config_payload()` (`endpoints/setup.py:1638-1640`) attaches
`payload["swan"] = _serialize_swan_section(swan_section)` **only if `[swan]` exists in api.conf**,
and `_serialize_swan_section()` reads `omp_num_threads` with a default of `0`.

**So deleting the section does not remove a dead key — it changes a live value.** With no `[swan]`
section there is no `swan` key in the push; the marine side constructs `SwanConfig({})`, which sets
`omp_num_threads = 0`, documented in its own source as *"0 = let OpenMP use all cores"*. On librewxr
that is **16**.

**Why that specific number is not a tuning detail.** `reference/clearskies-dev.md` §"librewxr
resource budget": *"`omp_num_threads = 6`. **Six. Not 16, not 0.** This is an operator ruling, not a
tuning knob. Do not change it without asking."* With measurements, on the same 81x71 L2 grid:

| `omp_num_threads` | SWAN RSS | L2 wall-clock |
|---|---|---|
| 16 | 627 MB peak, **179 MB into swap** | 6m51s - 7m57s |
| 6 | **87 MB**, no swap | 9m40s |

and on 2026-07-25, at 16 threads with the compute service also busy, one L2 run took **50m32s
instead of 7m**. Following T8.2b literally would reinstate exactly the condition T8.1b exists to
prevent, on a box with 1,355 MB available.

**A second, sharper problem — the ruling currently lives in the wrong file.** `omp_num_threads = 6`
is set in **librewxr's** `/etc/weewx-clearskies/api.conf`, which is read by the old 8767 SWAN
service. The value in **weewx's** `api.conf` — the one the API pushes from — is **16**.
`briefs/SURF-PUBLISH-RESULTS-ONLY.md` §7 already noticed this and called it *"harmless (SWAN does
not run there) but misleading."* **It stops being harmless the moment the API begins pushing it to
the host that does run SWAN.** This is C-66's lesson exactly: when a change moves where an answer
comes from, every surface carrying that answer moves with it. T8.4 retires librewxr's `api.conf` as
a SWAN input; if the ruling is not migrated first, it is simply lost.

**Decision (coordinator).**

1. **Keep `[swan]` in weewx's `api.conf`, carrying the model-tuning keys only.** Remove
   `service_url` and `verify_tls` — those are the keys `marine_service_url` genuinely replaces, and
   removing them is what T8.2b's own step 2 is about.
2. **Migrate the operator ruling: set `omp_num_threads = 6`** in weewx's `api.conf`, replacing the
   stale `16`. This does not change the ruling; it moves it to the file that now enforces it. The
   effective value on the SWAN host before and after this phase is 6 either way.
3. **Record a named gate exception** for the Part B QA `grep -E "swan|surf_compute"` check and the
   QC Gate 8 "api.conf matches target state" criterion.

**Why this is not an escalation.** Three governing statements, read together, settle it without a
new decision: `reference/clearskies-dev.md` forbids changing `omp_num_threads` without asking;
`ARCHITECTURE.md` states the marine service never reads `api.conf` and the API is the single source
of truth for operator config, so `api.conf [swan]` is the *only* place this value can come from;
and the shipped API code already reads it from there and pushes it. Per
`rules/clearskies-process.md` §"Over-triggering is a failure mode too" — the responsibility is
already settled and this is the next instance of it, not a new design question. And per CLAUDE.md's
named non-excuse, *"a governing document says so"* is not authorization to make a change that
breaks an operator ruling: a plan step that is wrong is a finding to surface, which is what this
entry is.

**Precedent for the gate exception: C-40 at QC Gate 6**, where the gate's grep listed `marine_config`
and legitimately matched, because the API keeps the marine config *schema* while shedding marine
*computation*. Identical shape here: the gate's grep term `swan` predates the distinction between
`[swan]`'s connection keys (gone) and its model-tuning keys (retained by design, because the API
owns operator config and pushes it). The grep is over-broad, not the config.

**Follow-up, not blocking:** the section name `[swan]` is now the only thing in `api.conf` still
implying the API knows about SWAN, when what it actually holds is "marine model tuning the operator
sets and the API forwards." Renaming it is a config-key change (trigger 7) with a wizard, admin,
serializer and migration surface, and is deliberately NOT bundled into a deploy phase. Recorded for
a later round.

---

## C-72 — the companion proxy ignores `marine_verify_tls`, re-introducing the Part A TLS failure (CLOSED 2026-07-26 — api `994b4e4`, verified live)

Found by the coordinator immediately after C-71, still reading the API's marine surface against its
own contract before deploying it. **This one would have taken the entire marine surface down on
first start.**

**The defect.** `services/companion_proxy.py` hardcodes `verify=True` on every outbound request to
the marine service — four sites:

```
257:  httpx.Client(timeout=_MANIFEST_FETCH_TIMEOUT_S,    verify=True)   manifest fetch
399:  httpx.Client(timeout=_DISCOVERY_REQUEST_TIMEOUT_S, verify=True)   /discovery/* proxy
433:  httpx.Client(timeout=_PROXY_REQUEST_TIMEOUT_S,     verify=True)   mounted-route proxy
767:  httpx.post(..., verify=True, ...)                                 POST /report/gap
```

The marine service's certificate is **self-signed by default** — Ed25519, auto-generated on first
start. Verified live on librewxr 2026-07-26: `subject=CN = clearskies-marine`, self-signed, SAN
carrying `192.168.7.22`.

**Consequence.** The manifest fetch fails certificate verification, so **zero marine routes are
mounted** and every marine page is dead — while `api.conf` says `marine_verify_tls = false`. This is
the same `SSL: CERTIFICATE_VERIFY_FAILED certificate verify failed: self-signed certificate` that
the plan's §0.2 records as the Part A root cause and that Phase 2 fixed on the old path. The new
path re-introduces it.

**And the diagnostic lies.** `POST /setup/providers/test-marine` (`setup.py:~2818`, `~4498`) **does**
honour `marine_verify_tls`, as does the config push (`_push_marine_service_config()`:
`httpx.AsyncClient(timeout=10.0, verify=verify_tls)`). So the wizard's Test Connection reports
success, the config push succeeds, and the proxy silently mounts nothing. Same family as C-64 — the
operator is told it worked.

**The contract this violates is explicit in three governing documents**, none of which scopes the
key to the config-push path:

- `API-MANUAL.md:3082` — *"Verify TLS certificate **on marine service requests**. Set `false` for a
  self-signed cert on the same VLAN (TLS encryption stays active either way)."*
- `OPERATIONS-MANUAL.md:1080` — the same table row.
- `OPERATIONS-MANUAL.md:1131` — *"For separate-host deployments with a self-signed cert, set
  `marine_verify_tls = false` in `api.conf [providers]`."*

`config/settings.py` parses only `marine_service_url` from `[providers]` (`settings.py:1319-1332`),
never `marine_verify_tls`, which is why the proxy had nothing to read.

**Not an architectural change, so not escalated.** No config key is added: `marine_verify_tls`
already exists, is already written by the wizard, already parsed by
`_read_marine_service_connection()`, and already honoured at three call sites. Making four more
honour it is CLAUDE.md's explicitly-permitted *"fix a defect where code diverges from its own stated
contract."* The secure default `True` is unchanged.

**Dispatched to `clearskies-api-dev`** with the secure default preserved and a startup WARNING
required when verification is disabled, so an unverified TLS connection is visible in the journal
rather than silent.

**CLOSED 2026-07-26 — fixed in api `994b4e4` and proven live, not on the agent's report.** All four
call sites now read `state.verify_tls`; `grep -n "verify=" companion_proxy.py` returns four hits, all
`verify=state.verify_tls`, zero literals. Default remains `True` when the key is absent
(`_bool(section.get("marine_verify_tls", True))`). The API's own startup journal on weewx is the
evidence that matters:

```
WARNING companion_proxy: marine_verify_tls=false - TLS certificate verification is DISABLED
        for requests to https://192.168.7.22:8780 (encryption stays active; only certificate
        verification is skipped)
INFO    httpx: HTTP Request: GET https://192.168.7.22:8780/manifest "HTTP/1.1 200 OK"
INFO    companion_proxy: registered /api/v1/surf -> /surf (cache_ttl=1800s)          [x18]
```

Before the fix that manifest line would have been `CERTIFICATE_VERIFY_FAILED` and the 18 route
registrations would not exist. A proxied `GET /api/v1/tides` now returns the marine service's own
404 body with `"instance": "https://192.168.7.22:8780/tides"` — the upstream URL in the response is
proof the answer came from the marine service rather than from anything left in the API.

**How this survived Phase 6's audit and QC Gate 6.** The gate criterion was *"proxy mounts routes
from manifest"*, verified against a mock. Nothing had ever pointed the proxy at the real
self-signed marine service, because — per the Phase 7 closeout — *"nothing is deployed until Phase
8"* and config push was recorded as **NOT LIVE-TESTABLE**, verified by contract inspection only.
Contract inspection reads the code's stated contract; it does not read the TLS material the code
will meet. Worth carrying: the class of defect that survives a mock is the one where the mock's
transport is not the real transport.

---

## C-73 — the marine service's config-recovery pull has C-72's defect, mirrored (OPEN → Phase 8, low priority)

Found by the coordinator at T8.2, immediately after C-72, while choosing how to get the first config
into the marine service. Same defect class, opposite direction, different repo.

`weewx_clearskies_marine/config/__init__.py` `fetch_config_from_api()` (line ~162) calls:

```python
resp = httpx.get(
    url,
    headers={"Authorization": f"Bearer {secret}"},
    timeout=timeout,
)
```

No `verify=` argument, so httpx defaults to `verify=True`. The API it is fetching from presents a
**self-signed** certificate — `ARCHITECTURE.md`'s container inventory: *"TLS always enabled (Ed25519
self-signed by default)"*. So on the documented default deployment the T6.4b startup recovery pull
fails certificate verification, logs
`Failed to fetch marine config from ...: ConnectError`, and the service starts serving `/health` and
`/manifest` only.

**Why it is much less severe than C-72, and is not being fixed in the same breath.**

- C-72 broke the **primary** path — the API's manifest fetch, on every start, taking the entire
  marine surface down.
- C-73 breaks a **recovery** path that only runs when the marine service starts with no local
  `marine.conf`. The normal path — the API's `POST /config` push — is unaffected, and a local config
  file always wins over this fetch. On this installation `CLEARSKIES_MARINE_API_URL` is not set at
  all, so the fetch is never even attempted.
- Its failure is already loud: the caller logs ERROR naming the URL, and `__main__.py` follows with
  *"serving /health and /manifest only until POST /config"*. Nothing is silently wrong.

**Not fixed in Phase 8's deploy round, deliberately.** Unlike C-72 there is no existing config key to
honour: the marine service has no `verify_tls` setting of its own for its outbound call to the API,
and the connection is described by a single environment variable (`CLEARSKIES_MARINE_API_URL`).
Deciding how the marine service should be told whether to verify the API's certificate — a new
setting, or trust derived from the URL, or an explicit CA path — **adds a config key, which is
trigger 7.** That is a design question, and this deploy phase is the wrong place to answer it.

**What was done instead, and why it is sufficient for now.** The first config was delivered by
`POST /config` — byte-identical to what the API's push sends, since `GET /setup/marine/config` and
the push are built by the same `_build_marine_service_config_payload()` (API-MANUAL §19.5, *"one
serializer, both paths"*). The payload was fetched from that endpoint and posted verbatim. Verified
landed: `marine.conf` written (4,031 bytes, mode 0640), grid-sizing chain ran to completion, runner
started.

**The standing lesson, third instance this phase.** C-72, C-73 and the same-host trust claim in
`OPERATIONS-MANUAL.md:1131` (*"For same-host deployments the API accepts this certificate without
verification (localhost trust)"* — also not implemented) are all the same shape: **TLS verification
was decided per-call-site rather than per-connection, and every site that was not the one someone
tested got the library default.** A connection between two Clear Skies services should have exactly
one place that decides whether its certificate is verified. Worth an ADR rather than a third
point-fix.

---

## C-63 — CLOSED (stack `eda8fdd`)

`MARINE_SAME_HOST_URL = "https://localhost:8780"` now lives once, in a new
`weewx_clearskies_config/constants.py`. Both routers import it and neither imports the other, so the
house rule the duplication existed to protect still holds. The comment in `admin/routes.py`
explaining the deliberate duplication is removed — a comment describing a reversed decision is worse
than none. The two *other* local-copy comments in that file (the `_()` helper, the photo-sidecar
helper) are untouched; those duplications are real and still deliberate.

Full `8780` sweep after the change: one Python definition, plus a docstring example in
`wizard/state.py:251-252` (accepted URL formats, not a same-host default) and
`https://marine.example.com:8780` placeholders in two templates and a translatable help sentence.
The placeholders are operator-facing copy and the help sentence is a translation key — folding
either into the constant would break 13 locale files for no gain. Left, and named, rather than
absorbed.

---

## C-64 — CLOSED for what was in scope, with one limitation recorded rather than papered over (stack `e573a7e`, `0287950`; meta `d8c7c93`)

**Part 1 — the empty string no longer reaches the API.** `marine_service_save` sends
`marine_service_url` (and `marine_verify_tls`) only when the field is non-empty; omission is the
API's documented "leave it alone" signal. The wizard already did exactly this
(`wizard/routes.py:4177`) — checked, not assumed, so no wizard change was needed.

**Part 2 — both directions guarded**, using the saved marine locations from the
`GET /setup/current-config` response the section already fetches. No new endpoint, no new config key,
no new error mechanism. Blank URL with ≥1 saved location is blocked; adding a *new* location with no
`marine_service_url` is blocked. **Editing an existing location is deliberately not blocked**, so a
config already in that state — say from a hand-edited `api.conf` — stays repairable.

**The limitation, stated because it matters and was not in the original concern. Promoted to its own entry at the operator's instruction — see C-75, because an open item recorded inside a closed entry does not get found.** The API writes the
URL under `if apply.marine_service_url is not None:`, so **`None` means "leave the existing value
alone", not "clear it."** After this fix, clearing the field no longer persists a broken empty URL —
but it also cannot clear a saved one, and the operator sees the old value reappear on re-read. A true
"disconnect" needs an API-side sentinel distinguishing *omitted* from *explicitly cleared*, which is
a change to the `ApplyRequest` data contract — **trigger 4, not authorised here.** Documented in
API-MANUAL §19.2 and both operator-facing manuals rather than left as a surprise. **The half C-64
actually described — "an operator can disconnect the marine service and be told it saved" — is
closed:** nothing false is persisted and nothing false is reported.

**Verification** (baseline from a read-only worktree at `b7830bb`): ruff 174 errors before and after,
mypy 93 before and after, pytest **309 passed / 6 failed / 12 xfailed before AND after** — the same
six pre-existing failures (`test_registry` ×1, `test_wizard_earthquake_config` ×4,
`test_wizard_topology` ×1), none marine. Six behaviour smoke checks through a real `TestClient` with
the API client mocked all passed, including an explicit confirmation that the **pre-fix** payload
still validates with `marine_service_url=''` — the defect itself, reproduced before being fixed.

The apply payload was walked against the **real** `ApplyRequest` imported from the API repo, not
inferred from the template (C-67's lesson applied): `database`, `station`, `column_mapping`,
`column_units`, `marine`, `marine_service_url`, `marine_verify_tls`, `marine_service_secret` all
confirmed accepted under `extra="forbid"`.

**Two new English strings** were added and no locale files were touched — they belong to the C-69
round and are listed there.

**Adjacent finding not fixed, deliberately:** a blocked *add* can leave an orphaned
`marine-photos/<slug>.*` file and sidecar row, because the photo is written before the API is
contacted. Overwritten on a successful retry with the same name. Moving the guard earlier would
reverse the section's deliberate "photo upload must not be gated on API reachability" ordering — a
behaviour change, correctly declined.

---

## C-74 — the admin help text advertises port 8766 for the marine service, in all 13 locales (OPEN → C-69's round)

Found by the C-64 agent while rewriting adjacent operator copy, and correctly named rather than
silently fixed.

`help.admin.marine_service.body` tells the operator that the same-host marine service address is
**`https://localhost:8766`**. It is `8780` everywhere else — the port registry, `api.conf`, the
wizard, the admin's own placeholder text, and the running service.

**8766 is not a typo for 8780. It is a real port that was deleted.** ARCHITECTURE.md's port registry:
*"Removed ports (ADR-058, 2026-06-14): Port 8766 (Realtime BFF main) and 8082 (Realtime BFF health)
are eliminated. The realtime service has been merged into the API."* So the help text hands the
operator the address of a service that has not existed since June, and an operator who follows it
gets a connection refused with no clue why.

**C-66's pattern for the third time this phase** — an answer moved and one surface explaining it did
not follow. Same family as C-72 (the proxy that ignored the key three manuals documented) and C-73.

**Routed to C-69's locale round, not fixed here.** The string lives in all 13 locale catalogues; the
C-69 round is the one that touches them, and the operator directive is explicit that locale work is
its own round and must not be folded into a deploy phase. The same wrong port in
`docs/OPERATOR-MANUAL.md` **was** fixed (stack `0287950`), because it is not a locale file and sat
inside a sentence that had to be rewritten anyway.

**Also fixed in `0287950`:** `docs/OPERATOR-MANUAL.md` told the operator *"Leave blank to
disconnect."* That was never true — it is the exact instruction that leads into C-64's defect.

---

## C-75 — there is still no way to *disconnect* the marine service; `None` means "leave alone", not "clear" (OPEN → needs an operator decision, data-contract change)

Split out of C-64's closure at the operator's instruction, 2026-07-26, because it is an **open** item
and was recorded inside a **closed** entry, where it would not be found by anyone scanning for open
work.

**The finding, in the C-64 agent's own words:**

> The API writes the URL under `if apply.marine_service_url is not None:` — **`None` means "leave the
> existing value alone", not "clear it"**. So after the fix, clearing the box no longer writes a
> broken URL, but it also does not clear a saved one; the operator sees the old URL reappear on
> re-read. A real "disconnect" needs an API-side sentinel — a data-contract change, out of scope and
> not authorized. Documented explicitly in API-MANUAL §19.2 and both operator-facing manuals rather
> than left as a surprise.

**What C-64 did and did not close.** C-64's stated defect was *"an operator can disconnect the marine
service entirely by clearing a field, and the UI reports success."* That is closed: the empty string
no longer reaches the API, nothing false is persisted, and nothing false is reported. What is **not**
closed is the capability the operator was reaching for when they cleared the field. Clearing it is
now correctly a no-op — but it is a *silent* no-op with respect to the saved value, and the old URL
reappears on the next read.

**Why it was not fixed.** `ApplyRequest.marine_service_url` is `str | None = None`, and every consumer
reads `None` as "not supplied — leave the persisted value untouched". Distinguishing *omitted* from
*explicitly cleared* requires a third state on the wire. Every option changes the contract:

| Option | Cost |
|---|---|
| A sentinel value (e.g. `""` meaning "clear") | Reverses today's meaning of `""`, which is precisely what C-64 just stopped. Any other client sending `""` by accident would now disconnect the service. |
| A separate boolean (`marine_service_disconnect: bool`) | A new field on `ApplyRequest`, and a new state the wizard, admin and `GET /setup/current-config` all have to agree on. |
| `Unset` sentinel / `model_fields_set` | Least invasive on the wire, but changes how *every* optional apply field is interpreted, not just this one. |

All three are **trigger 4** — a change to a data contract between components, in field names,
shapes or nullability. Not authorised, and deliberately not decided by the coordinator.

**Current operator workaround, which does work:** edit `marine_service_url` out of
`/etc/weewx-clearskies/api.conf [providers]` directly and restart the API. The companion proxy then
mounts no marine routes and marine capabilities drop out of `GET /api/v1/capabilities`, which is the
documented unconfigured state. So the capability is not *absent* from the system, only from the UI.

**Documented rather than left as a surprise** — API-MANUAL §19.2 and both operator-facing manuals now
state the blank-field semantics explicitly (stack `0287950`, meta `d8c7c93`). The Operator Manual
previously said *"Leave blank to disconnect,"* which was never true and is the exact instruction that
led into C-64's defect; that sentence is gone.

**Recommendation when this is taken up:** option B, a separate explicit boolean. It is the only one
that does not overload an existing value's meaning, and overloading `""` is what produced C-64.
Needs operator approval before any of it is written.

---

## C-76 — a failed WW3 fetch degrades SWAN to a calm boundary and the run is published anyway (DECIDED BY OPERATOR 2026-07-26 — never substitute; fix dispatched)

Found by the coordinator watching the marine service's **first** SWAN cycle, 2026-07-26 08:26.

```
WARNING weewx_clearskies_marine.providers.nearshore.swan:
        SWAN: WW3 boundary data unavailable; SWAN will use calm boundary
  caused by: httpcore.ConnectTimeout: _ssl.c:983: The handshake operation timed out
  at providers/marine/wavewatch.py:527  ww3_boundary = wavewatch.fetch(...)
```

**First, the part that is NOT a problem — measured before concluding anything, per the standing rule
about not diagnosing a systemic fault from one log line.** WaveWatch III is fetched from PacIOOS's
ERDDAP server in Hawaii (`pae-paha.pacioos.hawaii.edu`), a long-haul TLS connection. On the old 8767
service it has worked consistently — successful fetches at 22:52, 01:02 and 07:03 today, *"WaveWatch
III forecast fetched: 25 timestep(s) for grid=ww3_global"* each time — and across its **entire**
journal it has logged the calm-boundary warning **zero** times. So this was a transient handshake
timeout on one attempt, not a broken endpoint and not something the move to the marine service
caused. The provider code is byte-identical to what has been running for weeks.

**The actual concern is what happens next, and it is pre-existing.** WW3 supplies SWAN's **deep-water
boundary spectrum** — the swell arriving from offshore. When the fetch fails, the run does not fail:
it substitutes a **calm boundary**, meaning zero incident swell energy, and continues. The cycle then
completes normally, writes `forecast_cache.json`, and is served through the API to the dashboard.
Nothing in the published payload records that the run had no swell boundary.

The result is a forecast that is **wind-sea only**. At a spot like Huntington Beach Pier, whose surf
is overwhelmingly swell-driven, that is not a degraded answer — it is a wrong one, and it is
presented with the same confidence as a good one.

**This is the shape the operator has already ruled against** (SURF-PUBLISH-RESULTS-ONLY §2): *"the
model either works, or it doesn't... these fallbacks are not fallbacks, they are smoke and mirrors
that should never have existed. They were never discussed in planning, hide problems."* The
convergence gate already implements the right pattern for a different failure — a run that fails
convergence *never persists hotstart or overwrites the forecast cache*. A run with no boundary
condition arguably deserves the same treatment, or at minimum a flag on the published payload so the
surf endpoint can report `modelStatus: "unavailable"` rather than a confident flat forecast.

### DECIDED BY OPERATOR, 2026-07-26 — in chat, verbatim

> "again this is one of those false fallbacks that should not happen... again if we cannot
> successfully it should retry but in no case substitute bogus data like a calm boundary."

**This supersedes the "recorded, not fixed" disposition below**, which was written before the ruling
and is kept only to show what the coordinator's reasoning had been and why it needed an operator
decision rather than a coordinator one. The ruling supplies exactly the authorization that was
missing: the change is triggers 2 and 4, and the operator has made it.

**Scope of the fix, as dispatched:**

- A failed WW3 fetch produces **no output** for that cycle — no SWAN run on a substituted boundary,
  no hotstart persisted, no `forecast_cache.json` overwrite. The previous good forecast stays in
  place with its own older `run_time`: stale but honest.
- Logged at **ERROR**, not WARNING. It is a failed run, not a degraded one.
- It follows the **existing convergence-gate precedent in the same file** rather than inventing a
  mechanism — a run that fails convergence already never persists hotstart or overwrites the cache.

**On the "it should retry" half of the ruling — retry already exists, twice over, and the
implementer was told not to add a third.** `providers/_common/http.py` gives every provider
`max_retries=2` (3 total attempts, 0.5 s base, factor 2.0, 5.0 s cap, jittered), and connection-level
failures — DNS, TCP, TLS — already trigger it, so the fetch that failed had already made three
attempts. At the cycle level the marine runner re-checks every 300 s, so a skipped cycle retries
naturally on the next check. Adding a retry loop or changing the interval would be trigger 6 and is
outside the ruling. So the entire change is the second half: do not substitute.

**Explicitly NOT harmonised with it:** the CO-OPS handling ~20 lines below sets
`tide_predictions = None` on failure and lets SWAN run without WLEVEL, carrying its own "do NOT fall
back to MLLW" comment. That is a genuinely optional input; the deep-water boundary spectrum is not.
The asymmetry is deliberate and now carries a comment saying so, to stop a future reader tidying the
two into one shape.

**A sweep for sibling patterns was ordered with the fix — report only, fix nothing.** The operator's
"*again* this is one of those false fallbacks" says this is a class, not an instance. Each hit needs
its own ruling, because some substitutions are legitimate — the CO-OPS one is the proof.

**Not fixed in Phase 8, and the reasoning is not "no time."** Changing a calm-boundary run from
*published* to *withheld* changes what the model is responsible for producing under a named failure
condition, and adds a state to the payload contract the API reads — **triggers 2 and 4.** It is also
squarely a physics-behaviour decision about what the model should do when an input is missing, which
is the operator's to make, not a deploy phase's. Recorded here with the evidence so it can be decided
on its merits.

**It does, however, gate T8.6 right now.** Any end-to-end verification must confirm that the run
whose data is being checked had a **successful** WW3 fetch. Verifying the marine surface against a
calm-boundary cycle would reproduce, exactly, the mistake C-08 exists to prevent — measuring a
payload the broken path produced and concluding the path works. Added to the T8.6 checklist as a
precondition, not an afterthought.

**Recommendation when taken up:** carry a boolean on the run record (something like
`boundary_source: "ww3" | "calm"`), let the existing `modelStatus: "unavailable"` machinery surface
it, and do not invent a second reporting mechanism. The plumbing for an honest "no answer" already
exists from SURF-PUBLISH-RESULTS-ONLY; this failure mode simply never got wired into it.

---

### Two live confirmations recorded here because this is where they were observed

**C-71 is proven end-to-end.** The marine service's own SWAN runner logged, on its first real cycle:

```
INFO weewx_clearskies_marine.services.swan_runner: SWAN runner: OMP_NUM_THREADS=6
```

That value travelled `api.conf [swan]` → `_serialize_swan_section()` → `POST /config` →
`marine.conf` → `SwanConfig` → the SWAN process environment. Had T8.2b deleted the `[swan]` section
as written, this line would read `OMP_NUM_THREADS=16` and the box would be in swap.

**The stale-hotstart recovery works, and is worth noting because C-70 predicted this exact
interaction.** The marine service inherited `/var/run/weewx-clearskies/swan/level2_hotstart.dat` from
the old 8767 service and logged:

```
INFO    SWAN level2: using hotstart from previous run
WARNING SWAN level2: crashed with hotstart loaded — deleting stale hotstart and retrying cold
INFO    SWAN runner: OMP_NUM_THREADS=6
```

It detected the incompatible inherited state, discarded it, and restarted cold — loudly, and without
publishing anything from the crashed attempt. This is the handover working as designed. It also
retroactively justifies C-70's decision to stop the old service *before* the first marine cycle: had
both been writing that file concurrently, this recovery would have been racing a live writer.

---

## C-55 / C-59 — the Phase 8 assessment (DELIVERED 2026-07-26). One endpoint is broken today, one should move, two stay.

C-55 asked for **one assessment** of the four remaining `/setup/marine/*` endpoints rather than a
fifth individual escalation, and C-59 was sequenced with it because `rasterio`'s dependency question
travels with whichever way the upload endpoint lands. This is that assessment, by the coordinator,
from reading the code on both sides.

**The governing pattern is already settled** — C-40, C-41, C-42, C-48 and C-54 each answered a
version of "is answering this the API's job or the marine service's?", and ARCHITECTURE.md now
carries the result as a standing invariant: *"when the API needs marine data for something that is
not a dashboard route — a wizard lookup, a setup-time question, an operational check — the answer is
a pass-through in the API... the marine service exposes it, the manifest or an explicit proxy route
carries it, the API fronts it."* So no new principle is needed here, only its application, and per
`rules/clearskies-process.md` §"Over-triggering is a failure mode too" applying a settled ruling to
the next instance is not a new decision.

### Verdicts

| Endpoint | Verdict | Basis |
|---|---|---|
| `POST /setup/marine/bathymetry/upload` | **MOVE — and it is broken today, not merely misplaced** | below |
| `POST /setup/marine/discover-structures` | **MOVE** | below |
| `GET /setup/marine/species` | **STAY** | reference data for the wizard's picker |
| `GET /setup/marine/species-database` | **STAY** | same |

### 1. `bathymetry/upload` — a live defect in split-host deployment, not a tidiness question

This is the finding that changes C-55 from a cleanup item into a defect report.

```
weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py:4259
    _OPERATOR_BATHY_DIR: Path = Path("/etc/weewx-clearskies/operator_bathymetry")
    _OPERATOR_BATHY_TIF: Path = _OPERATOR_BATHY_DIR / "operator.tif"
:4421
    _OPERATOR_BATHY_DIR.mkdir(parents=True, exist_ok=True)

weewx-clearskies-marine/weewx_clearskies_marine/services/bathymetry_resolver.py:915
    _OPERATOR_BATHY_DIR = Path("/etc/weewx-clearskies/operator_bathymetry")
:964
    tif_path = _OPERATOR_BATHY_DIR / "operator.tif"
```

**Same path string, two different machines.** The API writes the uploaded GeoTIFF to
`/etc/weewx-clearskies/operator_bathymetry/operator.tif` on the **weewx host**. The only code that
reads it is the marine service's bathymetry resolver, running on **librewxr**. Nothing copies the
file between them.

So on the split-host topology this plan exists to support, operator-supplied bathymetry — priority
(1) in the resolver's documented source chain, ahead of NCEI and USGS — is written where nothing will
ever read it. The upload returns success. The operator is told their bathymetry was accepted, and the
model silently uses NCEI instead. **Same failure family as C-64 and C-72: the UI reports success for
something that did not happen.**

This was invisible until today because SWAN used to run inside the API process, on the same host that
received the upload. The paths were correct when they were written. **C-66's lesson for the fourth
time this phase** — the computation moved hosts and a surface that depended on co-location did not
move with it.

Moving the endpoint to the marine service resolves it structurally: the file is then written by the
process that reads it, on the host that reads it, and no cross-host copy has to be invented.

**C-59 dissolves rather than being answered.** C-59 asked whether `rasterio` should be declared in
the API. If the endpoint moves, the dependency moves with it — and per
`rules/clearskies-process.md` §"Moving a module moves its dependencies", carrying an existing import
along with the code that requires it *"is the mechanical consequence of a move"* and needs no
separate approval. `rasterio` is declared in the marine service's `[nearshore]` extra as part of the
move, and the API declares nothing. This is exactly why C-59 was sequenced behind C-55 rather than
decided first — deciding the dependency first would have declared a package into a repo that is
about to stop needing it.

**C-59's separable half is fixed regardless of when the move lands.** `endpoints/setup.py:4370-4371`
tells the operator to *"Install rasterio (add to `[nearshore]` extra)"* — an extra Phase 6 deleted
from the API repo, so the instruction cannot be followed. Same defect class as C-66 and C-74:
install guidance naming a component that no longer exists.

### 2. `discover-structures` — moves, and C-55's own stated doubt resolves against staying

C-55 recorded this one as *"Not a marine provider module — it queries OSM, which the API queries for
non-marine purposes too. **Needs a reading, not an assumption.**"*

**The reading was done and it says the opposite.** Every OSM/Overpass reference in the API:

```
grep -rniE "overpass|openstreetmap|nominatim|osm" weewx_clearskies_api/ --include=*.py -l
  weewx_clearskies_api/config/marine_config.py
  weewx_clearskies_api/endpoints/setup.py          (_OVERPASS_URL, :3260)
```

Two files, both marine. **The API has no non-marine OSM consumer at all**, so the reason offered for
leaving it in place does not exist. Recorded plainly because the concern explicitly asked not to
assume it.

On substance the case is stronger than "not disproven": the structures this endpoint discovers exist
to become SWAN `OBSTACLE` commands and to size the L3 alongshore shadow zone. The consumer is the
wave model, wholly inside the marine service. It is a setup-time marine question answered by an
outbound query — the exact shape of `/discovery/buoy-stations`, `/discovery/tide-stations` and
`/discovery/ofs-model`, which C-42 already moved and the API already proxies.

### 3. `species` and `species-database` — stay, with a duplication flagged

C-55's own read holds: reference data, not computation and not a provider fetch. The wizard needs a
species list to render a picker; that is operator-configuration support, which C-40 already
established the API keeps.

**But `data/species.yaml` now exists in both repos** — the API's copy feeds the wizard picker, the
marine service's feeds `score_fishing()`. Two copies of a reference dataset with no mechanism keeping
them in step: an operator could pick a species in the wizard that the scorer does not know. Not
urgent, not a Phase 8 item, and **not** grounds to move the endpoint — recorded so it is found rather
than rediscovered.

### Disposition — assessment delivered now, implementation sequenced after T8.6

C-55 asked Phase 8 for an **assessment**; that is what this is, and it is complete. On the
implementation:

- Both moves are **setup-time** endpoints. Neither is on the runtime dashboard path, so neither
  affects T8.6's end-to-end verification, and doing them before T8.6 would add risk to the deploy
  without advancing it.
- **They land in Phase 8, after T8.6** — not deferred out of it. The plan's NO DEFERRAL RULE applies
  and there is no reason to invoke an exception.
- The `rasterio` error-message half of C-59 is separable and can be fixed with the move.

**One point genuinely needs the operator, and it is not the move.** The move is settled by C-42's
pattern. What is not settled is **what to do about bathymetry an operator already uploaded** before
this was found — on this installation, `/etc/weewx-clearskies/operator_bathymetry/` on weewx should
be checked, and if a file is there it has never been used by the model and the operator has been
running on NCEI data believing otherwise. That is a data-provenance question, not an engineering one.
Checked and reported separately.

**Checked immediately, and the answer is reassuring: nothing was lost.**

```
weewx:    ls /etc/weewx-clearskies/operator_bathymetry/  -> No such file or directory
librewxr: ls /etc/weewx-clearskies/operator_bathymetry/  -> No such file or directory
```

The directory has never been created on either host, so no operator has ever used the upload feature
on this installation and no bathymetry has been silently ignored. The defect is real and would have
bitten the first operator to try it — but there is **no data-provenance question to answer and
nothing to remediate**. Recorded with the commands, because "probably nobody used it" is an
assumption and this is a measurement.

---

## C-76 — CLOSED (marine `c2461ff`, deployed)

Fixed per the operator's ruling. The WW3 `except` block no longer builds
`{"forecast": [], "grid": "unavailable", "model_run": ""}`; it logs **ERROR** and **raises**.

**Verified independently by the coordinator, not taken from the implementer's report:**

- The raise sits at swan.py ~1503; `_SWANRunnerWithCleanup` is constructed 300+ lines later (~1811)
  and cache persistence later still (~1920-2050). Nothing between them can write a hotstart or
  overwrite `forecast_cache.json`, so the convergence gate's guarantee is preserved.
- `run_all_spots()` — the only caller of `_run_all_spots_locked()` — wraps it in `try: ... finally:`
  with **no `except`**. Read directly; the exception propagates.
- It lands in `service.py:313`'s `except Exception: logger.error(...); time.sleep(300); continue`,
  which does **not** advance `last_hrrr_cycle`. So the same HRRR cycle is retried every 5 minutes
  until it succeeds — the operator's requested cadence, from machinery that already existed.
- `ruff` 0 issues before and after. `mypy` 171 pre-existing errors, byte-identical before and after.
  `pytest tests/` 52 passed, 2 skipped.

**Why raising beats returning, and why it is recorded:** a substituted calm boundary — or a quiet
return — lets the function finish "normally", which **advances `last_hrrr_cycle`**. The bad cycle
would then never be retried until the next HRRR cycle hours later, and the wind-sea-only forecast it
produced would be published and cached as if valid. The failure looking like success is the whole
defect, not a side effect of it.

**Coverage gap named, not built around:** no test exercises the new raise path. The repo has no
tests for `swan.py` or the runner at all. Flagged for T8.9.

**Reset performed after the fix, at the operator's instruction** — the in-flight cycle was running on
a calm boundary and its output was worthless. Service stopped, `forecast_cache.json` **archived**
(not deleted) to `/var/run/weewx-clearskies/swan-precleanup-20260726T083936Z/`, all hotstart files
and L1/L2/L3 work dirs removed, plus a stale `surfbeat_huntington-city-beach-pier` work directory
dating from 23 July that would have fed carry-forward IG state three days out of date. Bathymetry
caches, `swan_grid_sizing.json` and `spot_profiles/` deliberately **kept** — expensive to rebuild and
unaffected by the boundary failure. Service restarted at `c2461ff`, confirmed cold:
`{"last_run": null, "spots": ["huntington-city-beach-pier"]}` and *"SWAN: no usable on-disk forecast
cache — starting cold"*.

This also gives **C-08** the genuinely fresh run its energy-closure measurement requires.

---

## C-77 — bathymetry falls back to a fabricated uniform 15 m flat seabed (OPEN → NEEDS AN OPERATOR RULING; same class as C-76)

Found by the C-76 sweep, which the coordinator ordered precisely because the operator's wording —
*"**again** this is one of those false fallbacks"* — said this was a class rather than an instance.
It is the one hit that is unambiguously the same class as WW3, and it is arguably worse.

**The behaviour.** `providers/nearshore/swan.py` ~249-485, the per-level CUDEM download chain. When
**every** bathymetry source fails — operator-supplied file, NCEI regional DEM via OPeNDAP, USGS Great
Lakes topobathy, NCEI CRM — the function returns `{}` and logs *"SWAN will use uniform 15m depth"*
(WARNING or ERROR depending on branch). The run then proceeds, executes SWAN, passes the convergence
gate, **persists hotstart, and overwrites `forecast_cache.json`.**

**Why this is the same shape as C-76 and not an optional-input degradation.** Bathymetry is SWAN's
`BOTTOM` input. It is what makes a nearshore wave model a nearshore wave model — shoaling,
refraction, depth-limited breaking and the breaking-depth criterion the entire L3 grid is sized
around all derive from it. A **flat 15 m seabed is not a missing input; it is a fabricated one.** The
model runs happily and produces a smooth, plausible-looking forecast for a beach that does not exist.
Every depth-dependent result — break point, surf-zone width, peel angle, the `1.3 × Hs / 0.73`
handoff — is then computed against fiction.

Compare the real profile this spot actually has, measured today at 08:25: the 30 m contour 6,017 m
out, the 15 m contour 2,433 m out, and 1.8 m depth just 85 m off the beach. A uniform 15 m plane
replaces all of that with a flat floor that never shallows, so waves never feel the bottom and never
break where they really break.

**It also carries the paper trail CLAUDE.md warns about.** The module docstring at ~32-33 records
this as a deliberate *"Key design decision"*: *"CUDEM bathymetry: passed as an empty dict... defaults
to a uniform 15m ocean depth."* Per the named non-excuse, *"a governing document says so"* is not
authorization — a document describing a superseded or wrong design *"is exactly how a wrong
architectural change acquires a paper trail that looks legitimate."*

**The right precedent already exists in this codebase, one module away.**
`enrichment/bathymetry.py`'s `find_depth_contour_distance()` (LC-10) faces the same temptation for a
closely related quantity and **raises `ValueError` naming the spot, bearing and target depth** rather
than substituting a hardcoded distance. Two functions, one contour-distance and one depth-grid,
opposite answers to the same question.

**Not fixed. This needs the operator's ruling, exactly as C-76 did.** Removing a substituted model
input changes what the model does under a named failure condition — triggers 2 and 4 — and it is a
physics-behaviour decision about a required input, which is the operator's call and not the
coordinator's. C-76's ruling was explicitly about the calm boundary; extending it by analogy would be
the coordinator deciding a physics question on the strength of a phrase.

**Coordinator's recommendation:** treat it exactly as C-76 was treated — log ERROR naming every
source that was tried and failed, and **raise**, so the runner loop retries the same cycle every
5 minutes without advancing `last_hrrr_cycle` and without publishing. Bathymetry failures are far
more likely to be persistent than WW3's transient TLS timeout, but that argues *for* raising, not
against: a persistent inability to obtain a seabed should stop the model loudly, not fill it in.

**Mitigating fact, so the urgency is judged accurately and not overstated:** this path has almost
certainly never fired on this installation. All three bathymetry levels are cached on disk and the
runtime path reads the caches only — verified today, the grid-sizing chain logged
`CUDEM L1/L2/L3: cached bathymetry datum=NAVD88 source=ncei_regional` for all three levels and
downloaded nothing. The fallback would bite a **new** spot, or one whose cache was cleared, on a day
NCEI was unreachable. It is a live landmine rather than a live fire.

### The rest of the sweep — assessed as legitimate, no action recommended

Recorded so the class is closed rather than left half-open, and so nobody re-raises them:

| Site | Substitutes | Assessment |
|---|---|---|
| CO-OPS tide / WLEVEL (~1506) | `None` → SWAN runs without WLEVEL | **Legitimate.** Optional input, *omitted* not fabricated, carries an explicit "do NOT fall back to MLLW" comment (ADR-098). |
| OFS surface currents (~1589) | `None` | **Legitimate.** Optional forcing; absence is a documented SWAN-manual-safe default. |
| GFS wind hours 48-72 (~1453) | `None` → 0-48 h forecast | **Legitimate.** Produces a *shorter* forecast, visibly — it does not disguise a 48 h answer as 72 h. |
| Wave-setup profile (~1767) | tide-only WLEVEL | **Legitimate.** Degrades an enhancement, not a required input. |
| `swan_runner.py:3130-3159` | loud WARNING + degrade to single CURVE | **Already correct** — cites the 2026-07-23 0.01 m Hs and 2026-07-19 VDatum 0.0 m incidents by name and deliberately refuses the silent (0,0) substitution. Good precedent. |

The distinction that separates the two groups: **omitting an optional input is honest; fabricating a
required one is not.**

### ⚠ SUPERSEDED SAME DAY — OPERATOR RULING 2026-07-26 EXTENDS THIS TO EVERY INPUT

The table immediately above assessed CO-OPS, OFS, GFS and wave-setup as "legitimate optional-input
degradations." **The operator overruled that assessment in chat**, verbatim:

> "CUDEM failures would be the same issue, we cannot substitute bogus data. Actually none of these
> are allowed to be quite [quiet] failures... they all need to hold up model runs until they can be
> fetched correctly. Omission of any of that data results in inaccurate and therefore bogus
> information."

**The coordinator's distinction — "omitting an optional input is honest; fabricating a required one
is not" — is rejected.** The operator's position is that there are no optional inputs here: a SWAN
run missing tide, currents, or the 48-72 h wind is not a degraded-but-honest run, it is an
inaccurate one, and an inaccurate forecast is bogus regardless of whether the missing value was
fabricated or merely absent. That is a physics-accuracy judgement and it is the operator's to make.

**New rule for the marine model, applying to all of C-77 and superseding the table above:**

> **SWAN runs only when every one of its inputs is present.** Any input fetch that fails — WW3
> boundary, CUDEM bathymetry, CO-OPS tide/WLEVEL, OFS currents, GFS wind, wave-setup profile — logs
> ERROR and raises. Nothing is substituted, nothing is omitted, no partial run is published. The
> runner loop's existing handler retries the same HRRR cycle every 5 minutes without advancing
> `last_hrrr_cycle`, until every input is available. C-76's mechanism, applied to all of them.

`enrichment/bathymetry.py`'s `find_depth_contour_distance()` (LC-10) is the in-repo precedent: it
raises `ValueError` naming the spot, bearing and target rather than substituting.

### One question this raises that the coordinator will NOT decide, and is surfacing instead

**Transient unavailability and structural unavailability are not the same failure, and "hold until
fetched correctly" only terminates for the first.**

WW3 is global and CUDEM/NCEI covers the US coast, so a failure there is almost always transient — the
data exists and the fetch will succeed on a retry. That is the case the ruling is plainly aimed at,
and it is the case on this installation today.

**OFS is different: it is regional.** `WCOFS` covers the US West Coast; other models cover other
basins; **some coastlines are covered by no OFS model at all.** For such a spot, currents are not
temporarily unfetchable — they do not exist. The same is true of the USGS Great Lakes topobathy DEM
outside the Great Lakes. If those are treated as required inputs that hold the run, a spot in an
uncovered region **never produces a forecast at all**, and the retry loop spins every five minutes
forever.

This installation is unaffected — both configured locations carry `ofs_model: WCOFS` and are inside
its domain, verified in the pushed config — so it does not block the work now.

The distinction worth drawing when this is settled is between **"the fetch failed"** (retry, hold the
run — the ruling as stated) and **"no provider covers this location"**, which is a configuration fact
knowable at setup time rather than a runtime failure, and which arguably belongs in the wizard's
viability checks rather than in a retry loop. Recorded for the operator's decision; the implementer
has been told to report where the two cases are indistinguishable in the current code rather than to
invent a policy.

---

## C-78 — the convergence gate's own log fabricates the numbers an operator uses to judge a run (OPEN → Phase 8, small fix, disproportionate value)

Found by the coordinator reading the first clean marine SWAN cycle's journal, 2026-07-26 08:44. Two
lines, three seconds apart, describing the same L1 run:

```
SWAN convergence level1: overflow_count=0, accuracy=0.0%,   nan_count=0, valid_fraction=100.0%
SWAN convergence OK level=level1: accuracy=100.0%, valid_fraction=0.0%,  nan_count=0
```

The same run is reported as **0.0% accuracy** and **100.0% accuracy**, and as **100.0%
valid_fraction** and **0.0% valid_fraction**. Read either line alone and you would draw the opposite
conclusion from the other.

**Cause — `services/swan_runner.py`, and it is not a transposition.** The same unmeasured quantity is
given two different fabricated defaults:

```
3669:   accuracy_pct if accuracy_pct is not None else 0.0      # the detail line
3713:   accuracy_pct if accuracy_pct is not None else 100.0    # the "convergence OK" line
3698:   _frac_pct = (valid_fraction * 100.0) if valid_fraction is not None else 0.0
```

`accuracy_pct` is only populated for **stationary** runs (`3533: if is_stationary and accuracy_pct is
not None`). L1 is nonstationary, so it is `None` — and the two call sites invent opposite values for
it. `100.0` is the more damaging of the two: it prints **perfect convergence accuracy for a quantity
that was never measured**, inside the line whose whole purpose is to tell the operator the gate
passed.

**And `nan_count=0` at line 3711 is a hardcoded string literal, not a variable.** That line always
reports zero NaNs regardless of the actual count. The detail line above it reports the real one.

**Why this is the same class as C-76 and C-77, not a cosmetic nit.** The rule the operator set —
`rules/coding.md` §1 "A model runs on all its inputs or it does not run" — is that an unavailable
value must be reported as unavailable, never substituted. Here the substitution has moved from the
model's inputs into the model's **observability**, which is arguably worse: these are the exact lines
an operator reads to decide whether to trust a forecast, and they are the lines this project has
already misdiagnosed from twice. `reference/clearskies-dev.md` records the standing warning: *"Get the
whole timeline before concluding anything systemic from a single log line — a `nan_detected` line
next to ten successful runs is an intermittent, not a root cause. That mistake has been made twice on
this project."* Fabricated values in those same lines make that failure mode considerably easier to
fall into.

**Fix (small, no behaviour change):** report unmeasured quantities as unmeasured — `accuracy=n/a`
when `accuracy_pct is None`, `valid_fraction=n/a` when `valid_fraction is None` — rather than
inventing `0.0` or `100.0`; and make `nan_count` read the actual variable. No change to the gate's
pass/fail logic, which uses the real values and is not affected by any of this. Purely a matter of
the log telling the truth about what it knows.

**Not folded into C-77's round** — that work is in `providers/nearshore/swan.py` and this is
`services/swan_runner.py`; keeping them separate keeps each commit's evidence clean. Same phase.

---

## C-79 — when FINE bathymetry fails for a cluster, L3 keeps running on MEDIUM data instead of taking the architecture's own designed exit (OPEN → NEEDS AN OPERATOR RULING; triggers 2 + 3)

Surfaced by the C-77 implementer while scoping the bathymetry raise, and correctly escalated rather
than decided — the coordinator's ruling was to leave the behaviour untouched and record it.

**What happens today.** `services/grid_sizing_chain.py` calls `download_bathymetry_for_level()` three
times. L1 and L2 abort the chain on failure. **L3 does not.** When the FINE (10 m) download fails for
one cluster it logs ERROR, substitutes the **MEDIUM (100 m)** grid for that cluster's profile, and
carries on — writing `swan_grid_sizing.json` and every other spot's profile as normal. The cluster's
L3 grid stays **enabled** and is then run at 10 m resolution off 100 m bathymetry.

**Why this is NOT the same as C-76/C-77 and was deliberately left alone.** MEDIUM bathymetry is
**real measured seabed at coarser resolution**. The uniform 15 m default that C-77 removes is
**fabricated**. Treating "lower fidelity" and "made up" as the same thing would make the operator's
rule unfalsifiable, and the ruling is explicitly about substituting bogus data and omitting data.
Coarser real data is neither.

**Why it is still a finding.** The architecture already has a sanctioned answer to "we cannot get
fine bathymetry for this cluster", and this is not it. ADR-093 Amendment 2 §4, as recorded in
`ARCHITECTURE.md`: the setup-time viability test **disables L3 for that cluster**, which then runs
**L1 → L2 → SwellTrack from the ~15 m reference, "as an open beach does"** — and that state is
*recorded*, so an operator can see the spot has no fine grid.

What the code does instead is a **third state nobody designed**: L3 stays enabled, a 10 m
computational grid is driven by 100 m bathymetry, and nothing in the output says so. It is not the
designed degradation, it is not a failure, and it is invisible. A 10 m grid cannot resolve features
its own depth field does not contain, so the spot gets fine-grid *cost* and *apparent* fidelity
without fine-grid information.

**Not fixed, and not the coordinator's to fix.** Changing how a cluster's grid resolution is sourced,
or routing the failure into the viability test's L3-disabled path, is **trigger 3** (a model's
resolution) and **trigger 2** (what a component is responsible for). The operator rules.

**Coordinator's recommendation:** route a FINE-tier failure into the existing L3-disabled path rather
than inventing a substitution — the machinery, the fallback and the operator-visible state all
already exist, and it is the answer the architecture already gives. Explicitly **not** recommended:
aborting the whole apply chain, which would punish every unaffected spot for one cluster's failure.

---

## C-80 — the caches the runtime path trusts are written non-atomically (OPEN → Phase 8, small fix)

Found by the C-77 implementer while verifying that an aborted apply chain cannot leave a partial
cache. It can.

| Path | Write | Atomic? |
|---|---|---|
| `grid_sizing_chain.py:359` — `spot_profiles/{spot_id}.json` | `cache_path.write_text(json.dumps(...))` | **No** |
| `grid_sizing_chain.py:372` — `swan_grid_sizing.json` | `_SWAN_GRID_SIZING_CACHE_PATH.write_text(...)` | **No** |
| `swan.py:245, 398, 428, 459, 476` — bathymetry caches | direct `write_text` | **No** |
| `swan.py:820-824, 893-897` — `_persist_forecast_cache_to_disk` | temp file + `os.replace()` | **Yes** |

**The codebase already knows the right pattern and applies it to the forecast cache — but not to the
caches the SWAN runtime path reads and trusts.** A process kill mid-write during a `POST /config`
apply chain (OOM on a 5.7 GB box that already runs 20% over on its radar container, or a restart)
leaves a truncated `swan_grid_sizing.json` or profile JSON. The runtime path then reads it.

**Why this belongs with C-76/C-77 rather than in a general tidy-up.** Those concerns are about the
model never running on values it did not really obtain. A truncated cache is exactly that — a
substituted input arriving by a different route, and a worse one, because it looks like a valid
cache rather than a failure. The whole point of making the runtime path cache-only (ARCHITECTURE.md:
*"reads both caches only — zero CUDEM downloads, zero grid sizing, at runtime"*) is that those files
are trusted; trusted files must not be writable in a torn state.

**Fix:** apply the temp-file + `os.replace()` pattern already used by `_persist_forecast_cache_to_disk`
in the same file. No behaviour change, no new dependency, no contract change — `os.replace()` is
atomic within a filesystem and all these paths are under `/etc/weewx-clearskies/`. Kept out of C-77's
commits so each change's evidence stays clean.

---

## C-08 — CORRECTED: following its own instruction literally would have measured the rejected algorithm (OPEN → measurement ready, awaiting the fresh run)

C-08 and the plan's Phase 4B block both say: *"Re-run `scripts/verify_partition_duplication.py`
against a fresh model run after deploy; closure should sit at ≈1.0 rather than a 1.63 median."*

**Followed literally that measures the wrong thing, and would have produced a confidently wrong
answer.** Found by the coordinator reading the script before running it, 2026-07-26.

**Three reasons the existing script cannot validate the fix:**

1. **It calls `decompose_spectrum()` itself** (`scripts/verify_partition_duplication.py:59`) rather
   than reading the payload's own `components`. `decompose_spectrum()` is the algorithm **T4B.2
   rejected**; it has had no production caller since `12f9ddc`, because SWAN's own PT* watershed
   partitions are the source at every live site. Running it against a fresh payload re-measures the
   rejected algorithm and would still return ≈1.6 — and that number would then have been read as
   "the fix did not work." **This is the same shape of mistake C-08 exists to prevent:** measuring
   something other than the thing under test and reading the result as if it settled it. The
   original concern was about the *payload* being stale; the script being pinned to the old
   algorithm is a second, independent version of the same trap.
2. **The published payload is trimmed.** SURF-PUBLISH-RESULTS-ONLY drops `energy`, `freqs_hz`,
   `dirs_deg` and `handoff_by_transect` at the HTTP serving boundary, so a fetch of
   `GET /surf/{id}/forecast` has no spectra left to integrate. The untrimmed data exists only in the
   model host's own `forecast_cache.json`.
3. **It imports from `/home/ubuntu/repos/weewx-clearskies-api`**, where the SWAN code no longer
   exists after the marine separation.

**Replacement: `scripts/verify_energy_closure_deployed.py`.** It measures what C-08 actually wants —
for every timestep, the summed m0 of the components **the model published** (PT*-derived) against
the m0 of the spectrum they came from, read from librewxr's untrimmed cache.

**No silent skipping.** A timestep with no spectrum, no `components` key, empty components (the PT*
gap the no-silent-fallback rule produces), or a non-positive m0 is **counted and named as
unmeasurable**, never quietly dropped from the sample. A run where most timesteps are unmeasurable
prints `NO MEASURABLE TIMESTEPS — this is a FAIL, not a pass` and exits non-zero. A closure figure
computed from a handful of surviving timesteps, with the rest silently discarded, would be exactly
the kind of flattering number this concern was opened to prevent.

**Pass criterion:** median closure within 0.85-1.15 of unity. Baseline printed alongside for
comparison: the broken `decompose_spectrum()` measured median 1.626, max 2.271, 65/65
multi-component timesteps over 105% (n=67, 2026-07-25).

`verify_partition_duplication.py` is **kept, not deleted** — it remains the direct measurement of the
two algorithms against each other, which is what it was written for and what
`scripts/compare_partitioning.py` still uses `decompose_spectrum()` for. It is simply not the tool
for this question.

---

## C-81 — The SWAN boundary collapses a multi-swell sea into ONE parametric train, so the surf forecast can never show more than one swell (OPEN → BLOCKER, NEEDS AN OPERATOR RULING)

**Found by the operator, 2026-07-26, from a Surfline screenshot** — not by any check in this plan. Every
automated check in Phase 8 passed while this was live, which is the most important fact about it.

### What reality says vs what we publish

Surfline, Huntington City Beach Pier, same day:

| | Surfline | Ours (`data.spectralComponents`) | Verdict |
|---|---|---|---|
| Surf height | **4–6 ft, "chest to overhead"** | **3.83–4.24 ft, essentially flat for 14 h** (max 6.04 ft once in 67 steps) | **FAIL** — at/below the bottom of the range, never reaches overhead, and does not vary |
| Swell 1 | 1.5 ft **19 s** SSW **197°** | 1.68 ft 20.0 s **279.6° (W)** | period ✓, **direction 82° wrong** |
| Swell 2 | 1.4 ft **12 s** S 187° | 0.38 ft 12.5 s 177.1° | period+dir ✓, **height 3.7× low** |
| Swell 3 | 1.5 ft **9 s** S 181° | 0.49 ft 10.5 s 205.6° | **height 3× low** |
| — | (not listed) | **2.26 ft 7.7 s 262.6° wind_swell — our LARGEST component** | Surfline does not see it |

A 20 s groundswell from **279° (due west)** at Huntington is physically implausible on its face — that
window is shadowed by Catalina and Palos Verdes. Surfline has it at 197° SSW, which is the real austral
swell window.

### The mechanism

`services/swan_formats.py:1555–1631`, `ww3_to_swan_boundary()`. Its own docstring states it plainly:

> *"Converts WW3 **scalar** wave parameters (Hs, Tp, Dir) into SWAN's TPAR boundary spectrum file. WW3
> data is available as scalar parameters (**not a full 2-D directional spectrum**) from
> wavewatch.fetch(); this function **synthesises a JONSWAP-shape parametric spectrum** with a fixed
> directional spreading of 30°."*

And lines 1596–1600 narrow it further — having taken the bulk sea state, it **overwrites** it with a
single swell train:

```python
# Prefer swell parameters (lower-frequency energy that dominates breaking)
if pt.swellHeight is not None and pt.swellPeriod is not None:
    hs = pt.swellHeight
    tp = pt.swellPeriod
    mwd = pt.swellDirection if pt.swellDirection is not None else mwd
```

So **one** Hs/Tp/Dir triple, **one** JONSWAP peak, **one** fixed 30° spread, per timestep. SWAN's
incident spectrum is unimodal *by construction*. Everything downstream is then correct and useless:
SWAN faithfully propagates one swell, the PT\* watershed partitioner faithfully finds one partition,
and the published `multiSwell` faithfully reports one component.

### The decisive evidence that this is input loss, not partitioning

Two swell-decomposition products exist in the *same* response payload, from *different* sources:

- `data.spectralComponents` ← decomposition of the **real NDBC buoy spectrum** (`providers/buoy/ndbc.py:992`) → **4 components**, real `frequencyRange` values
- `forecast[].multiSwell` ← decomposition of the **SWAN** deep-water SPECOUT (`services/surf_1d_pipeline.py:23`, emitted `endpoints/surf.py:909`) → **1 component** in 65 of 67 timesteps, `frequencyRange: [0.0, 0.0]`

**A real buoy at the same place and time resolves four swell trains; SWAN resolves one.** The ocean is
multi-modal, our model input is not. That is conclusive.

### Why the dashboard shows the worse of the two

`repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx:40–41`:

```
// Swell rule (FAIL CONDITION): NEVER use data.spectralComponents. Only
// forecast[0].multiSwell. If null/empty → "No model swell data available".
```

The dashboard is *explicitly forbidden* from displaying the 4-component buoy decomposition and must
show only `multiSwell`. **The rule's intent is right** — do not pass observed buoy data off as a model
forecast (SURF-23). But it trusts a model that structurally cannot produce what it is being asked for.
The four-component answer is sitting in the payload, banned from display, while the card shows one.

### Why the surf height is low AND flat — same root cause

Our two largest components are groundswell 1.68 ft @ 20.0 s and **wind_swell 2.26 ft @ 7.7 s**. Our
largest single component is short-period wind sea. Total Hs comes out near Surfline's combined swell
(≈2.7 ft vs ≈2.54 ft) — which is exactly the coincidence that made the coordinator initially and
wrongly call it a match — but the energy sits at **the wrong place in the spectrum**. The same Hs at
7.7 s breaks much smaller and weaker than at 12–19 s, and carries no set structure. Hence: face height
pinned at ~4 ft, flat across 14 hours while Tp swings 5.2→10.0 s, and no "overhead" sets.

Dropping Surfline's 12 s (1.4 ft) and 9 s (1.5 ft) trains alone removes ~40% of swell Hs:
√(1.5²+1.4²+1.5²) = 2.54 ft → 1.5 ft.

### Why this needs an operator ruling and was NOT fixed

Changing how WW3 enters SWAN is architectural on two counts:

- **Trigger 1** — the boundary condition is a model input specification; replacing a synthesised
  JONSWAP with partitioned or full 2-D spectra changes what the model is being asked to solve, and the
  fixed 30° `DSPR` is a coefficient inside it.
- **Trigger 4** — `wavewatch.fetch()`'s return shape would have to carry per-partition or 2-D spectral
  data across the provider boundary; `BOUNDSPEC ... VARIABLE PAR` would likely become file-based 2-D
  spectra. Field names, shapes and units all change.
- Plausibly **trigger 7** as well, if a different WW3 product/endpoint must be fetched.

Per the named non-excuse, the docstring recording this as the current design is **not** authorization —
it is the paper trail that made it look intentional and survivable.

### Coordinator's recommendation (for the operator to accept or reject)

1. **Feed WW3's partitioned swell trains, not its bulk scalars.** NOAA's WW3 output carries multiple
   wave partitions (typically up to 3 swell partitions plus wind sea) as separate Hs/Tp/Dir sets.
   Emitting one TPAR-equivalent boundary per partition, or a superposed multi-peak boundary spectrum,
   restores multi-modality without leaving the parametric world.
2. **Better, if the source supports it: fetch WW3 2-D spectra** at the boundary nodes and use
   `BOUNDSPEC ... FILE` with real directional spectra. The `domain_boundary_nodes` parameter at
   `swan_formats.py:1557` is already reserved for exactly this and is currently `# noqa: ARG001`
   unused — the design anticipated it.
3. **Do not "fix" this by pointing the dashboard at `spectralComponents`.** That would show real buoy
   observations in a forecast card and would be a genuine regression against SURF-23, trading a wrong
   number for a dishonest one.
4. **Stop publishing a 279° groundswell at a west-shadowed spot** — investigate whether the direction
   error is in the NDBC decomposition, the swell-window/shadowing logic, or the buoy-to-spot transfer,
   *after* the boundary question is settled, since the boundary may be feeding it.

**Scope warning, stated plainly:** this is not a Phase 8 clean-up item. It is a defect in the physics
input path that predates the marine separation and would have existed identically in the pre-Phase-5
API. Phase 8's job is deploy + clean up. This should almost certainly become its own phase or an ADR,
not be absorbed into a closeout.

---

## C-82 — Two contradictory swell decompositions ship in one payload with no provenance marking (OPEN)

`GET /surf/{id}` returns both `data.spectralComponents` (NDBC-observed, 4 components) and
`forecast[].multiSwell` (SWAN-modelled, 1 component). They disagree on component count, on period
(20.0 s vs 13.42 s) and on `frequencyRange` (real ranges vs `[0.0, 0.0]`). Nothing in the payload marks
which is observed and which is modelled; the only thing preventing a consumer from mixing them is a
comment in one dashboard file (`SurfingTab.tsx:40`).

**Consequence:** any second consumer — the config UI, a future mobile client, an operator reading JSON —
will reasonably read `spectralComponents` and get a different, better-looking answer than the dashboard
shows, with no way to know why.

**Recommendation:** mark provenance explicitly on both fields (e.g. `source: "ndbc_observed"` /
`"swan_model"`) so the constraint lives in the contract rather than in a comment. **Data contract change
— trigger 4, needs a ruling.** Depends on C-81's outcome; if the boundary fix makes `multiSwell`
trustworthy, the right answer may instead be to drop `spectralComponents` from this response entirely.

---

## C-83 — The C-08 energy-closure test cannot detect under-partitioning, and passed while C-81 was live (OPEN, method defect)

`scripts/verify_energy_closure_deployed.py` measures `sum(component m0) / spectrum m0`. When the model
emits **one** component, that ratio is ~1.0 *by definition* — the single partition contains the whole
spectrum. The test is only meaningful on multi-component timesteps.

Measured this cycle: **median 1.022, min 0.998, max 1.051**, with **65 of 66 timesteps single-component**.
The lone 2-component timestep closed at 1.0164. Against the 1.626 median / 2.271 max baseline that is a
real improvement and the original duplication defect **is** genuinely fixed — but the headline "PASS"
carried far more assurance than the measurement supports, and the coordinator reported it that way
before the operator challenged it.

**This is the same failure C-08 exists to prevent, one level up:** measuring self-consistency of a model
and reading the result as physical validation.

**Fixes required:**
1. The script must **refuse to report PASS when the multi-component sample is too small** — report
   `INCONCLUSIVE (n_multi=1)` rather than PASS, and state the single/multi split in the headline, not
   three lines down.
2. Add the **complementary** check it lacks: compare published component **count, period and direction**
   against an independent source (NDBC decomposition at the same timestep is already in the payload —
   free, and would have caught C-81 immediately: 4 vs 1).
3. Two real bugs in the script were found and fixed while running it today, both of which had produced
   confidently wrong numbers on first execution:
   - the component height field is **`height`**, not `hs_m`/`hs`/`significant_height_m` — the first run
     reported "NO MEASURABLE TIMESTEPS," which would have read as a total model failure;
   - SWAN writes 2-D variance density in **m²/Hz/degree**, so the direction bin width must be used in
     **degrees**; converting to radians understated m0 by 180/π and the first run reported a closure of
     **58.5**. Both fixed and documented in the script's docstrings.

---

## C-84 — First forecast timestep publishes 0.0 ft surf with `modelStatus: "degraded_bulk"` (OPEN, small)

The 06:00Z timestep of every cycle publishes `breakingFaceHeight: 0.0`, `period: 1.6 s`,
`direction: 121.4°`, `conditionsText: "0-1 ft at 2 seconds from the SE. Wind chop dominates."`, and
`modelStatus: "degraded_bulk"`. Its cache entry has `components: []` and a spectrum Hs of **0.01 m**.

This is the SWAN cold-start timestep, before the boundary energy has propagated into the grid — a
spin-up artifact, not a forecast. It is nonetheless published as a normal forecast hour and would render
on the dashboard as flat calm.

**Recommendation:** either drop the spin-up timestep from the published forecast, or surface
`modelStatus: "degraded_bulk"` in the UI so it is not read as a real 0 ft hour. **Consult the operator
before dropping a timestep** — trimming published output is a contract change (trigger 4). Related to
C-83's honesty principle: an artifact should be labelled, not rendered as data.

---

## C-85 — T8.6 findings: the marine capability surface is empty end-to-end (see C-46/C-56), plus route and provider gaps (OPEN)

Recorded from the T8.6 E2E sweep so none of it is lost.

**Confirmed working:**
- marine `/health` on librewxr:8780 responds; cycle completed 09:04:55Z, L1+L2+L3, real WW3 boundary.
- marine `/manifest` advertises **18 endpoints**; the API mounts them. Verified live: a request to
  `GET /api/v1/surf/spots` returned a 404 whose body was
  `{"type":"https://clearskies.weewx.org/errors/marine/404", ..., "instance":"https://192.168.7.22:8780/surf/spots"}`
  — i.e. the API **proxied to the marine service** and the marine service answered. The companion proxy
  works.
- `GET /api/v1/surf/{id}` returns a full payload: 67 forecast hours, tide predictions, water temp,
  beach profile, `breakerFormula: komar_gaughan`, `surfHeightDisplay: face`, units in ft/°F.

**Empty or missing:**
- **`GET /api/v1/capabilities` advertises ZERO marine providers.** Domains are exactly
  `[alerts, almanac, aqi, earthquakes, forecast, radar, seeing]`. marine `/manifest` returns
  `"capabilities": []` and `"locations": []`. This is **C-46/C-56 confirmed live, not a tidy-up** — the
  API's config push payload has no `capabilities` and no top-level `locations` key (top-level keys are
  exactly `marine`, `station`, `swan`), so marine's `compute_capabilities()` (`endpoints/manifest.py:215`)
  and `compute_locations()` (:236) read absent keys and always return `[]`. Their docstrings still say
  *"Phase 4 scaffold: no config has ever been pushed."* `MARINE_PROVIDER_MODULES` /
  `get_provider_module()` still have **zero importers** outside `dispatch.py`. This contradicts
  ARCHITECTURE.md, which says marine capabilities are absent from `/api/v1/capabilities` **only when
  unconfigured** — it is configured and they are absent. Needs a ruling on where the capability list
  derives from (trigger 4).
- **`GET /api/v1/surf/{id}/forecast` is not mounted** — 404 from the API itself, not proxied. The
  manifest exposes `/surf`, `/surf/{location_id}`, `/surf/{location_id}/profile` only. **Assessed as
  benign:** the dashboard calls `/surf/{id}` and `/surf/{id}/profile` (`api/client.ts:478,485,494`) and
  never `/forecast`. `briefs/SURF-PUBLISH-RESULTS-ONLY.md` references `/forecast`; the brief is stale on
  this point. Flagged for doc correction, not a code change.
- **NDBC 404 for station `prjc1`** on huntington-harbor during the cycle. Station ID appears invalid or
  retired. Needs verification against NDBC's active station list.
- **NDBC self-rate-limit** logged at 08:47 ("1 calls per 1s"). Cosmetic if the limiter is working as
  designed; worth confirming it is not serialising a burst that then times out.

**API operational notes discovered while testing, for the runbook:** the API serves **HTTPS** on 8765
(self-signed) — `http://` yields a connection failure, not a redirect; `openapi.json` and `/docs` are
**disabled in production** (404); `/api/v1/health` does **not** exist (404) while `/api/v1/capabilities`
does and requires **no** auth token. `weewx`'s address is **not** 192.168.7.21; probes must run from the
host or via the correct address.

---

---

## C-86 — ROOT CAUSE: we are not using WaveWatch III. We use a regional server's 0.5° republication that averages the swell partitions into one number, destroying the groundswell (OPEN → BLOCKER, NEEDS AN OPERATOR RULING)

**Supersedes the recommendation in C-81, which was wrong.** C-81 correctly identified that the SWAN
boundary carries one swell train, but recommended feeding "WW3's partitioned swell trains" while also
concluding the source could not supply them. Both halves were based on reading code and one dataset.
The operator ordered actual research into the data. The data says something different and much simpler.

### What we are actually fetching

`providers/marine/wavewatch.py` → `https://pae-paha.pacioos.hawaii.edu/erddap/griddap/ww3_global`.

**PacIOOS is the Pacific Islands Ocean Observing System** — a regional observing programme. The dataset
is a republication of the legacy `NWW3_Global_Best` product. PROVIDER-MANUAL §14.3 records how this
happened: the originally documented base (`erddap.aoml.noaa.gov`) and its 7-grid table *"were never
live-verified"* and were *"found completely unreachable,"* so this republication was substituted and
documented as "WaveWatch III forecasts."

Verified live 2026-07-26 — the dataset has exactly **9** wave variables and **no partition dimension**:

| Group | Variables |
|---|---|
| Total | `Thgt` `Tper` `Tdir` |
| Swell | `shgt` `sper` `sdir` — **one, averaged** |
| Wind sea | `whgt` `wper` `wdir` |

Resolution **0.5°** (~55 km), per both the manual and the dataset metadata.

### The measurement that identifies the defect

Same location (33.5 N, 118.5 W — the SWAN L1 boundary point), same day, two sources:

**NOAA WaveWatch III via Unidata THREDDS, 2026-07-26T15:00Z** —
`thredds.ucar.edu/thredds/ncss/grid/grib/NCEP/WW3/Global/Best`, `ordered_sequence_of_data` dimension:

| | Hs | Period | Direction |
|---|---|---|---|
| Swell partition 1 | 0.58 m | **6.26 s** | 273.4° (W wind swell) |
| Swell partition 2 | 0.40 m (1.31 ft) | **19.05 s** | **214.6° (SSW)** |
| `Primary_wave_mean_period_surface` | — | **19.06 s** | 215.0° |
| Combined Hs | 0.80 m | | |

**PacIOOS `ww3_global`, same point:** `Thgt 1.06 m`, `Tper 12.66 s`, `Tdir 195°`,
`shgt 0.93 m`, `sper 12.73 s`, `sdir 192°`, wind sea `null/null/null`.

**Surfline for the spot:** 1.5 ft **19 s** SSW **197°** / 1.4 ft 12 s S 187° / 1.5 ft 9 s S 181°;
surf height **4–6 ft, chest to overhead**.

**Read the three together.** Real WW3 resolves a **19-second, 214.6° groundswell** — the train Surfline
leads with, matching it closely on height (1.31 ft vs 1.5 ft), period (19.05 s vs 19 s) and direction
(214.6° vs 197°). Our source reports **one swell at 12.73 s**, a weighted average of the 19.05 s
groundswell and the 6.26 s wind swell — **a number that corresponds to no wave in the water.** The
disagreement is not confined to the partitions: real WW3's own bulk primary period is **19.06 s** where
PacIOOS's `Tper` is **12.66 s**. These are different products, not different views of one.

### Why this single number explains everything observed tonight

Peak period governs shoaling and breaking face height far more strongly than offshore height does. A
1.3 ft 19 s groundswell breaks substantially larger than a 3 ft 12.7 s sea, which is exactly why
Surfline forecasts 4–6 ft from a *smaller* combined swell (2.54 ft) than our boundary carries (3.05 ft).
Feeding SWAN 12.7 s instead of 19 s accounts for all three published symptoms at once:

- **surf height low** — 3.83–4.24 ft against 4–6 ft, at or below the bottom of the real range;
- **surf height flat** — a single averaged train has no arriving/departing structure, so the forecast
  barely moves (~4 ft across 14 h while `Tper` swung 5.2→10.0 s);
- **no long-period sets** — nothing in the input has a 19 s envelope to produce them.

It also explains why every check in Phase 8 passed. The energy in the average is roughly conserved
(0.93 m vs a 0.80 m combined), so closure, convergence and plausibility screens are all satisfied. The
**distribution** is wrong, and no conservation test can see that (C-83).

### This reframes C-81 and C-08

- `ww3_to_swan_boundary()`'s single JONSWAP peak is **not** the root cause. It is a faithful rendering
  of a source that only ever supplies one swell. Fixing the boundary writer alone changes nothing.
- T4B.2 was **correct** on its own terms and remains so: `decompose_spectrum()` really was reporting one
  swell as three (67 spectra; closest-pair direction separation median **1.6°**, worst case three
  components at Tp 10.2/10.2/10.1 s). It was splitting one averaged peak, not finding real trains. The
  pre-T4B.2 display was not better — it showed three copies of the wrong swell instead of one.
- So the surf output has **never** carried the real multi-train sea, before or after any Part B work.
  This is not a marine-separation regression; it is a data-source defect that predates it and would
  exist identically in the pre-Phase-5 API.

### Two replacement sources, both global — the operator chooses

Global coverage is a hard requirement (operator, 2026-07-26: *"THIS NEEDS TO WORK GLOBALLY WE CANNOT BE
USING REGIONAL MODELS, THAT WAS NEVER THE INTENT"*). Both options below are global NCEP WaveWatch III.

| | **A. Unidata THREDDS** | **B. NOMADS `gfswave.global.0p16`** |
|---|---|---|
| Endpoint | `thredds.ucar.edu/thredds/ncss/grid/grib/NCEP/WW3/Global/Best` | `nomads.ncep.noaa.gov/cgi-bin/filter_gfswave.pl` |
| Wire format | OPeNDAP / NetCDF Subset Service → **CSV or NetCDF** | GRIB2 |
| Resolution | 0.5° | **0.16°** (~3× finer) |
| Swell partitions | **2** (`ordered_sequence_of_data = 2`) | **3** (`SWELL/SWPER/SWDIR 1,2,3`) |
| Correct primary period | **yes** — 19.06 s, verified | yes |
| Parsing burden | **none** | GRIB2 — but `eccodes 2.48.0` is already installed on librewxr,
`GRIB_AVAILABLE` is `True`, and the repo already fetches NOMADS GRIB via the filter CGI for HRRR
(`filter_hrrr_2d.pl`) and GFS (`filter_gfs_0p25.pl`), so `filter_gfswave.pl` is the same pattern |
| Verified live | 2026-07-26, values above | 2026-07-26 00z and 06z `.idx` inventories |

Both were confirmed reachable and populated today. **Note NOAA retired NOMADS OPeNDAP** (Service Change
Notice 25-81), which is why option B is GRIB2 and not `.ascii` — that retirement is also a standing risk
to option A's longevity worth weighing.

**Coordinator's recommendation: B**, because it carries three partitions rather than two and is 3× finer,
and because the GRIB machinery it needs already exists and is already relied on for wind. Take **A** if
avoiding GRIB entirely is worth losing the third partition and the resolution — it still fixes the
19-second groundswell, which is the defect that matters.

Either way the boundary writer must then emit a **multi-train** boundary (one TPAR-equivalent per
partition, or superposed spectra) instead of one synthesised JONSWAP peak, and stop discarding the
wind-sea partition and the total-vs-swell difference.

### Why this was NOT implemented tonight

Architectural on four counts, and the operator's approval is required before any of it:

- **Trigger 7** — replaces the provider's endpoint and data source; option B adds a GRIB dependency to
  this provider's path.
- **Trigger 4** — `wavewatch.fetch()`'s return shape must carry per-partition arrays across the provider
  boundary; `MarineForecastPoint`'s single `swellHeight/swellPeriod/swellDirection` triple no longer
  expresses the data.
- **Trigger 1** — the boundary specification and its fixed 30° `DSPR` change; what the model is asked to
  solve changes.
- **Trigger 3, possibly** — a finer source grid may affect L1 boundary sampling.

Per the named non-excuse, PROVIDER-MANUAL §14.3 documenting the PacIOOS dataset as "WaveWatch III
forecasts" is **not** authorization to leave it — it is the paper trail that let a regional
republication stand in for the operational model for months. §14.3 must be corrected as part of whatever
fix is approved (doc-code sync).

### Verification the fix must pass — not a conservation check

Per the new rule in `rules/clearskies-process.md`, "Validate against reality, never against the model's
own output." Acceptance for this work is:

1. The published swell list contains a **19 s ±1 s train from the SSW** on a day WW3 shows one, with
   height within ~30% of the WW3 partition.
2. Published surf height **overlaps Surfline's stated range**, and **varies** across the forecast.
3. Published component count tracks WW3's partition count — not fixed at 1, not fabricated as 3.
4. Component periods are **distinct** (the T4B.2 failure signature was Tp 10.2/10.2/10.1 s).
5. C-83's fixes are in place first, so the closure test can no longer report PASS on a degenerate sample.

---

### GRIB2 verified by direct parse — option B confirmed, and it is the better source

Operator direction 2026-07-26: *"eh, let's parse the GRIB2 to see what it provides."* Done —
downloaded a NOMADS `filter_gfswave.pl` subset and decoded it with the already-installed `eccodes`
on librewxr. Read-only; nothing installed, no service touched.

`gfswave.t06z.global.0p16`, 2026-07-26, nearest point to (33.5 N, −118.5):

| f-hour | partition | `shts` Hs | `mpts` period | `swdir` direction |
|---|---|---|---|---|
| f000 | 1 / 2 / 3 | 0.45 / 0.34 / 0.18 m | 6.09 / **20.22** / 11.76 s | 268.6 / **218.3** / 207.0° |
| f003 | 1 / 2 / 3 | 0.54 / 0.35 / 0.17 m | 6.18 / **19.57** / 11.75 s | 269.8 / **217.2** / 208.0° |
| f006 | 1 / 2 / 3 | 0.61 / 0.38 / 0.23 m | 6.39 / **19.11** / 11.70 s | 272.6 / **216.9** / 199.0° |

Bulk at f006: `swh` 0.78 m, `perpw` **19.10 s**, `dirpw` 219.2°. Wind speed `ws` 1.76 m/s.

**Three partitions with genuinely distinct periods** — 6.4 / 19.1 / 11.7 s — which is the property
`decompose_spectrum()` never had (its worst case was Tp 10.2/10.2/10.1 s) and the PacIOOS source cannot
have (one averaged `sper`).

Against Surfline for the spot:

| Surfline | gfswave partition | Verdict |
|---|---|---|
| 1.5 ft **19 s** SSW 197° | lev 2 — 1.25 ft, **19.11 s**, 216.9° | period exact, height within 17%, direction 20° off |
| 1.4 ft **12 s** S 187° | lev 3 — 0.75 ft, **11.70 s**, 199.0° | period within 3%, direction 12° off, height low |
| 1.5 ft 9 s S 181° | — (lev 1 is 6.4 s from 272°, a W wind swell) | not matched |

Two of three trains recovered, **including the 19 s groundswell that governs the surf**. The residual
direction bias (~12–20° clockwise) and the unmatched 9 s train are separate, smaller questions to
examine after the source is fixed — and are plausibly why Surfline's is a licensed nearshore model and
ours is a global one.

**Energy consistency:** √(0.61² + 0.38² + 0.23²) = 0.755 m against `swh` 0.78 m. The partitions account
for the total, so a multi-train boundary built from them will not double-count (C-83's failure mode) nor
lose energy.

**Two implementation facts that must not be missed:**

1. **`9999` is the missing-value sentinel.** At this point `shww`, `mpww` and `wvdir` (wind-wave fields)
   are all `9999.000` — there are no wind waves, matching THREDDS reporting `NaN` for the same fields.
   This must be masked as missing, never ingested. A 9999 m wave height reaching SWAN's boundary would be
   catastrophic, and per `rules/coding.md` §1 a missing input must halt the run, not be substituted.
2. **Bandwidth is better than today's.** Each forecast hour's regional subset is **~8 KB**, so a 25-step
   cycle is ~200 KB — cheaper than the current ERDDAP JSON fetch, not more expensive. The
   `filter_gfswave.pl` CGI accepts the same `subregion`/`leftlon`/`rightlon`/`toplat`/`bottomlat`
   parameters the HRRR and GFS wind providers already use.

**Revised recommendation: option B, `gfswave.global.0p16` via `filter_gfswave.pl` + `eccodes`.** It is
global (0.16°, ~3× finer than the 0.5° we use now), carries three partitions rather than THREDDS's two,
gives the correct primary period, is energy-consistent, costs less bandwidth, needs no new dependency,
and reuses the NOMADS-GRIB pattern already in the repo for wind. It also avoids depending on a
third-party academic mirror at a time when NOAA has just retired NOMADS OPeNDAP (SCN 25-81).

Research script kept at `/tmp/ww3_partitions.py` on librewxr and in the session scratchpad; it should be
committed to `scripts/` as the reproducible source-comparison measurement if this work is approved.

**Still requires the operator's approval before any code changes** — the trigger analysis above is
unchanged by this measurement. What the measurement settles is *which* source, not *whether* to switch.

---

---

## C-87 — The correct boundary source is WW3's own 2-D spectra, not any bulk product. Design measured end to end; needs an operator ruling to implement (OPEN → BLOCKER)

**Supersedes C-86's recommendation as well.** C-86 concluded "use `gfswave.global.0p25` for its three swell
partitions." That is still better than what we run today, but it is not what the SWAN manual says to do,
and the operator was right to push past it: *"you need to figure out what oceanographers and engineers
say is the best data source of the WW3 datasets to use to plug into SWAN."*

### What the SWAN manual actually specifies (not a coordinator judgement)

SWAN User Manual, "Boundary and initial conditions" — SWAN provides a **dedicated WAVEWATCH III nesting
command**:

| Command | Parent model | Data it expects |
|---|---|---|
| `BOUNDSPEC ... PAR` / TPAR | none | parametric bulk parameters — **what we use today** |
| `BOUNDSPEC ... FILE` | none | 1-D or 2-D spectra from measurements or other models |
| `BOUNDNEST1` | a coarser SWAN run | full 2-D spectra |
| `BOUNDNEST2` | WAM Cycle 4.5 | full spectra (manual marks it *"not fully tested"*) |
| **`BOUNDNEST3`** | **WAVEWATCH III** | **full 2-D spectra** |

The manual's exact wording for `BOUNDNEST3`:

> *"The output files of WAVEWATCH III have to be created with the post-processor of WAVEWATCH III as
> output transfer files (formatted or unformatted) with WW_3 OUTP (output type 1 sub type 3) at the
> locations along the nest boundary."*

The literature agrees on the principle: SWAN nesting in WW3 uses *"oceanic boundary conditions in the
form of two-dimensional wave spectra supplied by the WAVEWATCH III model."* Bulk parameters are what you
*validate* against, not what you drive a nested model with — and the intercomparison work notes that
models disagree on **peak period** near the coast by up to ~1.4 s even when Hs agrees, which is exactly
the quantity our bulk source gets wrong by 6.4 s.

**So the defect is one level deeper than C-86 said.** It is not "we get one partition instead of three."
It is *"we parameterise a spectrum that WW3 already computed and publishes in SWAN's own nesting
format."* Feeding three partitions instead of one would still be a synthesised approximation of a
spectrum we can simply read.

### The data exists, operationally, and was verified live 2026-07-26

**Ocean — `gfswave.<STATION>.spec`**
`/pub/data/nccf/com/gfs/prod/gfs.YYYYMMDD/CC/wave/station/bulls.tCCz/`

```
'WAVEWATCH III SPECTRA'     50    36     1 'spectral resolution for points'
...frequency array (0.035 -> 0.964 Hz, i.e. periods 28.6 s -> 1.04 s)...
...direction array (36 bins)...
20260726 060000
'46222     '  33.62-118.32     487.9   2.20 143.8   0.03 285.6
...50 x 36 = 1800 energy density values...
```

Per-timestep header carries **station id, lat, lon, depth (m), wind speed/direction, current
speed/direction**. Station 46222 is San Pedro Channel — 33.62 N, 118.32 W, **487.9 m depth**, ~20 km off
Huntington. A textbook deep-water L1 boundary point.

**Great Lakes — `glwu.<STATION>.spec`**
`/pub/data/nccf/com/glwu/prod/glwu.YYYYMMDD/bulls.tCCz/`

```
'WAVEWATCH III SPECTRA'     32    36     1 'Great Lakes WAVEWATCH III Unst'
```

**Identical format.** GLWU *is* a WAVEWATCH III implementation (unstructured grid). The header is
self-describing — it declares `nfreq` and `ndir` — so **one parser serves both products**, no branching
on format.

**Why the Great Lakes need their own product, confirmed by measurement, not assumption:** at Lake
Michigan (43.0 N, 87.0 W) `gfswave.global.0p25` returns **9999** (missing) for `swh` and every
partition, and PacIOOS `ww3_global` returns **null**. Global ocean wave models mask inland water. Any
Great Lakes surf spot has therefore been running with no WW3 boundary at all — and now that C-76 makes a
missing boundary raise instead of substituting calm, a Great Lakes spot would fail loudly rather than
publish fiction. That is the correct behaviour but it means **Great Lakes spots are currently
unsupported in practice**, which should be stated rather than discovered.

### Sizes — practical, and the trap to avoid

| Object | Size | Verdict |
|---|---|---|
| `gfswave.tCCz.spec_tar.gz` (all stations) | **1.72 GB** | do not fetch |
| `gfswave.tCCz.ibp_tar` (all boundary points) | **11.37 GB** | do not fetch |
| **`gfswave.<STATION>.spec`** (one station) | **7.75 MB** | **fetch this** |
| **`glwu.<STATION>.spec`** (one station) | **1.94 MB** | **fetch this** |
| `gfswave.<STATION>.bull` | 52 KB | station discovery |
| `gfswave.<STATION>.cbull` | 27 KB | — |

The per-station files are individually addressable, so the tarballs are a trap, not a requirement. 7.75 MB
per cycle is less than the 21 MB/60 s the system was moving before SURF-PUBLISH-RESULTS-ONLY.

There is also an `ibp` (Interpolated Boundary Points) family — WW3 output produced specifically for
downstream nesting. It is only published as an 11 GB tarball, so per-station `.spec` is the practical
equivalent. **Worth a follow-up question to NCEP** whether IBP points are individually addressable
anywhere, since they are the purpose-built answer.

### Station discovery — the operator-location problem, solved cheaply

~4,036 ocean stations (12,108 files ÷ 3) and ~115 Great Lakes stations (579 ÷ 5). We must not probe
7.75 MB files to find out where they are. Measured solution:

1. **One directory listing per product** yields the full station-ID list.
2. **An HTTP range request for bytes 0–120 of `<station>.bull`** yields the location line —
   `Location : 46222      (33.62N 118.32W)` for ocean, `Location : 45002   (45.34N  86.41W)` for GLWU.
   ~100 bytes per station instead of 7.75 MB.
3. Build a **station catalogue once and cache it long-term.** The repo already has this exact pattern:
   `/discovery/buoy-stations` and `/discovery/tide-stations` carry `cache_ttl 86400`, and NDBC station
   discovery with lat/lon already exists (§14.1). Many `gfswave` station IDs *are* NDBC IDs (46222,
   45002), so that existing metadata covers a large fraction; the range-request path covers the rest
   (e.g. `3FYT`, `0Y2W3`).
4. At 2 req/s (the existing ERDDAP-era rate limit) a full cold catalogue build is ~35 min, once, cached.
   It belongs in configuration/discovery time, not in the forecast cycle.

**Station selection per spot** then needs, and the `.spec` header supplies, everything required:
- **water body** — Great Lakes vs ocean, choosing the catalogue. Precedent exists: the bathymetry chain
  already distinguishes Great Lakes (USGS Great Lakes topobathy) from ocean (NCEI/CUDEM).
- **depth** — the per-timestep header carries it (487.9 m at 46222), so "is this a deep-water boundary
  point" is checkable from the data rather than assumed.
- **distance and bearing** — nearest station, seaward of the spot, within a maximum distance.

### The honesty requirement that follows, and it is not optional

Global station coverage is **uneven**. Some coastlines will have no station within any defensible
distance. Per `rules/coding.md` §1 and the C-76/C-77 rulings, that must **not** silently degrade to the
gridded bulk product — that would reintroduce exactly the averaged-away groundswell this concern is
about, just with a different provenance. The correct shape is a **configuration-time viability check**:
a spot is supportable only if a suitable spectral boundary source exists for it, and the operator is
told so at setup, in the wizard, with the distance and depth of the station chosen. Same pattern as the
existing L3 cluster viability test.

### What changes in the code — smaller than C-86 implied

`swan_formats.py` already emits file-based boundary commands for the nested levels
(`BOUNDSPEC SIDE W CCW CONSTANT FILE 'BOUND_W.txt' 1`) alongside `BOUNDNEST1` for L2/L3. The change at L1
is to make the boundary file a **2-D spectrum** rather than a TPAR parametric table, and to select
`BOUNDNEST3` or `BOUNDSPEC ... FILE` per the manual depending on whether one station or several points
along the boundary are used. **`ww3_to_swan_boundary()`'s single synthesised JONSWAP peak and its fixed
30° `DSPR` both disappear** — nothing is synthesised any more.

Note a resolution consequence worth flagging: WW3 ocean spectra are **50 freq × 36 dir out to 28.6 s**,
while our SWAN spectral grid is **32 × 36 out to 23.9 s**. The incoming spectrum is finer and reaches
longer periods than our grid currently represents, so SWAN's `CGRID` frequency range is part of this
decision (SWAN will interpolate, per `BOUNDNEST1`'s documented behaviour, but truncating at 23.9 s would
discard exactly the long-period energy we are trying to recover).

### Still not implemented — the trigger analysis is unchanged and the operator decides

Triggers **7** (new endpoints/products, GRIB and spectral file fetching, a new cached catalogue),
**4** (`wavewatch.fetch()` must return 2-D spectra, not a bulk `MarineForecastPoint` triple), **1** (the
boundary specification changes and the fixed 30° `DSPR` is removed), and **3** (SWAN's `CGRID` frequency
range may need to widen to accept 28.6 s energy).

PROVIDER-MANUAL §14.3 must be rewritten with whatever is approved; it currently documents a PacIOOS
0.5° bulk republication as "WaveWatch III forecasts", which is how this survived.

### Open questions the operator should decide, stated rather than assumed

1. **One station or several along the L1 boundary?** `BOUNDNEST3` is designed for multiple points
   ("locations along the nest boundary"); a single station implies `BOUNDSPEC ... FILE`. Several points
   is more faithful and costs 7.75 MB each.
2. **Are the IBP files individually addressable?** They are the purpose-built nesting product; only the
   11 GB tarball was found.
3. **`CGRID` frequency range** — widen to 28.6 s or accept truncation.
4. **Max acceptable station distance**, and what the wizard tells an operator whose spot has none.
5. **GLWU cadence differs** — hourly `bulls.tCCz` for 00–14z observed, versus the ocean product's
   00/06/12/18z. The runner's cycle logic assumes 6-hourly.

---

---

## OPERATOR RULING 2026-07-26 — C-86 / C-87 APPROVED INTO PHASE 8; T8.6 ORDERING CONSTRAINT VOID

> *"So this is a test environment. We can take things down. There is no reason to continue these services,
> especially in light of the fact that it is all bogus data right now, and the surf page does not work
> anyway with the current arrangement. So it is not like we are blanking out data for existing web traffic.
> This should get incorporated into Phase 8."*

**What this authorizes:**

1. **C-86 / C-87 are APPROVED** and become **T8.10** in the plan, with the design in
   `briefs/WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md`: per-station `gfswave.<ST>.spec` + `glwu.<ST>.spec`,
   `BOUNDSPEC SIDE ... CONSTANT FILE`, `CGRID` low end to 0.03 Hz, cached station catalogue,
   configuration-time viability with no silent degradation. Triggers 7, 4, 1, 3 are hereby authorized for
   this scope only.
2. **T8.4 / T8.4b / T8.5 are UNBLOCKED.** The rule "T8.6 must pass before T8.4/T8.5" existed because the
   old services were the rollback path. They reproduce the same defect, so they were never a rollback path
   for it, and the environment carries no live traffic. Decommissioning proceeds independently of T8.6.
3. **C-70's stop-not-disable posture is retired** — the services can now be disabled and the old repo
   archived.

**What this does NOT authorize:** anything outside T8.10's stated scope. New triggers still stop and
surface.

**C-81 and C-86's recommendations remain superseded** by C-87 (single station via `BOUNDSPEC CONSTANT
FILE`; `BOUNDNEST3` unusable because station points cannot satisfy the manual's 0.1x-spacing positioning
rule). Kept in the register for the audit trail, not as guidance.

### Second authorization, same day — the marine forecast endpoint

> *"ok the marine forecast fix needs to be included in phase 8 as well."*

This authorizes **T8.10i**: re-sourcing `endpoints/marine.py` off the PacIOOS republication onto **gridded**
WW3 (`gfswave.global.0p25` for ocean, GLWU gridded for the Great Lakes). It resolves the unowned-consumer
blocker the Fable plan review found — `wavewatch.fetch()` has three call sites feeding the offshore marine
forecast, and T8.10b changes that function's return shape.

**Operator question answered in the same exchange — station files vs gridded files.** Both are needed, for
different consumers, and neither is a fallback for the other:

| | Station `.spec` | Gridded GRIB2 |
|---|---|---|
| Carries | full 2-D spectrum E(f,theta) | bulk + 3 swell partitions, **no spectrum** |
| Available | fixed buoy/output points | anywhere on the grid |
| Consumer | **SWAN L1 boundary** (T8.10c) | **`/marine` offshore forecast** (T8.10i) |

The SWAN boundary needs the spectrum, which gridded cannot supply. `/marine` is bulk by nature and needs
arbitrary-spot coverage, which stations cannot supply.

**Still requiring a separate ruling:** whether `/marine` may gain **new response fields** to carry the three
gridded partitions (trigger 4). Filling existing shape is authorized; adding fields is not.

### Third direction, same day — grid resolution tiering, and a correction to the record

**Grid resolution tiering — operator direction, 2026-07-26.** Verbatim: *"the current source we are using IS
GLOBAL, we just need to specify the right files. If we have the ability to get more accurate and detailed
grid files for large parts of the world, which would be the mid latitude areas, then let's do that... and we
use the .25 degree files for the remaining parts of the world (well other than Great Lakes which as its own
files)."*

**Correction to the record:** the PacIOOS source **is** global. Its defects are **resolution** (0.5 deg) and
**averaging the swell partitions into one triple** — not coverage. Earlier plan/brief wording that framed the
finer NOAA grids as "regional models we ruled out" was a coordinator mischaracterisation; tiering resolution
by location is not substituting a regional model for global coverage.

All extents below measured live from the GRIB messages on 2026-07-26:

| Grid | Type | Latitude | Longitude | Increment | Use |
|---|---|---|---|---|---|
| `gfswave.global.0p16` | regular_ll | 52.5 N .. 15.0 S | all | **0.1667 deg** | **Tier 1** |
| `gfswave.global.0p25` | regular_ll | **+90 .. -90** | all | 0.25 deg | **Tier 2 (baseline)** |
| `glwu.grlc_2p5km` | unstructured | Great Lakes | — | ~2.5 km | **Great Lakes** |
| `gfswave.gsouth.0p25` | regular_ll | -10.5 .. -79.5 | all | 0.25 deg | **not used** — same resolution as Tier 2 |
| `gfswave.wcoast.0p16` | regular_ll | 50 .. 25 N | 210-250 E | 0.1667 deg | **not used** — wholly inside Tier 1 |
| `gfswave.atlocn.0p16` | regular_ll | 55 .. 0 N | 260-310 E | 0.1667 deg | deferred — gains only +2.5 deg latitude, Atlantic only |
| `gfswave.epacif.0p16` | regular_ll | 30 N .. 20 S | 130-215 E | 0.1667 deg | deferred — gains only +5 deg latitude, Pacific only |
| `gfswave.arctic.9km` | **polar_stereographic** | Arctic | — | ~9 km | deferred — finer than Tier 2 but a different projection; needs its own decision |

**Selection rule:** a spot at latitude within 52.5 N .. 15.0 S uses **Tier 1**; anything outside uses
**Tier 2**; Great Lakes spots use **GLWU**. Tier 1 is ~1.5x finer than Tier 2 and ~3x finer than the PacIOOS
source it replaces.

**This is tiering, NOT a runtime fallback — the distinction is load-bearing.** The tier is resolved
**deterministically from the spot's coordinates at configuration time** and recorded. If the chosen grid's
fetch fails at runtime it **raises**; it must never quietly fall through to a coarser grid. A silent
coarse-grid substitution is the same class of defect as C-76's calm boundary and C-86's averaged swell — the
answer would change without anyone being told. See `rules/coding.md` section 1.

**`atlocn` / `epacif` / `arctic` are deferred, not rejected.** Each is genuinely finer than Tier 2 in its
area. They are held back because two grids cover the requirement and each addition costs another fetch path
(and, for `arctic`, projection handling). Revisit if a configured spot falls in one of their exclusive areas.

### Fourth direction, same day — setup-time grid probe

**Setup-time grid probe — operator direction, 2026-07-26:** *"I think we need to do a grid fetch at setup,
just to verify we have data for that location."*

Do a **real fetch** of the resolved tier grid at the spot's coordinates during setup and confirm the value is
**not the missing sentinel**. This is not a coverage calculation from a bounding box — it is an actual read,
because a point can be inside a grid's declared extent and still carry no wave data.

**Proof the check is necessary and that it works** (measured 2026-07-26): at Lake Michigan (43.0 N, 87.0 W),
`gfswave.global.0p25` returns **9999** for `swh` and every swell partition, and the PacIOOS source returns
**null** — both points sit well inside the declared global extent. Nothing but a real read distinguishes
"covered" from "has data".

**`9999` means TWO different things and conflating them breaks the probe.** It is the GRIB
`missingValue` sentinel (read directly off the message header, confirmed `missingValue 9999`), but the reason
a field is missing differs, and only one of them means "no data at this location":

| Measured 2026-07-26 | `swh` (total) | partition fields | Means |
|---|---|---|---|
| Lake Michigan 43.0 N, 87.0 W | **9999** | all 9999 (`shts`/`mpts` 1,2,3) | **point is not in the model's water** — land-masked. Reject the spot. |
| Huntington 33.5 N, 118.5 W | **0.78** | `shts` 0.61/0.38/0.23 real, but `shww`/`mpww`/`wvdir` **9999** | **valid ocean point**; the wind-sea partition simply does not exist this hour. Accept the spot. |

**Therefore the probe must test `HTSGW` / `swh` — total significant wave height — and nothing else.** It is
present whenever the point is in the model's water. **Probing a partition field instead would wrongly reject
valid ocean spots on any hour with no wind swell**, which is most summer mornings at Huntington.

**What the probe must catch:**
- `swh == missingValue` → the point is not in this model's water. Land-masked cells, and enclosed water
  bodies the ocean model masks, which is every Great Lakes spot. Reject, or route to GLWU.
- A spot outside the resolved tier's latitude band — a Tier 1 probe at 53 N returns nothing, and selection
  must land on Tier 2 rather than reading the empty result as "no data anywhere".

**Separately, in the ingest path:** `missingValue` must never be ingested as data anywhere. A 9999 m wave
height reaching SWAN's boundary would be catastrophic. Read the sentinel from the GRIB `missingValue` key
rather than hardcoding 9999, and mask on it. A **missing partition is normal and is reported as absent**; a
missing **total** during a live cycle is a failure and **raises** (rules/coding.md section 1).

**Cost:** trivial. A `filter_gfswave.pl` subregion subset spanning ~3 deg x 3 deg with nine variables measured
**4,577 bytes**. Run once per spot at setup, not per cycle.

**Where it belongs:** the marine service already advertises **`GET /discovery/grib-availability`** with
`cache_ttl: 0` in its manifest. **Extend that endpoint** rather than adding a new one — check what it does
today before writing anything, since reusing it keeps this inside the authorized scope instead of adding an
endpoint (trigger 7).

**Both halves of viability are checked at setup, and both can refuse a spot:**

| Probe | Confirms | Feeds |
|---|---|---|
| **Gridded fetch** (this item) | the tier grid has non-missing data at the spot | `/marine` offshore forecast (T8.10i) |
| **Station lookup** (above) | a suitable deep-water station exists within range | SWAN L1 boundary (T8.10c) |

A spot that fails **either** probe is refused at setup with a message naming which probe failed and why. A
spot may legitimately pass one and fail the other — e.g. gridded data present but no station near enough —
and the message must say which, because the remedies differ.
