# ADR-103: Multi-Station Real Spectral Boundary for the SWAN L1 Domain

**Status:** Accepted (decision + implementation: operator ruling and code landed 2026-07-26; this
ADR document itself is a 2026-08-06 catch-up write-up — see "Amendment 2026-08-06" below for why).
**Date:** 2026-08-06 (document drafted). Decision date: 2026-07-26.
**Supersedes:** None (no prior ADR existed for this boundary; the parametric single-station design
it replaced was never itself the subject of an ADR).
**Related:** ADR-095 (SWAN model corrections), ADR-093 (SWAN nearshore model — the 4-level nest this
boundary feeds at L1), C-99 / C-104 (`docs/archive/MARINE-SEP-CONCERNS.md`).

## Context

SWAN's L1 (outer, ~1 km) grid needs a deep-water spectral boundary condition — the incident swell
arriving from offshore. Two designs existed for this in the marine repo's history:

1. **Round 1 (pre-2026-07-26): a single-station parametric boundary.** `ww3_to_swan_boundary()`
   fetched one NOAA WW3 station's *bulk* (scalar) parameters and synthesized a single JONSWAP peak,
   emitted via `BOUNDSPEC ... CONSTANT FILE` (spatially uniform along the whole side). This
   collapsed WW3's own multi-partition directional spectrum into one train, discarding exactly the
   structure (separate swell trains at separate periods/directions) the surf pipeline downstream
   needs to resolve real multi-swell days.
2. **The operator's 2026-07-26 ruling rejected that design outright**, verbatim: *"YOU CANNOT JUST
   PICK ONE STATION POINT... YOU ARE MANDATED TO USE THE WWIII GRID! YOU ARE TO PROVIDE THE
   DIFFERENT VALUES AT THE BOUNDARY BASED UPON THE WWIII DATA FROM THAT GRID!"* The requirement:
   the boundary must vary spatially along the side, driven by real WW3 spectra, not one averaged
   point.

**A separate, unrelated planning document (an earlier draft of
`docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md`) later proposed a *three-tier* boundary
design** — Tier 1 full spectrum, Tier 2 per-partition parametric superposition as a fallback, Tier
3 single-peak synthesis as a last-resort degraded mode — under this same ADR filename. **That
three-tier design was never implemented and is struck** (see "Amendment 2026-08-06" below); this
document does not describe it. It describes what was actually built in response to the 2026-07-26
ruling, which predates that plan draft by ten days and already satisfies the "use the WW3 grid,
not one point" requirement without any degraded/parametric tier.

## Options considered

| Option | Verdict |
|---|---|
| Single-station parametric boundary (`ww3_to_swan_boundary()`, round 1) | **Rejected by the operator, 2026-07-26** — collapses WW3's own directional spectrum into one averaged train; does not vary along the boundary side. |
| Three-tier design (full spectrum → per-partition parametric fallback → single-peak degraded mode) | **Never built.** Proposed in an early draft of a later, unrelated plan under this ADR's filename; struck by that plan's own 2026-08-06 rewrite once it was found the shipped design (below) already exists and never degrades. No fallback tier of any kind exists in the code. |
| **Multi-station real 2-D spectral boundary, refuse-don't-degrade on insufficient stations** | **Chosen and shipped 2026-07-26.** Selects real NOAA WW3 station spectra against L1's own computed extent, one real 2-D spectrum file per qualifying station, emitted as `BOUNDSPEC SIDE <side> CCW VARIABLE FILE ...` so the boundary varies along each side. Refuses the cycle (`BoundaryNotViableError`) rather than ever falling back to a single point or a synthesized/degraded spectrum. |

## Decision

The SWAN L1 boundary is built from **real, multi-station, spatially varying WW3 spectra**, selected
per cycle against L1's own computed extent, with **no fallback of any kind** — a cycle that cannot
find enough qualifying real stations is refused and retried, never degraded.

### The shipped mechanism

