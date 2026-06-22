# AQI Historical Data Provider Survey

**Purpose:** Survey of historical PM2.5/PM10 data availability from four AQI data providers, to inform bootstrap requirements for the haze detection auto-calibration system's clean-sky baseline.

**Research date:** 2026-06-21  
**Method:** All claims sourced from fetched API documentation and official provider pages — no training-data assertions.

---

## 1. Aeris / Xweather

### Availability
**Yes.** A dedicated historical archive endpoint exists.

- **Endpoint URL:** `https://data.api.xweather.com/airquality/archive/{action}`
- **Documentation:** https://www.xweather.com/docs/weather-api/endpoints/airquality-archive

### Lookback Window
**January 2024 to present** (approximately 2.5 years as of mid-2026). This is explicitly stated in the documentation as the support range.

### Temporal Resolution
**Hourly.** The archive delivers data at 1-hour intervals, and a single request can fetch up to 24 hours of data for any qualifying day.

### Rate Limits
Xweather does not publish per-tier call limits in their public documentation. Their rate-limiting page confirms limits are enforced at two levels — per-minute and per-billing-period — but the specific numbers require contacting sales or support.

- **Free tier:** 30-day developer trial, full API access. Stated limit: 1,000 accesses/day (100/minute) via the PWSWeather Contributor Plan, which provides a free Xweather subscription to PWS operators who contribute data.
- **Paid tiers:** 6 plans ranging roughly $50–$950/month (per third-party sources; Xweather does not publish prices on public pages).
- **Cost multiplier:** The archive endpoint (and all air quality endpoints) count as **5x** a normal API access. A single archive request consumes 5 of your daily/period allotment.

Sources:
- https://www.xweather.com/docs/weather-api/getting-started/rate-limiting
- https://www.pwsweather.com/contributor-plan/
- https://www.xweather.com/docs/weather-api/endpoints/airquality-archive

### Cost Per API Call
Not published per-call. Xweather uses a subscription model with a call-count allotment per billing period. The air quality archive endpoint carries a 5x usage multiplier.

### PM Field Availability
**Raw PM2.5 and PM10 values are returned**, not just composite AQI.

Response fields per pollutant period:
- `periods.#.pollutants.#.valueUGM3` — concentration in micrograms per cubic meter (µg/m³)
- `periods.#.pollutants.#.valuePPB` — parts per billion (null for PM2.5 and PM10)
- Individual AQI value and category per pollutant
- Composite AQI, dominant pollutant, health index

Pollutants covered: PM2.5, PM10, O3, CO, NO2, SO2.

Source: https://www.xweather.com/docs/weather-api/endpoints/airquality-archive

### Notes for PWS Operators
The PWSWeather Contributor Plan gives PWS data contributors a free Xweather subscription (valued at $400+/year) with 1,000 accesses/day and 100/minute rate limit. With the 5x multiplier, that's effectively 200 archive endpoint calls per day. Historical coverage starting January 2024 means a maximum lookback of ~2.5 years from now, growing forward from that fixed start date.

---

## 2. AirNow (US EPA)

### Availability
**Yes — two distinct access paths exist:**

**(A) AirNow API — web service for real-time and near-historical data**
- Historical observations endpoint: queries by reporting area, state, ZIP code, or lat/lon
- Documentation: https://docs.airnowapi.org/webservices

**(B) EPA AQS (Air Quality System) bulk download files**
- Pre-generated annual and daily summary CSV files going back to 1980
- Download hub: https://aqs.epa.gov/aqsweb/airdata/download_files.html

**(C) AirNow file server — hourly obs files**
- Rolling hourly files on Amazon S3 at `files.airnowtech.org`
- Structure: `https://files.airnowtech.org/airnow/YYYY/YYYYMMDD/`
- Currently documented as retaining 72 hours of rolling updates; longer historical archive availability is not clearly documented

