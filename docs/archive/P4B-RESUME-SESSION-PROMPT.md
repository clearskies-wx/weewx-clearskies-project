# Phase 4B — resume prompt

**Written:** 2026-07-25, end of session. **State: clean.** Both repos committed and pushed;
nothing uncommitted, no agents running, no half-finished work in the tree.

Read this, then `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` **Phase 4B section in full**.

---

## Where things are

| | |
|---|---|
| API repo HEAD | `eca80ee`, pushed |
| Meta repo HEAD | `081206d`, pushed |
| Dashboard HEAD | `923dd0c`, pushed |
| librewxr | deployed at `eca80ee`, both services healthy (8767, 8770) |
| weewx | deployed at `eca80ee`, healthy (8765) |

**Phase 4A: complete.** All 11 tasks done, audit's 3 BLOCKERs (F1/F2/F3) remediated and verified
live. T4A.5 ran: HB profile regenerated (629 points, NAVD88), HB Pier confirmed **viable**, full
SWAN run completed on the new code in 1200 s, face heights track Surfline (5.93 ft vs their
4–6 ft).

**QC Gate 4A: deferred by the operator.** Not blocked — deliberately skipped to start 4B. Its
checklist has never been walked.

**Phase 4B: approved, docs synced, zero code written.**

---

## What Phase 4B is

SWAN L3 computes a 2D wave field. The handoff to SwellTrack collapses it to **one point per
spot** and replicates that value across all 32 transects — so the alongshore variation the 2D run
spends 1200 s computing is discarded at the boundary. 4B makes each 1D line read the field at its
own location.

Found when the operator asked what the CURVE transect was for. **Pre-existing, not a 4A
regression** — Amendment 2 fixed the handoff's *time* dimension and never touched *space*. The
adversarial audit missed it too: check A1 asked whether stations *within* the one curve aligned;
nobody asked why there was one curve.

## Operator rulings from this session — do not re-litigate

- **Approved:** per-transect handoff (trigger 3), distinct `handoff_by_transect` values
  (trigger 4), station spacing 50 m → 10 m to match the L3 grid (trigger 3).
- **NOT yet approved:** replacing `decompose_spectrum()` with SWAN's watershed partitioning
  (trigger 1). Approved only to *build and measure* the comparison. The operator decides on the
  numbers.
- **Accepted limitations:** L2's 100 m resolution means ~3 distinct cells across a 320 m spot —
  "still better than ALL coming from the same cell." Higher-resolution bathymetry shoreward of
  15 m is hard to obtain and is a standing limitation to live with.
- **T4B.5 CLOSED:** SurfBeat stays alongshore-uniform. The IEM's biphase equation assumes "mild
  and alongshore uniform" bottom slopes. Do not make it per-transect.
- **Gate 4A deferred.**

## Next actions

1. Re-dispatch the two agents. Prompts are in this session's history; scope was correct.
   - **Agent A** — T4B.1/T4B.3/T4B.4. Owns `swan_formats.py`, `swan_runner.py`,
     `transect_handoff.py`, `swan_domain.py`.
   - **Agent B** — T4B.2. Owns `swan_spectral.py`, `surf_1d_pipeline.py`.
2. **Sequencing issue B caught before being stopped:** real PT* TABLE columns will not exist
   until A's emission change lands, so B's watershed side would be synthetic. **Either run A
   first, or accept synthetic data and label it.** Decide deliberately.
3. Then T4B.6 (wire distinct values through — 5 call sites), T4B.7 (ADR-093 Amendment 3),
   T4B.8 (verify against real data), QC Gate 4B.

## SWAN facts verified this session — use these, do not re-derive

All in `docs/reference/swan-commands-extract.md`. Verified against the 41.51 manual
(`/tmp/swanuse.txt` on librewxr) **and** the Fortran source (`/tmp/swan_src/src/`).

- `POINTS 'sname' FILE 'fname'` — arbitrary output coordinates, **degrees** for spherical
  (manual p. 92). No output-point count limit exists in the manual.
- `SPECOUT` accepts a POINTS set (p. 108), identical to CURVE. Point output is **interpolated
  from the computational grid** (p. 90; `SWOEXA`/`SWOEXD`).
