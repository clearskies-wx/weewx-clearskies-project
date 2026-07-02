# Provider Registration & API Access Reference

**Date:** 2026-06-30
**Purpose:** Collect signup processes, account tiers, API key acquisition, and PWS contributor paths for all providers that require registration. For use in end-operator documentation and setup manuals.

---

## Clear Skies License & Provider Terms

Clear Skies is licensed under **GPL v3 for non-commercial use only**. Commercial use of Clear Skies requires a separate license grant from the project.

**Each operator is solely responsible for understanding and complying with the terms of service of every third-party data provider they configure.** Clear Skies provides the software only — we do not provide legal advice regarding provider compliance, commercial use classification, or tier eligibility. Operators must read and agree to each provider's terms independently.

The setup wizard and operator documentation should present provider terms/signup links and clearly state this responsibility, but must not interpret those terms on the operator's behalf.

## PWS Contributor Context

Most Clear Skies operators are personal weather station (PWS) owners already uploading data to weewx. Several major providers offer **free API access to PWS contributors** — this is the primary signup path for Clear Skies operators, not the general developer signup.

---

## 1. Xweather (via PWSWeather Contributor Plan)

### PWS Contributor Path (recommended for Clear Skies operators)

| Field | Detail |
|-------|--------|
| **Plan name** | PWSWeather Contributor Plan |
| **Cost** | Free (valued at $400+/year) |
| **What you get** | Xweather Weather API + Maps access (observations, 7-day forecasts, 24-hour hourly, sun/moon, places, alerts, observation summaries/archives, air quality) |
| **Rate limits** | 1,000 API accesses/day, 100/minute. 3,000 map units/day, 100/minute. |
| **Credentials received** | Client ID + Client Secret (Access ID + Secret Key) |
| **Commercial use** | Allowed by Xweather with attribution — operators must verify their own compliance with Xweather's terms |

**Signup steps:**

1. **Create a PWSWeather account** at `https://www.pwsweather.com/` — validate your email
2. **Register your station** — go to your PWSWeather dashboard, select "Add a station", enter station information
3. **Upload data** — configure weewx to upload to PWSWeather (weewx has a built-in PWSWeather uploader). Your station must be contributing quality data at least 22 hours/day.
4. **Wait for QA approval** — new stations must pass quality assurance checks; allow up to 4 days
5. **Activate the Contributor Plan** — go to `https://www.xweather.com/pricing/weather-api-pay-as-you-go/pws-contributor` (redirects from the old `signup.xweather.com/pws-contributor`). Associate your PWSWeather User ID to get your Access ID and Secret Key.
6. **Set credentials in Clear Skies** — enter the Access ID as `AERIS_CLIENT_ID` and Secret Key as `AERIS_CLIENT_SECRET` in the setup wizard

**Requirements:**
- Active PWSWeather account with a station uploading data
- Quality data contribution ≥22 hours/day
- Attribution required for public-facing use
- One subscription per PWS contributor

### General Developer Path (alternative)

| Field | Detail |
|-------|--------|
| **Signup URL** | `https://www.xweather.com/pricing/weather-api-pay-as-you-go` |
| **Free tier** | First 15,000 API accesses/month free (no credit card required) |
| **Pay-as-you-go** | $0.0006/access base rate with multipliers (1× for standard endpoints, 5× for AQI, 10× for lightning) |
| **Enterprise** | Custom pricing for 5M+ accesses/month, 99.99% SLA |

**Signup steps:**

1. Go to the Xweather pricing page and sign up for a free account
2. Log into your account and navigate to the **Apps** section
3. Click **New Application**, enter a project name and namespace
4. Copy your **Client ID** and **Client Secret**

### Config keys used by Clear Skies

| Env var | Value |
|---------|-------|
| `WEEWX_CLEARSKIES_AERIS_CLIENT_ID` | Your Access ID / Client ID |
| `WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET` | Your Secret Key / Client Secret |

---

## 2. OpenWeatherMap (OpenWeather)

### PWS Contributor Path

