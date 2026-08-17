> **Committed copy.** Source: `scratch/SYNTAX-607-VERIFICATION.md`, verbatim (no content
> changes below this note). This is the authoritative `6.07:NNNN` line-cite map for the
> plan's WW3 SYNTAX PRESCRIPTIONS rows — cites below point INTO
> `docs/reference/ww3-user-manual-v6.07.txt`, committed alongside this file at DOC-W.4.

# WW3 SYNTAX PRESCRIPTIONS — re-verification against v6.07 manual (Q5 ruling)

Authority: `scratch/ww3-manual-6.07.txt` (22,961 lines). Diff source for CHANGED/NOT-FOUND
verdicts: `scratch/ww3-manual-5.16.txt` (17,667 lines). Every 6.07 cite below was re-opened
at its exact line range and the quoted text confirmed present before being recorded.

## Structural note — read this before using any cite below

6.07 is NOT a uniform line-shift from 5.16. The manual was reorganized:

- **New Chapter 6** ("Program files", developer material) inserted around old §5.9,
  pushing everything after it down.
- **New Appendix G** ("Configuration of Input Files") consolidates every full example
  deck (`ww3_grid.inp`, `ww3_shel.inp`, `ww3_prep.inp`, `ww3_prnc.inp`, `ww3_bound.inp`,
  `ww3_bounc.inp`, `ww3_outp.inp`, …) that in 5.16 lived **inline inside the relevant
  §4.4.x subsection**. This is why most SYNTAX-row cites (which point at full example
  decks) shift by **~+7,160 lines**, while cites into Chapter 2 physics/Chapter 5 switch
  material shift by only **~+200–300 lines**. There is no single offset — each cite
  below was individually re-derived.
- **Former Appendix A** ("Managing multiple model versions") was **dropped**, so every
  later appendix letter shifted back by one: old **C** (nested runs) → new **B**; old
  **D** (MPI) → new **C**; old **E** (mosaic) → new **D**; old **F** (OASIS) → new **E**.
  6.07 adds a **new Appendix F** ("Coupling with NUOPC", not in 5.16) before the new
  Appendix G.
- §5.4.1/5.4.2/5.4.3 (mandatory/optional/default switches) renumbered to **§5.9.1/5.9.2/5.9.3**.

None of this is a behavior change — it only invalidates old line cites. Substantive
CHANGED/ADDITION findings are called out explicitly per-row below.

---

## Row 6 — `ww3_grid.inp` structure

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| Spectral def line grammar + example `1.1 0.04118 25 24 0.` | UNCHANGED | 14548–14562 | `1.1 0.04118 25 24 0.` | Digit-for-digit identical. A **second, different** worked example exists inline in §4.4.2 at 8415–8429 using `1.1 0.04118 32 24 0.` (32 dirs, not 24) — this is a 6.07-only addition (new short illustrative example alongside the legacy Appendix-G one); does not contradict the row, both are valid syntax illustrations. |
| ~40 freqs / 1.07 increment / 5× peak-freq / ~10° directional recommendation | UNCHANGED | 1432–1440 | "recommended number of frequencies is about 40, with a frequency increment factor 1.07... directional resolution ... is about 10." | All four numbers (40, 1.07, 5×, 10°) confirmed digit-for-digit against 6.07 text. |
| Model flags line `FLDRY FLCX FLCY FLCTH FLCK FLSOU`, example `FTTTFT` | UNCHANGED | 14566–14578 | `FTTTFT` | identical |
| Time-steps line, 4 values seconds, example `900. 950. 900. 300.` | UNCHANGED | 14608–14612 | `900. 950. 900. 300.` | Digit-for-digit identical |
| `&MISC FLAGTR = n` codes 0/1/2/3/4 | UNCHANGED | 15349–15361 | "0: No subgrid... 1: Transparancies at cell boundaries... 2: Transp. at cell centers. 3: Like 1 with cont. ice. 4: Like 2 with cont. ice." | identical wording |
| FLAGTR example `= 4` | UNCHANGED | 15490 | `&MISC CICE0 = 0.25, CICEN = 0.75, FLAGTR = 4 /` | digit-for-digit identical to 5.16:8175 |
| Obstruction field read as additional bottom-style input when FLAGTR>0 | UNCHANGED | 15927–15939 | "If sub-grid information is available as indicated by FLAGTR above, additional input... unit number of file (can be 10, and/or identical to bottom depth unit)" | identical |
| `!/O1` switch mandatory for nested-run boundary marking (App C.1 step 3) | UNCHANGED | 13735–13738 (now App **B**, not C — see structural note) | "Make sure that the model switch !/O1 is selected in the switch file" | identical wording, appendix letter changed C→B |

**Row 6 bottom line: no grammar or numeric-constant changes. All cites need updating (mostly a ~+7,160-line shift into the new Appendix G); the App C→B relettering applies.**

