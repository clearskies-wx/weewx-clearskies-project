# Marine Service Separation Plan

**Status:** DRAFT — awaiting review
**Created:** 2026-07-22
**Origin:** User-ordered full audit of the marine/surf system. The audit (documented in `docs/planning/briefs/SURF-MODEL-SEPARATION-BRIEF.md`) found that the ~28,000-line marine system was improperly embedded in the API instead of being a standalone companion service. A partial extraction was attempted (SWAN service on librewxr:8767, compute service on librewxr:8770) but left the surf page empty for 24+ hours due to cascading failures: TLS cert rejection, local SWAN fallback producing no cached data, and two-service fragmentation.
**Governing brief:** `docs/planning/briefs/SURF-MODEL-SEPARATION-BRIEF.md`

---

## CURRENT STATUS — 2026-07-25 (session handoff)

| Phase | State |
|---|---|
| **Phase 1** — Governing doc updates | COMPLETE, QC Gate 1 passed |
| **Phase 2** — TLS + remote mode | Code landed; QC Gate 2 never formally closed |
| **Phase 3** — SWAN caching + E2E | **NOT closed.** Root cause is live: see below |
| **Phase 4** — Marine service repo + scaffold | **COMPLETE. QC Gate 4 CLOSED 2026-07-25** |
| **Phase 4A** — SwellTrack pipeline + vocabulary | **Tasks complete; QC Gate 4A walked but NOT a clean pass** — see `briefs/P4A-QC-GATE-4A-RESULTS.md`. The "3 of 8 tasks done, T4A.3 halted" text that stood here until 2026-07-25 contradicted this document's own task table below, which records T4A.3 and every other task as DONE. Corrected to match the detail table. |
| **Phase 4B** — Per-transect grid-derived handoff | **PARTIALLY IMPLEMENTED AND DEPLOYED** — not "not started." See the corrected status block below. |
| **Phase 5** — Move provider modules | **CODE COMPLETE.** Adversarial audit run 2026-07-25: C-28 cleared with evidence, one HIGH finding (C-31, dispatch registry held only the scaffold stub) fixed in Phase 6. |
| **Phase 6** — API companion proxy | **COMPLETE. QC Gate 6 walked and passed with two named exceptions (C-40, C-48), 2026-07-25.** See the Phase 6 closeout below. |
| **Phase 7** — Wizard/Admin updates | **COMPLETE. QC Gate 7 walked and passed with named exceptions, 2026-07-26.** See the Phase 7 closeout below. |
| Phase 8 | IN PROGRESS — T8.1/8.1b/8.2/8.2b/8.3 deployed; T8.6 RUN and FAILED; T8.10 added 2026-07-26 |

### Phase 7 — COMPLETE. QC Gate 7 walked 2026-07-26, passed with named exceptions.

**ADR-099 was accepted by the operator on 2026-07-26.** Status flipped to `Accepted` (meta
`b3c5cf5`), and all **10** `(target — pending ADR-099 acceptance)` annotations were cleared from
`ARCHITECTURE.md` (`66a2769`). They were not removed uniformly: 2 sites describe state the code has
reached and became plain fact; 8 describe state that is built but **not deployed** (the marine
service is not running on port 8780; ports 8767 and 8770 are still live on librewxr) and carry
`(not yet deployed — Phase 8)` instead. Stripping the marker from that second group would have made
`ARCHITECTURE.md` — the "what IS" document — assert a running service that does not exist.
Archival of ADR-099 per the consolidation lifecycle is deferred to the Phase 8 closeout so the
document stays citable while Phase 8 executes against it.

#### QC Gate 7 — result

Walked by the coordinator against final code, every check re-run independently rather than taken
from any agent report.

| Gate criterion | Result |
|---|---|
| "Marine Service" naming throughout | **PASS** — `"Wave Modeling"` = 0 repo-wide, translations included |
| Single URL field | **PASS** — both second URLs gone (T7.2, C-58) |
| Test Connection works | **PASS at contract level** — two-probe; 401 surfaces as "Secret rejected" (C-52) |
| Validation works | **SPLIT — named exception.** Wizard guarded (T7.4 + C-57); admin has no guard (**C-64**) |
| Secret in `secrets.env` | **PASS** — never written to `api.conf`; mirrored to `os.environ` *before* the config push |
| Config push works | **NOT LIVE-TESTABLE** — nothing is deployed until Phase 8. Verified by contract inspection only |
| All 13 locales updated | **PASS** — 28 dead strings pruned, 39+5 added, `help.admin.marine_service.*` in 13/13 |
| Pydantic models accept new fields | **PASS — but only after C-67**, which was a live defect at the time the gate was requested |
| Auditor: zero unresolved findings | **1 carried** — F2 → **C-64**, routed to Phase 8 by prior decision |

**Verification evidence (coordinator-run):**

```
"Wave Modeling" outside translations                 -> 0
surf_compute_/trushore_service_url/test-compute      -> 0 (1 correct historical docstring)
apply key: wizard :4175 ["swan"], admin :3122 ["swan"] -> both correct
marine manifest discovery entries / mounted routes   -> 7 / 7
uv lock --check                                      -> Resolved 72 packages (exit 0)
locale parity vs en.json, both directions            -> 40 / 22 (baseline 42 / 22)
13 locales valid JSON; 5 new C-66 strings            -> 13/13 present, 12/12 translated
```

#### The gate's real finding — C-67

**The criterion "Pydantic models accept new fields" was not met when this gate was requested, and had
not been met for many commits.** The API renamed `ApplyRequest.trushore` to `swan` in the
TruShore→SWAN rename (`0685121`); the config UI never followed. With `extra="forbid"`, every apply
carrying SWAN config returned 422 and wrote **nothing** — not the SWAN settings, not the marine
locations, not any other section in the same request. Separately, three admin sites read the old key
from `/setup/current-config` and silently rendered defaults over the operator's saved settings.

The payload *fields* were always correct; only the enclosing key was wrong, so every inspection that
checked field names found them right. Found by the adversarial audit (write path) and extended by the
coordinator (read path). Fixed in stack `e85e174`.

#### Named exceptions — the gate passes with these open, all tracked

| Concern | Disposition |
|---|---|
| **C-63** | Same-host URL literal exists twice by design (no cross-router imports). Verified: exactly two, identical. Low priority. |
| **C-64** | Admin has no blank-URL guard. Sharpened by the audit: clearing the field writes `""`, which Pydantic accepts, so an operator can disconnect the marine service and be told it saved. → Phase 8. |
| **C-55 / C-59** | Four `/setup/marine/*` endpoints and undeclared `rasterio` → Phase 8 assessment, sequenced together. |
| **C-68** | The marine service has no install documentation of its own → Phase 8, with T8.1. |
| **C-69** | Locale drift, inherited: 40/22 key asymmetry **and** ~23–25% untranslated values (`fil` an outlier at ~48%). Phase 7 introduced none of it and reduced the key gap by 2. Own round. |
| `config_writer.py:513` | The one surviving `surf_compute_` hit. Read and confirmed a correct historical docstring — **not a miss**. |

#### Deploy-readiness items cleared this phase

- **C-60 item 1 — the deploy blocker — CLOSED** (API `0a514f2`). `uv.lock` regenerated: 11 packages
  pruned, zero added, zero version churn. ⚠ The concern's stated mechanism was **wrong** and is
  corrected in the register: `deploy-api.sh` runs no `uv` command at all. The real blast radius was
  `uv run --frozen` (the documented pytest invocation on weewx) and `uv sync --frozen`
  (`deploy-compute.sh`).
- **C-60 item 2 — RESOLVED, no operator decision needed.** ADR-085 is already archived, and archived
  ADRs are not restated to current state. What it actually pointed at was live manual drift, fixed
  across `ARCHITECTURE.md`, `OPERATIONS-MANUAL.md`, `API-MANUAL.md` and `PROVIDER-MANUAL.md` — the
  Operations Manual had been telling operators to `apt install libeccodes-dev` and
  `pip install weewx-clearskies-api[marine]`, an extra that no longer exists.
- **C-66 — CLOSED** (stack `49b080c` + `b7830bb`). C-54 moved the SWAN answer to the marine host; the
  copy beside it still said "this host" and named a deleted pip extra. Every instruction pointed at
  the wrong machine on exactly the split-host topology this plan exists to support.

**Standing lesson from C-66 and C-67 together:** when a change moves *where an answer comes from*,
every surface that explains that answer moves with it — not just the call sites that fetch it. And
when a contract is renamed, **the key a payload is filed under is part of that contract too.**

| Task | State |
|---|---|
| T7.1 rename "Wave Modeling" → "Marine Service" | **DONE** — wizard + admin code. `"Wave Modeling"` returns **0** repo-wide outside `translations/`. |
| T7.2 unify URL fields | **DONE, fully met.** Both second URLs removed — the providers-step compute host and the TruShore/SWAN `service_url` (C-58). |
| T7.3 Test Connection | **DONE** — `POST /setup/providers/test-marine`, two-probe (C-52); wizard and admin repointed. |
| T7.4 validation | **DONE** — providers step **and** marine step (C-57; the providers-only check could never fire on a first pass). |
| T7.5 admin providers section | **DONE** — `marine-service`, plus two save-path defects fixed (C-62, C-65). |
| T7.6 config push feedback | **DONE** — `marine_config_push` on the apply response, rendered on both surfaces. |
| Carried concerns C-48 / C-49 / C-54 | **DONE** — three marine `/discovery` endpoints; the last four marine-physics modules deleted from the API (**−5,569 lines**); `[marine]` extra pruned. |
| **Translations (13 locales) + Operator Manual** | **NOT STARTED** |
| **Adversarial audit** | **NOT STARTED** |
| **QC Gate 7** | **NOT WALKED** |

**Full detail, per-round verification evidence and an ordered resume plan are in
`c:\tmp\marine-sep-P7-scratch.md`.** Read it before resuming — it carries the string lists, the
exact help-key literals, and the deploy-blocking items below.

**Three findings that must not be lost:**

- **C-65 — the one regression this phase introduced, and it was the coordinator's.** A freeze placed
  on the admin TruShore section pending C-58 was never lifted when C-58 was decided, so only the
  wizard half was dispatched and the admin's Save began returning 422. Fixed. The standing lesson: a
  freeze pending a decision must be lifted **explicitly on every surface it covered**.
- **C-60 will break the Phase 8 deploy if ignored.** `pyproject.toml` lost the `[marine]` extra and
  `uv.lock` was not regenerated, while `deploy-api.sh` runs `uv run --frozen` — precisely the mode
  that fails on that mismatch.
- **Two escalations in this phase should never have reached the operator** (C-54, C-58); both were
  answered by documents this project already carries. `rules/clearskies-process.md` gained
  "Over-triggering is a failure mode too" as the durable fix.

**Nothing is blocked on the operator.**

### ⚠ Cross-round correction, 2026-07-25 — read before starting ANY remaining phase

A separate round, **SURF-PUBLISH-RESULTS-ONLY** (`briefs/SURF-PUBLISH-RESULTS-ONLY.md`),
landed between Phase 4B and Phase 5. It changed the data contract between the SWAN service
and the API, and it deleted the API-side recompute paths. **Several acceptance criteria
written in Phases 4B, 5 and 6 predate it and, if followed literally, would rebuild exactly
what it removed.** Each affected task now carries an inline ⚠ correction block. Do not
treat those blocks as optional context — they override the surrounding original text.

The governing rule that round established, which every later phase must preserve:

> **The model host publishes answers. The API serves answers.** Model working data — raw
> spectra, per-transect spectra — does not cross the host boundary. In remote mode the API
> does not recompute; a model gap surfaces as an explicit unavailable state, never as a
> substituted or locally recomputed value. Bundled single-host mode is a different topology:
> there SWAN runs in-process, and local computation IS the model, not a fallback.

#### Phase 4B — actual implementation state (verified against git, 2026-07-25)

The row that read "NOT STARTED — awaiting operator sign-off" was wrong. Seven commits are in
the API repo and deployed to librewxr; the per-transect handoff work is what produced the
21 MB published payload that SURF-PUBLISH-RESULTS-ONLY then had to address.

| Task | Actual state | Evidence |
|---|---|---|
| T4B.1 — per-transect POINTS/TABLE bands | **DONE, deployed** | `4492927`, hardened in `4dd8964` |
| T4B.2 — watershed partitioning | **DONE, not yet deployed.** Operator-approved 2026-07-25 after measurement (below). `decompose_spectrum()` has no production caller; SWAN's own PT* watershed partitions are the source at every site, L2 and L3. | `660e3c1`, `95d1e00`, `be78773`, `12f9ddc` |
| T4B.3 — per-transect per-hour selection | **DONE, deployed** | `4dd8964`, `e9a1047` |
| T4B.4 — L2 fallback per transect | **DONE, deployed** | `services/swan_runner.py`, `_t4b4_transect_dwr_name` |
| T4B.5 — SurfBeat stays uniform | **RESOLVED BY READING** — no code needed | — |
| T4B.6 / T4B.7 / T4B.8 | **NOT DONE** | — |

**Phase 4B was approved by the operator on 2026-07-25.** The "awaiting operator sign-off"
text that stood in the status row was written *before* that approval and was simply never
updated; `ARCHITECTURE.md` recorded the approval correctly at the time. There is no dispute
about approval — only a stale status line, now corrected here and in `ARCHITECTURE.md`.

**T4B.2 is closed. The swap was made, and the earlier reading of the evidence was backwards.**

⚠ **CORRECTION 2026-07-25 — supersedes what this section previously said.** This document
argued *against* the swap on the grounds that "SWAN's watershed resolved a single partition in
95.2% of rows, where `decompose_spectrum()` finds 3–5, so swapping would flatten the multi-swell
structure the spot actually has." That inference is invalid in both of its halves:

1. **The 95.2% figure was an artefact of the parser, not a property of SWAN.**
   `parse_table_pt_partitions()` looked for `-9`/`-999` sentinel values to mean "no partition
   here." SWAN never emits those. Measured across real output: **25288 exact-`0.0` fields and
   5264 real values — zero sentinels.** Absent partitions are encoded as `0.00000`, so the
   parser counted every absent slot as a present partition and the partition census built on
   top of it was measuring the parser. Fixed in `12f9ddc`; absence is now detected from a
   partition significant height of ~0 (tolerance 0.0005).

2. **"Ours finds more components" is evidence against ours, not for it.** A decomposition may
   not report more energy than the spectrum contains. Measured with
   `scripts/verify_partition_duplication.py` over 67 real preserved spectra, summing each
   reported component's m0 against the spectrum's own total m0:

   ```
   ENERGY CLOSURE (1.00 = exactly the energy present)
     all timesteps (n=67):        min 0.672   median 1.626   max 2.271
     multi-component (n=65):      min 1.511   median 1.626   max 2.271
     multi-component over 105%:   65/65
   COMPONENT COUNT: {1:2, 2:3, 3:43, 4:15, 5:4}
   CLOSEST-PAIR DIRECTION SEPARATION: min 0.6°  median 1.6°  max 4.4°  (65/65 under 80°)
   WORST — spectrum Hs=0.6012 m, closure=2.271:
     hs=0.5830 tp=10.2 dir=206.4 / hs=0.5120 tp=10.2 dir=210.1 / hs=0.4680 tp=10.1 dir=201.1
   ```

   Those three "independent swells" are 5° apart at the same 10.2 s period. They are one swell
   reported three times. **Cause:** the ±4-bin neighbourhood spans roughly 80° on a 10°/bin
   direction grid, with no exclusion between peaks, so neighbouring peaks integrate over each
   other's energy. The multi-swell structure being "flattened" was never there.

**Scope executed in `12f9ddc`** (operator-authorized directly in chat, 2026-07-25):

- Parser absence detection corrected (above).
- Both L3 CURVE handoff call sites source SWAN's PT* partitions; `decompose_spectrum()` is not
  called on either path.
- **L2 DWR PT* output added** — operator ruled this an oversight to be fixed in this round, not
  a new feature. `TABLE ... TIME XP YP PTHSIGN PTRTP PTDIR PTDSPR` is now emitted at the
  per-spot DWR baseline point and at every T4B.4 per-transect cell, producing
  `TABLE_DWR_{n}.txt` / `TABLE_{cell}.txt`. Without it, spots with no L3 grid would have kept
  the broken decomposition. Additive output only — no grid, nesting, or handoff change.
- `run_pipeline()` reads `specout_data["components"]` instead of recomputing, so the 1D physics
  and the displayed swell breakdown cannot diverge.
- No silent fallback: a missing (point, timestep) yields empty components and a WARNING naming
  spot and timestep. TABLE rows align to output points **by coordinate**, never by row order;
  unmatched rows are discarded with a WARNING.

**Coordinator QC, independently run — not accepted on the implementer's report:**

- `git show --stat 12f9ddc` — 6 files, matching the declared scope; working tree clean.
- No production module imports or calls `decompose_spectrum()` or `parse_and_decompose()`;
  the sole remaining caller is `scripts/compare_partitioning.py`.
- Coordinate alignment uses metre tolerance against UTM point coordinates built by the same
  `lonlat_to_utm()` call that writes the `POINTS` line — units are consistent.
- The new L2 column set is character-for-character the set already running on the L3 CURVE
  table on librewxr (`swan_formats.py:1459`) — copied from working output, not guessed.
- `pytest tests/test_swan_spectral_multi.py tests/services/test_swan_runner.py
  tests/test_surf_1d_pipeline.py tests/test_swan_runner_handoff.py -q` → **117 passed,
  15 errors**. The 15 are a pre-existing fixture defect (`config requires 'inner_bbox'`);
  `git blame` puts that line at `46eb8839`, 2026-07-17, eight days before this round.

**⚠ Open QC item — the pass/fail number is NOT yet measured.** The energy-closure figure above
was computed from the preserved payload at `/tmp/pub.json` on librewxr. That file's
`components` were themselves produced by `decompose_spectrum()` — verified at both population
sites in the deployed code, and confirmed by the measurement reproducing the broken baseline to
three decimal places. **It therefore cannot validate the fix.** Re-run
`scripts/verify_partition_duplication.py` against a *fresh* model run after deploy; closure
should sit at ≈1.0 rather than a 1.63 median. The in-repo energy-closure unit test uses a
self-consistent synthetic spectrum and is a contract test on the parser — it is not a
substitute for this measurement.

**Known limitation, logged honestly rather than deferred silently:** per-transect alongshore
variation would require each transect's own TABLE PT* columns, not the shared CURVE's. Not
done this round and not claimed.

**Doc-code sync:** the implementation round was scope-blocked from editing documentation.
`PROVIDER-MANUAL.md`, `ARCHITECTURE.md`, the SWAN reference doc and any manual describing SWAN
TABLE output or the swell-component source are handled in a separate commit.

### Phase 4 — COMPLETE

Repo `weewx-clearskies-marine` created, **private** on GitHub
(`clearskies-wx/weewx-clearskies-marine`), 7 commits. T4.1-T4.6 all PASS,
independently verified by the coordinator on weather-dev (Linux, Python 3.12)
with curl — not on the implementer's platform or with its HTTP client.
Adversarial audit produced 5 findings: 2 BLOCKER (both fixed and re-verified),
3 NON-BLOCKING (fixed or tracked to named tasks T5.8 note / T6.4b).
Full evidence in `c:	mp\marine-sep-P4-scratch.md`.

### Phase 4A — task status

**Updated 2026-07-25, resume session Rounds 1 and 2.**

| Task | State |
|---|---|
| T4A.1 (API side + dashboard side) | **DONE**, independently verified |
| T4A.2 (PCHIP profile) | **DONE** |
| T4A.2b (B-J flux marching + LC-22 exact Qb) | **DONE** |
| T4A.4 (remove SWAN CURVE fallback) | **DONE**, independently verified |
| T4A.13 (superseded brief banners) | **DONE** `25afa30` — 38 insertions, 0 deletions, coordinator-verified |
| T4A.12 (remove Supplement 4 topographic multipliers) | **DONE** `7dd9899` + `4d58957` (API-MANUAL), coordinator-verified |
| T4A.8 (SurfBeat `NameError`) | **DONE** `08ce616` — 6 F821 at parent → 0, coordinator-verified |
| T4A.7 (delete `wave_transform` supplements) | **DONE** `167ad73` + `aef7669`. Gate answered: SWAN interpolates POINTS/SPECOUT output to the requested coordinate (manual §2.6.4/§4.6.1 + `swanout1.ftn` `SWOEXA`/`SWOEXD`). **Both** surviving supplements removed. |
| T4A.3.0 (reconstruct intended-vs-actual) | **DONE** `ed4613f` — `briefs/P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md`. 17 rows, 11 inventory entries, 8 named gaps. **No longer blocks T4A.3.** |
| T4A.3 (CUDEM at apply time) | **DONE** `8850e7e` + `db33f01` + `47c3d91`. The earlier "halted, uncommitted, implements a wrong instruction" state is resolved: that work was reviewed and committed as `244ee08`, and the claim that part of it implemented a retracted instruction **was wrong** — see the correction in `briefs/P4A-RESUME-SESSION-PROMPT.md`. `00564b9` adds `max_hs_m`. **Gap: "progress visible to operator" is NOT met** — the chain runs via `BackgroundTasks`; see the named gaps in `briefs/P4A-AUDIT-FINDINGS.md`. |
| T4A.11 (widen L3 trigger + viability test) | **DONE** `ceb8252` + `d90bc88` + `eca80ee`. Merged with T4A.3 under one agent — both own L3 sizing in `swan_domain.py`. Includes the L2 fallback for L3-disabled spots (see the defect note below) and the shoreward-edge criterion (audit F1). |
| T4A.9 / T4A.10 (per-hour handoff + QB assertion) | **DONE** `a54f2cb` + `a0c45b5` + `69957f7`. The reopen matters: the handoff was computed and then **discarded at the compute-offload wire**, and only 1 of 5 call sites ever passed it. |
| T4A.6 (beach profile shape mismatches a–g) | **DONE** `8e2710f` + dashboard `452d921`/`923dd0c`, plus audit fixes `dcbe9e4` (F2) and `3c7e993` (F3). **Watch item:** item (b)'s jacking annotations render only when jacking factors exist, and the regenerated HB profile produces **zero** of them — see T4A.5 below. |
| T4A.5 (regenerate caches on librewxr) | **DONE 2026-07-25** — see the T4A.5 results block below for evidence and two recorded deviations. |
| Adversarial audit + QC Gate 4A | **Audit DONE** — 3 BLOCKERs (F1/F2/F3), all remediated; findings recorded in `briefs/P4A-AUDIT-FINDINGS.md`. Gate assessment pending final end-to-end run. |
| **Phase 4B** (per-transect grid-derived handoff) | **APPROVED 2026-07-25 and largely DONE — this row's "NOT STARTED — awaiting operator sign-off" text was stale and is corrected in the Phase 4B section above, which is authoritative.** T4B.1/3/4 done and deployed; T4B.2 done in `12f9ddc`, not yet deployed; T4B.5 needed no code; T4B.6/7/8 outstanding. The original findings stand as the motivation: the handoff collapsed the 2D field to one point per spot and replicated it across all 32 transects; 50 m station spacing could not reach the handoff depth (all 73 timesteps clamped); and `decompose_spectrum()` did not conserve energy — measured at a 1.626 median and 2.271 worst-case energy closure, now replaced by SWAN's own watershed partitions. |

**Defect found 2026-07-25 and folded into T4A.11 — L3-disabled spots currently produce NO data.**
`swan_runner.py:1525` skips a cluster whose `grid is None`, and the returned result dict is only
ever populated from L3's own output parse. The L2 deep-water reference SPECOUT **is** computed
for every spot and then discarded, because the per-spot cache-write loop
(`providers/nearshore/swan.py:1764`) never reaches those spot ids. ADR-093 Amendment 2 §4 states
that such a spot "runs L1 → L2 → SwellTrack from L2's ~15 m reference, as an open beach does" —
**that fallback does not exist in the code.** Because the viability test makes L3-disabled the
majority case, landing it without the fallback would take working spots to zero data behind a
valid HTTP 200. Building the fallback is now mandatory in T4A.11 and must land before the
viability test can return false. Found by T4A.3.0, coordinator-verified in the code. Full
citations: `briefs/P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md` Area 1 row 1.3.

Same root cause also silently disables the SurfBeat strip for those spots
(`endpoints/surf.py:829–831`, `if not _sb_pts: continue`), which undercuts the premise that the
strip carries approach-zone wave height once L3 stops early.

### Live production state (verified 2026-07-25, librewxr)

**SWAN is working.** Over the last 5 days: **10 successful runs (1/1 spot cached)
and 3 convergence failures.** The most recent run — 2026-07-25 01:40, HRRR cycle
`25T00:00Z` — succeeded. The convergence gate is doing its job: it catches the
occasional bad run, and the next cycle recovers.

> **Correction (2026-07-25).** An earlier version of this block claimed SWAN was
> "running and discarding its own output" and called that the root cause of the
> empty surf page. **That was wrong** — extrapolated from a single `nan_detected`
> log line without checking whether surrounding runs succeeded. The operator
> caught it. The empty surf page is caused by the broken 50-point spot profile
> starving SwellTrack, which is what T4A.2 fixes and T4A.5 deploys — the
> diagnosis this plan already carried.

**Tracked observation — not a blocker, do not let it displace Phase 4A work.**
All three convergence failures fell on the **18Z HRRR cycle**:

| Failure | Check | HRRR cycle |
|---|---|---|
| 2026-07-23 01:40 | `low_valid_fraction` 38.8% | `2026-07-22T18:00:00Z` |
| 2026-07-23 19:31 | `nan_detected` 1567 | `2026-07-23T18:00:00Z` |
| 2026-07-24 19:33 | `nan_detected` 1061 | `2026-07-24T18:00:00Z` |

Zero failures on 00Z, 06Z or 12Z in the same window. Three data points — 3-for-3
on one cycle against 0-for-10 on the others is suggestive, not proven. HRRR 404s
were checked as a confound and occur on succeeding cycles too, so missing GRIB
files alone do not explain it. **Worth chasing after Phase 4A closes**; the model
is not yet completely implemented and that comes first.

### Deployment state

> **⚠ This block is a snapshot and goes stale fast. Verify against the hosts before relying
> on it — do not plan a deploy from these commit hashes.** The version below stood unchanged
> through several rounds of work while every hash in it moved.

**Updated 2026-07-25, after SURF-PUBLISH-RESULTS-ONLY:**

- weewx: API deployed and running. SWAN binary disabled there (remote mode —
  `[swan] service_url = https://192.168.7.22:8767`).
- librewxr: SWAN + compute services active. Was pinned behind origin at `ce4415b` until
  2026-07-25; deploying moved it forward 8 commits and pulled in the Phase 4B per-transect
  work, which is what produced the 21 MB published payload.
- ~~**Local, committed, NOT pushed and NOT deployed:** API repo `main` at `69b9442`
  (6 commits), SWAN service repo at `ca22432` (2 commits), dashboard `main` at `46c9e45`,
  meta repo `main` carrying the brief and the doc updates.~~
- **CORRECTED 2026-07-25, Phase 5 open — the line above is stale. Everything is pushed and
  deployed, and SURF-PUBLISH-RESULTS-ONLY is live.** Verified by `git fetch` + `status -sb`
  on every repo and by querying the hosts directly, not from any snapshot:

  | Repo | Branch | Local = origin | Deployed |
  |---|---|---|---|
  | weewx-clearskies-api | main | `12f9ddc` | weewx `12f9ddc`, librewxr `12f9ddc` |
  | weewx-clearskies-swan-swelltrack | master | `ca22432` | librewxr `ca22432` |
  | weewx-clearskies-marine | main | `51ce31b` | not deployed (Phase 8) |
  | weewx-clearskies-dashboard | main | `df60297` | — |
  | weewx-clearskies-stack | main | `f8beb34` | — |

  Live contract check from the weewx host against `librewxr:8767` —
  `GET /surf/huntington-city-beach-pier/forecast` returns **2.69 MB** (was 21.03 MB) with keys
  `forecast, hrrr_cycle_time, run_time, spectral, swelltrack, transect`; `swelltrack` has 67
  entries; `energy`, `freqs_hz`, `dirs_deg` and `handoff_by_transect` are gone. All six API
  marine endpoints return HTTP 200 with non-empty bodies. **T5.0's prerequisite is met.**

- **Deploy order remains mandatory for any future redeploy of these repos** — see
  `briefs/SURF-PUBLISH-RESULTS-ONLY.md` §6. The `swelltrack` publication fix must go first;
  deploying the API's recompute deletion before it would leave every forecast hour reporting
  `modelStatus: "unavailable"`.
- **Concerns register:** `docs/planning/MARINE-SEP-CONCERNS.md` carries every item the
  coordinator flagged during Phases 5–8, with recorded decisions for the blocking ones.

**Superseded snapshot (kept only to show how far it had drifted):** weewx API at `0d87b28`,
librewxr API repo at `bfff1f7`, local API `main` at `11b5242`, local dashboard at `20c6e50`.

---


**NO DEFERRAL RULE:** Every task in every phase must be completed and verified before the QC gate closes. "Deferred to v2", "batched with later audit", and "blocked on X" are not acceptable outcomes. If a task cannot be completed, the phase fails and work stops until the blocker is resolved. This rule exists because the SURF-1D-IMPLEMENTATION-PLAN deferred adversarial audits for Phases 2, 3, and 4 — exactly the quality gate that would have caught the issues this plan remediates. The only exception is Surfline comparisons (weather-dependent — clock extends until conditions occur naturally).

---

## 0. Orientation

### 0.1 Execution context

Same SSH rules, deploy scripts, and filesystem permissions as CLAUDE.md. Additionally:

