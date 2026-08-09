# AUDIT BRIEF — Gate DOC (adversarial), L1-BOUNDARY-REBUILD-PLAN Phase DOC

**Round identity:** Gate DOC, L1-BOUNDARY-REBUILD-PLAN-2026-08-08. Lead: coordinator.
You: clearskies-auditor (Sonnet), adversarial. You review ONLY the git diff and the source
documents — you have NOT been shown the implementer's report, commit message rationale, or
notes, and you must not seek them out. Report findings via SendMessage to "main".

**Claim under audit:** the meta repo's newest commit (subject beginning
`docs(L1-plan): Phase DOC`) correctly updates every governing document to the ruled target
state of the plan, sourced ONLY from the plan and the brief, with target-state tags on all
not-yet-deployed behavior. **Your job is to DISPROVE this.** Look for: invented detail
present in neither source; a live-behavior claim silently rewritten as if already changed;
an untagged target-state statement; a ruling dropped or paraphrased into a different
meaning; a constant that differs from the plan's named-constants block.

## Sources of truth (read first)
1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — Pre-approval register P1–P15,
   named constants block, SWAN SYNTAX PRESCRIPTIONS, Phase designs, DOC.1–DOC.4 + Gate DOC.
2. `docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` — §8 rulings
   D1–D13 (and §5/§6/D7 matrix).
3. The diff: `git -C c:\CODE\weather-belchertown show <commit>` (find it via
   `git log --oneline -5`).

## Gate rows (each row needs your OWN command/evidence pasted; a row with no evidence FAILS)
1. **Traceability spot-map:** pick 10 random substantive claims across the changed docs
   (use a deterministic method you state, e.g. every Nth added line with content) and map
   each back to a specific brief ruling or plan design line. ANY orphan (no source) = FAIL,
   cite it.
2. **Tag completeness:** grep the diff for added statements describing behavior not yet
   deployed; each must carry `(ruled 2026-08-08; lands with Phase <X> of
   L1-BOUNDARY-REBUILD-PLAN)` (or sit under a tagged heading). List any untagged.
3. **No false live claims:** verify no existing statement about CURRENT deployed behavior
   was changed to claim unshipped behavior is live (the station-boundary path, the ±1.0°
   wind bbox, the CO-OPS uniform tide, the shelf-derived horizon are ALL still live today).
4. **ADR completeness:** diff the new ADR's decision list against brief §8 — all of D1–D13
   present, constants verbatim (cap 100.0 km, margin 10.0, σθ_ref 15°, k=1, s=28/s=7,
   σf 0.015 Hz, γ 3.3, spacing = L1 dx, pad 0.3°, STOFS gate ≤ 0.15 m; r and RTOFS
   endpoint stated as measured-then-pinned with bounds, not values). The D11
   missing-data-vs-constrained-geometry distinction must appear.
5. **INDEX.md consistency:** new row matches the ADR file's number/title/status/date; no
   other rows disturbed.
6. **Docs-only round:** `git show <commit> --stat` — zero changes outside docs/ (no code,
   no rules/, no reference/, nothing in repos/).
7. **Numbering:** the new ADR is ADR-104 (ADR-101/102/103 already exist and are untouched
   except ADR-103's amendment note).

Empty findings are acceptable ONLY with the evidence of what you ruled out, per row.
Real findings only: each must cite the file/line and the source it contradicts or lacks.

**Read-only:** you change nothing. No git write operations. No code. Findings via
SendMessage to "main", ranked by severity.
