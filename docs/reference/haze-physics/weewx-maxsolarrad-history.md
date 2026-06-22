# weewx maxSolarRad Archiving History

**Purpose:** Research for haze detection auto-calibration baseline. Determines when `maxSolarRad` entered the weewx archive database, whether it can be recomputed for historical records that predate archiving, and what the realistic data availability scenario looks like.

**Archived:** 2026-06-21
**Researcher:** Claude (research agent R5.2)

**Primary sources (all fetched live):**
- weewx GitHub repo: `src/weewx/schemas/wview_extended.py`, `src/weewx/schemas/wview.py`, `src/weewx/wxformulas.py`, `src/weewx/almanac.py`, `src/weewx_data/weewx.conf`, `docs_src/changes.md`
- weewx Google Groups threads: "Cannot add maxSolarRad to schema", "trouble getting a calculated max solar radiation written in archive table"
- weewx GitHub issue #115: https://github.com/weewx/weewx/issues/115

---

## 1. When Was maxSolarRad First Added to the Archive Schema?

### Short answer

`maxSolarRad` was **never in the original `wview` schema** and is **not automatically archived by default in any pre-4.0 weewx installation**. It became part of the default archive schema only with **weewx 4.0.0 (released 30 April 2020)**, which introduced the `wview_extended` schema as the new default.

### Full timeline

| Version | Date | Event |
|---------|------|-------|
| 3.2.0 | 2015-07-15 | `maxSolarRad` added to `StdWXCalculate` — computed for loop packets and archive records, but NOT stored to the database because it was not in the `wview` schema |
| 3.2.0–3.9.x | 2015–2019 | `maxSolarRad` calculated but silently discarded; database column doesn't exist |
| 4.0.0 | 2020-04-30 | `wview_extended` introduced as new default schema; `maxSolarRad` is a column in this schema; new installs archive it |
| 4.0.0+ | 2020–present | `maxSolarRad = prefer_hardware` is in the default `[StdWXCalculate]` config; ephem package required to produce non-NULL values |

### Source evidence

**Changelog v3.2.0** (`docs_src/changes.md`, line 1994):
> "Added windrun, evapotranspiration, humidex, apparent temperature, maximum theoretical solar radiation, beaufort, and cloudbase to StdWXCalculate."

This added the *calculation* — not the *archiving*.

**Original `wview` schema** (`src/weewx/schemas/wview.py`): contains 49 fields. `maxSolarRad` is absent. The listed fields end with `inTempBatteryStatus`. Copyright 2009–2021, meaning this schema predates and postdates v3.2.0 and was never extended to include `maxSolarRad`.

**`wview_extended` schema** (`src/weewx/schemas/wview_extended.py`): contains `('maxSolarRad', 'REAL')` as a column. The file header: `"""The extended wview schema."""` — added in weewx 4.0.0.

**Changelog v4.0.0** (`docs_src/changes.md`, line 1049):
> "New default schema (`wview_extended`) that offers many new types. The old schema is still supported. Fixes issue #115."

**Issue #115** (opened 2016-04-11): explicitly listed `maxSolarRad` as a missing field in the wview schema: "does not include many commonly requested fields (cloudbase, humidex, appTemp, maxSolarRad)."

**Default `weewx.conf`** (`src/weewx_data/weewx.conf`): includes `maxSolarRad = prefer_hardware` in `[StdWXCalculate][[Calculations]]` — this is the config shipped with every new installation.

### The gap: pre-4.0 installs still running on wview schema

When a station upgrades from weewx 3.x to 4.x, **weewx does NOT alter the existing database**. The schema is only used when the database is first created. Upgrading weewx reads the schema directly from the live database, which remains `wview` (no `maxSolarRad` column). The user must manually add the column:

```bash
weectl database add-column maxSolarRad
```

This adds the column with NULL values for all historical records. It does NOT backfill values.

A station that installed weewx before April 2020 will have:
- Records from the install date through ~April 2020: `maxSolarRad` column does not exist
- Records after April 2020 on a fresh install or after manual column addition: `maxSolarRad` exists but is NULL for the old records

---

## 2. Computed for Loop Packets but Not Stored?

**Yes, exactly.** From weewx 3.2.0 through 3.9.x (July 2015–February 2019):