- **weewx container:** API server (port 8765), MariaDB, Redis. SWAN binary has been **disabled** (`/usr/local/bin/swan.disabled`) during the audit to stop it from choking the API with failed runs. Marine provider modules (NDBC, CO-OPS, NWS, HRRR, GFS, WW3, OFS, ERDDAP) currently embedded in the API and fetching data directly. Config at `/etc/weewx-clearskies/api.conf` has `[swan] service_url = https://192.168.7.22:8767` and `[providers] surf_compute_host = https://192.168.7.22:8770`.
- **librewxr container:** 6 GB RAM, 16 cores. Runs the SWAN standalone service (`weewx-clearskies-swan` repo) on port 8767 and the compute service (`compute_service.py`) on port 8770. SWAN binary at `/usr/local/bin/swan`. API repo at `/home/ubuntu/repos/weewx-clearskies-api` (5 commits behind origin). Memory pressure: 4.3 GB of 5.6 GB used, 1.0 GB swap.
- **weather-dev container:** Dashboard (React SPA), config UI (wizard + admin), Caddy proxy. All deployed and current. Surf page renders but shows no forecast data.
- **Marine service port:** **8780** (registered in ARCHITECTURE.md port registry, Phase 1 T1.1).
- **Deploy scripts:**
  - `scripts/deploy-api.sh` — API changes to weewx (pull + restart + wait + verify)
  - `scripts/deploy-compute.sh` — Compute service to librewxr
  - `scripts/redeploy-weather-dev.sh` — Dashboard/config to weather-dev (pull + restart + build + publish)

### 0.2 Current state

| Component | Host | State | Issue |
|---|---|---|---|
| API service | weewx | Running, healthy (port 8765) | Non-marine endpoints work. Surf returns `forecast: []`, `lastRunTime: null` |
| SWAN binary | weewx | **Disabled** (`swan.disabled`) | Renamed during audit to stop CPU-choking local SWAN runs |
| SWAN provider (`swan.py`) | weewx (in API) | Probes `https://192.168.7.22:8767` at startup | **Fails every time:** `SSL: CERTIFICATE_VERIFY_FAILED certificate verify failed: self-signed certificate` |
| SWAN standalone service | librewxr:8767 | Running, healthy, actively computing | Health shows `last_run` populated, spots configured, runs succeeding |
| Compute service | librewxr:8770 | Running, healthy, idle | No compute requests in 11+ hours. Auth works. |
| Surf endpoint | weewx | Returns empty forecast | `nearshoreModel: "SWAN + SwellTrack"` correct, but `forecast: []` |
| Beach profile | weewx | Returns 404 | "No SWAN data cached for location" |
| Dashboard surf page | weather-dev | Renders, no data | SurfingTab.tsx (2,625 lines) complete — waiting for data |
| API repo (weewx) | weewx | Commit `fa48126` | 1 commit behind origin |
| API repo (librewxr) | librewxr | Commit `7dab1c5` | **5 commits behind origin** |
| Local repos (DILBERT) | local | All current | API: `6a0513e`, Dashboard: `9603fe6`, Stack: `f8beb34` |

**Root cause chain:**

```
1. Everything marine embedded in API (architectural violation)
      ↓
2. Partial extraction: SWAN on librewxr:8767, SwellTrack/SurfBeat on librewxr:8770
   BUT API still contains all the same code
      ↓
3. API tries remote SWAN → self-signed TLS cert → CERTIFICATE_VERIFY_FAILED
      ↓
4. Falls back to "bundled mode" — runs SWAN locally on weewx
      ↓
5. Local SWAN full runs fail at L3; quick updates succeed but 0 spots cached
      ↓
6. No SWAN data → no SwellTrack → no SurfBeat → no surf forecast
      ↓
7. Surf endpoint returns empty forecast, beach profile returns 404
      ↓
8. Dashboard surf page has no data
```

### 0.3 Agent assignments

| Role | Model | Responsibility |
|---|---|---|
| **Coordinator** | Opus | Architecture, agent briefs, QC gates, doc updates, research. Keeps this plan updated and checks items off as verified. |
| **clearskies-api-dev** | Sonnet | API code: TLS fix, companion service proxy, marine service scaffold, provider module moves |
| **clearskies-dashboard-dev** | Sonnet | Dashboard: no changes expected (dashboard is unaware of marine service) |
| **clearskies-docs-author** | Sonnet | Documentation only — manuals, the Operator Manual, and the 13 translation files. **Corrected 2026-07-25:** this row previously read "Wizard/admin: rename …, unify URL fields, config push", which is code work this role is hard-scoped against. See the correction block at the head of Phase 7. |
| **stack implementation agent** | Sonnet | Config UI code in `weewx-clearskies-stack`: wizard and admin routes, state, templates, client-side script. The stack repo has no dedicated dev role; dispatched as general-purpose. |
| **clearskies-test-author** | Sonnet | Tests: marine service unit tests, proxy integration tests, manifest handler tests |
| **clearskies-auditor** | Sonnet | Adversarial audit per phase (MANDATORY — no deferral) |

All agent prompts must include the git restrictions block:

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

### 0.4 Scratch file discipline

All agents write progress to `c:\tmp\marine-sep-{phase}-scratch.md`. Coordinator appends after every commit, lead-call, audit finding, state change. Not reconstructed retroactively. This prevents context loss at session limits.

Scratch files per phase:
- `c:\tmp\marine-sep-P1-scratch.md`
- `c:\tmp\marine-sep-P2-scratch.md`
- `c:\tmp\marine-sep-P3-scratch.md`
- `c:\tmp\marine-sep-P4-scratch.md`
- `c:\tmp\marine-sep-P5-scratch.md`
- `c:\tmp\marine-sep-P6-scratch.md`
- `c:\tmp\marine-sep-P7-scratch.md`
- `c:\tmp\marine-sep-P8-scratch.md`

### 0.5 Test baselines (must not regress)

| Suite | Baseline | Command |
|---|---|---|
| API pytest | Check before Phase 1 | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | Check before Phase 7 | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |

### 0.6 Code inventory

All code counts and file paths from the audit brief §4. Every file has been verified to exist in `repos/weewx-clearskies-api/weewx_clearskies_api/`.

#### Marine data provider modules (move entirely to marine service)

| Provider module | Lines | What it provides |
|---|---|---|
| `providers/buoy/ndbc.py` | 1,001 | NDBC buoy observations (wave height, period, water temp, met) |
| `providers/tides/coops.py` | 774 | CO-OPS tide predictions and observations |
| `providers/marine/nws_marine.py` | 645 | NWS marine zone weather forecasts |
| `providers/marine/nws_srf.py` | 1,215 | NWS NWPS surf forecasts |
| `providers/marine/wavewatch.py` | 578 | WaveWatch III deep-water boundary spectra |
| `providers/marine/grib_processor.py` | 449 | GRIB2 processing for marine data |
| `providers/wind/hrrr.py` | 907 | HRRR 3 km wind forcing (0-48h) |
| `providers/wind/gfs.py` | 729 | GFS 0.25° wind forcing (48-72h) |
| `providers/ocean/ofs.py` | 665 | OFS ocean surface currents |
| `providers/ocean/erddap_ocean.py` | 247 | ERDDAP ocean data |
| `providers/nearshore/swan.py` | 2,307 | SWAN orchestration (rewritten as internal pipeline in marine service) |
| **Subtotal** | **9,517** | |

#### Wave physics and model code (move entirely)

| Module | Lines | What it does |
|---|---|---|
| `services/swan_runner.py` | 2,628 | 3-level SWAN subprocess execution |
| `services/swan_domain.py` | 634 | Grid domain sizing, spot clustering |
| `services/swan_formats.py` | 1,511 | SWAN INPUT file generation |
| `services/swan_spectral.py` | 555 | SPECOUT parsing |
| `services/surf_1d_analytical.py` | 612 | SwellTrack 1D cross-shore model |
| `services/surf_1d_pipeline.py` | 1,091 | SwellTrack per-transect pipeline |
| `services/surfbeat_runner.py` | 961 | SurfBeat IG strip |
| `services/wave_setup.py` | 316 | Wave-induced water level |
| `services/bathymetry_resolver.py` | 1,070 | CUDEM bathymetry resolution |
| `services/shelf_boundary.py` | 80 | GSFM shelf distance |
| `services/transect_handoff.py` | 742 | SWAN-to-SwellTrack handoff |
| `enrichment/bathymetry.py` | 1,197 | SWAN depth grid generation |
| **Subtotal** | **11,397** | |

#### Enrichment / scoring (move to marine service)

| Module | Lines | What it does |
|---|---|---|
| `enrichment/breaker_height.py` | 283 | Breaking wave calculations |
| `enrichment/surf_scorer.py` | 730 | Surf quality scoring |
| `enrichment/wave_transform.py` | 312 | Wave transformation utilities |
| **Subtotal** | **1,325** | |

#### Marine config and services (move to marine service)

| Module | Lines | What it does |
|---|---|---|
| `config/marine_config.py` | 934 | Marine location config parsing |
| `services/marine_location_resolver.py` | 140 | Location resolution |
| `services/marine_weather_cache.py` | 135 | Marine weather caching |
| **Subtotal** | **1,209** | |

#### Delete (artifacts of the partial extraction)

| Module | Lines | Why delete |
|---|---|---|
| `services/compute_service.py` | 681 | The broken half-service on librewxr:8770 — replaced by the unified marine service |
| `services/compute_client.py` | 361 | Client for the broken half-service — replaced by the marine service client |
| **Subtotal** | **1,042** | |

#### Marine endpoints (delete from API — replaced by dynamic registration)

| Endpoint | Lines | Disposition |
|---|---|---|
| `endpoints/surf.py` | 1,317 | Delete — marine service serves `/surf/{id}`, API mounts via manifest |
| `endpoints/beach_profile.py` | 881 | Delete — marine service serves `/surf/{id}/profile` |
| `endpoints/marine.py` | 1,040 | Delete — marine service serves `/marine/{id}` |
| `endpoints/fishing.py` | 510 | Delete — marine service serves `/fishing/{id}` |
| `endpoints/beach_safety.py` | 497 | Delete — marine service serves `/beach-safety/{id}` |
| **Subtotal** | **4,245** | All deleted |

#### Summary

| Category | Lines | Disposition |
|---|---|---|
| Provider modules → marine service (11 modules) | 9,517 | Move |
| Wave physics → marine service (12 modules) | 11,397 | Move |
| Enrichment/scoring → marine service (3 modules) | 1,325 | Move |
| Config/services → marine service (3 modules) | 1,209 | Move |
| Delete (broken partial extraction) | 1,042 | Delete |
| Delete (endpoints replaced by dynamic registration) | 4,245 | Delete |
| **Total removed from API** | **~28,735** | |
| **API-side addition** | **~200-300 lines** | Generic companion-service proxy + manifest handler |

---

## PART A — Short-Term Fix (Phases 1-3)

**Goal:** Get the surf page showing real data by fixing the broken integration between the weewx API and the SWAN service running on librewxr. This does NOT restructure the architecture — it patches the existing broken remote mode so data flows again.

---

## Phase 1 — Governing Document Updates

**Purpose:** Update ARCHITECTURE.md, ADRs, and manuals to reflect the target marine service architecture BEFORE any code changes. Agents read docs before coding — stale docs produce wrong code. Documents are updated to describe the world as it WILL be after this plan completes, not as it is now.

**Scratch file:** `c:\tmp\marine-sep-P1-scratch.md`

### T1.1 — Update ARCHITECTURE.md

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/ARCHITECTURE.md`

**Do:**
1. Document the marine service as a **companion service** — a standalone extension that handles everything marine (wave physics, tides, buoy data, marine weather, fishing, beach safety). Same architectural DNA as the API (same provider module pattern, same structure).
2. Add the marine service to the Services table: `clearskies-marine`, repo `weewx-clearskies-marine`, port 8780 (single port), technology FastAPI.
3. Document the **manifest registration pattern**: marine service exposes `GET /manifest` returning an endpoint manifest. API dynamically mounts routes from the manifest under `/api/v1/`. Adding a new marine endpoint requires zero API code changes.
4. Document the deployment model: same-host (API calls `localhost:8780`) or separate-host (API calls `https://{host}:8780`). Operator configures `marine_service_url` in `api.conf` `[providers]`.
5. Remove references to SWAN running inside the API as a subprocess. SWAN runs inside the marine service. The API contains zero marine physics code.
6. Remove references to `surf_compute_host` and the compute service on port 8770.
7. Document that alerts stay in the API — marine alerts (coastal flood, high surf, rip current) are part of the unified alert system regardless of whether the marine service is installed.
8. Update the port registry to include the marine service port (8780). Remove port 8770 (compute service — eliminated).
9. Mark new marine service sections with '(target — pending ADR-099 acceptance)' until the ADR is user-approved. After approval, remove the annotation. This follows process rules that ARCHITECTURE.md describes "what IS."

**Accept:**
- ARCHITECTURE.md describes the marine service as a companion service with manifest registration.
- No references to SWAN running inside the API or as a subprocess.
- No references to compute_service.py or port 8770.
- `marine_service_url` documented as the single config key for the marine service.

### T1.2 — Draft ADR for marine service separation

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** New ADR (e.g., `docs/decisions/ADR-099-marine-service-separation.md`)

**Do:**
Draft an ADR documenting:
1. **Context:** The marine system (~28,000 lines) was embedded in the API. A partial extraction left two services (SWAN on 8767, compute on 8770) and the API still containing all the same code. The surf page has been broken for 24+ hours.
2. **Decision:** Separate all marine code into a standalone companion service (`weewx-clearskies-marine`). The API communicates via HTTP (authenticated, TLS). The marine service registers its endpoints via a manifest. Config is pushed from the API on operator apply.
3. **Options considered:** (a) Keep marine in API — rejected, 28K lines is unsustainable. (b) Two half-services (current broken state) — rejected, fragmented and broken. (c) Unified standalone marine service — accepted.
4. **Consequences:** API shrinks by ~28K lines. One service, one port, one auth token. Extensible pattern for future companion services. Dashboard unchanged.
5. **Implementation guidance:** Part A patches the existing integration first. Part B builds the proper architecture.

**Accept:**
- ADR follows the Nygard format per `docs/decisions/_TEMPLATE.md`.
- Status: Proposed (awaiting user approval).
- All three options evaluated with reasons.

### T1.3 — Update API-MANUAL

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/manuals/API-MANUAL.md`

**Do:**
1. Document that marine endpoints (`/surf/{id}`, `/marine/{id}`, `/tides/{id}`, `/fishing/{id}`, `/beach-safety/{id}`, `/surf/{id}/profile`) are **dynamically registered** from the marine service manifest. They are not hardcoded routes in the API.
2. Document the `marine_service_url` config key in the providers section.
3. Document the response envelope wrapping: API fetches raw data from the marine service, wraps in the standard envelope (`data`, `stationClock`, `freshness`, `units`), and applies unit conversion.
4. Document the capability merging: marine capabilities appear in `/api/v1/capabilities` when the marine service is connected.
5. Remove references to SWAN as an in-process model. Remove references to `surf_compute_host`.

**Accept:**
- API-MANUAL describes marine endpoints as dynamically registered.
- `marine_service_url` documented.
- No references to in-process SWAN or `surf_compute_host`.

### T1.4 — Update OPERATIONS-MANUAL

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/manuals/OPERATIONS-MANUAL.md`

**Do:**
1. Document the marine service deployment: same-host (install on API host, use `localhost:8780`) vs separate-host (install on compute machine, use `https://{host}:8780`).
2. Document the `marine_service_url` config key and the shared secret (`MARINE_SERVICE_SECRET` in `secrets.env`).
3. Document the config push model: wizard/admin save → API `/setup/apply` → marine service `/config`.
4. Remove references to the two-service model (`surf_compute_host` + `service_url`).
5. Document the marine service health check endpoint and monitoring.

**Accept:**
- OPERATIONS-MANUAL describes a single `marine_service_url` config key.
- Deployment model (same-host vs separate-host) documented.
- Config push model documented.

### T1.5 — Update PROVIDER-MANUAL

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
1. Document that the marine service's internal provider modules follow the same pattern as API providers: CAPABILITY declaration, `fetch()` interface, canonical field mapping, cache TTL management, error handling.
2. Document that marine data sources (NDBC, CO-OPS, NWS, HRRR, GFS, WW3, OFS, ERDDAP, CUDEM) are fetched directly by the marine service, not by the API.
3. Remove references to marine providers being part of the API's provider registry.

**Accept:**
- PROVIDER-MANUAL describes marine providers as internal to the marine service.
- Same provider module pattern documented for both API and marine service.

### Adversarial Audit — Phase 1

- **Owner:** `clearskies-auditor`

**Scope:**
1. Every doc updated in T1.1-T1.5 — verify no references to `surf_compute_host`, `compute_service.py`, or SWAN running as an API subprocess remain.
2. Verify `marine_service_url` is documented as the single config key for the marine service in all relevant manuals.
3. Verify the manifest registration pattern is described consistently across ARCHITECTURE.md and API-MANUAL.
4. Verify alerts are documented as staying in the API, not moving to the marine service.
5. Silent deferral scan: grep for TODO, FIXME, "deferred", "future" in all modified docs.

### QC Gate 1

- All 5 documents updated.
- `marine_service_url` consistent across all docs.
- No references to `surf_compute_host`, `compute_service.py`, or SWAN-as-subprocess.
- Manifest registration pattern described consistently.
- Alerts documented as staying in the API.
- Auditor: zero unresolved findings.

---

## Phase 2 — Fix TLS + Remote Mode Connection

**Purpose:** Fix the immediate blocker — the API cannot connect to the SWAN service on librewxr because of self-signed TLS cert verification failure. This is the root cause of the 24+ hour outage: `SSL: CERTIFICATE_VERIFY_FAILED certificate verify failed: self-signed certificate`.

**Scratch file:** `c:\tmp\marine-sep-P2-scratch.md`

### T2.1 — Fix TLS verification in SWAN provider remote mode

- **Owner:** `clearskies-api-dev`
- **Files:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py`, `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py`

**Reading list:**
1. `providers/nearshore/swan.py` — read `configure_remote_mode()` (line ~937) and `_remote_health_loop()` (line ~810). These are the two functions that make `httpx.get()` calls to the SWAN service without passing `verify=False`.
2. `services/compute_client.py` — read `remote_swelltrack()` and `remote_surfbeat()`. These correctly use `verify=verify_tls` — the pattern to follow.
3. `config/marine_config.py` — read the existing `surf_compute_verify_tls` config field.

**Do:**
1. Add a `verify_tls: bool = True` config option to the `[swan]` section in `marine_config.py`. This follows the same pattern as `surf_compute_verify_tls` in the `[providers]` section.
2. In `configure_remote_mode()`, change the `httpx.get(f"{service_url}/health", timeout=10.0)` call to pass `verify=verify_tls`. The function signature must accept the verify flag.
3. In `_remote_health_loop()`, change all `httpx.get()` calls (health check at line ~843, forecast fetch at line ~867) to pass `verify=verify_tls`. The function signature must accept the verify flag.
4. Wire the config: `run_all_spots()` reads `swan_cfg.verify_tls` and passes it to `configure_remote_mode()`.

**Accept:**
- `configure_remote_mode()` passes `verify=False` when `verify_tls=false` in `api.conf`.
- `_remote_health_loop()` passes `verify=False` for all its HTTP calls.
- The pattern matches `compute_client.py`'s existing `verify=verify_tls` approach.
- No regression when `verify_tls=true` (default) — full cert verification still happens.

### T2.2 — Sync librewxr API repo to current HEAD

- **Owner:** Coordinator (Opus) — with user approval before any SSH commands
- **Files:** API repo on librewxr at `/home/ubuntu/repos/weewx-clearskies-api`

**Do:**
1. Push all local API commits to GitHub (coordinator, with user approval).
2. SSH to librewxr, pull the API repo to current HEAD (`sudo -u ubuntu git pull --ff-only`).
3. Restart the SWAN standalone service (`sudo systemctl restart weewx-clearskies-swan`) so it picks up any code changes.
4. Restart the compute service (`sudo systemctl restart weewx-clearskies-compute`) so it picks up any code changes.
5. Verify both services are running and healthy.

**Accept:**
- librewxr API repo at same commit as origin HEAD (currently 5 commits behind).
- SWAN service on port 8767: healthy, running.
- Compute service on port 8770: healthy, running.

### T2.3 — Configure and verify remote mode activates

- **Owner:** Coordinator (Opus)
- **Files:** `/etc/weewx-clearskies/api.conf` on weewx

**Do:**
1. Add `verify_tls = false` to the `[swan]` section in `api.conf` on weewx. (Self-signed cert on same VLAN — same pattern as `surf_compute_verify_tls = false`.)
2. Deploy the TLS-fixed API to weewx via `scripts/deploy-api.sh`.
3. Check API logs for: `"SWAN: probing remote service at https://192.168.7.22:8767"` followed by `"SWAN remote service reachable"` (not `CERTIFICATE_VERIFY_FAILED`).
4. Verify the remote health thread starts: `"SWAN: remote mode active"`.

**Accept:**
- API logs show remote mode activated successfully.
- No `CERTIFICATE_VERIFY_FAILED` errors.
- Remote health thread is running.

### T2.4 — Verify SWAN forecast data flows from librewxr to API cache

- **Owner:** Coordinator (Opus)

**Do:**
1. Monitor the `_remote_health_loop` in API logs. It should:
   - Call `GET https://192.168.7.22:8767/health` every 60 seconds.
   - Get a 200 response with `last_run` populated.
   - Call `GET https://192.168.7.22:8767/surf/{spot_id}/forecast` for each spot.
   - Store the forecast data in the last-good cache key.
2. After the next SWAN cycle completes on librewxr, verify:
   - `GET /api/v1/surf/huntington-city-beach-pier` returns non-empty `forecast` array.
   - `lastRunTime` is populated (not null).
   - `surfForecastError` is absent or null.

**Accept:**
- Health loop fetches forecast data from librewxr and stores in cache.
- Surf endpoint returns non-empty forecast within one SWAN cycle (~1 hour).

### Adversarial Audit — Phase 2

- **Owner:** `clearskies-auditor`

**Scope:**
1. TLS fix: verify `verify=False` is passed in ALL httpx calls in `swan.py` when `verify_tls=false` — not just `configure_remote_mode` but also `_remote_health_loop` and any other HTTP calls.
2. Config: verify `verify_tls` is read from `api.conf` `[swan]` section, not hardcoded.
3. Default safety: verify `verify_tls` defaults to `True` (not `False`) — self-signed skip is opt-in.
4. No bypass on production: verify that setting `verify_tls=true` still performs full cert verification (no accidental always-skip).
5. Silent deferral scan: grep for `pass`, `TODO`, `FIXME`, hardcoded `verify=False` (should be configurable, not hardcoded) in `swan.py`.

### QC Gate 2

- API connects to librewxr:8767 without TLS errors.
- Remote mode activates (log evidence).
- Health thread running and fetching data.
- `verify_tls` is configurable (not hardcoded).
- Default is `True` (secure default).
- Auditor: zero unresolved findings.

---

## Phase 3 — Fix SWAN Data Caching + End-to-End Verification

**Purpose:** Even with remote mode working, the "1 spot resolved, 0 spots cached" bug reported in the audit may exist on librewxr too. Verify the full pipeline produces data visible on the surf page.

**Scratch file:** `c:\tmp\marine-sep-P3-scratch.md`

### T3.1 — Investigate the "0 spots cached" bug

- **Owner:** `clearskies-api-dev`
- **Files:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py`, `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`

**Reading list:**
1. `providers/nearshore/swan.py` — read `_run_all_spots_locked()` and the cache storage logic. The audit found: "Hourly quick updates: 53 seconds, succeeds (1 spot resolved, 48/48 valid), but **0 spots cached** (handoff bug)."
2. `services/swan_runner.py` — read the spot resolution and cache write code path.
3. `services/transect_handoff.py` — read the SWAN-to-SwellTrack handoff logic.

**Do:**
1. Trace the code path from `_run_all_spots_locked()` through to the cache storage step. Find where the resolved spot's data fails to reach the cache.
2. Identify the specific bug: is it a cache key mismatch, a missing write call, a data format issue, or a handoff failure?
3. Document the root cause and fix.

**Accept:**
- Root cause of "1 spot resolved, 0 spots cached" identified and documented.
- Fix implemented.
- Quick update produces "1 spot resolved, 1 spot cached" (or appropriate count).

### T3.2 — Verify the caching bug scope

- **Owner:** `clearskies-api-dev`

**Do:**
1. Determine whether the "0 spots cached" bug affects only the local weewx code path (bundled SWAN mode) or also the remote librewxr code path.
2. The remote health loop (`_remote_health_loop`) fetches `/surf/{spot_id}/forecast` from librewxr and stores it in the last-good cache. This is a different code path from the bundled SWAN mode cache write. If the remote path works, the bug may be limited to bundled mode.
3. If the bug affects the remote path too, fix it there as well.

**Accept:**
- Clear determination: bug is bundled-only or affects both paths.
- If remote path is affected, fix applied.

### T3.3 — Deploy API to weewx with TLS fix

- **Owner:** Coordinator (Opus) — via `scripts/deploy-api.sh`

**Do:**
1. Deploy the API with all Phase 2 changes (TLS fix, any caching bug fix).
2. Verify health endpoint returns 200.
3. Verify remote mode activates in logs.
4. Verify `GET /api/v1/surf/huntington-city-beach-pier` returns a response (may be empty until SWAN cycle completes).

**Accept:**
- API deployed and healthy.
- Remote mode active.
- No TLS errors in logs.

### T3.4 — Wait for SWAN cycle on librewxr and verify surf data

- **Owner:** Coordinator (Opus)

**Do:**
1. Wait for the next SWAN cycle to complete on librewxr (check health endpoint `last_run`).
2. After cycle completes, verify:
   - `GET /api/v1/surf/huntington-city-beach-pier` returns non-empty `forecast` array.
   - `lastRunTime` is populated.
   - `waveHeight`, `wavePeriod`, `waveDirection` fields are present and non-null.
   - `faceHeight` and `breakPoints` are populated (SwellTrack output).
   - `setTimingMinutes` and `igWaveHeightM` populated if SurfBeat is running.

**Accept:**
- Surf endpoint returns complete forecast data.
- All required fields populated.

### T3.5 — Verify dashboard surf page displays real data

- **Owner:** Coordinator (Opus)

**Do:**
1. Open the dashboard surf page in a browser.
2. Verify: wave height card, conditions card, 72h forecast scroll, beach profile chart all render with real data.
3. Verify attribution reads "SWAN + SwellTrack".
4. Take a screenshot for the execution log.

**Accept:**
- Dashboard surf page shows real data (not empty, not "—", not loading).
- Attribution correct.

### T3.6 — Surfline comparison

- **Owner:** Coordinator (Opus)

**Do:**
1. At the time of the SWAN cycle, check Surfline's reported surf height for Huntington Beach.
2. Compare our face height against Surfline's reported height.
3. Document: our value, Surfline's value, delta, conditions.

**Accept:**
- Face height within ±30% of Surfline's reported value for the first comparison.
- This is an ongoing task: ≥3 comparisons across different conditions within 14 days. This is the one exception to the no-deferral rule — it depends on weather, not work.

### Adversarial Audit — Phase 3

- **Owner:** `clearskies-auditor`

**Scope:**
1. Cache verification: verify the SWAN data is stored in the correct cache key and retrievable by the surf endpoint.
2. Remote health loop: verify it fetches and caches data from all configured spots (not just the first one).
3. End-to-end: verify `GET /api/v1/surf/{id}` returns all expected fields (not null, not degraded).
4. Verify SWAN is NOT running on weewx: `swan.disabled` exists, no SWAN processes, no new SWAN log entries.
5. Verify SWAN IS running on librewxr: health check shows spots, `last_run` populated.
6. Silent deferral scan on all modified files.

### QC Gate 3 (Part A Final)

- Surf endpoint returns non-empty forecast array.
- Beach profile endpoint returns data.
- SurfBeat fields present (set timing, IG wave height) if SurfBeat is enabled.
- Dashboard renders complete surf page with real data.
- Attribution reads "SWAN + SwellTrack".
- SWAN is NOT running on weewx (binary disabled, no SWAN processes, no SWAN log entries).
- SWAN IS running on librewxr (health check, last_run populated).
- API connects to librewxr via remote mode (log evidence).
- Silent deferral scan: zero findings.
- Test baselines recorded as NEW counts (T8.9; they must change — T8.10 adds code).

---

## Part A QA — Short-Term Fix Verification

A comprehensive final verification that the short-term fix works end-to-end. This checklist must be completed before Part B begins.

| Check | Method | Pass criteria |
|---|---|---|
| Surf endpoint returns non-empty forecast | `GET /api/v1/surf/huntington-city-beach-pier` | `forecast` array length > 0 |
| Beach profile returns data | `GET /api/v1/surf/huntington-city-beach-pier/profile` | 200 response with profile data |
| SurfBeat fields present | Inspect surf response | `setTimingMinutes`, `igWaveHeightM` non-null |
| Dashboard renders complete surf page | Visual inspection | All cards, charts, forecast scroll show data |
| Attribution correct | Inspect surf response + dashboard | `nearshoreModel: "SWAN + SwellTrack"` |
| SWAN NOT on weewx | `ssh weewx "ls /usr/local/bin/swan*"` | Only `swan.disabled` exists |
| SWAN NOT on weewx (processes) | `ssh weewx "pgrep -f swan"` | No matches |
| SWAN IS on librewxr | `curl https://192.168.7.22:8767/health -k` | `status: ok`, `last_run` populated |
| API remote mode active | `journalctl -u weewx-clearskies-api \| grep 'remote mode'` | "SWAN: remote mode active" present |
| Silent deferral scan | `grep -rn "TODO\|FIXME\|pass$\|return \[\]\|return None" {modified_files}` | Zero findings in modified files |
| API pytest baseline | Run baseline command | No regression from pre-Phase 1 baseline |

---

## PART B — Marine Service Separation (Phases 4-8)

**Goal:** Build the proper standalone marine service and remove all marine code from the API. The marine service handles everything marine: wave physics (SWAN, SwellTrack, SurfBeat), tides, buoy data, marine weather forecasts, ocean currents, fishing/solunar, beach safety. The API becomes a thin proxy that dynamically mounts marine routes from the service's manifest.

### Target architecture

