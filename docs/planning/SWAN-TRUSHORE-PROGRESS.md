# SWAN+TruShore Implementation — Progress Tracker

**Session 1:** 2026-07-16 to 2026-07-17
**Session 2:** 2026-07-17
**Session 3:** 2026-07-17
**Session 4:** 2026-07-17
**Session 5:** 2026-07-17 (current)
**Plan:** docs/planning/SWAN-TRUSHORE-PLAN.md
**Status:** Phases 0–5 complete. Phase 6 T6.1–T6.3 done. Phase 7 T7.0–T7.4 complete. T7.5 in progress — SWAN pipeline end-to-end functional, producing real surf forecast data with CUDEM bathymetry and hotstart support. Remaining: period/scoring per-timestep variation, remove debug logging, final QA.

## Phase Tracker

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0 — ADR & Manual Updates | ✅ COMPLETE (2026-07-16) | Pre-session 1 |
| Phase 1 — HRRR Wind Provider | ✅ COMPLETE (2026-07-16) | QC Gate 1: 9/9 pass |
| Phase 2 — SWAN Model Integration | ✅ COMPLETE (2026-07-17) | QC Gate 2: PASS |
| Phase 3 — TruShore Post-Processing | ✅ COMPLETE (2026-07-17) | QC Gate 3: PASS |
| Phase 4 — Separated Service Option | ✅ COMPLETE (2026-07-17) | QC Gate 4: auditor pass (session 3) |
| Phase 5 — Dashboard Integration | ✅ COMPLETE (2026-07-17) | QC Gate 5: auditor pass (session 3) |
| Phase 6 — Final QA Audit | 🔄 IN PROGRESS | T6.1–T6.3 done. T6.4/T6.5 deferred to Phase 7 T7.5. |
| Phase 7 — Remedial: Nested Grid + GFS Wind | 🔄 IN PROGRESS | T7.0 complete (docs). T7.1–T7.5 pending (code + verification). |

## Session 4 Work Completed

### T7.0 — Document and manual updates (COMPLETE)

All governing documents updated to describe nested grid architecture, GFS wind supplement, and memory budget before any coding begins:

| Document | Changes |
|----------|---------|
| `docs/manuals/API-MANUAL.md` §17 | SWAN integration table: added GFS wind for hours 48–72, nested grid description, blended wind forcing section, updated schedule to 4×/day extended cycles, cache TTL 6h, wind source table now shows `gfs_trushore` for hours 48–72 |
| `docs/manuals/PROVIDER-MANUAL.md` §14.14 | Added HRRR forecast range limitation table (18h vs 48h cycles), extended cycle usage note, cache TTL updated to 6h |
| `docs/manuals/PROVIDER-MANUAL.md` §14.15 | Replaced single flat grid with nested grid table (outer 2–3km + inner 200–500m), ≤300 MB memory budget, added GFS to input sources, runner API updated for nested execution, cache TTL 6h, schedule 4×/day |
| `docs/manuals/PROVIDER-MANUAL.md` §14.16 | NEW: GFS wind provider — module identity, NOMADS URL, 0.25° resolution, 384h range, 3-hour timesteps, earth-relative winds (no rotation), 6h cache TTL, graceful degradation on GFS failure |
| `docs/ARCHITECTURE.md` | SWAN+TruShore note: nested grid description + memory budget + GFS provider. Standalone service: 4×/day. Provider layout: `gfs` added to `wind/`. Caching TTLs: HRRR/GFS/TruShore all 6h |
| `docs/manuals/DASHBOARD-MANUAL.md` | TruShore refresh interval: 3300s → 21600s |
| `docs/manuals/OPERATIONS-MANUAL.md` | Wizard flow: nested grid parameters (outer resolution, inner resolution, inner nest bbox) |
| `repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md` §5 | Intro: nested grid + blended wind + 4×/day. Prerequisites: GFS provider. Wizard: nested grid field table (outer/inner). Admin: outer/inner resolution fields + memory budget. Troubleshooting: OOM guidance. §6 wizard step: nested grid params. §7 admin: nested grid resolutions + memory |
| `docs/planning/SWAN-TRUSHORE-PLAN.md` | Verification section: wind source updated for HRRR + GFS |

**Verification sweep:** Grepped all governing documents for stale references (flat grid, single resolution, hourly schedule, 55-min TTL, swan_grid_resolution_m). Zero stale references remain in manuals, ARCHITECTURE.md, or Operator Manual. Plan and research brief references are historical context (documenting what went wrong), not governing.

## Session 3 Commits

### Stack repo (weewx-clearskies-stack)

| Commit | Description |
|--------|-------------|
| 6793dec | fix(T4.4/T4.5): add 72 i18n keys + fix Jinja2 do extension + docstring |
| 67959bd | docs(T4.6): add SWAN+TruShore section to Operator Manual |
| 6a29ab6 | docs(T4.6): update §3 wizard step list and last-updated date |

### Dashboard repo (weewx-clearskies-dashboard)

| Commit | Description |
|--------|-------------|
| def032e | fix(a11y): increase NearshoreModelIndicator info icon to 24px touch target |

### API repo: no new commits this session (session 2 commits pushed)

## Session 3 Work Completed

### T4.4/T4.5 i18n (HIGHEST PRIORITY — resolved)
- 72 new translation keys added to all 13 locale files
- Keys cover wizard trushore step + admin trushore section + route handler error messages
- All 13 JSON files validated

