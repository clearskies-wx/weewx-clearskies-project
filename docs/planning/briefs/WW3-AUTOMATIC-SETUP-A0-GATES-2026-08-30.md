# WW3 Automatic Setup Parity — A0 Results-Free Gate Lock

**Round:** A0 evidence/prototype only, 2026-08-30
**Authority:** `MARINE-MODEL-RECOVERY-PLAN-2026-08-29.md` §8A, decision D14
**Status:** locked method specification; no candidate result is recorded here
**Environment:** WSL/local scratch only. No production mutation and no librewxr scratch directory unless separately named and approved.

## 1. Purpose and contamination firewall

A0 determines the evidence needed for a later operator ruling on six separate choices:

1. **O** — NOAA spectra to project-WW3 G1 active-cell/source mapping.
2. **H** — project-WW3 G1 to SWAN L2 `BOUNDNEST3` curve.
3. **D** — diagnostic point output separate from the SWAN boundary transfer.
4. **G** — globally usable wetness/bathymetry source and datum policy.
5. **I** — artifact dependency, invalidation, generation promotion, and rollback policy.
6. **B** — WW3 initialization/bootstrap method.

This file locks methods, fixtures, comparison relationships, refusal forms, resource accounting, and decision-packet fields **before any prototype output is read**. A prototype worker must not edit this file. The later Sol auditor receives the source/manual inventory and this file, not an implementer narrative as evidence. Results belong in a separately named prototype report; this file retains the no-results placeholders in §13.

No A0 participant may select O/H/D/G/I/B, merge axes under a combined label, choose a new scientific criterion, alter a production contract, or infer a global conclusion from synthetic geometry. An unbound criterion, missing source, conflicting authority, or need for a new persisted artifact/configuration/dependency is a refusal and an operator-decision packet, not a repair.

## 2. Fixed scope, authorities, and ownership

### 2.1 Fixed facts

- WW3 remains the deep-water model; SWAN remains L2–L4; the model handoff and grids are not changed by A0.
- The configuration-time geography/bathymetry pipeline is the intended automatic setup authority. Forecast cycles consume a frozen derivation and do not re-derive geography.
- O and H consume shared installation evidence but are separate contracts. `OPEN`/`CLOSED` belongs only to H; it does not select G1 status-2 cells.
- `ww3_l2_transfer.ww3` is the prospective canonical SWAN transfer and must be boundary-only. Buoy, seam, and `DREF*` output remain diagnostic consumers.
- R3 only refuses exhausted/short/unmergeable transfer use. It is not a topology or source/status consistency guard.

### 2.2 Authority inventory to be reconciled after A0

| Authority | Relevant requirement/conflict | A0 owner |
| --- | --- | --- |
| Recovery Plan §8A | Six independent decisions, global/rotational symmetry, cell/segment wetness, topology and rollback evidence | Gate lock / Sol audit |
| ADR-100, 2026-08-17 amendment | geography fan/regime are a WW3 setup consumer for extent and boundary placement | Source/manual inventory |
| ADR-109 D3/D6/D13 and gaps | existing S/W status/placement and transfer assumptions conflict with ADR-100 | Sol audit; operator ruling |
| Evolution Plan W3/W4 and Q4/PW7 | historical `CLOSED` and S/W/east-land rationale is SoCal-specific and cannot govern a global implementation | Sol audit; later documentation owner |
| Local SWAN manual §2.6.3 and `BOUNDNEST3` | water-boundary omission is an error source; land absorbs energy; curve/order/corners/location rules govern H | Native SWAN prototype / Sol audit |
| Local WW3 v6.07 manual | active-boundary status, output-boundary lines, Type-2 point output, and transfer output govern O/D | Native WW3 prototype / Sol audit |
| Provider Manual §14.18 | its partially-land paragraph still calls the ADR-109 amendment “Proposed” and describes the former fine-DEM depth override/unbuilt-hook history; that stale account conflicts with accepted ADR/source and cannot select A1 behavior | Sol audit; later documentation owner |

