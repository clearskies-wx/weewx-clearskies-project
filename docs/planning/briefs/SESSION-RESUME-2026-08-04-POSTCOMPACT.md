# SESSION RESUME — 2026-08-04 ~02:00Z (written pre-compact at operator request)

**Role:** Coordinator (Fable). **Standing grants (operator, this session):** push/deploy as needed
as coordinator; "proceed with all of this work". **SUPERSEDES SESSION-RESUME-2026-08-03-EVENING.md.**

**OPERATOR'S RESUME INSTRUCTION (verbatim intent):** after compaction, resume with (1) the pending
operator RULINGS, then (2) the EYEBALL SESSION. Present rulings ONE AT A TIME, each with
self-contained plain-English background, one question at the end. A QUESTION IS NEVER A RULING —
record decisions only from explicit answers, read back in the operator's words before logging.
Answer questions plainly, attach nothing. (Binding communication rules from 2026-08-03, unchanged.)

## 1. RULINGS QUEUE (present in this order, one at a time)

1. **F2b — admin omit-when-default trap.** Background: the deployed apply semantics are
   replace-whole-section + preserve-list (decision item 8; documented in API-MANUAL "Surf-field
   apply semantics"). The admin UI only SENDS a field when its value differs from that field's
   default. Combined effect: a field currently holding a non-default value can never be reset
   BACK to its default via admin — the preserve loop sees it absent from the payload and carries
   the old value forward. Question: should the admin ALWAYS send every field it has UI for?
   (One-word ruling expected. Full text at AUDIT-OPUS-WINDOW-2026-08-03.md:585.)
2. **Deletion sign-off #1: `_TRANSECT_BAND_PAD_FRACTION`** (marine swan_runner.py) — provably
   dead: its only uses were inside the D1-deleted function. Coordinator-verified. Never-keep-
   dead-code rule says delete; deletion needs operator sign-off.
3. **Deletion sign-off #2: `check_heading_consistency`** (marine geography.py) — zero production
   callers since G6.2 replaced it with mod-360 `check_facing_consistency`; tests-only.
   Coordinator-verified.
4. **C-E03 per-criterion rulings** — the spacing-dependence inventory is DONE:
   [C-E03-SPACING-DEPENDENCE-INVENTORY-2026-08-03.md](C-E03-SPACING-DEPENDENCE-INVENTORY-2026-08-03.md)
   (17 criteria C1-C17, conversion table at top). Headlines: C1-C6 are five spacing-blind
   "5-transect" counts all inside `_compute_main_break_zone()` (picks the published headline
   height), all drift 2.5× at 25 m spacing, none can see `transect_spacing_m`; C11/C12
   (25%/50% fractions) are scale-free and safe; NO alongshore heatmap smoothing exists anywhere
   (that concern has no code object); `transect_spacing_m` has no upper bound and is
   undocumented. Any re-expression in metres is trigger-1, per-criterion operator approval.
   Suggest walking C1-C6 as one decision (same function, same fix shape), then C7, then the
   validation/bounds gap.
5. **Process note (surface only, NOT a rule per no-rule-accumulation ruling):** D10.2's F3 class
   — my two implementation briefs scoped marine+dashboard but the field crossed an API-proxy hop
   neither could touch (conversion table gap caught at deploy prep). Lesson shape: a cross-repo
   contract round enumerates every hop the field crosses, including proxies. Operator decides if
   it's worth writing down.

## 2. EYEBALL SESSION (after rulings)

Operator drives the browser; coordinator watches the librewxr journal LIVE
(`ssh -F .local/ssh/config librewxr "sudo journalctl -u weewx-clearskies-marine -f"` — sudo
REQUIRED, unit name exact). Items:
- Admin imagery, structure tools, heatmap ortho alignment, prjc1→PRJC1 rename via admin.
- The config save doubles as: **Gate G6 accept line 5** (full-nest run vs baseline after a config
  push) AND **preserve-list live proof** (api.conf surf fields unchanged after the save —
  compare `/etc/weewx-clearskies/api.conf` surf sub-block before/after).
- NEW since last plan: check the surf card's two restored readouts — "In pier shadow: X ft"
  secondary line and "AT BREAK" per-partition rows (both live with real data), plus the About
  page's imagery-provider credit (Data Providers card).

## 3. DEPLOYED STATE (all hosts current, all repos pushed)

| Host | Repo @ commit | Content |
|---|---|---|
| weewx (api) | `c1a8212` | D10.2 F3: shadowFaceHeight in conversion table + first convert_marine_payload tests |
| librewxr (marine) | `5cd7fbb` @ 2026-08-04 01:50:13Z | D10.2 (shadowFaceHeight/perPartitionBreaks emission) + WIND STEP-1 STACK (gatherer+store dormant, F1/F2/F4/AttributeError all audit-CLOSED) |
| weather-dev (dashboard) | `63733b1` | D10.2 renders (shadow line, AT BREAK rows, aud F1 no-fallback) + About-page imagery credit |
| weather-dev (stack) | `c7f7593` | (unchanged this window) wizard round-trip fixes |
| superproject | `970dd0e` pushed | all ledgers/plans/briefs/manuals current |

**CLOSED THIS WINDOW (2026-08-03 23:19Z → 2026-08-04 02:00Z):** marine-deploy gate battery 5/5
(inv-4 = 0/cycle with trigger scenario present; NDBC −18%; trace 27 GB→5.1 GB); D10.2 end-to-end
(3 repos, 3 audit findings F1/F2/F3 all remediated+re-verified, final live gate: shadow 73/73
non-null ft, sane vs bestPeak); about-attr; 3 docs rounds (V3-F1 doc conflicts, preserve-list
semantics, D10.2 field rows + stale partitionBreakInfo bullet); C-E03 inventory; wind step-1
(built, audited — auditor found F1 HIGH restart-persistence + F2 MEDIUM pacing; implementer found
F4 cross-track mark_held which lead upgraded to deploy blocker, 4×/day systematic; all fixed with
falsifiability, re-verified, deployed).

## 4. COORDINATOR QUEUE (no operator input needed)

1. **⏳ WIND STEP-1 OBSERVATION GATE** (pre-stated, AUDIT-OPUS-WINDOW §wind ledger row): observe
   ≥2 extended cycles via `/health`'s `windGatherer` key — 06z assembles ~07:00-07:30Z, 12z
   ~13:00-13:30Z. Each: `tracks.hrrr_extended.inProgress.heldHours` climbs → 49 →
   `lastCompleted` stamped + `extended_cycle_assembled` in journal. Also: store files present
   and bounded (`/var/run/weewx-clearskies/swan/wind_timeline.json` + `incoming.json`); NO
   QuotaExhausted-as-ERROR (self-collision WARNINGs acceptable/rare). At 01:50Z the gatherer
   already assembled hrrr_hourly 19/19 in 30 s and fired the first hourly_cycle_assembled.
2. **Wind §5 step 2** (display wind switches to store) — HOLD until step-1 gate passes. Step-3
   brief must SURFACE the GFS-interpolation placement question (trigger 5: store vs
   swan_runner._stitch_wind) to the operator — deliberately deferred, do not assume.
3. Tracked curiosities → next marine investigation round: parameterless direct `GET /surf/{id}`
   served 6-day-stale payload while API path fresh; API /surf latency variance (0.9 s vs 14.9 s);
   marine 401 "Invalid token" on the secrets.env SURF_COMPUTE_SECRET probe post-restart (two
   secrets files — probe-only, API path unaffected).
4. Test-hardening batch (tracked): NOAA-call stubs for facing tests; marine-apply coverage; C8
   7/9 no-op paths; aud-tip KAT-6 non-monotonic fixture; broader convert_marine_payload
   coverage; benign F4-flush residual (F4-only tick's held-marks flush next changed tick).

## 5. PROCESS FACTS (save re-derivation)

- Deploy scripts FROM SUPERPROJECT ROOT (Bash): `bash scripts/deploy-api.sh` /
  `deploy-marine.sh` / `redeploy-weather-dev.sh`.
- Marine port 8780 serves TLS (`curl -sk https://…`); journal unit `weewx-clearskies-marine`,
  sudo required; API on weewx serves TLS on 8765 too (`curl -sk https://127.0.0.1:8765/...`).
- Post-restart marine /health shows transient `failed` (inputs registry empty until the startup
  cycle fetches) — expected, clears within minutes; deploy-overlap can 503 the API surf route
  briefly (cold proxy cache + marine busy) — self-heals.
- Round discipline that caught real defects this window (keep): scope-acks caught my wrong cites
  3× (openapi:1489=trace dict; providers/wind/ path; serializer import cycle); adversarial
  audits found 5 real findings (aud-d102 F1/F2 + aud-wind1 F1/F2 + my F3 at deploy prep);
  implementer self-reported F4 under the fired-guards closeout requirement. Falsifiability
  transcripts mandatory; auditors re-verify remediations with their own probes.
- PowerShell here-strings mangle quotes passed to git commit — use Bash heredoc for multi-line
  commit messages.
- Fresh named auditor per batch; audits never see implementer closeouts; one implementation
  agent per repo seat.
