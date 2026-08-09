# GATE S AUDIT BRIEF — WLEVEL HALF (blind, adversarial) — L1-BOUNDARY-REBUILD-PLAN

**Round identity:** QC Gate S, wlevel half only (currents rows run after S1 lands). Lead:
coordinator (session 6). You: `clearskies-auditor` (Sonnet). Date: 2026-08-09.

**Your posture is ADVERSARIAL.** The claim under audit: *the S2 STOFS water-level provider and
WLEVEL chain work as designed and are deployed live.* Your job is to DISPROVE it. You pass the
gate only by reporting you could not disprove it AND naming what you ruled out. Look
specifically for: values right by accident, right for one timestep only, right in cache but
never recomputed, right because a fallback fired silently.

**BLINDNESS RULE (hard):** you get the DESIGN and the EXPECTED NUMBERS below — nothing else.
Do NOT read: any dev/test agent closeout, any commit message on the marine repo
(`git log` for HEAD verification is allowed; `git show`/commit bodies are not), any session
scratch/handoff file, the plan's decision log. You audit the system, not the implementer's
evidence. Exception (plan Gate S row): you RUN the named KATs for the falsifiability drills —
running them is allowed; reading their authors' reports is not.

## READING LIST (design + expected numbers ONLY)
1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — §S2 design block, §S3 design
   block, §Gate S rows, PRIME DIRECTIVE 8 (no silent fallbacks).
2. `docs/manuals/PROVIDER-MANUAL.md` §14.13a (STOFS wlevel provider + chain — the doc whose
   sync you verify).
3. `docs/ARCHITECTURE.md` — "L1-BOUNDARY-REBUILD-PLAN target state" block, SWAN input chain
   bullet (water-level chain prose).
4. Code (read as the system, not as work product): marine repo
   `weewx_clearskies_marine/providers/ocean/stofs_wlevel.py`,
   `providers/nearshore/swan.py` (tide-fetch site), `services/swan_runner.py`
   (`_write_wlevel_grid_txt`), `services/vertical_datum.py` (S3 Hawaii branch),
   `providers/tides/coops.py` (`fetch_datums`).

## SYSTEM FACTS (verified by lead, session 6)
- Marine repo local checkout: `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`,
  HEAD `462b38f`, clean — verify both before starting; drift → STOP and report.
- Deployed: same commit live on librewxr since 2026-08-09 22:04 UTC (service
  `weewx-clearskies-marine`, port 8780, TLS, journal needs sudo).
- Local test venv (Windows): `.venv-round4\Scripts\python.exe` in the marine repo root.
  Mutation drills run LOCALLY (temporary local edit → run KAT → `git checkout --` revert;
  NEVER commit a mutation, NEVER edit anything on librewxr).
- SSH (read-only): `ssh -F .local/ssh/config librewxr "<cmd>"` from the meta repo root.

## EXPECTED NUMBERS (the claim you try to break)
- Cutover bias gate: |mean bias| ≤ 0.15 m; the lead's pre-cutover measurement was
  **−0.044 m over 25 pairs** vs CO-OPS station 9410660 predictions. You RECOMPUTE this
  independently from raw fetches (STOFS-2D-Global `conus.west` grib2 values at the station
  cell vs CO-OPS predictions API, ≥24 h of matched hours). Your number should land near
  −0.04 m; > 0.15 m absolute = gate FAIL; a sign flip or a drift ≥ 2× the lead's number is a
  finding even inside tolerance.
- WLEVEL.txt spatially-varying on all four grids (`/var/lib/weewx-clearskies/swan/level*/`),
  67 timesteps each; line counts 6767 / 5561 / 3149 / 11390 (L1/L2/L3_0/L4_0). Spot-verify
  values VARY across the grid within one timestep (a spatially-uniform block = the claim is
  false — that is the old CO-OPS stamp wearing STOFS clothes).
- Journal INFO line per cycle: `spatially-varying WLEVEL primary (P8 chain)`.

## GATE ROWS (wlevel half — each row needs a pasted raw command + output)
1. **Bias-gate recompute** — as above, your own pipeline, raw fetches, command + numbers pasted.
2. **No-silent-fallback grep** — grep the wlevel chain end to end for zero-fill /
   fabricated-default patterns (`np.zeros` fills, `or 0.0`, silent `except: return`) and for
   the deleted "~30 km uniform tide" justification comment (must be GONE). Any silent
   substitution path = FAIL.
3. **Mutation drill (cut STOFS URL)** — locally, break the STOFS URL template (one character),
   run the chain-fallback KAT(s) (`tests/test_swan_wlevel_chain_fallback.py`,
   `tests/test_stofs_wlevel_provider.py`): the chain must fall back to CO-OPS-uniform with a
   LOUD selection log line (assert the log text exists), never silently. Then revert and rerun
   green. Paste both transcripts.
4. **Hawaii NAVD88 refusal** — mutate/arrange the S3 datum-branch KAT input so a
   geodetic-referenced (NAVD88) source appears in a VDatum-less tidal region: the code must
   raise `DatumConversionError` (refuse), never approximate. Prove the KAT is falsifiable
   (mutate the code check → KAT fails → revert).
5. **Doc-sync** — PROVIDER-MANUAL §14.13a and the ARCHITECTURE.md input-chain bullet describe
   the code as it IS (chain order, refusal slug `tide_fetch_failed`, cutover gate, datum
   handling). Drift = finding.
6. **Baselines** — run exactly this selection (the recorded `462b38f` baseline selection —
   do not add or drop files):
   `tests/test_island_autosizing.py tests/services/ tests/test_coops_fetch_datums.py tests/test_stofs_wlevel_provider.py tests/test_swan_wlevel_chain_fallback.py`
   with the local venv. Expected: **249 pass / 3 fail**, the 3 being tracked pre-existing
   (`test_double_break_transect55_kat` wave_reforms, `test_wind_gatherer` cold-start
   reconcile, `test_wind_timeline_store` round-trip). Any OTHER failure = finding. Do not
   list a file AND its parent directory (double-collection inflates counts).

## PROHIBITIONS
- Git: read-only (`status`/`log --oneline`/`diff` for your own mutation reverts). No
  add/commit/push/pull/fetch/merge/rebase. Mutations are reverted with `git checkout -- <file>`
  before closeout; closeout states the working tree is clean.
- No edits on librewxr, no service restarts, no config pushes, no full pytest suite, no
  downloading SWAN documentation (local manual at `docs/reference/`).
- Architectural findings (the 7-trigger list in `rules/agents.md`) are REPORTED, never fixed.
- Findings must be real: each cites the specific rule/plan row and a specific failure mode.
  Generic tradeoffs are not findings. An empty audit is a legitimate outcome.

## CLOSEOUT (via SendMessage to "main")
Verdict per gate row (PASS with pasted evidence / FAIL with finding), the list of what you
ruled out, every command you ran with raw output for the numbers rows, working-tree-clean
confirmation.