- `TABLE` accepts `PTHSIGN|PTRTP|PTWLEN|PTDIR|PTDSPR|PTWFRAC|PTSTEEP` (`swanpre2.ftn:1572`),
  using the Hanson & Phillips (2001) watershed algorithm. Partition 01 = wind sea, 02–10 swells
  descending. `PARTIT` is BLOCK-only.
- Each keyword expands to **10 columns** (`HsPT01`…`HsPT10`). Individual partitions are rejected.
- **`PTDIR`'s exception value is `-999`; every other PT variable uses `-9`** (`swanmain.ftn:2649+`,
  `OVEXCV`). A uniform-sentinel parser reads absent partitions as real data.
- `SPECOUT … S` = frequencies **above** the IG cut-off (sea-swell); **`L` = below it (the IG
  spectrum)**. Both surfbeat-only. `HBIG` = bound IG wave height, first COMPUTE only.
- SURFBEAT requires: regular `REG` grid, `MODE STATIONARY`, `BOUND SIDE WEST` only, two bare
  COMPUTEs, shoreline `OBSTACLE` with `TRANSM`/`REFL`/`RDIFF`. `surfbeat_runner.py` already does
  all of this correctly. The west-boundary/+x-east requirement is a **portability limit** — fine
  at HB, broken on an east-facing coast.

## Measured numbers — do not re-estimate

- `TABLE_1.txt` **204 KB** vs `SPEC_1.txt` **7.4 MB**, same 18 stations × 73 timesteps. TABLE-based
  handoff is ~12 MB even at 60× the points. `/var/run` is tmpfs, 9.4 GB with 8.9 GB free — the
  real costs are parse time and RAM, not disk or bandwidth.
- **73/73 timesteps clamped** on the 2026-07-25 07:06Z run. Handoff landed at ~2.25× breaking
  depth instead of 1.3×, because the two shallowest stations are 0.98 m (boundary, correctly
  excluded) and 2.37 m with nothing between.
- HB profile: 629 points, uniform 1.5 m, 0 → 10.2 m over 942 m. Deepest handoff needed 7.12 m, so
  coverage is adequate.
- Source DEM has **no sandbar field** — 1 local depth minimum at 8.57 m native sampling, 7 cm
  relief, outside the surf zone. Hence zero jacking factors and all-spilling breakers. Accepted;
  future fix is satellite-derived bathymetry, see `FUTURE-ENHANCEMENTS.md`.

## Coordinator mistakes this session — the shape of them, so they are not repeated

1. **Two consecutive wrong rulings on the L3 shoreward edge.** Both were mine; the second was
   caught only because agent B2 refused to implement it and quoted the brief back. The answer was
   in ADR-093 Amendment 2 §2 the whole time. **Read the governing doc in full before ruling.**
2. **`deploy-compute.sh` stripped librewxr's SWAN dependencies** — `uv sync --frozen` against a
   venv both services share, with a lockfile that has zero occurrences of "nearshore". systemd
   reported `active` because the process held old code in memory. Fixed in `7901a84`; the script
   now verifies imports. **`uv.lock` still lacks the extras — `uv sync` can never provision that
   host correctly.**
3. **Called 4–6 ft surf "flat"** and used it to explain away the 73/73 clamping. The operator
   produced a Surfline screenshot. The real cause — station spacing — was already in the run
   output. **Do not reach for an environmental explanation before checking the mechanism.**
4. **Quoted costs twice without sizing them** (435 MB, then "10–40×"). Both were wrong by an order
   of magnitude. **Measure before escalating.**
5. **Audit findings were reported in chat only** and nearly lost. Now at
   `briefs/P4A-AUDIT-FINDINGS.md`. **Write findings to a file as part of the audit.**

## Tracked, not done

- QC Gate 4A checklist — never walked.
- Dead legacy 2-level SWAN path, `swan_runner.py` ~1015–1314.
- `download_bidirectional_profile()` — zero production callers.
- `tests/services/test_swan_runner.py` — 15 pre-existing collection errors (missing `inner_bbox`).
- Alongshore shadow-zone multiplier applied to the wrong axis (pre-existing; B2 found it).
- Dashboard `public/card-manifest.json` has an **uncommitted** `marine-summary` card entry of
  unknown provenance. Left alone.
- Three named operator gaps in `P4A-AUDIT-FINDINGS.md` (BackgroundTasks progress, L3-disabled
  staleness, HB's two vertical datums).
