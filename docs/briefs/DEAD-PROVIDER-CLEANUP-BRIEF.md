# Dead Provider Cleanup Brief

**Status:** Ready  
**Created:** 2026-07-01  
**Origin:** T9.5/T9.6 audit findings from PROVIDER-ATTRIBUTION-PLAN.md; user confirmed all listed providers are dead code that was supposed to be removed but wasn't.

---

## Problem

Six provider modules are wired into the API dispatch registry and documented in manuals as if they are active, but they are dead code — not offered in the wizard, not used by any operator, and never intended to remain. They were supposed to be removed but the cleanup was never done.

## Providers to remove

| provider_id | Domain | Module file | Why dead |
|---|---|---|---|
| `wunderground` | forecast | `providers/forecast/wunderground.py` | Insufficient data for full site operation; not in wizard |
| `geonet` | earthquakes | `providers/earthquakes/geonet.py` | NZ-only; not in wizard; never offered |
| `emsc` | earthquakes | `providers/earthquakes/emsc.py` | Euro-Mediterranean; not in wizard; never offered |
| `renass` | earthquakes | `providers/earthquakes/renass.py` | France-only; not in wizard; never offered |
| `msc_geomet` | radar | `providers/radar/msc_geomet.py` | Canada WMS; not in wizard; never offered |
| `dwd_radolan` | radar | `providers/radar/dwd_radolan.py` | Germany DWD; not in wizard; never offered |

## Scope of removal (per provider)

### API repo (`weewx-clearskies-api`)

1. **Module file** — delete `providers/{domain}/{provider_id}.py`
2. **Dispatch registry** — remove `("{domain}", "{provider_id}")` entry from `providers/_common/dispatch.py` `PROVIDER_MODULES`
3. **Settings** — remove from `valid_providers` sets in `config/settings.py` (wunderground is in `[forecast] valid_providers`)
4. **CONFIG.md** — remove provider from documented config values, env var entries (`WEEWX_CLEARSKIES_WUNDERGROUND_API_KEY`, `WEEWX_CLEARSKIES_WUNDERGROUND_PWS_STATION_ID`)
5. **Tests** — remove or update any test fixtures/mocks referencing the provider
6. **api-docs** — check `docs/reference/api-docs/` for provider-specific reference docs

### Stack repo (`weewx-clearskies-stack`)

7. **Wizard providers** — no entries to remove (already confirmed: none of these are in the wizard PROVIDERS list)
8. **Docs** — remove from `docs/providers.md` if mentioned

### Docs (meta repo)

9. **PROVIDER-MANUAL.md** — remove provider entries from §4 (forecast), §7 (radar), §9 (earthquakes) tables. Remove any dedicated subsections.
10. **OPERATIONS-MANUAL.md** — remove config key references, env var documentation
11. **API-MANUAL.md** — remove any endpoint-specific documentation referencing these providers
12. **DASHBOARD-MANUAL.md** — line 80 already correctly calls them dead; after removal, remove the parenthetical list entirely since the providers won't exist

### What NOT to touch

- `openaq` AQI module — dead as an AQI display provider but actively used as haze calibration bootstrap data source (OPERATIONS-MANUAL §4). Separate concern; do not remove.
- Provider API reference docs in `docs/reference/api-docs/` — these document the external APIs for historical reference. Archive rather than delete.
- Archived ADRs, snapshots, planning docs — historical records, never modified.

## Verification

After removal:
- `ruff check` + `mypy` clean
- API starts without errors
- `GET /api/v1/capabilities` returns no entries for removed providers
- `grep -r "wunderground\|geonet\|emsc\|renass\|msc_geomet\|dwd_radolan" repos/weewx-clearskies-api/weewx_clearskies_api/` returns zero hits (excluding archived/snapshot files)
- All manuals internally consistent with reduced provider set