1. `StdWXCalculate` computed `maxSolarRad` and inserted it into the archive record Python dict.
2. `StdArchive` then saved the record to the database.
3. Because the `wview` database table had no `maxSolarRad` column, the value was silently ignored by the SQL INSERT.

This was confirmed in the Google Groups thread "Cannot add maxSolarRad to schema": "I'm not running the latest WeeWx, but I didn't think it's important since maxSolarRad has been introduced quite a long time ago" — the respondent was referring to the calculation being introduced, not the archiving.

Additionally, the Google Groups thread "trouble getting a calculated max solar radiation written in archive table" showed that even after adding the column, `maxSolarRad` remained NULL until `ephem` (pyephem) was installed: "Pyephem is required to calculate maxSolarRad otherwise it will always be None/null."

---

## 3. Ryan-Stolzenbach Recomputation Feasibility

### Inputs required

From `src/weewx/wxformulas.py`, function `solar_rad_RS()`:

```python
def solar_rad_RS(lat, lon, altitude_m, ts=None, atc=0.8):
    """Calculate maximum solar radiation
    Ryan-Stolzenbach, MIT 1972
    """
    from weewx.almanac import Almanac
    if atc < 0.7 or atc > 0.91:
        atc = 0.8
    ...
    alm = Almanac(ts, lat, lon, altitude_m)
    el = alm.sun.alt          # solar elevation degrees from horizon
    R = alm.sun.earth_distance  # Earth-Sun distance in AU
    z = altitude_m
    nrel = 1367.0             # NREL solar constant, W/m^2
    sinal = math.sin(math.radians(el))
    if sinal >= 0:            # sun must be above horizon
        rm = math.pow((288.0 - 0.0065 * z) / 288.0, 5.256) \
             / (sinal + 0.15 * math.pow(el + 3.885, -1.253))
        toa = nrel * sinal / (R * R)
        sr = toa * math.pow(atc, rm)
```

**Complete variable list:**

| Variable | Source | Available for recomputation? |
|----------|--------|------------------------------|
| `lat` | Station latitude (decimal degrees) | Yes — static station config |
| `lon` | Station longitude (decimal degrees) | Yes — static station config |
| `altitude_m` | Station altitude in meters | Yes — static station config |
| `ts` | Unix epoch timestamp of archive record | Yes — always present in archive |
| `atc` | Atmospheric transmission coefficient (0.7–0.91, default 0.8) | Yes — constant, not measured |
| `el` = `alm.sun.alt` | Solar elevation angle from horizon (degrees) | Computed from lat/lon/ts via `ephem` |
| `R` = `alm.sun.earth_distance` | Earth-Sun distance in AU | Computed from ts via `ephem` |

**Conclusion: full recomputation is feasible.** Every input is either static station metadata or derivable from the timestamp via the `ephem` library. No weather observation data is required.

### The `atc` parameter

`atc` is the **atmospheric transmission coefficient**, representing the fraction of top-of-atmosphere radiation that survives passage through a standard clear atmosphere. It captures the combined attenuation from molecular scattering (Rayleigh) and clean dry-air absorption.

- Valid range: 0.70–0.91 (enforced by the code — values outside this range revert to 0.80)
- Default: **0.80** (used for all recomputation if not overridden)
- Physical meaning: at `atc=0.80`, 80% of direct-beam radiation passes through one air-mass of atmosphere
- It does NOT represent aerosol loading, haze, or humidity — it is a clean-sky parameter

For recomputation purposes, use **`atc=0.80`** (the weewx default) for all historical records. This matches what weewx originally computed when the values were first calculated. Using a site-specific tuned value is possible but would create inconsistency with whatever subset of records WAS archived.

### Dependency: `ephem` package

`solar_rad_RS()` calls `alm.sun.alt` and `alm.sun.earth_distance` via the `Almanac` class. These attributes require the `ephem` Python package (formerly `pyephem`). Without it, `AlmanacBinder.__getattr__` raises `AttributeError`, which is caught by the `except (AttributeError, ValueError, OverflowError)` in `solar_rad_RS()`, and the function returns `None`.

The `weeutil.Sun` fallback (used when `ephem` is absent) only provides sunrise/sunset times — it does NOT provide solar elevation or Earth-Sun distance, which the RS formula requires.

As of weewx 5.2, the Almanac is extensible and can use alternatives to `ephem` (e.g., the Skyfield extension, per changelog note at line 123). For recomputation scripts, `ephem` is the tested path.

