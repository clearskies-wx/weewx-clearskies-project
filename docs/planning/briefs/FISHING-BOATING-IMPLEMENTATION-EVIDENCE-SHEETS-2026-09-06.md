# Fishing and Boating remediation — implementation and evidence sheets

**Status:** Phase 1 target-state instructions. No deployment, restart, source
sync, production test, or live-verification command has been run under this
sheet. The operator's 2026-09-06 hold remains in force.

## Shared execution constraints

- Preserve concurrent Marine Service work. A phase owner may modify only its
  sheet's allowlist; a changed file outside that list stops the phase for
  coordinator review.
- Do not change wave-model code, model grids, boundaries, schedules, physics,
  ports, dependencies, endpoints, configuration keys, or persisted formats.
- A source record is not inferred from a display value. Every implementation
  must retain the selected source, source type, valid time, unit, and, for
  water temperature, coverage tier and depth. `unavailable` remains explicit.
- WCOFS is eligible only for points it covers on the United States West Coast.
  The resolver selects by coverage at the chosen point; it must not use WCOFS
  as a nationwide default.
- Run the stated real-host check only after the operator authorizes deployment.
  Capture raw output in `scratch/fishing-boating-remediation-2026-09-06/` with
  its command, UTC timestamp, and source identifiers. A passing automated test
  alone cannot close a gate.

## Phase 2 — species evidence and test design

**Allowlist:** `docs/planning/briefs/FISHING-BOATING-SPECIES-MATRIX-2026-09-06.md`, `docs/planning/briefs/FISHING-BOATING-SCORER-KNOWN-ANSWERS-2026-09-06.md`, and `docs/manuals/API-MANUAL.md`. No source code, tests, configuration, or other files.

**Instructions:** Catalogue every selectable source species, region, category,
alias, source, legal/seasonal availability, habitat depth, temperature band,
tide/time preference, and pressure trait. Record whether the source supports a
numeric multiplier. Define known-answer scorer cases from the approved formula;
do not change service code in this phase.

**Phase 2 evidence method:** This is a research/design gate, not a deployment
or a production-test gate. Capture the matrix source URLs and access dates, then
independently reproduce the arithmetic in
`FISHING-BOATING-SCORER-KNOWN-ANSWERS-2026-09-06.md`. Record the command, UTC
time, inputs, arithmetic, result, and what that check cannot prove in
`scratch/fishing-boating-remediation-2026-09-06/phase2/`.

The independent calculation must use the approved formula directly, not call
the scorer or reuse its helper functions. The Phase 4 evidence sheet—not this
Phase 2 row—runs the future deployed scorer and its regression guard on
`librewxr`.

Expected result: every known-answer case has independently reproduced
arithmetic; all 90 catalogue labels appear in the matrix; each matrix field
names source evidence, a derived mapping, a plan judgment, missing evidence, or
not applicable. This proves research coverage and arithmetic only. It does not
prove a deployed endpoint or biological validity.

## Phase 3 — provider and API provenance contract

