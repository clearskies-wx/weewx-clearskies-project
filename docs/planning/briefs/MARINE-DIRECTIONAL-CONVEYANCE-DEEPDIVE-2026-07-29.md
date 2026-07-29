# Marine deep-dive handoff: we are DESTROYING wave DIRECTION somewhere in our own code (2026-07-29)

**This file exists so the next session (post context-compaction) starts correct, not from zero.**
Operator was (repeatedly, correctly) frustrated that prior work relied on training-data assumptions
instead of reading specs and verifying real output. Do not repeat that. Read this fully, then do the
deep dive.

## THE PROBLEM, in plain English (no internal ID codes)

Reality off Huntington Beach (Surfline, operator ground truth): **surf face 4–6 ft**, and **THREE
distinct swells that differ mainly by the DIRECTION they come from**:
- ~**18 s** from the **SSW (~195°)**
- ~**16 s** from the **SSE (~168°)**
- ~**10 s** from the **S (~184°)**

We publish garbage: one/two smeared swells at the wrong period (a ~8.1 s *mean*, and a broad ~13 s
lump), and we do NOT preserve the three direction-distinct swells.

**This is DEFINITELY our bug, and it is a DIRECTIONAL bug.** Established this session by reading the
code (not assuming):
1. The ocean-wave input (NOAA WW3 station 2-D directional spectra — energy as a function of frequency
   AND direction) is read **INTACT**. Full 50-frequency × 36-direction matrix. Its correctness was
   reconciled against the buoy's own bulk wave height (`.bull` file), which even caught a real axis
   bug. The full spectral structure — including all the swells and their directions — is present after
   we read it.
2. We hand that **full 2-D spectrum** to SWAN as a boundary condition, still intact (verified in code,
   with cited manual references).
3. We publish smeared, mostly-directionless output.

Therefore: **the three swells ARE in our input** (everyone, Surfline included, uses the same NOAA
global wave data — there is no other open-ocean source). We are losing them **in our own processing,
downstream of the intact 2-D boundary.** The task is to find the exact step that collapses/mis-maps
DIRECTION and fix it.

## THE ENGINEERING FRAMING (operator's, and it is the load-bearing point)

- The three swells are distinguished by **DIRECTION**, not just period. Two of them (18 s SSW, 16 s
  SSE) are close in period — what separates them is where they come FROM.
- **Any step that collapses the direction axis destroys the thing that matters:** integrating energy
  over direction, averaging directions, projecting to "energy vs period" (1-D), or mis-mapping the
  direction convention/axis so energy is propagated FROM the wrong compass bearing.
- **Energy in the wrong direction is worthless.** SWAN's entire value is propagating directional wave
  energy (shoaling, refraction) toward the beach. If direction is wrong or lost, SWAN output is
  meaningless regardless of how right the total energy looks.
- **DO NOT diagnose in the "energy vs period" (1-D) domain.** That projection merges
  same-period-different-direction swells by construction and CANNOT show three direction-separated
  trains. The earlier "broad 13 s hump / ~2 trains" conclusion came from exactly this invalid 1-D
  projection — discard it. **Work in the full 2-D (frequency × direction) domain and track DIRECTION
  at every stage.**

## MANDATE: FULLY READ THE SWAN MANUAL FIRST (do not skip, do not use training data)

- Local copy (DO NOT download — it is committed): `docs/reference/swan-user-manual.pdf`. Extract text
  with `pdftotext -layout docs/reference/swan-user-manual.pdf <out.txt>` and read it. A partial
  curated extract exists at `docs/reference/swan-commands-extract.md` but it is NOT the whole manual —
  read the FULL manual for the directional machinery.
- Sections that matter for this bug: **coordinate & direction conventions** (Units and coordinate
  systems, node7); **BOUNDSPEC / boundary spectral file format** (Appendix D, node27); **how SWAN
  represents and propagates the 2-D directional spectrum**; **CGRID directional resolution** (we use
  `CIRCLE 36` = 36 direction bins, 10° each); **NESTOUT / BOUNDNEST1** nesting (does each nest preserve
  the directional spectrum?); how SWAN interpolates an incoming boundary spectrum onto its own
  direction grid.
- Rule now written into the repo: SWAN docs are local, never download them
  (`reference/clearskies-dev.md`, `rules/agents.md`).

## THE SUSPECT CHAIN — trace DIRECTION through every stage, find where it dies

Data flow: WW3 .spec → our boundary file → SWAN L1 → nest to L2 → L3 → L4 → extract spectrum for the
1-D surf model → split into named swells → publish. At each stage, dump the 2-D directional spectrum
(or the per-swell directions) and find where 3 directions become 1, or get rotated wrong.

1. **Boundary-write direction convention — PRIME SUSPECT (self-flagged unverified in the code).**
   `services/swan_formats.py`:
   - `_ww3_dir_rad_going_to_to_swan_nautical_coming_from_deg()` (~line 2016): converts WW3 direction
     (radians, nautical, "going-to") → SWAN (degrees, nautical, "coming-from") with a bare **+180°**.
   - The code's OWN comment admits this +180 was reasoned from the manual/`wavespectra` library but
     **NOT reconciled against a live station file** the way the energy axis-order was. A wrong
     direction convention rotates ALL the energy to wrong bearings → SWAN refracts/propagates it from
     the wrong way → wrong surf. **Verify the emitted boundary directions against a real WW3 spectrum
     AND against what SWAN's manual says BOUNDSPEC expects. This could be the whole bug.**
   - Also check the per-value density unit conversion (~line 2033, ×π/180) is not interacting.