| Field | Detail |
|-------|--------|
| **Plan received** | Startup plan (free for PWS contributors) |
| **What you get** | Current weather, minute-by-minute forecast (1h), 15-min forecast (48h), hourly forecast (2 days), historical data (47+ years) |
| **Rate limits** | 600 calls/minute, 10,000,000 calls/month |
| **Data updates** | Every 10 minutes |

**Signup steps:**

1. **Create an OpenWeather account** at `https://home.openweathermap.org/users/sign_up`
2. **Connect your weather station** using the Weather Station API (`https://openweathermap.org/api/stations`)
3. **Contact OpenWeather** to request the free Startup plan for PWS contributors — this is not self-service; you must email/contact their support
4. **Receive your API key** — it will be emailed to you

**Note:** The Startup plan activation for PWS contributors requires manual contact with OpenWeather support. This is less streamlined than the PWSWeather/Xweather path.

### General Developer Path

| Field | Detail |
|-------|--------|
| **Signup URL** | `https://home.openweathermap.org/users/sign_up` |
| **Free tier** | 60 calls/minute, 1,000,000 calls/month. Includes: current weather, 3-hourly forecast (5 days), weather maps 1.0, air pollution API, geocoding. Data updates every 2 hours. |
| **One Call API** | Version 4.0 (successor to 3.0). Required for hourly/daily forecast details and alerts. Available on Startup tier and above. |

**Paid tiers:**

| Tier | Rate limit | Calls/month | Key features |
|------|-----------|-------------|--------------|
| Free | 60/min | 1M | Current, 3-hour forecast, AQI, maps 1.0 |
| Startup | 600/min | 10M | + minute forecast, 15-min forecast, hourly, 47yr history |
| Developer | 3,000/min | 100M | Same as Free feature set but higher volume |
| Professional | 30,000/min | 1B | + 30-day forecast, maps 2.0, relief maps |
| Expert | 100,000/min | 3B | + business API, all maps, all history, SLA |

**Signup steps:**

1. Create account at `https://home.openweathermap.org/users/sign_up`
2. API key is sent immediately in confirmation email — no approval needed
3. Subscribe to desired tier on the pricing page

### Config keys used by Clear Skies

| Env var | Value |
|---------|-------|
| `WEEWX_CLEARSKIES_OWM_API_KEY` | Your API key (32-character string) |

---

## 3. IQAir (AirVisual API)

### Signup process

| Field | Detail |
|-------|--------|
| **Signup URL** | `https://dashboard.iqair.com/` (create account or log in) |
| **Free tier** | Community plan — free, no credit card |

**Account tiers:**

| Tier | Cost | Calls/min | Calls/day | Calls/month | Data included |
|------|------|-----------|-----------|-------------|---------------|
| Community | Free | 5 | 500 | 10,000 | City-level AQI (US & China scales), real-time weather |
| Startup | Paid subscription | 100 | 100,000 | 1,000,000 | + station-level data, pollutant concentrations (PM2.5, PM10, SO2, NO2, O3, CO) |
| Enterprise | Paid subscription | 1,000 | 1,000,000 | 10,000,000 | + 7-day daily AQI forecast, 3-day 3-hourly forecast, weather forecasts, 48hr history |