### Lookback Window
- **AirNow API (web services):** Primarily designed for current data and near-term history. Historical observation endpoints exist but the supported date range is not explicitly documented; the FAQ recommends using file products for database population.
- **EPA AQS bulk download:** Data back to **1980** for most criteria pollutants. PM2.5 data available from the 1990s onward (PM2.5 monitoring began in the late 1990s). Files updated twice yearly (June and November).
- **AirNow file server:** Clearly documented rolling 72-hour window for hourly obs files. Directory structure suggests year/date organization that may extend further, but no official documentation confirms multi-year archive depth.

### Temporal Resolution
- **Hourly** raw sample data available in both the AQS sample data files and the AirNow hourly obs files.
- **Daily** summary files also available.
- Annual summaries available.
- EPA explicitly states: "we do not have monthly data."

Source: https://aqs.epa.gov/aqsweb/airdata/download_files.html

### Rate Limits
- **AirNow API:** No published rate limit. The FAQ discourages using web services to "loop through all zip codes to populate a database" and suggests file products for bulk historical needs.
- **AQS API** (programmatic access to the same data as the bulk files): Maximum 10 requests per minute; minimum 5 seconds between requests; maximum 1,000,000 rows per query. Queries must stay within a single calendar year.
- **Bulk file download (aqs.epa.gov):** No stated rate limit; files are direct HTTP downloads.

Sources:
- https://aqs.epa.gov/aqsweb/documents/data_api.html
- https://docs.airnowapi.org/faq

### Cost
**Free.** All EPA/AirNow data — web services, bulk files, AQS API — are free to access with no registration fee. AQS API requires user registration (free).

### PM Field Availability
**Both raw PM2.5 and PM10 concentration values are returned, alongside composite AQI.**

The AirNow hourly AQ obs file format (HourlyAQObsFactSheet) includes:
- `PM25` and `PM25_Unit` — raw PM2.5 concentration
- `PM10` and `PM10_Unit` — raw PM10 concentration
- `PM25_AQI`, `PM10_AQI` — NowCast AQI per pollutant
- `OZONE`, `NO2`, `CO`, `SO2` and their units and AQI values
- Measurement validity flag (`PM25_Measured`, `PM10_Measured`, etc.)

The EPA AQS bulk download files are organized by parameter code: PM2.5 FRM/FEM (88101), PM2.5 non-FRM/FEM (88502), PM10 (81102).

Source: https://docs.airnowapi.org/docs/HourlyAQObsFactSheet.pdf

### Coverage
US-only. Data from over 2,500 monitoring stations operated by state, local, tribal, and federal agencies. Some coverage of Canada and Mexico via AirNow partnerships.

Sources:
- https://www.airnow.gov/about-the-data/
- https://catalog.data.gov/dataset/airnow-real-time-air-quality-rest-api

### Notes for Bootstrap Use
The EPA AQS bulk download is the most reliable path for getting 2+ years of clean, validated hourly PM2.5 data for any US monitoring station. Find the nearest monitor to the PWS location using the EPA's station finder, then download annual hourly sample files for PM2.5 (parameter 88101). Each file is per-year per-pollutant in zipped CSV format. Data lag: up to 6 months before it appears in AQS (i.e., 2025 data may not be in the June 2025 release). For more recent data (past ~6 months), use AirNow hourly obs files or the AQS API with AirNow preliminary data.

---

## 3. OpenAQ

### Availability
**Yes.** OpenAQ provides a public API (v3, current as of 2025) with full historical measurement access.

- **API base URL:** `https://api.openaq.org/v3/`
- **Documentation:** https://docs.openaq.org/
- **Note:** API v1 and v2 were retired January 31, 2025 and return HTTP 410.

### Historical Endpoints
Per-sensor historical measurements are accessed at:
- Raw measurements: `GET /v3/sensors/{sensors_id}/measurements`
- Hourly averages: `GET /v3/sensors/{sensors_id}/hours`
- Daily averages: `GET /v3/sensors/{sensors_id}/days`
- Yearly averages: `GET /v3/sensors/{sensors_id}/years`

