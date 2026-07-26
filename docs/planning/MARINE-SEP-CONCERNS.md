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

## C-64 — the admin has no equivalent of the wizard's blank-URL guard (OPEN → Phase 8)

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

---

## C-63 — the same-host URL literal now exists twice, by design (OPEN → low priority)

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
   `uv lock` against PyPI. But `deploy-api.sh` and the documented test invocations use
   `uv run --frozen`, which is precisely the mode that fails when the lock and the manifest
   disagree. **Regenerate before Phase 8's deploy, not during it.**
2. **`Dockerfile` cited ADR-085 for the `libeccodes-dev` / `libeccodes0` system packages**, which
   were installed solely to serve the `[marine]` extra. Removing them was required — leaving the
   build pointing at a now-nonexistent extra would have failed outright — and the evidence supports
   it, since GRIB2 processing moved to the marine service. But **ADR-085 now describes a dependency
   the API no longer has.** That is an ADR-status question, not a doc-sync fix, and belongs to the
   phase-boundary ADR compliance sweep.

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
