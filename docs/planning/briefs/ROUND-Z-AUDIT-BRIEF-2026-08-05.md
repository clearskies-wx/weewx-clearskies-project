# ROUND Z AUDIT BRIEF — blind adversarial audit of surf-zone truthing

**Round identity:** Round Z, audit leg. Date 2026-08-05. Lead: coordinator. You:
clearskies-auditor. You are BLIND: do not read the implementing agents' commit-message
bodies, closeout prose, docs/planning narratives for this round, or the Round Z test
files (tests/test_break_detection_z2.py, tests/test_zones_waterline_z1.py, and the
2026-08-05 additions to tests/services/test_hotstart_timestamp.py). Reading source code
and diffs is your job; reading the authors' prose about it is barred.

## The claims to DISPROVE

Deployed: marine `59f5e49` (process start 2026-08-05 05:21:53 UTC on librewxr), api
`c99f6d5` (weewx host). Diff range marine `b551d03^..59f5e49` for this round's source
(b551d03 itself was Round P-audited; your source focus is 4c0f7e7, b551d03, d0075fe and
their interaction), api `ac96064..c99f6d5`.

1. **Foam-to-waterline:** the aggregate foam zone now ends at the first transect sample
   at/inside the published tide-aware `waterlineDistance` (operator-approved criterion
   change), with the legacy bore criterion only as a fallback when no waterline exists.
2. **Break detection:** re-arm hysteresis (`_BREAK_REARM_HYSTERESIS = 0.15`) eliminates
   crossing-jitter "breaks" on depth-saturated profiles; the depth floor is now
   `_MIN_BREAK_DEPTH_M = 0.15` so a real shorebreak in 0.15-0.3 m water can register.
3. **perBreakZones:** new per-transect list, one entry per break (outermost-first),
   impact end clamped at the next break, innermost foam ends at the waterline; aggregate
   `surfZones` unchanged; null-mirrored when unavailable; API converts `breakDistance`
   and nested zone fields to display feet with a `units.breakDistance` entry.
4. **Hotstart:** `_read_hotfile_timestamp` scans past the LOCATIONS block (bounded at
   2 MB) instead of a 4096-byte prefix; the staleness check accepts a hotfile whose stamp
   is AT/AFTER the requested start and deletes only when the stamp PREDATES it.

## The one question that matters most — attack it hardest

**Does the 0.15 hysteresis over-suppress GENUINE double breaks?** Operator ground truth:
Huntington Beach almost always has a real double break (outer bar + inner/shore break).
The hysteresis requires H/d to drop below 0.85·gamma (= 0.6205 for gamma 0.73) in the
trough before an inner break can fire. If a typical HB bar-trough only drops H/d to, say,
0.65·gamma... wait — 0.65 < 0.6205? Compute it properly yourself: the question is whether
real trough geometry (bar crest ~2-3 m depth, trough ~3-4 m, from the spot's CUDEM
profiles at /etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json on
librewxr) drops the RATIO far enough to re-arm. Use real per-transect depth profiles +
the saturated-decay Hs model (Hs = min(Hs_offshore-decayed, gamma*d)) to quantify: on a
2 m swell day, does the ratio in the trough fall below 0.6205? If typical HB troughs do
NOT re-arm the detector, Round Z has traded a fake double break for a suppressed REAL
one — that is a CONFIRMED finding, report it with the numbers. If they DO re-arm, state
the margin.

Also look for: foam-end off-by-one at the waterline sample; perBreakZones clamp
inverting when breaks are closer than the 50%-energy decay distance; the Z5 ordering
check accepting a WRONG state (e.g. service down past the horizon: stamp then PREDATES
the new start — verify that path cold-starts); the endpoint's waterline=None branch;
values right for one timestep only; cached pre-change payloads (check generatedAt).

## Access (read-only — you never edit, commit, deploy, restart, or run pytest)

- Source: `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (HEAD 59f5e49),
  `...\repos\weewx-clearskies-api` (HEAD c99f6d5).
- Live marine: `ssh -F .local/ssh/config librewxr '<cmd>'` — journal via
  `sudo journalctl -u weewx-clearskies-marine ...`; endpoint via
  `SECRET=$(sudo grep -oP "(?<=MARINE_SERVICE_SECRET=).*" /etc/weewx-clearskies/marine/secrets.env); curl -sk --max-time 300 -H "Authorization: Bearer $SECRET" https://localhost:8780/surf/huntington-city-beach-pier/profile`
  (add `?transect_index=all` for the full set; slow under co-tenant load — patience, not
  a finding).
- Live API: `ssh -F .local/ssh/config weewx "curl -sk 'https://localhost:8765/api/v1/surf/huntington-city-beach-pier/profile?cb=<nonce>'"`.
- Spot bathymetry: `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json`
  on librewxr (sudo cat). Local SWAN manual at docs/reference/swan-user-manual.txt — do
  NOT web-search SWAN behavior.
- You may run your own read-only Python locally (the marine package imports fine from
  the repo root) to compute ratios/zones on real data — that is analysis, not testing.

## Verdict format

SendMessage to "main": per claim, "could not disprove" WITH what you ruled out (command/
diff hunk per item), or numbered findings (file:line or live command + output;
introduced-by-round vs pre-existing). The hysteresis-over-suppression question gets its
own section with the quantitative answer either way. Real findings only; an empty audit
is acceptable; an unsupported PASS is not.
