# UAT Bug-Fix Plan (Post Fix-it-List)

**Created:** 2026-05-24
**Source:** User UAT of deployed dashboard at weather-test.shaneburkhardt.com
**Predecessor:** docs/archive/FIX-IT-LIST-PLAN.md (completed, archived)

## Context

The Fix-it List plan was executed and deployed, but live UAT revealed 15 issues: runtime crashes from API data type mismatches, visual bugs (wrong compass direction, missing icons, font inconsistency), missing features (webcam/timelapse), and deployment gaps (earthquake/forecast fixes present in code but not in the deployed build).

## Bug Inventory

| # | Bug | Severity | Root Cause |
|---|-----|----------|------------|
| 1 | Humidity shows "--%"  | Critical | `outHumidity` can be `undefined` (API omits key); strict `!== null` guard passes; "%" appended unconditionally |
| 2 | Wind degrees shows "--" | Critical | SSE loop packets deliver `windDir` as string; `formatValue` rejects non-numbers |
| 3 | Wind compass points wrong way | High | Arrow points where wind comes FROM; user wants where it's GOING |
| 4 | Wind label wrong format | High | Shows "W --°"; should be "From the W 270°" |
| 5 | Forecast Lo temp "--" | Medium | NWS returns null tempMin for partially elapsed day — valid but confusing |
| 6 | Lightning "0.0 km" / "0 strikes" when no data | High | `nearestDistanceKm ?? 0` coerces null to 0 |
| 7 | Radar centered on 0,0 (Gulf of Guinea) | Critical | Leaflet MapContainer center is init-only; station null on first render |
| 8 | Times missing timezone (PDT) | High | `formatLocalTime` missing `timeZoneName: 'short'` |
| 9 | Current Conditions missing weather icon | High | `WeatherIcon` component exists but never wired into card |
| 10 | Font inconsistency (serif/sans mix) | Medium | `font-sans` only on `html`; form elements use UA stylesheet fonts |
| 11 | Records page confusing columns + useless Notes | High | Column order: Value/Today/Date — illogical. Notes placeholder with no functionality |
| 12 | Earthquake page fixes not deployed | High | Code present (38fd80a) but deployed build predates it |
| 13 | Webcam + timelapse missing | High | Completely unimplemented — no code in any repo |
| 14 | Forecast icons not deployed | High | Same as #12 — deployment gap |
| 15 | Station longitude sign wrong | Critical | West of prime meridian needs negative longitude in weewx.conf |

---

## Phase 0: Station Config Verification

**Goal:** Fix station longitude (must be negative for US west coast) and verify API returns correct coordinates.
**Agent:** `general-purpose` (Sonnet) — SSH work
**Duration:** ~10 min

**Steps:**
1. SSH to weewx (192.168.7.20): `grep -A20 '\[Station\]' /etc/weewx/weewx.conf | grep -i 'lat\|lon'`
2. If longitude is positive (e.g., `117.99`), negate it to `-117.99`
3. Restart API: `sudo systemctl restart weewx-clearskies-api`
4. Verify: `curl -sk https://localhost:8765/api/v1/station | python3 -m json.tool | grep longitude`

**Acceptance:** Longitude is negative. API returns correct coordinates.

---

## Phase 1: Data Type Safety (Bugs 1, 2, 6)

**Goal:** Fix all "--" display bugs caused by undefined/string values from API/SSE.
**Agent:** `clearskies-dashboard-dev` (Sonnet)
**Duration:** ~25 min

### Task 1A: Fix null guards across all components

**Files:** `src/components/current-conditions-card.tsx`, `src/components/solar-uv-card.tsx`, `src/components/precipitation-barometer-card.tsx`

- Change ALL `!== null` guards on observation fields to `!= null` (loose equality catches both null and undefined)
- Audit every `observation.fieldName !== null` pattern in all three component files
- Ensure unit suffixes (%, °F, etc.) are INSIDE the conditional, not outside

### Task 1B: Coerce SSE string values to numbers

**File:** `src/hooks/useRealtimeObservation.ts`

In `mapPacketToObservation` (~line 124-131), add numeric coercion:
```typescript
let coerced: unknown = val;
if (typeof val === 'string') {
  const n = Number(val);
  coerced = Number.isFinite(n) ? n : null;
}
```

