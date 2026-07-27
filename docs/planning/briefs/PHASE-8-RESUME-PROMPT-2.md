# Phase 8 resume prompt #2 — session handoff, 2026-07-26 (evening)

**Supersedes [PHASE-8-RESUME-PROMPT.md](PHASE-8-RESUME-PROMPT.md)**, which is now history, not instructions.
Current as of meta `60e96ea` and marine `c97dd73`.

**Paste everything below the rule into a new session.**

---

You are the coordinator for **Phase 8 of `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`**, resuming
partly-executed work. The plan is mandatory. Log concerns in `docs/archive/MARINE-SEP-CONCERNS.md`.

**Read, in this order, before acting:**

1. This prompt, in full.
2. `docs/ARCHITECTURE.md` — the SWAN sections (grid levels, bathymetry, datum).
3. `docs/decisions/ADR-098-swan-datum-consistency.md` — **amended 2026-07-26**, amendments marked inline.
4. `rules/clearskies-process.md` — especially "Over-triggering is a failure mode too" and "Validate against
   reality, never against the model's own output".
5. `rules/coding.md` §1 — "A model runs on all its inputs or it does not run."
6. The plan's **T8.11** section (new) and the T8.10 subtasks.
7. `docs/archive/MARINE-SEP-CONCERNS.md`, last ~200 lines (C-88 → C-93).

**Verify state yourself** with `git status -sb` in every repo and against the live hosts before trusting any
summary, including this one.

**You may push and deploy as needed — this is a test environment with no live traffic.** But do not deploy
the marine service until the blocker in §3 is cleared.

**Carry the architectural change block in every implementation agent prompt.** For T8.11, triggers 7
(dependency) and 4 (data contract) are authorized **for that task's stated scope only**.

---

## 1. The single open question — answer this first

**Authorization to begin T8.11a**: install `vyperdatum` plus NOAA's PROJ separation grids on librewxr and
prove a real NAVD 88 → LMSL **array** transform works offline, before any integration code. It adds a
dependency (trigger 7), so it needs the operator's explicit go.

The decision *to do* T8.11 is already made and recorded in ADR-098 and the plan. What is unauthorized is
starting it. Do not begin implementation before this is answered; do unblocked work meanwhile (§5).

## 2. DONE and verified this session

**C-90 — fabricated bathymetry. Fixed, measured, committed, NOT deployed.**

Root cause: `bbox` was set to exactly the model domain with zero margin, but the resolvers subset with
`sel(lat=slice(...))` — which returns only cells *inside* the request — and then `coarsen(boundary="trim")`
discards the remainder. The returned grid is therefore **always** inset, so the outer ring of SWAN cells had
nothing to interpolate from and was filled with a magic −15 m. Structural: every level, every install. The
DEM itself had zero holes.

| grid | before | after |
|---|---|---|
| L1 | 49/616 fabricated, 1.3–697.0 m | **0 fabricated**, 0.3–736.2 m |
| L2 | 603/5904 fabricated, 0.2–35.9 m | **0 fabricated**, 0.0–50.0 m |
| L3 | 0/7084 | 0 |

Six fabrication sites removed. Unknown depths are now declared to SWAN with `INPGRID BOTTOM … EXCEPTION`
(user manual: exceptional points are "permanently excluded from the computations"). Fetch now requests the
domain **plus one cell of that level's resolution**, and a source that does not cover the domain is rejected
in favour of the next. Marine `b2a3177`, `c1f9ff9`, `c97dd73`.

**C-91 — selection corner geometry. Fixed and confirmed with the real code against the full catalogue:**
W = 46222 (7.7 km, 487.9 m), S = 46223 (16.9 km, 461.6 m) — 2 stations, one per side.

**Retired-station behaviour verified empirically**, not by reading: a fabricated station inside the distance
limit returned NOMADS 404 and was recorded as a `StationRejection` while selection proceeded. Shipped-
catalogue drift is harmless.

**Ocean station catalogue built:** 4,036 stations, `complete=True`, cycle `20260726/12`, 2,922 s, 288,441
bytes at `/etc/weewx-clearskies/marine/ww3_station_catalogue.json` on librewxr.

## 3. THE DEPLOY BLOCKER — read before restarting anything

Marine `c97dd73` makes **ETOPO 2022 15 arc-sec bed elevation** L1's primary source, pinned via
`mosaicRule`/`lockRasterIds` with its datum read from the NCEI catalogue. ETOPO is **MSL**; L2/L3 are
**NAVD 88**. The runtime reads ONE datum for every level (`"L2 preferred, L1 fallback"` in
`providers/nearshore/swan.py`), so deploying now runs L1 with BOTTOM in LMSL against a WLEVEL in NAVD 88.

Measured live: CO-OPS `NAVD − MSL = 0.799 m` at HB Pier (9410660). Under `Hb ≈ γ·d` that is **~0.6 m of
breaking height** and **~40 m of break-point shift on a 1:50 slope**.

**T8.11 must land before the marine restart, T8.10j and T8.10h.** All five live bathymetry caches are
currently NAVD 88, so the *running* system is datum-consistent — it is the new commit that would break it.

## 4. SETTLED — do NOT re-open, re-test, or re-litigate

This session lost significant time re-deriving decided things. Each of these is closed:

- **L1 must be ETOPO.** Operator: *"we already know the DEMs have HUGE HOLES IN THEIR COVERAGE regardless!
  That IS NOT AN OPTION FOR L1, THAT RESEARCH IS DONE."*