**Allowlist:** `repos/weewx-clearskies-marine/weewx_clearskies_marine/endpoints/marine.py`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/providers/marine/nws_marine.py`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/services/ocean_data_resolver.py`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/models/responses.py`,
`repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_response_conversion.py`,
`repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py`,
`repos/weewx-clearskies-api/weewx_clearskies_api/providers/forecast/aeris.py`,
`repos/weewx-clearskies-api/weewx_clearskies_api/providers/forecast/nws.py`,
`repos/weewx-clearskies-api/weewx_clearskies_api/providers/forecast/openmeteo.py`,
`repos/weewx-clearskies-api/weewx_clearskies_api/providers/forecast/openweathermap.py`,
`repos/weewx-clearskies-marine/tests/test_marine_provenance_contract.py`, and
`repos/weewx-clearskies-api/tests/unit/endpoints/test_setup_heuristics.py`.
No wave-model files or any other tests.

**Instructions:** Carry provider-neutral hourly mean-sea-level pressure through
the regular forecast contract; select station archive versus configured forecast
provider according to the approved location rule. Preserve NWS Coastal Waters
Forecast validity windows and join its regional additions only to overlapping
regular-forecast points. Preserve water-temperature source metadata from the
coverage-aware resolver; do not overwrite it with NDBC identifiers or times.

**Future evidence:** Hosts `librewxr` and `weewx`; after the approved
deployment, make the local capture directory
`scratch/fishing-boating-remediation-2026-09-06/phase3/` and run these exact
commands from this project root. They retain the raw deployed-service, upstream
Coastal Waters Forecast, API, and setup-compatibility outputs separately:

```powershell
ssh -F .local/ssh/config librewxr "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-marine && .venv/bin/python -m pytest tests/test_marine_provenance_contract.py -q'" | Tee-Object -FilePath scratch/fishing-boating-remediation-2026-09-06/phase3/marine-provenance-guard.txt
ssh -F .local/ssh/config librewxr "curl -fsS -H 'User-Agent: ClearSkies weather@shaneburkhardt.com' https://api.weather.gov/products/types/CWF/locations/LOX" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase3/nws-cwf-product-list-lox.json
@'
import json, urllib.request
headers = {'User-Agent': 'ClearSkies weather@shaneburkhardt.com'}
listing = urllib.request.urlopen(urllib.request.Request('https://api.weather.gov/products/types/CWF/locations/LOX', headers=headers))
product_url = json.load(listing)['@graph'][0]['@id']
print(urllib.request.urlopen(urllib.request.Request(product_url, headers=headers)).read().decode())
'@ | ssh -F .local/ssh/config librewxr "python3 -" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase3/nws-cwf-product-detail-lox.json
ssh -F .local/ssh/config weewx "curl -fsS https://weather.shaneburkhardt.com/api/v1/marine/huntington-harbor" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase3/marine-api-huntington-harbor.json
ssh -F .local/ssh/config weewx "curl -fsS 'https://weather.shaneburkhardt.com/api/v1/forecast?hours=72'" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase3/configured-forecast-provider-response.json
@'
set -euo pipefail
set -a; . /etc/weewx-clearskies/secrets.env; set +a
python3 - <<'PY'
import os, urllib.parse, urllib.request
params = urllib.parse.urlencode({'filter': '1hr', 'limit': '72', 'client_id': os.environ['WEEWX_CLEARSKIES_AERIS_CLIENT_ID'], 'client_secret': os.environ['WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET']})
print(urllib.request.urlopen('https://data.api.xweather.com/xcast/forecasts/33.6595,-117.9988?' + params).read().decode())
PY
'@ | ssh -F .local/ssh/config weewx "sudo bash -s" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase3/aeris-xcast-huntington-harbor-raw.json
ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && .venv/bin/python -m pytest tests/unit/endpoints/test_setup_heuristics.py -q'" | Tee-Object -FilePath scratch/fishing-boating-remediation-2026-09-06/phase3/setup-pressure-compatibility-guard.txt
```

Record the UTC-configured-location input and raw provider records in the same
directory; do not replace the saved raw response with a summarized excerpt.
Expected result: pressure and marine additions have matching valid windows, and
water temperature reports its actual source, model or observation valid time,
coverage tier, and depth. This proves one captured deployment only; coverage
fallback still requires the location matrix audit.

## Phase 4 — Fishing scoring and selection

**Allowlist:** `repos/weewx-clearskies-marine/weewx_clearskies_marine/endpoints/fishing.py`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/fishing_scorer.py`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/enrichment/fishing_species.py`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/tools/build_fishing_species_matrix.py`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/data/fishing_species_matrix.xlsx`,
`repos/weewx-clearskies-marine/weewx_clearskies_marine/data/fishing_species_matrix.sqlite`,
`repos/weewx-clearskies-marine/tests/test_fishing_remediation_known_answers.py`,
`repos/weewx-clearskies-marine/tests/test_fishing_endpoint_remediation.py`, and
`repos/weewx-clearskies-marine/tests/test_fishing_species_selection.py`. No
other files or tests.

**Instructions:** Implement only the approved selected-species score, hard
stops, fallback/profile disclosure, and time-matched inputs. No generic score
may remain. Do not reuse one current buoy observation for future periods.

**Future evidence:** Host `librewxr`; after the approved deployment, make the
local capture directory `scratch/fishing-boating-remediation-2026-09-06/phase4/`
and run these exact commands from this project root:

```powershell
ssh -F .local/ssh/config librewxr "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-marine && .venv/bin/python -m pytest tests/test_fishing_remediation_known_answers.py -q'" | Tee-Object -FilePath scratch/fishing-boating-remediation-2026-09-06/phase4/known-answers.txt
ssh -F .local/ssh/config librewxr "curl -fsS https://weather.shaneburkhardt.com/api/v1/fishing/huntington-harbor" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase4/fishing-api-huntington-harbor.json
ssh -F .local/ssh/config weewx "curl -fsS 'https://weather.shaneburkhardt.com/api/v1/forecast?hours=72'" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase4/configured-forecast-provider-response.json
@'
set -euo pipefail
set -a; . /etc/weewx-clearskies/secrets.env; set +a
python3 - <<'PY'
import os, urllib.parse, urllib.request
params = urllib.parse.urlencode({'filter': '1hr', 'limit': '72', 'client_id': os.environ['WEEWX_CLEARSKIES_AERIS_CLIENT_ID'], 'client_secret': os.environ['WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET']})
print(urllib.request.urlopen('https://data.api.xweather.com/xcast/forecasts/33.6595,-117.9988?' + params).read().decode())
PY
'@ | ssh -F .local/ssh/config weewx "sudo bash -s" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase4/aeris-xcast-huntington-harbor-raw.json
ssh -F .local/ssh/config librewxr "curl -fsS 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=clearskies&begin_date=20260906&end_date=20260909&datum=MLLW&station=9410660&time_zone=gmt&units=metric&interval=hilo&format=json'" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase4/coops-9410660-predictions.json
ssh -F .local/ssh/config librewxr "curl -fsS 'https://weather.shaneburkhardt.com/api/v1/almanac/solunar?lat=33.6595&lon=-117.9988&days=3'" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase4/solunar-huntington-harbor.json
```

Save the timestamped forecast-provider raw record and the selected
source-species profile beside those named API, CO-OPS, and solunar outputs in
the same directory.
Expected result: each known answer matches the independent hand derivation and
every period identifies its source times. This proves formula and input alignment,
not a forecast's future accuracy.

## Phase 5 — Dashboard reconstruction

**Allowlist:** `repos/weewx-clearskies-dashboard/src/components/marine/tabs/FishingTab.tsx`,
`repos/weewx-clearskies-dashboard/src/components/marine/tabs/BoatingTab.tsx`,
`repos/weewx-clearskies-dashboard/src/components/marine/shared/MarineStatTile.tsx`,
`repos/weewx-clearskies-dashboard/src/components/marine/tabs/FishingTab.test.tsx`,
`repos/weewx-clearskies-dashboard/src/components/marine/tabs/BoatingTab.test.tsx`,
`repos/weewx-clearskies-dashboard/src/components/marine/shared/MarineStatTile.test.tsx`, and
`repos/weewx-clearskies-dashboard/src/api/generated-types.ts`. The generated
contract file may change only when regenerated from the canonical OpenAPI
contract; no other files or tests are allowed.

**Instructions:** Render the shared normalized Current Conditions payload and
the API-derived selected-species choice. The browser must not select providers,
derive regional eligibility, or calculate scores.

**Future evidence:** Host `weather-dev`; after the approved deployment, make
the local capture directory `scratch/fishing-boating-remediation-2026-09-06/phase5/`
and run this exact command from this project root:

```powershell
ssh -F .local/ssh/config weather-dev "curl -fsS https://weather.shaneburkhardt.com/api/v1/marine/huntington-harbor" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase5/marine-api-huntington-harbor.json
ssh -F .local/ssh/config weather-dev "curl -fsS https://weather.shaneburkhardt.com/api/v1/marine/wrightsville-beach" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase5/marine-api-wrightsville-beach.json
```

Capture the rendered page in the browser at the same UTC minute and save it
as `scratch/fishing-boating-remediation-2026-09-06/phase5/browser-huntington-harbor.png`.
Also capture the configured non-West-Coast comparison location
`wrightsville-beach` as `scratch/fishing-boating-remediation-2026-09-06/phase5/browser-wrightsville-beach.png`.
Expected result:
source labels, nulls, validity times, and selected species match API responses.
This proves rendered contract fidelity at those captures only.

## Phase 6 — live audit and closeout

**Allowlist:** `docs/ARCHITECTURE.md`, `docs/manuals/API-MANUAL.md`,
`docs/manuals/PROVIDER-MANUAL.md`, `docs/manuals/DASHBOARD-MANUAL.md`,
`docs/contracts/openapi-v1.yaml`,
`docs/planning/FISHING-BOATING-REMEDIATION-PLAN-2026-09-05.md`, and
`docs/planning/briefs/FISHING-BOATING-IMPLEMENTATION-EVIDENCE-SHEETS-2026-09-06.md`.
No implementation, test, generated-contract, or other files are allowed.

**Instructions:** Independently compare provider records, deployed API output,
and rendered pages at matched times for the required locations. Re-run every
earlier gate after deployment. A failed live check returns to its owning phase.

**Future evidence:** Hosts `librewxr` and `weather-dev`; after the approved
deployment, make the local capture directory
`scratch/fishing-boating-remediation-2026-09-06/phase6/` and run these exact
commands from this project root:

```powershell
ssh -F .local/ssh/config librewxr "curl -fsS https://weather.shaneburkhardt.com/api/v1/fishing/huntington-harbor" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase6/fishing-api-huntington-harbor.json
ssh -F .local/ssh/config weather-dev "curl -fsS https://weather.shaneburkhardt.com/api/v1/marine/huntington-harbor" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase6/marine-api-huntington-harbor.json
@'
set -euo pipefail
set -a; . /etc/weewx-clearskies/secrets.env; set +a
python3 - <<'PY'
import os, urllib.parse, urllib.request
params = urllib.parse.urlencode({'filter': '1hr', 'limit': '72', 'client_id': os.environ['WEEWX_CLEARSKIES_AERIS_CLIENT_ID'], 'client_secret': os.environ['WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET']})
print(urllib.request.urlopen('https://data.api.xweather.com/xcast/forecasts/33.6595,-117.9988?' + params).read().decode())
PY
'@ | ssh -F .local/ssh/config weewx "sudo bash -s" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase6/aeris-xcast-huntington-harbor-raw.json
ssh -F .local/ssh/config librewxr "curl -fsS -H 'User-Agent: ClearSkies weather@shaneburkhardt.com' https://api.weather.gov/products/types/CWF/locations/LOX" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase6/nws-cwf-product-list-lox.json
@'
import json, urllib.request
headers = {'User-Agent': 'ClearSkies weather@shaneburkhardt.com'}
listing = urllib.request.urlopen(urllib.request.Request('https://api.weather.gov/products/types/CWF/locations/LOX', headers=headers))
product_url = json.load(listing)['@graph'][0]['@id']
print(urllib.request.urlopen(urllib.request.Request(product_url, headers=headers)).read().decode())
'@ | ssh -F .local/ssh/config librewxr "python3 -" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase6/nws-cwf-product-detail-lox.json
ssh -F .local/ssh/config librewxr "curl -fsS 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&application=clearskies&begin_date=20260906&end_date=20260909&datum=MLLW&station=9410660&time_zone=gmt&units=metric&interval=hilo&format=json'" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase6/coops-9410660-predictions.json
ssh -F .local/ssh/config librewxr "curl -fsS 'https://weather.shaneburkhardt.com/api/v1/almanac/solunar?lat=33.6595&lon=-117.9988&days=3'" | Set-Content -NoNewline scratch/fishing-boating-remediation-2026-09-06/phase6/solunar-huntington-harbor.json
```

Save the raw upstream records and browser captures at the same UTC minute in
the same directory; retain the exact commands and UTC timestamps in
`scratch/fishing-boating-remediation-2026-09-06/phase6/commands-and-times.txt`.
Expected result: each visible value is traceable to a real source record or an
explicit unavailable designation. This does not replace longer-term operational
monitoring.