This handles SSE loop packets that deliver windDir as "270" instead of 270.

### Task 1C: Fix lightning null distance

**Files:**
- `src/api/types.ts` line 434: `nearestDistanceKm: number` → `nearestDistanceKm: number | null`
- `src/hooks/useWeatherData.ts` line 467: `nearestDistanceKm ?? 0` → `nearestDistanceKm` (keep null)
- `src/routes/now.tsx` ~line 549: Only show distance when not null
- Add i18n key `lightning.noActivity` to all 13 `now.json` locale files
- When count1h=0 AND count24h=0 AND distance=null, show "No activity detected" instead of zeros

**Acceptance:** Humidity shows real value with %. Wind degrees show number. Lightning shows "--" or "No activity" when no data. `npx tsc --noEmit` passes.

---

## Phase 2: Now Page Visual Fixes (Bugs 3, 4, 5, 7, 8, 9)

**Goal:** Fix compass direction, wind label, radar centering, timezone display, weather icon.
**Agent:** `clearskies-dashboard-dev` (Sonnet)
**Duration:** ~30 min
**Depends on:** Phase 1 (both touch now.tsx — must be sequential)

### Task 2A: Wind compass direction

**File:** `src/routes/now.tsx` ~line 157

Change: `rotate(${windDir}deg)` → `rotate(${(windDir + 180) % 360}deg)`

Arrow now points where wind is GOING, not where it comes FROM.

### Task 2B: Wind label "From the W 270°"

**File:** `src/routes/now.tsx` ~line 174-175

Change JSX to use i18n: `{t('windCompass.directionLabel', { direction: windDirLabel(windDir), degrees: formatValue(windDir, 'degrees') })}`

Add to all 13 `public/locales/*/now.json`:
- en: `"directionLabel": "From the {{direction}} {{degrees}}°"`
- Translate appropriately for each language

### Task 2C: Radar map — don't render until station loads

**File:** `src/routes/now.tsx` ~line 632-635

Change: `<RadarMap center={[station?.latitude ?? 0, station?.longitude ?? 0]} />`
To: `{station ? <RadarMap center={[station.latitude, station.longitude]} /> : <TileSkeleton className="h-96" />}`

Leaflet MapContainer ignores center prop updates after mount — this prevents it from initializing at [0,0].

### Task 2D: Add timezone to all times

**File:** `src/routes/now.tsx` ~line 32

Add `timeZoneName: 'short'` to `Intl.DateTimeFormat` options in `formatLocalTime`.

Also check and fix in:
- `src/routes/almanac.tsx` — its own `formatLocalTime`
- `src/routes/forecast.tsx` — any time formatting
- `src/routes/earthquakes.tsx` — earthquake time display

### Task 2E: Weather icon on Current Conditions card

**Files:**
- `src/components/current-conditions-card.tsx`: Add `weatherCode` prop. Import and render `WeatherIcon` at size 64px next to temperature.
- `src/routes/now.tsx`: Pass `weatherCode={todayForecast?.weatherCode ?? null}` to `CurrentConditionsCard`

### Task 2F: Forecast Lo temp graceful handling

**File:** `src/routes/now.tsx` ~line 362

When `tempMin` is null, show only the high: "Hi 67°" instead of "Hi 67° / Lo --°". Use a conditional i18n key.

**Acceptance:** Compass points where wind goes. Label says "From the W 270°". Radar centers on station. Times show "PDT". Weather icon shows on Current Conditions. `npx tsc --noEmit` passes.

---

## Phase 3: Records Page Fix (Bug 11)

**Goal:** Fix confusing column order, remove useless Notes card.
**Agent:** `clearskies-dashboard-dev` (Sonnet)
**Duration:** ~20 min
**Independent of Phases 1-2** (different file)

### Task 3A: Remove operator notes placeholder card

**File:** `src/routes/records.tsx` ~lines 129-135

Delete the entire Card block with `operatorNotePlaceholder`. Remove the i18n key from all 13 `records.json` locale files.

### Task 3B: Reorder and rename columns

**File:** `src/routes/records.tsx`

