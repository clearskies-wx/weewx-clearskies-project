# Round brief — Marine Service Separation Plan, Phase 4A tasks T4A.1 (API side) + T4A.4

**Round:** MARINE-SEP-P4A-A2 (surf + beach-profile endpoint truthfulness)
**Date:** 2026-07-24
**Lead (coordinator):** Opus
**Implementation agent:** `clearskies-api-dev` (Sonnet)
**Auditor:** `clearskies-auditor` (Sonnet) — adversarial audit, mandatory, no deferral

---

## 1. Round identity and mandate

You are implementing two tasks of `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`:

- **T4A.1, Do step 1 only** — the API half of the beach-profile vocabulary
  unification. A `clearskies-dashboard-dev` agent implements steps 2-6 in the
  dashboard repo, in parallel, against the same fixed vocabulary decision.
- **T4A.4 in full** — remove the SWAN CURVE face-height fallback from the surf
  endpoint.

T4A.4 is the task that stops the surf endpoint from lying. Today it returns
confident-looking face heights computed by a single-point formula whenever the
1D model produces nothing, with only an unconsumed `degraded: true` to signal it.

**NO DEFERRAL RULE applies.** Read §"NO DEFERRAL RULE" at the top of the plan.
No TODOs, no stubs, no partial renames, no "follow-up".

---

## 2. Reading list — read these BEFORE writing any code

Read the original text. This brief deliberately does not restate their content.

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`:
   - §0.3 (git restrictions), §0.4 (scratch discipline)
   - §"Phase 4A" Purpose and the 7-item Origin list — items 4, 6 and 7 are your
     two tasks' reasons for existing.
   - **§T4A.1** — the Problem paragraph, the 4-column vocabulary table, the
     Decision paragraph, **Do step 1** (yours) and the Accept bullets. Read steps
     2-6 too so you know exactly what the dashboard agent is coding against.
   - **§T4A.4 in full** — the Problem paragraphs, the Deployment constraint, all
     7 Do steps, all Accept bullets.
   - §T4A.5 — the deployment constraint in T4A.4 references it.
   - §"Adversarial Audit — Phase 4A" items 1, 3, 4, 5 and §"QC Gate 4A".
2. `docs/manuals/API-MANUAL.md` — §17 (SwellTrack) and §18 (marine/surf endpoint
   contracts). Your response-shape changes must be reflected there; see §4.2.
3. `docs/manuals/PROVIDER-MANUAL.md` — §14 (marine providers, surf spot config).
4. `rules/coding.md` — §1 (especially "Weather data is safety-critical", "Treat
   your own output as untrusted", "Catch specific exceptions"), §2, §3
   (single responsibility, DRY — search before writing a helper), §4,
   §6.2 (**API i18n** — any human-readable text you add must resolve through the
   locale file; `modelStatus` values are code identifiers and are exempt per §6.6,
   but any label derived from them is not).
5. `rules/clearskies-process.md` — "Research-to-implementation discipline",
   especially *"'Data is flowing' is not verification — check physical
   plausibility"* and *"Agents do not make design decisions — they implement
   prescribed solutions"*. Also "Wizard ↔ API apply contract sync" if you touch
   any Pydantic response/request model.
6. Source files you are modifying — read each in full before editing:
   - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/beach_profile.py`
   - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
   - `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py`
     (`score_surf()` — T4A.4 Do step 3 changes its input)
   - `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/breaker_height.py`
     (`hsig_to_face_height()`, `hawaiian_height()` — Do steps 1 and 4)
7. Read-only context:
   - `repos/weewx-clearskies-api/weewx_clearskies_api/services/surf_1d_pipeline.py`
     — what `best_peak_face_height_m`, `spot_average_face_height_m` and `degraded`
     actually mean on the pipeline result.
   - `repos/weewx-clearskies-dashboard/src/api/types.ts` — the surf forecast and
     beach-profile types the dashboard agent is changing in parallel.
8. Existing tests: `repos/weewx-clearskies-api/tests/test_surf_endpoint.py`,
   `tests/test_surf_scorer.py`.

---

## 3. Pre-round verification (performed by the lead, 2026-07-24)

Facts I verified directly. Confirm them yourself before relying on them.

- API repo HEAD was `0d87b28` at round start; another agent (T4A.2/T4A.2b, files
  `enrichment/bathymetry.py` + `services/surf_1d_analytical.py` +
  `pyproject.toml` + 2 test files) is committing in the same repo **in parallel
  with you**. Its files and yours are disjoint. See lead call **LC-14** on
  staging discipline — this is not optional.