### 2.3 Gate ownership

| Evidence subject | Required owner now | Not an A0/A1 completion claim |
| --- | --- | --- |
| Manual/source/interface inventory | Sol troubleshooter, read-only | Policy selection |
| Fixture and method lock | This brief | Prototype result |
| Non-production native-binary experiment | Terra worker in WSL/local scratch | Production readiness |
| Adversarial interpretation | Independent Sol auditor | Operator decision |
| O/H/D/G/I/B selection | Operator, six separate choices | A1 implementation authorization |
| 73-record full/fast/horizon identity | R2 | A0/A1 gate |
| Unified health propagation | R8/R8b/R8c | A0/A1 gate |
| Automatic cold recovery | R11 | A0/A1 gate |
| Global multi-anchor operational/reality close | R12 | A0/A1 gate |

## 3. Shared fixture catalog and relational expectations

Every fixture records: study-area geometry; grid orientation; L2 perimeter coordinates; raw bathymetry/fraction-mask provenance; expected cell/segment wetness classification; expected ray classifications when applicable; and a hand-drawn ordered perimeter diagram. Fixtures must use production-shaped persisted geometry, not a convenient side-list substitute.

| ID | Fixture | Locked relational expectation | Required negative/control mutation |
| --- | --- | --- | --- |
| F-R90 | Four otherwise identical west/east/north/south-facing open coasts | Rotating coordinates by 90° rotates O status/source mapping and H curve by 90°; no cardinal side is privileged | fixed S/W; two-nearest-side rule |
| F-MB | Myrtle-Beach-shaped coast with three wet perimeter sides and partial land on one edge | Wetness is per cell/segment; partial land cannot discard the wet remainder; O and H may differ only by their declared contracts | whole-side land exclusion; S/W-only placement |
| F-IHC | Island, headland/peninsula, and cove | Fan classifications and bathymetry each retain their own role; a land-interrupted/open-water feature is not reduced to a local surf-point label | surf-point/buoy-ID dependent setup; ray-as-energy formula |
| F-DS | Disconnected wet perimeter segments | Each wet segment is enumerated; H must either prove one legal continuous curve or refuse for an operator decision; no hidden jump joins segments | point permutation; implied last-to-first connection |
| F-GL | Real source-backed Great Lakes configuration/setup case | The real configured source reaches derivation with declared source, horizontal/vertical datum, resolution, coverage and longitude convention; synthetic rotation is not a substitute | SoCal CRM invocation as if global |
| F-WRAP | Longitude-wrap and high-latitude case, if current supported geography/bathymetry interfaces claim support | Normalization and ordering preserve the same geometric relation across the wrap/high-latitude representation | longitude-sign/wrap mutation |

If F-WRAP cannot be instantiated from existing supported interfaces, the worker records `REFUSE: supported-range unclear` and the operator packet asks whether support is in scope. It must not invent a polar or longitude criterion.

The hand-derived expectation for every fixture is relational: the expected set of wet perimeter cells/segments, containment of required corners, continuity/non-continuity facts, and its coordinate rotation mapping. This gate intentionally sets no candidate-favoring height, energy, fetch, exposure, or new reachability threshold.

## 4. O axis — NOAA to G1 active cells and source mapping

### 4.1 Candidates and negative control

The prototype compares, independently of H:

- **O1:** every wet G1 perimeter cell is active and supplied through the supported NOAA/WW3 boundary mechanism.
- **O2:** geography/ray-derived wet active segments, with an explicit evidence entry for every omitted wet perimeter cell.
- **O3:** legacy fixed-S/W / two-sides-nearest-one-mean-bearing behavior, retained only as a negative control.

### 4.2 Invariants and evidence

For each O candidate/fixture pair, inventory rather than assume:

1. the status-map code for every G1 perimeter cell;
2. the selected active-cell identity/order and its source spectrum identity, native coordinate and valid time;
3. the source-file coverage and interpolation behavior the selected WW3 mechanism actually performs;
4. whether every status-2 cell has an applicable source and whether any supplied source has no selected status-2 target;
5. whether a land cell remains inactive even if H later covers land; and
6. the actual WW3 grid/preprocessor and model log evidence for accepted input boundary points, source processing and warnings.

Required mutations: fixed S/W, two-nearest sides, one-side-wide land exclusion, missing source for an active cell, active-cell/source identity mismatch, swapped source coordinates, changed valid-time header, and rotated fixture with unrotated mapping. Each mutation is expected to produce the predeclared refusal/evidence form in §12; a mutation that survives is a gate finding.

O is not passed by a parsed deck alone. Native WW3 evidence must identify the actual active-boundary/input processing result and any interpolation/source warning class. The source/manual inventory must state whether selected point order is preserved or irrelevant for each native WW3 operation; A0 must not extrapolate an ordering rule from one operation to another.

## 5. H axis — G1 to L2 SWAN transfer curve

### 5.1 Candidates and manual constraints

- **H1:** one ordered complete rectangular `CLOSED` curve, including land-covered portions where the SWAN manual permits them.
- **H2:** one installation-derived continuous `OPEN` curve, with documented omission evidence for every wet L2 boundary segment.
- **H3:** topology-dependent selection only if actual SWAN 41.51AB experiments produce an unambiguous rule for partial land and disconnected wet segments.

For every H candidate, verify from real output and local SWAN 41.51AB execution that:

1. every required L2 corner is represented as an actual WW3 computational/output location;
2. each WW3 point lies at the intended location along the L2 nest boundary;
3. serialized order is a single clockwise or counter-clockwise traversal with no jump, duplicate or silent rejoin;
4. consecutive locations satisfy the documented SWAN acceptance geometry; the method records coordinates and the manual relation, not a newly invented numeric tolerance;
5. the keyword matches actual topology: `CLOSED` only for a closed rectangle and `OPEN` only for an unclosed curve;
6. the transfer contains no buoy, seam, `DREF*`, or other off-boundary diagnostic point; and
7. land coverage, partial-land sides and disconnected wet segments are tested against the actual binary rather than inferred from grammar prose.

The H input record must also lock and exercise `FREE` versus `UNFORMATTED`, the required Cartesian `[xgc] [ygc]` origin, and longitude-before-latitude order. Required mutations: off-boundary diagnostic insertion, point permutation, duplicate, missing required corner, missing segment, discontinuity, wrong keyword, location moved off the boundary, spacing violation, formatted/binary keyword swap, stale origin, swapped origin, omitted origin, and lat/lon-order inversion. The run record includes the exact SWAN command, input, version, output/PRINT warnings, exit state, and the predeclared §12 verdict form. A binary acceptance that fails a structural check is a refusal; structural acceptance alone is not a scientific-quality claim.

### 5.2 Lateral-boundary safety method

For H2/H3, the prototype records the manual §2.6.3 affected-region geometry and tests boundary-location sensitivity with the locked fixture relationships. It does not invent a new attenuation, directional-reachability, or error-distance threshold. If deciding whether an omitted wet segment is safely irrelevant requires such a criterion, record `REFUSE: new scientific reachability criterion` for the operator packet.

## 6. D axis — diagnostic continuity separate from boundary transfer

The prototype compares native WW3 output arrangements that leave the canonical H transfer boundary-only while retaining the fixed actual-coordinate buoy, seam and `DREF*` records in the companion fixture manifest. `WW3-AUTOMATIC-SETUP-A0-FIXTURES-2026-08-30.md` §5 locks their IDs, coordinates, depth tokens, time axis, spectral axes, and canonical per-point printed energy tokens before any output is inspected. It must inspect the existing `model_wave_source` and `vchain` consumers and record their current transfer parsing, filenames, retention, valid-time axis and fingerprints; it must not change them.