### T4.4 Jinja2 fix (resolved)
- `{% do lats.append() %}` replaced with pre-computed `default_bbox` in route handler
- POST error re-render also passes `default_bbox` context
- No Jinja2 `do` extension required

### T4.4 docstring fix
- `GET /wizard/step/9` route: "step 15" → "step 16" (review step)

### T4.6 Operator Manual
- §5: new SWAN+TruShore subsection (Prerequisites, Wizard Setup, Admin Maintenance, Troubleshooting)
- §6: SWAN+TruShore conditional wizard entry
- §7: Managing SWAN+TruShore admin entry
- §3: wizard step list renumbered (14=TruShore, 15=TLS, 16=Review)

### Phase 5 a11y fix
- NearshoreModelIndicator info icon: 20px → 24px (WCAG 2.5.8 minimum)

### Deploys
- API: pushed and deployed to weewx (service active)
- Dashboard: pushed and deployed to weather-dev (serving HTTP 200)
- Stack: pushed to GitHub

## Phase 6 Progress

| Task | Status | Evidence |
|------|--------|----------|
| T6.1 QC gate re-audit | ✅ DONE | Phases 0–3 verified via code inspection; Phases 4–5 via auditor agent |
| T6.2 Silent deferral sweep | ✅ DONE | 27/27 tasks committed, 0 deferrals, 0 missing |
| T6.3 Manual-code consistency | ✅ DONE | NWPS=0 refs, WW3 not in surf fallback, HRRR provider exists, ADR-084 superseded, ADR-093/094 Accepted |
| T6.4 End-to-end SWAN output | ⛔ BLOCKED | SWAN not installed on weewx host (`which swan` → not found) |
| T6.5 Performance verification | ⛔ BLOCKED | Requires SWAN running on weewx host |

## QC Gate 4+5 Audit (Session 3)

Auditor reviewed all files. Findings pending final report.

## Session 5 Work Completed (2026-07-17)

### Bugs fixed (SWAN pipeline end-to-end)

| Bug | Root cause | Fix |
|-----|-----------|-----|
| `_warm_swan()` silently returns | Run marker stored on empty results; HRRR cache returned same cycle; dedup skipped at DEBUG level | Gate run_marker on `spots_cached > 0` |
| SWAN exits 0 with errors | `_spawn_swan()` only checked exit code, not stderr/Errfile | Check for "Severe error" in Errfile after exit 0 |
| TABLE parser misses all rows | SWAN 41.51 column header is `Hsig` not `HS`; `TIME` not requested; multi-line `%` header not parsed | Accept HSIG/HSIGN; request `TIME HSIGN` in TABLE command; scan `%` lines for column names |
| Validation rejects all output | `Tm01 < 1.0s` threshold rejected valid weak wind-sea; no QUANTITY excv set | Use SWAN `QUANTITY excv=-9.` sentinel; only reject ≤ -9 and extreme upper bounds |
| Tmpdir invisible from SSH | systemd `PrivateTmp=yes` hid tempfile dirs | Fixed path `/var/run/weewx-clearskies/swan/` |
| Flat 15m bathymetry | `cudem_bathymetry = {}` hardcoded; 2-D grid download deferred as "later task" | `download_swan_depth_grid()` via NCEI getSamples (POST, 1000-point batches); cached to `/etc/weewx-clearskies/swan_bathymetry.json` |
| Cold-start spin-up (t=0 shows 0.1ft) | No hotstart — every run starts from near-zero JONSWAP | `INIT HOTSTART` + `HOTFILE` per SWAN manual §4.5.3/§4.7; hotstart persists across runs |

### Commits (API repo)

| Commit | Description |
|--------|-------------|
| ee13dc9 | fix(trushore): gate run_marker on success + detect SWAN stderr errors |
| b3348b6 | debug(T7.5): fixed-path SWAN workdir + validation logging |
| 81a0b89 | fix(swan): accept HSIG column header from SWAN 41.51 |
| 59b4225 | fix(swan): use correct SWAN output quantity names per user manual |
| 78b1f7c | fix(swan): QUANTITY excv, header detection, validation per SWAN docs |
| c8261e9 | fix(swan): SET MAXERR 3 — SWAN was aborting on boundary warnings |
| c963fee | fix(swan): wire real CUDEM 2-D bathymetry into SWAN pipeline |
| 8904220 | fix(trushore): move CUDEM load after resolution config |
| a206977 | feat(swan): hotstart support — eliminates cold-start spin-up |

### Verification

- SWAN producing 67 timesteps of varying wave data (0.1ft → 4.0ft south swell over 72 hours)
- CUDEM 2-D grid: 65×78 = 5,070 points downloaded in 3.5 seconds, 2,215 ocean / 2,855 land
- Supplement pipeline active: `swellHeight` differs from `waveHeightAtBreak` (structure effects apply Kt < 1.0)
- Face height conversion working: `breakingFaceHeight` > `waveHeightAtBreak` for swell periods
- Dashboard displaying "Model: SWAN+TruShore" with live data

### Remaining issues

- **Period identical across all timesteps (8.2s)** — per-timestep period not varying in surf endpoint response
- **qualityStars identical (2) across all timesteps** — scoring not varying despite wave height differences
- **Debug WARNING logging in TABLE parser** — should be reverted to DEBUG after validation
- **Grid bbox not configurable via wizard** — API auto-computes from coordinates
- **Brief §3 table discrepancy** — carried from session 2