2. **Boundary-file → SWAN direction-grid mapping.** `ww3_spectrum_to_swan_boundary()`
   (`swan_formats.py:2036`) writes a full 2-D matrix; SWAN interpolates it onto its `CGRID ... CIRCLE
   36` grid. Confirm from the MANUAL that our BOUNDSPEC file's direction axis (order, units, wrap,
   coming-from) matches what SWAN reads, so the interpolation doesn't scramble bearings.
3. **Nesting L1→L2→L3→L4.** `swan_formats.py` `BOUNDNEST1` (~1596), `NESTOUT` (~1761). Does the nested
   boundary carry the full directional spectrum between levels, or is something lost/rotated at a nest?
4. **Extracting the spectrum from SWAN output.** `services/swan_spectral.py`:
   `parse_specout_file()` (SWAN SPECOUT 2-D), `parse_table_pt_partitions()` (~949, SWAN's own PT*
   partition columns incl. `PTDIR` direction), `watershed_partitions_to_component_format()` (~1158),
   `decompose_spectrum()` (~632). Confirm DIRECTION (`PTDIR`/component direction) is read and carried,
   not dropped.
5. **The watershed partition ↔ CURVE-station JOIN — leading suspect for the final collapse.**
   `services/swan_runner.py`: the coordinate join that matches SWAN partition output to output
   stations. Reported to orphan stations → empty component list → a no-fallback rule forces a **single
   bulk partition**, which publishes the **mean period (`TM01`, 8.1 s) and one direction** instead of
   the per-swell peak periods and three directions. This is where multi-direction most plausibly
   collapses to one. Instrument it: partitions (with directions) in vs components out.
6. **Hand-off to the 1-D surf model.** `services/surf_1d_analytical.py`, `services/surf_1d_pipeline.py`,
   `services/transect_handoff.py`. Does it take per-swell (height, period, **direction**) and preserve
   direction, or collapse to scalars?
7. **Published output.** `providers/nearshore/swan.py` (canonical partitions ~1467/1767):
   `spectralComponents` / `multiSwell` — how many components, with what directions, do we actually emit?

## WHAT IS VERIFIED-GOOD (don't waste time re-deriving; DO re-verify #1's direction flip live)
- `services/ww3_spectrum.py` — raw WW3 `.spec` parse. Full 2-D (50 freq × 36 dir). Reality-validated
  vs `.bull` bulk Hs; caught a direction-major-vs-frequency-major axis bug (would've been 24% high).
  Direction axis = radians, nautical "going-to", wraps through zero mid-array.
- `ww3_spectrum_to_swan_boundary()` (`swan_formats.py:2036`) — writes the FULL 2-D spectrum as a SWAN
  `BOUNDSPEC ... FILE`. No synthesis, no fixed spread. The OLD code that synthesized a single JONSWAP
  hump from scalar parameters (the true training-data failure) and a hardcoded calm-boundary TPAR are
  BOTH deleted (`swan_formats.py:1962-1983`). **Caveat: the +180 direction flip (#1) is the one piece
  the authors did NOT verify against live data — treat as unverified.**

## KEY FILE MAP (verified this session)
| Purpose | Location |
|---|---|
| WW3 raw 2-D spectrum parse | `services/ww3_spectrum.py` |
| WW3 → SWAN boundary write (full 2-D) | `services/swan_formats.py:2036`; dir fn `:2016`; density factor `:2033` |
| SWAN INPUT (CGRID CIRCLE 36 / BOUNDNEST1 / NESTOUT) | `services/swan_formats.py:1508` (CGRID), `1596` (BOUNDNEST1), `1761` (NESTOUT) |
| SWAN spectral output + partitions (incl. direction) | `services/swan_spectral.py:632/949/1158`, `parse_specout_file()` |
| Watershed↔station JOIN (suspect for final collapse) | `services/swan_runner.py` (the PT*↔CURVE-station coordinate join) |
| 1-D surf hand-off | `services/surf_1d_analytical.py`, `services/surf_1d_pipeline.py`, `services/transect_handoff.py` |
| Published swell components | `providers/nearshore/swan.py` (~1467/1767) |
| Plan (Track A working model; Phase 2 = the swell-split fix) | `docs/planning/MARINE-WORKING-MODEL-PLAN.md` |

Marine service runs on host `librewxr` (SSH: `ssh -F .local/ssh/config librewxr`; repo cmds
`sudo -u ubuntu`; SWAN binary `/usr/local/bin/swan`; workdirs `/var/run/weewx-clearskies/swan/`).

## HOW TO WORK THIS (post-compaction next actions, in order)
1. **Fully read the SWAN manual** directional/boundary/nesting sections (above). No SWAN behavior from
   memory.
2. **Deep-dive trace in the 2-D directional domain.** On a real run, dump the directional spectrum (or
   partition directions) at each stage in the suspect chain and find the exact file/line where the
   three swell directions collapse to one, or get rotated to wrong bearings. Track DIRECTION, never
   just energy.
3. **Verify the boundary +180° direction convention (#1) against a live WW3 spectrum** and SWAN's
   documented BOUNDSPEC convention — prime suspect.
4. **Report the exact stage that destroys direction**, then fix it. Validate against reality
   (Surfline's 3 swells at 18 s SSW / 16 s SSE / 10 s S), never against the model's own output, and
   never via a 1-D energy-vs-period projection.

## RULES I KEEP VIOLATING — STOP
- Don't assert SWAN/WW3 behavior from training data. Read the manual/spec; verify against real output.
- Validate against reality, not the model's own numbers, and not a 1-D energy projection.
- The load-bearing physical quantity here is DIRECTION. Preserve the 2-D spectrum end to end.
- Don't hedge a proven conclusion: input intact + output garbage ⇒ our code IS the culprit.