```
librewxr (or any compute-capable host, or same host as API)
+------------------------------------------------------+
| Marine Service (standalone)                          |
|                                                      |
|  Wave physics:                                       |
|   - SWAN 3-level nested grid (HRRR+GFS wind)        |
|   - SwellTrack per-transect 1D transformation        |
|   - SurfBeat IG strip (set timing)                   |
|                                                      |
|  Marine data providers (same pattern as API):        |
|   - NDBC buoy (spectral, met, water temp)            |
|   - CO-OPS tides (predictions, observations)         |
|   - NWS marine weather (zone forecasts)              |
|   - NWS NWPS surf forecast                           |
|   - WaveWatch III (boundary spectra)                 |
|   - HRRR wind (3 km, 0-48h)                         |
|   - GFS wind (0.25°, 48-72h)                        |
|   - CUDEM bathymetry (NCEI)                          |
|   - OFS ocean currents                               |
|   - ERDDAP ocean data                                |
|                                                      |
|  Enrichment:                                         |
|   - Surf scoring, breaker classification             |
|   - Beach profile blending                           |
|   - Face height calculation                          |
|   - Solunar, beach safety assessments                |
|                                                      |
|  Serves complete marine data via HTTP endpoints      |
|  One port, one health check, one auth token          |
+------------------------------------------------------+
         ↑
         | HTTP (authenticated, TLS)
         ↓
weewx host
+------------------------------------------------------+
| Clear Skies API                                      |
|   - Companion service proxy (generic, reusable)      |
|     Reads marine service /manifest                   |
|     Dynamically mounts /api/v1/surf, /marine, etc.   |
|   - Response envelope wrapping + unit conversion     |
|   - No marine physics code, no SWAN, no marine       |
|     provider modules                                 |
+------------------------------------------------------+
         ↑
         | HTTP (Caddy proxy)
         ↓
+------------------------------------------------------+
| Dashboard (unchanged)                                |
|   - Calls API endpoints as always                    |
|   - Has zero knowledge of the marine service         |
+------------------------------------------------------+
```

### Decisions (from audit brief §11, resolved 2026-07-22)

1. **Repo name:** `weewx-clearskies-marine`. The "marine" name reflects the full scope — tides, buoy data, fishing, beach safety, surf physics — not just SWAN.
2. **Config model:** API pushes config on apply. Wizard and admin talk only to the API. When the operator saves marine config, the API's `/setup/apply` handler pushes the marine config to the marine service's `/config` endpoint. One source of truth, one push path. The marine service never needs `api.conf`.
3. **Alerts stay in the API.** Alerts are a core feature, not a marine extension. Marine alerts (coastal flood, high surf, rip current) are part of the unified alert system regardless of whether the marine service is installed. Alerts never move.

---

## Phase 4A — Fix SwellTrack Pipeline + Vocabulary Unification

**Purpose:** The SwellTrack 1D model has never produced non-zero output in production. The SWAN CURVE fallback silently degrades the surf endpoint — surfers see face heights from a single-point formula, not from the 1D wave transformation model. The beach profile endpoint returns no data. The dashboard has two parallel type systems for the same data with different field names. All of this must be fixed BEFORE code moves to the marine service (Phase 5) — moving broken code produces a broken service.

**Origin (2026-07-23):** Session investigating "Current Swell Conditions" showing "No swell component data available" and "Beach Profile data unavailable" uncovered a chain of failures:

1. SWAN standalone service dropped `spectral` and `transect` from HTTP responses (fixed this session — `fc5680a`)
2. SWAN standalone service lost all data on restart — no disk persistence (fixed this session — `fc5680a`)
3. Beach profile endpoint ran SwellTrack locally instead of via compute service (fixed this session — `099e874`)
4. Beach profile API response field names (`hsEnvelope`, `distance`, `hs`) don't match dashboard types (`transect`, `distanceFromShore`, `waveHeight`) — two parallel type systems for the same data
5. SwellTrack produces zero face height on all 32 transects — spot profile has only 50 points at 50m spacing (should be variable-resolution at 1-5m per SURF-ZONE-MODEL-BRIEF §6.1)
6. Surf endpoint silently falls back to SWAN CURVE K-G/Caldwell formula when SwellTrack returns zero — `degraded=True` but response looks normal with real numbers
7. Surf scorer always uses SWAN CURVE face height, never SwellTrack face height

**Scope extension (2026-07-25) — the L3/1D boundary decisions.** T4A.3.0's reconstruction
work surfaced that the 1D-model introduction changed L3's *alongshore* extent and its
*existence* but never its *cross-shore* extent. L3 therefore still carried the pre-1D
geometry: offshore edge at the 15 m contour, shoreward edge at the shoreline. The operator
resolved this directly rather than through T4A.3.0. Decisions are in **ADR-093 Amendment 2**
and **ADR-095 Amendment 2**; the working-out, including several recorded dead ends, is in
`docs/planning/briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md`.

What changed, and where it lands:

| Decision | Task |
|---|---|
| L3 stops before shore; grid frozen at setup but the handoff cell moves per forecast hour | T4A.9 |
| New silent-failure path from the per-hour handoff needs a runtime assertion | T4A.10 |
| L3 trigger widens to operator classification; viability test with mandatory logging | T4A.11 |
| Supplement 4's topographic multipliers double-count L2's refraction — removed | T4A.12 |
| Two research briefs still describe the pre-1D design | T4A.13 |

T4A.3's L3 sizing steps were rewritten to match and are **no longer blocked**.

**Scratch file:** `c:\tmp\marine-sep-P4A-scratch.md`

### T4A.1 — Unify beach profile vocabulary (API + dashboard)

- **Owner:** `clearskies-api-dev` + `clearskies-dashboard-dev`
- **Files:**
  - API: `endpoints/beach_profile.py`
  - Dashboard: `src/api/types.ts`, `src/components/marine/tabs/BeachProfileChart.tsx`, `HeatMapCard.tsx`, `SurfingTab.tsx`
  - Dashboard: `src/api/openapi-v1.yaml` (add beach profile schemas — currently missing)

**Problem:** Two parallel type families describe the same cross-shore data with different names:

| Concept | `BeachProfileTransectPoint` | `HeatMapEnvelopePoint` | Model (`Analytical1DResult`) |
|---|---|---|---|
| Cross-shore distance | `distanceFromShore` | `distance` | `distances` (array) |
| Water depth | `depth` | `depth` | `depths` (array) |
| Wave height | `waveHeight` | `hs` | `hs_profile` (array) |
| Points array key | `transect` | `hsEnvelope` | — |

**Decision:** Use the model's vocabulary everywhere. The 1D analytical model uses `distance`, `depth`, `hs` — standard oceanographic terms. The API response already uses these names for the `transect_index=all` path. The single-transect response and dashboard types must match.

**Do:**
1. **API `beach_profile.py`:** Response uses `transect` as the array key (both single and all-transect paths). Each point uses `distance`, `depth`, `hs`. Break points use `distance`, `depth`, `hs`, `faceHeight`, `breakerType`. Revert the `distanceFromShore`/`waveHeight` rename from the earlier (wrong) fix in this session.
2. **Dashboard `types.ts`:** Merge `BeachProfileTransectPoint` and `HeatMapEnvelopePoint` into one type using `distance`, `depth`, `hs`. Merge `BeachProfileBreakPoint` and `HeatMapBreakPoint` similarly. `BeachProfileData.transect` and `HeatMapTransectData` both use `transect` as the array key (not `hsEnvelope`). Remove the `HeatMapEnvelopePoint` and `HeatMapBreakPoint` types — they become aliases of the unified types.
3. **Dashboard `BeachProfileChart.tsx`:** Update all field accesses from `p.distanceFromShore` → `p.distance`, `p.waveHeight` → `p.hs`, `bp.distanceFromShore` → `bp.distance`, `bp.waveHeight` → `bp.hs`. (~30 references per the exploration.)
4. **Dashboard `HeatMapCard.tsx`:** Update `row.hsEnvelope` → `row.transect`. Point field accesses (`pt.distance`, `pt.hs`) already use the correct names — no change needed.
5. **Dashboard `SurfingTab.tsx`:** `profileData.transect` is already the correct key — verify it works after the type merge.
6. **OpenAPI spec:** Add beach profile schemas to `openapi-v1.yaml` — currently entirely missing (doc-code sync gap from SURF-1D-IMPLEMENTATION-PLAN Phase 5).

**Accept:**
- One type definition for cross-shore points: `distance`, `depth`, `hs`.
- One array key: `transect` (not `hsEnvelope`).
- API response matches dashboard types for both single-transect and all-transect paths.
- BeachProfileChart renders without errors.
- HeatMapCard renders without errors.
- OpenAPI spec documents the beach profile response.

### T4A.2 — Implement PCHIP variable-resolution profile generation

- **Owner:** `clearskies-api-dev`
- **Files:** `enrichment/bathymetry.py`, new utility function
- **Reference:** SURF-ZONE-MODEL-BRIEF §6.1, API-MANUAL §17 SwellTrack configuration

**Problem:** `download_bidirectional_profile()` produces 50 points at ~50m spacing. At this resolution, the Battjes-Janssen dissipation over-attenuates wave energy and SwellTrack finds zero break points. With 5m interpolation from the same source data, SwellTrack correctly finds 3 break points with physically reasonable face heights (confirmed via direct test on librewxr).

**Do:**
1. Add a `interpolate_profile_pchip()` function that takes a raw CUDEM profile (list of `{distance_m, depth_m}` dicts) and returns a variable-resolution profile:
   - **Fine zone** (shore to `fine_zone_max_depth`): 1–2m dx
   - **Shoaling zone** (`fine_zone_max_depth` to ~15m): 3–5m dx
   - **Approach zone** (>15m): CUDEM native resolution (no interpolation needed)