**Real 2-D spectrum writer.** `ww3_spectrum_to_swan_boundary()`
(`weewx_clearskies_marine/services/swan_formats.py:2369-2508`) writes one SWAN Appendix-D-format
2-D spectrum file (`TIME`/`LONLAT`/`AFREQ`/`NDIR`/`QUANT`/`VaDens`) per selected WW3 station, from
that station's own parsed spectrum (`WW3Spectrum`, `services/ww3_spectrum.py`) — no synthesized
shape, no `DSPR` constant anywhere in this path. Converts WW3's nautical "going-to"
radians/m²·Hz⁻¹·rad⁻¹ convention to SWAN's nautical "coming-from" degrees/m²·Hz⁻¹·deg⁻¹, and sorts
the direction axis ascending (SWAN requires a monotonic `NDIR` axis).

**Multi-station command assembly.** `ww3_boundary_files_and_command()`
(`swan_formats.py:2538-2666`) takes an already-selected, already-fetched station set and emits one
`BOUNDSPEC SIDE <side> CCW VARIABLE FILE <len1> '<file1>' 1 <len2> '<file2>' 1 ...` line per
populated side — one real spectrum file per station, positioned along the side by `[len]` (computed
in UTM meters from the side's CCW begin corner to each station's foot-point, `swan_formats.py:2632-
2664`, R5 fix — `[len]` is what actually places each spectrum; a file's own embedded `LONLAT` header
is informational only, per the SWAN User Manual). Called unconditionally for the L1 ("outer") build
every normal nonstationary cycle (`services/swan_runner.py:4768`).

**`VARIABLE PAR` is forbidden; `BOUNDNEST3` is not usable.** `VARIABLE PAR` carries one parametric
bulk-parameter train per point, which would collapse the swell partitions this whole design exists
to preserve — never emitted anywhere in this path. `BOUNDNEST3` (SWAN's command for reading a
parent SWAN run's own boundary-specific nest output) does not apply here because WW3 station `.spec`
points are general model output, not the boundary-specific postprocessor product a `BOUNDNEST3`
parent run would need to generate for this exact domain.

### Station selection

`services/ww3_station_selection.py` selects real NOAA WW3 station spectra against **L1's own
computed extent** (never a hardcoded station or count; module docstring, lines 1-13). Two
independent filters, both computed from live data:

1. **Distance — one native WW3 grid cell, per product.** Ocean `gfswave.global.0p16`: ~18.5 km
   (`_max_distance_km`, `ww3_station_selection.py:378-383`). Great Lakes `glwu.grlc_2p5km`: 2.5 km.
   A station beyond one cell of the boundary line is projecting a spectrum WW3 itself computed for
   different water.
2. **Depth/agreement — `deep water OR tanh(kd) agreement`** (operator ruling C-99, 2026-07-27,
   `docs/archive/MARINE-SEP-CONCERNS.md`), applied to both products. `deep water` is
   `depth_m >= _DEEPWATER_DEPTH_COEFFICIENT * T_max^2` with `_DEEPWATER_DEPTH_COEFFICIENT = 0.78`
   (`ww3_station_selection.py:214`), `T_max` measured by energy content in the station's own live
   spectrum this cycle (`_longest_energetic_period_s`), not the product's fixed lowest-frequency
   bin. `tanh(kd)` saturates to 1 in deep water, so `deep water` is the degenerate case of the same
   dispersion-relation test rather than a separate branch (`ww3_station_selection.py:1219-1238`).
   For a station that fails the strict deep-water test, the **shallow-station direction only** is
   tested against a shortfall tolerance on raw `kd` (not `tanh(kd)`) — a station deeper than the
   boundary is unconditionally benign and accepted outright; a station shallower is tested against
   `_KD_AGREEMENT_SHORTFALL_TOLERANCE = 0.257 / 0.8 ≈ 0.321`
   (`ww3_station_selection.py:353`, `_kd_agrees()` at `:940-976`). **This tolerance is a judgment
   call, not a closed derivation — the module's own comment says so plainly**
   (`ww3_station_selection.py:307-315`): it reuses GLWU's published bulk-`Hs` RMSE (0.257 m in the
   0–0.8 m regime) divided by that regime's 0.8 m upper bound, as an analogy for a
   depth-agreement fraction, carried forward unchanged across three prior metric revisions. **It is
   provisional, awaiting operator sign-off (C-104) — not yet ruled.**

   *Doc-drift note (found while drafting this ADR, not fixed here — reported to the lead
   separately): `docs/ARCHITECTURE.md`'s "SWAN model inputs" paragraph and
   `docs/manuals/PROVIDER-MANUAL.md` §14.3b both name this constant
   `_TANH_KD_AGREEMENT_TOLERANCE` and describe it as a single symmetric `tanh(kd)` absolute-
   difference test. The constant in code at `5ca8fcc` is `_KD_AGREEMENT_SHORTFALL_TOLERANCE`
   (same ≈0.321 value) and the mechanism is a directional raw-`kd` shortfall test, applied only in
   the shallow-station direction (`ww3_station_selection.py:245-315`, the round-5/T8.10f-C-104
   defect-fix comment explains why the symmetric `tanh(kd)` form was wrong). This ADR documents the
   code as it stands; the two manuals' constant name and mechanism description are stale and are
   flagged as a separate finding, not corrected by this commit (out of this ADR-only task's
   allowlist).*

