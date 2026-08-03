# SESSION RESUME — 2026-08-03 evening (written pre-compact at operator request)

**Role:** Coordinator (Fable 5). **Session grants (operator, this session, still standing):**
push/deploy as needed as coordinator; "proceed with all of this work". Operator communication
style rulings THIS session — BINDING, the session's hardest-won lessons:

1. **ONE ITEM AT A TIME.** Never present multiple decisions in one message ("your interface
   sucks and things get lost"). Each item: self-contained background, plain English, one
   question at the end.
2. **A QUESTION IS NEVER A RULING.** Record a decision ONLY when the operator answers a direct
   question with an explicit choice; read back the decision in their words before logging it.
   This was violated twice (H5 "So C" context-collapse; an "ok" that prefaced a follow-up
   question) — both had to be struck. Never again.
3. **Answer questions plainly, attach nothing.** Don't use an answer as a springboard to push
   for approval.
4. **Read-only investigations need NO authorization** (rules/coordinator.md §4b, added today).
5. **NEVER KEEP DEAD CODE** (rules/coding.md §3, added today) — deletion still goes through the
   operator sign-off gate.
6. Don't add rules beyond ones with real teeth ("you start ignoring rules when you have too
   many").

## Where everything stands

**ALL 14 decision items RULED** — full record with operator wording in
[AUDIT-OPUS-WINDOW-2026-08-03.md](AUDIT-OPUS-WINDOW-2026-08-03.md) (items 1-14 + remediation
ledger). Highest-impact rulings: wind-provider decoupling+assembly architecture (item 9,
dissolves item 1); trace stays ON size-capped (item 4); inv-4 clamped gate (10); attribution
always-on + About page (11); lessons trimmed hard (12); D10.2 three rulings (13); G6.2 mod-360
(14); smart-L3 KEEP w/ size-gate + resolution-recheck conditions at first structureless spot
(7, evidence: SMART-L3-INVESTIGATION + L3-RESOLUTION-RESEARCH briefs); wizard clobber = keep
replace-whole-section + extend preserve-list, R5 merge REJECTED on operator's own history (8);
C-E03 reframed spacing-dependence-investigation-first (3).

**DEPLOYED + AUDIT-CLEAN (all adversarially audited, findings remediated + re-verified):**
| Host | Commit | Content |
|---|---|---|
| weewx (api) | `2f84bbf` | surf preserve-list (6 config-file-owned fields) + aud-r1 F1 byte-identity fix |
| weather-dev (stack) | `c7f7593` | wizard round-trip: pre-fill fallback + structures-500 fix + coordinates render + swan_step_completed gate + KATs. **Wizard is SAFE again** |
| librewxr (marine) | `f38a8f3` @ 2026-08-03 23:19:19 UTC | 6 commits: D1 deletion, trace cap (3 files/10 GB, reserved today-slot), inv4 clamped gate, G6.2 mod-360, L3 truth-fixes (40 m logs, /health stale reason relocated), aud-marine F1/F2 fix |

**Immediate post-deploy gates PASSED:** marine journal sweep 0 errors; librewxr
`pytest tests/test_facing_divergence_check.py` = 10/10 incl. flipped flip-KAT (lead's owed
G6.2 full-chain check CLOSED); weather-dev config service active, wizard 303-not-500, 0 errors;
weewx health 200, api.conf hash unchanged.

**⏳ CYCLE-DEPENDENT GATES OUTSTANDING** — run at/after the next full marine cycle (next 00z
extended HRRR assembles ≈01:00-01:40Z): commands + expected values pre-stated in
AUDIT-OPUS-WINDOW-2026-08-03.md §"MARINE BATCH DEPLOY": (1) inv-4 journal count 0 (baseline
~67/cycle); (2) "SWAN L3[0]: …at 40 m" log; (3) /health WITHOUT l3_viability_failed while
level3_0 runs; (4) NDBC 46222 reality gate ±30%; (5) trace dir self-prunes 27 GB → ≤3
files/≤10 GB at first emit; (6) preserve-list live proof rides operator's first admin save.

**WIND ARCHITECTURE ✅ FULLY APPROVED** (operator: "yes fully approved") —
[WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03.md](WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03.md):
in-process gatherer, ONE assembled 72 h timeline updated in place (NO fragment retention —
operator Q2), run triggers on assembled-complete, 12 h fast cycle, admin readout PINNED.
Build per §5 migration (gatherer dormant → display wind → full run → fast cycle → deletions),
each step deployed + reality-gated separately. NOT yet dispatched.

## Operator queue (pinned)
1. **Eyeball session**: admin imagery, structure tools, heatmap ortho alignment, prjc1→PRJC1
   — coordinator watches librewxr journal LIVE during the config save (doubles as Gate G6
   accept line 5 full-nest check + preserve-list live proof). Both surfaces safe.
2. **F2b one-word ruling**: should admin ALWAYS send fields it has UI for (fixes
   "can't-set-back-to-default" trap created by omit-when-default + preserve)?
3. **Deletion sign-offs ×2** (both provably dead, coordinator-verified):
   `_TRANSECT_BAND_PAD_FRACTION` (swan_runner.py, only uses were inside deleted D1 function)
   and `check_heading_consistency` (geography.py, zero production callers post-G6.2; tests-only).

## Coordinator queue (no operator input needed)
1. Cycle-dependent gate battery (above) — FIRST thing next window.
2. D10.2 round: marine emits `perPartitionBreaks` shape on SurfForecast + `shadowFaceHeight`
   secondary readout; dashboard re-points `partitionBreakInfo` type (ruled item 13; D10 doc
   fixes ride along: openapi:3664, openapi:3295, origin attribution).
3. About-page imagery attribution (dashboard, ruled item 11).
4. Meta doc-batch: ARCHITECTURE.md:119 (10 m → 40 m), swan-nesting-reference.md:47
   (mis-attributed "§3.5 2-3x" claim), wind-hole doc conflicts (PROVIDER-MANUAL:1841/:1845/
   :1893/:1816-1819, DASHBOARD-MANUAL:1194, API-MANUAL:1825/:3005), plan-row syncs.
   Doc-code sync for the deployed rounds' manuals (CONFIG/OPERATIONS wizard behavior notes).
5. C-E03 spacing-dependence investigation (read-only; ruled item 3 scope: inventory
   transect-count vs metres criteria — 5-consecutive window surf_1d_pipeline.py:1203,
   qualifying thresholds, invariant %, heatmap smoothing → conversion table for operator).
6. Wind-architecture build rounds (approved, sequence §5).
7. Test-hardening batch candidates (tracked): facing tests make live NOAA calls (stub
   boundary-station selection); marine-apply path had ZERO test coverage pre-preserve-round;
   C8 7/9 no-op paths untested; aud-tip KAT-6 non-monotonic fixture.
8. Trailer/authorship note: subagent commits may carry copied trailers — transcripts are the
   only model-identity evidence.

## Process facts (save re-derivation)
- Deploy scripts run FROM SUPERPROJECT ROOT: `bash scripts/deploy-api.sh` /
  `redeploy-weather-dev.sh` / `deploy-marine.sh` (cd to c:\CODE\weather-belchertown first).
- librewxr tests: `ssh -F .local/ssh/config librewxr "sudo -u ubuntu bash -lc 'cd
  ~/repos/weewx-clearskies-marine && .venv/bin/python -m pytest <file> -q'"` (venv works).
- journalctl on librewxr NEEDS sudo (empty stream otherwise — recorded in
  reference/clearskies-dev.md).
- Dispatch discipline that caught real errors today (keep): scope-ack before GO caught wrong
  module cites twice and an unscoped pinned-shape test; auditors briefed to DISPROVE with
  named targets caught 3 real findings (byte-identity break, retention off-by-one, false
  commit-message claim). Falsifiability transcripts mandatory in every closeout.
- Rules edits landed today: coordinator.md §4b (investigations need no authorization),
  coding.md §3 (never keep dead code; per-unit exception isolation; WARNING+ for silent skips;
  no hardcoded values in log strings), verification.md (KAT-fails-pre-change sentence;
  invariant-enumeration sentence in deploy gate), agents.md untouched,
  clearskies-dashboard-dev.md scope line (owns ALL UI surfaces incl. stack).
- MARINE-FORWARD-PLAN.md updated throughout (C3 amended 24h→12h + fast-cycle-unreachable
  finding; V3-F1 ruled; H5 dissolved; D1 approved; D10.2 ruled; smart-L3 ruling in PINNED
  section; TA-C21 closed; LM-3 toggle dropped + About task).
