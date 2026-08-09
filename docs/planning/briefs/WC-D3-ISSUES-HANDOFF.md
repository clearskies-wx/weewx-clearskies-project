# WC-D3 Issues — Handoff Prompt

**Date:** 2026-08-08
**Context:** Round WC (wind chop suppression) was implemented and deployed. WC-D1 (ST6 on L1) and WC-D2 (5s floor) are working correctly in production. WC-D3 (surf height range) has multiple issues visible on the live site.

## Current state of deployed code

- **Marine repo:** commit `65a7c73` on librewxr (running, no OOM, SWAN converges)
- **API repo:** commit `d6d6bc0` on weewx
- **Dashboard repo:** commit `43a8ceb` on weather-dev
- **Meta repo:** commit `57bcc27`
- Radar container is stopped (memory contention with SWAN)

## Issues to investigate (ALL of these, no coding until root causes are established)

### Issue 1: modelSurfHeightMin/Max are None in the API response

The API response for the first forecast entry shows:
```
modelSurfHeightMin: None
modelSurfHeightMax: None
```

Despite two qualifying partitions having real aggregated face heights:
```
partition 0: period=13.05s, meanFaceHeight=0.734m, peakFaceHeight=0.808m
partition 1: period=19.25s, meanFaceHeight=0.750m, peakFaceHeight=0.844m
```

The most recent code change (`65a7c73`) reverted to using `per_partition_breaks[].mean_face_height_m` filtered by `period_s >= 5.0`. This SHOULD produce non-null values given the data above. However, this was deployed moments before the handoff and a new SWAN cycle has not yet completed — the current API data is from the pre-fix cache. **First step: wait for the next SWAN cycle to complete and re-check whether the fields are populated.**

If still None after a fresh cycle, trace the computation in `surf_1d_pipeline.py` at both PipelineResult construction sites (~line 2352 and ~line 3415).

### Issue 2: Both groundswells should be breaking but individual transects show no breaks

The aggregated `perPartitionBreaks` shows `meanFaceHeight` for both the 13s and 19s partitions — meaning SOME transects broke. But the `breakPoints` on the representative transect show `faceHeight=None` and `breakerType=None`, suggesting the representative transect's own per-partition break results may be missing face height data.

**Investigate:**
- What does the representative transect's `per_partition` list look like?
- Do both partitions have PartitionBreakResult objects with break_points on that transect?
- If not, why? Is the bar too deep at the representative transect for these wave heights?
- Is the Q_b breaking fraction below `Q_B_VISIBLE = 0.05` at the representative transect for these conditions?

### Issue 3: Break point at ~100m (328 ft) offshore — physically impossible

The beach profile shows a break annotation at the far left edge (~328 ft from shore). For 1 ft waves (0.33m Hs), breaking depth would be roughly `0.33 / 0.73 ≈ 0.45m` — that's about 1.5 ft of water, which at Huntington is maybe 10-20 ft from shore, not 328 ft.

**Investigate:**
- What distance does the API report for the break points? (The raw data showed `distance=4.59m` and `distance=3.59m` — those are in METERS, ~15 ft and ~12 ft. But the profile chart shows the break at ~328 ft. Is the chart rendering the distance wrong, or is the API serving wrong distances?)
- Check the beach profile endpoint (`/surf/{id}/profile`) for the break point distances it serves — is it different from the surf endpoint's `breakPoints`?
- Is there a unit conversion issue (meters displayed as feet without conversion)?

### Issue 4: No wave reformation and shorebreak

After breaking over the bar, waves should reform in the trough and break again near shore. The profile shows only one break annotation (after the dominant-break filter) but even before that filter, there were only two breaks at the same location — no shorebreak.

**Investigate:**
- Does the 1D model's break state machine (Q_b onset/cessation/re-break from Round X) actually produce a shorebreak for these conditions?
- Is the 15cm reform floor (`_MIN_BREAK_DEPTH_M`) preventing re-break too aggressively?
- What does the full `break_points` list on the representative transect look like — how many breaks, at what distances?

### Issue 5: Impact zone extent of ~300 ft — physically impossible

The impact zone bar on the beach profile stretches from roughly the break point all the way to shore — about 300 ft. For 1 ft waves, the impact zone should be maybe 30-50 ft at most.

**Investigate:**
- What does the API serve for `surfZones` or `perBreakZones`?
- Is the whitewater/impact zone extent derived from roller energy (E_r from Round X), and if so, is the roller decay coefficient (β_D = 0.10) producing a physically realistic decay length?
- Is there a unit or scaling issue in how the zone extents are computed or rendered?

### Issue 6: Profile x-axis scale

The profile x-axis only extends to 328 ft. The operator expects a fixed standard scale based on location, not shrink-wrapped to the data.

**Investigate:**
- What determines the profile chart's x-axis extent? Is it data-driven (extends to the outermost feature) or fixed?
- What was the extent before the WC changes?
- Did the dominant-break filter change the `outerBreak` calculation that drives the extent?

## Files involved

- `weewx_clearskies_marine/services/surf_1d_pipeline.py` — WC-D3 min/max computation, break state machine, roller model
- `weewx_clearskies_marine/endpoints/surf.py` — entry wiring for modelSurfHeightMin/Max
- `weewx_clearskies_marine/endpoints/beach_profile.py` — profile endpoint, zone extents
- `weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx` — profile rendering, x-axis scale, dominant-break filter
- `weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx` — range display

## Rules

- **Investigate ALL six issues before proposing any code changes.**
- **Do not speculate** — pull actual data from the API, trace actual code paths.
- **The plan, architecture, and rules files are at:** `c:\CODE\weather-belchertown\docs\planning\SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md`, `c:\CODE\weather-belchertown\docs\ARCHITECTURE.md`, `c:\CODE\weather-belchertown\rules\*.md`
- **The SWAN manual is at:** `c:\CODE\weather-belchertown\docs\reference\swan-user-manual.txt`
- **SSH to librewxr:** `ssh -F c:\CODE\weather-belchertown\.local\ssh\config librewxr`
- **Marine service secret:** `sudo grep ^MARINE_SERVICE_SECRET= /etc/weewx-clearskies/marine/secrets.env | cut -d= -f2`
- **Surf endpoint:** `GET /surf/huntington-city-beach-pier` (requires Bearer auth)
- **Profile endpoint:** `GET /surf/huntington-city-beach-pier/profile` (requires Bearer auth)
