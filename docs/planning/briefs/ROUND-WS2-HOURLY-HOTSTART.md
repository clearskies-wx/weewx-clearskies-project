# Round WS2 — Hourly warm-start chain (per-hour hotfiles)

**Round identity:** WS2, 2026-08-05. Lead: coordinator (Fable). Implementer: marine-dev
(Sonnet, this brief). Auditor: separate blind adversarial agent, dispatched after
implementation — it will NOT see your tests, commits, or report.

**Operator ruling (2026-08-05, in chat):** warm start must apply to EVERYTHING — the
6-hourly full runs AND the hourly quick updates. The full-run fix (commit `3fd72f8`)
already writes one hotfile at the next full cycle's start. This round extends it:
the full run saves a wave-state snapshot after EVERY hourly compute step through the
next full cycle's start, so any later run (hourly quick update or next full run)
finds a snapshot stamped exactly at its own start time. The operator explicitly
approved the new persisted files (trigger 7) in chat.

---

## Scope

**Files you MAY create or modify (exhaustive allowlist):**
1. `weewx_clearskies_marine/services/swan_formats.py`
2. `weewx_clearskies_marine/services/swan_runner.py`
3. `tests/services/test_all_stationary_sequence.py`
4. `tests/services/test_hotstart_timestamp.py`
5. `tests/services/test_hourly_hotstart_chain.py` (new file, if you need it for the runner-side tests)