Query parameters include `date_from` and `date_to` for filtering time ranges.

Source: https://docs.openaq.org/resources/measurements

### Lookback Window
**Data begins approximately 2016** for the earliest integrated sources (US EPA AirNow data on OpenAQ is documented as starting April 26, 2016). OpenAQ was founded in 2015 and began aggregating historical data from reference-grade government monitors at that time.

**Full history is now accessible via the API.** Prior to a March 2023 update, data older than 90 days required AWS Athena queries on S3; the v3 API now exposes the full archive directly.

An alternative access path — the **AWS S3 archive** at `s3://openaq-data-archive` — provides gzip-compressed CSV files organized as `records/csv.gz/locationid={id}/year={year}/month={month}/` and is publicly accessible without credentials. This archive contains the complete historical dataset.

Sources:
- https://docs.openaq.org/resources/countries (Kazakhstan example: "datetimeFirst: 2018-07-27")
- https://openaq.medium.com/how-in-the-world-do-you-access-air-quality-data-older-than-90-days-on-the-openaq-platform-8562df519ecd
- https://docs.openaq.org/aws/about
- https://registry.opendata.aws/openaq/

### Temporal Resolution
**Hourly** (and sub-hourly for some sensor data). The API provides raw measurements as reported, plus pre-computed hourly, daily, and yearly averages via dedicated endpoints.

### Rate Limits
**Free tier:**
- 60 requests per minute
- 2,000 requests per hour
- No stated daily cap (inferred: ~48,000/day at hourly rate)

**Paid / custom tier:** Higher limits available by contacting platform@openaq.org. No published price list.

**Enforcement:** HTTP 429 on violation. Repeated violations can trigger temporary or permanent suspension.

Source: https://docs.openaq.org/using-the-api/rate-limits

### Cost
**Free** for the standard tier (API key required, free registration). Custom/higher-limit tiers are available by negotiation.

### PM Field Availability
**Raw PM2.5 and PM10 values are returned** (not just composite AQI). OpenAQ aggregates measurements as reported by the source monitoring networks. The platform's primary parameters include PM2.5, PM10, SO2, NO2, CO, O3, and black carbon (BC). Where the source reports raw concentration in µg/m³, that value is stored and returned.

Note: OpenAQ does not compute or return a composite AQI index — it stores and returns the raw measurement values as reported by the originating monitoring network. AQI conversion is left to the consumer.

Source: https://kitwaicloud.github.io/elk/openaq.html (parameter index)

### Global Coverage
- **141 countries and territories** (as of year-end 2025)
- **Over 15,300 active monitoring locations**
- **More than 2 billion total measurements** in the archive
- Predominantly reference-grade monitors (75% of locations) plus a growing air sensor network (25%)
- 33% year-over-year growth in low- and middle-income country locations in 2025

Source: https://openaq.medium.com/2025-year-in-data-59d62a4f31cd

### Notes for Bootstrap Use
OpenAQ is uniquely useful for PWS operators outside the US, where EPA AQS has no coverage. For US locations, the OpenAQ data ultimately aggregates the same AirNow monitoring network data, so going directly to EPA is simpler. For non-US locations, OpenAQ's API or S3 archive is the best free path to multi-year hourly PM2.5 data from government reference monitors. The AWS S3 archive path (no rate limits, bulk CSV download) is better suited to bootstrapping than the rate-limited API.

---

## 4. IQAir (AirVisual API)

### Availability
**Limited.** IQAir does offer some historical data, but the depth is tightly constrained by tier.

- **API documentation:** https://api-docs.iqair.com/

### Lookback Window by Tier

| Tier | Historical Access | Lookback Depth |
|------|-----------------|----------------|
| Community (Free) | No historical data | Real-time only |
| Startup (Paid) | Not explicitly documented | Not confirmed |
| Enterprise (Paid) | "48h historical air quality & weather data" | 48 hours |

The free Community tier provides no historical data access. The Enterprise tier is explicitly documented as offering "48h historical air quality & weather data."