2. Use `scipy.interpolate.PchipInterpolator` (Piecewise Cubic Hermite Interpolating Polynomial) — preserves sandbar curvature without overshoot artifacts. Deduplicate x-values (distance_m) before fitting — the adaptive refinement path in `bathymetry.py` can produce near-duplicates.
3. **Raw profile extraction at native DEM resolution.** The raw transect profile fed to PCHIP must be sampled at the native CUDEM resolution for that location (~10m at HB where 1/3 arc-second is the finest available, ~3m at locations covered by 1/9 arc-second tiles). Extract directly from the downloaded CUDEM grid — NOT from the 50m bidirectional profile stepper or the resampled L3 cache. PCHIP can interpolate between native samples to create finer grid points, but it cannot recreate features the raw sampling missed.
4. **Fine zone depth threshold** accounts for BOTH breaking physics and structure zones:
   ```
   fine_zone_max_depth = max(1.3 * max_hs_m / gamma, structure_zone_depth)
   ```
   *(Corrected 2026-07-24, coordinator lead call LC-1. This block previously read
   `... + structure_zone_depth`, contradicting the two worked examples below it,
   this task's own Accept bullet, and QC Gate 4A — all of which use `max()`. The
   two terms are independently-derived depths for the same zone, not additive
   contributions; addition would put Newport's fine zone at 17.1 m instead of
   10.0 m. `SURF-ZONE-MODEL-BRIEF.md` §6.1 carries the older pre-1.3-margin form
   and is superseded by this one.)*
   - `1.3 * max_hs_m / gamma`: maximum breaking depth with shoaling margin. Shoaling amplifies Hs before breaking (the model's own jacking factor), so a 4m offshore swell can break at ~7m depth, not 5.5m. The 1.3× margin is cheap (adds a few hundred fine-zone points) and prevents break points landing in the coarse zone during big swells — when accuracy matters most.
   - `structure_zone_depth`: the depth of the deepest structure affecting this spot, plus margin. **Default 0.0** when no structures configured — fine zone covers only the breaking zone. When an offshore breakwater sits at 8m depth: `structure_zone_depth = 10.0` (structure depth + 2m margin), extending the fine zone to cover structure interactions.
   - Example: HB, no structures, 4m max Hs → `fine_zone_max_depth = max(1.3 * 5.5, 0) = 7.1m`.
   - Example: Newport, breakwater at 8m, 4m max Hs → `fine_zone_max_depth = max(7.1, 10.0) = 10.0m`.
5. `max_hs_m` defaults to 4.0m. Per-spot configurable via `SurfSpotConfig.max_hs_m`.
6. `structure_zone_depth` is computed from the spot's structure config: deepest structure depth + margin. 0.0 when no structures. Required parameter (no default that silently extends the fine zone).
7. The function signature: `interpolate_profile_pchip(raw_profile, max_hs_m, gamma, structure_zone_depth=0.0) -> list[dict]`.

**Accept:**
- Raw profile extracted at native DEM resolution (~10m at HB, ~3m where 1/9 arc-second available).
- Fine zone extends to `max(1.3 * max_hs_m / gamma, structure_zone_depth)` — covers breaking zone with shoaling margin + structure zone when applicable.
- A spot with no structures gets fine resolution only through the surf zone — no wasteful 1-2m dx through the entire shoaling zone.
- A spot with an offshore breakwater at 8m depth gets fine resolution to ~10m depth.
- Per-zone dx bounds verified: fine zone ≤ 2m, shoaling zone 3-5m, approach zone ≥ native DEM resolution.
- `run_1d_analytical()` with the interpolated profile finds ≥1 break point with non-zero face height for 1.0m Hs / 10.3s Tp input.
- No phantom bars or troughs in the interpolated profile (PCHIP monotonicity-preserving).
- No duplicate x-values passed to PchipInterpolator.

### T4A.2b — Fix Battjes-Janssen forward-marching energy integration

- **Owner:** `clearskies-api-dev`
- **Files:** `services/surf_1d_analytical.py`

**Problem:** `_battjes_janssen()` (lines 153-177) computes dissipation at each grid point independently — each point starts from its own shoaled Hs and subtracts one step of dissipation. The wave doesn't "remember" energy lost at previous points. Consequence: dissipation scales linearly with dx. At 50m dx, one step wipes out the wave. At 2m dx, each step removes almost nothing, and the model degenerates to the `Hs = min(Hs, gamma * d)` depth-limited cap at line 484. Break point detection still works at fine resolution (the gamma×d crossing is the correct criterion), but the post-breaking energy decay in the surf zone is just the depth contour × gamma — not real physics.

The `_roller_model()` (lines 180-216) IS correctly forward-marching (`Er` accumulates from point to point), but it operates on the incorrectly-computed B-J output.

**Do:**
1. Convert `_battjes_janssen()` from vectorized-independent to a forward-marching loop. At each point i, compute Hs[i] from the energy flux arriving from point i-1 minus the dissipation at point i. Pattern matches `_roller_model` which already does this correctly:
   ```python
   for i in range(1, n):
       # Energy arriving from previous point (with shoaling)
       E_in = 0.125 * rho * g * Hs[i]**2  # Hs[i] has shoaling applied
       # B-J dissipation at this point
       Hmax = gamma * d[i]
       Qb = ...  # fraction breaking, from Hs[i-1] or Hs[i]
       Dtot = alpha * Qb * rho * g * (Hmax/sqrt(2))**2 / (4*T)
       # Subtract dissipation over this step
       E_out = max(E_in - Dtot * abs(dx[i]) / Cg[i], 0.0)
       Hs[i] = sqrt(8 * E_out / (rho * g))
   ```
2. The `_bottom_friction()` function already uses `np.cumsum` for accumulated friction — use the same forward-marching pattern for B-J.
3. After this fix, the post-breaking Hs envelope shows realistic energy decay: rapid dissipation at the break point, gradual decay through the surf zone, potential reformation in troughs between bars. This is what the beach profile chart renders.
4. Run the existing test suite and Surfline comparison to validate that break point locations and face heights remain physically reasonable (they should — the gamma×d crossing criterion is unchanged; only the post-breaking decay shape changes).

**Accept:**
- `_battjes_janssen()` is forward-marching: `Hs[i]` depends on `Hs[i-1]`.
- Post-breaking Hs decay is physically realistic (not just `gamma * depth`).
- Break points at the same locations as before (gamma×d crossing unchanged).
- Multi-bar profiles show reformation between bars (Hs recovers in troughs).
- Existing tests pass.

### T4A.3.0 — RECONSTRUCT: what the 1D-model introduction was supposed to change vs what was actually coded

- **Owner:** `clearskies-api-dev` (research + written diff only — NO code changes)
- **Added:** 2026-07-25 by operator direction.
- **SCOPE REDUCED 2026-07-25, and no longer blocks T4A.3.** The boundary questions this task
  was created to surface were resolved directly with the operator — see ADR-093 Amendment 2,
  ADR-095 Amendment 2, and `briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md`. L3 extent, handoff
  depth selection, the L3 trigger, and SPECOUT placement are **settled — do not re-derive
  them.** What remains in scope: the intended-vs-actual diff for the SWAN-side changes this
  task has not already covered (CURVE role, SurfBeat strip domain, per-level bathymetry), and
  the full inventory of governing-document statements still describing the pre-1D design
  beyond the ones already corrected.

**Why this exists.** The operator identified that the introduction of the dual 1D
models (SwellTrack analytical + SWAN SurfBeat strip) was **half-implemented**. The
1D models were built, but the SWAN-side consequences were never carried through,
and the governing documents still describe the pre-1D architecture. This is the
same half-implementation / silent-deferral failure the NO DEFERRAL RULE at the top
of this plan exists to prevent — so it is remediated, not worked around.

**The operator's statement of intent (2026-07-25):**

> SWAN fell short as a real wave model — that is why the dual 1D models exist.
> The SWAN SurfBeat and the SwellTrack analytical models should be modelling
> **from the end of the L3 grid to shore**. There SHOULD still be an L3 grid —
> it is not just L1/L2 straight to the 1D models — but L3 may only be needed
> **when there are obstacles**.

So: **L3 does not run to shore, and L3 is not sized to a fixed 15 m contour.**
Both of those are pre-1D assumptions still written into the docs and the code.

**Known contradictions already located (starting point, not the full list):**

| Doc | Line | Says | Status |
|---|---|---|---|
> **Table status 2026-07-25:** `ARCHITECTURE.md` 98, this plan's T4A.3, PROVIDER-MANUAL
> §14.15 and API-MANUAL §17 have been corrected per ADR-093 Amendment 2 / ADR-095
> Amendment 2. The three brief-level rows below are NOT yet corrected and remain live
> work for this task.

| `ARCHITECTURE.md` | 98 | L3 "extending 250 m each side of the pin cluster **from shore to 15 m depth**" | ~~STALE (pre-1D)~~ **CORRECTED 2026-07-25** |
| `ARCHITECTURE.md` | 114 | "L3 **optional** per location (auto-detected from structures). L3 smart-sized around structure clusters (**not entire beach**)" | Correct — **contradicts line 98** |
| `SURF-ZONE-MODEL-BRIEF.md` | 371 | "**SWAN L3 runs to shore** (current architecture, no changes)." | **STALE (pre-1D)** |
| `SURF-ZONE-MODEL-BRIEF.md` | 578 | "The 1D model **replaces SWAN L3** for the final leg of wave transformation." | Correct |
| `SURF-ZONE-MODEL-BRIEF.md` | 668 | "SWAN L3's value in the nearshore is the **2D spatial wave energy field** — structure interaction and bathymetric refraction, not wave height accuracy." | Correct |
| `SURF-ZONE-MODEL-BRIEF.md` | 225 | "At 15 m depth (open beaches), the handoff sits at L3's offshore boundary — L3 has not added independent computation at its own edge." | Correct |
| This plan, T4A.3 | 791, 797, 825, 838 | "L3: per-cluster, **shore → max(15 m contour, deepest structure + margin)**" | **STALE (pre-1D)** |

Code state: the *conditional-L3* half IS implemented — `l3_enabled`
(`auto`/`on`/`off`) exists in `marine_config.py` (~438, ~495) and
`endpoints/setup.py` (~495), and `compute_domains()` honours it (`swan_domain.py`
~170). The *L3-extent* half is NOT — sizing still targets the 15 m contour with a
2.5 km fallback.

**Do (research and write-up only — do not modify any source file):**
1. Read `docs/planning/SURF-1D-IMPLEMENTATION-PLAN.md` (and its archived form if
   it has moved) in full, plus `SURF-ZONE-MODEL-BRIEF.md`,
   `SWAN-L3-STABILITY-BRIEF.md`, `SWAN-NESTING-RESEARCH-BRIEF.md`,
   `1D-MODEL-BENCHMARK-BRIEF.md`, and ADR-093 / ADR-095 / ADR-096 / ADR-097.
2. Produce an **intended-vs-actual table** covering every SWAN-side change the 1D
   introduction implied: L3 extent, L3 conditionality, handoff depth selection,
   CURVE transect role, SPECOUT placement, what SurfBeat's strip domain should
   span, and the per-level bathymetry each of those needs.
3. For each row: what the plan/brief/ADR said should happen, what the code
   actually does today (cite file and line), and whether the gap is a silent
   deferral, a partial implementation, or an intentional deviation.
4. List every governing-document statement that must change, with its exact
   location.
5. Surface the open questions the documents do **not** settle.
   **PARTIALLY ANSWERED 2026-07-25 — do not re-litigate these two:**
   - *What determines L3's shoreward boundary?* The SWAN→SwellTrack handoff
     surface: breaking-onset contour `max(1.3 * max_hs_m / gamma, 5.0)`
     displaced seaward by a buffer distance. ADR-093 Amendment 2. The buffer
     magnitude (N wavelengths) remains open and is the one live sub-question.
   - *What determines the handoff when there is no L3?* L2's ~15 m deep-water
     reference — unchanged from ADR-093 Amendment 1, and now the majority case
     because of the L3 viability test.
   Still open and in scope for this task: whether L3's **offshore** edge should
   remain the 15 m contour now that L3's job has narrowed to structure
   interaction (brief D1), and the 10 m vs 15 m handoff inconsistency between
   SURF-ZONE-MODEL-BRIEF §2.3.4 and ADR-093 Amendment 1 (brief D3).

**Accept:**
- A written intended-vs-actual diff delivered to the coordinator, every row
  citing file + line for the "actual" column.
- An explicit list of stale statements in `ARCHITECTURE.md`, this plan, and the
  briefs.
- The open questions surfaced to the operator, unanswered — this task does not
  resolve architecture, it establishes the ground truth for a decision.
- **Zero source files modified.**

**Then, and only then:** the operator decides the target L3 model, the coordinator
rewrites T4A.3's grid-sizing steps to match, and implementation starts.

### T4A.3 — Move CUDEM download to apply time

- **Owner:** `clearskies-api-dev`
- **Files:** `endpoints/setup.py`, `enrichment/bathymetry.py`, `providers/nearshore/swan.py`, `services/swan_domain.py`

**Problem:** The CUDEM download → depth contour identification → L1/L2/L3 grid sizing → profile generation chain currently runs at SWAN runtime inside `_run_all_spots_locked()` (swan.py). This chain already works — grid boundaries are set from actual depth contours. But running at runtime means the first SWAN run takes an extra 5-10 minutes, and the profile generation step (currently producing broken 50-point profiles) is invisible to the operator.

**What changes:** Move the existing chain from runtime to apply time. Same logic, different trigger. The only new code is the PCHIP variable-resolution profile interpolation (T4A.2) — everything else is re-wiring existing functions to run from `/setup/apply` instead of from the SWAN cache warmer.

**Critical constraint:** CUDEM download must wait until ALL surf spots are defined (not per-spot), because the unified bounding box from all spots defines the L1 and L2 SWAN grids. The download is triggered at apply time, after all segments are confirmed.

**Current state of grid sizing (verified 2026-07-23):**
- L1: Uses GSFM shelf boundary distance (static data) — correct, no CUDEM needed.
- L2: **Hardcoded 6km offshore** (`_compute_level2`, swan_domain.py line 291: `offshore_km = 6.0`). The `offshore_depth_m=30.0` parameter is accepted but never used to find the actual 30m contour. This is wrong — 6km is a guess that varies wildly by coast (steep Pacific shelf vs gentle Gulf shelf).
- L3: Reads `offshore_distance_m` from the cached bidirectional CUDEM profile — distance to the 15m contour. This is CUDEM-dependent and correct in principle, but reads from the broken 50-point profile. Falls back to 2.5km when no profile exists (swan_domain.py line 582).

**Correct dependency chain (L1 triggers CUDEM download, L2/L3 sized from actual depth data):**

```
1. All spots defined (wizard complete)
      ↓
2. Size L1 grid from GSFM shelf boundary (static data, no CUDEM needed)
   - L1 (1km): GSFM shelf edge + 15km margin → shore
   - L1 bounding box = the CUDEM download area
      ↓
3. COARSE download: CUDEM at L1 resolution (1km) for L1 bounding box
   - CRM/DEM_all (~90m) is sufficient at this resolution
   - Purpose: locate depth contours for L2/L3 sizing
      ↓
4. Size L2 from actual 30m depth contour (FIX: replaces hardcoded 6km)
   - Search along EACH spot's offshore bearing (not averaged) — a single
     averaged transect through a submarine canyon (e.g. Newport Canyon)
     would place the 30m contour at the wrong distance
   - Take the MAX distance across all spots
   - L2 (100m): shore → actual 30m contour + margin
      ↓
5. MEDIUM download: CUDEM at L2 resolution (100m) for L2 bounding box
   - CUDEM 1/3 arc-second (~10m) covers this range at most US coasts
      ↓
6. Size L3 — **AMENDED 2026-07-25 per ADR-093 Amendment 2. L3 does NOT run to shore,
   and the handoff is NOT a fixed depth.**
   - Trigger: manmade structure discovered **OR** operator classified the spot as
     point break / headland / bay break. (Structure-only was the old trigger and
     could never enable L3 at a point break.)
   - Offshore edge: actual 15m depth contour (FIX: replaces 2.5km fallback)
   - **Shoreward edge:** size the grid to reach as far shoreward as it is EVER
     useful — the SHALLOW end of the year's breaking range, not the deep end.
     Small-swell days break shallow. Do NOT freeze the edge at
     `1.3 * max_hs_m / gamma`; that is the largest-swell breaking depth and
     using it as the handoff was the error corrected on 2026-07-25.
   - **The handoff itself is per forecast hour, not per setup:**
     `handoff_depth(hour) = 1.3 * Hs(hour) / gamma` — a 30% margin seaward of
     that hour's breaking depth. Read the spectrum from whichever cell that
     lands in. Grid geometry stays frozen at setup; only the sampled cell moves.
     Grid shoreward reach = the smallest value that expression ever produces for
     this spot (at HB, ~1.8 m — which spans the pier end to end).
   - **Then run the L3 viability test:** if the grid cannot reach the feature it
     exists for (structure or headland), DISABLE L3 for the cluster and **log
     which feature was unreachable and by how much.** Trigger is necessary, not
     sufficient. HB Pier's status is UNDETERMINED pending the margin decision —
     the earlier "HB fails" conclusion followed from the frozen-handoff error.
   - Setup-time calculation scope: depth-based only (contour positions, slope,
     breaking depths, spans, extents, relief). NO contour curvature, orientation
     variation, or automatic break-type detection.
   - Compute structure_zone_depth per spot (deepest structure depth + margin, 0 without structures)
   - Note: `structure_zone_depth` feeds SwellTrack's fine-zone sizing only
     (step 9). It can deepen the fine zone; it can never move the handoff.
      ↓
7. FINE download: CUDEM at L3 resolution (10m) for each L3 cluster bbox
   - CUDEM 1/9 arc-second (~3m) where available; 1/3 arc-second (~10m) elsewhere
      ↓  [NEW: T4A.2 PCHIP interpolation — replaces the broken 50-point profile]
8. Extract raw transect profiles from FINE download at native DEM resolution
   - Sample at ~10m (1/3 arc-sec) or ~3m (1/9 arc-sec) depending on coverage
      ↓
9. Generate per-transect variable-resolution profiles:
   - fine_zone_max_depth = max(1.3 * max_hs_m / gamma, structure_zone_depth)
   - PCHIP interpolation per T4A.2 spec
      ↓
10. Cache everything:
    - L1/L2/L3 CUDEM grids at per-level resolution
    - Per-spot profile JSON with variable resolution + vertical datum metadata
    - Grid boundary metadata (actual depth contour positions, extents)
```

**Do:**
1. In `/setup/apply` handler: after writing marine config to `api.conf`, size the L1 grid from GSFM shelf boundary data (`data/gsfm_shelf_boundary.json`, static). L1 bounding box = the download area (all spots, GSFM shelf distance + 15km margin).
2. Download CUDEM data in resolution tiers matching each grid level — CUDEM coverage at 1/9 arc-second (~3m) is nearshore only; the outer shelf covered by L1 may only have 1/3 arc-second (~10m) or CRM (~90m). Download strategy:
   - **L1 area** (full shelf): download at L1's native 1km resolution. CRM/DEM_all fallback is acceptable here — L1 doesn't need fine bathymetry.
   - **L2 area** (shore to ~30m): download at 100m resolution. CUDEM 1/3 arc-second (~10m) covers this range at most US coasts.
   - **L3 area** (shore to ~15m): download at 10m resolution. CUDEM 1/9 arc-second (~3m) covers the nearshore zone where it matters most.
   - Use `download_swan_depth_grid()` with the appropriate bbox and resolution per level. The existing DEM priority chain (operator GeoTIFF → regional OPeNDAP → Great Lakes → CRM fallback) handles coverage gaps.
   - Depth contour identification (steps 3-4) uses the finest available data for each contour's depth range.
3. **Fix L2 grid sizing** (`_compute_level2` in `swan_domain.py`): replace the hardcoded `offshore_km = 6.0` with actual 30m depth contour identification from the downloaded CUDEM grid. Find the geographic position where depth reaches 30m along the offshore bearing. This distance varies by coast — the current 6km guess is wrong for steep Pacific shelves (~2km to 30m) and gentle Gulf shelves (~30km to 30m).
4. **Fix L3 grid sizing** (`_compute_level3_cluster` in `swan_domain.py`) — **AMENDED 2026-07-25, ADR-093 Amendment 2.** L3 is bounded on BOTH cross-shore sides now.
   - *Offshore edge:* replace the 2.5km fallback with actual 15m depth contour identification from the downloaded CUDEM grid. `offshore_distance_m` comes directly from the CUDEM grid query — not from the broken 50-point spot profile.
   - *Shoreward edge:* size to the SHALLOW end of the year's breaking range — the smallest value `1.3 * Hs / gamma` ever produces for this spot. Do NOT freeze the edge at `1.3 * max_hs_m / gamma`; that is the largest-swell breaking depth, and using it as the handoff was the 2026-07-25 error. See ADR-093 Amendment 2 §2.
   - *Handoff is per forecast hour:* `handoff_depth(hour) = 1.3 * Hs(hour) / gamma` — 30% margin seaward of that hour's breaking depth. Sample the spectrum from whichever cell that lands in. Grid geometry stays frozen at setup; only the sampled cell moves. This does not violate the "grid geometry fixed at setup" rule — no bbox, extent, or resolution changes at runtime.
   - *Trigger:* manmade structure discovered **OR** operator classification of point break / headland / bay break.
   - *Viability test:* after sizing, verify the grid reaches the feature it exists for. If it does not, set `grid=None` for the cluster (L3 disabled) and **log at INFO which feature was unreachable and by how much** — a too-shallow grid announces itself at runtime, a too-seaward one is silently indistinguishable from "nothing to model." Same disposition as `l3_enabled="off"`, reached by computation rather than config.
   - *The handoff is a depth contour; the grid is a rectangle.* The shoreward edge must reach the landward-most excursion of the handoff contour across the cluster's transects.
   - *The previous instruction — "extend to `max(15m contour, deepest structure depth + margin)`" — is void.* It sized L3 by structure depth, which cannot override the depth at which SWAN stops being reliable. A pier reaching the beach does not make SWAN accurate at the beach.
5. Compute `structure_zone_depth` per spot — deepest structure depth + margin, or 0.0 when no structures configured.
6. For each surf spot: extract raw cross-shore profiles along each transect bearing from the FINE download at the DEM's native resolution (~10m at HB, ~3m where 1/9 arc-second available). Then interpolate to variable resolution via `interpolate_profile_pchip(raw_profile, max_hs_m, gamma, structure_zone_depth)` (T4A.2).
7. Contour search uses each spot's own offshore bearing (not an averaged bearing) — a single averaged transect through a submarine canyon (e.g. Newport Canyon) would mislocate the depth contour. Take the max distance across all spots for the grid boundary.
8. Store all outputs:
   - Per-level CUDEM grids: `swan_bathymetry_L1.json` (1km), `swan_bathymetry_L2.json` (100m), `swan_bathymetry_L3_{hash}.json` (10m per cluster) — same cache paths SWAN already reads.
   - Per-spot profiles: `/etc/weewx-clearskies/spot_profiles/{spot_id}.json` with variable dx. Include metadata: `structure_zone_depth`, `fine_zone_max_depth`, `max_hs_m`, `gamma`, actual depth contour positions (30m and 15m), **vertical datum** (required for the datum consistency check mandated by SURF-ZONE-MODEL-BRIEF §6), generation timestamp.
   - Grid boundary metadata: L1/L2/L3 extents with actual depth contour positions — SWAN reads these to configure its grid domains. No hardcoded distance fallbacks.
9. Remove the CUDEM download and grid sizing from `_run_all_spots_locked()` in `swan.py` — SWAN reads from pre-computed caches only. If caches are missing (operator never ran apply), SWAN logs ERROR and skips the run. No silent fallback to runtime download or hardcoded distances.
10. Admin save and re-apply re-trigger the full chain for any changed spots. Structure changes (adding/removing/moving a structure) also re-trigger because they affect L3 sizing and `structure_zone_depth`. Location coordinate changes re-trigger because they affect the bounding box and depth contour positions.
11. Add `max_hs_m: float = 4.0` to `SurfSpotConfig` in `marine_config.py`. Passed to profile generation for depth zone computation.

**Accept:**
- `/setup/apply` executes the full dependency chain: L1 sizing → coarse download → L2 from actual 30m contour → medium download → L3 from actual 15m contour → fine download → profile generation (progress visible to operator).
- L2 grid boundary set from actual 30m depth contour — not hardcoded 6km.
- L3 offshore boundary set from actual 15m depth contour — not 2.5km fallback.
- **L3 does not reach shore**, and its shoreward edge is sized to the shallow end of the breaking range — not frozen at the largest-swell breaking depth.
- **The handoff is computed per forecast hour** from that hour's breaking depth, sampled just seaward of it. Grid geometry is unchanged at runtime.
- **L3 viability test runs and is honoured:** a cluster whose grid cannot reach the feature it exists for has L3 disabled, with an INFO log naming what was unreachable and by how much. HB Pier's disposition is whatever the test returns — do not hard-code it either way.
- **L3 enables on structures OR operator classification** (point break / headland / bay break), not structures alone.
- **Supplement 4's topographic multipliers are gone** from `wave_transform.py`; the operator's classification now feeds the L3 trigger instead.
- No SPECOUT is extracted at an L3 boundary cell (ADR-095 Amendment 2).
- Contour search per-spot-bearing with max distance (not single averaged transect).
- Raw profiles extracted at native DEM resolution.
- Profiles are variable-resolution per T4A.2 spec, with fine zone extending to `max(1.3 * max_hs_m / gamma, structure_zone_depth)`.
- Profile metadata includes vertical datum.
- SWAN runtime reads from cached grids, profiles, and boundary metadata — zero CUDEM downloads, zero grid sizing, zero hardcoded distance guesses at runtime.
- Missing caches produce an explicit error, not a silent degradation.
- Admin location or structure changes re-trigger the full chain.

### T4A.4 — Remove SWAN CURVE fallback from surf endpoint

- **Owner:** `clearskies-api-dev`
- **Files:** `endpoints/surf.py`

**Problem:** The surf endpoint has a two-phase write pattern. Phase 1 (lines 890-1083) always computes SWAN CURVE K-G/Caldwell face heights. Phase 2 (lines 1136-1181) conditionally overrides with SwellTrack results. When SwellTrack returns zero face height (`_1d_face_m == 0.0`), the `else` branch at line 1172 silently keeps the SWAN CURVE values and sets `degraded=True`. The result: the response contains real-looking numbers that came from a single-point formula approximation, not from the 1D wave transformation model. There is no way for the consumer to distinguish "SwellTrack produced this" from "SWAN CURVE produced this as a silent fallback."

Additionally, `score_surf()` (line 1050) always uses SWAN CURVE `face_height_m`, never the SwellTrack face height. The quality score is always based on the formula approximation.

**Deployment constraint:** T4A.4 and T4A.5 MUST deploy together (or T4A.5 first). Removing the fallback before SwellTrack produces non-zero output = the surf page shows zeros for every timestep. Verify SwellTrack output is non-zero in production BEFORE the fallback removal goes live.

**Do:**
1. Remove Phase 1 SWAN CURVE face height computation. The 1D pipeline is the sole source of breaking wave heights.
2. Remove the `else` fallback branch at line 1172. Distinguish two cases:
   - **Model ran, genuinely no breaking** (e.g., flat conditions, Hs below 0.15m threshold): `breakingFaceHeight = 0.0`, `modelStatus = "no_breaking"`. This is a valid physical result — surfers see flat water.
   - **Model failed** (exception at line 1035, missing profile, pipeline returned None): `breakingFaceHeight = null`, `modelStatus = "unavailable"`. This is a failure — the dashboard shows "Surf forecast unavailable," not a confident "flat" rating.
   - Add `modelStatus` field to `SurfForecast` response: `"ok"`, `"no_breaking"`, `"unavailable"`, `"degraded_bulk"`. Replaces the boolean `degraded` flag which can't distinguish these cases.
3. Change `score_surf()` to use SwellTrack `best_peak_face_height_m` instead of SWAN CURVE `face_height_m`. When face height is null (model failure), the scorer returns null quality score — no rating. When face height is 0.0 (genuinely flat), the scorer rates it as "Flat" / 0 stars.
4. Recompute `breakingHawaiianHeight` from the SwellTrack face height (`best_peak_face_height_m * 0.5`), not from the removed Phase 1 CURVE value.
5. Keep `swellHeight` from SWAN SPECOUT (deep-water swell) — this is a display value showing what's arriving offshore, not a breaking height.
6. Keep SWAN TABLE `HSIGN`, `TM01`, `DIR` for the scorer's period and direction inputs — those don't change between SWAN CURVE and SwellTrack.
7. The `degraded` field is replaced by `modelStatus` (see step 2). `modelStatus = "degraded_bulk"` covers the T4.5 case (SPECOUT unavailable, bulk Hs/Tp/Dir used). `modelStatus = "ok"` when full spectral pipeline ran.

**Accept:**
- No SWAN CURVE face height computation in the surf endpoint.
- `breakingFaceHeight`: SwellTrack value, 0.0 for flat, null for model failure — never a formula guess.
- `breakingHawaiianHeight`: derived from SwellTrack face height.
- `modelStatus` distinguishes ok / no_breaking / unavailable / degraded_bulk.
- `score_surf()` scores SwellTrack face height. Returns null on model failure (not a confident "flat" rating).
- No silent degradation — failure is visible as null + "unavailable", not masked by formula values.
- T4A.5 deploys BEFORE or WITH T4A.4 — never after.

### T4A.5 — Regenerate spot profiles on librewxr

- **Owner:** Coordinator (Opus) — with user approval
- **Files:** `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` on librewxr

**Do:**
1. Run the new `interpolate_profile_pchip()` function on librewxr against the existing CUDEM data for Huntington Beach.
2. Regenerate the spot profile at variable resolution.
3. Restart the SWAN standalone service and compute service to pick up the new profile.
4. Verify: `run_1d_analytical()` with the new profile produces non-zero break points.
5. Verify: the surf endpoint returns `degraded=false` and face heights from SwellTrack (not SWAN CURVE).

**Accept:**
- Spot profile has ~400-500 points (variable resolution).
- SwellTrack produces non-zero face heights.
- Surf endpoint: `degraded=false`, `breakingFaceHeight` from SwellTrack.
- Beach profile endpoint returns full transect data.

**RESULT — run 2026-07-25 on librewxr.** Ran the real `_run_marine_apply_chain()`, not a
reimplementation, so what landed is exactly what the wizard writes.

| Accept criterion | Outcome |
|---|---|
| Profile ~400–500 points, variable resolution | **629 points, uniform 1.5 m spacing.** Deviation — see below. |
| SwellTrack produces non-zero face heights | **PASS.** Non-zero breaking heights at Hs = 1/2/3/4 m; surf zone widens 72 m → 188 m, breaks move offshore 103 m → 219 m, breaking depths 2.16 m → 4.93 m, runtime 14–17 ms. |
| Surf endpoint not degraded, heights from SwellTrack | **PASS.** `nearshoreModel: "SWAN + SwellTrack"`, `modelStatus` 66 × `ok` + 1 × `no_breaking` (hour 0 is genuinely flat — 1.6 s period wind chop), face heights max 5.19 m / mean 4.03 m. Note the response has no `degraded` field; `modelStatus` is the live equivalent and the criterion's field name is stale. |
| Beach profile endpoint returns full transect data | **PASS.** `transectCount: 32`, `openTransectCount: 32`, break points carrying distance/depth/hs. |

**Chain output, for the record:** 30 m contour at 6017 m; 15 m at 2433 m; **1.8 m at 85 m**.
L3 sized with "struct 567 m (alongshore extent only, Amendment 1 §2), shoreward reach 85 m
(breaking-depth criterion, Amendment 2 §2)" — the two mechanisms correctly separate. Profile:
629 points, datum NAVD88, `structure_zone_depth` 12.3 m, `fine_zone_max_depth` 12.3 m.

**This also settles ADR-093 Amendment 2 §5 — HB Pier is VIABLE.** The amendment left its status
"UNDETERMINED, pending the margin decision" and predicted "a grid reaching ~2 m depth would span
the pier end to end." The grid reaches 1.8 m at 85 m offshore, the viability test passed, and
L3 is enabled: `1 of 1 cluster(s) enabled`.

**Two recorded deviations — neither blocking, both real:**

1. **Uniform 1.5 m spacing, not variable, and 629 points not ~400–500.** Cause is arithmetic,
   not a defect: `fine_zone_max_depth` is 12.3 m (driven by `structure_zone_depth`) while the
   profile's deepest sample is 10.2 m, so the *entire* profile lies inside the fine zone and the
   coarse zone never begins. Correct by construction given the inputs. Worth noting that the
   criterion "~400–500 points (variable resolution)" was written before `structure_zone_depth`
   entered the fine-zone formula and no longer describes the reachable outcome here.
2. **The source DEM has no sandbar field — one cause, three symptoms.** Measured, not inferred:

   | Profile | Sampling | Local depth minima (bar crests) |
   |---|---|---|
   | Raw NCEI CUDEM `orange_county_13_navd88_2015.nc` (L3 fine) | 8.57 m native | **1** — 7 cm relief at 6.9 m depth (noise, outside the surf zone) |
   | Interpolated profile written to cache | 1.5 m | **1** — 5 mm relief, same location |

   At 8.6 m sampling a 30–50 m sandbar would span 4–6 samples and be plainly resolvable. It is
   not there. The surf zone (0–250 m, 0–5.6 m depth) is a smooth monotonic ramp at ~1:50.
   **PCHIP is not the cause** — the interpolation faithfully reproduces a smooth slope because
   the source is a smooth slope. Expected for CUDEM: surf-zone cells are interpolated between
   topographic LiDAR (dry beach) and offshore bathymetry, and the bar field sits in that seam;
   it is also a 2015 composite, and bars migrate seasonally.

   Three things first recorded as separate observations are this one finding:
   - **Zero jacking factors.** `_compute_jacking()` requires a strict local depth minimum
     (`depths[i] < depths[i±1]`). There is none, so T4A.6 item (b)'s jacking annotations do not
     render at HB with real data. This is the audit's A8 concern made concrete — B3 hand-added a
     jacking value during T4A.6 because a real sweep stayed below the render threshold.
   - **Every breaker classifies `spilling`; no plunging at any swell 1–4 m.** Plunging needs a
     steep bar face; on a 1:50 plane slope the Iribarren number stays low everywhere.
   - **Break points smear** across 40–219 m as a continuous dissipation ramp rather than
     concentrating at a bar crest.

   Face heights are probably under-predicted at the peak, since bar-crest amplification is what
   the jacking factor represents — **inference from the physics, not measured.**

   **Operator ruling 2026-07-25: accept and note.** No code fix can recover bars absent from the
   source data, and no better bathymetry is available for this coast. Do NOT change the
   bathymetry source, add a bar parameterisation, or loosen the `is_bar` test to make the feature
   appear to work. Recorded as working to the best of available knowledge. Future path:
   satellite-derived bathymetry — see [FUTURE-ENHANCEMENTS.md](FUTURE-ENHANCEMENTS.md).

**FINDING — the handoff clamped on all 73 timesteps, and station spacing is why.** The full run
(2026-07-25 07:06Z, 1200 s, `73/73 timestep(s) resolved a per-hour L3 station`) clamped every
single hour. Target depths were 0.02–1.37 m (Hs 0.01–0.77 m); the transect's two shallowest
stations are **0.98 m** (the grid boundary, excluded by design) and **2.37 m**, with nothing
between, so every target in that gap pinned to 2.37 m with a WARNING.

Consequence: the handoff sits at roughly **2.25× the breaking depth instead of the intended
1.3×** — systematically too deep, on every hour. The grid was sized to reach the 1.8 m contour at
85 m, but **station placement along the transect is too coarse to sample there**, so grid sizing
and station density are not consistent with each other.

> **This is NOT a small-conditions artefact — an earlier draft of this block said it was, and
> that was wrong.** Conditions during this run were good: Surfline reported **4–6 ft, chest to
> overhead**, with an active Beach Hazards Statement for high surf. The clamp fires in ordinary
> rideable surf, not marginal seas. The mistaken "flat conditions" reading is recorded here
> because it nearly buried a real finding behind a false explanation.

**Not urgent, and deliberately not tuned here.** Face heights independently agree with Surfline
(our max **5.93 ft** / mean 4.24 ft against their 4–6 ft), so SwellTrack absorbs the longer leg
without visible error. Station density is a sampling choice adjacent to trigger 3, and **T8.7
(Surfline comparison)** already exists as the plan's task for handoff-accuracy tuning against
more than one afternoon of data. Routed there.

> **A structural tension in the ADR's rule, surfaced not resolved.** Amendment 2 §2 says to size
> the grid to "the smallest value [`1.3 × Hs(hour) / gamma`] ever produces for this spot's
> conditions." That expression is unbounded below — as Hs → 0 the handoff depth → 0 and the grid
> would run to the shoreline, which §1 forbids outright. A floor is therefore structurally
> necessary, and `_MIN_DESIGN_HS_M = 1.0` is that floor, taken from the ADR's own worked example.
> **Whether 1.0 m is the right value is an open question for the operator — trigger 1, not a
> coordinator call.**

**Profile coverage confirmed adequate:** deepest handoff needed is `1.3 × 4.0 / 0.73 = 7.12 m`
and the profile reaches 10.2 m, so every forecast hour's handoff falls inside it.

### T4A.6 — Fix beach profile contract mismatches beyond vocabulary

- **Owner:** `clearskies-api-dev` + `clearskies-dashboard-dev`
- **Added:** 2026-07-24 by the coordinator, from findings surfaced by the
  `clearskies-dashboard-dev` agent while writing T4A.1's OpenAPI schemas.
- **Files:** API `endpoints/beach_profile.py`; dashboard `src/api/types.ts`,
  `BeachProfileChart.tsx`, `src/api/openapi-v1.yaml`

**Problem:** T4A.1 unifies the *names* of the cross-shore fields. Writing the
OpenAPI schema against the real API response exposed three further API↔dashboard
mismatches of *shape*, all in the same family as Phase 4A Origin item 4 (two
parallel type systems). Each one means a built dashboard feature never renders
against real data — the same silent-degradation class this phase exists to
eliminate, one layer down.

Full spec below, read directly from `endpoints/beach_profile.py`
(`_build_transect_profile()`) by the `clearskies-dashboard-dev` agent during
T4A.1 and documented faithfully in the new OpenAPI schemas (commit `e90fd43`).
This is a specification, not a rediscovery exercise.

| # | API emits | Dashboard type expects | Effect |
|---|---|---|---|
| a | `waveShapes` — **top-level** array on the transect result: `{distance, depth, regime, surface: [[phase, eta], …] \| null}` | `waveShape` (singular) array **nested inside each point** — a shape the API has never produced | `hasWaveShapeData = transect.some(p => p.waveShape…)` is always false; the chart's wave-shapes toggle is dead |
| b | `jackingFactors` — **top-level** array: `{barIndex, distance, factor}` | `jackingFactor` as a **scalar on each break point** | `if (!bp.jackingFactor \|\| bp.jackingFactor <= 1.3) return null` — jacking annotations never render |
| c | Break points carry nested `partitionInfo: {partitionIndex, periodS, directionDeg, classification, heightM}` plus top-level `iribarren: number` | Neither; only a flat, never-populated `partitionLabel?: string` | Partition annotation degraded to a lossy flat string |
| d | `_serialize_surf_zones()` per-zone dict can carry `width_m` → `widthM` | `SurfZoneExtent` has no `widthM` field | Zone width unavailable. **Unconfirmed:** which zones populate `width_m` was not verified against `surf_1d_analytical.py`'s `SurfZones` dataclass — verify before fixing |
| e | Single-transect response includes `perPartitionBreaks` (array of `{partitionIndex, periodS, directionDeg, heightM, classification, meanBreakDistanceM, meanFaceHeightM, peakFaceHeightM, meanBreakDepthM, dominantBreakerType}`) and `metadata` (`{axisUnits, verticalDatum, transectCount, openTransectCount}`) | `BeachProfileData` has **neither property at all** | Both silently dropped — not mis-shaped, absent |
| f | Vertical datum exists **only** at `metadata.verticalDatum`, and is currently **hardcoded `"NAVD88"`** rather than read from DEM metadata | `BeachProfileData.datum?: string \| null` as a **top-level sibling** of `transect` | `BeachProfileChart`'s `datum` prop is always `undefined`; the datum-qualified Y-axis label ("Depth (m, NAVD88)") never renders in production. **The hardcoded datum is itself a defect** — see T4A.3 lead call LC-13 and the coordinator's finding that HB is covered by DEMs in two different datums (NAVD88 and MHW) |

**Added 2026-07-25 — item (g), from the per-hour handoff decision (ADR-093 Amendment 2):**

| # | Problem | Fix |
|---|---|---|
| g | The response carries no record of **where the handoff was taken from**. Under the old design that was a fixed setup-time depth, so it was implicit in the config. It is now a per-forecast-hour choice (`1.3 × Hs(hour) / gamma`), which means the same spot hands off at different depths across the 72 hours — and nothing in the response says which. | Add the handoff depth actually used, and the source level (`L3` or `L2`), to the per-hour transect data and to `metadata`. Without it, T4A.10's failure mode is undiagnosable from the API alone: a handoff sampled from a breaking cell returns plausible small numbers, and there is no way to tell that from genuinely small surf. |

> **CORRECTED 2026-07-25 — items (a) through (e) need NO API changes.** This task's table is
> written as though both sides were wrong. They are not: `endpoints/beach_profile.py` already
> emits `waveShapes`, `jackingFactors`, `iribarren`/`partitionInfo`, `widthM`, `perPartitionBreaks`
> and `metadata` correctly today. **The mismatch is dashboard-only for (a)–(e).** Item (f) is a
> dashboard wiring change plus a value fix owned by T4A.3 (the datum). Item (g) is the only one
> requiring new API code. Verified by the implementing agent and confirmed by the coordinator.
>
> **Item (d) resolved:** the plan flagged as unconfirmed which zones populate `width_m`.
> `_classify_zones()` in `services/surf_1d_analytical.py` populates it **only** on
> `total_surf_zone` — never impact, foam, or reform.

**Do:**
1. For each of (a), (b), (c): decide which side is canonical and align the other.
   Default to the API's shape, matching T4A.1's Decision (the model's vocabulary
   and structure win) unless the dashboard shape is demonstrably better for
   rendering — in which case change the API and say why.
2. Update `src/api/types.ts` and the consuming components so each feature renders
   against real data.
3. Update `src/api/openapi-v1.yaml` to document the final agreed shape.
4. Verify each of the three features renders with real data on the dev
   dashboard — a passing `tsc` is not evidence that a chart overlay draws.

**Accept:**
- Wave shapes overlay renders from real API data.
- Jacking factor annotations render from real API data.
- Break point partition annotation renders the full API shape (`iribarren` and
  `partitionInfo`), not a lossy flat string.
- OpenAPI spec documents the agreed shape for all three.
- No remaining API↔dashboard shape mismatch in the beach profile response.
- Per-hour handoff depth and source level (L3/L2) present in the response and documented in the OpenAPI spec (item g).

**Not deferrable.** This task is inside Phase 4A and must close before QC Gate 4A.
It was separated from T4A.1 only because it requires a canonical-shape decision
and T4A.1's two agents were already in flight; injecting it mid-round risked the
churn the plan's execution rules exist to prevent.

### T4A.7 — Rewire the surviving SWAN supplements into the SwellTrack pipeline

- **Owner:** `clearskies-api-dev`
- **Added:** 2026-07-24 by the coordinator (lead call LC-27), from a finding
  surfaced by the `clearskies-api-dev` agent implementing T4A.4.
- **Files:** `services/surf_1d_pipeline.py`, `endpoints/surf.py`,
  `enrichment/wave_transform.py` (call site only)

**Problem:** Removing the SWAN CURVE face-height computation (T4A.4) orphaned
`wave_transform.apply_supplements()`. Investigation found `endpoints/surf.py` held
its **only** call site in the entire package — `surf_1d_pipeline.py` never called
it. So the supplements were feeding *only* the formula path T4A.4 deletes.

Two governing documents claim otherwise:
- `docs/ARCHITECTURE.md` — `wave_transform.py` "Applies bathymetric/structure
  supplements to SWAN Hs".
- `SURF-ZONE-MODEL-BRIEF.md` §7 — *"**Feeds the 1D model.** The 1D model receives
  the post-supplement Hs from SWAN. wave_transform.py continues to operate on
  SWAN's raw output before the handoff. No overlap."*

**The documents describe the intended design; the code never implemented it.**
The supplements have been feeding a formula approximation instead of the model
they were written for.

> **APPROVED 2026-07-25 by the operator, with one verification gate (see below).**
>
> History, because it matters for how this task is read: the DELETE disposition entered
> the plan as coordinator lead call LC-27 (2026-07-24) and is **named in `CLAUDE.md`** as
> the second of the three unapproved architectural changes the hard block was written
> about — *"ruled to delete `wave_transform.apply_supplements()` — first ruling 'rewire,'
> then 'delete' — a component-disposition call."* It sat in the plan as though approved
> for a day. It is now genuinely approved. The original ruling was still a violation; the
> conclusion happening to be right does not retire that.
>
> **Why the approval is narrow rather than a reversal.** By 2026-07-25 the disposition is
> no longer "delete a live component." Of the four supplements: #2 was already removed by
> ADR-095; #4 (topographic multipliers) was approved for removal by the operator on
> 2026-07-25 and is split out to **T4A.12**; #1 is a branch that has provably never
> executed. Removing provably-dead code is methodology, not architecture (`CLAUDE.md`,
> architecture-vs-methodology table). That leaves **#3 as the only supplement whose
> removal is a real decision.**
>
> **VERIFICATION GATE — do this before deleting supplement #3.** Confirm that the handoff
> spectrum is emitted at *requested coordinates* (SWAN `POINTS` at explicit x/y) rather
> than at grid-cell centres. If SWAN interpolates to the requested point, supplement #3 is
> genuinely redundant and goes. **If it does not, supplement #3 is doing real work and must
> stay** — report that and stop, do not delete it anyway. Note this interacts with the
> per-hour handoff (T4A.9), which selects a cell rather than a coordinate: reconcile the
> two before concluding.
>
> **Run T4A.12 first.** It is approved independently and is correct whatever this gate
> returns.
>
> The analysis below predates the 2026-07-25 review and reached the same double-counting
> and dead-branch conclusions independently. Retained.

**Disposition: DELETE — approved, subject to the supplement #3 verification gate above.** `wave_transform.py` is pre-1D-model code (its own docstring
dates it to "Phase 3, T3.1") written to supplement SWAN's bulk Hs before the
K-G/Caldwell single-point formula. Every one of its supplements is now either
superseded or dead:

| Supplement | Status |
|---|---|
| Sub-grid bilinear interpolation | **Superseded.** The 1D boundary condition is a SPECOUT emitted at the requested handoff coordinates, not a grid-cell value needing interpolation. |
| Breaker index correction (Battjes 1974 γ tuning) | **Dead at runtime, and superseded in principle.** Its guard requires `spot_config.bathymetric_profile`, but `marine_config.py` explicitly stopped reading that key ("we intentionally do not read it here — runtime CUDEM profiles are cached at `/etc/weewx-clearskies/spot_profiles/`"). `getattr(spot_config, "bathymetric_profile", None)` is therefore always `None` and **the branch has never executed**. Separately, it derives γ from a single configured scalar `beach_slope` and a crude `bathymetric_profile[0].depth_m` proxy, while `run_1d_analytical()` already computes `_local_slope()` at every point and `_iribarren()` at each detected break point from the real profile. Feeding the supplement's γ into the 1D model would inject a **coarser** estimate into a finer one. |
| Topographic focusing / sheltering | **Superseded.** SWAN's nested 2D grids model focusing and sheltering physically from real bathymetry at L2/L3. An operator-classified multiplier applied on top double-counts. |
| Coastal structure transmission/reflection | **Already removed** by ADR-095 — handled natively by the SWAN `OBSTACLE` command. |

**Do:**
1. Delete the `apply_supplements()` call from `endpoints/surf.py`.
2. Delete `apply_supplements()`, `apply_breaker_correction()`, `compute_iribarren()`,
   `compute_breaker_gamma()` and the topographic-adjustment helper from
   `enrichment/wave_transform.py`. **Keep `bilinear_interpolate()`** — `surf.py`
   still uses it for HRRR wind interpolation, an unrelated live caller.
   `rules/coding.md` §3: "No dead code."
3. Update `docs/ARCHITECTURE.md` (the `wave_transform.py` description) and
   `SURF-ZONE-MODEL-BRIEF.md` §7 (which claims "Feeds the 1D model … The 1D model
   receives the post-supplement Hs from SWAN"). Both describe a design that was
   never implemented. Replace with what the code does: the 1D model takes its
   boundary condition directly from the SWAN handoff SPECOUT.

   > **CORRECTED 2026-07-25 — this step was wrong about `ARCHITECTURE.md`.** That document
   > carries **no** `wave_transform.py` description to fix. The implementing agent grepped it for
   > `wave_transform`, `Battjes`, `Iribarren` and `Sub-grid` and found zero matches; the
   > coordinator confirmed. `ARCHITECTURE.md` was correctly left untouched, and adding a
   > description of a module reduced to a single wind-interpolation helper would grow that
   > document with something it deliberately does not track. `SURF-ZONE-MODEL-BRIEF.md` §7 was
   > the only stale statement and it was fixed (`aef7669`).
   >
   > The live stale documentation was in **`docs/manuals/API-MANUAL.md` §17**, which described
   > Supplements 1 and 3 as active pipeline stages plus five further references routing wave
   > heights through them. Fixed in the same commit. Two additional pre-existing inaccuracies
   > were found there and corrected: the marine card `waveHeight` and `observation.waveHeight`
   > fields both claimed a SWAN → `wave_transform` source, when `endpoints/marine.py` actually
   > uses WaveWatch III → NDBC buoy for both. Unrelated to this task; real drift; verified against
   > the code before correcting.

**Accept:**
- Supplement #3 verification gate answered with evidence (which SWAN command emits the
  handoff spectrum, and whether it interpolates to a requested coordinate), and the
  outcome recorded — either #3 removed, or #3 retained with the reason.
- No `apply_supplements()` call site anywhere; the function and its
  breaker-correction helpers are gone.
- `bilinear_interpolate()` retained; `surf.py`'s HRRR wind path still works.
- Targeted tests for the deleted functions removed; remaining tests pass with no
  regression against the 2-failure baseline.
- ARCHITECTURE.md and SURF-ZONE-MODEL-BRIEF §7 describe the implemented design.

**Follow-on question, deliberately NOT answered by this task:** whether
`run_1d_analytical()`'s fixed `gamma=0.73` should become a per-point value derived
from the model's own Iribarren number. That is a legitimate physics improvement,
but it is answered **inside** the 1D model using its own local-slope data — not by
resurrecting a pre-1D supplement built on coarser inputs. Tracked separately; not
in Phase 4A scope.

**Not deferrable.** Closes before QC Gate 4A.

### T4A.8 — Fix the latent `NameError` in the SurfBeat IG-strip precomputation

- **Owner:** `clearskies-api-dev`
- **Files:** `endpoints/surf.py`

**Problem:** A pre-existing F821 defect found during T4A.4 and confirmed present
at the pre-round commit `0d87b28` via `git stash` (i.e. not introduced this
round): in the SurfBeat IG-strip precomputation block, `ts_wind_speed` and
`ts_wind_direction` are referenced **before** their per-timestep-loop definition.

