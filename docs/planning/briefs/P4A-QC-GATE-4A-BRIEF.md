# QC Gate 4A — verification brief

**Round:** Marine Service Separation, QC Gate 4A. **Date:** 2026-07-25.
**Lead:** coordinator (Opus). **You:** `clearskies-auditor`.

Phase 4A completed and its three audit BLOCKERs were remediated, but **QC Gate 4A's checklist
has never been walked.** The operator deferred it to start Phase 4B. You walk it now.

## Your output is a FILE, not a message

Write your findings to `docs/planning/briefs/P4A-QC-GATE-4A-RESULTS.md` (meta repo) as you go —
not at the end, and not only in your closeout message. On 2026-07-25 an auditor reported via
message only; the findings list lived nowhere on disk, a later session recovered it from an
agent transcript, and nearly closed this same gate against a remembered list. Commit the file to
the meta repo when done.

For every checklist line, record one of:

- **PASS** — with the exact command run and its verbatim output, or the file:line you read.
- **FAIL** — with the same evidence, plus what the correct behaviour would be.
- **CANNOT VERIFY** — with what blocked you. This is a legitimate outcome. Do not upgrade a
  CANNOT VERIFY to a PASS by reasoning about what the code probably does.

**"I read the code and it looks right" is not evidence for a runtime line.** Lines 1, 2, 3, 8, 9,
10, 13 below are runtime claims and need runtime evidence.

## ⚠ Read-only. You write exactly one file, in the meta repo.

Two other agents are **concurrently modifying the API repo working tree** at
`c:\CODE\weather-belchertown\repos\weewx-clearskies-api`. Therefore:

- **Do not modify, create, or delete any file in the API repo or the dashboard repo.**
- **Do not read API repo source from the working tree** — it is changing under you and is no
  longer `eca80ee`. Read it with `git show eca80ee:<path>` from inside the API repo directory,
  e.g. `git show eca80ee:weewx_clearskies_api/enrichment/wave_transform.py`. Use
  `git grep <pattern> eca80ee -- <path>` for greps. This pins you to the state that is actually
  deployed.
- Meta repo docs (`docs/`, `rules/`, `reference/`) are stable — read those normally.
- The only file you write is `docs/planning/briefs/P4A-QC-GATE-4A-RESULTS.md`.
- Dashboard repo at `923dd0c` is not being modified — you may read its working tree.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`, `git show`, `git grep`. **`git checkout` of a commit is also banned** —
it would move the API repo's HEAD out from under two working agents. Use `git show` /
`git grep <commit>` instead, which do not touch the working tree.

If the remote is ahead or behind, STOP and report via SendMessage.

Never edit or commit on a container. SSH to `weewx`, `librewxr`, `weather-dev` is READ-ONLY.

## Environment facts you need

- Deployed state: `librewxr` and `weewx` both at API commit `eca80ee`; dashboard at `923dd0c`.
- SWAN and the SwellTrack/SurfBeat compute service run on **librewxr** (ports 8767 and 8770),
  not on the weewx host. The API is on **weewx** (port 8765).
- librewxr's SWAN working directory is `/var/run/weewx-clearskies/swan/` (tmpfs — run artifacts
  may or may not survive; `forecast_cache.json` was present at 07:29 on 2026-07-25).
- The `claude` SSH user **cannot** `cd` into `/home/ubuntu/repos/` on the containers. Wrap
  container commands as `sudo -u ubuntu bash -c '...'`.
- SSH form: `ssh -F .local/ssh/config <host> "<command>"` from
  `c:\CODE\weather-belchertown`. Hosts: `weewx`, `librewxr`, `weather-dev`.
- Read SWAN history: `ssh -F .local/ssh/config librewxr "sudo journalctl -u weewx-clearskies-swan --since '3 days ago' --no-pager"`. Get the **whole** timeline before concluding anything
  systemic from a single log line — that mistake has been made twice on this project.
- Public dev dashboard: `https://weather-test.shaneburkhardt.com`.
- Never run the full pytest suite.

## Reading list

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — Phase 4A section (`## Phase 4A — Fix
   SwellTrack Pipeline + Vocabulary Unification`, line 732) through `### QC Gate 4A` (line 1637).
   **The QC Gate 4A checklist at lines 1637–1652 is your checklist.** T4A.9, T4A.10, T4A.11,
   T4A.12, T4A.13 carry the Accept criteria behind several of its lines — read them.
2. `docs/planning/briefs/P4A-AUDIT-FINDINGS.md` in full. It records what was already found,
   already cleared ("do not re-litigate"), and already accepted as a gap. **Do not re-report an
   item that file already tracks as accepted or non-blocking** — instead note "already tracked"
   and move on. Line 14 of the gate ("Auditor: zero unresolved findings") is asking whether the
   three BLOCKERs F1/F2/F3 are genuinely closed in the deployed code.
3. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` Amendment 2 (lines 93–237) and
   `docs/decisions/ADR-095-swan-model-corrections.md` Amendments 1 and 2 (lines 83–144).
4. `docs/manuals/API-MANUAL.md` §17 and §18 (surf endpoint contract, wave transform supplements).
5. `rules/coding.md` §1 "Expensive computed data must be persisted to disk" (gate line 13) and
   §4 "Render and LOOK before declaring any UI/mockup change done" (gate line 7).
6. `reference/clearskies-dev.md` — "librewxr (compute host)", "Which host runs which tests",
   "Read SWAN run history on librewxr".

## The checklist — plan lines 1637–1652, with what counts as evidence

Read each line from the plan itself; the notes below say what evidence the lead will accept.

| # | Gate line (abbrev.) | Evidence required |
|---|---|---|
| 1 | Handoff depth varies per forecast hour; grid geometry unchanged across a cycle | Real values from the live system across ≥3 forecast hours showing different handoff depths, plus evidence `compute_domains()` output did not move across a cycle. Runtime evidence, not code reading. |
| 2 | Sampled handoff cell has QB ~ 0 on every transect/hour, **violation drill proven** | Two parts. (a) Live: zero QB violations at HB in a real cycle. (b) The drill: T4A.10 Accept says a forced violation produces the ERROR log and increments the counter. **If no drill was ever run, that is a FAIL or CANNOT VERIFY — say which.** Do not run a drill against production; report the gap. |
| 3 | L3 enables on operator classification as well as structures; viability test logs shortfalls | Source at `eca80ee` for the widened trigger; log evidence for the viability test's INFO line (T4A.5 recorded `1 of 1 cluster(s) enabled` — find it). Whether a *shortfall* has ever actually been logged is a separate question — if it has never fired, say so. |
| 4 | No topographic multiplier in `apply_supplements()` | `git grep` at `eca80ee` for the four multipliers (1.1 / 1.2 / 0.9 / 1.0 point-break/headland/bay-break/straight-beach) in `enrichment/wave_transform.py`. Also confirm the classification field still round-trips through wizard, admin, and apply (T4A.12 Accept), and that supplements 1 and 3 still fire. |
| 5 | Superseded briefs carry dated banners | `SURF-ZONE-MODEL-BRIEF.md` §4, §9 Option 1, §9 Option 3, §2.3.4; `SWAN-NESTING-RESEARCH-BRIEF.md` lines ~190–237. Four locations plus one. Each must have a dated banner naming the superseding ADR, and **no content deleted** (T4A.13). |
| 6 | One vocabulary: `distance`, `depth`, `hs`, `transect` | `git grep` at `eca80ee` across the API repo, plus the dashboard working tree, for `hsEnvelope`, `distanceFromShore`, and `waveHeight` in the beach-profile context. Zero matches except historical docs. Include `endpoints/surf.py`'s own `breakPoints` array and the `units_block` label keys in both endpoints. Note: `distanceFromShore` and `waveHeight` legitimately exist on `MarineForecastPoint` in the SWAN runner — scope the check to the beach-profile/surf response vocabulary, and say explicitly which occurrences you judged in-scope and which out. |
| 7 | Dashboard BeachProfileChart and HeatMapCard render without errors | **Render and look.** Headless screenshot of the relevant page on `https://weather-test.shaneburkhardt.com`, then Read the PNG and describe what you actually saw. "No console errors" is not this check. Per `rules/coding.md`: reading markup is not visual verification. |
| 8 | SwellTrack produces non-zero face heights at HB | Live values. |
| 9 | Surf endpoint: `degraded=false`, face heights from SwellTrack | Live `GET /api/v1/surf/...` response. Confirm `degraded` and that face height is not a SWAN CURVE value (T4A audit check 3: zero `hsig_to_face_height` calls in `surf.py`). |
| 10 | Beach profile endpoint returns full transect data with variable-resolution envelope | Live `GET /api/v1/surf/{id}/profile`. Record the point count and the spacing pattern. The audit's own criterion was >200 points with 1–2 m spacing near shore, wider offshore. Also record what `handoffDepthM` / `handoffSourceLevel` actually return, and whether they are identical across transects — **that is the Phase 4B defect and is expected to be identical today; record it as the pre-4B baseline, not as a new finding.** |
| 11 | Surf scorer uses SwellTrack face height | Source at `eca80ee`: what `score_surf()` receives. |
| 12 | CUDEM downloads at apply time, not runtime | Source at `eca80ee` plus log evidence that a SWAN runtime cycle performed zero CUDEM downloads. |
| 13 | Profiles persist across restarts | Disk evidence: `/etc/weewx-clearskies/spot_profiles/` and `/etc/weewx-clearskies/swan_grid_sizing.json` on the host that reads them. State which host and confirm the files are read on startup rather than only written. |
| 14 | Auditor: zero unresolved findings | Verify F1, F2, F3 from `P4A-AUDIT-FINDINGS.md` are genuinely closed **in the deployed code**, not just in a commit message. Then state whether anything new surfaced. |

## Rules for your findings

- **A claim that code is wrong, dead, or should be deleted requires MORE verification than a
  claim that it is fine.** Open the file before repeating any such claim.
- **Real findings only.** Every finding cites a specific ADR / rule / plan line and identifies a
  specific failure mode, a missed constraint, or forced downstream rework. Generic tradeoffs are
  not findings. An empty findings list is a fine outcome.
- Rank findings BLOCKER / non-blocking, and say for each whether it blocks closing Gate 4A.
- **Do not fix anything.** You audit. The lead decides remediation.
- If a gate line's Accept criterion turns out to be unmeasurable as written, say so — that is a
  finding about the gate, and it is worth more than a manufactured PASS.

## Deliverable

- `docs/planning/briefs/P4A-QC-GATE-4A-RESULTS.md` committed to the meta repo, with all 14 lines
  dispositioned PASS / FAIL / CANNOT VERIFY and evidence inline.
- A closeout SendMessage: the commit hash, a one-line-per-gate-item summary table, the count of
  BLOCKER vs non-blocking findings, and anything you could not verify and why.
