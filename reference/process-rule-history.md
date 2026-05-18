# Process Rule History — Incident Narratives

This file contains the detailed incident narratives that motivated each rule in
`rules/clearskies-process.md`. It exists for human reference — the lead agent
does NOT load this file during normal operation. Load only when investigating
a past incident or when the user asks "why does rule X exist?"

Rules are listed by the short name used in the rules file.

---

## Write decisions to disk immediately
**2026-05-01:** Context windows fill. Sessions get interrupted. Claude over-estimates retention. The file system is the only reliable record. User verbatim: "you tend to start dropping details as your context window fills and we may lose things if this session is interrupted."

## Corrections edit in place
**2026-05-02:** User direction: "I don't need a bunch of superseded ADRs laying around. That is ridiculous."

## Read the ADR before the plan
**2026-05-04:** Phase 1 spike built against the plan body's stale tech-stack table (Tremor + ECharts) when ADR-002 had already locked shadcn + Recharts. The spike validated the wrong stack and almost generated a Proposed ADR-002 amendment undoing an already-locked decision. Audit: docs/reference/PLAN-VS-ADR-AUDIT-2026-05-04.md.

## Recover lost state immediately
User verbatim: "the point of a computer is the fact that you can keep track of things that humans are not good at. if you fucking drop details and forget things, then you are no fucking better than a human and i have no fucking use for you."

## Concise ADRs
**2026-05-02:** User verbatim: "it will just bloat your context window, you will then ignore most of it, and I as a human cannot bare to read that drool."

## Don't dismiss user-named options
**2026-05-02:** Claude dropped Weather Underground from a comparison without research. User called it out.

## Scope the API to the dashboard
**2026-05-05:** Claude proposed server-side parsing of NOAA report text for hypothetical HA/mobile consumers. User: "This API is written by us for us. I do not think it is a good idea to bloat the API."

## Research external systems before asking
**2026-05-05:** Claude asked shape questions without reading weewx docs. User: "HAVE YOU EVEN READ THE WEEWX DOCUMENTATION TO FIGURE OUT WHAT IT ALREADY PROVIDES?" Same session: Claude proposed an EarthquakeRecord shape without reading earthquake provider docs.

## Audit means real findings
**2026-05-02:** Claude produced four empty audit findings. User: "YOU ARE NOT FUCKING AUDITING, YOU ARE JUST BEING CONTRARIAN."

## Plain English
**2026-05-05:** Claude produced "paragraph upon paragraph of utter techno-babble." User: "using the english language is not your strong suit is it. None of this means shit to me."
**2026-05-06:** Wall of technical terms without definitions. User: "you have been bombarding me with so much jargon, I cannot see straight."

## Real schemas in unit tests
**2026-05-06:** Phase 2 task 2 write-probe unit test used one-column synthetic archive table. Real production schema has multi-column NOT NULL constraints. Writable user gets IntegrityError (not OperationalError) against real schema — probe's broad catch swallowed it, passing a writable user. Only the integration test against production schema surfaced the defect.

## Two audit modes required
**2026-05-06:** Task 1 pytest caught 3 runtime bugs the auditor missed. Task 2 integration tests caught 2 runtime defects unit tests missed; auditor caught 5 source-side findings runtime tests had no visibility into. Neither mode found what the other found.

## Lead synthesizes auditor findings
**2026-05-06:** Task 2 round 3 auditor finding F4 admitted two remediations. Lead picked the simpler one matching ADR-012's spirit. Forwarding raw would have landed the dev on the complex option by default.

## Independent lead-pytest-verify
**2026-05-11:** 3b-12 close — api-dev claimed "1762 passed, 0 failed"; lead's independent run returned 103 failed / 1754 passed / 286 skipped. Lead initially trusted the count and almost closed the round on a false-clean narrative.

## Poll background teammates / Agent idle bug
**2026-05-07:** Phase 2 task 3a-2 had three consecutive agents hit the idle bug — api-dev round 1 (~30 min gap), test-author (~48 min gap), api-dev round 2 (overnight gap). Several hours wasted. ScheduleWakeup sentinel doesn't reliably fire outside /loop — verified 2026-05-07 when lead scheduled 240s wake and it never fired. User: "Why did 18:47 roll by and you did nothing?" Filed anthropics/claude-code #56930.

## Live scratchpad
**2026-05-07:** Session-limit hit mid-round with two background teammates active. Lead's retrospective handoff lost everything held only in context. User: "Why are we losing information? Why are you not dumping to a scratchpad to pick up later?"

## Lead-direct for small fixes
**2026-05-07:** 3b round 2 had four findings all under ~30 lines. Lead fixed directly in one commit. 3b round 3 had six findings; lead fixed all lead-direct (~250 lines across 5 files, would have been a full respawn otherwise).

## Cross-check canonical mapping cells
**2026-05-09:** 3b-7 (alerts/aeris) drafted against canonical §4.3 verbatim. Real Aeris fixture showed priority=96 (not 1-5 scale). Three further mismatches surfaced in same fixture. All were visible in api-docs at brief-draft time.

## Api-docs provenance
**2026-05-11:** 3b-14 close — 3 of 5 WMS-T api-docs files were from web research, not live captures. Layer names were guesses/stale references. test-author detected divergence during fixture capture. ~50 lines of fixes across 12 files.

## Brief-draft codebase verification
**2026-05-10:** 3b-10 brief cited credentials at `settings.aeris.client_id` (wrong — actual path is `settings.forecast.aeris_client_id`). Brief anti-pattern told dev NOT to extend datetime_utils.py — but a helper already existed there. Both forced mid-flight workarounds.

## Dimensional sanity checks
**2026-05-11:** 3b-11 surfaced off-by-1000 chemistry bug in ugm3_to_ppm() dating from 3b-9. Bug encoded in 6 places. 30-second mental check at brief-draft would have caught it.

## PowerShell multi-line commits
**2026-05-08:** Parentheses and quotes in heredoc commit message broke PowerShell parser. Git emitted ~30 pathspec errors.

## Sonnet auditor validated
**2026-05-18:** 3b-15 close used Sonnet auditor at 75K tokens (vs typical Opus auditor 200K+). 0 blocking findings, 1 parking-lot note. Clean results at fraction of cost.

## Agent management token burn
**2026-05-18:** User flagged agent management as dominant token-burn source. Key problems: Opus doing delegated work, large agent context loads, no mid-task monitoring, bloated briefs/rules. This round validated: Sonnet agents for all delegated work, focused prompts, smaller tasks.