**Impact:** a real `NameError` whenever that path executes — which requires
`surfbeat_enabled`, available bathymetry, and a valid cadence-hour match
simultaneously. It has evidently not fired in production yet, which means the
SurfBeat path has not been exercised under those conditions.

**Do:** fix the reference order. Add a regression test that exercises the
precomputation block with `surfbeat_enabled=True` and a valid cadence-hour match.

**Accept:**
- `ruff` reports no F821 in `endpoints/surf.py`.
- A test exercises the previously-unreachable path and passes.

**Not deferrable.** Closes before QC Gate 4A.

### Adversarial Audit — Phase 4A

- **Owner:** `clearskies-auditor`

**Scope:**
1. **Vocabulary:** grep all repos for `hsEnvelope`, `distanceFromShore`, `waveHeight` (in the beach profile context) — zero matches except historical docs. Only `transect`, `distance`, `depth`, `hs` used. This includes `endpoints/surf.py`'s own independent `breakPoints` array and the `units_block` label keys in both endpoints (coordinator lead calls LC-20 and LC-21, 2026-07-24).
2. **Profile resolution:** verify HB spot profile has >200 points with variable spacing (1-2m near shore, wider offshore).
3. **No SWAN CURVE face height in surf endpoint:** grep `surf.py` for `hsig_to_face_height` — zero calls. Face height comes only from pipeline.
4. **Scorer input:** verify `score_surf()` receives SwellTrack face height, not SWAN CURVE.
5. **No silent fallback:** when SwellTrack returns zero, response shows zero — not a formula value.
6. **CUDEM at apply time:** verify `/setup/apply` triggers CUDEM download. Verify SWAN runtime does NOT download CUDEM.
7. **Disk persistence:** verify all profiles survive service restart (SURF-ZONE-MODEL-BRIEF §6.1 + `rules/coding.md` persistence rule).
8. Silent deferral scan across all modified files.

### T4A.9 — Per-hour handoff cell selection (replaces the fixed handoff depth)

- **Owner:** `clearskies-api-dev`
- **Files:** `services/transect_handoff.py`, `services/surf_1d_pipeline.py`
- **Governing:** ADR-093 Amendment 2 §2. Read it before coding — do not work from this summary.

**Problem.** The handoff is currently treated as a single depth fixed at setup. ADR-093
Amendment 2 replaces this: the grid is frozen at setup, but the cell the handoff spectrum is
read from moves every forecast hour.

**Do:**
1. Compute `handoff_depth(hour) = 1.3 * Hs(hour) / gamma` per transect per forecast hour,
   where `Hs(hour)` is that hour's significant wave height at the transect and gamma = 0.73.
2. Select the handoff **position** nearest that depth along the transect, seaward side. This is
   a lookup against the existing grid — **no regrid, no resize, no bbox change.** Grid geometry
   stays exactly as `compute_domains()` produced it.

   > **CORRECTED 2026-07-25 (coordinator lead call LC-R2-1): "position", not "cell".** This step
   > previously said "select the L3 grid cell." ADR-095 Amendment 2 says extraction "happens at
   > the handoff position with grid on both sides of it," and the code already emits
   > `POINTS '{name}' {x} {y}` at explicit UTM coordinates (`swan_formats.py:1424`; same for the
   > L2 reference at `swan_runner.py:1444`). Per `rules/clearskies-process.md` — "ADR wins on
   > conflict — fix the plan to match" — the position reading governs, and the plan is corrected
   > here. This also keeps T4A.7's supplement-#3 gate coherent: SWAN bilinearly interpolates
   > output to the requested coordinate, which is what made that supplement redundant.
   >
   > **Mechanism (verified against the installed SWAN manual, pp. 90 and 108–109):**
   > `SPECOUT 'sname'` accepts a **CURVE** name, not only a POINTS set, and curve values are
   > "interpolated from the computational grid." The L3 input already emits
   > `CURVE 'CVn'` with a `TABLE` on it, so emitting `SPECOUT 'CVn'` yields a spectrum at every
   > station already inside SWAN's output loop — no new geometry, no candidate-point
   > construction. Exclude the clipped outermost stations from selection to satisfy the
   > no-boundary-cell rule.
   >
   > **Measured cost (00Z cycle, librewxr):** 36 directions × 31 frequencies = 1,116 bins;
   > ~5.9 KB per location per timestep; 19 curve stations × 67 timesteps ≈ 7.5 MB, up from
   > 386 KB. Against 233 MB already moved per L3 run (`nest_in.dat` 126 MB, `hotstart.dat`
   > 82 MB, `WIND.txt` 19 MB, `WLEVEL.txt` 9.5 MB) and 1387 s of L3 compute. **Under 1%.**
3. Extract the handoff spectrum from that cell. Where a per-hour cell coincides across
   transects, deduplicate as the existing SPECOUT logic already does.
4. **Never sample an L3 boundary cell** (ADR-095 Amendment 2). If the computed depth lands on
   or outside the grid edge, log WARNING and clamp to the nearest interior cell.
5. Delete any code path that resolves the handoff from `max_hs_m`. That was the frozen-depth
   error — it uses the year's largest swell for every hour of the year.

   > **NO-OP as written, confirmed 2026-07-25 by the coordinator and independently by the
   > implementing agent.** There is no such path. `max_hs_m` appears only in
   > `enrichment/bathymetry.py` fine-zone sizing (`compute_fine_zone_max_depth`,
   > `interpolate_profile_pchip`) — which this task itself says correctly stays. Zero occurrences
   > in `transect_handoff.py`, `swan_formats.py`, `swan_runner.py`, or the standalone SWAN repo.
   > The frozen-depth error lived in the *documents*, never in the handoff code: the code's fixed
   > handoff was structure-shadow-driven (`10.0 m` default, `max(5.0, tip_depth − 1.5)` when
   > shadowed), not `max_hs_m`-driven. **Do not invent a path in order to delete one.**

**Accept:**
- Handoff depth varies across the 72 forecast hours for the same transect.
- A 1 m hour and a 4 m hour at HB resolve to different cells (~1.8 m vs ~7.1 m depth).
- `compute_domains()` output is byte-identical before and after a forecast cycle.
- No remaining reference to `max_hs_m` in handoff selection (profile sizing still uses it —
  that is correct and stays).

### T4A.10 — Runtime assertion: sampled cell must be out of the breaking zone

- **Owner:** `clearskies-api-dev`
- **Files:** `services/transect_handoff.py`

**Why this exists.** The per-hour handoff introduces a new silent-failure path. If the hourly
depth is computed wrong, the sampled cell sits in breaking water, SWAN's Hs there has already
been dissipated, and the surf output looks like an ordinary small day. Same shape as the
2026-07-23 incident where 0.01 m Hs was served during a 6–8 ft swell with a valid HTTP 200.

**Do:**
1. After selecting the cell, assert SWAN's breaking fraction (QB) at that cell is ~0.
2. On violation: log ERROR with transect, hour, computed depth, actual cell depth, and QB —
   greppable pattern `SWAN handoff`. Move the sample seaward until QB ~ 0, or fail the hour.
3. Expose a counter on `/metrics` so repeated violations are visible to the operator.
4. Never fail silently and never serve a sample from a breaking cell.

**Accept:**
- Forced-violation drill (inject a shallow handoff) produces the ERROR log and the counter
  increments.
- Normal cycle produces zero violations at HB.

### T4A.11 — Widen the L3 trigger and implement the viability test

- **Owner:** `clearskies-api-dev`
- **Files:** `services/swan_domain.py`, `config/marine_config.py`
- **Governing:** ADR-093 Amendment 2 §3, §4. Read before coding.

**Do:**
1. L3 enables when Overpass API discovers a structure **OR** the operator's topographic
   classification is point break / headland / bay break. Structure-only was the old trigger
   and could never enable L3 at a point break.
2. Ensure the classification actually reaches `compute_domains()`. Per
   `rules/clearskies-process.md`, all inputs affecting grid sizing must be passed in, not
   applied afterwards — an agent previously added a runtime override rather than fixing the
   caller, and it produced 0.01 m wave heights.
3. Size the grid's shoreward reach to the smallest value `1.3 * Hs / gamma` ever produces for
   the spot.
4. **Viability test:** verify the grid reaches the feature it exists for. If not, set
   `grid=None` and **log at INFO which feature was unreachable and by how much.** A grid
   reaching too far shoreward announces itself at runtime (T4A.10); one stopping too far
   seaward is silently indistinguishable from "nothing here to model" — the log is what makes
   it visible.
5. Setup-time calculation is depth-based only: contour positions, slope, breaking depths,
   spans, extents, relief. **No contour curvature, orientation variation, or automatic
   break-type detection** — explicitly out of scope.

**Accept:**
- A spot classified as a point break with no structures enables L3.
- A cluster failing the viability test has `grid=None` and an INFO log naming the feature and
  the shortfall distance.
- HB Pier's disposition is whatever the test returns — not hard-coded either way.

### T4A.12 — Remove Supplement 4 topographic multipliers

- **Owner:** `clearskies-api-dev`
- **Files:** `enrichment/wave_transform.py`
- **Governing:** ADR-093 Amendment 2 §5b; API-MANUAL §17 (already updated).
- **Relationship to T4A.7:** T4A.7 proposes deleting `apply_supplements()` entirely and is
  **blocked pending operator approval** (it is the LC-27 component-deletion call named in
  CLAUDE.md). This task is the operator-approved **subset** — the topographic multipliers
  only. It is safe to run regardless of how T4A.7 is decided, and should run first. T4A.7's
  own analysis reached the same double-counting conclusion on 2026-07-24, independently of
  the 2026-07-25 review.

**Do:**
1. Remove the multiplicative topographic adjustment (point break ×1.1, headland ×1.2, bay
   break ×0.9, straight beach ×1.0) from `apply_supplements()`. Removed outright — not made
   conditional on whether L3 is running.
2. Retain the operator's classification field in spot config. Its job is now the L3 trigger
   (T4A.11), not a wave-height adjustment.
3. These multipliers stand in for refraction SWAN computes. Once L2 existed at 100 m they
   became double-counting.

**Accept:**
- `apply_supplements()` applies no topographic multiplier.
- The classification field still round-trips through wizard, admin, and apply.
- Supplements 1 and 3 still fire (2 was removed by ADR-095; 4 is removed here).

### T4A.13 — Mark superseded research briefs

- **Owner:** `clearskies-docs-author`
- **Files:** `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`,
  `docs/planning/briefs/SWAN-NESTING-RESEARCH-BRIEF.md`

**Do:** Add superseded banners — do **not** rewrite. These are research records and their
historical reasoning has value.
1. SURF-ZONE-MODEL-BRIEF §4 and §9 Option 1: "SWAN L3 runs to shore (current architecture, no
   changes)" — superseded by ADR-093 Amendment 2.
2. SURF-ZONE-MODEL-BRIEF §9 Option 3: "Truncate L3 at handoff depth… not recommended" — this
   now *describes the adopted architecture*. Note the reversal and why.
3. SURF-ZONE-MODEL-BRIEF §2.3.4: the fixed handoff algorithm and the `min(handoff, 15.0)`
   clamp — superseded by the per-hour handoff.
4. SWAN-NESTING-RESEARCH-BRIEF lines 190–237: the depth-of-closure derivation of the 15 m
   figure. Still correct as the *offshore* edge rationale; mark that it does not govern the
   shoreward edge.

**Accept:** Each location carries a dated banner naming the superseding ADR. No content
deleted.

### QC Gate 4A

- Handoff depth varies per forecast hour; grid geometry unchanged across a cycle.
- Sampled handoff cell has QB ~ 0 on every transect/hour, with the violation drill proven.
- L3 enables on operator classification as well as structures; viability test logs shortfalls.
- No topographic multiplier in `apply_supplements()`.
- Superseded briefs carry dated banners.
- One vocabulary for beach profile data: `distance`, `depth`, `hs`, `transect`.
- Dashboard BeachProfileChart and HeatMapCard render without errors.
- SwellTrack produces non-zero face heights at HB.
- Surf endpoint: `degraded=false`, face heights from SwellTrack.
- Beach profile endpoint returns full transect data with variable-resolution envelope.
- Surf scorer uses SwellTrack face height.
- CUDEM downloads at apply time, not runtime.
- Profiles persist across restarts.
- Auditor: zero unresolved findings.

---

## Phase 4B — Per-Transect Grid-Derived Handoff

**Purpose:** SWAN L3 computes a 2D wave field. The handoff to SwellTrack currently collapses it
to **one point per spot** and replicates that single value across all transects. Phase 4B makes
each 1D line take its boundary condition from the grid **at its own location**.

**Origin:** found 2026-07-25 during T4A.5 verification, when the operator asked what the CURVE
transect was for. Not a Phase 4A regression — a pre-existing hole Phase 4A built inside without
questioning. The adversarial audit missed it too: check A1 asked whether stations *within* the
one curve were correctly aligned; nobody asked why there was only one curve.

### The finding — evidence, not inference

**1. One CURVE per spot, not per transect.** `swan_formats.py:1394` loops over **spots**:

```python
for n, (spot_id, (spot_lon, spot_lat)) in enumerate(spots.items(), start=1):
    ...
    f"CURVE '{curve_name}'"        # curve_name = f"CV{n}" — n indexes SPOTS
```

HB is one spot → **one** cross-shore output line, at the spot pin.

**2. All transects receive that same value.** `endpoints/surf.py:1099`:

```python
_handoff_by_transect = {
    _idx: (_handoff_selection.handoff_depth_m, _handoff_selection.source_level)
    for _idx in range(len(_spot_transects))
}
```

A dict comprehension assigning **one** `_handoff_selection` to all 32 keys. "Per-transect" in
shape only. A transect in the pier's shadow is handed the same unshadowed spectrum as one 150 m
up the beach, and SwellTrack then faithfully propagates a boundary condition that was never true
at that location. **The alongshore variation the 2D run spent 1200 s computing is discarded at
the handoff.**

**3. Station spacing cannot hit the handoff depth.** `spacing_m: float = 50.0`
(`swan_formats.py:778`) — hardcoded, no config key, no caller override. On HB's ~1:50 nearshore
slope, 50 m horizontal ≈ **1.4 m of depth**. The two shallowest stations are 0.98 m (the grid
boundary, correctly excluded by T4A.10) and 2.37 m, with nothing between. Measured on the
2026-07-25 07:06Z run: **all 73 timesteps clamped**, handoff landing at ~2.25× breaking depth
instead of the intended 1.3×. This is not a small-conditions artefact — Surfline reported 4–6 ft
with an active Beach Hazards Statement during that run.

**4. L3-disabled spots are worse.** `swan_runner.py:1858` serves them from
`_l3_fallback_points_from_dwr()` — a **single ~15 m L2 deep-water reference point** per spot, not
even per-hour. Note the honest ceiling: L2 is 100 m resolution, so 32 transects spanning ~320 m
cover ~3 L2 cells. Per-transect sampling from L2 yields ~3 distinct values, not 32. Still right
to do; the limit is L2's grid, not our sampling. Sampling L2 shallower than 15 m is unreliable at
100 m cells (the whole surf zone is 2–3 cells wide), which is likely why Amendment 2 §4 chose
15 m.

**5. Our spectral partitioning does not conserve energy.** `swan_spectral.py:731`, verbatim:

```
# Neighbourhood: ±4 bins in frequency and direction (≈±40° for 10°/bin grids).
# No greedy cell exclusion — each peak integrates over its full neighbourhood
# independently so secondary swell systems are not masked by the dominant peak.
```

Fixed ±4-bin windows with **no cell exclusion**: windows overlap, so a spectral bin is counted
into multiple partitions, while bins outside every window are counted into none. Partition
heights do not sum to total Hs. L3 output has 31 directional bins ≈ 11.6°/bin, so ±4 bins ≈
**±46°** — the 2026-07-25 sea state (2.9 ft @ 12 s @ 184° and 0.7 ft @ 23 s @ 196°, **12° apart**)
sits well inside one window and gets smeared, with the 23 s energy double-counted.

### Verified SWAN mechanics — read from the manual and the source, not assumed

Checked against `/tmp/swanuse.txt` (SWAN 41.51 user manual) and `/tmp/swan_src/src/` on librewxr.

**`POINTS` — arbitrary output locations** (manual p. 92). `CURVE` is only a convenience that
auto-generates evenly-spaced points along a straight line; `POINTS` names exact coordinates:

```
                     |   < [xp] [yp] >    |
POINts   'sname'   <                        >
                     |   FILE  'fname'    |
```

Coordinates are in the problem coordinate system — **degrees** for spherical, metres for
Cartesian. Minimum abbreviation `POIN`. **No output-point count limit exists in the manual.**

**`SPECOUT` accepts a POINTS set** (manual p. 108): *"for each location of the output location set
'sname' (see commands **POINTS**, CURVE, FRAME or GROUP) the 1D or 2D … density spectrum … is to
be written."* So POINTS behaves identically to CURVE for spectral output. Point output is
**interpolated from the computational grid** (p. 90; `SWOEXA`/`SWOEXD` in `swanout1.ftn`) — so a
handoff reads the field *at the transect's coordinates*, better than nearest-cell, at no cost.

**`TABLE` accepts SWAN's own spectral partitioning.** Valid parameters include
`PTHSIGN|PTRTP|PTWLEN|PTDIR|PTDSPR|PTWFRAC|PTSTEEP` (`swanpre2.ftn:1572`). Partitioning uses the
**watershed algorithm of Hanson and Phillips (2001)** — every bin assigned to exactly one
partition, energy conserving, boundaries following the spectrum's own topography. Partition 01 is
**wind sea**; 02–10 are swells in descending Hs. At most 10 partitions. `PARTIT` is BLOCK-only and
must not appear in TABLE.

**Column layout and exception values** — from `swanmain.ftn:2649+`. Each keyword expands to 10
columns; individual partition keywords are rejected ("Use PTHSIGN instead"):

| Keyword | Columns | Exception value |
|---|---|---|
| `PTHSIGN` | `HsPT01` … `HsPT10` | `-9` |
| `PTRTP` | `TpPT01` … `TpPT10` | `-9` |
| `PTWLEN` | `WlPT01` … `WlPT10` | `-9` |
| `PTDIR` | `DrPT01` … `DrPT10` | **`-999`** |
| `PTDSPR` | `DsPT01` … `DsPT10` | `-9` |
| `PTWFRAC` | `WfPT01` … `WfPT10` | `-9` |
| `PTSTEE` | `StPT01` … `StPT10` | `-9` |

> **Parser trap, flagged deliberately: `PTDIR` uses `-999`, every other PT variable uses `-9`.**
> A parser assuming one uniform sentinel will mis-handle absent partitions. Absent partitions
> carry the exception value — **not** zero and **not** blank.

**`SPECOUT … S` / `… L`** (manual p. 109): `S` = frequencies **above** the IG cut-off f_ig (the
sea-swell part); `L` = frequencies **below** it (the infragravity part). Both "only relevant for
surfbeat (IEM) modelling." See T4B.5 — SurfBeat stays alongshore-uniform and needs no change.

**Why this makes the design cheap.** `run_1d_analytical()` takes scalars — `hs, tp, direction` —
not a spectrum, and ADR-093 Amendment 2 states SwellTrack "marches bulk parameters per partition
and reconstructs no surface." SWAN can therefore hand us exactly what SwellTrack consumes, in
TABLE. Measured on the 2026-07-25 run: `TABLE_1.txt` = **204 KB** vs `SPEC_1.txt` = **7.4 MB** for
the same 18 stations × 73 timesteps. A TABLE-based per-transect handoff is ~12 MB even at 60× the
points, against the ~435 MB a SPECOUT-based one would cost. Output lands on `/var/run` (tmpfs,
9.4 GB total, 8.9 GB free) — the constraint is parse time and RAM, not disk or bandwidth.

### ⚠ Architectural triggers — operator sign-off required before implementation

Per `CLAUDE.md`, these are architectural and **must be approved in chat, not inferred from this
document existing**:

| Change | Trigger | Why |
|---|---|---|
| Handoff moves from one point per spot to one per transect | **3** — a handoff point moves | Where SWAN stops and SwellTrack starts changes location |
| `handoff_by_transect` carries distinct values per transect | **4** — data contract | Shape is unchanged (already `dict[int, tuple[float, str]]`, threaded in `69957f7`); the *meaning* changes from "one value replicated" to "N real values" |
| Replace `decompose_spectrum()` with SWAN's watershed partitioning | **1** — algorithm | A different algorithm assigns energy to partitions. **Recommended** on the energy-conservation evidence above, but it is the operator's call |
| Station spacing 50 m → L3 grid resolution | **3** — resolution | Approved in chat 2026-07-25 ("this needs to be at the same granularity as the L3 grid") |

**ADR-093 Amendment 2 §2 is written entirely in the singular** and becomes wrong under this
change. It needs Amendment 3 — see T4B.7.

### T4B.1 — Per-transect handoff point sets

- **Owner:** `clearskies-api-dev`
- **Files:** `services/swan_formats.py`, `services/swan_domain.py`

**Do:**
1. Replace the one-CURVE-per-spot emission with `POINTS` per transect. Write the coordinate list
   to a file and reference it as `POINTS 'sname' FILE 'fname'`; do not inline hundreds of `[xp]
   [yp]` pairs. Coordinates in **degrees** (the L3 run is spherical).
2. Per transect, place points covering the depth band that transect's handoff can occupy, at the
   **L3 grid resolution (10 m)**, not 50 m.
3. Bound the band using **L2's per-hour Hs**, which is available because L2 completes before L3
   is written. Bracket generously above and below — L2's Hs is at 15 m and the wave shoals
   shoreward of that, so the estimate is systematically low and must not be treated as exact.
4. Emit `TABLE` at the same point set with `DEPTH` and `QB` (needed for selection and T4A.10).

**Accept:** L3 input contains one POINTS set per transect. Point count and total output size
logged. A spot with N transects produces N distinct point sets.

> **Do NOT use L2's Hs for the final selection** — only to decide which points to declare. See
> T4B.3.

### T4B.2 — SWAN watershed partitioning ✅ DONE (`12f9ddc`), operator-approved 2026-07-25

- **Owner:** `clearskies-api-dev`
- **Files as executed:** `services/swan_spectral.py`, `services/swan_runner.py`,
  `services/surf_1d_pipeline.py` (**not** `services/swan_formats.py` — see step 1 below)

**Done:**
1. `PTHSIGN PTRTP PTDIR PTDSPR` on the L3 `TABLE` at the handoff point set — and, added on
   operator ruling during execution, at the **L2 DWR points** as well: the per-spot baseline and
   every T4B.4 per-transect cell, producing `TABLE_DWR_{n}.txt` / `TABLE_{cell}.txt`. Without the
   L2 half, spots with no L3 grid would have kept the broken decomposition. This landed entirely
   in `swan_runner.py`, where those `POINTS`/`SPECOUT` commands are built as raw strings —
   `swan_formats.py` needed no change, so the file list above differs from the original plan.
2. ~~Treat `-9` as absent for all, and `-999` as absent for `PTDIR`.~~ **⚠ This instruction was
   wrong and was the source of the T4B.2 confusion.** SWAN emits neither sentinel. Measured on
   real output: **25288 exact-`0.0` fields, 5264 real values, zero sentinels.** Absence is a
   partition significant height of ~0 (tolerance 0.0005), which is what `12f9ddc` now detects;
   the sentinel check is retained only as belt-and-braces. Following the original text produced a
   partition census that measured the parser rather than SWAN, and that census is what made the
   swap look unwise.
3. Partitions feed the per-partition SwellTrack path; `decompose_spectrum()` has no production
   caller. `run_pipeline()` reads `specout_data["components"]` rather than recomputing, so
   physics and display share one source and cannot diverge.
4. Comparison run before removal — see EVIDENCE below. Σ partition m0 vs total m0 was the
   measurement that settled it.

**Accept — status:** ✅ code, tests, and QC complete (117 passed; 15 pre-existing fixture errors
dated `46eb8839`, 2026-07-17). ⚠ **The Σ-partition-m0-equals-total-m0 acceptance criterion is NOT
yet verified on real data.** The preserved payload used for the measurement below has
`components` written by `decompose_spectrum()` itself, so it reproduces the broken baseline and
cannot grade the fix. Re-run `scripts/verify_partition_duplication.py` against a **fresh** model
run after deploy and record closure here; it should be ≈1.0 against the 1.626 median below. The
in-repo unit test uses a synthetic self-consistent spectrum and is a parser contract test, not
this measurement.

> ### ✅ EVIDENCE 2026-07-25 — measured, and it settles the trigger-1 question
>
> Run against 67 real preserved spectra on librewxr, using `decompose_spectrum()` itself
> (not a reimplementation). Measures energy closure and pairwise separation — needs no real
> swell and does **not** touch `parse_table_pt_partitions()`, so the PT* parser defect does
> not block it.
>
> ```
> ENERGY CLOSURE  sum(component m0) / total m0
>   all timesteps (n=67):   min 0.672   median 1.626   max 2.271
>   multi-component timesteps exceeding 105% of available energy: 65/65
>
> CLOSEST-PAIR DIRECTION SEPARATION (multi-component timesteps)
>   min 0.6deg   median 1.6deg   max 4.4deg
>
> COMPONENT COUNT distribution: {1: 2, 2: 3, 3: 43, 4: 15, 5: 4}
>
> WORST ENERGY CLOSURE — spectrum Hs=0.6012 m, closure=2.271
>   hs=0.5830 m  tp=10.2 s  dir=206.4 deg
>   hs=0.5120 m  tp=10.2 s  dir=210.1 deg
>   hs=0.4680 m  tp=10.1 s  dir=201.1 deg
> ```
>
> **`decompose_spectrum()` does not find multiple swells. It finds one swell and reports it
> several times.** In the worst case three "swells" share a period to within 0.1 s, sit within
> 9° of each other, and each is nearly as tall as the whole spectrum. Median closest-pair
> separation across all multi-component timesteps is **1.6°** — narrower than one 10° direction
> bin.
>
> **Mechanism, from source.** `swan_spectral.py` integrates each peak over a fixed ±4-bin
> window with, in its own words, "no greedy cell exclusion." The live spectrum has 36
> direction bins at 10° each, so that window spans **80°**. Adjacent peaks therefore integrate
> almost the same energy. The 2026-07-25 case the plan cites — 12 s @ 184° and 23 s @ 196°,
> 12° apart — sits entirely inside one window; this method cannot separate it at any wave
> height.
>
> **This reverses the earlier preliminary read.** The "watershed finds 1, ours finds 3–5" gap
> was recorded as evidence *against* the swap. It is evidence *against `decompose_spectrum()`*:
> SWAN reporting one partition is the correct answer, and our 3–5 are duplicates. The 95.2%
> single-partition figure was additionally depressed by SWAN's hardcoded `HSPMIN = 0.05` floor
> (`SwanSpectPart.ftn:96`, discard at line 1424) acting on a run whose handoff Hs spanned only
> 0.01–0.77 m — a floor that is irrelevant at surfable heights.
>
> **SWAN partitioning facts, verified from primary sources** (`/tmp/swanuse.txt` line 4837+,
> `/tmp/swan_src/src/SwanSpectPart.ftn`), correcting secondhand claims made earlier:
>
> | Constant | Value | Effect |
> |---|---|---|
> | `HSPMIN` | 0.05 m | Partitions below this Hs are discarded outright |
> | `WSCUT` | 0.333 | Wind-sea fraction cutoff for classification |
> | `WSMULT` | 1.7 | Wind-sea boundary multiplier |
> | `IHMAX` | 100 | Flooding levels |
> | `FLCOMB` | **.FALSE.** | Wind-sea combining is **OFF** — SWAN does not merge wind seas by default |
>
> All five are compile-time `PARAMETER`s. They appear **nowhere in the user manual** — not
> operator-tunable without recompiling. Watershed is **not** strictly energy-conserving in its
> output: bin assignment is exclusive, but sub-`HSPMIN` partitions are then dropped.
>
> **Operator-visible consequence, live today:** the dashboard's multi-swell card is showing
> the same swell two to five times. Median 3 components where there is 1 real system.
>
> **Still to check before the swap lands:** whether the per-partition SwellTrack path is
> running the 1D model once per duplicate (43 of 67 timesteps report 3 components), which
> would be redundant compute on top of the display error.
>
> ⚠ **ADDENDUM — what this measurement can and cannot be reused for.** The same script was
> re-run on 2026-07-25 against the `components` already stored in that preserved payload, on the
> assumption they were SWAN's own PT* output and could therefore grade the replacement without a
> deploy. It returned the numbers above **identically to three decimal places** — same 1.626
> median, same 2.271 worst case, same three components at 206.4°/210.1°/201.1°. Inspection of
> the deployed code on librewxr confirms why: both sites that populate `components`
> (`swan_runner.py:317` and `:1108` as deployed) call `decompose_spectrum()`. The stored
> `components` **are** the broken output. So this file establishes the baseline and cannot
> validate the fix — that requires a fresh run. Recorded because the same shortcut looks
> reasonable and will be attempted again otherwise.
>
> The redundant-compute question above remains open and is the likely explanation for open item
> 2 (≈1260 unattributed `run_pipeline` calls). Not investigated in this round.

### T4B.3 — Per-transect per-hour selection

- **Owner:** `clearskies-api-dev`
- **Files:** `services/swan_runner.py` (`_select_l3_handoff_spectra`), `services/transect_handoff.py`

**Do:**
1. Keep the selection **post-run**, against L3's own TABLE Hs at the declared points — the
   existing `_select_l3_handoff_spectra()` logic, now run per transect rather than once.
2. Preserve coordinate-based station matching. Do **not** introduce index-order trust; the audit's
   A1 concern applies with more force at 32× the stations.
3. Preserve the boundary-station exclusion and the clamp-with-WARNING. With 10 m spacing the clamp
   should become rare — **log its rate** so a regression is visible.
4. Preserve T4A.10's QB assertion, per transect.

**Accept:** `handoff_by_transect` contains N distinct values. Clamp rate logged and materially
below the 73/73 measured on 2026-07-25.

### T4B.4 — L2 fallback per transect

- **Owner:** `clearskies-api-dev`
- **Files:** `services/swan_runner.py` (`_l3_fallback_points_from_dwr`)

**Do:** Emit L2 output at each transect's own offshore position rather than one point per spot.
Keep the ~15 m reference depth (Amendment 2 §4). **Log that L2's 100 m resolution bounds this to
~3 distinct values across a 320 m spot** — do not present it as full 32-way variation.