For each D candidate, prove or refuse with native files and parsers:

1. actual-coordinate coverage for every buoy, seam and `DREF*` point is retained;
2. valid-time coverage and retention are unchanged unless a later operator ruling says otherwise;
3. metadata/point fingerprints distinguish boundary and diagnostic identities;
4. spectra/energy or byte equivalence is checked where the candidate promises preservation; where a representation legitimately differs, declare the independent comparison method before inspection;
5. the selected existing `model_wave_source` and vchain read paths identify the intended diagnostic source, including trigger-4 consumer-contract evidence; and
6. one native `ww3_outp` pass versus a separate native post-processing pass is compared only as a D mechanism, with all file/contract additions surfaced as trigger-7 decisions.

Required mutations: append a diagnostic point to the H transfer, remove a diagnostic point, move a diagnostic coordinate, alter a valid-time axis/header, cross-wire a consumer to the boundary-only transfer, and change a diagnostic fingerprint without its declared counterpart. Surviving mutations are findings. No custom spectral-transfer rewriter is introduced by A0.

## 7. G axis — global wetness/bathymetry source evidence

The operator has fixed the horizontal occupancy source: existing OSM/Overpass only. Ocean occupancy is `natural=coastline` at mean high water, with directed land-left/water-right geometry. Great Lakes retain their Great Lakes physical regime but use the lake relation layer—not coastline fallback—where the snapshot has `natural=water`, `water=lake`, `type=multipolygon`, and `tidal=no`. Regular installation-selected bathymetry, converted to the model datum, supplies every depth. OSM supplies horizontal water fraction only; there is no fine-DEM depth override.

The OSM gate verifies structural/topology/snapshot/provenance validity, rather than multi-provider fallback accuracy: required tags/layer, complete outer and inner relation rings, island holes, directed coastline geometry, bbox-clipping behavior, coordinate normalization, query/snapshot SHA-256 freezing, and a refusal for missing, malformed or incomplete geometry. There is no GSHHG, secondary occupancy provider, or silent fallback.

Mandatory setup evidence:

- a real source-backed Myrtle Beach configuration/setup case;
- the F-GL real Great Lakes configuration/setup case;
- source/datum/resolution/provenance records for both; and
- explicit refusal where an existing source cannot supply the stated derivation.

The current Southern-California-only CRM path is a negative control for the former design only. It must not be used as an occupancy fallback or a depth override in the fixed policy. Any absence/malformed topology/incomplete OSM snapshot is a setup refusal.

### 7.1 Fine-resolution data causal gate

Fine-resolution bathymetry is not presumed globally required. The fixed-policy causal variants hold grid, NOAA boundary spectra, wind, binary, physics switches, time window, restart state, output points, and O/H/D topology identical:

1. **C0:** center classification with the manifest's fixed synthetic depth field and `FLAGTR=0`.
2. **C1:** OSM-fraction-derived classification with the identical fixed depth field and `FLAGTR=0`.
3. **C2:** identical C1 status and depth grid, with `FLAGTR=2`, `tau = water area fraction`, and obstruction file `1-tau`.

`C1−C0` isolates horizontal occupancy classification. `C2−C1` isolates the operator-confirmed fractional transmission representation. C2 is **not diffraction**, a diffraction surrogate, or an energy-attenuation candidate. Island interiors remain land. Any directional map, diffraction compensation, new fraction threshold, depth override, or new formula is a mutation/research refusal, not a candidate.

The manifest locks the synthetic depth field and occupancy polygons so neither depth nor fixture geometry can move between C0/C1/C2. Required mutations: center classification restored under C1/C2; `tau` written in place of `1-tau`; all partial coefficients set to zero or one while status/depth remain C1-identical; spatially permuted fraction with total area preserved; omitted island hole; clipped/unfinished ring; rotated geometry with unrotated occupancy; and malformed/missing OSM snapshot. Every survivor is a finding.