## Consequences

- The L1 boundary varies spatially along each populated side, satisfying the operator's 2026-07-26
  requirement — it is not one averaged point.
- No fallback tier of any kind exists or may be added at this call site (see "Refuse, never
  degrade" below) — a design constraint that binds future changes here, not just this one.
- The station-selection kd-agreement tolerance is explicitly provisional; a future operator ruling
  on C-104 changes `_KD_AGREEMENT_SHORTFALL_TOLERANCE`'s value or derivation, not this ADR's
  decision to refuse-don't-degrade.
- `docs/ARCHITECTURE.md` and `docs/manuals/PROVIDER-MANUAL.md` carry a stale constant name/
  description for the kd-agreement tolerance (see doc-drift note above) — tracked as a finding for
  a future doc-sync pass, not fixed by this ADR.

### Refuse, never degrade

**Fewer than 2 qualifying stations overall, or zero on either offshore side, refuses the cycle —
it never substitutes a synthesized or single-point boundary.** `select_boundary_stations()` raises
`BoundaryNotViableError` (class defined `ww3_station_selection.py:559`) in both cases
(`:1259-1272` for the total-`< 2` check, `:1273-1282` for the zero-per-side check). This is a
confirmed, standing operator ruling (2026-07-26), reconfirmed by the SURF-PHYSICS-REMODEL-PLAN's
D-3 decision item and decision-register item 8 (2026-08-06, "ok approved"): **no fallback tiers of
any kind exist or may be added.**

`providers/nearshore/swan.py`'s call site (`:2704-2850`) propagates the refusal rather than
swallowing it: the SWAN cycle for that run aborts, last-good forecast cache is preserved, and the
marine runner loop's own retry-same-cycle handling (`service.py`'s `_marine_runner_loop`) fires
instead of advancing to the next HRRR cycle — the same posture the code already applies to a plain
WW3 fetch/network failure (C-76, 2026-07-26).

**Two prior fabrication sites in this call chain were deleted in the same 2026-07-26 round, not
just superseded:**

1. `ww3_to_swan_boundary()` — the old single-station parametric synthesis function itself. It does
   not exist in the codebase as of `5ca8fcc`; only historical comments describing its deletion
   remain (`swan_formats.py:2297-2317`).
2. **A hidden hardcoded "calm boundary" fabrication site** — `TPAR 0.5m 8s`, written whenever the
   parametric path above returned empty, one layer below the fetch-failure handling the earlier
   C-76 ruling had already fixed. This was discovered and deleted in the same round that removed
   `ww3_to_swan_boundary()`.