New column order: **Record | Today | Record Value | Date Set**
- Move "Today" column before "Value"
- Rename "Value" → "Record" (it's the all-time record value)
- Rename "Date Observed" → "Date Set"

Update i18n keys in all 13 `public/locales/*/records.json` files.

**Acceptance:** Records table reads logically. Notes card gone. All 13 locales updated.

---

## Phase 4: Font Audit (Bug 10)

**Goal:** Ensure Inter Variable renders on ALL elements — no serif leakage.
**Agent:** `clearskies-dashboard-dev` (Sonnet)
**Duration:** ~15 min
**Independent of Phases 1-3**

### Task 4A: Force font inheritance

**File:** `src/index.css`

Add to `@layer base`:
```css
button, input, select, textarea {
  font-family: inherit;
}
```

Ensure `body` rule includes `@apply font-sans`.

### Task 4B: Grep and fix any serif/mono leaks

Search `src/` for `font-serif`, `font-mono` (outside of Reports page pre-formatted text), explicit `fontFamily` style props, `Times`, `Georgia`. Fix any that shouldn't be there.

**Acceptance:** DevTools computed font-family shows "Inter Variable" on body, cards, buttons, headings.

---

## Phase 5: Rebuild + Redeploy

**Goal:** Deploy all fixes to weather-dev.
**Agent:** `general-purpose` (Sonnet) — SSH work
**Duration:** ~15 min
**Depends on:** Phases 0-4 all complete

**Deploy workflow (native, NOT Docker):**

```bash
# Dashboard
ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && git pull && npm ci --legacy-peer-deps && npm run build"
ssh weather-dev "sudo rm -rf /var/www/clearskies/assets && sudo cp -r /home/ubuntu/repos/weewx-clearskies-dashboard/dist/. /var/www/clearskies/"

# API already restarted in Phase 0 if weewx.conf changed
```

**Verification checklist:**
- [ ] Humidity shows value with % (not "--%")
- [ ] Wind degrees shows number (not "--")
- [ ] Compass arrow points where wind is going
- [ ] Wind label: "From the W 270°"
- [ ] Forecast: shows Hi only when Lo unavailable
- [ ] Lightning: "No activity detected" when no strikes
- [ ] Radar map centered on Huntington Beach, CA (correct negative longitude)
- [ ] Sunrise/Sunset times show "PDT"
- [ ] Weather icon on Current Conditions card
- [ ] Fonts: all sans-serif, no mix
- [ ] Records: Today | Record | Date Set order, no Notes card
- [ ] Earthquake page: pagination + badge fix visible
- [ ] Forecast page: weather icons + precip bars visible

---

## Phase 6: Webcam + Timelapse (Bug 13 — New Feature)

**Goal:** Add webcam live view and timelapse player.
**Duration:** 3 sub-phases, ~30 min each

### Phase 6A: API webcam endpoint
**Agent:** `clearskies-api-dev` (Sonnet)

- Add `[webcam]` config section to settings (image_url, refresh_interval, timelapse_dir, timelapse_max_frames)
- Add `WebcamResponse` Pydantic model
- Add `GET /api/v1/webcam` endpoint
- Register router in app.py
- Update api.conf.example

### Phase 6B: Dashboard webcam component + route
**Agent:** `clearskies-dashboard-dev` (Sonnet)

- Add `WebcamData` type, `useWebcam()` hook, API client function
- Create `src/components/shared/webcam-view.tsx` — auto-refreshing image + timelapse player
- Create `src/routes/webcam.tsx` page
- Add route to router, add nav link
- Add `webcam.json` locale files (all 13 languages)

### Phase 6C: Deploy webcam feature
**Agent:** `general-purpose` (Sonnet)

- Push both repos
- Deploy API (git pull + restart service on weewx host)
- Deploy dashboard (git pull + build + copy on weather-dev)
- Configure `[webcam]` in live api.conf with station's webcam URL

---

## Execution Order

```
Phase 0 (station lng)  ─┐
Phase 3 (records)      ─┤
Phase 4 (fonts)        ─┼─► Phase 5 (deploy) ─► Phase 6A ─► Phase 6B ─► Phase 6C
Phase 1 (data types)   ─┤
  └► Phase 2 (visuals) ─┘
```

Phases 0, 1, 3, 4 can run in parallel (different files/hosts).
Phase 2 must follow Phase 1 (both modify now.tsx).
Phase 5 waits for all code phases.
Phase 6 is independent new work after Phase 5 deployment is verified.
