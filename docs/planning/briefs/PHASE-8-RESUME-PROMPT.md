# Phase 8 — Resume Prompt (2026-07-26 handoff)

> ## ⛔ SUPERSEDED — use [PHASE-8-RESUME-PROMPT-2.md](PHASE-8-RESUME-PROMPT-2.md)
>
> This file is **history, not instructions**. The current resume prompt is
> `PHASE-8-RESUME-PROMPT-2.md` (2026-07-26 evening). Read that one.

> ## ⚠ PARTLY SUPERSEDED — a later session ran on 2026-07-26. READ THE LIVE SCRATCH FIRST.
>
> **`c:\tmp\marine-sep-P8-resume-scratch.md` is the current state of record and wins wherever it and this
> brief disagree.** Read it before this document, not after.
>
> What changed after this brief was written:
>
> - **T8.4, T8.4b, T8.5 are DONE**; C-77 (`b7356ae`) is deployed. weewx is clean of SWAN artifacts.
> - **T8.10a, T8.10b, T8.10c (both rounds), T8.10d are implemented and pushed** — but **NOT deployed**.
>   The marine service is still running `b7356ae`; newer code sits on disk via `--no-restart`.
> - **A background job may still be running**: the full ocean WW3 station catalogue build on librewxr
>   (`/tmp/ocean_cat.log`). ~2 hours, resumable. It is a hard deploy prerequisite. Check it first.
> - **The brief's "one station, `BOUNDSPEC … CONSTANT FILE`" design is VOID** — operator ruled the boundary
>   must vary along its length (`BOUNDSPEC … VARIABLE FILE`). See the plan's T8.10c superseding block.
> - **The depth/distance thresholds are NO LONGER an operator question.** They are computed:
>   depth ≥ `0.78 × T²`, distance ≤ one WW3 grid cell. Do not re-ask.
> - **The "one measurement still missing" (GLWU frequency array) is CLOSED** — 32 bins, 0.0500–0.960 Hz.
> - New concerns since: **C-88** (duplicate NOMADS rate limiters), **C-89** (C-76 closed while a second
>   calm-boundary fabrication survived — now deleted), **C-90** (C-77's −15 m depth alive at all three DEM
>   priorities — **NOT yet fixed**), **C-91** (selection geometry — fixed), **C-92** (catalogue never built;
>   orphaned API data files).
> - New governing document: **`docs/RELEASE-DATA-REFRESH.md`** — shipped data artifacts and when to refresh
>   them.
> - **Only two operator decisions remain open**: C-85's capability surface, and whether `/marine` may gain a
>   `spectralComponents` field. Everything else previously listed as a question has been answered.
>
> Two behavioural notes that cost real time this session: the operator wants **short** replies, and wants
> physics questions **researched from the SWAN manual and the literature**, never put to them as a choice.

Paste the block below into a new session.

---

You are the coordinator for **Phase 8 of `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — "Deploy + Clean Up"**, the final phase of Part B. Phase 8 is **partly executed**; you are resuming it, not starting it.

## Read first, in this order

1. `docs/ARCHITECTURE.md` — and follow all rules, especially agent delegation and adversarial QC.
2. `rules/clearskies-process.md` — note especially **"Over-triggering is a failure mode too"**, **"Moving a module moves its dependencies"**, and the newest section, **"Validate against reality, never against the model's own output"**. That last one exists because of what went wrong on 2026-07-26; do not repeat it.
3. `rules/coding.md` §1 — **"A model runs on all its inputs or it does not run — never substitute, never omit."**
4. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`, the **Phase 8** section — T8.1 through T8.10j plus the Adversarial Audit and QC Gate 8.
5. `docs/planning/briefs/WW3-SPECTRAL-BOUNDARY-DATA-BRIEF.md` — **mandatory before any T8.10 subtask.** All measured data, SWAN-manual citations, and resolved design questions live here.
6. `docs/planning/MARINE-SEP-CONCERNS.md` — the **last ~400 lines**: C-81 through C-87, the operator rulings of 2026-07-26, the grid-tiering direction, the setup-probe direction, and the Great Lakes correction. 92+ entries; do not re-read the whole file.
7. `reference/clearskies-dev.md` — repo paths, SSH, deploy scripts.

The plan is mandatory. Your job is to get it implemented, not to run on wild goose chases. Log concerns in `docs/planning/MARINE-SEP-CONCERNS.md`. If something looks blocking, read the architecture, briefs and manuals first — most "blockers" are already answered there.

**You may push and deploy as needed.** This is a test environment with no live traffic.