**Accept:** L3-disabled spots receive per-transect handoffs. The resolution limit is logged, not
hidden.

### T4B.5 — SurfBeat line — RESOLVED BY READING: stays alongshore-uniform

- **Owner:** Coordinator (investigation complete 2026-07-25)

**Finding: SurfBeat must NOT be made per-transect.** The IEM's own governing assumption forbids
it. Manual p. 80, on the biphase evolution equation that the infragravity energy balance is
solved in tandem with:

> For the prediction of the biphase for obliquely incident waves, an evolution equation is
> provided **under the assumption that the bottom slopes are mild and alongshore uniform.**

Running 32 per-transect SurfBeat strips would be modelling alongshore variation with a module
that assumes alongshore uniformity — asserting a precision the physics does not carry. It would
also cost 32 separate grids × 2 COMPUTEs each = 64 additional SWAN runs.

**Additional hard constraints, all already honoured by `services/surfbeat_runner.py`:**

- `CANNOT BE USED IN CASE OF CURVILINEAR or UNSTRUCTURED GRIDS AND NOT IN 1D-MODE` — regular
  `REG` grid only.
- **Stationary only** — "we assume that the conditions under which the surfbeat is modelled are
  stationary." It is a separate stationary run, not part of the L3 nonstationary 72 h run.
- **Two COMPUTEs** — first solves short + bound IG spectra, second the free reflected IG waves.
- **Offshore boundary on the WEST side, +x pointing east.** Works at HB (beach faces ~238°, so
  offshore is west) but is a hard geometric constraint that will not hold for an east-facing
  coast. **Recorded as a portability limit.**
- **Shoreline OBSTACLE parallel to the y-axis**, `TRANSM 1.0` in the first COMPUTE (so the wave
  field is unaffected) and `REFL [reflc]` in the second. `RDIFF [pown]` is required.

**Correction to an earlier draft of this plan:** `SPECOUT … S` is *not* the SurfBeat output
mechanism. Manual p. 109: `S` = frequencies **above** the IG cut-off (the sea-swell part); **`L` =
frequencies below it — that is the infragravity spectrum.** There is also `HBIG` (bound IG wave
height, m), which is "only to be specified for surfbeat (IEM) during first COMPUTE."

**Do:**
1. Leave SurfBeat's single alongshore-uniform strip as it is. Do not add per-transect strips.
2. Record the alongshore-uniformity assumption in `PROVIDER-MANUAL.md` so a future session does
   not "fix" this the way T4B.1 fixes the L3 handoff — the two look alike and are not.
3. Note that `surfbeat_runner.py` carries its own `_STATION_SPACING_M = 25.0`, independent of the
   L3 CURVE spacing. **Out of scope for 4B**; flagged so it is not assumed to follow T4B.1.

**Accept:** SurfBeat unchanged. The reason is written down where the next person will find it.

### T4B.6 — Wire the distinct values through

- **Owner:** `clearskies-api-dev`
- **Files:** `services/compute_client.py`, `services/compute_service.py`, `endpoints/surf.py`,
  `endpoints/beach_profile.py`

**Do:** Remove the dict comprehension that replicates one value. The wire format does **not**
change — `handoff_by_transect: dict[int, tuple[float, str]]` already exists and is already
threaded across the compute boundary (`69957f7`). Only the values become real.

**Accept:** All 5 call sites pass distinct per-transect values. `handoffDepthM` differs between
transects in the beach-profile response.

> ### ⚠ CORRECTED 2026-07-25 — the "5 call sites" criterion is now wrong
>
> SURF-PUBLISH-RESULTS-ONLY deleted the API-host recompute paths. **In remote mode
> (`[swan] service_url` set — the deployed topology) `endpoints/surf.py` and
> `endpoints/beach_profile.py` no longer build `handoff_by_transect` at all**, and the
> published payload no longer carries `handoff_by_transect`, `energy`, `freqs_hz`, or
> `dirs_deg`. Two of the five original call sites do not exist there any more.
>
> **An agent working to the criterion above would re-add the recompute path to satisfy it.
> Do not.** The corrected criterion:
>
> - **Remote mode:** distinct per-transect values are produced and consumed entirely on the
>   model host — in `swan_runner.py`'s selection, in the SWAN service's
>   `GET /surf/{spot_id}/profile`, and in the precomputed `swelltrack` results. Verify
>   `handoffDepthM` differs between transects **in the API's beach-profile response**, which
>   now originates on the model host. Do NOT verify by inspecting API-host computation —
>   there is none.
> - **Bundled single-host mode:** the original criterion still applies unchanged. The
>   in-process call sites are the model, and they must pass distinct values.
>
> Do not re-publish the removed spectral fields to satisfy any part of this task. If T4B.6
> appears to require them on the API host, the task is blocked — STOP and surface it.

### T4B.7 — ADR-093 Amendment 3

- **Owner:** `clearskies-docs-author`

**Do:** Record that the handoff is per transect and grid-derived. Amendment 2 §2's singular
phrasing ("*the* handoff", "*which cell* we read the handoff spectrum from") becomes wrong and
must be superseded, not silently reinterpreted. State the partitioning decision and its evidence.
Update `ARCHITECTURE.md` and `PROVIDER-MANUAL.md` in the same commit per the doc-code sync rule.

### T4B.8 — Verify against a real swell

- **Owner:** Coordinator

**Do:** Confirm handoff depths differ across transects, that a shadowed transect receives a
genuinely different spectrum from an unshadowed one, and that face heights still track Surfline.
Record the clamp rate.

**Accept:** Per-transect variation demonstrated with real data, not synthetic.

> **Known limit, stated up front:** the large-swell handoff path cannot be verified until a real
> swell arrives. The 2026-07-25 run spanned Hs 0.01–0.77 m at the handoff. This is a genuine
> testability gap, not something to paper over — see T8.7.

### QC Gate 4B

- Handoff depth differs across transects for the same spot and hour.
- A pier-shadowed transect and an open transect receive different spectra.
- Partition heights sum to total Hs; the 12°-separation case resolves as two partitions.
- `PTDIR`'s `-999` and the other variables' `-9` are both handled; no partition read as a real 0.
- Clamp rate logged and materially below 73/73.
- L3-disabled spots receive per-transect L2 handoffs, with the 100 m resolution limit logged.
- SurfBeat **unchanged and still alongshore-uniform**, with the IEM assumption documented.
- Coordinate-based station matching preserved; no index-order trust at 32× stations.
- T4A.10's QB assertion holds per transect.
- ADR-093 Amendment 3 written; ARCHITECTURE.md and PROVIDER-MANUAL.md match.
- Face heights still track Surfline.
- Auditor: zero unresolved findings.

---

## Phase 4 — Marine Service Repo + Scaffold

**Purpose:** Create the `weewx-clearskies-marine` repo, scaffold the service structure, and set up the provider module architecture. The scaffold has endpoints, auth, TLS, systemd, and health — but no provider modules yet (those move in Phase 5).

**Scratch file:** `c:\tmp\marine-sep-P4-scratch.md`

### T4.1 — Create repo with proper structure

- **Owner:** `clearskies-api-dev`
- **Files:** New repo `weewx-clearskies-marine` (local at `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`)

**Do:**
1. Create the repo structure mirroring API repo conventions:
```
weewx-clearskies-marine/
  weewx_clearskies_marine/
    __init__.py
    __main__.py              # CLI entry point
    service.py               # FastAPI app, startup, health, manifest
    config.py                # Marine service config (reads its own config file)
    providers/               # Provider modules (same pattern as API)
      __init__.py
      buoy/
      tides/
      marine/
      wind/
      ocean/
      nearshore/
    services/                # Internal services (SWAN, SwellTrack, SurfBeat)
      __init__.py
    enrichment/              # Scoring, breaker height, wave transform
      __init__.py
    endpoints/               # HTTP endpoint handlers
      __init__.py
    data/                    # Static data files (GSFM, species YAML, etc.)
  tests/
    __init__.py
  pyproject.toml
  LICENSE
```
2. The structure mirrors the API repo exactly. A developer who knows the API repo can navigate the marine service repo without learning a new layout.

**Accept:**
- Repo created with all directories.
- `pyproject.toml` with proper metadata and the dependency split defined in T4.5 (core stays light; heavyweight geospatial deps live in the `[nearshore]` extra).
- `pip install -e .` succeeds.
- `[nearshore]` optional extra for SWAN (eccodes, xarray, netCDF4; the SWAN Fortran binary is an out-of-band system requirement, not a pip dependency).

*(Corrected 2026-07-24, coordinator lead call LC-6. This bullet previously listed
eccodes/xarray/netCDF4 as core dependencies, contradicting T4.5 Do step 2 and
ARCHITECTURE.md's repo-layout row ("`pip install -e .` for core;
`pip install -e ".[nearshore]"` adds SWAN binary support"), and diverging from
the API repo's own `[marine]`/`[nearshore]` precedent. T4.5's split is
authoritative. `cryptography` is additionally core because T4.4 makes TLS
unconditional.)*

### T4.2 — Set up provider module infrastructure

- **Owner:** `clearskies-api-dev`
- **Files:** `weewx_clearskies_marine/providers/__init__.py`, base provider module pattern

**Do:**
1. Create the provider module base pattern — CAPABILITY declaration, `fetch()` interface, canonical field mapping, cache TTL, error handling — identical to the API's provider pattern.
2. Create the provider registry that discovers and loads provider modules.
3. Create the provider dispatch mechanism (internal scheduler, cache warmer).

**Accept:**
- Provider base pattern implemented.
- Registry discovers modules in `providers/` subdirectories.
- A stub provider (empty `fetch()` returning test data) loads and runs.

### T4.3 — Implement /health, /manifest, and /config endpoints

- **Owner:** `clearskies-api-dev`
- **Files:** `weewx_clearskies_marine/service.py`, `weewx_clearskies_marine/endpoints/`

**Do:**
1. `GET /health` (no auth): returns `{"status": "ok", "version": "1.0.0", "last_run": timestamp, "spots": [...], "run_in_progress": bool}`.
2. `GET /manifest` (no auth): returns the endpoint manifest JSON:
```json
{
  "service": "clearskies-marine",
  "version": "1.0.0",
  "endpoints": [
    {"path": "/surf/{location_id}", "method": "GET", "upstream": "/surf/{location_id}", "cache_ttl": 1800},
    {"path": "/surf/{location_id}/profile", "method": "GET", "upstream": "/surf/{location_id}/profile", "cache_ttl": 1800},
    {"path": "/marine/{location_id}", "method": "GET", "upstream": "/marine/{location_id}", "cache_ttl": 300},
    {"path": "/tides/{location_id}", "method": "GET", "upstream": "/tides/{location_id}", "cache_ttl": 3600},
    {"path": "/fishing/{location_id}", "method": "GET", "upstream": "/fishing/{location_id}", "cache_ttl": 1800},
    {"path": "/beach-safety/{location_id}", "method": "GET", "upstream": "/beach-safety/{location_id}", "cache_ttl": 900}
  ],
  "capabilities": ["surf", "tides", "marine_weather", "fishing", "beach_safety"],
  "locations": [...]
}
```
3. `POST /config` (auth required): receives config push from API, stores marine config locally, restarts run loop.

**Accept:**
- `/health` returns valid JSON with all fields.
- `/manifest` returns the complete endpoint manifest.
- `/config` accepts a config payload, persists it, and returns 200.

### T4.4 — Implement TLS, auth, and systemd unit

- **Owner:** `clearskies-api-dev`
- **Files:** `weewx_clearskies_marine/service.py`, systemd unit template

**Do:**
1. **TLS:** Generate self-signed cert on first start (same pattern as API TLS). Store in `/etc/weewx-clearskies/marine/`. Support `--hostname` CLI arg for SAN.
2. **Auth:** Bearer token authentication. Read `MARINE_SERVICE_SECRET` from `secrets.env`. All endpoints except `/health` and `/manifest` require `Authorization: Bearer {token}`. Return 401 for missing/wrong token.
3. **Systemd unit template:** `weewx-clearskies-marine.service` — ExecStart, User, WorkingDirectory, Restart=on-failure.
4. **Bind address:** `0.0.0.0` by default. Configurable via CLI arg.

**Accept:**
- Service starts with TLS on configured port.
- Unauthenticated requests to protected endpoints return 401.
- Wrong-token requests return 401. Correct-token requests return 200.
- Health and manifest endpoints accessible without auth.
- Systemd unit template created.

### T4.5 — Set up pyproject.toml and pip installability

- **Owner:** `clearskies-api-dev`
- **Files:** `pyproject.toml`

**Do:**
1. Package name: `weewx-clearskies-marine`.
2. Dependencies: fastapi, uvicorn, httpx, numpy, pydantic, redis.
3. Optional extra `[nearshore]`: adds SWAN-specific dependencies.
4. Entry point: `python -m weewx_clearskies_marine` starts the service.
5. `pip install -e .` and `pip install -e ".[nearshore]"` both succeed.

**Accept:**
- `pip install -e .` succeeds and service starts.
- `python -m weewx_clearskies_marine --help` shows CLI options.

### T4.6 — Write marine service scaffold tests

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-marine/tests/`

**Do:**
1. Write tests for `/health`, `/manifest`, `/config` endpoints (correct response shape, required fields, status codes).
2. Write auth tests: 401 for missing token, 401 for wrong token, 200 for correct token on protected endpoints. Verify `/health` and `/manifest` are accessible without auth.
3. Write TLS tests: verify service only listens on HTTPS, verify cert generation.

**Accept:**
- All scaffold endpoint tests pass.
- Auth enforcement verified (401 for missing/wrong token on protected endpoints, 200 without auth on /health and /manifest).
- TLS tests pass.

### Adversarial Audit — Phase 4

- **Owner:** `clearskies-auditor`

**Scope:**
1. Repo structure mirrors API repo conventions.
2. Provider module pattern matches API pattern (CAPABILITY, fetch(), canonical mapping, cache TTL).
3. Auth enforcement: verify all endpoints except `/health` and `/manifest` require Bearer token.
4. TLS: verify service only listens on HTTPS.
5. Manifest format matches the specification.
6. Secret storage: verify secret is read from `secrets.env`, not source code, not config file.
7. Silent deferral scan across all new files.

### QC Gate 4

- Repo created with proper structure.
- Provider module infrastructure operational.
- `/health`, `/manifest`, `/config` endpoints functional.
- TLS and auth working (verified with curl tests).
- `pip install -e .` succeeds.
- Auditor: zero unresolved findings.

---

## Phase 5 — Move Provider Modules

**Purpose:** Move all marine data provider modules from the API repo to the marine service repo. Keep the same architecture — same CAPABILITY, same `fetch()`, same caching. Wire the internal pipeline end-to-end.

**Scratch file:** `c:\tmp\marine-sep-P5-scratch.md`

### T5.0 — Capture golden response fixtures

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-marine/tests/fixtures/`

**Do:**
1. Before moving any code, capture the current API response JSON for each marine endpoint as golden fixtures:
   - `GET /api/v1/surf/huntington-city-beach-pier` → `tests/fixtures/golden_surf.json`
   - `GET /api/v1/surf/huntington-city-beach-pier/profile` → `tests/fixtures/golden_surf_profile.json`
   - `GET /api/v1/marine/huntington-city-beach-pier` → `tests/fixtures/golden_marine.json`
   - `GET /api/v1/tides/huntington-city-beach-pier` → `tests/fixtures/golden_tides.json`
   - `GET /api/v1/fishing/huntington-city-beach-pier` → `tests/fixtures/golden_fishing.json`
   - `GET /api/v1/beach-safety/huntington-city-beach-pier` → `tests/fixtures/golden_beach_safety.json`
2. Commit golden fixtures to the marine service test suite.
3. These fixtures serve as regression baselines for Phase 5 provider moves.

**Accept:**
- Golden response JSON captured for all 6 marine endpoints.
- Fixtures committed to `repos/weewx-clearskies-marine/tests/fixtures/`.
- Each fixture contains a valid, non-empty response from the working Part A API.

> ### ⚠ CORRECTED 2026-07-25 — capture these fixtures AFTER SURF-PUBLISH-RESULTS-ONLY is deployed
>
> This is the highest-risk interaction between the two rounds. These fixtures become the
> regression baseline that Phase 5's acceptance and the Phase 5 audit both check against.
>
> **If they are captured before SURF-PUBLISH-RESULTS-ONLY is deployed, they freeze the old
> beach-profile behaviour** — a 404 where the model has no answer, and the pre-trim response
> shape. Phase 5 would then flag the corrected 200-with-null-`modelStatus` response as a
> regression, and an agent would faithfully "fix" it back to the behaviour we deliberately
> removed. The failure would look like a passing gate.
>
> **Prerequisite:** confirm the deploy is live before capturing. The check is that
> `GET /surf/{spot}/forecast` on the SWAN service returns a payload containing `swelltrack`
> and NOT containing `handoff_by_transect`, `energy`, `freqs_hz`, or `dirs_deg`. Record the
> capture date and the deployed commit of both repos alongside the fixtures.
>
> `golden_surf_profile.json` must additionally be captured for BOTH cases — a timestep the
> model answered, and one it did not — or the unavailable contract has no regression cover
> at all.

### T5.1 — Move buoy/ndbc.py (1,001 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/buoy/ndbc.py`
- **Target:** `repos/weewx-clearskies-marine/weewx_clearskies_marine/providers/buoy/ndbc.py`

**Do:** Copy, update imports, wire into marine service registry, verify against live NDBC API.

**Accept:** `fetch()` returns real buoy data from live NDBC. CAPABILITY declaration intact.

### T5.2 — Move tides/coops.py (774 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/tides/coops.py`
- **Target:** `providers/tides/coops.py` in marine service

**Do:** Copy, update imports, wire, verify against live CO-OPS API.

**Accept:** `fetch()` returns real tide data.

### T5.3 — Move marine forecast providers (2,887 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/marine/nws_marine.py` (645), `nws_srf.py` (1,215), `wavewatch.py` (578), `grib_processor.py` (449)
- **Target:** `providers/marine/` in marine service

**Do:** Copy all 4, update imports, wire, verify NWS marine and WW3 against live APIs.

**Accept:** All 4 modules load. NWS marine and WW3 fetch real data.

### T5.4 — Move wind providers (1,636 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/wind/hrrr.py` (907), `gfs.py` (729)
- **Target:** `providers/wind/` in marine service

**Do:** Copy both, update imports, wire, verify HRRR against live NOAA NOMADS.

**Accept:** HRRR and GFS providers load and fetch real wind data.

### T5.5 — Move ocean providers (912 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/ocean/ofs.py` (665), `erddap_ocean.py` (247)
- **Target:** `providers/ocean/` in marine service

**Do:** Copy both, update imports, wire, verify OFS against live data.

**Accept:** OFS and ERDDAP providers load and fetch real data.

### T5.6 — Move wave physics code (11,397 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `services/swan_runner.py` (2,628), `swan_domain.py` (634), `swan_formats.py` (1,511), `swan_spectral.py` (555), `surf_1d_analytical.py` (612), `surf_1d_pipeline.py` (1,091), `surfbeat_runner.py` (961), `wave_setup.py` (316), `bathymetry_resolver.py` (1,070), `shelf_boundary.py` (80), `transect_handoff.py` (742), `enrichment/bathymetry.py` (1,197)
- **Target:** `services/` and `enrichment/` in marine service

**Do:** Copy all 12 files, update imports, move static data files (`data/gsfm_shelf_boundary.json`, `data/ncei_regional_dem_index.json`), verify import resolution.

**Accept:** All 12 modules load without import errors. Static data files present. SWAN runner can locate the SWAN binary.

### T5.7 — Move enrichment code (1,325 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `enrichment/breaker_height.py` (283), `surf_scorer.py` (730), `wave_transform.py` (312)
- **Target:** `enrichment/` in marine service

**Do:** Copy all 3, update imports, move species data YAML if needed.

**Accept:** All enrichment modules load and scoring/classification functions work.

### T5.8 — Move config and service support code (1,209 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `config/marine_config.py` (934), `services/marine_location_resolver.py` (140), `services/marine_weather_cache.py` (135)
- **Target:** `config/` and `services/` in marine service

**Do:** Copy all 3, adapt `marine_config.py` to read from the marine service's own config file (received via `POST /config`), update imports.

**Structural note (added 2026-07-24, Phase 4 audit finding — NON-BLOCKING, forced downstream rework):** Phase 4's T4.1 scaffold created `weewx_clearskies_marine/config.py` as a **flat module** (matching T4.1's own literal tree spec), but this task names `config/` — a **package** — as `marine_config.py`'s target. They collide at the same name. Resolve it at the start of this task, before moving 934 lines: convert `config.py` to `config/__init__.py` re-exporting its current public surface (non-breaking for existing importers), then land `marine_config.py` as `config/marine_config.py`. Do not discover this mid-move.

**Accept:** Config parsing works from local config file. Location resolver and weather cache operational. `config.py` converted to a package with no import breakage; the marine service's own config surface still resolves from `weewx_clearskies_marine.config`.

### T5.9 — Wire the internal pipeline

- **Owner:** `clearskies-api-dev`
- **Files:** `service.py`, endpoint handlers in marine service

**Do:**
1. Wire: SWAN (fetches wind, bathymetry, boundary) → SwellTrack (per-transect) → SurfBeat (IG strip) → scoring → serve via endpoints.
2. Wire: buoy → tides → marine weather → ocean currents → cache → serve via endpoints.
3. Implement all 6 data endpoints with same response shapes as current API endpoints (SI units):
   - `GET /surf/{location_id}` — complete surf forecast
   - `GET /surf/{location_id}/profile` — beach profile
   - `GET /marine/{location_id}` — marine observations
   - `GET /tides/{location_id}` — tide predictions/observations
   - `GET /fishing/{location_id}` — fishing conditions
   - `GET /beach-safety/{location_id}` — beach safety assessment

> ### ⚠ CORRECTED 2026-07-25 — "current response shapes" means POST-SURF-PUBLISH-RESULTS-ONLY, and one endpoint is missing
>
> **(a) A seventh endpoint is required.** `POST /report/gap` is missing from the list above
> and has no home after Phase 8. It exists today on the SWAN service (port 8767); T8.4 stops
> that service. It is how the API tells the model host "you were asked for a spot/hour you
> never published," so that every model failure lands in the model's own log in one place.
> Without it the API's gap reporter POSTs into a void — and because it is deliberately
> fire-and-forget, **that failure would itself be silent**, which is precisely the class of
> problem this plan exists to remove. Port it to the marine service: Bearer auth, body
> `{spot_id, valid_time, endpoint, run_time}`, 204, bounded in-memory dedup, one WARNING per
> distinct combination. Add it to `GET /manifest` only if the manifest supports non-GET
> routes; otherwise the API calls it directly and that is documented.
>
> **(b) "Same response shapes as current API endpoints" must be read as of AFTER
> SURF-PUBLISH-RESULTS-ONLY deploys, not before.** Specifically, the marine service must
> reproduce, not re-litigate:
> - `GET /surf/{location_id}/profile` returns HTTP 200 with a nulled payload and
>   `modelStatus: "unavailable"` when the model has no answer for the requested hour.
>   404 is reserved for configuration and bad-request errors — unknown location, no surf-spot
>   config, no transects, transect index out of range. **That distinction is load-bearing and
>   must survive the move.**
> - The service publishes results, not model working data. Do not reintroduce `energy`,
>   `freqs_hz`, `dirs_deg`, or `handoff_by_transect` into any response the API consumes. The
>   service keeps them internally — it needs them to answer profile requests — but they do
>   not cross the host boundary.
> - `GET /surf/{location_id}/profile` computes on the model host. The API must never need
>   model working data in order to build a response.

**Accept:**
- Full SWAN → SwellTrack → SurfBeat pipeline runs end-to-end.
- All 6 data endpoints return correctly shaped responses.
- **`GET /health`'s `spots` field populates from configured surf spots.** In the
  Phase 4 scaffold this is deliberately unwired — `state.py`'s `_spot_ids` is
  populated only by `set_run_state()`, which nothing in the config path calls,
  and `state.py`'s docstring says "Phase 5 populates this from the actual run
  loop." Confirmed as a NON-BLOCKING finding at QC Gate 4 (2026-07-24) and
  carried here so it is not lost. A service reporting `spots: []` while serving a
  configured spot is a monitoring-layer instance of the same "looks fine, isn't"
  failure this plan exists to remove. The Phase 4 test that pins the empty
  behaviour is provisional and must be updated when this lands.

### ~~T5.10 — Write marine service provider + pipeline tests~~ — CANCELLED 2026-07-25

**Cancelled by operator.** Phase 5 does not write new marine-service tests. The Phase 4
suite (auth, config, health, manifest, TLS) remains the marine service's baseline.

Coverage for the moved code comes from the tests migrated out of the API repo in T6.4b-tests,
which already exercise the providers, wave physics, and enrichment — writing a parallel suite
here duplicated them. The golden fixtures captured in T5.0 are retained and are used for
end-to-end comparison at T8.6, not for unit-level shape assertions.

### Adversarial Audit — Phase 5

- **Owner:** `clearskies-auditor`

**Scope:**
1. Provider module count: verify all 11 provider modules from §0.6 are present (count files).
2. Wave physics count: verify all 12 modules present.
3. Import resolution: `python -c "import weewx_clearskies_marine.providers.buoy.ndbc"` etc. for all modules.
4. CAPABILITY declarations: verify every provider has one.
5. Pipeline end-to-end: verify SWAN → SwellTrack → SurfBeat → scoring → endpoints.
6. Endpoint shape: verify each endpoint returns the same field names as the current API endpoint.
7. Golden fixture regression: verify each endpoint response matches the golden fixture captured in T5.0 (field names, structure — values may differ due to time).
8. Silent deferral scan across all marine service files.

### QC Gate 5

- All 29 modules moved and loading: 11 providers, 12 physics, 3 enrichment, 3 config.
- Full pipeline operational.
- All 6 data endpoints return correctly shaped responses.
- Auditor: zero unresolved findings.

---

## Phase 6 — API Companion Service Proxy

**Purpose:** Build the generic companion service proxy in the API — the manifest handler that dynamically mounts routes from any companion service. Then delete all marine code from the API.

**Scratch file:** `c:\tmp\marine-sep-P6-scratch.md`

### T6.1 — Implement the manifest handler

- **Owner:** `clearskies-api-dev`
- **Files:** New file `repos/weewx-clearskies-api/weewx_clearskies_api/services/companion_proxy.py`

**Do:**
1. At API startup, when `marine_service_url` is configured in `api.conf` `[providers]`:
   - Call `GET {marine_service_url}/manifest` (no auth).
   - Parse the endpoint manifest JSON.
   - For each endpoint, dynamically create a FastAPI route under `/api/v1/`.
2. Each route handler: fetch from `{marine_service_url}{upstream_path}` with auth, cache with manifest TTL, wrap in API response envelope.
3. When `marine_service_url` not configured: no marine routes (marine features disabled).
4. When marine service unreachable at startup: log ERROR, start without marine routes. Retry every 5 minutes.
5. When the marine service becomes unreachable after startup (runtime failure): mounted routes return the last cached response (stale is preferred to no data, same principle as SWAN provider). If no cache exists, return 503 with a clear error message. Dashboard shows the stale data with a data-age indicator.
6. Support periodic manifest refresh (every 5 minutes) to pick up endpoint changes without API restart. If an endpoint is removed from the manifest, remove its route on the next refresh.
7. API auth/rate-limiting middleware applies to proxied routes identically to native routes. Proxied routes are not exempt from CORS, rate limiting, or security headers.

**Accept:**
- Manifest fetched at startup. Routes dynamically created.
- Each route proxies to marine service, wraps in envelope, returns.
- No marine routes when URL not configured.
- Runtime failure serves cached data (or 503 if no cache).
- Manifest refreshes periodically; removed endpoints are de-registered.
- Proxied routes subject to same auth/rate-limiting/CORS as native routes.