Both were removed by marine commit **`5fe77af`** ("feat(T8.10c round2/T8.10f): real multi-station
spectral L1 boundary, no uniform fallback", 2026-07-26 09:21:12 -0700), preceded by **`a671390`**
("feat(T8.10c/T8.10d): real WW3 spectral boundary writer + CGRID low-freq widen", same day
08:24:23) which landed the real spectrum writer this ADR describes above. No `DSPR` constant
remains anywhere in this path.

### Distinct refusal naming in `/health` (H-1, 2026-08-06)

As of marine commit **`5ca8fcc`** ("feat(h1): handoff-collapse instrumentation + health flag +
distinct boundary-refusal naming"), a D-3 refusal is named distinctly from a generic fetch/network
failure in `/health`, so an operator reading `/health` can tell the two apart. In
`providers/nearshore/swan.py`, the boundary-selection `try` block now has a narrower `except
BoundaryNotViableError` clause **before** the generic `except Exception:` (`:2762-2782`):

- **`BoundaryNotViableError` (a D-3 refusal — too few qualifying stations):**
  `state.record_no_publish("ww3_boundary_refused", f"D-3 refusal — {exc}")` (`:2781`) — logged at
  ERROR (`:2770-2779`), then re-raised.
- **Any other exception (network/parse/fetch failure):**
  `state.record_no_publish("ww3_boundary_failed", "no viable real WW3 spectral boundary station
  selection")` (`:2846-2849`) — unchanged from the prior C-76 posture, logged at ERROR
  (`:2835-2844`), then re-raised.

Both slugs still raise — this is a naming distinction only, not a new outcome. **No fallback
tier is introduced by this naming change**; `ww3_boundary_refused` and `ww3_boundary_failed` are
both refusals, surfaced differently in `GET /health` as `no-publish: <slug> <detail>` so an
operator can distinguish "not enough real stations qualified" from "the fetch itself failed." See
`docs/manuals/PROVIDER-MANUAL.md` §14.3b ("Distinct boundary-refusal naming") and
`docs/manuals/OPERATIONS-MANUAL.md` ("Marine service deployment" health reasons) for the full
`/health` surfacing — not duplicated here.

## Acceptance criteria

- [x] The L1 boundary is built from real WW3 station spectra, not a single averaged point —
      `ww3_spectrum_to_swan_boundary()` writes one real 2-D spectrum file per selected station
      (`swan_formats.py:2369-2508`); confirmed no `DSPR` constant or synthesized shape anywhere in
      this path.
- [x] The boundary varies spatially along each populated side —
      `ww3_boundary_files_and_command()` emits one `BOUNDSPEC SIDE <side> CCW VARIABLE FILE` line
      per side carrying every qualifying station on that side, each at its own `[len]` position
      (`swan_formats.py:2538-2666`).
- [x] `VARIABLE PAR` is never emitted (would collapse partitions) — confirmed by reading
      `ww3_boundary_files_and_command()`'s full body; the only command form it constructs is
      `VARIABLE FILE`.
- [x] `BOUNDNEST3` is not used for this boundary — confirmed no call site in
      `services/swan_formats.py` or `services/swan_runner.py` uses it for the L1 WW3 boundary.
- [x] Station selection is against L1's own computed extent, filtered on distance (one native WW3
      grid cell) and the `deep water OR tanh(kd) agreement` criterion — `ww3_station_selection.py`
      module docstring + `:1219-1282`.
- [x] Fewer than 2 qualifying stations overall, or zero on either offshore side, refuses the cycle
      (`BoundaryNotViableError`) rather than degrading — `ww3_station_selection.py:1259-1282`;
      caller propagates rather than substitutes, `providers/nearshore/swan.py:2704-2850`.
- [x] No fallback tier (parametric, single-peak, or otherwise) exists in this call chain —
      confirmed by reading the full boundary call chain from `_run_all_spots_locked()` through
      `select_boundary_stations()`; every failure path raises, none substitutes.
- [x] A D-3 refusal is distinctly named in `/health`, separate from a generic fetch failure —
      `providers/nearshore/swan.py:2762-2782` (`ww3_boundary_refused`) vs `:2783-2850`
      (`ww3_boundary_failed`), both marine `5ca8fcc`.
- [ ] `_KD_AGREEMENT_SHORTFALL_TOLERANCE`'s value/derivation receives operator sign-off (C-104) —
      open; the criterion functions correctly today with a provisional value.

Checked at: this document's own drafting (2026-08-06), against marine repo commit `5ca8fcc`, by
direct code reading (see file:line citations throughout) — not test output. A future phase-boundary
ADR compliance sweep should re-verify against whatever commit is then current.

## Implementation guidance

This section documents where a future change to this boundary must land, and what it must not
do — it is not an open implementation task.

- **Any future change to the boundary mechanism** touches
  `services/swan_formats.py` (`ww3_spectrum_to_swan_boundary()`, `ww3_boundary_files_and_command()`),
  `services/ww3_station_selection.py` (selection, both filters, `BoundaryNotViableError`), and the
  call site in `providers/nearshore/swan.py` (`:2704-2850`).
- **Do not reintroduce a fallback tier of any kind.** The refuse-don't-degrade posture is a standing
  operator ruling (2026-07-26, reconfirmed 2026-08-06 as plan decision-register item 8) — any
  design that substitutes a synthesized, single-point, or "degraded" spectrum when station
  selection comes up short is the exact design this ADR's decision rejects, and reintroducing one
  is an architectural change requiring explicit operator approval in chat before any code is
  written.
- **`_KD_AGREEMENT_SHORTFALL_TOLERANCE` is provisional (C-104).** A future change to its value or
  derivation is not, by itself, architectural — it is a constant tuning within the existing
  refuse-don't-degrade design — but should be accompanied by the operator sign-off C-104 is
  waiting on, and by updating this ADR plus `docs/ARCHITECTURE.md` and
  `docs/manuals/PROVIDER-MANUAL.md` §14.3b in the same commit (including fixing the stale
  `_TANH_KD_AGREEMENT_TOLERANCE` name noted above).
- **Out of scope for this ADR:** the L3/L4 nesting boundary (`BOUNDNEST1`, internal to SWAN's own
  grid chain, unrelated to WW3) and the handoff from SWAN to the 1-D surf model — both documented
  elsewhere (`docs/ARCHITECTURE.md` "MARINE HANDOFF MODEL", ADR-093).

## References

- Related ADRs: ADR-093 (SWAN nearshore model), ADR-095 (SWAN model corrections), ADR-104 (island-aware L1
  sizing and partition-reconstruction WW3 boundary — supersedes this ADR's mechanism for L1 when Phase B
  lands, see "Amendment 2026-08-08" above)
- Concerns / rulings: C-76, C-94, C-99, C-104 (`docs/archive/MARINE-SEP-CONCERNS.md`)
- `docs/manuals/PROVIDER-MANUAL.md` §14.3a (WW3 station spectral fetch), §14.3b (station
  selection + spatially varying boundary, distinct refusal naming, bulk-fallback health flag)
- `docs/ARCHITECTURE.md` — "SWAN model inputs" paragraph (L1 WW3 boundary block)
- Marine repo commits: `a671390`, `5fe77af` (2026-07-26, the shipped design), `5ca8fcc` (2026-08-06,
  H-1 distinct refusal naming)
- Plan: `docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md` — root-cause #2 strike-note (struck
  2026-08-06), decision D-3, decision-register item 8, this ADR's doc-delta row under task H-1