The causal evidence names the model datum and the regular selected bathymetry input used for all cells; it confirms that no fine DEM supplied a replacement depth. It reports only the locked structural/native evidence. No finer-island result may be described as improving diffraction, island shadow physics, or global accuracy.

## 8. Artifact dependency, compatibility, promotion and rollback experiment

The worker builds a dependency matrix from controlled non-production generation changes. It must enumerate, without pre-deciding outcomes, whether each change requires reuse, regeneration, refusal, cold initialization, invalidation, or a later operator policy for each artifact/state.

| Changed input/identity | `swan_grid_sizing.json` / `ww3_leg` derivation | OSM geometry cache/snapshot | `mod_def.ww3` | WW3 restart | raw horizon | merged transfer | SWAN state/hotstarts | cache selection | marker | Required evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| O outer active-cell/source mapping only | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | controlled generation experiment + native logs/hashes |
| H L2 curve only | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | controlled generation experiment + SWAN input/output evidence |
| D diagnostics only | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | parser/consumer and retention evidence |
| domain or grid identity | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | deck/hash/native initialization evidence |
| G occupancy snapshot or bathymetry datum/source | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | snapshot/source provenance plus compatibility experiment |
| WW3/SWAN binary or model config | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | `[UNSET]` | binary/config hashes and native compatibility evidence |

Each experiment records complete old/new generation identities, artifact hashes, process inputs, observed/expected evidence form, and whether mixed generations remain unavailable. Do not assume that restart deletion is valid. Do not infer that every topology-only change invalidates `mod_def.ww3`, or that it preserves a restart/horizon/SWAN state: each matrix cell needs evidence or stays `[UNSET]` for the operator.

Atomicity drill: interrupt generation creation before each temporary write, hash, promotion, cleanup, and rollback boundary. The method must establish whether an old complete generation is retained and can be restored hash-matched as a set. A partial/mixed generation must be recorded as unavailable; no A0 experiment writes production cache/marker/state.

## 9. Initialization, warm/cold and bootstrap experiments

For every mechanically viable O/H/D/G candidate that changes a WW3-compatible identity, run and document the method for:

- warm continuation from an existing compatible restart;
- cold run with no assumed restart;
- first-install/bootstrap with no verified predecessor; and
- interruption and retry across generation promotion/rollback.

The experiment must not make a restart disappear and call the resulting behavior a valid cold start. It records the native WW3 initialization inputs, precondition identities, restart provenance, emitted warnings/errors, output artifacts, and the §12 verdict. If a valid method cannot be demonstrated under existing approved contracts, record `REFUSE: bootstrap method unproven`; B remains an operator decision. R11 retains automated recovery ownership.

## 10. Resource and native-process accounting

Use the already locked R0 ceilings and baseline inputs as the total ceiling authority. The worker cites the exact R0 gate row/ceiling before launch; A0 adds no number and does not relax any ceiling. In addition, before prototype output is read: the existing Overpass request retains its configured absolute **25 s** timeout; local OSM fraction derivation is **≤30 s**, incremental RSS **≤512 MiB**, swap growth **0**; and any extra native `ww3_outp` pass is **≤10 s**, incremental RSS **≤128 MiB**, swap growth **0**.

For each extra native WW3 post-processing pass, separately record wall time, peak RSS, swap delta, disk growth, input/output byte counts, process command/version, and overlap/concurrency state. Measure additional work separately from the existing leg/horizon process so a D mechanism cannot hide cost in a combined number. Exceeding or lacking an R0 measurement form is a refusal, not a revised limit.

## 11. Operator decision-packet schema

The final A0 report presents exactly six independently selectable packets. No `A/B/C` shorthand may combine an outer boundary, inner curve, diagnostic output, source, rollback, or bootstrap choice.

Each packet contains:

| Field | Required content |
| --- | --- |
| Axis and option identifier | One of O, H, D, G, I, B; one specific candidate or `no viable option` |
| Scope | What contract/behavior it controls and what it explicitly does not control |
| Manual and governing authority | Local manual/ADR/plan citations, including conflict status |
| Fixture/native evidence | Fixture IDs, commands/artifact hashes, native binary/version, verdict form and unresolved cases |
| Assumptions and scientific criteria | Existing authority only; otherwise explicit operator-decision placeholder |
| Contracts/files/artifacts | Existing consumers/artifacts affected; trigger-4/7 and any trigger-2/3/5/6 callout |
| Cost/resource evidence | R0 comparison record and any separately measured native pass |
| Failure/refusal mode | What becomes unavailable and what must not advance |
| Dependency/rollback/bootstrap linkage | I/B evidence relied on; `[UNSET]` cells explicitly retained |
| Recommendation and unknowns | Auditor recommendation, alternatives, and no unstated default |
| Required operator wording | Exact selection/ruling needed before A1 |

## 12. Verdict, pass/fail/refusal evidence form

Every fixture × candidate × axis execution must use this form. These labels describe the method; they are not results claimed by this file.

```text
RUN ID:
Axis / candidate / fixture:
Environment and source revision:
Input derivation and artifact hashes:
Predeclared structural/metamorphic expectation:
Native command, binary version, and relevant manual citation:
Mutation (or none):
Evidence captured: status/source map; coordinate/order listing; native output/PRINT/log class;
  parser/consumer trace; resource record; generation/rollback record as applicable.
PASS criterion: every locked applicable structural, relational, native-warning, and refusal check holds.
FAIL criterion: a locked applicable check does not hold, including a surviving mutation.
REFUSAL criterion: source/coverage/manual/binary/criterion/contract evidence is unavailable or
  requires an unapproved architectural choice.
Verdict: [PASS | FAIL | REFUSAL | NOT RUN]
No-results placeholder: [UNFILLED]
Follow-up owner: [Sol audit | operator | R2 | R8 | R11 | R12 | other named owner]
```

`PASS` is limited to an evidence row satisfying its predeclared check. It is not a production-safety, global-accuracy, A1-readiness, R2 horizon, R8 health, R11 recovery, or R12 reality claim.

## 13. Locked no-results register

| Subject | Result placeholder | Required next evidence |
| --- | --- | --- |
| O1/O2/O3 across F-R90/F-MB/F-IHC/F-DS/F-GL/F-WRAP | `[NOT RUN]` | §4 native WW3 evidence and mutations |
| H1/H2/H3 across applicable fixtures | `[NOT RUN]` | §5 SWAN 41.51AB evidence and mutations |
| D native output arrangements | `[NOT RUN]` | §6 continuity/consumer evidence |
| G source inventory and real Myrtle/Great Lakes setup | `[NOT RUN]` | §7 source/datum/coverage evidence |
| G fine-data causal variants C0/C1/C2/C3 | `[NOT RUN]` | §7.1 mask/depth/transmission/diffraction evidence and mutations |
| I dependency/atomicity/rollback matrix | `[NOT RUN]` | §8 controlled-generation evidence |
| B warm/cold/bootstrap | `[NOT RUN]` | §9 native initialization evidence |
| Resource overhead | `[NOT RUN]` | §10 R0-comparable separate measurements |

## 14. A0 terminal condition

A0 closes only when the locked method has been executed, independently audited, and the operator has explicitly selected or refused all six packets: O, H, D, G, I, and B. A missing provider/source, unsupported wetness coverage, unresolved disconnected-segment grammar, new scientific reachability criterion, new file/config/dependency, or unproven initialization leaves A1 blocked and is surfaced without workaround.

Later work retains its named ownership: R2 for verified 73-record transfer identity, R8 for unified health, R11 for automatic recovery, and R12 for global/reality closeout. This gate does not authorize code, contract, boundary, grid, artifact, or deployment changes.