> ### ⚠ CORRECTED 2026-07-25 — the proxy's 503 and the model's `modelStatus` are different things
>
> Point 5 above says the proxy returns 503 when it has no cache. That is correct for its own
> failure mode and must NOT be extended to cover the model's.
>
> Three states are distinct and must stay distinguishable end to end. Collapsing any two of
> them re-creates the ambiguity SURF-PUBLISH-RESULTS-ONLY removed:
>
> | Situation | Correct response | Meaning to the visitor |
> |---|---|---|
> | Marine service unreachable, no cache | **503** (proxy's own) | The system is broken |
> | Marine service answered; the model has no result for that hour | **200**, null payload, `modelStatus: "unavailable"` | The system works; the model has no answer |
> | Unknown location / not configured / bad parameter | **404** | You asked for something that does not exist |
>
> **The proxy must pass the second case through untouched.** A 200 carrying
> `modelStatus: "unavailable"` is a successful proxied response, not an upstream failure —
> the proxy must not rewrite it to 503, must not treat it as a cache miss, and must not
> suppress caching of it. Equally, the proxy's own 503 must not be dressed up as a
> `modelStatus` value; a dead service is not a model gap.
>
> Add explicit test coverage for all three, in T6.2b. The failure this guards against is
> silent: every one of these still returns a syntactically valid response, so a proxy that
> conflates them looks healthy while telling the operator the wrong thing about their model.

### T6.2 — Implement response envelope wrapping and unit conversion

- **Owner:** `clearskies-api-dev`
- **Files:** `companion_proxy.py`

**Do:**
1. Marine service returns raw data in SI units (meters, seconds, Celsius).
2. Companion proxy wraps in standard API envelope (`data`, `stationClock`, `freshness`, `units`).
3. Apply unit conversion: SI → operator display units per existing unit conversion pipeline.

**Accept:**
- Proxied responses wrapped in standard envelope.
- Unit conversion applied correctly.

### ~~T6.2b — Write companion proxy tests~~ — DEFERRED TO PHASE 8 (operator, 2026-07-25)

**All test-writing happens at the end, in Phase 8. Nothing test-related runs in Phases 5, 6, or 7.**

The work itself is not cancelled — manifest parsing/route creation/malformed handling, envelope
wrapping, SI → display unit conversion, and capability merging all still need covering, against a
mock marine service with no live dependency. It happens in T8.9 after the code is built and
deployed, not interleaved with it.

### T6.3 — Implement capability merging

- **Owner:** `clearskies-api-dev`
- **Files:** Capabilities endpoint code

**Do:**
1. `/api/v1/capabilities` merges marine capabilities from manifest into the response.
2. Marine capabilities appear when service connected, absent when not.

**Accept:**
- Capabilities response includes marine when connected.

### T6.4 — Implement config push

- **Owner:** `clearskies-api-dev`
- **Files:** `endpoints/setup.py`

**Do:**
1. On `/setup/apply`: if `marine_service_url` is configured, POST marine config to `{marine_service_url}/config` with auth.
2. Failure to push logs ERROR but does not fail the apply.

**Accept:**
- Wizard apply → API → marine service `/config` push works.
- Failure does not block apply.

### ~~T6.4b(i) — Migrate marine tests from API repo to marine service repo~~ — DEFERRED TO PHASE 8 (operator, 2026-07-25)

**All test work happens at the end, in Phase 8.** Renumbered `T6.4b(i)` here because the plan
had two tasks numbered T6.4b — the other is "Marine service config recovery on restart" below,
which is unaffected and stays in Phase 6.

The migration itself still has to happen: move the marine provider / wave physics / enrichment /
endpoint tests to `repos/weewx-clearskies-marine/tests/`, repoint imports from
`weewx_clearskies_api` to `weewx_clearskies_marine`, and reset both repos' pytest baselines.
It moves to **T8.9**.

> **One coupling to respect in Phase 6.** T6.5–T6.8 delete the marine code from the API. Test
> files that import deleted modules must be removed *with* that code in the same commit —
> otherwise the API suite errors at collection for the whole of Phases 6–7 and the deletion
> looks like it broke something it didn't. Deleting orphaned test files alongside their source
> is part of the deletion, not test-writing, so it does not conflict with this deferral. Phase 8
> then restores them in the marine repo.

### T6.4b — Marine service config recovery on restart

- **Owner:** `clearskies-api-dev`
- **Added:** 2026-07-24, from Phase 4 adversarial audit finding **F5** (reverse
  check — a documented requirement belonging to no phase).
- **Files:** `endpoints/setup.py` (API side), marine service `__main__.py` /
  `config.py` (client side)

**Problem:** `OPERATIONS-MANUAL` described, as current behaviour, a mechanism
where "on marine service restart, the service fetches its config from the API via
`GET {api_url}/setup/marine/config`". Neither side of that mechanism exists —
not the API handler, not the marine service's outbound call — and it was assigned
to no task in any phase. The manual has been corrected to describe what actually
happens (local-disk reload) and to mark the fetch as a target pointing here.

**Why it still matters:** a marine service with no local config — a fresh
install, or one whose config directory was wiped — cannot recover it and serves
nothing until an operator notices and re-runs apply. Local-disk reload is correct
and verified (it survives `kill -9`), but it cannot self-heal from an empty disk.

**Do:**
1. Add `GET /setup/marine/config` to the API, authenticated with
   `MARINE_SERVICE_SECRET`, returning the same marine config subset that
   `/setup/apply` pushes (T6.4). One serializer, both paths — do not let the push
   shape and the pull shape drift.
2. On marine service startup: if no local config exists **and**
   `marine_service_url`'s peer API is reachable, fetch and persist it. If local
   config exists, use it — do not fetch on every start, and never let a fetch
   overwrite newer local config.
3. Failure to fetch logs at ERROR and the service starts without config, serving
   `/health` and `/manifest` only. It must not crash-loop.

**Accept:**
- A marine service with an empty config directory recovers its config from the
  API on startup and serves marine endpoints without operator intervention.
- A marine service with existing local config does not fetch.
- Push and pull share one serializer.
- An unreachable API at startup degrades to health-and-manifest, logged at ERROR,
  with no crash loop.
- `OPERATIONS-MANUAL`'s "(target — not yet implemented)" annotation is removed.

### T6.5 — Delete marine endpoints from API (4,245 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** Delete `endpoints/surf.py` (1,317), `beach_profile.py` (881), `marine.py` (1,040), `fishing.py` (510), `beach_safety.py` (497). Also delete `endpoints/tides.py` if it exists as a separate file.

**Do:** Delete all listed files. Remove route registrations from app. Remove dangling imports.

**Note:** If tides are served by `endpoints/marine.py` (which handles all marine list/detail endpoints), no separate `tides.py` deletion is needed — the `marine.py` deletion covers it. Verify before deleting.

**Accept:** All marine endpoint files deleted. No import errors. API starts cleanly.

### T6.6 — Delete marine provider modules from API (~9,517 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** Delete `providers/buoy/`, `providers/tides/`, `providers/marine/`, `providers/wind/`, `providers/ocean/`, `providers/nearshore/`

**Do:** Delete all marine provider directories. Remove from registry. Remove cache warmer entries. Remove imports.

**Accept:** All deleted. No import errors. Cache warmer skips marine.

### T6.7 — Delete wave physics, enrichment, and config code (~13,931 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** All modules from §0.6 sections 4.2, 4.3, 4.4

**Do:** Delete all files. Remove data files moved to marine service. Remove `[nearshore]` pip extra from `pyproject.toml`.

**Accept:** All deleted. `[nearshore]` extra removed. No import errors.

### T6.8 — Delete compute_service.py and compute_client.py (1,042 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** `services/compute_service.py` (681), `services/compute_client.py` (361)

**Do:** Delete both. Remove imports. Remove `surf_compute_host` and `surf_compute_verify_tls` from config. Remove `SURF_COMPUTE_SECRET` references.

**Accept:** Both deleted. No references to compute service in API code.

> ### ⚠ NOTE 2026-07-25 — deletion ordering within Phase 6
>
> `compute_client.py` gained one public alias (`deserialize_pipeline_result`) in
> SURF-PUBLISH-RESULTS-ONLY. Its only importer is `providers/nearshore/swan.py`'s
> `fetch_profile()`, which **T6.6 deletes**. So both sides disappear together and this is not
> a conflict — but the order matters: run T6.5/T6.6 before or with T6.8. Deleting
> `compute_client.py` first leaves a broken import in a file that is about to be deleted
> anyway, and an agent that hits it may "repair" it instead of proceeding. If you see that
> import break, the fix is to continue with T6.6, not to restore anything.

*T6.9 (api.conf cleanup) moved to Phase 8 as T8.2b — the old Part A API code needs `[swan]` and `surf_compute_host` until the new API is deployed in T8.2. Removing them during Phase 6 while the old code is deployed would break the working Part A fix.*

### Adversarial Audit — Phase 6

- **Owner:** `clearskies-auditor`

**Scope:**
1. **Zero marine code in API:** `grep -rn "swan_runner\|ndbc\|coops\|wavewatch\|hrrr\|gfs\|surfbeat\|swelltrack\|breaker_height\|surf_scorer\|wave_transform\|bathymetry_resolver\|marine_config" repos/weewx-clearskies-api/weewx_clearskies_api/` — zero matches (excluding companion_proxy and config references to `marine_service_url`).
2. Zero hardcoded marine endpoints.
3. Manifest handler works. Envelope wrapping correct. Unit conversion correct.
4. Capability merging works. Config push works.
5. `compute_service.py` and `compute_client.py` deleted.
6. Marine tests migrated to marine service repo (T6.4b).
7. Silent deferral scan across ALL API files.
8. Runtime failure behavior: verify API serves cached data when marine service is unreachable after startup.

### QC Gate 6

- API contains zero marine physics code (grep verified).
- API contains zero marine provider modules (grep verified).
- Companion proxy dynamically mounts routes from manifest.
- Proxied responses wrapped correctly with unit conversion.
- Runtime failure serves cached data (or 503 if no cache).
- Manifest periodic refresh works. Proxied routes subject to auth/rate-limiting.
- Capabilities merged. Config push works.
- Compute service artifacts deleted. Marine tests migrated.
- Auditor: zero unresolved findings.
- Note: api.conf cleanup deferred to T8.2b (after API deploy).

---

## Phase 7 — Wizard/Admin Updates

**Purpose:** Update the config UI for the new marine service architecture.

**Scratch file:** `c:\tmp\marine-sep-P7-scratch.md`

> ### ⚠ CORRECTED 2026-07-25 — the owner column below is wrong for T7.1–T7.6
>
> Every task in this phase names `clearskies-docs-author` as owner. That agent's role is
> hard-scoped to documentation and explicitly forbids code changes, routing them "to the dev
> agents via the lead." T7.1–T7.6 are Python route handlers, Jinja templates, HTMX wiring and
> client-side validation. The assignment was unexecutable as written.
>
> **Found at dispatch by the docs-author agent itself, which refused the work rather than
> stretching its scope — the correct call.** "A document assigns it to me" is not authorization
> to act outside a stated constraint, by exactly the reasoning the architectural-change block
> applies to "a plan says so."
>
> **Corrected ownership for this phase:**
>
> | Work | Owner |
> |---|---|
> | Wizard and admin **code** — `wizard/routes.py`, `admin/routes.py`, `state.py`, `state_persistence.py`, `config_writer.py`, all Jinja templates and their client-side script | stack implementation agent (general-purpose; the stack repo has no dedicated dev role) |
> | The 13 translation files and `OPERATOR-MANUAL.md` | `clearskies-docs-author` — and it runs **after** the code, because the locale files are keyed by English source string and those strings do not exist until the templates are written |
> | API halves of T7.2 / T7.3 / T7.6 — apply models, `api.conf` writing, `/setup/providers/test-marine`, the apply response's push-outcome field | `clearskies-api-dev` |
>
> §0.3's agent-assignment table carried the same error and is corrected there too.

### T7.1 — Rename "Wave Modeling" to "Marine Service" in wizard

- **Owner:** stack implementation agent (was: `clearskies-docs-author` — see the correction above)
- **Files:** `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_providers.html`, translation files (13 locales)

**Do:** Rename section. Update i18n keys. Update help text.

**Accept:** Wizard shows "Marine Service" not "Wave Modeling". All 13 locales updated.

### T7.2 — Unify URL fields

- **Owner:** `clearskies-docs-author`
- **Files:** `step_providers.html`, `wizard/routes.py`, `endpoints/setup.py`

**Do:**
1. Replace `surf_compute_host` + `service_url` with single `marine_service_url`. Secret field: `MARINE_SERVICE_SECRET`. Update API's `ApplyRequest` Pydantic model.
2. Add a "Same host" checkbox that auto-fills `https://localhost:8780` when checked.

**Accept:** Single URL field. "Same host" checkbox auto-fills localhost URL. Apply payload sends `marine_service_url`. API Pydantic model accepts it.

### T7.3 — Update Test Connection

- **Owner:** `clearskies-docs-author` + `clearskies-api-dev`
- **Files:** `step_providers.html`, `endpoints/setup.py`

**Do:** Change to test marine service health: `POST /setup/providers/test-marine` → `GET {marine_service_url}/health`. Returns version, spots, status.

**Accept:** Test Connection tests marine service health. Returns useful info on success/failure.

### T7.4 — Add validation: blank URL is error when marine features enabled

- **Owner:** `clearskies-docs-author`
- **Files:** `step_providers.html`, `wizard/routes.py`

**Do:** Require Marine Service URL when any marine feature is enabled. Validation client-side and server-side.

**Accept:** Validation error shown when marine features enabled but URL blank.

### T7.5 — Update admin providers section

- **Owner:** `clearskies-docs-author`
- **Files:** `admin/providers.html` or `admin/marine.html`, `admin/routes.py`

**Do:** Rename to "Marine Service". Single URL. Secret update. Test connection. Status display.

**Accept:** Admin shows "Marine Service" with unified URL. Test connection works.

### T7.6 — Config push on apply

- **Owner:** `clearskies-docs-author` + `clearskies-api-dev`

**Do:** Wizard/admin apply → API → marine service `/config`. Show push result in UI feedback. Failure does not block local save.

**Accept:** Config push works end-to-end. Success/failure shown in UI.

### Adversarial Audit — Phase 7

- **Owner:** `clearskies-auditor`

**Scope:**
1. "Wave Modeling" appears nowhere in wizard or admin. Only "Marine Service."
2. Single URL field `marine_service_url`, not two URLs.
3. Test Connection tests marine service, not old compute service.
4. Blank URL + enabled marine = validation error.
5. Secret goes to `secrets.env` as `MARINE_SERVICE_SECRET`.
6. Config push works end-to-end.
7. Pydantic model sync — no 422 errors.
8. Silent deferral scan.

### QC Gate 7

- "Marine Service" naming throughout. Single URL field.
- Test Connection works. Validation works.
- Secret in `secrets.env`. Config push works.
- All 13 locales updated. Pydantic models accept new fields.
- Auditor: zero unresolved findings.

---

## Phase 8 — Deploy + Clean Up

**Purpose:** Deploy everything, clean up old architecture artifacts, verify end-to-end.

**Scratch file:** `c:\tmp\marine-sep-P8-scratch.md`

### T8.1 — Deploy marine service to librewxr

- **Owner:** Coordinator (Opus) — with user approval

**Do:**
1. Create deploy script `scripts/deploy-marine.sh`.
2. Clone `weewx-clearskies-marine` on librewxr. Install with `pip install -e ".[nearshore]"`.
3. Install systemd unit. Generate `MARINE_SERVICE_SECRET` on both hosts.
4. Generate TLS cert. Start service on port 8780.
5. Verify: health OK, manifest returned.

**Accept:** Marine service running on librewxr:8780. Health and manifest endpoints working. TLS and auth verified.

### T8.1b — Verify librewxr memory capacity

- **Owner:** Coordinator (Opus)

**Do:**
1. Before deploying the unified marine service alongside old services, check current memory usage on librewxr without the old SWAN+compute services running.
2. Estimate projected memory for the unified marine service based on the component sizes (SWAN runner, provider modules, enrichment pipeline).
3. Evaluate whether LibreWxR main process (3.3 GB) can be moved or its memory reduced to provide headroom.
4. Document: current usage, projected usage, swap pressure assessment.

**Accept:** Unified marine service runs without swap pressure. Memory assessment documented. If headroom is insufficient, document mitigation plan before proceeding.

### T8.2 — Deploy API to weewx

- **Owner:** Coordinator (Opus) — via `scripts/deploy-api.sh`

**Do:** Deploy API with marine code removed and companion proxy added. Verify manifest fetch from `https://192.168.7.22:8780/manifest`, dynamic route mounting.

**Accept:** API deployed and healthy. Manifest fetched. Marine routes available.

### T8.2b — Clean up api.conf

- **Owner:** Coordinator (Opus)
- **Files:** `/etc/weewx-clearskies/api.conf` on weewx

*Moved from Phase 6 (was T6.9). The old Part A API code needed `[swan]` and `surf_compute_host` — removing them before the new API is deployed (T8.2) would break the working Part A fix.*

**Do:**
1. Remove `[swan]` section.
2. Replace `surf_compute_host` + `surf_compute_verify_tls` with `marine_service_url = https://192.168.7.22:8780` in `[providers]`.
3. Store `MARINE_SERVICE_SECRET` in `secrets.env` (replacing `SURF_COMPUTE_SECRET`).

**Accept:**
- `api.conf` has `marine_service_url`, no `[swan]`, no `surf_compute_host`.
- `secrets.env` has `MARINE_SERVICE_SECRET`.

### T8.3 — Deploy dashboard + config UI to weather-dev

- **Owner:** Coordinator (Opus) — via `scripts/redeploy-weather-dev.sh`

**Do:** Deploy dashboard (no changes expected) and config UI (Marine Service naming). Verify surf page and wizard.

**Accept:** Dashboard and config UI deployed. Surf page renders. Wizard shows "Marine Service."

### T8.6 — E2E verification

- **Owner:** Coordinator (Opus)
- **Status: RUN 2026-07-26 — FAILED.** Findings in C-85 (capability surface empty end to end) and
  C-81/C-86 (surf output physically wrong: one swell train, 3.83-4.24 ft flat against a real 4-6 ft).
  **T8.6 must RE-RUN after T8.10 lands** — T8.10 changes the very output T8.6 verifies, so the pre-T8.10
  result cannot be carried forward. QC Gate 8 requires the re-run to pass.

**Ordering (operator ruling 2026-07-26):** T8.6 is **no longer a gate on T8.4/T8.4b/T8.5**. The gate
existed because the old services were a rollback path; they reproduce the same defect, so they were never
a rollback path for it, and this environment carries no live traffic. Decommissioning proceeds
independently.

**Do:**
1. Wait for a marine service SWAN cycle to complete.
2. Verify all marine endpoints return data via the companion proxy.
3. Verify the dashboard renders all marine tabs with real data.
4. Verify marine capabilities appear in `GET /api/v1/capabilities` (**blocked on C-85 — see the scope
   note below**).
5. Verify physical plausibility against reality rather than self-consistency — T8.10h's criteria.

**Scope note, do NOT bypass:** C-85's capability-surface fix needs its own **trigger-4** ruling on where
the capability list derives from. The 2026-07-26 ruling authorized T8.10's scope only. "T8.6 cannot pass
without it" is a **named non-excuse** — surface it and wait; do not implement it under this task.

**Accept:** All marine endpoints return data. Dashboard renders the complete marine page. T8.10h's
reality checks pass. Any item deferred on a pending ruling is named explicitly, never silently skipped.

### T8.4 — Stop and disable old services on librewxr

- **Owner:** Coordinator (Opus) — with user approval

**Prerequisite: NONE. Unblocked by operator ruling 2026-07-26** — see T8.6's ordering note. The former
"T8.6 must pass first" prerequisite is void, and C-70's stop-not-disable posture is retired.

**Do:**
1. Verify the actual unit names on librewxr first (`systemctl list-units 'weewx-clearskies-*'`) — the old
   repo was renamed to `weewx-clearskies-swan-swelltrack`, so do not assume unit names.
2. Stop and disable the old SWAN service on 8767.
3. Stop and disable the old compute service on 8770.
4. Verify ports 8767 and 8770 are not listening.

**Rollback:** None, and none is needed. The old services reproduce the same boundary defect (C-86), so
re-enabling them restores nothing. If the marine service fails, fix it forward.

**Accept:** Old services stopped and disabled by their verified real unit names. Neither port listening.

### T8.4b — Archive the old SWAN repo on librewxr

- **Owner:** Coordinator (Opus) — with user approval

**Do:**
1. After T8.4 disables the old SWAN service, archive the old SWAN repo on librewxr. **Verify the real
   directory name before moving anything** — the repo was renamed to `weewx-clearskies-swan-swelltrack`
   on local, GitHub and librewxr, and the `.pth` install path was updated after the rename, so the old
   `weewx-clearskies-swan` path may not exist.
2. Move it under `/home/ubuntu/repos/archived/` preserving its actual directory name.
3. Create the `archived/` directory if it does not exist.

**Accept:** Old repo moved to archived directory. Git history preserved. No files left at original path.

### T8.5 — Clean up weewx filesystem (AFTER E2E verification)

- **Owner:** Coordinator (Opus) — with user approval

**Prerequisite: NONE. Unblocked by operator ruling 2026-07-26** — see T8.6's ordering note.

**Do:**
1. Remove `swan.disabled` from `/usr/local/bin/`.
2. Remove `/var/run/weewx-clearskies/swan/`.
3. Remove `/etc/weewx-clearskies/swan_bathymetry_*.json`.
4. Remove `/etc/weewx-clearskies/spot_profiles/`.
5. Remove `SURF_COMPUTE_SECRET` from `secrets.env`.

**Accept:** No SWAN artifacts on weewx. `secrets.env` has `MARINE_SERVICE_SECRET` only.

### T8.7 — Surfline comparison — **SUPERSEDED by T8.10h; runs after T8.10**

- **Owner:** Coordinator (Opus)

**Why superseded:** "Face height within +/-30% of Surfline" **passes on the known-defective output**, so it
cannot gate anything. Measured 2026-07-26: we published 3.83-4.24 ft against Surfline's 4-6 ft — inside
+/-30% of any midpoint reading of that range — while the forecast was flat for 14 hours and carried one
swell train instead of three. The criterion tests central height only, which was never the failure mode
(C-81, C-86). It is also ambiguous: +/-30% of *which* number in a range?

**Do:** Nothing separately. Execute **T8.10h**, which compares period structure, component count and
temporal variation as well as height, after T8.10 has changed the boundary source.

**Accept:** T8.10h's criteria. This task closes by reference, not by its own measurement.

### T8.9 — All deferred test work (operator directive, 2026-07-25)

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-marine/tests/`, `repos/weewx-clearskies-api/tests/`

**No test work happens in Phases 5, 6, or 7.** It all lands here, after the code is built and deployed.

**Ordering — corrected 2026-07-26.** The original rationale ("runs after T8.6 so tests are written against
behaviour already proven working") is now false in both directions: T8.6 failed, and T8.10 changes the
behaviour afterward. **T8.9 runs after T8.10**, otherwise it resets pytest baselines that T8.10
immediately breaks.

**Do:**
1. **From T6.4b(i)** — migrate the marine provider / wave physics / enrichment / endpoint tests
   from the API repo to the marine repo, repointing imports to `weewx_clearskies_marine`.
   (Phase 6 deleted the ones that pointed at deleted source; those get reinstated here.)
2. **From T6.2b** — companion proxy tests against a mock marine service, no live dependency:
   manifest parsing, route creation, malformed manifests, envelope wrapping, SI → display unit
   conversion, capability merging.
3. **From T8.10** — tests for the new boundary path, none of which existed when this task was written:
   the `.spec` parser for both products (ocean `50 36`, GLWU `32 36`); the malformed/truncated-file
   **raise** path; station-catalogue build and resume; the GLWU hourly vs ocean 6-hourly cycle branch; and
   the configuration-time viability **refusal** paths. Note the marine repo has **no tests for `swan.py`
   or the runner at all**, so the C-76/C-77 raise paths are also uncovered and land here.
4. Reset both repos' pytest baselines to the new counts.

**Accept:**
- Marine repo suite passes; API repo suite passes with no regressions in retained tests.
- Both baselines recorded in the plan as **new** counts — they will change, since T8.10 adds code.
- Every new failure path from T8.10 and from C-76/C-77 has a test asserting that it raises.

### T8.10 — WW3 spectral boundary: stop parameterising a spectrum WW3 already computes

**Added to Phase 8 by operator decision, 2026-07-26.** Origin: C-86 / C-87 and
[briefs/WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md](briefs/WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md), which carries all
the measured data, the SWAN-manual citations and the resolved design questions. **Read the brief before
starting any subtask.**

**Operator ruling on scope and on the T8.6 ordering constraint (2026-07-26):** *"So this is a test
environment. We can take things down. There is no reason to continue these services, especially in light
of the fact that it is all bogus data right now, and the surf page does not work anyway with the current
arrangement. So it is not like we are blanking out data for existing web traffic. This should get
incorporated into Phase 8."* The rule that T8.6 must pass before T8.4/T8.5 existed because the old services
were the rollback path; they reproduce the same defect, so they were never a rollback path for it. **T8.4 /
T8.4b / T8.5 are unblocked and proceed independently of T8.6.**

**Why:** `providers/marine/wavewatch.py` fetches a PacIOOS 0.5° republication of legacy `NWW3_Global_Best`
that reports **one averaged swell**. At the L1 boundary point it gave `sper` **12.73 s** — the weighted mean
of a 19.11 s groundswell and a 6.39 s wind swell, a period matching no wave in the water. Real WW3 publishes
the full 2-D directional spectrum. Period governs shoaling and breaking height far more than offshore
height, so this one substitution produced surf 3.83–4.24 ft (flat for 14 h) against a real 4–6 ft with sets.

#### T8.10a — Station catalogue discovery

- **Owner:** `clearskies-api-dev` (marine repo)

**Do:** Build a cached catalogue of WW3 spectral station locations for both products.
Directory listing gives IDs (~4,036 ocean, ~115 Great Lakes); an HTTP **range request for bytes 0–120** of
`<station>.bull` gives `Location : 46222      (33.62N 118.32W)` — ~100 bytes instead of 7.75 MB. Reuse the
existing discovery-cache pattern (`/discovery/buoy-stations` caches at 86400 s) and the existing NDBC
lat/lon metadata, since many `gfswave` IDs *are* NDBC IDs. Respect the existing 2 req/s limit; a cold build
is ~35 min and belongs at configuration/discovery time, **never** in the forecast cycle.

**Accept:** Catalogue persists across restarts; a cold build is resumable; no station probe fetches a
`.spec`; rate limit honoured.

#### T8.10b — Fetch and parse the WW3 2-D spectrum

- **Owner:** `clearskies-api-dev` (marine repo)

**Do:** Fetch the selected station's `.spec` and parse it. Format is self-describing and **identical for
both products**, so **one parser, no format branching**:

```
'WAVEWATCH III SPECTRA'     50    36     1 'spectral resolution for points'
 <nfreq frequencies>            ocean: 0.035..0.964 Hz (28.6 s .. 1.04 s)
 <ndir directions>              36 bins
20260726 060000
'46222     '  33.62-118.32     487.9   2.20 143.8   0.03 285.6
 <nfreq x ndir energy densities>
```

Per-timestep header carries **id, lat, lon, depth (m), wind speed/dir, current speed/dir**.
Ocean: `/gfs.YYYYMMDD/CC/wave/station/bulls.tCCz/gfswave.<ST>.spec` (7.75 MB).
Great Lakes: `/glwu.YYYYMMDD/bulls.tCCz/glwu.<ST>.spec` (1.94 MB, `32 36`).

**Never fetch the tarballs** — `spec_tar.gz` is 1.72 GB, `ibp_tar` is 11.37 GB.

**Station files vs gridded files — we need BOTH, for different consumers (operator question, 2026-07-26).**
NOAA publishes two wave families and they are not substitutes:

| | Station `.spec` | Gridded GRIB2 |
|---|---|---|
| Carries | **full 2-D spectrum** E(f,theta) | bulk `HTSGW/PERPW/DIRPW` + 3 swell partitions — **no spectrum** |
| Available | fixed buoy/output points | anywhere on a 0.25 deg / 0.16 deg grid |
| Consumer | **SWAN L1 boundary** (T8.10c) | **`endpoints/marine.py` offshore forecast** (T8.10i) |

The SWAN boundary requires station files — gridded physically cannot supply a spectrum. The `/marine`
offshore forecast is bulk by nature and needs coverage at arbitrary spots, which is what gridded is for.
**Neither is a fallback for the other**, and neither may substitute for the other on failure.

**Also measure and record GLWU's frequency array.** Only its bin counts (`32 36`) have been observed; the
actual frequency range is unmeasured, so T8.10d's accept cannot be evaluated for GLWU until it is. If
GLWU's top bin exceeds 1.0 Hz, raise it rather than silently widening `CGRID`'s upper bound — that bound is
tied to the WAM Cycle 4 source-term retuning and is not ours to move.

**Accept:** Both products parse with the same code path; integrated spectral m0 reconciles with the
`.bull` bulk Hs for the same station/timestep; a malformed or truncated file **raises** (rules/coding.md §1),
never returns a partial spectrum.

#### T8.10c — Write a real spectral boundary; delete the synthesised one

- **Owner:** `clearskies-api-dev` (marine repo)
- **Files:** `services/swan_formats.py`

**Do:** Emit the 2-D spectrum as SWAN's boundary file and drive L1 with
`BOUNDSPEC SIDE ... CONSTANT FILE` (manual: *"the wave spectra are constant along the side or segment"*).
**`ww3_to_swan_boundary()`'s synthesised JONSWAP peak and its fixed 30° `DSPR` are both deleted** — nothing
is synthesised any more. Remove the "prefer swell parameters" overwrite at the old lines 1596–1600.

**`BOUNDNEST3` is NOT usable and must not be attempted.** The manual accepts a WW3 output location *"only
if the SWAN grid point on the nest boundary lies within a rectangle between two consecutive WAVEWATCH III
output locations with a width equal to 0.1 times the distance between these output locations"* — station
points do not lie on our boundary. A uniform offshore spectrum is documented standard practice, with
peer-reviewed precedent for driving nearshore SWAN from a single directional spectrum (J. Atmos. Ocean.
Tech. 38(12), 2021). L2/L3 `BOUNDNEST1` nesting is unchanged.

**Accept:** No parametric TPAR path remains for L1; no `DSPR` constant anywhere; SWAN reads the spectral
file without boundary warnings.

#### T8.10d — Widen `CGRID` low frequency to 0.03 Hz

- **Owner:** `clearskies-api-dev` (marine repo)

**Do:** Our `CGRID` runs 0.0418–1.0 Hz (23.9–1.0 s). WW3's lowest bin is **0.035 Hz**, *below* our cutoff,
so today we would truncate exactly the long-period energy this task recovers. Set the low end to
**0.03 Hz**; keep the 1.0 Hz upper (the manual's WAM Cycle 4 source terms are retuned for ~1 Hz, so the
upper bound must not move).

**Also state, do not guess:** whether the number of frequency bins changes when the low end widens from
0.0418 to 0.03 Hz, or whether the existing count is redistributed. SWAN interpolates incoming spectral
frequencies (documented for `BOUNDNEST1`), so both are defensible — but the choice must be recorded, not
left implicit. Runtime cost scales with bin count and `omp_num_threads = 6` is an operator ruling that
must not be touched to compensate.

**Accept:** No incoming WW3 frequency bin falls outside `CGRID`, for **both** products (ocean and GLWU —
see T8.10b's measurement item); upper limit still 1.0 Hz; bin-count decision recorded.

#### T8.10e — Great Lakes routing via GLWU

- **Owner:** `clearskies-api-dev` (marine repo)

**Do:** Route Great Lakes spots to GLWU. Measured 2026-07-26 at Lake Michigan (43.0 N, 87.0 W):
`gfswave.global.0p25` returns **9999** for `swh` and every partition, PacIOOS returns **null** — global
ocean models mask inland water, so Great Lakes spots have **never** had a WW3 boundary. Precedent for the
water-body decision exists in the bathymetry chain (USGS Great Lakes topobathy vs NCEI/CUDEM).
**GLWU cadence is hourly** (`bulls.tCCz`, 00–14z observed) against the ocean product's 00/06/12/18z — the
runner's cycle logic assumes 6-hourly and must branch.

**A Great Lakes spot must actually be configured for this to be checkable.** None is configured today, and
the brief calls Great Lakes support "currently theoretical". Configuring one pulls in the Great Lakes
bathymetry chain, grid sizing and cluster viability. **If that turns out to be more than a config entry,
stop and report** — standing up a new water body is not in T8.10's authorized scope, and T8.10e/T8.10h#6
would then be deferred with that stated explicitly rather than silently skipped.

**Accept:** A Great Lakes spot produces a real spectral boundary where it previously produced none; cycle
selection correct for both cadences. If deferred for the reason above, the deferral is recorded in the plan
and in the concerns register, not left implied.

#### T8.10f — Configuration-time viability, no silent degradation

- **Owner:** `clearskies-api-dev` (marine repo) + `clearskies-docs-author`

**Do:** Station selection is **depth-led**, not distance-led — the `.spec` header supplies depth per
timestep, and published practice initialises SWAN from buoy data in ~550 m (station 46222 is 487.9 m,
~20 km offshore). Where no suitable station exists, the spot is **not supportable**: fail at configuration
time and tell the operator, with the chosen station's id, distance and depth surfaced at setup. Same shape
as the existing L3 cluster viability test.

**It must never fall back to the gridded bulk product.** That reintroduces the averaged-away groundswell
with different provenance — per rules/coding.md §1 and the C-76/C-77 rulings.

**Record in the provider docs:** deep water needs d > 1.56 T²/2, so 28.6 s wants **638 m** and 488 m does
not satisfy it — the longest bins arrive already depth-influenced. True of any buoy on a narrow shelf;
state it rather than let it be discovered.

**Setup-time grid probe — operator direction, 2026-07-26:** *"I think we need to do a grid fetch at setup,
just to verify we have data for that location."*

Do a **real fetch** of the resolved tier grid at the spot's coordinates during setup and confirm the value is
**not the missing sentinel**. This is not a coverage calculation from a bounding box — it is an actual read,
because a point can be inside a grid's declared extent and still carry no wave data.

**Proof the check is necessary and that it works** (measured 2026-07-26): at Lake Michigan (43.0 N, 87.0 W),
`gfswave.global.0p25` returns **9999** for `swh` and every swell partition, and the PacIOOS source returns
**null** — both points sit well inside the declared global extent. Nothing but a real read distinguishes
"covered" from "has data".

**`9999` means TWO different things and conflating them breaks the probe.** It is the GRIB
`missingValue` sentinel (read directly off the message header, confirmed `missingValue 9999`), but the reason
a field is missing differs, and only one of them means "no data at this location":

| Measured 2026-07-26 | `swh` (total) | partition fields | Means |
|---|---|---|---|
| Lake Michigan 43.0 N, 87.0 W | **9999** | all 9999 (`shts`/`mpts` 1,2,3) | **point is not in the model's water** — land-masked. Reject the spot. |
| Huntington 33.5 N, 118.5 W | **0.78** | `shts` 0.61/0.38/0.23 real, but `shww`/`mpww`/`wvdir` **9999** | **valid ocean point**; the wind-sea partition simply does not exist this hour. Accept the spot. |

**Therefore the probe must test `HTSGW` / `swh` — total significant wave height — and nothing else.** It is
present whenever the point is in the model's water. **Probing a partition field instead would wrongly reject
valid ocean spots on any hour with no wind swell**, which is most summer mornings at Huntington.

**What the probe must catch:**
- `swh == missingValue` → the point is not in this model's water. Land-masked cells, and enclosed water
  bodies the ocean model masks, which is every Great Lakes spot. Reject, or route to GLWU.
- A spot outside the resolved tier's latitude band — a Tier 1 probe at 53 N returns nothing, and selection
  must land on Tier 2 rather than reading the empty result as "no data anywhere".

**Separately, in the ingest path:** `missingValue` must never be ingested as data anywhere. A 9999 m wave
height reaching SWAN's boundary would be catastrophic. Read the sentinel from the GRIB `missingValue` key
rather than hardcoding 9999, and mask on it. A **missing partition is normal and is reported as absent**; a
missing **total** during a live cycle is a failure and **raises** (rules/coding.md section 1).

**Cost:** trivial. A `filter_gfswave.pl` subregion subset spanning ~3 deg x 3 deg with nine variables measured
**4,577 bytes**. Run once per spot at setup, not per cycle.

**Where it belongs:** the marine service already advertises **`GET /discovery/grib-availability`** with
`cache_ttl: 0` in its manifest. **Extend that endpoint** rather than adding a new one — check what it does
today before writing anything, since reusing it keeps this inside the authorized scope instead of adding an
endpoint (trigger 7).

**Both halves of viability are checked at setup, and both can refuse a spot:**

| Probe | Confirms | Feeds |
|---|---|---|
| **Gridded fetch** (this item) | the tier grid has non-missing data at the spot | `/marine` offshore forecast (T8.10i) |
| **Station lookup** (above) | a suitable deep-water station exists within range | SWAN L1 boundary (T8.10c) |

A spot that fails **either** probe is refused at setup with a message naming which probe failed and why. A
spot may legitimately pass one and fail the other — e.g. gridded data present but no station near enough —
and the message must say which, because the remedies differ.

**Thresholds are NOT the implementer's to choose.** The ruling authorized the viability check's
*existence*, not the numbers in it. A minimum station depth and a maximum station distance are constants
inside a physics-derived criterion (trigger 1). **Propose values with their basis and wait for the
operator.** Published precedent is ~550 m; station 46222 is 487.9 m at ~20 km.

**Cross-repo ownership — the operator-facing half is not in this repo.** Surfacing the chosen station's id,
distance and depth at setup crosses marine → API → config UI, and per the C-42 invariant nothing but the
API talks to the marine service. **`clearskies-api-dev` (API repo) and the config-UI owner must be
dispatched for that half**; this subtask alone cannot deliver it.

**Accept:**
- No code path substitutes bulk data for a missing spectrum.
- **A setup-time gridded probe actually fetches and reads the tier grid at the spot**, and `9999` is
  recognised as missing rather than ingested. Verified against a Great Lakes coordinate, which must fail the
  ocean-grid probe and route to GLWU.
- Unsupportable spots are refused at config time with a message naming **which** probe failed (gridded or
  station) and why, plus the nearest station's id, distance and depth.
- Depth/distance thresholds carry a recorded operator decision, not an implementer default.

#### T8.10i — Re-source `endpoints/marine.py` off PacIOOS onto gridded WW3

- **Owner:** `clearskies-api-dev` (marine repo)
- **Files:** `endpoints/marine.py`, `providers/marine/wavewatch.py`

**Found by the Fable review, 2026-07-26 — an unowned consumer of the contract change.**
`wavewatch.fetch()` has three call sites in `endpoints/marine.py` (~:217/:219, ~:431/:433, ~:570/:572)
feeding the offshore marine forecast, source-labelled `"wavewatch+ndbc+nws_marine"` (~:645). T8.10b changes
that function's return shape and T8.10c owns only `swan_formats.py`, so without this subtask the change
either breaks `/marine` or leaves the misdescribed PacIOOS source alive — the exact thing T8.10g exists to
eliminate.

**Do:** Point this consumer at **gridded** WW3 using the two-tier selection below, and at **GLWU gridded**
for Great Lakes. Keep bulk fields bulk; expose the three swell partitions where the
response shape already has somewhere to put them, and do **not** invent new fields under this task.
Delete the PacIOOS/ERDDAP fetch path once no consumer remains.

**Authorized by the operator, 2026-07-26:** *"ok the marine forecast fix needs to be included in phase 8 as
well."* Re-sourcing this consumer is in scope for Phase 8 — it is no longer a scope flag to surface.

**One residual boundary that IS still a ruling:** if serving the three gridded partitions to `/marine`
requires **new response fields** (as opposed to filling shape the response already has), that is a further
trigger-4 data-contract decision. Stop and report *that specific case* only; the re-sourcing itself
proceeds.

**Accept:** No consumer of `wavewatch.fetch()` reads PacIOOS. `/marine` returns data at arbitrary spots
including the Great Lakes, where it previously returned nulls. No new response fields added without a
ruling.

**Grid resolution tiering — operator direction, 2026-07-26.** Verbatim: *"the current source we are using IS
GLOBAL, we just need to specify the right files. If we have the ability to get more accurate and detailed
grid files for large parts of the world, which would be the mid latitude areas, then let's do that... and we
use the .25 degree files for the remaining parts of the world (well other than Great Lakes which as its own
files)."*

**Correction to the record:** the PacIOOS source **is** global. Its defects are **resolution** (0.5 deg) and
**averaging the swell partitions into one triple** — not coverage. Earlier plan/brief wording that framed the
finer NOAA grids as "regional models we ruled out" was a coordinator mischaracterisation; tiering resolution
by location is not substituting a regional model for global coverage.

All extents below measured live from the GRIB messages on 2026-07-26:

| Grid | Type | Latitude | Longitude | Increment | Use |
|---|---|---|---|---|---|
| `gfswave.global.0p16` | regular_ll | 52.5 N .. 15.0 S | all | **0.1667 deg** | **Tier 1** |
| `gfswave.global.0p25` | regular_ll | **+90 .. -90** | all | 0.25 deg | **Tier 2 (baseline)** |
| `glwu.grlc_2p5km` | unstructured | Great Lakes | — | ~2.5 km | **Great Lakes** |
| `gfswave.gsouth.0p25` | regular_ll | -10.5 .. -79.5 | all | 0.25 deg | **not used** — same resolution as Tier 2 |
| `gfswave.wcoast.0p16` | regular_ll | 50 .. 25 N | 210-250 E | 0.1667 deg | **not used** — wholly inside Tier 1 |
| `gfswave.atlocn.0p16` | regular_ll | 55 .. 0 N | 260-310 E | 0.1667 deg | deferred — gains only +2.5 deg latitude, Atlantic only |
| `gfswave.epacif.0p16` | regular_ll | 30 N .. 20 S | 130-215 E | 0.1667 deg | deferred — gains only +5 deg latitude, Pacific only |
| `gfswave.arctic.9km` | **polar_stereographic** | Arctic | — | ~9 km | deferred — finer than Tier 2 but a different projection; needs its own decision |

**Selection rule:** a spot at latitude within 52.5 N .. 15.0 S uses **Tier 1**; anything outside uses
**Tier 2**; Great Lakes spots use **GLWU**. Tier 1 is ~1.5x finer than Tier 2 and ~3x finer than the PacIOOS
source it replaces.

**This is tiering, NOT a runtime fallback — the distinction is load-bearing.** The tier is resolved
**deterministically from the spot's coordinates at configuration time** and recorded. If the chosen grid's
fetch fails at runtime it **raises**; it must never quietly fall through to a coarser grid. A silent
coarse-grid substitution is the same class of defect as C-76's calm boundary and C-86's averaged swell — the
answer would change without anyone being told. See `rules/coding.md` section 1.

**`atlocn` / `epacif` / `arctic` are deferred, not rejected.** Each is genuinely finer than Tier 2 in its
area. They are held back because two grids cover the requirement and each addition costs another fetch path
(and, for `arctic`, projection handling). Revisit if a configured spot falls in one of their exclusive areas.

#### T8.10j — Invalidate pre-T8.10 model state at deploy

- **Owner:** Coordinator (Opus)

**Found by the Fable review, 2026-07-26.** The marine service persists model output disk → Redis → memory
and restores it on startup, and SWAN carries hotstart state across runs. Deploying T8.10 without clearing
that state means T8.10h could validate **pre-fix output** and pass.

**Do:** Before the first post-T8.10 cycle, archive (do not delete) `forecast_cache.json`, clear the Redis
last-good entry, and remove L1/L2/L3 hotstart files — the procedure already used for the C-76 reset, which
archived to a timestamped `swan-precleanup-*` directory. **Keep** bathymetry caches, `swan_grid_sizing.json`
and `spot_profiles/` — expensive to rebuild and unaffected by a boundary-source change. Confirm the service
logs a cold start.

**Accept:** First post-T8.10 cycle starts cold, with `last_run: null` before it begins. Prior cache
archived, not destroyed.

#### T8.10g — Doc sync (mandatory, same phase)

- **Owner:** `clearskies-docs-author`

**Do:** Rewrite **PROVIDER-MANUAL §14.3**, which currently documents the PacIOOS 0.5° bulk republication as
"WaveWatch III forecasts" — that is how this survived. Update §14.15 (SWAN runner boundary inputs),
ARCHITECTURE.md, and any capability/field lists touched by the contract change.

**Accept:** No governing document still describes a parametric TPAR boundary or the PacIOOS source.

#### T8.10h — Validate against reality, not against the model

- **Owner:** Coordinator (Opus)

Per `rules/clearskies-process.md` "Validate against reality, never against the model's own output". A
conservation check **cannot** detect a missing input and did not — see C-83.

**Accept:**
1. Published swell list contains a **19 s ± 1 s SSW train** on a day WW3 shows one, height within ~30% of
   the WW3 partition.
2. Published surf height overlaps Surfline's stated range **and its range width is comparable** — not
   merely touching at one end. The defective output (3.83-4.24 ft vs 4-6 ft) technically overlapped at
   4.0-4.24 while being wrong, so overlap alone is not a criterion. Variation must **track WW3 partition
   arrival and tide**, not be satisfied by a single outlier: the pre-fix run had exactly one 6.04 ft step
   in 67 and was otherwise flat.
3. Component count **tracks WW3's station partition count within +/-1** across the forecast, neither
   pinned at 1 nor fixed at 3. State the comparison basis in the result: SWAN's watershed partitioning of
   its own SPECOUT need not exactly equal the WW3 station partition count even when both are correct, so
   this is a distribution check, not an equality check.
4. Component periods are **distinct** (the T4B.2 failure signature was Tp 10.2/10.2/10.1 s).
5. C-83's fixes land first, so the closure test cannot report PASS on a degenerate sample. **This subtask
   owns them** — no other task does. Specifically, in `scripts/verify_energy_closure_deployed.py`: report
   the single-vs-multi-component split in the headline, return `INCONCLUSIVE` rather than `PASS` when the
   multi-component sample is too small (the 2026-07-26 run was n_multi=1 and reported PASS), and add the
   independent comparison of component count, period and direction against the WW3 station partitions —
   which would have caught C-86 immediately.
6. A **Great Lakes** spot produces a real boundary.

### Adversarial Audit — Phase 8

**Scope extension for T8.10 (added 2026-07-26 after the Fable review).** The audit and QC Gate 8 as
originally written check only old-architecture cleanup and would pass with T8.10 half-done. Add:

- `grep` the marine repo for `pacioos`, `pae-paha`, `erddap`, `TPAR`, `DSPR`, `ww3_to_swan_boundary`,
  `JONSWAP` in the boundary path — the first five must be **absent** from live code.
- Confirm no governing document still describes a parametric boundary or the PacIOOS source (T8.10g's
  accept is otherwise unverified by any gate).
- Confirm the station catalogue persists across a service restart and that no forecast-cycle code path
  builds it.
- Confirm `CGRID` low frequency is 0.03 Hz and the upper bound is still 1.0 Hz.
- Confirm T8.6 **re-ran after T8.10 and passed**. A pre-T8.10 T8.6 result does not satisfy the gate.
- Confirm T8.9 recorded **new** pytest baselines (they must change — T8.10 adds code).


- **Owner:** `clearskies-auditor`

**Scope:**
1. Marine service standalone on librewxr (one service, one port).
2. Old services (8767, 8770) not listening.
3. weewx clean: no SWAN binary, no working dirs, no caches.
4. API clean: zero marine code (grep verification).
5. Manifest registration: all marine endpoints via manifest.
6. Config push: wizard apply → API → marine service.
7. api.conf: `marine_service_url` present, no `[swan]`, no `surf_compute_host`.
8. secrets.env: `MARINE_SERVICE_SECRET` only, no `SURF_COMPUTE_SECRET`.
9. Dashboard renders all marine tabs.
10. Silent deferral scan across ALL repos.

### QC Gate 8 (Part B Final)

- Marine service standalone on librewxr (one port, one service).
- API contains zero marine code (grep verified).
- All marine endpoints via manifest registration.
- Dashboard renders complete marine page with all tabs.
- Config push works. Old services disabled. weewx clean.
- api.conf and secrets.env match target state.
- Silent deferral scan: zero findings across all repos.
- Test baselines hold.
- All governing documents match implementation.

---

## Part B QA — Marine Service Separation Verification

| Check | Method | Pass criteria |
|---|---|---|
| Marine service standalone | `curl -k https://librewxr:8780/health` | `status: ok`, spots listed, last_run populated |
| One service, one port | `ssh librewxr "ss -tlnp \| grep -E '876[0-9]\|8780'"` | Only port 8780 listening |
| API zero marine physics | `grep -rn "swan_runner\|surf_1d_analytical\|surfbeat_runner" repos/weewx-clearskies-api/weewx_clearskies_api/` | Zero matches |
| API zero marine providers | `grep -rn "ndbc\|coops\|nws_marine\|hrrr\|gfs\|ofs" repos/weewx-clearskies-api/weewx_clearskies_api/providers/` | Zero matches |
| Marine endpoints via manifest | API startup log | All 6 endpoints mounted from manifest |
| Marine service runtime failure | Stop marine service, verify API returns last cached response with `freshness.validUntil` in the past | API serves cached data (or 503 if no cache) |
| Dashboard renders marine | Screenshot comparison against current functional state (from Part A QA) | All marine tabs show data, visual parity with Part A |
| Config push works | Wizard apply | API pushes to marine service `/config` |
| No compute service files | `ls repos/weewx-clearskies-api/.../services/compute_*` | No files found |
| No SWAN on weewx | `ssh weewx "ls /usr/local/bin/swan*"` | Nothing found |
| api.conf clean | `grep -E "swan\|surf_compute" api.conf` | No matches; `marine_service_url` present |
| Old services disabled | `systemctl is-enabled weewx-clearskies-swan weewx-clearskies-compute` | Both "disabled" |
| Silent deferral scan | `grep -rn "TODO\|FIXME" {all_modified_files}` + `grep -rn 'pass$' repos/weewx-clearskies-marine/` | Zero findings (pass$ scoped to marine service files only) |
| API pytest baseline | Run baseline command | No regression |
| Dashboard vitest baseline | Run baseline command | No regression |
| Governing docs match | `grep -rn 'surf_compute_host\|compute_service\|SWAN.*subprocess' docs/ARCHITECTURE.md docs/manuals/API-MANUAL.md docs/manuals/OPERATIONS-MANUAL.md docs/manuals/PROVIDER-MANUAL.md` | Zero matches |

---

## Summary

| Phase | Purpose | Key deliverables | Status |
|---|---|---|---|
| **PART A** | | | |
| 1 | Governing Document Updates | ARCHITECTURE.md, ADR-099, API-MANUAL, OPS-MANUAL, PROVIDER-MANUAL | PENDING |
| 2 | Fix TLS + Remote Mode | `verify_tls` config, TLS fix, librewxr sync, remote mode activated | PENDING |
| 3 | Fix Caching + E2E Verify | Caching bug fixed, surf page shows data, Surfline comparison | PENDING |
| **PART B** | | | |
| 4A | Fix SwellTrack Pipeline + Vocabulary | Unified vocabulary, PCHIP variable-resolution profiles, CUDEM at apply time, remove SWAN CURVE fallback | PENDING |
| 4 | Marine Service Scaffold | `weewx-clearskies-marine` repo, provider infra, /health + /manifest + /config, TLS + auth | PENDING |
| 5 | Move Provider Modules | All 29 modules moved (11+12+3+3), pipeline wired, 6 endpoints serving | PENDING |
| 6 | API Companion Proxy | Manifest handler, response wrapping, unit conversion, delete ~28K lines from API | PENDING |
| 7 | Wizard/Admin Updates | "Marine Service" naming, unified URL, test connection, validation, config push | PENDING |
| 8 | Deploy + Clean Up | Marine service deployed, old services removed, weewx cleaned, E2E verified | PENDING |

**Adversarial audit is mandatory for every phase.** No phase closes without the auditor sign-off. No findings may be deferred to a later phase.

**The coordinator keeps this plan updated and checks items off as verified.** After every QC gate, the coordinator updates the phase status from PENDING to COMPLETE with the date and relevant commit hashes.

---

## Execution Log

### 2026-07-23 — Session: Data flow fixes + SwellTrack pipeline investigation

**Part A hot fixes (deployed):**
- `fc5680a` (weewx-clearskies-swan-swelltrack) — SWAN standalone service: added `spectral` and `transect` to HTTP response cache; added disk→Redis→memory restore on startup. Previously dropped swell decomposition data and lost all data on restart.
- `099e874` (weewx-clearskies-api) — Beach profile endpoint: routed SwellTrack through compute service (was running locally on weewx with no CUDEM data → always failed).
- `0d87b28` (weewx-clearskies-api) — Beach profile response: aligned field names with dashboard contract (`hsEnvelope`→`transect`, `distance`→`distanceFromShore`, `hs`→`waveHeight`). NOTE: This rename was wrong — should have used model vocabulary. Will be reverted in Phase 4A T4A.1.

**Repo operations:**
- Created `clearskies-wx/weewx-clearskies-swan-swelltrack` on GitHub (repo was local-only). All commits pushed.
- Renamed repo from `weewx-clearskies-swan` to `weewx-clearskies-swan-swelltrack` (local, GitHub, librewxr).
- Installed `gh` CLI on librewxr, authenticated with GitHub.
- Updated `.pth` editable install path on librewxr after directory rename.
- Updated ARCHITECTURE.md, PROVIDER-MANUAL, clearskies-dev.md with new repo name and librewxr repo paths.

**Doc updates:**
- `rules/coding.md` — Added "Expensive computed data must be persisted to disk" rule (§1, after caching rule). Incident: SWAN service volatile-only cache dropped spectral data and lost everything on restart.
- `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md` — Added §6.1: variable-resolution 1D grid spec (depth-based zones, PCHIP interpolation, max breaking depth computation). Research-backed: XBeach docs confirm dx ≤ 2m eliminates grid influence.
- `docs/manuals/API-MANUAL.md` — Added `max_hs_m` config key and depth zone table to §17 SwellTrack configuration.

**SwellTrack pipeline investigation (root cause found, fix planned in Phase 4A):**
- SwellTrack has NEVER produced non-zero output in production. All 32 transects × all timesteps → `best_peak=0.00 m`.
- Root cause: spot profile at `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` has 50 points at 50m spacing. Battjes-Janssen dissipation over-attenuates at this resolution — wave dies before reaching breaking depth.
- Confirmed fix: same profile interpolated to 5m resolution → 3 break points found (1.13m Hs spilling at 80m from shore). Model works; resolution was wrong.
- The "5.5 ft face height" shown on the dashboard comes from SWAN CURVE K-G/Caldwell fallback, NOT from SwellTrack. `degraded=True` on all entries but response looks normal — silent degradation.
- Surf scorer always uses SWAN CURVE face height, never SwellTrack.
- Phase 4A created to fix all of this before code moves to marine service.

### 2026-07-25 — Phase 6 closeout (API companion service proxy)

**Everything Phase 6 was to *build* is built, committed and audited. Roughly half of what it was to
*delete* is blocked on one operator decision.**

**Landed — API repo:** `96ea534` `335daa9` (T6.1 companion proxy, C-10 gap client), `ceaf02a`
(T6.2/T6.3 envelope + SI→display conversion + capability merge), `12ac049` (T6.4/T6.4b config push
and recovery pull), `d530e45` `4583bec` `1fe737e` (C-24/C-25/C-29/C-37 API-side re-merge and label
consolidation), `ac7c191` `02fb9d3` `9df764c` `e482bd7` `8fae2be` (T6.5-T6.8 deletions).
**Marine repo:** `50bccae` (C-30), `242f8d7` (T6.4b), `a464c37` (C-26 canonical units), `10e347a`
(C-31 registry), `b16e3af` (species profiles to Celsius), `cc2be6a` (C-29/C-37 marine half),
`26f18fa` (C-39). **Docs:** `a1c6dce` `3d8cfbb` `7ef9d65` `917d312`.

**Deleted: 19,887 lines** — 11,405 from the API (7,340 source + 4,065 orphaned tests) and 8,482 from
the marine service (unused i18n, 13 locale files, the `babel` pin). The plan's "~28,735 lines removed"
headline was stale before this phase began and is now wrong by more than 2×; these are the measured
figures.

**QC Gate 6 — walked, partial.** Met: dynamic manifest-driven route mounting; envelope wrapping and
unit conversion; runtime failure serving cached data or 503; periodic manifest refresh with
de-registration; capability merging; config push and pull sharing one serializer; marine-side config
recovery. **Not yet assessable:** the zero-marine-code and zero-provider-module criteria, blocked on
C-41/C-42. **Named gate exception (C-40):** the gate's grep lists `marine_config`, which now
legitimately matches — the API retains the marine config *schema* because it owns the wizard and the
config push; it sheds marine *computation*. Same handling C-16 received at Gate 5.

**Adversarial audit — 2 findings, no blockers.** F1/C-44 (`totalWaterLevelForecast[].residual`
reaching the dashboard in raw metres) and F2 (`enrichment/fishing_scorer.py` orphaned in the API).
Both dispatched for fix with accompanying sweeps, since each was found by accident rather than by
looking. Everything else verified clean with command-level evidence.

**Blocked on the operator — three decisions, all the same question in different places:**

1. **C-41/C-42** — does wizard-time and apply-time marine support code live in the API or behind the
   marine service? `endpoints/setup.py`'s apply chain and wizard discovery helpers transitively reach
   the entire wave-physics cluster and all five provider directories. Held: that cluster,
   `providers/{buoy,tides,marine,wind,ocean}/`, `marine_location_resolver.py`, `compute_client.py`,
   the `surf_compute_*` keys and the `[nearshore]` extra. **The current arrangement stops working at
   T8.5**, which removes the librewxr API — the only reason the apply chain's output file is today
   visible to the SWAN runtime that reads it.
2. **Surf t=0 station wind (C-24)** — inject the station observation into the marine service's surf
   request so scoring happens once with the right inputs, or leave t=0 on forecast wind with
   `windSource` truthfully reporting it. Recomputing API-side would duplicate `score_surf()` across
   two services; patching only the wind fields would produce a self-contradictory response.
3. **Fishing / solunar** — `score_fishing()` consumes solunar and almanac values as scoring inputs
   worth 31.25% of `overallScore`, so solunar is not a separable output field.

**The pattern worth carrying into Phase 7.** §0.6's inventory was built by listing files with
"marine" in the path, so it repeatedly put *operator-configuration* code on the deletion list
alongside *marine computation*. C-40 was resolved on that distinction; C-41 and C-42 are the same
distinction unresolved. Phase 7 is the wizard phase and will meet it again.

### 2026-07-25 — Phase 6 FINAL closeout, QC Gate 6 walked

The operator's rulings on C-41, C-42 and C-47 unblocked everything that was held. All Phase 6 code
work is complete.

**The three rulings, because they shaped the rest of the phase:**

1. **C-41** — the apply-time grid-sizing/bathymetry chain is a marine function. It moved to the marine
   service and runs on config receipt (`aa40379`). It had only ever lived in the API because SWAN
   used to run *inside* the API.
2. **C-42** — the wizard never talks to the marine service; nothing does except the API. The API
   proxies wizard discovery queries (`09f0577` + marine `7fb111a`). Now recorded as a standing
   invariant in `ARCHITECTURE.md`.
3. **C-47** — when the marine service needs data the API owns, it queries the API. That resolved both
   the surf t=0 station wind and the fishing/solunar coupling in one line (`f75c927`, `5b52ede`,
   plus `20e0c54` adding `GET /current?units=si` and `sunrise`/`sunset` on `/almanac/solunar`).

**Final deletion figures.** ~30,800 net lines removed from the API across 63 files in the held-cluster
round alone, on top of the 11,405 removed earlier and 8,482 from the marine service. The plan's
"~28,735 lines removed" headline was stale from the outset; the measured total is substantially
larger.

**QC Gate 6 — walked by the coordinator, not accepted on agent reports:**

| Criterion | Result |
|---|---|
| Zero marine endpoint files in the API | **PASS** — `ls endpoints/` matches nothing marine |
| Zero marine provider modules | **PASS** — `providers/{buoy,marine,nearshore,ocean,tides,wind}/` contain no source, only untracked `__pycache__` |
| Zero live imports of deleted physics modules | **PASS** — the gate grep, filtered to actual import statements, returns two hits, both `bathymetry_resolver` (see exceptions) |
| API imports clean | **PASS** — `import weewx_clearskies_api.app` succeeds |
| Proxy mounts routes from manifest; envelope + unit conversion; runtime failure serves cache or 503; periodic refresh; capability merging; config push/pull one serializer; marine config recovery | **PASS** — audited with command-level evidence |
| Adversarial audit: zero unresolved findings | **PASS** — 2 findings (C-44 `residual`, orphaned `fishing_scorer.py`), both fixed in `ee25fdb` |

**Two named exceptions, both recorded rather than absorbed into a pass:**

- **C-40** — `config/marine_config.py` stays. The API owns the wizard and the config push, so it keeps
  the marine config *schema*; it sheds marine *computation*. The gate's grep term list predates that
  distinction.
- **C-48** — `swan_domain.py`, `shelf_boundary.py`, `bathymetry_resolver.py` and
  `enrichment/bathymetry.py` remain, held solely by two wizard endpoints
  (`/setup/marine/compute-estimate`, `/setup/marine/coverage`) that still compute marine physics in
  the API. No new decision is needed — the C-42 pattern settles it — but the marine service needs two
  new endpoints, which is work rather than a deletion. **Routed to Phase 7**, which is the wizard
  phase.

**Bugs found and fixed that were not on any task list:** every display-unit-calibrated threshold in
the marine service made canonical (C-26; two were live per-request bugs); the provider dispatch
registry populated (C-31 — it had only ever held the Phase 4 scaffold stub); the manifest completed
from 6 routes to 11 (C-30 — the five list routes would have 404'd silently); `defusedxml` declared
(C-45 — a clean install could not import the NDBC provider); a `heightM` double-conversion caused by a
docstring asserting the opposite of the code (C-50); and `is_station_served()` initialised so the
station-observation restoration is actually reachable (C-51).

**Carried into Phase 7:** C-48 (two wizard endpoints), C-49 (orphaned `test-compute` endpoint, partly
orphaned `[marine]` extra — sequence after C-48), C-46 (`MARINE_PROVIDER_MODULES` has no consumer).
**Carried into Phase 8:** C-43 (one untranslated locale key), C-33 (documented health poll no task
implements), C-38 (`assessment.waterTemp` now converts where it did not before), plus all previously
recorded Phase 8 items.