For deeper historical access, IQAir's platform website (not the API) provides:
- Past 48 hours: hourly data
- Past 30 days: daily average data
- Yearly and monthly averages since 2018 (via World Air Quality Reports)

This platform access is "freely available on the IQAir platform" as a web UI (graphs), not a programmatic API.

Sources:
- https://www.iqair.com/us/air-pollution-data-api
- https://www.iqair.com/support/knowledge-base/how-can-i-access-historical-data-on-the-iqair-platform

### Temporal Resolution
- **API (all tiers):** Hourly for the 48-hour window on Enterprise; real-time only on lower tiers.
- **Web platform:** Hourly toggle for past 48 hours; daily averages for past 30 days; monthly/yearly averages back to 2018.

### Rate Limits

| Tier | Per Minute | Per Day | Per Month |
|------|-----------|---------|-----------|
| Community (Free) | 5 | 500 | 10,000 |
| Startup (Paid) | 100 | 100,000 | 1,000,000 |
| Enterprise (Paid) | 1,000 | 1,000,000 | 10,000,000 |

Source: https://www.iqair.com/us/air-pollution-data-api

### Cost
Pricing is not published on the public product page. The commercial API page indicates Startup and Enterprise plans are available via "monthly or annual subscription" but requires contacting IQAir sales for pricing.

### PM Field Availability
**Raw PM2.5 and PM10 values are returned alongside composite AQI.**

The AirVisual API returns, per Startup and Enterprise tiers: PM2.5, PM10, SO2, NO2, O3, CO concentrations, plus US AQI and Chinese AQI indices. PM2.5 and PM10 are reported in µg/m³.

The free Community tier returns overall AQI and limited pollutant data.

Source: https://www.iqair.com/us/air-pollution-data-api

### Notes for Bootstrap Use
IQAir is **not viable for historical bootstrapping**. The 48-hour lookback on the Enterprise API tier is insufficient for building a 1–2 year baseline. The web platform's historical UI (back to 2018) is not accessible via API. IQAir is primarily a real-time and forecast data provider.

---

## Cross-Provider Summary

### Typical Temporal Resolution of Historical AQI Data

**Hourly** is the standard resolution across all providers that offer historical data. Daily aggregates are also universally available. Sub-hourly (e.g., 5-minute) exists in the EPA AQS sample data for some monitors.

| Provider | Historical Resolution |
|----------|--------------------|
| Xweather | Hourly |
| AirNow / EPA AQS | Hourly (raw sample), Daily (summary) |
| OpenAQ | Hourly (and sub-hourly for some sensors) |
| IQAir API | Hourly (48h window only on Enterprise) |

### PM2.5 and PM10 Raw Value Availability

All three viable providers (Xweather, AirNow/EPA, OpenAQ) return raw PM2.5 and PM10 concentration values in µg/m³, not just composite AQI index. The AQI index is derived from the raw concentration values per the EPA NowCast formula.

---

## Bootstrap Feasibility Summary

**Scenario:** A typical personal weather station (PWS) operator in the United States needs 1–2 years of hourly PM2.5 data near their station location to bootstrap a clean-sky baseline for haze detection auto-calibration.

### Recommended Path: EPA AQS Bulk Download + AirNow Recent Files

**Step 1 — Identify nearest reference monitor.**
Use the EPA's AirData tool at https://aqs.epa.gov/aqsweb/airdata/download_files.html or the interactive map to find the nearest PM2.5 FRM/FEM monitoring station (parameter code 88101).

**Step 2 — Download annual hourly files from EPA AQS.**
Annual zipped CSV files cover hourly sample data per pollutant. For 2 years of data, download two annual files (e.g., `hourly_88101_2023.zip` and `hourly_88101_2024.zip`). These are free, no registration needed, and contain the full raw PM2.5 concentration values from every US monitor.

- Data goes back to 1980 (PM2.5 from late 1990s onward).
- No rate limits — direct file download.
- Files are validated quality-assured data (6-month lag from collection to publication).

