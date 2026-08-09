# ROUND BRIEF — Phase G: island-aware L1 autosizing (L1-BOUNDARY-REBUILD-PLAN)

**Round identity:** Phase G tasks G1–G6 (G7 is lead-owned verification, no code; G8 is
test-author's — a separate brief). Lead: coordinator. You: clearskies-api-dev (Sonnet).
Auditor: `clearskies-auditor` at Gate G (blind — you will not brief it).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).
Dispatched only after W6 closes (marine repo runs one round at a time).

**Authorization:** G1–G6 ARE architectural (L1 extent/boundary + a new config key) and are
PRE-APPROVED by the operator via the plan's Pre-approval register **P1, P2, P3** (rulings
D1/D2/D11). The named constants are FIXED by the plan (§"Named constants", plan :97-101) —
`L1_MAX_EXTENT_KM = 100.0`, enclosure margin `10.0` km, `SIGMA_THETA_REF = 15°`, `K_FILL = 1`.
Do not re-derive them; anything beyond P1–P3's text → STOP and surface.

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — §PHASE G in full (tasks
   G1–G8, G-Accept, Gate G rows: your spec, verbatim; do NOT work from this brief's
   one-line labels) and the §PRE-APPROVAL REGISTER rows P1–P3 + the named-constants block.
2. `docs/ARCHITECTURE.md` — the "L1-BOUNDARY-REBUILD-PLAN target state" block (first
   bullet, L1 offshore extent) and the ⚙ GEOMETRY MODEL block (context for what the fan
   and wrap-candidate machinery you are extending already does).
3. `weewx_clearskies_marine/services/geography.py` — module header, `RayResult` (:135),
   `resolve_regime_horizon_km` (:170-192), `_classify_ray` (:294-351), the ray-march
   caller around :487.
4. `weewx_clearskies_marine/services/swan_domain.py` — `_compute_level1` in full,
   especially the shelf-distance sizing (:1120-1132) and the G2.5 wrap-enclosure block
   (:1168-1192).
5. `weewx_clearskies_marine/services/grid_sizing_chain.py` — `run_grid_sizing_chain`
   (:2517-) and the stage-1/stage-2 flow (:988-, :1233-) to find the correct config-push
   insertion points for G5 plumbing and the G6 zone-span check;
   `_locked_utm_zone_for_deployment` (:819-895) for the locked zone G6 validates against.
6. `weewx_clearskies_marine/config/marine_config.py` — `SwanConfig` (:202-320): the
   parse/validate pattern G5's new key must follow.
7. `rules/verification.md` — KAT falsifiability (test-author owns the KATs, but your
   commits must leave the seams they need: pure, importable helpers).

## PRE-ROUND VERIFICATION (lead, 2026-08-09, marine HEAD `5cc28e8`)
- geography.py + swan_domain.py UNCHANGED since the plan's line cites were verified
  (git diff a399eb6..5cc28e8 touches neither). One drift: `_classify_ray` is at :294,
  not the plan's :296.
- grid_sizing_chain.py and marine_config.py HAVE changed since the plan was written
  (B-phase commits). G5/G6 designs are line-independent; anchor points re-verified at
  `5cc28e8` as cited above.
- F1 geometry signature (`_domain_geometry_signature`, grid_sizing_chain.py:309-331)
  confirmed to include L1 bbox+resolution — the L1 relocation WILL trip cold-start (G7,
  lead verifies live at G-Accept; not your task).
- `RayResult` is a dataclass; verify at scope-ack that no positional construction exists
  before appending the G2 field (plan G2's own caveat).

## SCOPE
**Modify:** `services/geography.py` (G1, G2), `services/swan_domain.py` (G3, G4),
`services/grid_sizing_chain.py` (G5 plumbing, G6), `config/marine_config.py` (G5 key).
**Create:** nothing else. NO test files (test-author owns G8 — `tests/test_island_autosizing.py`).
**Do NOT touch:** any provider, `swan_formats.py`, `swan_runner.py`,
`boundary_reconstruction.py`, `ww3_partition_fields.py`, any endpoint, any frozen-core
file, existing tests. No dependencies. The ONLY new config key is `[swan]
l1_offshore_extent_km` (P3) — no others.

## DESIGN (decided — plan §PHASE G, tasks G1–G6, verbatim; read there)
The plan text is the spec. Constraints the lead re-states as hard edges only:
1. G1: the cap constant lives in `geography.py` ONLY; `swan_domain.py` imports it.
   `find_shelf_distance` still sizes the BASE offshore extent (with its 30 km fallback);
   Great Lakes horizon/sizing unchanged.
2. G2: pure dataclass-field addition (`open_water_resume_km: float | None`), recorded at
   qualification from values the march already has.
3. G3: enclosure point at `resume + 10.0` km along the ray (replaces point-at-full-horizon);
   `resume + 10.0 > cap` ⇒ NO enclosure point for that ray (never partial) → near-lee set.
4. G4: exact arithmetic per plan (chord width W, `L_fill = W/(2·tan 15°)`, clustering gap
   ≤ 10°); applied BEFORE the min/max envelope; best-achievable is SILENT (D11 — no new
   warnings/health flags; sizing trace keeps ordinary numbers only).
5. G5: override replaces the autosized offshore extent (base + enclosures + near-lee),
   clamped to cap; wrap enclosure points suppressed when set; lateral + landward
   unchanged; validation refuses negative/NaN/> cap at config push, naming the cap.
   Admin UI is Phase A — config plumbing only here.
6. G6: L1 bbox longitudes within ±3.5° of the LOCKED zone's central meridian, else loud
   config-push refusal naming the span and the cap.

## VERIFICATION (yours, before closeout)
`.venv-round4\Scripts\python.exe -m pytest tests/test_swan_domain*.py tests/test_geography*.py
tests/services/ -q` — adjust to the actual test files matching your changed modules
(changed-files + affected directory; NEVER the full suite). Name the exact command in your
scope-ack. Expected: 0 new failures vs a pre-change run of the same selection (record both
counts). If an existing test pins pre-G sizing behavior your change breaks → STALE-TEST
BLOCK: stop and report, do not fix code or test on your own authority.

## LEAD CALLS
- `_classify_ray` line drift (:294) — cosmetic, no action.
- G7 (cold-start guard) and all doc-sync (ARCHITECTURE.md, ADR-100 amendment) are the
  LEAD's, not yours. Do not edit meta-repo files.
- Commit granularity: one commit per task (G1..G6) or logical pairs (G1+G2, G3+G4); each
  message names the task ID.
- Keep G4's helper (`_near_lee_max_extents`) pure (rays + base extent in, per-bearing caps
  out) so G8's KATs can hit it without fixtures-through-config.

## OPEN QUESTIONS
None pre-identified. Anything ambiguous between plan text and code reality → SendMessage,
do not pick.

## MANDATORY BLOCKS
Comply verbatim with the three blocks in
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS (git
restrictions; stale-test; architectural). **SCOPE-ACK REQUIRED via SendMessage to "main"
before any code:** deliverables, exclusions, exact verification command, the RayResult
positional-construction check result, and any further line drift. Wait for confirmation.
Tone: concise.
