# Session state — MARINE-FORWARD-PLAN execution (2026-08-02)

## ═══ RESUME HERE (written pre-compaction ~02:40 UTC 2026-08-02) ═══

**Role:** Coordinator (Fable). **Mission:** EXECUTE `docs/planning/MARINE-FORWARD-PLAN.md`
(meta repo, the ONLY live marine plan — read it in full first; it has granular tasks, agent
assignments, per-phase adversarial QC gates, MUST-NOT-TOUCH lists, and a PRIME DIRECTIVE
anti-regression section that binds every dispatch).

**Standing operator grants (2026-08-02, in chat — survive compaction, session-scoped):**
1. **Push/deploy as necessary for TESTING purposes** — coordinator discretion; production
   cutover still excluded.
2. **Every implementation task → Sonnet coding agent; adversarial `clearskies-auditor` pass
   BEFORE the lead gate; doc-sync closes every round.** (Permanent process mandate.)
3. **Keep THIS scratch file updated as execution proceeds** (operator ordered scratch-file
   progress guarding against session limits/compaction). Update the Progress log below after
   every gate event; rewrite the RESUME HERE header whenever the "next action" changes.

**MANDATORY reads before FIRST dispatch (operator instruction "read architecture and follow
all rules"):** `docs/ARCHITECTURE.md` (marine section ~:99-127), `rules/agents.md`,
`rules/verification.md`, `rules/coordinator.md`, `rules/clearskies-process.md` (agent-prompt
architectural block section), `reference/clearskies-dev.md`. The plan's PRIME DIRECTIVE
restates the deploy discipline; the rules files are the canonical text.

## Execution order (from the plan)
Phase H → (D2 EARLY — tiny, guards H1's test surface) → Phase D → Phase V as evidence allows →
Phase G6 → Phase C. Each phase's QC gate closes before the next round dispatches. H4 ships
after H1/H2 (operator sequencing) and GATES D4/D5 live verification.

**Recommended opener (told to operator, unchallenged): dispatch D2 (clearskies-test-author)
and H1 (clearskies-api-dev) in parallel** — D2 is one test file; H1 starts with the read-only
H1.1 enumeration + scope-ack. Then H2 → H3 → Gate H (auditor) → H4 → Gate H row 8 → Phase D.

## Dispatch pattern (proven, 2026-08-01 Rounds 1-2)
1. Write task brief to scratchpad (`<task>-brief.md`) citing the PLAN section verbatim +
   mandatory blocks (git local-only/no-push, architectural STOP w/ per-task pre-approvals only,
   stale-test STOP, SSH read-only for agents, numbers-not-adjectives).
2. Agent scope-acks (files + tests + consumers found + what it will NOT touch) → coordinator
   confirms → GO.
3. Closeout → dispatch `clearskies-auditor` adversarially (charter: hunt can't-fail tests,
   allowlist vs git show --stat, falsifiability by mutation) → remediation loop if findings →
   re-audit → LEAD GATE (independent pytest in own shell, stat vs allowlist, code spot-check).
4. Doc-sync agent pass (CLAUDE.md doc-code sync) → coordinator QC → meta commit.
5. Baseline capture → push → deploy (`scripts/deploy-marine.sh`) → reality gate (matched-time
   vs NDBC 46222/Surfline; publish-liveness within one cycle) → gate record in plan + this file.

## Resumable named agents (SendMessage by name; full context in their transcripts)
- `l4-rewrite` — Sonnet clearskies-api-dev, deep marine-repo context (L4 rewrite + break
  rounds). Reuse for marine coding tasks (H1/H2/H4/D1/C2/C3/C4/G6.1).
- `round1-auditor` — adversarial auditor (caught F1 blocker Round 1 + F1 fixture gap Round 2).
  Reuse for all QC gates.
- `doc-sync` — docs agent (3 successful passes). Reuse for H3 + per-round doc-sync.
- Dashboard tasks (D4/D5/G6.3) need a NEW `clearskies-dashboard-dev` Sonnet agent.

## State at compaction (2026-08-02 ~02:40 UTC)
- **Marine repo:** main = `732e87d`, pushed + DEPLOYED (librewxr proc since 00:55:18Z).
  Untracked `test_claim2.py` in marine repo: ignore, never commit/delete.
- **Meta repo:** main = `cb9b402`, pushed. Plans consolidated: restoration/geometry/working-
  model/separation ALL archived to docs/archive/ with banners; MARINE-FORWARD-PLAN.md is live.
- **Model status: WORKS, fully verified.** Round-2 zone math verified LIVE on the 01:51Z
  scheduled cycle (headline≤best_peak all 73 h, e.g. main_zone=[25..30] 6 transects 5
  qualifying face=0.61; API serves populated zone fields 73/73, rep-index in-zone, 0
  violations). Break detection verified (143/143 transects break at physically correct depths;
  3 real double-breaks detected on a small day).
- **Routine cycle watcher:** background task `brbexbaak` (held ssh, fires on next "full SWAN
  cycle complete") — the ~02:05Z routine cycle was mid-L4 at 02:11Z, expect completion
  ~02:45-03:00Z. Pure regression datapoint, nothing gates on it. On fire: grep the new cycle's
  `main_zone=` INFO lines + confirm no ERROR; log here.
- **Known live defect (planned, do NOT hotfix):** dashboard surf 503s = H4 (marine event-loop
  stalls during 206 MB cache publish/reads → API proxy TLS handshake timeout). Evidence chain
  in plan §H4. Operator sequencing: model-first, H4 after H1/H2.

## Key operator rulings this session (already in plan/decision logs; do not re-litigate)
- V4 CLOSED accept-as-is; C4 UNBLOCKED with ruled thresholds (bulk-parameter fallback ONLY —
  L4/L3/L2 routing is NEVER degradation); G5 + C5 + G1R.3 + D3 + D7 PINNED; L3/L4 inseparable
  (L4 ⇒ L3 step-down, SWAN ratios); Phase F is DONE and stays wired; separation plan archived.

## Progress log (update after every gate event)
- 2026-08-02 02:40Z — pre-compaction setup. No forward-plan task dispatched yet. Next action:
  post-compaction → mandatory reads → write D2 + H1 briefs → dispatch.
═══════════════════════════════════════════════════════════════════
