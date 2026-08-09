# AUDIT BRIEF — Gate B (adversarial), L1-BOUNDARY-REBUILD-PLAN Phase B

**Round identity:** Gate B. Lead: coordinator. You: clearskies-auditor (Sonnet),
adversarial + blind (diffs + design sources only; no implementer/test-author reports).
Report via SendMessage to "main", per-row evidence pasted.

**Claim under audit:** Phase B replaced the station-`.spec` L1 boundary with per-L1-cell
spectra reconstructed from gridded WW3 partition fields (B1 fetcher, B2 reconstruction +
Appendix-D writer, B3 BOUNDSPEC emission, B4 station-path deletion), with KATs K1–K7.
**Disprove it.** Priority targets: an emitted file whose axis/orientation/units deviate
from the prescribed grammar in a way SWAN would silently accept; a direction-convention
flip hiding in one path; UTM `[len]` arithmetic wrong for a non-verified corner (N/E);
normalization that makes K1 pass by construction rather than by correctness; a KAT that
passes against pre-B code.

## Sources
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — SWAN SYNTAX
   PRESCRIPTIONS §1–§4 **as corrected** (AFREQ count = 35 = msc+1; correction note is in
   the §2 region), Phase B designs, named constants, Gate B rows, PRIME DIRECTIVE.
2. Brief `L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` §5, rulings D3/D4.
3. LOCAL SWAN manual `docs/reference/swan-user-manual.txt` (cites in the plan). NEVER
   download SWAN docs.
4. Marine repo commits `95abc74..HEAD` (B1 10c8d70, B2 f81e520, B3 dcfd84a, B4 f190fcd,
   plus the B5 test commit(s) after them). Meta doc-sync `b22e80f`.
5. `.venv-round4` for running tests/mutations (ephemeral only, revert everything,
   clean tree after).

## Gate rows
1. **K1–K7 exist and are falsifiable.** Run the B5 test files. Then mutations (each:
   mutate → run → REVERT → `git status` clean): (a) break the per-train unit-integral
   normalization in boundary_reconstruction.py → K1 must fail; (b) introduce a +180°
   flip in the GRIB2 direction path → K2 must fail; (c) swap a CCW begin corner in the
   emission (e.g. S begins SE) → K5 must fail. Paste each run.
2. **Emitted-file grammar vs the manual, YOUR OWN reading:** generate a file via the
   writer (synthetic input) and verify against `swan-user-manual.txt` Appendix-D cites
   (:7028-7031, :7041-7110, :7169-7306): first line `SWAN   1`, TIME/1 nonstationary,
   LOCATIONS, AFREQ **35** ascending 0.03→1.0, NDIR 72, QUANT/VaDens/m2/Hz/degr,
   per-timestep date + FACTOR + 35×72 integer matrix, frequency-major. Cross-check the
   axis against the LIVE deployed SPECOUT (`/var/lib/weewx-clearskies/swan/level2/
   SPEC_DWR_1.txt` on librewxr, read-only) — same 35-frequency ladder.
3. **Forbidden emissions:** grep the new emission path for `PAR`, `TPAR`, `BOUND SHAPE`,
   `BOUNDNEST2/3` — none may be emitted. `BOUNDNEST1 NEST 'nest_in.dat' CLOSED` (the
   L1→L2 nest mechanism) must be UNTOUCHED by the round (diff swan_formats.py's nest
   block region).
4. **Pinned-command regression:** diff the INPUT-building code paths — CGRID/INPGRID/
   READINP/GEN3/INIT HOTSTART/NESTOUT emission strings byte-unchanged vs 95abc74 (plan
   §3's protection). Only the BOUNDSPEC block construction may differ.
5. **No surviving station-path imports:** your own grep for
   `ww3_station_selection|ww3_station_catalogue` in production code (comments excepted;
   note stale comment refs as LOW findings).
6. **Config-time refusal role:** verify by code reading (and a mocked/cut-network run if
   feasible) that `_validate_ww3_boundary_viability`'s failure produces the same loud
   config-push refusal role as before (logged ERROR naming the extent, returns
   None/refuses — never silently passes).
7. **Doc-sync:** PROVIDER-MANUAL §14.3a-amendment now IMPLEMENTED (tags removed),
   ARCHITECTURE.md boundary paragraph rewritten live, both accurate to the shipped code
   (spot-check 5 claims).
8. **Scope:** `git show --stat` per commit — nothing outside the Phase-B allowlist
   (plan B1–B4 Files lists + tests/); frozen-core untouched; `CIRCLE 72 0.03 1.0 34`
   string unchanged.

The B-Accept ±10% station-position comparison is NOT yours (needs the live deploy; the
lead runs it and you recompute at the blind walk in Phase V). Findings ranked; empty rows
only with named rule-outs.