- Pre-existing dirty files, unrelated, carried since Phase 1: `providers/alerts/nws.py`
  (one-line comment) and untracked `services/surfbeat_strip_benchmark.py`.
  **Do not touch, do not stage, do not commit.**
- **Test baseline at `0d87b28`**, run on weewx:
  `pytest tests/test_bathymetry.py tests/test_surf_endpoint.py
  tests/test_surf_scorer.py tests/test_marine_endpoint.py --tb=no -q`
  → **3 failed, 95 passed**. Pre-existing failures you inherit and must not grow:
  `test_bathymetry.py::test_download_profile_mock`,
  `test_bathymetry.py::test_download_profile_mock_triggers_refinement`,
  `test_surf_scorer.py::test_perfect_conditions`.
  Note the third one is in **your** file — do not "fix" it by weakening the test;
  triage it and report whether your change makes it pass, still fail, or fail
  differently.
- **`beach_profile.py` current output**, from `_build_transect_profile()`
  (~line 298) which serves **both** the single-transect and the
  `transect_index=all` branch: array key `"transect"` (line ~544); point keys
  `"distanceFromShore"`, `"depth"`, `"waveHeight"` (lines ~391-393); break-point
  keys `"distanceFromShore"`, `"depth"`, `"waveHeight"` (lines ~426-428, 443-445)
  plus a sort on `b["distanceFromShore"]` at line ~453. Wave shapes and jacking
  factors at lines ~503 and ~516 **already** use `"distance"`. So the file is
  currently internally inconsistent — that is what T4A.1 fixes.
- **`surf.py` current fallback**, verified: Phase 1 computes
  `_breaker_height.hsig_to_face_height(...)` → `face_height_m` at line ~916 and
  `hawaiian_height(face_height_m)` at ~925; `score_surf(wave_height=face_height_m, …)`
  at ~1050; `entry["breakingFaceHeight"]` / `["breakingHawaiianHeight"]` written
  at ~1080-1081. Phase 2 at ~1136-1181: `_1d_face_m` defaults to `0.0` when
  `_pipeline_result is None`; `_apply_1d = _pipeline_result is not None and
  _1d_face_m > 0.0`; the `else` at line ~1172 sets the pipeline fields to `None`
  and `entry["degraded"] = True` while **leaving the Phase-1 CURVE
  `breakingFaceHeight` in place**. That is the silent fallback.
- **Live confirmation of the failure**, `GET /api/v1/surf/huntington-city-beach-pier`
  on weewx, 2026-07-24: every forecast entry has `degraded: true`,
  `bestPeakFaceHeight: null`, `breakPoints: null`, `openTransectCount: 0` of
  `transectCount: 32`, yet `breakingFaceHeight` carries real-looking numbers
  (e.g. 2.99 at 13:00Z). Those numbers are SWAN CURVE output, not SwellTrack.
- **`grep -rn "degraded" repos/weewx-clearskies-dashboard/src/` finds no
  consumer** of this field. Removing it breaks nothing; the dashboard agent is
  adding `modelStatus` handling in parallel per its own brief's LC-E.

---

## 4. Scope

### 4.1 Files to create or modify (exhaustive)

| File | What changes |
|---|---|
| `weewx_clearskies_api/endpoints/beach_profile.py` | T4A.1 Do step 1 — vocabulary only. |
| `weewx_clearskies_api/endpoints/surf.py` | T4A.4 Do steps 1, 2, 4, 5, 6, 7. |
| `weewx_clearskies_api/enrichment/surf_scorer.py` | T4A.4 Do step 3 — null-face-height handling. |
| `tests/test_surf_endpoint.py` | Tests for the four `modelStatus` cases and the absence of CURVE face heights. |
| `tests/test_surf_scorer.py` | Tests for null vs 0.0 face height. Do **not** weaken the pre-existing failing test. |
| `tests/test_beach_profile.py` (new if absent) | Vocabulary assertions for both response paths. |

### 4.2 Files NOT to touch

- `enrichment/bathymetry.py`, `services/surf_1d_analytical.py`,
  `services/swan_domain.py`, `providers/nearshore/swan.py`,
  `endpoints/setup.py`, `config/marine_config.py`, `pyproject.toml` —
  **T4A.2/T4A.2b and T4A.3 own these**, in parallel with you.
- `enrichment/breaker_height.py` — **read it, do not change it.** T4A.4 removes
  *calls* to `hsig_to_face_height()` from the surf endpoint; the module itself
  stays (the beach-profile break-point face heights and the 1D pipeline still use
  it, and SURF-ZONE-MODEL-BRIEF §7 says the K-G/Caldwell conversion is retained).
  If you conclude the module becomes fully dead, report it — do not delete it.