---

## Amendment 2026-08-06 — this document rewritten from a design that was never shipped

**This ADR did not exist as a file before this date.** An early draft of
`docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md` (commit `083d8b1`, 2026-08-05) listed
`docs/decisions/ADR-103-spectral-boundary.md` as a **NEW** document to be authored for a
**three-tier boundary design** — Tier 1 (full WW3 spectrum), Tier 2 (per-partition parametric
superposition fallback), Tier 3 (single-peak synthesis, flagged degraded) — framed as the fix for a
believed-live defect ("root cause #2": a spectrum-collapsing parametric boundary,
`ww3_to_swan_boundary()`).

That premise was stale at drafting. A 2026-08-06 fact-pin
(`docs/planning/scratch/Y0-FACT-PIN-2026-08-05.md`) found `ww3_to_swan_boundary()` had already been
deleted ten days earlier (2026-07-26, marine `5fe77af`) and replaced by the real multi-station
spectral boundary this document describes — live in production since that date, not a proposed
fix. The plan was rewritten in place the same day (`62008d2`, "ONE PLAN! ONE PLAN ONLY!" — operator
order) to strike the three-tier design and root-cause #2 entirely, replacing them with task H-1
(handoff-collapse instrumentation) and this document's row: "REWRITTEN from the original plan's
version... documents the boundary design that ACTUALLY exists... NOT the struck three-tier design."

So "rewrite" describes the *plan's* intent for this filename, not an edit to a prior committed ADR
file — none existed. This document is the first and only committed version of ADR-103, and it
documents the shipped multi-station design exclusively. The three-tier design is not implemented,
is not planned, and must not be inferred as a future direction from its mention here — it is
recorded only so a reader who finds the phrase "three-tier" in an old plan commit does not conclude
it was ever built.

## Amendment 2026-08-08 — superseded for L1 by ADR-104, pending Phase B