**Note for Clear Skies:** The free Community plan does NOT include per-pollutant concentrations — only overall AQI. For full pollutant breakdown (needed for the AQI card's per-pollutant dots and for haze detection PM eligibility), operators need the Startup plan.

**Signup steps:**

1. Go to `https://dashboard.iqair.com/` — create an IQAir account or sign in
2. Click the **"Air quality API"** tab in the left menu
3. Click **"+ Create an API key"** (top-right button)
4. Copy your API key — it's available immediately
5. To upgrade beyond Community, contact IQAir sales

### Config keys used by Clear Skies

| Env var | Value |
|---------|-------|
| `WEEWX_CLEARSKIES_IQAIR_API_KEY` | Your API key |

---

## 4. AstronomyAPI.com

### Signup process

| Field | Detail |
|-------|--------|
| **Signup URL** | `https://astronomyapi.com/auth/signup` |
| **Cost** | Free. Section 6.1 of the ToS grants a "personal, worldwide, royalty-free, non-assignable and non-exclusive license." |
| **Rate limits** | Not publicly documented in the ToS. Contact CodeBreez (the company behind it) for high-volume or custom endpoint needs. |
| **Company** | CodeBreez, Colombo, Sri Lanka |
| **ToS** | `https://astronomyapi.com/terms-of-service` (last revised April 11, 2020) |
| **Credentials** | Application ID + Application Secret |

**Signup steps:**

1. Go to `https://astronomyapi.com/auth/signup` — create a free account
2. After login, go to your dashboard
3. Click **"Create Application"** to generate credentials
4. Copy your **Application ID** (visible anytime on dashboard) and **Application Secret** (**visible only once during creation** — save it immediately; if lost, create a new application and delete the old one)
5. Authentication uses HTTP Basic Auth: Base64-encode `applicationId:applicationSecret`

**Note for Clear Skies:** AstronomyAPI is optional — it provides eclipse contact times, altitudes, and obscuration data. Without it, Clear Skies falls back to Skyfield-only eclipse data (dates and types but no visibility tiers). The wizard should make this clear.

### Config keys used by Clear Skies

| Env var | Value |
|---------|-------|
| `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_ID` | Your Application ID |
| `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_SECRET` | Your Application Secret |

---

## 5. National Weather Service (NWS / NOAA)

### No registration required

| Field | Detail |
|-------|--------|
| **API URL** | `https://api.weather.gov/` |
| **Cost** | Free (public domain, U.S. government) |
| **API key** | None required (future: will switch to API key system, timeline unknown) |
| **Authentication** | User-Agent header required — should identify your application and include a contact email |
| **Rate limits** | Not formally documented; be respectful of the shared resource |
| **Coverage** | US + US territories + adjacent waters only |

**What Clear Skies operators need to do:** Nothing. The API configures the User-Agent header automatically. NWS is the recommended default forecast and alerts provider for US-based stations — zero signup friction.

---

## Providers That Require No Registration

These providers are keyless and need no operator action:

| Provider | Domain | Notes |
|----------|--------|-------|
| **Open-Meteo** | Forecast, AQI | Free, no key. Free tier is non-commercial only; paid subscriptions available at `https://open-meteo.com/en/pricing`. Operators must review Open-Meteo's terms for their use case. |
| **RainViewer** | Radar | Free, no key. Personal/educational use only per their terms. Operators must review RainViewer's terms for their use case. |
| **LibreWxR** | Radar, Satellite | Free (public API at `api.librewxr.net`). Self-hosted option available. AGPL-3.0 code. |
| **USGS** | Earthquakes | Free, no key. Public domain. |
| **7Timer** | Seeing forecast | Free, no key. |

---

## Summary: Recommended Operator Signup Order

For a typical US-based Clear Skies operator with a PWS:

| Step | Action | Time | Result |
|------|--------|------|--------|
| 1 | Register at PWSWeather.com, add station, start uploading | 10 min + up to 4 days QA | PWSWeather account |
| 2 | Activate Xweather Contributor Plan | 5 min | Xweather Client ID + Secret (forecast, AQI, alerts) |
| 3 | Register at OpenWeather, connect station, request Startup | 10 min + wait for support | OWM API key (optional, or skip if Xweather is primary) |
| 4 | Register at IQAir for Community API key | 5 min | IQAir API key (optional AQI provider) |
| 5 | Register at AstronomyAPI.com | 5 min | App ID + Secret (optional, for eclipse visibility tiers) |

**Minimum viable setup (US station):** Steps 1–2 give full forecast + AQI + alerts via Xweather for free. NWS forecast and alerts are keyless. Radar defaults to RainViewer (keyless). Earthquakes default to USGS (keyless). Almanac uses Skyfield (no key). A US operator can have a fully functional Clear Skies deployment with only a PWSWeather account + Xweather Contributor Plan activation.

**Non-US stations:** Open-Meteo (keyless, global) replaces NWS for forecasts. Xweather Contributor Plan works globally. IQAir or Open-Meteo covers AQI. Alerts via Xweather (global coverage) or OWM (One Call 3.0, paid).
