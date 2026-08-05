# ROUND P AUDIT BRIEF — blind adversarial audit of beach-profile unification

**Round identity:** Round P (profile unification), audit leg. Date 2026-08-05. Lead:
coordinator. You: clearskies-auditor. You are BLIND: you have NOT been shown, and must not
seek out, the implementing agent's commit messages, closeout reports, or the test-author's
tests. Audit the system, not the paperwork. (Reading source code and its git DIFFS is your
job; reading the implementer's PROSE about the code is what is barred — skip commit message
bodies and any docs/planning/briefs or scratch narratives for this round.)

## The claim you must try to DISPROVE

The beach-profile endpoint (`GET /surf/{location_id}/profile`, marine service
`weewx-clearskies-marine` on librewxr, deployed commit `8c2def8`) is claimed to now derive
`surfZones`, `waveShapes`, and `jackingFactors` from the SAME main-pipeline per-transect
arrays it publishes as `transect[]`/`breakPoints` (blended Hs, tide-aware depths, full
distances, published break points) — with NO second endpoint-local model run — and to
publish three new per-transect fields with correct semantics:

- `tideLevel` (m, LMSL-relative): the tide the pipeline used for this timestep.
- `waterlineDistance` (m | null): seaward-most crossing where the RAW signed profile's
  `signed_depth == -tideLevel`, linearly interpolated; null + WARNING when never reached.
- `beachElevation` (list of {distance, elevation} m): RAW signed profile as elevations
  (`-signed_depth`, positive up), unclamped, native resolution, distance ≤ max transect
  distance.

Expected live relations (verify independently, do not take these on faith):
- `surfZones.impactZone.startDistance` == outermost `breakPoints[].distance` (exact same
  arrays in/out).
- Interpolated `beachElevation` at `waterlineDistance` == `tideLevel` (to interpolation
  accuracy).
- `transect[].depth` values are CLAMPED solver inputs (floor 0.01 m); `beachElevation` is
  the ONLY unclamped land geometry. If you find land info claimed anywhere else, or
  clamping leaking into `beachElevation`, that is a finding.
- API side (weewx host, port 8765, api commit `ac96064`): the three new fields convert
  m→ft on the display path with `units` entries (`tideLevel`/`waterlineDistance`/
  `elevation` = "ft" for a foot-configured operator).

Look specifically for values that are right by accident, right for one timestep only,
right in cache but never recomputed, or right because a fallback fired silently. The
proxy on the weewx host caches this route (TTL 1800 s) and serves stale on marine
failure — a correct-looking payload can be a cached pre-change one; check `generatedAt`.

## Access

- Source (read-only): `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`
  (HEAD `8c2def8`), `c:\CODE\weather-belchertown\repos\weewx-clearskies-api` (HEAD
  `ac96064`). Diff range for the round on marine: `47c8084..8c2def8`; on api:
  `c1a8212..ac96064` (conversion table area). You may read any code/diff; you must not
  read commit message bodies, docs/planning narratives for this round, or tests added
  after 47c8084 (`git log --format=%h --name-only` is fine for *what* changed, `git log`
  prose is not).
- Live marine (read-only, from project root):
  `ssh -F .local/ssh/config librewxr '<cmd>'` — service journal via
  `sudo journalctl -u weewx-clearskies-marine ...`; direct endpoint via
  `SECRET=$(sudo grep -oP "(?<=MARINE_SERVICE_SECRET=).*" /etc/weewx-clearskies/marine/secrets.env); curl -sk -H "Authorization: Bearer $SECRET" https://localhost:8780/surf/huntington-city-beach-pier/profile`
- Live API (read-only): `ssh -F .local/ssh/config weewx "curl -sk 'https://localhost:8765/api/v1/surf/huntington-city-beach-pier/profile?cb=<nonce>'"`
  (the cb param busts the proxy cache key).
- You must NOT edit, commit, deploy, restart, or write anything anywhere — findings via
  SendMessage only. No git write operations, no pull/push/fetch/checkout.

## Three side-investigations (in scope, report findings only — do NOT fix)

1. **`endpoints/surf.py:389-423` `_compute_median_bathy_profile()`** feeds SurfBeat with
   no distance filter — negative-distance LAND points included in the median. Establish:
   does this corrupt SurfBeat's input, and did the Round P diff make it better/worse/
   unchanged? Cite lines and, if corrupt, quantify with a live transect.
2. **`jackingFactors` is an empty list** at HB pier both pre- and post-change. Establish
   from `_compute_jacking` (services/surf_1d_analytical.py) whether empty is correct for
   this bathymetry (no qualifying bars) or whether the detection is broken (e.g. a
   condition that can never be true on real arrays). Known bathymetry: sandbar structure
   exists in the CUDEM profile.
3. **Chronic SWAN hotstart failure:** journal shows 223× "persistent hotstart timestamp
   unparseable (token=None) — deleting stale hotstart, cold-starting" since Jul 28,
   including repeats within a single process lifetime. Each forces a cold start and (post-
   restart) hours of all-transect bulk-fallback. Locate the writer/reader of the hotstart
   timestamp token (`services/swan_runner.py`, and note `tests/services/
   test_hotstart_timestamp.py` exists — you may read THAT test, it predates this round)
   and identify why the token parses as None. Report the mechanism; do not fix.

## Verdict format

SendMessage to "main": for the main claim, either "could not disprove" WITH the list of
what you ruled out (each with the command/diff hunk that ruled it out), or numbered
findings — each citing file:line or a live command + output, classified
introduced-by-round vs pre-existing. Then the three side-investigation reports. Real
findings only: each must name a specific failure mode, missed constraint, or forced
rework. Generic tradeoffs are not findings. An empty audit is acceptable; an unsupported
PASS is not.