## Row 6a — `ww3_grid.inp` grid-definition + file-read grammar

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| Grid-def worked example `'RECT' T 'NONE'` / `12 12` / `1. 1. 4.` / `-1. -1. 4.` | UNCHANGED | 15716–15721 | `'RECT' T 'NONE'` ... `12  12` ... `1.  1.   4.` ... `-1. -1.  4.` | digit-for-digit identical |
| Bottom-depth read line fields (limiting depth, min depth, unit, scale, IDLA, IDFM, format, FROM, filename) | UNCHANGED | 15665–15696 | "Limiting bottom depth... scale factor for bottom depths (mult.), IDLA, IDFM, format for formatted read, FROM and filename." | identical |
| IDLA codes 1–4 | UNCHANGED | 15669–15675 | "1: Read line-by-line bottom to top. 2: Like 1, single read statement. 3: Read line-by-line top to bottom. 4: Like 3, single read statement." | identical |
| IDFM codes 1–3 | UNCHANGED | 15677–15681 | "1: Free format. 2: Fixed format with above format descriptor. 3: Unformatted." | identical |
| Unit 10 = field read inline, no comment lines | UNCHANGED | 15665–15667 | "If the above unit number equals 10, then the bottom depths are read this file... No comment lines allowed" | identical |
| Sign-convention TRAP example `-0.1 2.50 10 -10. 3 1 '(....)' 'NAME' 'bottom.inp'` | UNCHANGED | 15725 | `-0.1 2.50 10 -10. 3 1 '(....)' 'NAME' 'bottom.inp'` | digit-for-digit identical to 5.16:8418 — trap's factual basis (negative scale turns positive digits into water) still holds |
| Obstruction read: unit==bottom unit ⇒ same file assumed; scale example `0.2`; two NX×NY fields | UNCHANGED | 15920–16019 | "10 0.2 3 1 '(....)' 'NAME' 'obstr.inp'" / "if this unit number is the same as the previous bottom depth unit number, it is assumed that this is the same file without further checks" / "size of fields is always NX * NY" | all digit-for-digit identical |
| Status-map legend 0=land/1=sea/2=active boundary/3=excluded | UNCHANGED | 16050–16054 | "0: Land point. 1: Regular sea point. 2: Active boundary point. 3: Point excluded from grid." | identical |
| `FROM='PART'` segmented data, closed by mandatory `0 0 F` | UNCHANGED | 16022–16112 | "if FROM = 'PART', then segmented data is read from below" ... `00F` (pdftotext squishes the spaces; same artifact present at 5.16:8794 too — not a real syntax change) | identical |

**Row 6a bottom line: every claim UNCHANGED, all numeric examples verified digit-for-digit. Cites shift into Appendix G (~+7,300 lines from the 5.16 citations).**

## Row 6b — `ww3_shel.inp` structure

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| Forcing-flags fixed order: ice(5)/mud(3) optional, water levels, currents, winds, ice conc., 3× assimilation | UNCHANGED | 18480–18517 | "FF Water levels / FF Currents / TT Winds / T Ice concentrations / F Assimilation... Mean parameters / ...1-D spectra / ...2-D spectra" | identical order |
| Time frame: start line then end line `yyyymmdd hhmmss` | UNCHANGED | 18519–18527 | `19680606 000000` / `19680606 060000` | identical example |
| IOSTYP=1 generally recommended | UNCHANGED | 18542–18544 | "IOSTYP = 1 is generally recommended." | identical |
| Output types share `first-time interval(s) last-time` header, interval 0 disables | UNCHANGED | 18566–18578 | "first time... output interval (s), and last time... Output is disabled by setting the output interval to 0." | identical |
| Type 2 point output: `lon lat 'NAME'`, name ≤10 chars/no-spaces advised, closed by `'STOPSTRING'` | UNCHANGED | 19023–19076 | "longitude, latitude and name (C*10)... closed by defining a point with the name 'STOPSTRING'." | identical |
| Type 4 = restart cadence, no additional data | UNCHANGED | 19095–19098 | "Type 4: Restart files (no additional data required)." | identical |
| Type 5 = boundary(nest) cadence, no additional data | UNCHANGED | 19103–19106 | "Type 5: Boundary data (no additional data required)." | identical |
| Type 6 = dummy line | UNCHANGED | 19111–19113 | "Type 6: Separated wave field data (dummy for now)." | identical |
| Type 7 = coupling, fully commented unless COU compiled | UNCHANGED | 19122–19124 | "Type 7: Coupling. (must be fully commented if not used with switch COU..." | identical |
| Homogeneous field data closed by mandatory `'STP'` | UNCHANGED | 19150–19178 | "'STP' is mandatory stop string." | identical |

**Row 6b bottom line: every claim UNCHANGED. Note (pre-existing manual quirk, both versions): the deck's own comment literally says "Five output types are available" despite documenting seven (1–7) — this inconsistency exists identically in 5.16 and 6.07, it is not a 6.07 regression.**