- **No datum conversion by a single offset, ever.** Separations vary over short distances; it must be a
  grid. `normalize_to_msl()` applies one domain-centre scalar and is to be **deleted**, not enabled.
- **Per-level WLEVEL fetching: DENIED.**
- **Wave-inversion bathymetry (cBathy etc.): out of reach** — no camera network. Optical SDB only.
- **Datum policy is SELECTION first**, conversion only where selection cannot work — which, for the US at
  10 m, it cannot.
- **SWAN permits differing datums across nested grids** (BOTTOM datum is "arbitrary"; only BOTTOM↔WLEVEL
  must match within a run) — but the field unifies anyway, and so do we.
- **GEBCO/ETOPO mix datums in shallow water.** The nesting contains it because ETOPO serves L1 only and
  L1 contributes the boundary spectrum at L2's offshore edge (~35–50 m). Recorded in T8.11.
- **`omp_num_threads = 6`** is an operator ruling. Never touch.

## 5. Unblocked work if T8.11a is not yet authorized

1. **Ship the station catalogue as package data** — copy to
   `weewx_clearskies_marine/data/ww3_station_catalogue.json`, load as default, let an on-disk rebuild
   supersede it. Its row already exists in `docs/RELEASE-DATA-REFRESH.md`.
2. **Queued small fixes:** delete dead `_load_or_download_cudem_grid()` (`swan.py:275`); stale `:1900`
   comment; `ofs.py:~486` docstring (claims SWAN runs without current input — C-77 made that false);
   C-90b (`_query_vdatum_offset()` returns 0.0 silently twice — dies with T8.11b anyway).
3. **T8.10e** Great Lakes routing — `ww3_station_selection.py` supports `product="great_lakes"` but nothing
   passes it. Rebuild the GL catalogue (96 stations, ~1 min); it is **not** in the current file. **Do not
   configure the Whiting spot until the GLWU pull works** — a setup raise aborts the cycle for every spot.

## 6. Ordering constraints

- **T8.11 → restart → T8.10j → T8.10h.** T8.10j (cache/hotstart invalidation) must precede T8.10h, or
  T8.10h validates pre-fix output.
- T8.4 / T8.4b / T8.5 are unblocked and independent of T8.6.
- T8.9 runs after T8.10. T8.6 re-runs after T8.10.
- **Walk QC Gate 8 and the Part B QA table yourself. Do not accept agent reports.** "Data is flowing" is not
  verification — check physical plausibility against an external source.

## 7. Bring to the operator, do not decide

- **C-85 capability surface** (trigger 4). Pushed config has top-level `capabilities`/`locations`, both
  **empty**; the real data is under `marine.locations`. Recommend marine derives from `marine.locations`
  (no contract change). *"T8.6 can't pass without it" is a named non-excuse.*
- **May `/marine` gain a `spectralComponents` field?** (trigger 4, T8.10i). Recommend yes, reusing the
  existing `SpectralWaveComponent`.
- **QC Gate 8 conflict:** `api.conf` retains a `[swan]` section (kept deliberately at T8.2b) while the
  Part B QA table demands `grep -E "swan|surf_compute" api.conf` → no matches. Both cannot be right.

## 8. Repo state

**Nothing is pushed. Nothing is deployed.** Live caches still hold the pre-fix grids; they regenerate only
on a `POST /config` push.

- **marine:** `b2a3177`, `c1f9ff9`, `c97dd73`.
- **meta:** ARCHITECTURE syncs; `adc7c19`, `ca97dd6` (ADR-098 amendments); `2e4c1d5`, `76b4d9d`, `0c45f07`
  (SDB research entry); `60e96ea` (T8.11 tasks).
- Live scratch: `c:\tmp\marine-sep-P8-resume-scratch.md` — keep current per §0.4.

## 9. Process notes that earned their keep

- **Bash heredocs break** on quotes and apostrophes. Write the message with the Write tool, then
  `git commit -F <file>`. A commit message containing `"quoted text"` will shatter the shell — this
  happened again this session.
- `cd` inside a Bash call **persists**; use absolute paths.
- Run host Python as `sudo -u ubuntu /home/ubuntu/repos/weewx-clearskies-marine/.venv/bin/python`. To test
  edited modules without touching the deployment: copy the package tree to a scratch dir, overwrite the
  changed files, run with `PYTHONPATH` pointed at it.
- **Caches short-circuit tests.** `download_bathymetry_for_level()` returns the cached grid before any new
  code runs — patch `_CUDEM_GRID_PATH_L1` / `_L2` / `_CUDEM_L3_CACHE_DIR` to a temp dir, or you will measure
  the old behaviour and conclude nothing changed. This cost a full cycle.
- **Verify search-summary and agent claims.** A web-search summary asserted Surfline "incorporates
  satellite-derived bathymetry"; the underlying copy lists "satellite assimilation" and "bathymetry mapping"
  as *separate* items and never says it. Do not record inferences as facts.
- The operator is **actively annoyed by long replies, by re-litigating settled questions, and by being asked
  things that are researchable.** For physics/SWAN questions read the manual — `docs/reference/swan-user-manual.pdf`,
  already extracted to `/tmp/swanuser.txt` via `pdftotext -layout`.
- **If you imply a question, ask it explicitly.** "You may want to adjust" is not a question.