- `providers/alerts/nws.py`, `services/surfbeat_strip_benchmark.py`.
- Anything in `repos/weewx-clearskies-dashboard/` — **read-only reference.**
  The dashboard half of T4A.1 belongs to another agent.
- Anything in `repos/weewx-clearskies-swan-swelltrack/`,
  `repos/weewx-clearskies-stack/`, `repos/weewx-clearskies-marine/`.
- Any file in the meta repo (`docs/`, `rules/`, `reference/`) — the coordinator
  owns governing-doc updates. **In your closeout, tell me exactly what needs to
  change in `docs/manuals/API-MANUAL.md` §18** (the `modelStatus` field, the
  nullable `breakingFaceHeight`, the removal of `degraded`, and the beach-profile
  field names) so I can make the doc-code-sync commit.
- **Any file on any container.** Forbidden by any mechanism, including staging a
  file "as data" for a script.

### 4.3 Verification commands — report raw output

```bash
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-api
git log --oneline -1                      # your actual starting HEAD

# Adversarial Audit item 3 — run it on yourself first. Expect ZERO hits:
grep -n "hsig_to_face_height" weewx_clearskies_api/endpoints/surf.py

# Adversarial Audit item 1 (API side) — expect ZERO hits in beach_profile.py:
grep -n "distanceFromShore\|waveHeight\|hsEnvelope" weewx_clearskies_api/endpoints/beach_profile.py

# Your tests, then the 4-file regression set (must not grow past baseline).
```

Remote verification on weewx requires the lead to deploy first (container
checkout is pinned; you cannot push). **Report that as the blocker** rather than
working around it. I will deploy and re-run at QC Gate 4A.

**Physical plausibility.** Per `rules/clearskies-process.md`, a valid HTTP 200 is
not verification. For each of your four `modelStatus` cases, state what a consumer
sees and why it is the truthful rendering — in particular, why `"unavailable"` +
`null` is correct rather than `0.0`, and why `"no_breaking"` + `0.0` is correct
rather than `null`. If you cannot articulate the difference, you have not
understood T4A.4's Do step 2 and should re-read it.

### 4.4 Deliverable definition

- 2–4 commits on local `main`, messages naming the tasks
  (`refactor(T4A.1): …`, `feat(T4A.4): …`).
- `git status` showing **only** the two pre-existing dirty files (plus whatever
  the parallel agent has in flight — do not stage those).
- A SendMessage closeout walking **every Accept bullet of T4A.1 and every Accept
  bullet of T4A.4** with per-bullet evidence (file + line, or command + raw
  output), plus the API-MANUAL change list from §4.2. Assertion without evidence
  will be rejected.

---

## 5. Lead calls — decisions already made; implement them, do not re-derive

### LC-14 — Stage explicitly; never `git add -A` or `git add .`

Another agent is committing in this same checkout at the same time. `git add -A`
would sweep its half-finished edits into your commit. **Stage only the exact
paths you changed, by name, every time.** If `git status` shows a modified file
you did not touch, leave it alone and do not mention it in your commit. This rule
is absolute for this round.

### LC-15 — `transect` is the array key; `distance` / `depth` / `hs` are the point keys

T4A.1's Decision is explicit and the plan says to revert the earlier
`distanceFromShore`/`waveHeight` rename (commits `89c3bfe`/`0d87b28`). Concretely,
in `_build_transect_profile()`:
- envelope points: `distance`, `depth`, `hs` (keep `swellHeight`,
  `breakingFraction`, `breakingDissipation`, `waveShape` unchanged — only the
  three renamed keys change)
- break points: `distance`, `depth`, `hs`, `faceHeight`, `breakerType`
- the sort key at line ~453 changes with them
- array key stays `"transect"`

Because both response paths go through this one builder, both change together —
that is the point. Do not add a compatibility shim emitting both spellings; a
dual-vocabulary response is exactly the problem T4A.1 exists to delete, and the
dashboard agent is changing in lockstep this round.

Wave shapes and jacking factors already use `"distance"` — leave them.

### LC-16 — `modelStatus` replaces `degraded`; do not keep both

T4A.4 Do steps 2 and 7 define four values: `"ok"`, `"no_breaking"`,
`"unavailable"`, `"degraded_bulk"`. Remove `degraded` from the response entirely
rather than keeping it "for compatibility". I verified the dashboard has no
consumer, and the dashboard agent is adding `modelStatus` this round. Two fields
expressing overlapping truth is how the current bug survived.