## Row 6c — Wind-field preprocessor decks

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| `ww3_prep` field-type line grammar (type/format/time-flag/header-flag) | UNCHANGED | 17944–17960 | field type codes IC1/IC5/ICE/ISI/LEV/WND/WNS/CUR/DAT; format types AI/LL/F1/F2 | identical |
| `ww3_prep` grid-range line `x0 xn nx y0 yn ny` | UNCHANGED | 17994–17999 | `-0.25 2.5 15 -0.25 2.5 4` | identical structure/values to 5.16 example |
| `ww3_prep` data-file def: FROM/IDLA/IDFM + format, then unit+filename; unit 10 = inline | UNCHANGED | 18027–18040 | `'UNIT' 3 1 '(..T..)' '(..F..)'` / `10 'data_file.1'` / "If the above unit numbers are 10, data is read from this file" | identical |
| `ww3_prnc` field-type line, dim-names line (time dim must be `time`), var-names line, filename line | UNCHANGED | 18178–18225 | `'WND' 'LL' T T` / "time dimension is expected to be called 'time'" / `UV` / `'wind.nc'` | identical |
| **FINDING (pre-existing, not a 6.07 change)**: row's `ww3_prep` bullet quotes the field-type example as `'WND' 'LL' T T` | **CORRECTION, not a version change** | `ww3_prep.inp` actual example: 17983 (`'ICE' 'LL' F T`); the literal `'WND' 'LL' T T` string belongs to the `ww3_prnc.inp` example at 18178 | manual's actual `ww3_prep` example is `'ICE' 'LL' F T`, not `'WND' 'LL' T T` — same mismatch exists identically at 5.16:9306 (`'ICE' 'LL' F T`) vs 5.16:9528 (`'WND'...`, which is prnc's line). The plan's bullet accidentally reused prnc's literal quote for prep. Grammar (4-token field-type line) is correct either way; only the illustrative example value is misattributed. Low impact — no design consequence, but worth the lead correcting the quote when landing cites. |

**Row 6c bottom line: grammar fully UNCHANGED. One pre-existing (not 6.07-introduced) quote misattribution flagged above.**

## Row 7 — Switch-string grammar

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| One token per category (propagation/flux/linear-input/source-term/stability/etc.) | UNCHANGED | §5.9.1 Mandatory switches, 10002–10186 (was §5.4.1, 13677–13866) | "Of each of the below groups of switches exactly one has to be selected." | identical rule, section renumbered 5.4.1→5.9.1 |
| **Example switch string (Fig 6.1, w3adc)** | **CHANGED** | 10796–10800 | 6.07: `'F90 NOGRB SHRD PR3 UQ FLX2 LN1 ST2 STAB2 NL1 BT1 DB1 MLIM TR0 BS0 XX0 WNX1 WNT1 CRX1 CRT1 O0 O1 O2 O3 O4 O5 O6 O7 O11 O14'` vs 5.16: `'F90 NOGRB LRB4 SHRD NOPA PR3 UQ FLX2 LN1 ST2 STAB2 ...'` | **6.07 dropped the `LRB4` and `NOPA` tokens** from the manual's own w3adc illustration. This is the manual's own example only — never a prescription (plan already states "an agent never chooses a switch token"; OUR tokens are separately fixed by ADR-109/F1b) — so no design impact, but the row's literal quoted string is now stale and should be replaced with the corrected text above. |
| "No model-wide default" statement | UNCHANGED | §5.9.3 Default model settings, 10365–10390 (was §5.4.3, 14041–14045) | "a clear \"default\" model version can no longer be identified" | identical, section renumbered 5.4.3→5.9.3 |
| FLX0–FLX4, NL1/NL2, BT1, DB1, STAB0/2/3 all present with same meanings | UNCHANGED | 10052–10099 | flx0…flx4 (Eq refs unchanged); nl1/nl2; bt1 JONSWAP; db1 Battjes-Janssen | identical definitions |
| **stab3 compatibility** | **CHANGED** | 10079–10082 | 6.07: "stab3 Enable stability correction from Abdalla and Bidlot (2002). **Compatible with st3 and st4 only.**" vs 5.16: "stab3 ... **for st4.**" | 6.07 **widened** stab3's documented compatibility to include st3 (WAM4/ECWAM) as well as st4 (Ardhuin). Moderate impact for F1b: doesn't change the P1/P2 candidate framing (P2 already runs WITHOUT STAB3 per the defaults-untouched rule), but F1b's parenthetical "stab3 ↔ ST4 only" is no longer what the manual says — should be corrected to "stab3 ↔ ST3 or ST4" if the row is amended. |

**Row 7 bottom line: mandatory-switch grammar and category structure UNCHANGED (renumbered §5.4→§5.9). Two textual CHANGED items found (illustrative example string, stab3 compatibility) — neither forces a design change but both should be corrected in the plan's quotes.**

## Row 8 — Nest generation, parent side

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| Parent writes boundary data via `ww3_shel.inp` output type 5 begin/increment/end | UNCHANGED | (row 6b, confirmed above) | — | — |
| First nest file `nest1.ww3`, up to **9** per run, renamed `nest.ww3` in child dir | UNCHANGED | 13716–13718, 13805–13807 | "for instance nest1.ww3. This file is then renamed to nest.ww3" / "presently set up for producing up to **9** files with boundary data per model run" | digit "9" confirmed unchanged; **appendix relettered C→B** (structural note) |
| Verification duties: child reports "processed and found OK", no incompatible/missing warnings, `log.ww3` shows updates at expected times | UNCHANGED | 13787–13801 | "the program reports that the file nest.ww3 has been processed and has been found OK, and (ii) that no additional warnings are present... Also check the log file log.ww3" | identical wording |

**Row 8 bottom line: fully UNCHANGED, "9" confirmed digit-for-digit. Cite needs App C→B relabel.**

## Row 9 — External boundary assembly (`ww3_bound`/`ww3_bounc`)

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| `nest.ww3` built by `ww3_bound` (ASCII) / `ww3_bounc` (NetCDF), one spectral grid HARD CONSTRAINT | UNCHANGED | App **B.2** (was C.2), 13810–13820 | "generate nest.ww3 file from spectral output using ww3 bound... takes a list of spectra files, which should have the same spectral grid" | identical, App C→B |
| `ww3_bound.inp`: `WRITE` mode, interpolation method 1=nearest/2=linear | UNCHANGED | G.3.1, 17722–17738 | "Boundary option: READ or WRITE" / `WRITE` / "Interpolation method: 1: nearest / 2: linear interpolation" / `2` | digit-for-digit identical example (mode WRITE, method 2) |
| ASCII spectra in the `ww3_outp` transfer format | UNCHANGED | G.3.1, 17746–17748 | "These ASCII files use the WAVEWATCH III format as described in the ww3_outp.inp file." | identical |

**Row 9 bottom line: fully UNCHANGED. Cite needs App C.2→B.2 relabel; deck-example cite shifts into new Appendix G.**

## Row 10 — WW3→SWAN transfer file (`ww3_outp` ITYPE=1/OTYPE=3)

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| ITYPE=1 (spectra), OTYPE=3 (transfer file), plus scaling/unit/unformatted-flag inputs | UNCHANGED | 21674–21690 | "ITYPE = 1, Spectra... Sub-type OTYPE: ... 3: Transfer file... Scaling factors... Unit number for transfer file... Flag for unformatted transfer file." | identical |
| Example line `1 0. 0. 33 F` | UNCHANGED | 21688 | `1 0. 0. 33 F` | digit-for-digit identical to 5.16 |
| Record structure: file ID+nfreq/ndir/npoints+grid name; freq bins Hz; dir bins radians oceanographic conv.; per-time per-point name/lat/lon/depth/wind/current/E(f,θ) | UNCHANGED | 21692–21708 | "File ID in quotes, number of frequencies, directions and points. grid name..." / "Bin frequencies in Hz..." / "Bin directions in radians... (Oceanographic conv.)" / "Point name (C*10), lat, lon, d, U10 and direction, current speed and direction" / "E(f,theta)" | identical |
| Formatted output free-format readable | UNCHANGED | 21710 | "The formatted file is readable using free format throughout." | identical |

**Row 10 bottom line: fully UNCHANGED, digit-for-digit. Cite shifts into the ITYPE/OTYPE reference table region (~+9,600 lines from 5.16's citation — this table is deep inside the `ww3_outp` program-file section, which also moved due to Chapter 6 insertion).**

## Row 11 — Boundary-only validation run

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| Recommended nest test: wind OFF, no restart file, energy enters only via boundary | UNCHANGED | App **B.1** (was C.1), 13795–13801 | "make a model run of the small scale model where the wind fields are switched off in ww3_shel.inp, and where no restart file restart.ww3 is made available. In such a model run, wave energy can only enter the domain from the boundaries." | identical wording; App C→B |

**Row 11 bottom line: fully UNCHANGED. Cite needs App C.1→B.1 relabel.**

## Row 12 — Island representation (FLAGTR)

Covered under row 6/6a (FLAGTR codes 0–4, obstruction-grid grammar) — UNCHANGED, see above. No standalone new claims beyond row 6a's obstruction-read grammar.

## Row 13 — WW3 grids are spherical

No manual-syntax claim to verify (design statement; BOUNDNEST3 `[xgc]/[ygc]` bridge is SWAN-side, correctly out of scope per the brief). Nothing to re-verify.

---

## F1b — WW3 physics configuration cites

| Claim | Verdict | 6.07 cite | Quote | Notes |
|---|---|---|---|---|
| P1 = ST6 (BYDRZ), §2.3.11 | UNCHANGED (section renumbered by line only) | 2832–3250 | "2.3.11 Sin + Sds: Rogers et al. 2012 & Zieger et al. 2015 / Switch: ST6 / Provided by: A. Babanin, I. Young, M. Donelan, E. Rogers, S. Zieger, Q. Liu" | was 5.16 :2522–2800; still immediately follows the ST4 section, same relative structure |
| P2 = ST4 (Ardhuin et al. 2010), §2.3.10 | UNCHANGED | 2516–2832 | "2.3.10 Sin + Sds: Ardhuin et al. 2010 ... / Switch: ST4 / Provided by: F. Ardhuin" | was 5.16 :2232–2520 |
| ST6 negative-input term (maps to SWAN's `NEGATINP`) | UNCHANGED | 2973–2980 | "Negative Input. Apart from the positive input, ST6 also has a negative input term... adjustable through the SIN6 namelist parameter SINA0." | was 5.16 :2673; note `NEGATINP` itself is a **SWAN** token — the plan correctly frames this as a cross-model conceptual mapping, not a literal WW3-manual string, and neither manual version contains the literal text "NEGATINP" (expected, not a defect) |
| ST4 TEST471 named default tunings | UNCHANGED | 2625–2631 | "TEST471 generally provides the best results at global scale..." | was 5.16 :2381–2412 |
| **ST6 calibration table (Table 2.8)** | **CHANGED — HIGH IMPACT** | 3066–3082 | See detail below | **6.07 added a third "vers. 6.07" default-value column, distinct from 5.16's values** |
| CDFAC (FLX4) pairs with ST6/P1; FLX0 pairs with ST4/P2 | UNCHANGED | Table 2.8 CDFAC row (3078); FLX0 def (10052) | CDFAC = 0.09 in **both** the vers.5.16 and vers.6.07 columns; FLX0 "No routine used; flux computation included in source terms" | The one namelist value F1b explicitly cites (CDFAC=0.09) is UNCHANGED — see high-impact finding below for the values that DID change |
| NL1(DIA) vs NL2(WRT), ~40 freqs/1.07 pricing NL2 out | UNCHANGED | 1432–1440 (same as row 6) | — | — |
| §5.9.1 mandatory switch groups, exactly one token/group, no model-wide default | UNCHANGED | 10002–10186, 10365–10390 | (same as row 7) | renumbered §5.4→§5.9 |
| Pure-OpenMP combination `SHRD OMPG OMPX` | UNCHANGED | 10279–10282 | "A pure OpenMP approach requires the shrd, ompg and ompx switches" | was 5.16 :13946–13960; digit/token set identical |
| `OMP_NUM_THREADS ≤ 4` | **NOT a manual quote — not applicable** | — | — | This is stated in the plan as an environment/hardware constraint (our build host), not a manual-asserted numeric threshold. Manual text at both versions (6.07:10728, 5.16:14387) only says `-O` uses `OMP_NUM_THREADS`; no numeric cap is stated by the manual itself. Not a verification target for this pass — flagging so the lead knows it isn't manual-sourced and shouldn't be cited as if it were. |

### HIGH-IMPACT FINDING — ST6 Table 2.8 default calibration values changed at 6.07

6.07's Table 2.8 (line 3066) added a third column "vers. 6.07" alongside "vers. 4.18" and
"vers. 5.16". Comparing 5.16's defaults (the ones available when the earlier feasibility
work was done) to 6.07's (what our built **6.07.1** binary actually compiles in):

| Parameter | var/namelist | 5.16 default | **6.07 default** | Changed? |
|---|---|---|---|---|
| a1 | SDSP1/SDS6 | 3.74E-7 | **4.75E-6** | YES |
| a0 | SINA0(→SINWS in 6.07's row label)/SIN6 | 5.24E-6 | **7.00E-5** | YES |
| β (CSTB1) | SWL6 | n/a (hard-coded 28.0) | **32.0** (now namelist-exposed) | YES — was hard-coded, now a tunable default |
| Nhf (SWLB1) | SWL6 | n/a (hard-coded 6.0) | **6.0** (now namelist-exposed) | value unchanged, representation changed (hard-coded → namelist) |
| CDFAC | FLX4 | 0.09 | 0.09 | **NO — unchanged** |
| NLPROP | SNL1 | F | F | NO — unchanged |
| C constants | SNL1 | 0.0032 / 1.00E-4 / 3.00E7 | 0.0041 / 1.0 / 3.00E7 | first two changed |

**Why this matters:** F1b's rule is "each package's manual defaults, UNTOUCHED in Phase F" —
this rule is still satisfiable and requires no design decision (F1's build will compile in
whatever 6.07 hard-codes as default; nothing in our deck sets these namelist values
explicitly). The finding is purely about **provenance of past numbers**: if any earlier
feasibility document, ADR draft, or F5-catalog note quotes ST6 defaults as
"SDSP1=3.74E-7" / "SINA0=5.24E-6" / "β=28.0" (the 5.16-era values), those are **stale for
our built 6.07.1 binary** and should not be treated as ground truth going forward — the
6.07 column above is what F1's smoke test will actually exercise. The one value the plan
explicitly names and depends on (**CDFAC=0.09** for the P1/FLX4 pairing) is confirmed
unchanged, so F1b's specific pairing rationale is unaffected.

### Secondary footnote finding (low impact)

6.07 §2.3.11 adds footnote 6 (line 3232): "This was changed to CDFAC=1.0 since vers. 6.07
as the magnitude 10⁻⁴ was hard-coded in FLX4 module." This refers to a **different,
generic/un-tuned FLX4 baseline value** mentioned in running prose (distinct from the
ST6-specific Table 2.8 CDFAC=0.09 above) — its representation moved from `1.0E-4` to
`1.0` because the module now hard-codes the 10⁻⁴ scale internally. Since our P1 candidate
uses the ST6-calibrated Table 2.8 value (confirmed unchanged at 0.09), this footnote does
not affect F1b's design — flagged only for completeness in case any future bulk-adjustment
tuning discussion touches generic FLX4 CDFAC.

---

## Trap re-confirmation (brief §"keep the known traps in view")

- **Depth-sign/scale-factor trap** (row 6a): example `-0.1 2.50 10 -10. 3 1 ...` confirmed
  digit-for-digit unchanged at 6.07:15725. Trap's factual basis (negative scale turns
  positive file digits into water; ETOPO stores water as negative elevations) still holds.
- **IDLA/IDFM codes**: confirmed unchanged (1–4 / 1–3) at 6.07:15669–15681.
- **`'STOPSTRING'`/`'STP'` literals**: both confirmed unchanged, exact strings, at
  6.07:19076 (`'STOPSTRING'`) and 6.07:19178 (`'STP'`).
- **FLAGTR values**: confirmed unchanged, 0–4, at 6.07:15349–15361, example `=4` at 15490.
- **[xgc]/[ygc] misprint**: SWAN-side, correctly out of scope — not touched.

---

## Summary — findings ranked by F2 impact

1. **HIGH — ST6 calibration table gained a 6.07-specific default column** (SDSP1, SINA0,
   β, Nhf changed values or representation; CDFAC unchanged at 0.09). No design action
   required (defaults-untouched rule already covers it via automatic compile-in), but any
   document quoting 5.16-era ST6 defaults as current is stale.
2. **MODERATE — `stab3` compatibility widened** from "st4 only" (5.16) to "st3 and st4"
   (6.07). No candidate-framing impact (P2 excludes STAB3 by design already); F1b's
   parenthetical should be corrected if the row is amended.
3. **LOW — Fig 6.1 (w3adc) example switch string changed**: 6.07 dropped `LRB4` and
   `NOPA` tokens from the manual's own illustration. Purely illustrative text, no
   prescriptive weight — not an OUR-switch source.
4. **LOW / pre-existing — row 6c's `ww3_prep` field-type quote is misattributed** (quotes
   prnc's `'WND' 'LL' T T` where prep's actual example is `'ICE' 'LL' F T`). Present
   identically in 5.16 — not introduced by the 6.07 switch, just never caught. Grammar
   itself (4-token field-type line) is correct.
5. **STRUCTURAL — every cite in rows 6/6a/6b/6c/7/8/9/10/11/F1b needs updating** to the
   new line numbers recorded in this report; the shift is non-uniform (Appendix
   relettering C→B, D→C, E→D, F(old)→E; new Appendix F "NUOPC" and Appendix G
   "Configuration of Input Files" added; §5.4→§5.9 switch-section renumbering).

## Bottom line (plain English)

Switching the authority from the 5.16 manual to the 6.07 manual does **not** change any
grammar our WW3 decks need to follow — every field order, code table (IDLA/IDFM/FLAGTR/
status-map legend), keyword, and worked-example numeric value in rows 6 through 13 is
identical in substance between the two manual versions; only the page/line locations
moved because 6.07 reorganized the document (new developer chapter, consolidated
example-deck appendix, dropped/added appendices). The one real substantive change that
matters for what we build is that **6.07 ships different default calibration numbers for
the ST6 (P1) physics package** than 5.16 did — but since Phase F's rule is to use
manual/compiled-in defaults untouched, this requires no design change, only a caution
that any older document citing 5.16-era ST6 defaults as ground truth is now out of date
for our 6.07.1-built binaries. Two low-impact quote corrections (the w3adc example string,
the misattributed `ww3_prep` example line) and one moderate wording correction (`stab3`'s
now-broader compatibility) round out the findings; none of them block F2.

---

## ww3_grid measured-behavior addendum (F2, 2026-08-16)

*(Not a cite-location or quoted-value re-verification like the rows above — these are
four RUNTIME findings from actually executing `ww3_grid` end-to-end during F2's grid
build, each confirmed by reproducing the same failure against the manual's own literal
Appendix G.1.1 worked example text before applying the fix. Recorded here per the
lead's F2b ruling so DOC-W.4's committed cite map carries measured deck-runnability
gaps, not just cite-location/quoted-value drift.)*

| # | Finding | Evidence | Fix applied |
|---|---|---|---|
| 1 | **Model-flags line must be space-separated.** The manual's own printed `FTTTFT` (6.07:14560, no spaces) is a page-compaction artifact, not valid input. Feeding it verbatim (even copied byte-for-byte from the manual text) produces `*** WAVEWATCH III ERROR IN W3GRID : ERROR IN READING FROM INPUT FILE, IOSTAT= 0` immediately after the "Model definition:" header. | Reproduced against a test deck built from the manual's OWN literal Appendix G.1.1 text (not just our own deck) — same failure. The shipped, WORKING `ww3_ts2` regtest deck (`regtests/ww3_ts2/input/ww3_grid.inp`, the same case F1's smoke test ran successfully) uses space-separated `F T T F F T`. | Use space-separated flags, e.g. `F T T T F T` (same manual-stated flag VALUES, 6.07:14560's `FLDRY FLCX FLCY FLCTH FLCK FLSOU` = F,T,T,T,F,T — only the delimiting changed). |
| 2 | **An empty namelist section breaks the reader.** Going straight from the time-steps line to the literal `END OF NAMELISTS` string (exactly as the manual's own Appendix G.1.1 example shows, with zero namelist entries in between) reproduces the same IOSTAT=0 error as finding 1, independent of the flags fix. | Same test-deck reproduction as finding 1; the working `ww3_ts2` deck always carries at least one namelist line (`&PRO2`, `&PRO3`, `&PRO4`, `&SDB1`, `&MISC` in its case). | Always state at least one namelist entry explicitly — F2 used `&MISC FLAGTR = 0 /` (G1, no obstruction) / `= 2 /` (G2, cell-center transparencies), which is also the PRIME-DIRECTIVE-11-correct choice (FLAGTR stated, never silently defaulted). |
| 3 | **"Output boundary points" is a separate, easy-to-miss mandatory section.** After the bottom-depth and status-map blocks parse successfully (confirmed by `ww3_grid` correctly printing "Input boundary points" / "Excluded points" counts matching our own independently-computed status-map values), `ww3_grid` prints an "Output boundary points:" header and then fails with `*** WAVEWATCH III ERROR IN NEXTLN : PREMATURE END OF INPUT FILE` unless a closing zero-point line is supplied. | The section and its mandatory close (`0. 0. 0. 0.  0`) are documented at 6.07:16148-16179, but positioned separately from the bottom-depth/status-map block text (6.07:15665-16045) that most of SYNTAX row 6a's citations point at — easy to omit because it doesn't read as part of "the grid-definition block" on a first pass. | Always emit the closing line `0. 0. 0. 0.  0` after the status-map read line, even when zero output boundary points are wanted (our G1/G2 decks define none — WD9's point output lives in `ww3_shel.inp`, not here). |
| 4 | **Apparent contradiction, resolved (no fix needed, recorded for clarity):** `ww3_grid.inp`'s own doc text (6.07:15557) says "the outer grid lines are always defined as land points," which reads as forbidding active-boundary-point marking on a grid's outer ring (which is exactly what F2's WD7 S/W boundary marking does). | Chapter 6's fuller text (6.07:11866-11869) resolves it: "the outer grid points ... will be considered as land points, inactive points, **or active boundary points**" — all three are valid outer-ring states; the grid-def section's phrasing is shorthand for "non-propagating by default," not "forced to land." | None — F2's boundary-point marking on the S/W perimeter is correct as designed; this row exists so the apparent contradiction isn't rediscovered as a false blocker. |

**Where these bind:** SYNTAX row 6 (spectral def / model flags / time-steps / namelist
section) and row 6a (grid-def / bottom-depth / status-map / output-boundary-points
blocks) should carry these four findings as citations at DOC-W.4's commit, alongside the
existing UNCHANGED/CHANGED verdicts above. None of the four are quoted-value drift
between 5.16 and 6.07 — they are gaps in what a compact manual excerpt shows vs. what a
real, complete, runnable deck needs, caught only by actually running `ww3_grid` to
completion (F2, `scratch/F2-CONFIG-REPORT.md` §6-§7).

---

## Measured-behavior addendum, part 2 (F2b/F2c, 2026-08-16) — wind, boundary, shel

Same discipline as the ww3_grid addendum above: runtime findings from actually running
`ww3_prep`, `ww3_bound`, `ww3_outp`, `ww3_strt`, and `ww3_shel` end-to-end, each traced
to either a real shipped regtest example or the WW3 6.07.1 source itself
(`model/ftn/*.ftn`), not guessed. Full narrative: `scratch/F2-CONFIG-REPORT.md` F2b/F2c
addenda.

| # | Row | Finding | Authority |
|---|---|---|---|
| 5 | 6c | `ww3_prep`'s `'WND' 'LL'` data-file-definition line needs **TWO** format strings (header record format, data record format), not one — `'NAME' IDLA IDFM 'header_fmt' 'data_fmt'` — and the field data is normally read from an **external file** (`FROM='NAME'`, any unit ≠ 10), not inline. No "additional input for data" (dimension/reclen/missing-value) line exists for `WND`/`LL` — that block belongs to a different field-type branch. | `regtests/ww3_ts4/input_rg_multi/ww3_prep_wind.inp` + `wind.raw` (WW3 6.07.1 b582f8c) |
| 6 | 9 | `ww3_bound.inp`'s spectra-file list IS closed by the literal `'STOPSTRING'` (the manual's own template doesn't show this, but the program requires it — confirmed both by testing and by reading `model/ftn/ww3_bound.ftn:218`, `IF (FILENAME(:JJ).EQ."'STOPSTRING'") EXIT`). Without it: `ERROR IN NEXTLN: PREMATURE END OF INPUT FILE`. | `model/ftn/ww3_bound.ftn:218`; cross-confirmed by `regtests/ww3_tp2.8/input/ww3_bounc.inp`'s own use of the same terminator |
| 7 | 9/10 | **Transfer-file format, now proven authoritative** (supersedes prior uncertainty): header `'ID'(A22 fixed-width field, functionally forgiving of minor padding) NFREQ NDIR NPOINTS 'GRIDNAME'`, read via fixed format `(A1,A22,A1,X,2I6)` for the first two integers only; freq/dir arrays free-format; per-time `yyyymmdd hhmmss` free-format; per-point info line **fixed-format** `(A1,A10,A1,2F7.2,F10.1,F7.2,F6.1,F7.2,F6.1)` = name/lat/lon/depth/wind-speed/wind-dir/current-speed/current-dir; E(f,θ) free-format. Direction values are checked for COUNT only (`NTHI.NE.NTH` → reject) — order/monotonicity is NOT validated, so no re-sorting is needed after a nautical-FROM→oceanographic-TO conversion. | `model/ftn/ww3_bound.ftn:315-435` (full read logic); specimen produced by our own `ww3_outp` per `regtests/ww3_ts2/input/ww3_outp_spec.inp` (OTYPE 1→3) and `regtests/ww3_tp2.8/input/ww3_outp.inp` (full ITYPE=1/OTYPE=3 documentation block) |
| 8 | 9 | The `XFR` (frequency increment factor) consistency check (`ABS((FREQ(2)/FREQ(1))-XFR).GT.0.005` → `ILLEGAL XFR` reject) is the SOURCE-LEVEL enforcement of row 9's "single spectral grid across all input files" hard constraint — confirmed by direct rejection when feeding a mismatched-grid specimen, and direct pass-through when feeding data on the target grid's own axes. | `model/ftn/ww3_bound.ftn:361` |
| 9 | 6b | `ww3_shel.inp`'s forcing-flags block ALSO needs space-separated `T`/`F` pairs (`F F` not `FF`) — the same packed-vs-spaced gap as finding #1 (`ww3_grid`'s model-flags line), now confirmed in a second program's deck. Packed flags produce `Fortran runtime error: Bad logical value while reading item 2`. | Direct test against F1's P1-built `ww3_shel` binary |
| 10 | 6b | `ww3_strt.inp`'s calm-start option is **ITYPE=5** ("Starting from calm conditions... No additional data"), not ITYPE=1 (Gaussian spectrum, requires 9 further parameters — using it with no data produces `PREMATURE END OF INPUT FILE`). | 6.07:17622-17707 (`ww3_strt.inp`'s own full worked example, G.2.1) |
| 11 | 6b | Our 6.07.1 build's Group-2 (standard mean wave params) output-field count exceeds the 9-parameter baseline (6.07 added STE-related optional params — consistent with the ST6-table precedent already found in the Q5 syntax re-verification). Positional group T/F flags for Type-1 output are therefore version/build-sensitive; the **`N`/namelist-symbol** method (`N` then a line of parameter symbols, e.g. `HS`) sidesteps the exact-count ambiguity entirely. | Direct test; proven pattern from `regtests/ww3_ts2/input/ww3_shel.inp`'s own shipped deck |

**Where these bind:** row 6c (wind preprocessor), row 9 (external boundary assembly —
now has its full proven format), row 10 (transfer-file record structure — cite map
should treat `model/ftn/ww3_bound.ftn` as the primary authority alongside the manual
prose), and row 6b (`ww3_shel.inp`/`ww3_strt.inp` grammar) all gain findings from F2b/F2c
at DOC-W.4's commit. Finding #7 in particular is the format authority W2's real boundary
emitter should implement against.