**Step 3 — Fill the recent gap with AirNow preliminary data.**
For the most recent ~6 months not yet in AQS, use the AirNow hourly obs files at `files.airnowtech.org` or the AQS API with AirNow's preliminary data. This covers the period since the last AQS release.

**Outcome:** 2 full years of hourly PM2.5 data in CSV format, free, covering any US location with a nearby reference monitor.

---

### Alternative Path: OpenAQ (for non-US locations or when nearest monitor is not in EPA AQS)

Use OpenAQ's AWS S3 archive at `s3://openaq-data-archive` (public, no credentials, no rate limits). Data back to ~2016 for many government reference monitors globally. Locate the sensor ID for the nearest monitor via the OpenAQ explore interface at https://explore.openaq.org/, then download the relevant location's gzip CSV files directly from S3.

This path works worldwide wherever OpenAQ has aggregated a government reference monitor.

---

### Xweather: Viable But Limited

The Xweather archive endpoint is usable if the operator already has an Xweather subscription (e.g., via the PWSWeather Contributor Plan). However, the fixed start date of January 2024 limits maximum lookback to ~2.5 years and shrinks every day back data becomes available elsewhere. Cost multiplier of 5x per call makes it expensive against a limited daily allotment. **Use this path only if EPA AQS lacks a nearby monitor and real-time Xweather data is already being consumed.**

---

### IQAir: Not viable for bootstrap

The 48-hour API lookback is insufficient. Do not use IQAir as a bootstrap data source.

---

### Summary Table

| Provider | Best Use Case | Lookback | Raw PM2.5/PM10 | Cost | Viable for 1–2yr Bootstrap? |
|----------|-------------|---------|---------------|------|---------------------------|
| EPA AQS bulk download | US baseline, validated | 1980–present | Yes | Free | **Yes — recommended** |
| AirNow hourly files | US, recent 6 months | Rolling (72h–1yr approx) | Yes | Free | Yes (gap fill) |
| OpenAQ (AWS S3) | Non-US or global | ~2016–present | Yes (raw values) | Free | **Yes — non-US recommended** |
| Xweather archive | Already subscribed users | Jan 2024–present | Yes | Subscription + 5x multiplier | Marginal |
| IQAir API | Real-time / forecast only | 48 hours (Enterprise) | Yes | Paid (undisclosed) | **No** |

---

*Sources consulted for this survey (all fetched 2026-06-21):*
- https://www.xweather.com/docs/weather-api/endpoints/airquality-archive
- https://www.xweather.com/docs/weather-api/endpoints/airquality
- https://www.xweather.com/docs/weather-api/getting-started/rate-limiting
- https://www.pwsweather.com/contributor-plan/
- https://docs.airnowapi.org/webservices
- https://docs.airnowapi.org/faq
- https://docs.airnowapi.org/docs/HourlyAQObsFactSheet.pdf
- https://aqs.epa.gov/aqsweb/airdata/download_files.html
- https://aqs.epa.gov/aqsweb/documents/data_api.html
- https://www.airnow.gov/about-the-data/
- https://catalog.data.gov/dataset/airnow-real-time-air-quality-rest-api
- https://docs.openaq.org/resources/measurements
- https://docs.openaq.org/using-the-api/rate-limits
- https://docs.openaq.org/aws/about
- https://registry.opendata.aws/openaq/
- https://openaq.medium.com/2025-year-in-data-59d62a4f31cd
- https://openaq.medium.com/how-in-the-world-do-you-access-air-quality-data-older-than-90-days-on-the-openaq-platform-8562df519ecd
- https://docs.openaq.org/resources/countries
- https://www.iqair.com/us/air-pollution-data-api
- https://www.iqair.com/support/knowledge-base/how-can-i-access-historical-data-on-the-iqair-platform
- https://kitwaicloud.github.io/elk/openaq.html
- https://forum.airnowtech.org/t/automatically-grabbing-files-on-files-airnowtech-org/204
