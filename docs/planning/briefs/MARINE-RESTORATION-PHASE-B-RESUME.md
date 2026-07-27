# Resume prompt — Marine Model Restoration, Phase B

**Written:** 2026-07-27 by the Phase A coordinator, immediately before the mandated VSCode restart.
**Read this first, then the plan.** You are starting at Phase B. Phase A is done and committed.

---

## What you are doing

Execute **Phase B** of [`docs/planning/MARINE-MODEL-RESTORATION-PLAN.md`](../MARINE-MODEL-RESTORATION-PLAN.md)
— tasks B1 (DEBUG trace), B2 (runtime invariants), B3 (marine health reports a real state), and
B4 (admin status page). Read the plan yourself. Do not work from this brief's summary of it; this
brief exists to give you starting state, not task specs.

**Sequence from here:** Phase B → **Deploy 1** (needs the operator's word "push") → Gate B →
Phase C → **Deploy 2** → Gate C → Phase D → Gate D.

## Step 0 — before you dispatch anything, confirm the new profiles loaded

Phase A rewrote all six agent profiles and added a restrictive `tools:` line to each. **Profiles load
at session start.** That is the entire reason the restart gate exists — dispatching Phase B from the
session that wrote Phase A would run agents under the profiles Phase A replaced.

Confirm before dispatching:

1. `grep -c '^tools:' .claude/agents/clearskies-*.md` returns 1 for each of the six files.
2. No profile's `tools:` line contains `Agent` or `Task`.
3. Spot-check that a dispatched agent actually lacks the Agent tool — if a Phase B agent reports it
   can spawn subagents, **stop**: the frontmatter is not being honoured and A5 has failed in
   practice even though it passed on disk.

**Known risk, unverified at handoff:** the `tools:` names were written but could not be exercised in
the session that wrote them, because that session had already loaded the old profiles. If a profile
turns out to be missing a tool it needs — `SendMessage` above all — that is a Phase A defect to fix
before Phase B work continues, not something to work around.

## Governance that is new since the last session — read these

Phase A moved rules out of `CLAUDE.md` and `rules/clearskies-process.md` into three new files.
The originals now hold pointers only.

| File | What is in it |
|---|---|
| `rules/agents.md` | Agent orchestration, git safety, scope binding, prompt requirements, architectural-change block, false-claim protocol, and the new "agents may not spawn agents" rule |
| `rules/verification.md` | The **three-layer model** (guard / invariant / adversarial), the **known-answer test mandate** for numerical kernels, audit rules, round-close gate, validate-against-reality |
| `rules/coordinator.md` | Dispatch gate (four things or the task is not ready), acceptance gate, stop-and-surface, and the **operator spot-check protocol** |

`rules/coding.md` §1 gained the **coastline-anchor rule** — cross-shore distances are measured from
the coastline anchor, never the spot pin. Read it before any grid, transect, or profile work.

**The three-layer distinction governs every Phase B gate row.** A guard is not evidence the system
works; an invariant is a runtime assertion on real data; an adversarial pass is an auditor who never
sees the implementer's own output. Do not report a guard as a live check.

## Repo state at handoff

| Repo | Branch | HEAD | State |
|---|---|---|---|
| meta (`c:\CODE\weather-belchertown`) | `main` | *Phase A commit — see `git log -1`* | clean at handoff |
| marine (`repos/weewx-clearskies-marine`) | `main` | `4276806` | clean, **ahead of `origin/main` by 12** |

**The twelve unpushed marine commits**, oldest first — these are the fixes Deploy 1 carries and
Gate B Part 3 verifies:

```
eb3c4b7  docs(ww3_station_selection): record both failed HSRERR/band-membership anchors
1664701  fix(surf): resolve on-demand tide fallback from cached series, not 0.0 default
7fb75f9  fix(surf): SwellTrack starts at the SWAN handoff, and the dispersion solve converges
83f0205  fix(surf): publish multiSwell from the deep-water reference, not the SwellTrack handoff
bed7ec7  fix(swan): restore the DWR OUTPUT clause and the QB breaking-zone guard
aa4553d  fix(swan): emit INIT HOTSTART after CGRID and READ BOT
bd8c928  fix(swan): place the deep-water reference on the 15 m contour, or not at all
35af390  fix(beach_profile): convert between the handoff and canonical partition index spaces
ac6bd8a  fix(swan): project per-transect POINTS bands from the shoreline, not the segment
c28588b  fix(swan): place contour-sized grid edges on their contour, not offset by the pin
595ff6a  fix(surfbeat): publish station distances in the input profile's own coordinate
4276806  fix(swan): say so when a transect endpoint is not at the depth it is sized for
```

**The live system is running NONE of these.** Deployed commit on librewxr is **`007028d`**
("fix(surf-pipeline): thread fetched CO-OPS tide into run_pipeline's tide_level"). That is also the
**Deploy 1 rollback hash** — verified live, not copied from the plan.

## Live baseline — measured 2026-07-27, deployed `007028d`

Every number below came from the running system, not from the plan. These are what Phase B's
invariants must fire against, and what Gate B compares to.

**Access:** `ssh -F .local/ssh/config librewxr`. The marine service is
`weewx-clearskies-marine.service`, port 8780, working dir `/etc/weewx-clearskies/marine`, venv at
`/home/ubuntu/repos/weewx-clearskies-marine/.venv`. Forecast cache:
`/run/weewx-clearskies/swan/forecast_cache.json` (root-readable; use `sudo python3`).

| Quantity | Live value | Which defect it is |
|---|---|---|
| **Health endpoint** | `{"status":"ok","version":"0.1.0","last_run":"2026-07-27T13:30:27Z","spots":["huntington-city-beach-pier"],"run_in_progress":false}` | **B3's whole premise.** `status` is hardcoded `ok` while defects 4, 5 and 6 are live underneath it |
| **L3 grid** | lat 33.647439→33.654024, lon −118.011249→−118.001879, 10 m ⇒ **867.9 m × 733.1 m = 87 × 73 = 6,351 cells** | Defect 6, the grid collapse. Plan's "87 × 73" confirmed independently |
| **Shadowed count** | `compute_transect_shadows complete: 32 transects total, 0 shadowed, 32 open. beach_facing=238.0°` — and **every transect logs `structures=[]`** | Defect 4. The `structures=[]` is the smoking gun for C2: the classifier receives no structures at all |
| **Transect spread** | 32 transects, **1 distinct** break-point Hs (1.70017 m), **spread = 0.0 m**; 32 handoff depths, **1 distinct** (1.7452 m) | Defect 5 / C1. "Two writers, zero readers" confirmed live |
| **Face height** | `best_peak_face_height_m` = `spot_average_face_height_m` = **2.15922 m (7.08 ft)**, identical | Invariant 8's target — best peak cannot exceed a spot average when all 32 transects are the same |
| **Peel** | `peel_direction: "a_frame"`, `peel_classification: "fast_a_frame"` | C1's live check expects this to stop being `a_frame` on every timestep |
| **First forecast hour** | `waveHeight: 0.01, wavePeriod: 1.6, swellHeight: 0.0` at `2026-07-27T12:00:00Z` | D1. The cold-start initial field published as a forecast hour |

Sample timestep for the spread and face-height figures: `2026-07-28T21:00:00Z`.
Shadow log sample: `Jul 27 17:56:45`.

## Things the Phase A coordinator wants you to know

- **Grid sizing is config-time, not per-cycle.** `run_grid_sizing_chain()` fires on `POST /config`
  with ≥1 surf spot, and geometry is cached to `/etc/weewx-clearskies/swan_grid_sizing.json`
  (`generated_at: 2026-07-27T05:47:11Z`). A forced cycle will NOT re-size the grid. Anyone who
  forces a cycle, sees 87 × 73, and concludes a grid fix failed has made a sequencing error. This
  bites B1's grid-sizing trace record, invariant 6, and C3's live check.
- **B3 must rule on required vs degrading inputs before dispatch.** The plan says the task states the
  list and the coordinator rules on it. Do that before writing the brief, not during the gate.
- **Deploy 1 needs the operator to say "push".** Not implied by Phase B finishing.
- **`.claude/` is tracked in this repo**, despite `rules/clearskies-process.md` §"Plan and
  documentation discipline" claiming agent definitions are gitignored. The doc is stale. Left as a
  finding, not fixed, because it was outside every Phase A allowlist.

## What Phase A did NOT do

Phase A was governance only — no marine code was touched, no agent was dispatched to write code, and
nothing was deployed or pushed. Every defect in the plan is still live exactly as measured above.