Create and keep live `c:\tmp\marine-sep-P8-resume-scratch.md` per plan §0.4. The previous scratch (`marine-sep-P8-scratch.md`) is **history, not instructions**.

## Verify state before trusting any of this

Run `git status -sb` in the meta repo and each of `repos/weewx-clearskies-{api,marine,dashboard,stack}`. Then verify the hosts. The summary below was true at handoff:

| Host | What | Commit |
|---|---|---|
| `librewxr:8780` | marine service, running | `c2461ff` — **`b7356ae` (C-77) is pushed but NOT deployed** |
| `weewx:8765` | API + companion proxy, 18 marine routes mounted | `994b4e4` |
| `weather-dev` | dashboard + config UI | dashboard `df60297`, stack current |
| `librewxr` | old SWAN 8767 + compute 8770 | **stopped, still `enabled`** — T8.4 now removes them |

`api.conf`: `[swan] omp_num_threads = 6` (**an operator ruling, not a tuning knob** — 16 threads caused a 50m32s run vs 7m), `[providers] marine_service_url = https://192.168.7.22:8780`, `marine_verify_tls = false`. `secrets.env` still contains `SURF_COMPUTE_SECRET` (T8.5 removes it).

## Done, and not to be redone

T8.1, T8.1b, T8.2, T8.2b, T8.3 are complete and deployed. C-63, C-64, C-49, C-70, C-71, C-72, C-76, C-77 are closed. The C-69/C-74 locale round is done and pushed.

**T8.6 was run on 2026-07-26 and FAILED.** Two causes, both recorded: C-85 (marine capability surface empty end to end) and C-81/C-86 (surf output physically wrong).

**C-08 passed but weakly** — energy closure median 1.022 against a 1.626 baseline, so the old triplication defect is genuinely fixed. But 65 of 66 timesteps had one component, where the ratio is 1.0 by definition. **C-83 owns the fixes** that stop that script reporting PASS on a degenerate sample; they land inside T8.10h and must land before T8.10h's other criteria are judged.

## The centre of this phase: T8.10

We were not using WaveWatch III. The provider fetched a **PacIOOS** (Pacific Islands) 0.5° republication of legacy `NWW3_Global_Best` that reports **one averaged swell**. At the SWAN L1 boundary it gave `sper` **12.73 s** — the weighted mean of a 19.11 s groundswell and a 6.39 s wind swell, a period matching no wave in the water. Real WW3 publishes full 2-D directional spectra in SWAN's own nesting format. Period drives shoaling and breaking height far more than offshore height, so that one substitution produced surf of 3.83–4.24 ft, flat for 14 hours, against a real 4–6 ft with sets.

**Its coverage was global** — the defects are resolution and the averaging, not extent. Do not re-litigate that.

T8.10a–j are fully specified with the measured facts inline. Highlights you must not re-derive:

- **Station `.spec` → SWAN boundary; gridded → `/marine`.** Both needed, different consumers, **neither is a fallback for the other**.
- **`BOUNDNEST3` is NOT usable** — the manual accepts a WW3 output location only if the nest-boundary grid point lies within 0.1× the spacing between two consecutive output locations, and buoy stations do not lie on our boundary. Use `BOUNDSPEC SIDE ... CONSTANT FILE`.
- **Grid tiering:** `global.0p16` (0.1667°) for 52.5 N–15.0 S; `global.0p25` (pole-to-pole, 0.25°) elsewhere; GLWU for the Great Lakes. `gsouth.0p25` and `wcoast.0p16` earn nothing. **Tier resolves deterministically from coordinates at config time; a runtime fetch failure RAISES and never falls through to a coarser grid.**
- **`CGRID` low end 0.0418 → 0.03 Hz**, upper stays 1.0 Hz.
- **Never fetch the tarballs** — 1.72 GB and 11.37 GB. Per-station `.spec` is 7.75 MB (ocean) / 1.94 MB (GLWU).
- **`missingValue` (9999 here) means two different things.** Probe `HTSGW`/`swh` only. A missing **partition** is normal; a missing **total** is a failure. **`0.0` is falsy in Python** — `if not swh` would reject a valid calm spot.
- **Great Lakes is a DEFECT FIX, not a new capability.** Marine was already selectable at any lat/lon with no ocean gate; region detection, the contour ladder and the USGS Great Lakes DEM (priority 2 in the SWAN bathymetry chain) all work. Only the wave pull was never implemented.

## Ordering — not free