Map the existing signals onto the four values exactly as Do step 2 and Do step 7
specify — read them; I am not restating them here. Note that the current code
folds two distinct conditions into one boolean at line ~1171
(`_pipeline_result.degraded or _swelltrack_compute_fallback`); decide which
`modelStatus` value each maps to, state your mapping in the closeout, and make it
explicit in the code.

The distinction that matters, and that the auditor will probe: a model that ran
and found flat water is **not** the same as a model that failed. Conflating them
tells a surfer "it's flat" when the truth is "we don't know."

### LC-17 — `score_surf()` returns null, and the caller must not paper over it

Do step 3: the scorer takes the SwellTrack face height. When it is `None`, the
scorer returns no quality score. Implement that as an explicit `None` return (or
a result object whose score fields are `None`) — **not** as a 0-star rating and
not as a raised exception the endpoint swallows.

Then check every consumer of the scorer's output in `surf.py` — `qualityStars`,
`qualityLabel`, `scoring`, `conditionsText` — and make each one null/absent
rather than defaulted. A `conditionsText` reading "0-1 ft, Poor" generated from a
null face height is the same lie in prose form. `conditionsText` is
human-readable and must resolve through the locale file per `rules/coding.md`
§6.2 — if you need a new "forecast unavailable" string, add the key and tell me;
do not hardcode English.

### LC-18 — Deployment ordering is mine, not yours

T4A.4's Deployment constraint says T4A.4 and T4A.5 must deploy together, or
T4A.5 first, because removing the fallback before SwellTrack produces non-zero
output makes the surf page show zeros everywhere.

**That is a coordinator responsibility.** I control the deploy and I will
sequence it: T4A.2's PCHIP profile regenerated on librewxr (T4A.5) is verified to
produce non-zero SwellTrack output *before* your T4A.4 change goes live. You
implement T4A.4 fully and commit it locally. Do **not** add a feature flag, a
config toggle, an environment-variable guard, or any other mechanism to make the
fallback removal conditional — that would reintroduce the dual-path ambiguity
under a new name. Commit the clean removal.

### LC-19 — `waveHeightAtBreak` and `swellHeight` disposition

T4A.4 Do steps 5 and 6 keep `swellHeight` (deep-water SPECOUT) and the SWAN TABLE
`HSIGN`/`TM01`/`DIR` scorer inputs. They do not mention `waveHeightAtBreak`,
which today is derived from the CURVE path in Phase 1 and overwritten from
`_best_face_m / 1.27` in Phase 2 (line ~1152).

**My call:** `waveHeightAtBreak` is a breaking-zone quantity, so it follows
`breakingFaceHeight` — derive it from the SwellTrack result only, and make it
`null` when `modelStatus == "unavailable"` and `0.0` when `"no_breaking"`. The
`/1.27` derivation at line ~1152 stays. If reading the code shows
`waveHeightAtBreak` has a consumer that cannot handle null, report it before
changing it.

---

## 6. Open questions — SendMessage the lead; do NOT resolve unilaterally

- If removing the Phase-1 CURVE computation orphans variables or fields consumed
  further down `surf.py` that you cannot cleanly derive from SwellTrack, list them
  and stop. Do not reinstate a partial CURVE path to keep them alive.
- If `enrichment/breaker_height.py` becomes entirely unreferenced after your
  change, report it — do not delete it (see §4.2).
- If `test_surf_scorer.py::test_perfect_conditions` (pre-existing failure) turns
  out to be failing *because* of the CURVE-vs-SwellTrack input mismatch your
  change fixes, say so — that would be a genuine fix, and I want it recorded
  rather than quietly absorbed.
- If the four `modelStatus` values cannot cleanly cover a state the current code
  can reach, describe the state — do not invent a fifth value.
- Anything that would require touching a file in §4.2.

---

## 7. Git restrictions (MANDATORY)

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`,
> `git rebase`, `git merge`, or `git checkout` of remote branches. You may only
> `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is
> ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

> **Agents edit and commit ONLY on the local machine — HARD BAN on container
> edits.** All editing and committing happens at
> `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`. You must NEVER edit
> source files on weewx, weather-dev or librewxr, and never run any git write
> operation on any container. SSH to containers is READ-ONLY.

Per **LC-14**: stage only your own named files. Never `git add -A`, never
`git add .`.

**Commit messages:** use `git commit -F c:\tmp\<name>-msg.txt` — PowerShell
heredocs break on parens and quotes.

**Scratch file:** append to `c:\tmp\marine-sep-P4A-scratch.md` after every commit
and every decision.

---

## 8. Scope acknowledgment — required before any code

Before writing any code, SendMessage the lead with a one-paragraph scope
acknowledgment: what you will deliver, what you will NOT touch, your measured
starting HEAD, and the exact verification commands you will run.
