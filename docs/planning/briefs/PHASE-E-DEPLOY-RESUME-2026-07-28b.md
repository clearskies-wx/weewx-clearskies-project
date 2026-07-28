# Phase E Deploy — RESUME BRIEF #2 (2026-07-28, compaction checkpoint)

**Purpose:** Resume the Phase-E live deploy + Gate E after compaction. Supersedes the state in
`PHASE-E-DEPLOY-RESUME-2026-07-28.md` (that brief's profile blocker is now FIXED). Agent contexts do
NOT survive compaction — re-verify commits from `git log`, re-dispatch any unfinished agent fresh.

**Role:** I am the **coordinator** for the Marine Model Restoration Plan Phase E. Read / verify /
dispatch / QC / commit / push. Every agent report is a CLAIM to independently re-verify (re-run tests,
read the diff, check the allowlist). Delegation + adversarial-QC is mandatory (operator instruction
this session): impl / tests / audit are separate agents; the auditor is blind to the others' work.

**Standing authorizations (still in force):** "Standing permission to push and deploy as necessary for
testing. Do not re-ask." "keep going unless there is a reason you need me." Surface NEW findings /
architectural triggers; keep working unblocked items.

**Operator posture this session:** deeply engaged on the bathymetry science — insisted I use the SWAN
manuals, not training data; corrected grid-resolution-vs-bathymetry-resolution conflation; directed
"resample what we already have, not re-download." Honor that.

---

## WHERE WE ARE (STOP POINT)

- **Marine service DEPLOYED on librewxr at `b1f5da3`** (profile fix + F1 open-beach fix + their tests).
  `/health` 200, auth enforced.
- **Profile blocker RESOLVED and confirmed live:** HB per-spot profile regenerates at native ~10.3 m,
  PCHIP ACCEPTS it (log: `spot 'huntington-city-beach-pier' profile cached (928 points, ...,
  32/32 per-transect profiles)`). New `swan_bathymetry_PROFILE_*.json` cache written.
- **Full SWAN run STILL BLOCKED on the live system** because the L3-nest and L4 **compute-bathymetry
  caches are never written at apply** (the E4→E2b tracked gap — swan.py `download_all_bathymetry` is
  only ever called with `allow_download=False`; nothing populates `swan_bathymetry_L3_{hash}` /
  `swan_bathymetry_L4_{hash}` for the final nest/L4 geometry). Runtime fails-clean: `RuntimeError:
  SWAN: bathymetry vertical datums do not agree ... no cache at swan_bathymetry_L3_.../L4_...`.
- **The fix for that gap is CODED LOCALLY but NOT pushed/deployed** (see commits below).

---

## COMMIT STATE (marine repo `repos/weewx-clearskies-marine`, branch `main`)

- `origin/main` = **`b1f5da3`** (pushed + deployed).
- Local ahead of origin, NOT pushed:
  - **`b5c056d`** — `fix(marine): resample per-cluster study-area bathymetry onto L3/L4 caches`
  - **`88273a2`** — `test(marine): guard tests for area-mean bathymetry resample + L4 coverage-box drift` (18 tests)
  - **(maybe) a 3rd commit** = the F1/F2/F3 margin remediation, if the `bathy-resample` agent finished
    before compaction. **CHECK `git log --oneline origin/main..HEAD` on resume.**

**Deploy flow reminder:** local edit → local commit → coordinator pushes → `deploy-marine.sh` pulls to
librewxr. The resample fix must be **pushed + deployed + config re-pushed** to unblock the live run.

---

## THE RESAMPLE FIX (b5c056d) — what it does and why (do NOT re-litigate the design)

**Operator directive:** don't re-download L3/L4 bathymetry; fetch the nearshore native seabed ONCE
over a study area enclosing the fine grids, and **resample** onto each grid.

**Key science (verified in the LOCAL SWAN manuals — cite these, they are real):**
- `docs/reference/swan-technical-manual.pdf` §2.3.7 (p.57): *"the large-scale bathymetry is represented
  by the **mean bed elevation** d(x) given at the computational grid points, so that refraction is
  resolved properly."* → the reducer is **area-mean**, matching the existing download's
  `.coarsen(...).mean()`.
- `docs/reference/swan-user-manual.pdf` §2.6.2 (p.18-19): input grid ≈ computational grid (align to
  the target's cells) so sharp features (sandbars/shoals) aren't "lost in the interpolation."
- SWAN interpolates the input BOTTOM grid onto the computational grid **pointwise (tri-linear), it does
  NOT average** — so we must supply seabed at ~grid resolution (per-grid coarsening is CORRECT, not
  redundant). D1's native profile stays on its OWN separate cache (never coarsened).
- **grid resolution ≠ bathymetry resolution.** HB's best native bathymetry is **10 m** (CUDEM); the
  `_PROFILE_MIN_RESOLUTION_M=3.0` is only a request floor (returns native 10 m at HB). See C-E04.

**Mechanism (b5c056d):** per-cluster, size a study-area extent = transect corridor ∪ cluster L3 grid ∪
structure-polygon±margin; download native once; after L4/nest sized, `assert_grid_encloses` (fail-clean
RuntimeError, no fabrication) then `area_mean_resample_grid` onto L3-nest (40 m) and L4 coverage box
(10 m), write `bathymetry_cache_path(...)`. New module `services/bathymetry_resample.py`
(`area_mean_resample_grid`, `l4_coverage_domain`, `assert_grid_encloses`). `swan.py` left untouched
(runtime read path frozen).

**Adversarial audit VERDICT (blind, commit b5c056d): core PROVEN sound.** Actively attacked and could
NOT break: C-90/fabrication (NaN preserved, output clamped to real source range), cache-format/runtime
key match (incl. optional `source_vertical_datum`), orientation (runtime reads dir from
`lat_first/lat_last`), **scientific equivalence** (RMS 0.009 m vs true area-weighted ground truth on a
non-aligned sloped+shoal case → resample ≡ download), performance (1.38 s for 10⁵-cell L4), scope,
manual citations. **18 independent guard tests (88273a2) pass** (my own re-run: 18/18).

---

## F1 REMEDIATION (HIGH finding — fail-clean, does NOT affect HB) — status + spec

**F1:** the upfront study-area margin `_STRUCTURE_STUDY_MARGIN_K=8` (→3010 m) under-derives — it covers
`compute_structure_grid_domain`'s grid-corner offset (~4·l_tip) but NOT `l4_coverage_domain`'s own
`max(along,across)` margin stacked on top. Required ≥ ~12·l_tip (+ footprint). A **deep-tip structure**
(jetty/breakwater tip ≥~40–50 m water) shortfalls → `assert_grid_encloses` raises → no cache → that
cluster's run aborts (C-77). **Fail-clean, never wrong seabed. HB (tip ~10 m) is comfortable (3010 m
provided vs 1730 m required).** The in-code "comfortably non-marginal" comment is FALSE for deep tips.
**F2 (LOW):** `np.errstate` doesn't suppress numpy "Mean of empty slice" warning → log flood at 10⁵
cells; use `warnings.catch_warnings()`. **F3 (LOW):** `area_mean_resample_grid` docstring says "single
nearest source cell" but fallback is PER-AXIS — fix docstring.

**On resume, decide (operator may weigh in):**
- **Option A — deploy the resample fix as-is now (b5c056d+88273a2), remediate F1 as fast-follow.** F1
  is fail-clean and cannot affect HB, so HB can go live and Gate E can proceed; fix F1 before any
  deep-tip structure is ever configured. Fastest path to the first full run.
- **Option B — land F1 first, then deploy.** Cleaner (no known-wrong margin / false comment shipped).

**F1 remediation spec (if re-dispatching — the `bathy-resample` agent's in-flight work may be lost):**
Re-derive the study margin so it provably ≥ the actual `l4_coverage_domain` margin-from-polygon for ALL
tip depths (5–150 m) and structure sizes. **Preferred:** compute a conservative worst-case L4 coverage
box upfront using `compute_structure_grid_domain`'s own along/across-span logic with **l_tip =
l_tip_max** (deep-water asymptote; real l_tip ≤ l_tip_max always) + the structure polygon dimensions,
and size the study area to enclose that — no hand-tuned multiplier. Acceptance: a sweep table (tip
5–150 m × structure sizes incl. a long jetty) with **0 shortfall + headroom**, HB row shown; fix the
false comment; F2 warning-suppression; F3 docstring. Allowlist: `grid_sizing_chain.py` +
`bathymetry_resample.py` ONLY. Do NOT touch the resampler core averaging or the coverage assertion
(audited clean). Then independently reproduce the sweep before accepting.

---

## RESUME STEPS (in order)

1. **`git log --oneline origin/main..HEAD`** — confirm `b5c056d`+`88273a2` present; check for a 3rd (F1)
   commit. `git status` clean. If F1 commit exists: independently verify it (re-run the tip-depth
   sweep → 0 shortfall; `git show --stat` = 2 files; `pytest tests/test_bathymetry_resample.py
   tests/test_profile_native_resolution.py tests/test_grid_sizing_coldstart.py -q` green). If not:
   choose Option A or B above (surface to operator), re-dispatch F1 per spec if Option B.
2. **Push** (standing permission): `git push origin main`. Pre-flight: `git fetch` + confirm remote not
   ahead (`git log HEAD..origin/main` empty).
3. **Deploy code:** from project root `bash scripts/deploy-marine.sh` (pull→venv→imports→unit→restart→
   verify health/auth). Confirms the new marine code online.
4. **Re-push HB config** (regenerates grid sizing → now writes L3/L4 caches via resample):
   ```
   scp -F .local/ssh/config -q C:/tmp/marine_payload.json librewxr:/tmp/marine_payload.json
   ssh -F .local/ssh/config librewxr "TOKEN=\$(sudo grep '^MARINE_SERVICE_SECRET=' /etc/weewx-clearskies/marine/secrets.env | cut -d= -f2-); curl -sk -X POST https://localhost:8780/config -H \"Authorization: Bearer \$TOKEN\" -H 'Content-Type: application/json' --data @/tmp/marine_payload.json -w '\nHTTP %{http_code}\n'"
   ```
   `C:/tmp/marine_payload.json` = HB-only (huntington-city-beach-pier w/ real 35-pt OSM pier polygon +
   huntington-harbor; NO Bolsa Chica — this is deliberate, Option A this round, operator-approved).
   Bolsa Chica's full def is saved at `<scratchpad>/live_marine.conf.json` for re-adding later.
5. **Watch:** grid sizing regenerates → this time the L3/L4 caches SHOULD be written (grep
   `swan_bathymetry_L3_|swan_bathymetry_L4_|resample|profile cached|assert.*enclos`). Then watch the
   **first FULL SWAN run** — it should COMPLETE + publish, **in cadence (~7 min target at ~12,600
   cells), NOT the old 75-min blowup** (the whole point of Phase E). Log tags:
   `grid sizing|profile cached|full SWAN run|run complete|published|ERROR|datum|overrun`.
   **Watch the resample apply-time duration** (L4 ~10⁵ cells; ~1.4 s in the probe but confirm live) and
   whether the ~3 km study fetch downloads OK (larger than before).
6. **Validate against REALITY, not model output** (rules/verification.md): once a run completes, compare
   published surf height / partitions to Surfline / Surf-forecast / NDBC — a completed run is NOT proof
   of correctness (the zero-energy-bug class completes and looks fine). This is Gate D territory but do a
   sanity read now.
7. **Walk Gate E** — the 27-row table in `docs/planning/MARINE-MODEL-RESTORATION-PLAN.md` (§"QC GATE E",
   ~line 1543). Each row needs a `file:line` read + a live number. Then the **blind adversarial** pass.
   **Known invariant-3 finding already surfaced live:** `marine invariant 3: 1 structure configured but
   0 of 32 transects shadowed` fired — that is **E11 item 2 / Gate E row 19**, resolve there. Other
   owed: E6 row 11 (`TRANSM 0.82` OBSTACLE line), E12 timeout value.

---

## KEY FACTS / ACCESS

- **SSH:** `ssh -F .local/ssh/config librewxr "<cmd>"` (from PROJECT ROOT — the config path is relative;
  if cwd is the marine repo, use `-F /c/CODE/weather-belchertown/.local/ssh/config`). `sudo` for root
  reads. Marine service: librewxr:8780, systemd `weewx-clearskies-marine`, caches +
  `swan_grid_sizing.json` + `spot_profiles/` + `swan_bathymetry_*` under `/etc/weewx-clearskies/`,
  config `/etc/weewx-clearskies/marine/marine.conf`.
- **Deploy script:** `scripts/deploy-marine.sh`. **Test runner:** bare `python -m pytest -q` (CPython
  3.14, no venv) from `repos/weewx-clearskies-marine`. Never run the full suite — targeted files only.
- **Probe scripts:** put in the SESSION SCRATCHDIR, not `$TEMP` (a stray `$TEMP/inspect.py` shadows
  stdlib). Run with `PYTHONPATH=$(pwd)` from the marine repo.
- **HB geometry (for F1 verification):** structure tip depth ~10.3 m; L4 real coverage box
  lat 33.6393–33.6682, lon −118.0232 to −117.9879; L4 grid rotation 221°, dx 10 m, ~5292 cells.

## CONCERNS REGISTER — `docs/planning/MARINE-MODEL-RESTORATION-CONCERNS.md` (created this session)

- **C-E01** — Bolsa Chica derived `beach_facing_degrees` = 49° (inland) vs SW ocean; verify transects
  march seaward BEFORE Bolsa Chica goes live.
- **C-E02** — admin/wizard silently drops structure `coordinates` on save (why HB's OSM polygon vanished
  from live config; manual config push is the workaround).
- **C-E03** — Bolsa Chica at 10 m spacing = ~589 transects (5.88 km beach); recommend ~200 m before it
  goes online. Cadence risk.
- **C-E04** — grid-res ≠ bathy-res; HB native = 10 m; the per-grid coarsening is CORRECT per SWAN manual
  (NOT a single-native-for-all-grids refactor — the manual says that's wrong). Remaining nit is pure
  network efficiency (re-fetch overlap) — the resample fix (b5c056d) already addresses most of it.

## SESSION LEDGER (2026-07-28, continued)

- Marine pushed earlier this session: `b1f5da3` (profile native-resolution fix `40b07a5` + F1 open-beach
  bbox fix `bb01e96` + known-answer tests `d5f92f9` + F1 guard `b1f5da3`). Deployed; profile blocker
  resolved live.
- Resample fix `b5c056d` + tests `88273a2` committed locally (NOT pushed). Audited: core sound, 1 HIGH
  (F1, fail-clean, non-HB) + 2 LOW remediation pending/in-flight.
- Meta repo: `MARINE-MODEL-RESTORATION-CONCERNS.md` created (C-E01..04); this resume brief.
- **Operator said "stop and compact before pushing and redeploy."** Nothing pushed since b1f5da3.