---

## 4. weewx Database Schema Evolution

### Schema generations

| Schema | Introduced | Fields | maxSolarRad |
|--------|-----------|--------|-------------|
| `wview` (old-style) | weewx 1.x | 49 columns | **Not present** |
| `wview_extended` (new-style) | weewx 4.0.0 (2020-04-30) | 111+ columns | **Present** as `REAL` |
| `wview_small` | weewx 4.x | Subset | Unknown (not inspected) |

The schema is specified using "old-style" (list of tuples) for `wview` and "new-style" (allows explicit daily summary schemas) for `wview_extended`. Both styles are supported in v4 and v5.

### Migration behavior when upgrading

When upgrading weewx from any version to any higher version:

1. **weewx does not alter the archive table schema.** The schema in `schemas/wview_extended.py` is only read when creating a new database from scratch.
2. After upgrade, weewx reads the live schema directly from the SQLite/MySQL `pragma` or `information_schema`.
3. If `maxSolarRad` is not a column in the live database, it remains absent — even if `wview_extended` is now the default config schema.

### Adding the column manually

```bash
# weewx 5.x syntax:
weectl database add-column maxSolarRad --type REAL

# weewx 4.x syntax:
wee_database --add-column=maxSolarRad --type=REAL
```

This adds a `NULL`-filled column to all existing archive rows.

### Backfilling via `calc-missing`

**weewx 4.0.0** added `--calc-missing` to `wee_database` (renamed `weectl database calc-missing` in v5.0.0). This walks historical archive records and calculates any derived types that have NULL values, then writes them back.

**Workflow to backfill maxSolarRad into an old database:**

```bash
# Step 1: Add the column
weectl database add-column maxSolarRad --type REAL

# Step 2: Rebuild — calculates maxSolarRad for every record where it is NULL
weectl database calc-missing
```

**Critical requirement:** `ephem` must be installed, AND `maxSolarRad = prefer_hardware` (or `= software`) must appear in `[StdWXCalculate][[Calculations]]` in `weewx.conf`. Otherwise `calc-missing` will skip the field.

**weewx does NOT backfill automatically during upgrade.** The user must explicitly run `calc-missing`.

---

## 5. From What weewx Version Is maxSolarRad Reliably in the Archive?

**Definitive answer:** `maxSolarRad` is reliably in the archive for **fresh installations of weewx 4.0.0 or later, on hardware where `ephem` is installed.**

The caveats:

1. **Schema must be wview_extended.** New installs from v4.0.0 onward default to this. Upgraded stations retain their old `wview` schema unless manually migrated.

2. **ephem must be installed.** Without `ephem`, all calculated values are NULL. Pre-packaged distros (Raspberry Pi OS, Ubuntu) may or may not include `ephem` in the weewx package dependencies. The user may need to `pip install ephem` separately.

3. **StdWXCalculate must be configured.** v4.0.0 changed StdWXCalculate so it calculates nothing by default — everything must be listed in `weewx.conf`. New installs from v4.0.0 onward ship with `maxSolarRad = prefer_hardware` in the default config. Upgraded installs that don't update their `weewx.conf` will have no `maxSolarRad` calculation, even if the schema column exists.

---

## 6. What To Do for Older Records

For pre-4.0.0 records (or records from a station that ran the `wview` schema), the options are:

### Option A: weewx `calc-missing` (preferred if weewx 4.0+ is available)

- Requires adding the column first (`weectl database add-column maxSolarRad`)
- Uses the exact same RS formula weewx uses for live data
- Uses the station's configured `atc` (from `weewx.conf [StdWXCalculate][[WXXTypes]]`, default 0.80)
- Fills in NULL values only; does not overwrite existing values
- Produces values consistent with current live data

### Option B: External Python script using the RS formula directly

For stations where running weewx tooling is inconvenient, or for the Clear Skies project's own baseline bootstrap:

```python
import math
import ephem
import time

def solar_rad_RS(lat, lon, altitude_m, ts, atc=0.8):
    """Replicate weewx solar_rad_RS exactly."""
    if atc < 0.7 or atc > 0.91:
        atc = 0.8
    try:
        observer = ephem.Observer()
        observer.lat = str(lat)
        observer.lon = str(lon)
        observer.elevation = altitude_m
        observer.date = ephem.Date(ts / 86400.0 + 25567.5)  # unix ts to Dublin JD
        sun = ephem.Sun()
        sun.compute(observer)
        el = math.degrees(sun.alt)
        R = sun.earth_distance  # AU
        sinal = math.sin(math.radians(el))
        if sinal < 0:
            return 0.0
        rm = math.pow((288.0 - 0.0065 * altitude_m) / 288.0, 5.256) \
             / (sinal + 0.15 * math.pow(el + 3.885, -1.253))
        toa = 1367.0 * sinal / (R * R)
        return toa * math.pow(atc, rm)
    except Exception:
        return None
```

Note: The weewx `Almanac` wrapper converts unix timestamps to Dublin Julian Days via `timestamp_to_djd()`. Use `ephem.Date(ts / 86400.0 + 25567.5)` for the direct ephem equivalent (25567.5 = days from Dublin epoch 1899-12-31.5 to unix epoch 1970-01-01).

### Option C: Verify the existing schema before any migration

```bash
# SQLite
sqlite3 ~/weewx-data/archive/weewx.sdb ".schema archive" | grep maxSolarRad

# MariaDB
mysql -u weewx -p weewx -e "DESCRIBE archive" | grep maxSolarRad
```

If the column is absent: run Option A. If it's present but all NULLs: `ephem` was not installed during the recording period — run Option A or B to backfill.

---

## 7. Practical Impact

### Typical station scenarios

**Station installed 2016–2019 (weewx 3.x, never upgraded):**
- Schema: `wview` — no `maxSolarRad` column
- Calculation: performed since v3.2.0 but discarded
- Archive: zero historical `maxSolarRad` values
- What to do: Add column + run `calc-missing` after upgrading to weewx 4.x; or run external script

**Station installed 2019–2020 (weewx 3.9.x):**
- Same as above

**Station installed April 2020–present (weewx 4.0+) from fresh install:**
- Schema: `wview_extended` — column exists from day 1
- Calculation: enabled if `ephem` installed and `maxSolarRad = prefer_hardware` in config
- Archive: values present from install date IF `ephem` was installed at setup time
- If `ephem` missing: column exists but all NULLs until `ephem` installed

**Station that upgraded from 3.x to 4.x in place:**
- Schema: remains `wview` unless manually migrated
- No `maxSolarRad` column; same as 2016–2019 scenario above
- Common case: many long-running stations

**Station running Belchertown skin (this project's production station):**
- Production `cloud` container running legacy Belchertown; weewx version unknown without inspection
- Need to check: `sqlite3 /path/to/weewx.sdb ".schema archive" | grep maxSolarRad`

### For the haze detection auto-calibration baseline

The calibration approach that assumed `maxSolarRad` availability in the archive must account for:

1. **Minimum weewx version requirement:** 4.0.0 (released 2020-04-30), with `ephem` installed
2. **Stations without maxSolarRad in archive:** the baseline CAN be reconstructed using the RS formula from station lat/lon/altitude + timestamp — all inputs are available from the archive's `dateTime` column and the station's static config
3. **Recomputed values are deterministic:** given the same lat, lon, altitude, ts, and atc, the formula always produces the same result; recomputed baseline and live-recorded values will match exactly (same code path)
4. **The `atc` constant is not observable from history:** for all historical recomputation, use `atc=0.80` (weewx default) unless the station's `weewx.conf` shows a non-default value — mixing `atc` values across the dataset would introduce a systematic offset

**Key conclusion for the calibration design:** If maxSolarRad is absent from the archive (or is all NULLs), the baseline bootstrap must use recomputed maxSolarRad values rather than archived ones. The recomputed values are computationally equivalent — same RS formula, same inputs — so this is not a quality downgrade, it is just a pre-processing step.

---

## Key Source Files (GitHub)

- Schema (extended): `src/weewx/schemas/wview_extended.py` — confirms `maxSolarRad REAL` in wview_extended
- Schema (original): `src/weewx/schemas/wview.py` — confirms maxSolarRad absent from wview
- Formula: `src/weewx/wxformulas.py`, function `solar_rad_RS()` (lines 390–449)
- Almanac ephem integration: `src/weewx/almanac.py`
- Default config: `src/weewx_data/weewx.conf`
- Changelog: `docs_src/changes.md`
- GitHub issue #115: https://github.com/weewx/weewx/issues/115