- **T8.4 / T8.4b / T8.5 are UNBLOCKED** by the 2026-07-26 ruling and proceed independently of T8.6. Verify real unit and directory names first — the old repo was renamed `weewx-clearskies-swan-swelltrack`.
- **T8.10j (cache/hotstart invalidation) must run before T8.10h**, or T8.10h can validate pre-fix output and pass.
- **T8.9 runs after T8.10**, or it resets pytest baselines T8.10 immediately breaks.
- **T8.6 must RE-RUN after T8.10.** QC Gate 8 requires the re-run; a pre-T8.10 result does not satisfy it.
- **Do not configure the Whiting, Indiana test spot until the GLWU pull works.** A raise in the SWAN setup path aborts the cycle for **every** spot (`providers/nearshore/swan.py:2004-2011`), so adding it early takes Huntington down too. Coordinate `41.680447, -87.483689`; GLWU coverage already verified there.
- **T8.7 is superseded** by T8.10h and closes by reference.

## Bring these to the operator — do not decide them yourself

1. **T8.10f depth/distance thresholds.** Constants inside a physics criterion (trigger 1). Propose values with their basis. Precedent ~550 m; station 46222 is 487.9 m at ~20 km.
2. **C-85's capability surface.** Needs its own **trigger-4** ruling on where the capability list derives from. "T8.6 cannot pass without it" is a **named non-excuse**.
3. **New `/marine` response fields.** Filling existing shape is authorized; adding fields is not.

Also outstanding and unruled: **C-75** (no way to disconnect the marine service), **C-79** (L3 silently runs on coarser bathymetry). Small unfixed items: **C-33**, **C-38**, **C-73**, **C-78**, **C-80**. **C-55** (move `bathymetry/upload` + `discover-structures`) is assessed and ready to implement. Phase 4B's T4B.6/7/8 remain outstanding, and ADR-099 archival is due at closeout.

## One measurement still missing

**GLWU's frequency array is unmeasured** — only its `32 36` bin counts are known. T8.10d's acceptance cannot be evaluated for the Great Lakes until someone measures it. If GLWU's top bin exceeds 1.0 Hz, **raise it** rather than widening `CGRID`'s upper bound, which is tied to the WAM Cycle 4 source-term retuning.

## Architectural change block — mandatory in EVERY implementation agent prompt

A change is architectural if it does ANY of: (1) changes a physics/mathematical formula or a constant, coefficient, threshold or criterion inside one; (2) deletes, replaces or rewires a module/component/service, or changes what one is responsible for; (3) changes a model's domain, grid, boundary, extent, resolution or handoff point; (4) changes a data contract between components — field names, shapes, nullability, units crossing a boundary; (5) changes where a computation happens; (6) changes a schedule, trigger or cadence; (7) adds or removes a dependency, port, endpoint, config key or persisted file.

**Triggers 7, 4, 1 and 3 are authorized for T8.10's stated scope only.** Anything beyond it stops and reports to you; you bring it to the operator.

Two justifications that do **NOT** authorize anything: *"the task can't be completed without it"* and *"a governing document says so."*

## Operational facts learned the hard way

- SSH: `ssh -F .local/ssh/config <host>`. Keys in `.local/ssh/`, never `~/.ssh/`. Direct SSH to `weewx` and `weather-dev`; only `cloud` needs `lxc exec` via `ratbert`.
- On `librewxr`, the marine venv needs `sudo -u ubuntu /home/ubuntu/repos/weewx-clearskies-marine/.venv/bin/python`. Without `sudo -u ubuntu` you get "Permission denied" — and if you swallow it with `|| echo MISSING` you will wrongly conclude a library is absent. `eccodes 2.48.0`, `xarray`, `numpy` are installed; `GRIB_AVAILABLE` is `True`.
- The API serves **HTTPS** on 8765 (self-signed). `http://` fails outright. `openapi.json` and `/docs` are disabled in production. **`/api/v1/health` does not exist**; `/api/v1/capabilities` does and needs no auth. `weewx` is **not** 192.168.7.21 — run probes from the host.
- **Bash heredocs fail** when content contains backticks or quotes. Write the script with the Write tool, then execute it. `deploy-compute.sh` has a latent heredoc bug.
- Use the deploy scripts. **Never** `chown`/`chmod` on weewx or weather-dev, and never a bare `git pull` as the `claude` user.
- Agents must not run `git pull/push/fetch/rebase/merge/remote`. No worktree isolation for implementation work.

## How to finish

Walk **QC Gate 8** and the **Part B QA table** yourself — do not accept agent reports. "Data is flowing" is not verification: check physical plausibility against an external source before declaring anything done. Before reporting complete, walk this prompt and confirm every item has a deliverable or an explicit deferral communicated to the operator.