**Files you must NOT touch:** everything else. Named traps you must NOT touch even
though they are adjacent: `service.py` (scheduling/cadence), `providers/nearshore/swan.py`,
any config module, the `COMPUTE NONST` (T0.3) branch and the single-snapshot
`stationary` branch in `build_swan_input`, the `INIT HOTSTART` emission (input-side
name `hotstart.dat` and its command position are FROZEN), and the Z5b exact-equality
admission rule (exact stamp match stays exact — do NOT loosen to "nearest earlier
stamp" or any tolerance).

**Work location:** local checkout `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`,
branch `warm-start-fix` (HEAD `3fd72f8`, clean — pre-flight verified by lead).
Commit locally to this branch only.

**Verification:** you cannot run pytest locally (no local venv; marine tests run
canonically on librewxr, which the lead operates). Your loop is: implement → commit →
report via SendMessage → the LEAD runs the targeted tests on librewxr and reports
results back → you fix if needed. Before committing, at minimum run
`python -m py_compile` on both changed modules if a system python exists; otherwise
state that you could not. Do NOT ssh anywhere. Do NOT run any full test suite ever.

**Deliverable definition:** 1–2 commits on local branch `warm-start-fix`:
(a) implementation in the two service files, (b) test updates/additions, with every
changed/deleted test listed in your closeout message and the reason. Lead will see
in `git log`: your commits, nothing else.

---

## Reading list (read BEFORE coding — read the originals, in this order)

1. `docs/reference/swan-user-manual.txt` — the FULL official SWAN manual is IN THE
   REPO's parent project at `c:\CODE\weather-belchertown\docs\reference\swan-user-manual.txt`.
   Read: lines ~1182–1205 (command-block sequencing: "HOTFILE immediately after
   COMPUTE"; commands after COMPUTE are ignored EXCEPT HOTFILE and STOP), lines
   ~5773–5790 (HOTFile command: writes the wave field at the end of the immediately
   preceding COMPUTE), lines ~2797–2809 (INITIAL HOTSTART semantics).
   **Do NOT web-search or download SWAN documentation — the manual is local.**
2. `weewx_clearskies_marine/services/swan_formats.py` — the `stationary_sequence`
   emission branch (search `HOTFILE placement (DQ-1a`); the `swan_t_hotsave`
   parameter docstring; `_swan_time` / `_parse_iso` helpers at top.
3. `weewx_clearskies_marine/services/swan_runner.py` — read ALL of:
   - the Z5b admission block (search `T0.3 part 2 (Z5b`), through the
     `persistent_hot.exists()` copy and the stale-output cleanup that follows;
   - `_read_hotfile_timestamp` and its `_HOTFILE_TIMESTAMP_SCAN_LIMIT_BYTES` comment;
   - `_save_hotstart`;
   - `_spawn_swan_with_hotstart_retry`;
   - the L3 grid-resize hotstart invalidation (search `T3.4`) and the L4 equivalent
     (search `Amendment 3`);
   - the quick-update warm-start copy block in `run_quick_update` (search
     `level1_hotstart.dat` — a list of copy patterns) and its surrounding comments
     (isolated tree, `save_hotstart=False`, read-only one-way copy);
   - `_check_convergence` — find whether its NaN scan (check 2) references the
     hotstart filename, and repoint per the design below.
4. `tests/services/test_all_stationary_sequence.py` — the four HOTFILE-placement
   tests added in `3fd72f8` (they pin the SINGLE-hotfile design you are replacing —
   you are explicitly tasked to update them; list each change in your closeout).
5. `tests/services/test_hotstart_timestamp.py` — existing hotsave-split tests
   (COMPUTE NONST branch — do not change their subject; they cover a branch you
   must not touch).

## Pre-round verification (lead's evidence of clean start)

- Repo: branch `warm-start-fix`, HEAD `3fd72f8`, working tree clean, == origin/warm-start-fix.
- Targeted tests at `3fd72f8`: `tests/services/test_all_stationary_sequence.py` +
  `tests/services/test_hotstart_timestamp.py` = **24 passed, 0 failed** (librewxr
  worktree, 0.29 s).
- Live service on librewxr runs `0560c41` (neither `3fd72f8` nor this round deployed yet).

---

## Design (this is the design; you code it, you do not redesign it)

### D1 — Emission: per-hour HOTFILEs (`swan_formats.py`, stationary_sequence branch)

Replace the single-HOTFILE-at-hotsave emission (landed in `3fd72f8`) with:

- Let `t0` = first entry of `valid_times` (parsed). Let `hotsave` = `swan_t_hotsave`
  (a `YYYYMMDD.HHMMSS` token, may be None).
- For each `COMPUTE STAT` at time `t`: emit, immediately after that COMPUTE line,
  `HOTFILE 'hotstart_<token>.dat'` (token = `t` as `%Y%m%d.%H%M%S`) **iff**
  `t0 < t <= hotsave` (token/string comparison is safe — both sides come from the
  same strftime format; parse if you prefer, but be consistent).
- `swan_t_hotsave=None` → emit NO HOTFILE lines (an isolated chain that persists
  nothing has no consumer; dead outputs are waste).
- If `hotsave` is not None but NO compute time fell in `(t0, hotsave]` → emit no
  HOTFILE lines and `logger.warning` naming the hotsave value (mirror the existing
  unmatched-hotsave warning wording). Do NOT fall back to an end-of-window HOTFILE —
  an end-stamped file is exactly the bug this work kills.
- Cardinality with the production 6 h cadence and hourly valid_times: exactly 6
  HOTFILE lines (t0+1h … t0+6h). Short window (end < t0+6h): fewer, down to the
  clamped end. Update the parameter docstring to match.

### D2 — Persistence naming

- Run-dir outputs: `hotstart_<token>.dat` (written by SWAN per D1).
- Persistent copies (run_dir.parent): `{key}_hotstart_<token>.dat` where `{key}` is
  the existing hotstart_key ("level1", "level3_0", …).
- The run-dir INPUT-side copy keeps the frozen name `hotstart.dat` (`_HOTSTART_FILE`
  constant unchanged — it is now the input-copy name only).
- Legacy unsuffixed persistent files (`{key}_hotstart.dat`) are a superseded format:
  delete on sight in D3/D4 paths, log at info once per encounter.

### D3 — Admission (`swan_runner.py`, the Z5b block)

Given requested start `_t_start_dt` (token `swan_t_start_str`):

1. Candidate = `run_dir.parent / f"{hot_key}_hotstart_{swan_t_start_str}.dat"` —
   exact-token lookup, no globbing for "closest".
2. If it exists: read its INTERNAL stamp with `_read_hotfile_timestamp` (keep this
   defense — a renamed/corrupt file must not slip through on filename alone). Parse
   with `_parse_swan_time`. Unparseable OR != `_t_start_dt` → warning (keep the
   existing message shapes), delete THAT file, cold-start. Equal → copy to
   `run_dir / "hotstart.dat"`, set `hotstart_arg`, keep the existing
   "using hotstart from previous run" info log.
3. No candidate → cold start with an INFO log (normal after restarts/gaps — not a
   warning).
4. Hygiene in the same block: delete any `{hot_key}_hotstart_*.dat` whose token
   parses to a time EARLIER than `_t_start_dt` (never consumable again), and any
   legacy `{hot_key}_hotstart.dat`. Files with FUTURE tokens stay — an hourly run
   at 07Z must leave the 08–12Z snapshots for the runs that need them. (In the
   quick-update isolated tree these deletions touch copies only — the one-way copy
   design already guarantees the real set is untouched; say so in a comment.)
5. Keep the existing run-dir stale-output cleanup, extended: before the run, also
   delete `run_dir/hotstart_*.dat` leftovers so `_save_hotstart` can never persist
   a previous cycle's outputs.

### D4 — Save (`_save_hotstart`)

- Collect `run_dir/hotstart_*.dat`. If empty → keep the existing "no hotstart file
  produced" warning path (unchanged wording is fine).
- Else: first delete ALL existing `{key}_hotstart_*.dat` and legacy
  `{key}_hotstart.dat` in the parent (full-set replacement — the old cycle's
  snapshots are superseded), then copy each output to
  `{key}_hotstart_<token>.dat`. Log one info line: count + total bytes.

### D5 — Crash retry (`_spawn_swan_with_hotstart_retry`)

On crash-with-hotstart-loaded: delete ALL persistent `{grid_level}_hotstart*.dat`
(glob covers tokened + legacy) + the run-dir input copy, rewrite INPUT without
INIT HOTSTART (existing logic), retry cold. The whole persistent set is suspect if
loading one member crashed SWAN — grid identity is shared across the set.

### D6 — Grid-resize invalidation (L3 + L4 blocks)

Switch the single-file unlink to a glob unlink of `{key}_hotstart*.dat` for the
resized cluster. Same log lines, same trigger conditions — placement change only.

### D7 — Quick-update copy patterns (`run_quick_update`)

The read-only one-way copy patterns (`level1_hotstart.dat`, `level2_hotstart.dat`,
`level3_*_hotstart.dat`, `level4_*_hotstart.dat`) become the tokened equivalents
(`level1_hotstart_*.dat`, etc.). Read how the copy code consumes the patterns and
adapt minimally. `save_hotstart=False` for this chain is unchanged and untouchable.

### D8 — Convergence NaN scan (`_check_convergence` check 2)

If (and only if) it references the hotstart filename: repoint it to scan every
`run_dir/hotstart_*.dat` produced by this run (text NaN scan per file, same method).
If it does not reference the filename, leave it alone and say so in your closeout.

### Tests (guards — each must FAIL against `3fd72f8`, and your closeout must say which do)

- **Builder (update the four `3fd72f8` tests + add):** hotsave=t0+6h on the 72 h
  window → exactly 6 HOTFILE lines, correct names, each immediately after its own
  COMPUTE STAT, none after t0+6h; hotsave=None → zero HOTFILE lines; unmatched
  hotsave → zero lines + warning; short window → clamped count.
- **Runner (new file OK, no SWAN binary needed — these are filesystem/logic tests;
  follow the existing mock/tmp-path patterns in `test_hotstart_timestamp.py`):**
  exact-token admission accepts; internal-stamp-mismatch deletes and cold-starts;
  missing token cold-starts (info, file set untouched except stale purge); stale
  (past-token) purge deletes only past tokens, keeps future ones; legacy-name purge;
  `_save_hotstart` full-set replacement; retry purge deletes the whole set.
- Known-answer-test mandate: N/A this round — no numerical kernel is touched
  (command emission + file plumbing only). Stated here so the omission is explicit.

## Lead calls (already decided — follow, do not re-derive)

1. Snapshots saved only through `t0 + 6 h` (the existing `swan_t_hotsave` bound),
   NOT all 72 h — bounded disk (~6×~10 MB per grid) vs ~72× for snapshots nothing
   would ever consume. librewxr disk/memory pressure is a watched concern.
2. Exact-stamp admission stays (operator safety ruling Z5b). Warm start is achieved
   by producing the right snapshots, never by loosening the check.
3. Input-copy name `hotstart.dat` frozen — separating input name from tokened output
   names removes the old mid-run overwrite of the input copy as a side benefit.
4. No end-of-window fallback anywhere (see D1).

## Open questions

None known. If you hit one — or ANY existing test contradicts this design beyond
the four explicitly-reassigned builder tests — STOP and SendMessage the lead.

---

## Mandatory blocks

**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`,
`git rebase`, `git merge`, or `git checkout` of remote branches. You may only
`git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead
or behind, STOP and report via SendMessage. Do not resolve it yourself.

**Architectural changes — STOP, do not proceed.** You may not make an architectural
change. If your task requires one, STOP and report via SendMessage — do not
implement it, do not work around it, do not pick an option.

A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient,
   threshold or criterion inside one. This does NOT cover changing how the same
   equation is solved. Test: does it change *which equation is satisfied*, or only
   *how precisely/efficiently*? Only the first is architectural.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is
   responsible for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability,
   units crossing a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
   (The per-hour persisted hotfiles of THIS round are operator-approved in chat
   2026-08-05 — that approval covers exactly the files in D1/D2, nothing more.)

**These do NOT authorize you:** "my task's acceptance criteria are unreachable
without it" (then your task is blocked — say so), or "a plan/manual/ADR says so"
(a wrong or stale document is a finding to report, not permission to change code).

You MAY still: resolve a contradiction between two statements inside the same
document by taking the reading its own examples support (and say so); apply a rule
already written in the rules files; fix code that diverges from its own stated
contract.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your
tasked change, STOP and report it via SendMessage — do not modify code to make it
pass, and do not delete it on your own authority. A behavior change and its test
updates land in the same commit, per your task's design; a test you were not told
to touch that fails against your change is a finding. Your closeout report must
list every test you modified or deleted, with the reason, and every guard,
invariant, or viability check that fired during your work — including ones you
believe are unrelated or pre-existing.

**Scope acknowledgment required BEFORE any code:** SendMessage the lead one
paragraph: what you will deliver, what you will NOT touch, and the verification
loop you will follow (per the Verification section — lead-run tests). Wait for the
lead's confirmation before writing code.