**Status: Accepted.** Operator rulings D1–D13,
`docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` §8 (specifically D3/D4), recorded in
full at **ADR-104** ("Island-aware L1 sizing and partition-reconstruction WW3 boundary"). Pointer only —
decision content is not restated here.

**What changes, and when.** The multi-station real-spectrum boundary this ADR documents — station selection
against L1's own extent, one real 2-D `.spec` file per qualifying station, `BOUNDSPEC SIDE ... VARIABLE FILE`
— is **superseded when Phase B of L1-BOUNDARY-REBUILD-PLAN lands (ruled 2026-08-08; lands with Phase B of
L1-BOUNDARY-REBUILD-PLAN)**, replaced by per-L1-cell 2-D spectra reconstructed from gridded WW3 partition
fields (ocean `gfswave.global.0p16`, Great Lakes `glwu.grlc_2p5km`), spacing = L1's own cell size (1 km).
This ADR's own refuse-don't-degrade posture (never a synthesized single-point or "degraded" boundary) is
preserved by the ADR-104 design, which raises on missing fields/steps/wet-cell coverage rather than
substituting. **The station path documented throughout this ADR is live TODAY and stays live until Phase B
lands** — this note does not itself change any code or behavior. `services/ww3_station_selection.py`,
`services/ww3_station_catalogue.py`, `data/ww3_station_catalogue.json`, and the station-fetch half of
`services/ww3_spectrum.py` are deleted only when Phase B/B4 ships; the Appendix-D 2-D spectrum WRITER this
ADR's "Real 2-D spectrum writer" paragraph describes is extracted and kept, reused by the reconstruction path.
`_KD_AGREEMENT_SHORTFALL_TOLERANCE` (C-104, still provisional as of this note) becomes moot for L1 once Phase
B lands, since station depth/agreement filtering no longer applies to the L1 boundary — it is not otherwise
affected by this amendment.

## Amendment (2026-08-17): reconstruction lineage gains a `ww3_bound` consumer; L1-emission remnant tagged SUPERSEDED-AT-V5 — ADR-109

**Status: Accepted.** Recorded by the DOC-W.5 full-index ADR impact sweep
(`docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md`, Phase DOC-W, task DOC-W.5), following
acceptance of **ADR-109** ("WW3 deep-water leg"). Pointer + scope note only — no decision content in
this ADR is restated or re-opened.

**New consumer (PW4/W2, current — lands with Phase W).** The per-cell parametric-spectrum
reconstruction lineage this ADR started (the "Real 2-D spectrum writer" this document describes,
extracted and kept per the 2026-08-08 amendment above, now the per-cell reconstruction path ADR-104
D3 built on it) gains a WW3-consumable output path: the same per-cell partition-summed spectra feed
`ww3_bound`, the boundary-assembly program ADR-109 D5 picked, via a new emitter (ADR-109 D5/D6, plan
task W2/PW4) so WW3's OWN deep-water leg can assemble its SWAN-facing boundary from the identical
per-cell construction this ADR's writer already produces. The emitter's file format follows
`ww3_bound`'s own transfer format (ADR-109 D5's frequency-fastest ordering, trap 21) — it does not
change the spectral-construction math itself (JONSWAP wind-sea, Gaussian swell shapes, cos²ˢ
directional spreads — untouched by this amendment, per ADR-106's own "R1 changes where, never how"
framing, which this addition follows).

**SUPERSEDED-AT-V5 (tag only — the supersession note itself lands at Phase V5, never before).** This
ADR's own **L1-emission remnant** — the original per-station, real-2-D-spectrum
`BOUNDSPEC SIDE ... VARIABLE FILE` emission mechanism this document's "Multi-station command
assembly" section describes, already noted superseded-for-L1 by ADR-104's D3 mechanism per the
2026-08-08 amendment above — is tagged **SUPERSEDED-AT-V5**. It dies fully (its emission code path
is retired, not merely unused) only if and when Phase V5 rules retirement of the live SWAN-L1
serving path; until then this tag records the disposition, nothing more. This is consistent with
ADR-109 D15: the live SWAN-L1 path is not superseded by ADR-109, so nothing here is superseded NOW —
only tagged for what happens if/when V5 rules retirement.
