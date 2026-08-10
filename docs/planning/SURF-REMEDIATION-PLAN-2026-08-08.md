# Surf Remediation Plan — audit-driven fixes (2026-08-08)

**Created:** 2026-08-08, from the same-day live audit of the six WC-D3 handoff issues
(`docs/planning/briefs/WC-D3-ISSUES-HANDOFF.md`) plus the operator's memory finding.
**Status:** ACTIVE — operator approved 2026-08-08 in chat: "1. yes. 2. sorry i meant 150.
3. yes. 4. yes, follow all rules, especially related to agent delegation and adversarial qc."
All DECIDE items RULED: D-R1 approved (Q_b-only cessation); D-R2 = 150 m window for
Huntington (operator's earlier "140" was a typo, corrected in chat) + 30 m landward, preset
ladder 150/300/500; D-R3 approved (move to /var/lib, current-cycle hotstart retention, +15%
wall-clock ceiling); D-R4 REQUIRED (runs parallel, reports before Gate R2's reality row).
Execution order R1 → R4 → R2 → R3 stands. Progress is tracked per-phase below and in the
decision log.
**Structure model:** `docs/planning/MARINE-FORWARD-PLAN.md` (operator-directed: line-level tasks,
per-task agent assignments, per-phase adversarial QC gates, zero regression tolerance).
**Audit evidence:** every claim below was verified live on 2026-08-08 against marine `65a7c73`
(deployed 04:47Z, first full cycle completed 05:26Z), dashboard `43a8ceb`, api `d6d6bc0`.
Commands and raw numbers are in the audit conversation record; the load-bearing ones are
restated inline.

**What the audit established (plain English):**

1. **The surf height range never displays** because the min/max numbers are computed correctly
   and then dropped by the cache writer — proven by prediction: the 04:51Z cycle ran on the
   "fixed" computation and all 73 served hours still carried `modelSurfHeightMin/Max = None`
   while the same payload held real qualifying face heights (0.72–0.75 m). → Phase R1.
2. **The break location is not a bug.** The two endpoints agree to the decimal at matched hours;
   the handoff compared a high-tide hour (+0.909 m, break 4.6 m out) against a low-tide chart
   (−0.315 m, break 93.7 m out). The stored beach profile genuinely contains a wide knee-deep
   terrace (0.8 m deep at 16 m out → 1.5 m at 93 m out, datum LMSL, generated 2026-08-03,
   correctly anchored). Operator ruling 2026-08-08: breaking out there is acceptable IF real —
   **but the wave must then re-form and break again at the beach. It cannot.** → Phase R2.
3. **The wave can never stop breaking.** Cessation requires Q_b < 0.02 **AND** H ≤ Γ·d
   (Γ = 0.40) — but the DDD dissipation relaxes H *toward* Γ·d asymptotically from above and
   cannot cross it on a flat or shallowing bed. Live proof: the served march carries
   hs = 0.0040 m in 0.0100 m of water — pinned at exactly 0.40·d down to 1 cm depth. One break
   at ~94 m, "still breaking" to the sand: no cessation → no reformation → no shorebreak →
   impact zone spans the whole terrace → the zone code (which assumes cessation happens
   mid-profile) emits a backwards reform-trough overlapping the impact zone. → Phase R2.
4. **The chart's x-scale is data-driven** (3 tiers, 100/300/1000 m, picked by outermost break
   distance — `BeachProfileChart.tsx:144-161`, `:315-317`) and cropped 50 m of real transect.
   Operator ruling 2026-08-08 (third time of asking): **fixed scale, always** — fixed seaward
   extent and fixed landward extent. → Phase R3.
5. **~3.9 GB of "files" are actually RAM.** The SWAN working root is hardcoded to
   `/var/run/weewx-clearskies/swan` (`providers/nearshore/swan.py:237`, `:1735`, `:4099`) —
   a tmpfs. Contents measured 2026-08-08: level dirs 887+759+487+297 MB, 24 hotstart files
   totalling 1.2 GB, profile store 331 MB. cgroup accounting charges tmpfs pages to the
   service: systemd recorded **"5.1G memory peak"** against the 6 GB container cap on the
   process stopped at 00:14Z. Operator ruling 2026-08-08: **"We need to fucking STOP THAT."**
   → Phase R4. (librewxr has 435 GB free on real disk; `/var/lib/weewx-clearskies` exists.)

**What was NOT broken (do not "fix" any of this):** breaking face heights (2.9 ft vs Surfline
2–3 ft — matched); endpoint agreement (surf vs profile, same hour, identical); the Round Z
shoreline anchor (verified consistent across tide levels); the 04:51Z cycle itself (162/162
transects, zero bulk-fallback, clean journal).

---

## PRIME DIRECTIVE — carried over verbatim in force from MARINE-FORWARD-PLAN.md

All seven rules of that plan's prime directive bind every task here (frozen core, baseline
before/diff after, one functional change per deploy, reality gate on every deploy, stale-test
stop, Sonnet agent discipline with adversarial audit before lead gate, line numbers are hints).
One explicit note: `surf_1d_analytical.py` is in the frozen core — **Phase R2 names it in its
Files list, which is the only mechanism that unfreezes it, for that phase only.**

**Execution order:** R1 → R4 → R2 → R3. Reasoning: R1 is a two-line restoration of an already
approved feature (deploys solo, immediately). R4 next because memory pressure corrupts every
later gate's evidence (the M-0 lesson: no point polishing physics on a starved host) and
because reclaiming ~3.5 GB is what lets the radar container come back. R2 is the operator's
physics complaint and needs clean cycles to gate. R3 is display-only and gates best when R2's
double break exists to draw. Operator may reorder in chat.

---

## DECIDE — operator rulings needed before the affected phase dispatches

- **D-R1 (gates R2) — how a wave stops breaking.** RECOMMENDED: cessation = Q_b < 0.02 alone;
  **delete the `AND H ≤ Γ·d` term.** Why: the AND-term tests for a state the dissipation math
  approaches but can never reach (audit item 3) — it is dead weight that happens to also make
  cessation impossible exactly where the operator needs it. The Q_b threshold alone is
  well-behaved: once a broken wave decays near the stable height, Q_b falls to ~0.002–0.004,
  far under 0.02, so cessation fires promptly; the 0.05-onset / 0.02-cessation hysteresis
  already prevents flicker. Alternative considered and NOT recommended: keep the AND-term with
  a tolerance (H ≤ Γ·d·1.05) — it fires in today's exact live case but stays coupled to an
  asymptote and will fail again on any profile where H rides slightly above the stable curve.
  This is a criterion change inside the breaking physics (trigger 1): **operator approval of
  this plan is the authorization, recorded here.**
- **D-R2 (gates R3) — the fixed scale windows.** Operator semantics ruled 2026-08-08: the
  chart uses **fixed preset windows** (a ladder of standard widths); each LOCATION is assigned
  one window from the ladder based on where its breaks occur — assigned at spot setup, sticky,
  never re-chosen hour-to-hour. RECOMMENDED ladder: **150 / 300 / 500 m seaward**, landward
  fixed at **30 m** for all. Huntington gets the 150 m window (its modeled profile spans
  145 m, so 150 shows all of it; its breaks never exceed ~94 m).
  **OPEN SUB-QUESTION:** the operator wrote "140/30 is fine" — 140 m would clip the outermost
  5 m of Huntington's modeled profile; 150 m covers it exactly. Confirm 140 literal or 150.
- **D-R3 (gates R4) — where the files go and what is kept.** RECOMMENDED: working root moves
  to `/var/lib/weewx-clearskies/swan` (real disk, 435 GB free); hotstart retention = current
  cycle only (delete each level's older stamps at cycle end); the forecast cache and profile
  store migrate by copy at deploy so no forecast gap occurs. Accept up to +15% cycle
  wall-clock from disk I/O (pre-flight R4.1 measures actual; if worse than +15%, STOP and
  surface before proceeding).
- **D-R4 (REQUIRED — promoted 2026-08-08 after the operator's reality challenge) — is the
  terrace real?** The knee-deep shelf comes from the ingested survey dataset and is
  faithfully processed — but sandbars move, and the survey has an epoch. The entire
  "breaking starts ~300 ft out at low tide" picture rests on this shelf; if the survey lies,
  the breaks land wrong regardless of any breaking formula. Read-only task, runs in parallel
  with R1/R4, and **must report before Gate R2's reality row is judged**: compare the stored
  transect-24/55 profiles against an independent source (NOAA CUDEM tile and/or CDIP MOP
  profile for this reach), report the depth delta over 0–150 m. No code change from this
  plan either way; findings go to the operator.
  **DONE 2026-08-08 — VERDICT: CONSISTENT (the shelf is real morphology).** Strongest
  independent evidence: the Scripps HB06 field experiment (Huntington State Beach, fall
  2006, 42 surveyed transects × 3 surveys; Clark, Feddersen & Guza 2010 JGR): measured
  flat terrace slope 0.006 between ~0.7–2 m depth spanning ~10–75 m offshore, beach face
  0.075, seaward slope 0.03 — the stored profile (terrace slope 0.009 at 0.8–1.5 m over
  16–93 m) is the same feature within survey variability. **Measured surf-zone width at
  HB06 was 88–122 m — bracketing the model's ~90 m low-tide outer-break distance.**
  Transect 55's bar minimum (1.545 m @ 79.7 m) sits inside the documented terrace/bar
  band. NOT verified (on record): the source DEM's identity/epoch for this cell (public
  CUDEM tiles don't cover SoCal; NCEI mosaics returned NoData here), today's exact 2026
  bar position (bars migrate; HB06 is the same season though), and pier-adjacent effects
  (scour/rip at the pilings — HB06 was ~3 km down-coast). Gate-R2 consequence: the
  bathymetry is CLEARED as the prime suspect; if the cam still disagrees post-R2, the
  escalation order effectively starts at shoaling amplification and the Q_B_VISIBLE dial.

**Ruled by operator in chat 2026-08-08 (recorded, not open):** breaking far offshore is
acceptable where the bathymetry supports it, but reformation + second break must follow
(basis of R2). The chart scale must be fixed, not data-driven — third request (basis of R3).
Holding model files on the RAM disk must stop (basis of R4).

---

## PHASE R1 — Serve the computed surf-height range *(the cache save/load bug)*

**Owner:** `clearskies-api-dev` (Sonnet, marine repo). **QC:** `clearskies-auditor` at Gate R1.

**Root cause (verified):** `services/swelltrack_cache.py` — `serialize_pipeline_result_for_cache()`
(`:124-171`) omits `model_surf_height_min_m` / `model_surf_height_max_m`;
`deserialize_pipeline_result_from_cache()` (`:256-332`) never reads them, so the dataclass
defaults (`surf_1d_pipeline.py:539,543` — `None`) are served on every cache hit, which is the
production path for every forecast entry (`endpoints/surf.py:1169`). The three prior "fixes"
(`65a7c73` and predecessors) all rewrote the computation (`surf_1d_pipeline.py:2352-2365`,
`:3457-3458`), which was never wrong at HEAD.

**R1.1 — Codec round-trip.** Add both fields to the serializer dict and the deserializer
constructor call. Deserializer reads via `.get("model_surf_height_min_m")` with `None` default —
a pre-R1 cache entry must load cleanly (same legacy-tolerance pattern as
`shadow_face_height_m`, `:283-287` docstring / `:328-331`).
**R1.2 — Test-gap closure** (`clearskies-test-author`). Name in the closeout WHY WC-K3 missed
this: it exercised `run_pipeline()` directly, never the serialize→deserialize→serve path. New
guard: full round-trip test — construct a `PipelineResult` with min=1.3/max=2.5, serialize,
deserialize, assert both survive; plus a legacy-dict fixture (keys absent) asserting clean
`None`. **The round-trip test MUST FAIL against pre-R1 code** (transcript recorded).
**Files (exhaustive):** `weewx_clearskies_marine/services/swelltrack_cache.py`;
`tests/test_wc_height_range.py` (extend) or `tests/test_swelltrack_cache_roundtrip.py` (new).
**MUST NOT TOUCH:** the min/max computation in `surf_1d_pipeline.py` (correct at HEAD, twice
verified); `endpoints/surf.py` wiring (`:1420-1433`, correct); the M-0d full-resolution profile
store codec (separate codec, profile endpoint does not serve min/max).
**Accept (live):** after ONE post-deploy cycle, `GET /surf/huntington-city-beach-pier` shows
non-null `modelSurfHeightMin/Max` on hours whose `perPartitionBreaks` carry qualifying
(Tp ≥ 5 s) mean face heights, with min/max equal to the smallest/largest of those values —
raw payload excerpt pasted beside the per-partition list. Dashboard range ("X–Y ft") renders
(fallback logic `SurfingTab.tsx:458-461, :1562` already correct — no dashboard change).

## PHASE R1b — Min/max redefined: true extremes of the good surf, pooled across swells (operator-ruled 2026-08-08)

**⚠ R1b-D1 AMENDED 2026-08-09 PM (operator, in chat, verbatim anchors: "It was NEVER supposed
to be every transect — ONLY the TOP transects"; "I don't want the limp-ass bottom of the
barrel, why the fuck would we measure that"; "get the documentation right"):** the min/max
pool is the +0.75σ UPPER TAIL ONLY — the per-transect faces at/above the zone's qualifying
threshold `min(zone_mean + 0.75·zone_σ, 5th-highest)` (the same `eff_threshold` the
BD-7 selection already computes). `modelSurfHeightMin` = min of that TOP set;
`modelSurfHeightMax` = max of that top set. The prior text below (pool = every qualifying
partition's face on qualifying transects) let a marginal-but-qualifying swell drag the min
to "no surf" (live 2026-08-09: served 1.1–4.3 ft) and is SUPERSEDED. Both construction
sites change; API-MANUAL rows fixed same round. Live expectation after the fix: a tight
range near the good-surf faces (e.g. ~3.8–4.3 ft on the 2026-08-09 evening ocean), never
a floor at the smallest swell.

**Operator ruling (in chat, verbatim anchors):** "yes that was wrong... We need to take the
min/max of the range of 'good surf' regardless of the swell.... which means capturing the
true min/max... not the means of the top percentage of each swell." Root defect: the WC-D3
implementation defined min/max over PER-SWELL aggregates (each qualifying partition's
mean-across-transects face, `_summarize()` at `surf_1d_pipeline.py:1246-1252`) — a
swell-vs-swell comparison (live: 0.725 vs 0.756 m, a meaningless 3 cm "range"), which is
also exactly why Gate R1's F1 headline drop appeared (max-of-means < the validated
headline). This phase supersedes the F1 SHIP/DECOUPLE fork.

**R1b-D1 (the definition, operator-ruled concept, coordinator design):** the min/max pool =
every per-transect, per-partition breaking face height (`PartitionBreakResult.face_height_m`
where the partition result exists and has break points) for qualifying partitions
(Tp ≥ `_MIN_SURFABLE_PERIOD_S`), over the transects the site already classifies as the good
surf (the BD-9 main-break-zone qualifying transects, `zone["qualifying_indices"]`).
`modelSurfHeightMin` = true min of the pool; `modelSurfHeightMax` = true max; `breakingFaceHeight`
= that max (wiring unchanged). Fallback chain: qualifying-zone pool empty → pool over ALL
transects with qualifying-partition breaks; still empty → both None (flat). Both
construction sites change (per-transect path ~`:2352-2365`; shared/fallback path
~`:3415-3423` — agent re-pins at HEAD). The per-swell aggregates (`per_partition_breaks`
mean/peak) are NOT touched — they remain the per-swell display data; only the min/max
SOURCE changes.

**Expected live numbers (from the 2026-08-08 01:37Z cycle):** min ≈ 0.70–0.76 m, max ≈
0.90–0.96 m (bounded above by bestPeak 0.96); headline within ~5% of the pre-deploy
BD-7 value it currently serves — the F1 double-digit drop must NOT occur (gate row).

**Tasks:** R1b.1 (api-dev, Sonnet): implement at both sites. CORRECTED at scope-ack
2026-08-08: `test_wc_height_range.py` pins wiring/shape only — NO assertions on the min/max
computation exist at HEAD, so the file is untouched and the "update expectations" premise
is struck. Consequence: NEITHER semantics had a computation guard — R1b.3 added.
R1b.3 (test-author, Sonnet, before deploy): a pooled-semantics guard test — multi-transect,
multi-partition fixture where per-swell means give a DIFFERENT min/max than the true pooled
extremes (e.g. two swells whose per-transect faces interleave), asserting the pooled answer;
plus the empty-qualifying-zone fallback and the all-null flat case. Must FAIL against the
pre-R1b computation (transcript recorded — falsifiability requirement).
R1b.2 (auditor): delta re-audit — attack the pool construction
(partition-index alignment between `per_partition` and that transect's own partitions list;
transects with partial partition coverage; the fallback chain; headline delta vs live).
**R1b.2 DONE 2026-08-08 — NO BLOCKER.** Alignment traced line-by-line at both sites
(None-padding preserves indices; bounds guards are dead-but-harmless defense); face
provenance clean (no 0.0/None can enter the pool); fallback branch reachable only on
genuinely flat hours where None/None is correct; codec/wiring diff-confirmed unchanged.
Projected headline delta 0.7–3.2% on live data (vs 9–25% under the struck per-swell-means
definition). Two MINOR findings, lead-ACCEPTED as binding live-gate obligations:
(aud-F1) the ≤5% headline row is proven only for well-separated swells — on a compound-sea
hour (partitions within 3 s / 45° / >50% energy ratio, the `_combine_partition_faces_11_3`
RSS path) `bestPeak`/`mainZone` can exceed any single-partition pool face; the gate row
must be re-measured at the first compound-sea hour and the operator told to watch for it.
(aud-F2) pool-min plausibility is unmeasurable pre-deploy (no endpoint serves full
per-transect-per-partition faces) — the post-deploy per-transect cross-check is
load-bearing evidence, pasted, not a checkbox. R1b.3 guard test landed `6aee246`
(fail-pre-change transcript: old code 0.8428 vs demanded true-pool-min 0.5870).
**Deploy:** R1 + R1b ship as ONE deploy (one functional change: the range feature, correctly
defined — the codec fix alone was never operator-visible behavior).
**Accept (live, all pasted):** min < max on multi-swell hours; min/max equal the true
extremes of the served qualifying-zone faces (cross-checked against the profile endpoint's
per-transect data at the same timestep); `breakingFaceHeight` delta vs pre-deploy matched
hour ≤ ~5%; dashboard renders the range.

### ✅ GATE R1+R1b — PASSED 2026-08-08 07:35Z (live accept on the 06:52Z cycle, all raw output in session record)

Deploy: push `65a7c73..6aee246`, `deploy-marine.sh` (running commit 6aee246, proc start
06:48:19Z, health 200). Targeted pytest on librewxr: **8 passed, 0 failed** (round-trip +
pooled-extremes guards, both with recorded fail-pre-change transcripts). Live accept
(cycle 06:52:15Z, completed 07:28:22Z, convergence 99.7%/100% valid, cold start after
restart — normal):
- **73/73 hours serve non-null min/max**; `min ≤ max` and `breakingFaceHeight == max` hold
  on every entry (violations: NONE).
- **Headline delta at matched hours: +1.2% to +1.6%** (00Z 0.918→0.933, 01Z 0.946→0.959,
  02Z 0.935→0.946) — inside the ≤5% row, direction UP (pool max = bestPeak this cycle).
- **Per-transect cross-check (aud-F2, load-bearing): PASS** — profile transect 23 faces
  0.924/0.884 m both within served [0.855, 0.936] at 07:00Z.
- **Dashboard API serves converted range** (weewx: 00Z "min=2.50 max=3.06 ft").
- Current-hours display ≈ **2.5–3.1 ft** vs Surfline 2–3 ft.
Standing obligations carried forward (not gate failures): compound-sea-hour headline
re-measurement (aud-F1) when one occurs; flat-hour zero-qualifying live example (R1 F2).

**NEW DECIDE — D-R5 (trace-swell floor for the range MIN; operator ruling needed):** the
2026-08-10T00Z hour serves min=0.21 / max=1.43 m (**"0.7–4.7 ft"**) because a tiny 22 s
forerunner swell (mean face 0.18 m) pools alongside the real 14.8 s swell (faces
1.17–1.43 m). True extremes, exactly as ruled — but a trace swell arguably isn't "good
surf," and the displayed range reads absurdly wide (the operator's own "2–5 feet?" worry).
Options: (a) leave as-is (honest true min); (b) RECOMMENDED — pool a partition's faces
only if its peak face ≥ 25% of the overall pool max (design constant, trace-swell floor:
2026-08-10T00Z would then serve ≈ "3.3–4.7 ft"); (c) min restricted to the dominant
partition only. No change ships without the ruling.

### ⛔ QC GATE R1 — `clearskies-auditor` (adversarial), then lead gate *(superseded record below)*
**Gate status 2026-08-08: audit COMPLETE — 1 BLOCKER (F1), 1 MINOR (F2); deploy HELD for
operator ruling.** R1.2 CLOSED (fail-pre-change transcript on record). R1.1 CLOSED at commit
`b503b4a` (lead-verified diff: allowlist exact; remote smoke `roundtrip: 1.3 2.5` /
`legacy: None None`). Audit verdict: the min/max claim could NOT be disproven (legacy
entries, both construction sites, no bypass path, unit conversion, M-0d isolation all ruled
out, methods named). **F1 [BLOCKER, lead-ACCEPTED]:** deploying R1 activates the dormant
WC-D3 redefinition at `endpoints/surf.py:1425-1433` — `breakingFaceHeight` switches from
the BD-7 fallback (currently matching Surfline) to `model_surf_height_max_m`, dropping
9–25% (median ~14%) on 73/73 live hours (auditor's per-hour table on record). Not a code
defect — a plan gap: R1's accept criteria never gated the coupled headline. Surfaced to
operator with options SHIP-AS-DESIGNED (the approved WC-D3 semantic; new value sits inside
Surfline's 2–3 ft envelope; recommended) vs DECOUPLE (pin headline to BD-7 until the R2
webcam gate). AWAITING RULING — nothing deploys until it lands. **F2 [MINOR, lead-accepted
as tracked coverage gap]:** zero-qualifying-hour path verified by inspection only (no
flat-calm hour existed in the live forecast to observe end-to-end); covered by WC-K3's
null-case fixture; post-deploy live confirmation added to the R1 accept evidence when a
flat hour next occurs.
Adversarial brief: "Prove a served entry can still carry None min/max while its own
perPartitionBreaks hold qualifying faces — try legacy cache entries, the fallback pipeline
path (`run_pipeline()` `:3457`), zero-qualifying hours, and the unit-conversion layer
(`marine_response_conversion.py:194-195` collision with the NWS `surfHeightMin`)." Standard
rows: scope walkthrough, KAT fail-pre-change transcript, doc-sync (API-MANUAL §17 note that
the fields are now live), deploy discipline, live accept pasted.

---

## PHASE R4 — Evict the model's file tree from RAM *(operator-ruled)*

**Owner:** `clearskies-api-dev` (Sonnet, marine repo) + lead for the deploy/unit steps.
**QC:** `clearskies-auditor` at Gate R4. **Pre-approved architectural scope (trigger 5/7):**
computation files move host location `/run` → `/var/lib`; one new config key; systemd unit
edit. Nothing else.

**Provenance (established from git history 2026-08-08, operator question "who decided this"):**
the RAM location was never a designed or approved decision. Commit `b3348b6` (API repo,
2026-07-17, "debug(T7.5): fixed-path SWAN workdir + validation logging", a debugging change
authored in an Opus session) replaced `tempfile.mkdtemp()` with the fixed path
`/var/run/weewx-clearskies/swan` for one reason: the systemd unit's `PrivateTmp=yes` hid the
temp files from SSH inspection, and a fixed path made SWAN's files visible for debugging.
The commit message never mentions tmpfs/RAM; the side effect (Ubuntu's `/tmp` is real disk,
`/var/run` is RAM) went unnoticed. The path was then ported wholesale into the marine service
on 2026-07-25 (`f2494bb` T5.6, `006c6a7` T5.9), and everything that grew afterward — 4-level
nest working dirs, per-hour hotstarts, the forecast cache, M-0d's profile store — landed under
it. Both memory-trimming campaigns (M-0/M0b, MEM-3) hunted process RSS and never audited the
storage backing of the file tree. That is the process failure to not repeat: **any fixed path
choice names its filesystem type in the commit message.**

**R4.1 STATUS: DONE 2026-08-08 (read-only agent, full report in session record). Headlines:**
(a) **Throughput PASSES with ~100× margin** — measured 1.3 GB/s direct write to the real
disk; a full cycle writes ≈3.9 GB → ≈3 s added against the 2100 s baseline (0.14%; ceiling
was 15%). (b) **Path inventory is larger than the plan's three anchors:** 7 code sites
(swan.py:237/:1735/:4099, surfbeat_runner.py:79, profile_store.py:78,
wind_timeline_store.py:73, grid_sizing_chain.py:242), 4 test files patching the literal
string, the unit file in 4 locations (live unit, repo packaging, deploy-marine.sh heredoc,
INSTALL/CONFIG docs), plus manual references. (c) **The API's loop socket also lives at
/var/run/weewx-clearskies (settings.py:1501) — R4 moves ONLY the swan/ subtree; the parent
/var/run path and its ReadWritePaths line STAY.** (d) **R4.4's premise was WRONG — retention
already exists:** `_save_hotstart` (swan_runner.py:5488-5490) deletes the previous cycle's
full per-level set before writing the new one, and the hourly quick-update path consumes the
ENTIRE 24-file set (swan_runner.py:4414-4417) — all 1.2 GB of stamps are live working state,
not hoard. R4.4 is DOWNGRADED to a verification row (post-move: file count at cycle end
equals one cycle's set — already the code's behavior). The coordinator's earlier "delete
each level's older stamps" instruction is withdrawn — it would have broken quick updates.
(e) **One bootstrap blocker, lead-RULED:** /var/lib/weewx-clearskies exists root-owned (with
14 GB of root content), the service runs as ubuntu, and chown is banned. Ruling: one-time
standup step `sudo install -d -o ubuntu -g ubuntu -m 0750 /var/lib/weewx-clearskies/swan`
(creates ONLY the new subdir — §11 set-once pattern, no ownership change to anything
existing; run by the coordinator at deploy) + `ReadWritePaths=/var/lib/weewx-clearskies/swan`
(tight scope) added in all four unit-file locations. StateDirectory= rejected — it would
manage ownership of the whole parent, which holds root-owned content. (f) reestablish_spot
needs no edits (imports the constant). (g) No tmpfs-semantics reliance in code; moving to
disk also FIXES a latent fragility (no tmpfiles.d entry today — a reboot silently erases
hotstarts/cache). (h) No ENOSPC handling — acceptable at 439 GB free, noted.

### ✅ GATE R4 — PASSED 2026-08-08 08:30Z (first full on-disk cycle verified; raw output in session record)
Accept rows: (1) cycle 07:52:12→08:24:09Z = **31 m 57 s vs 35 min baseline — FASTER on disk**
(warm start; ceiling was +15%); (2) post-deploy writes to the old tmpfs tree: **0 files**
(the two stray files at exactly 07:47:39.6 were the dying pre-deploy process, verified by
mtime); (3) published normally (lastRunTime 07:52:12Z, 67 entries — no gap at any point);
(4) hotstart replacement on the new root: exactly one cycle's set (24 files); (5) old tree
DELETED post-verification → **tmpfs 3.9 GB → 28 MB; host available memory 1–1.5 GB → 3.9 GB;
shared pages 3 MB**. Radar container can return — operator's call on timing. Residual noted:
`/run/weewx-clearskies/swan-precleanup-20260726T083936Z` (28 MB, Round Z teardown scope).
**Gate event on record:** invariant `11:roller_closure` fired during this cycle's precompute
(comparison_starved=True, Sunday big-swell valid-times, PRE-R2 physics). **CLASSIFIED
PRE-EXISTING, not caused by today's deploys** — journal counts: 2026-08-05: 0; 08-06: 7,162
(Round X roller/closure deploy day); 08-07: 207,499; 08-08 so far: 106,451. Always the
comparison_starved variant (zero-included-step zone fragments), consistent with the Round X
transition-step exclusion rules meeting degenerate single-step zones. TWO tracked
consequences: (a) the R2 gate adds a pre/post firing-rate row — real cessation changes zone
structure, so the rate must be re-measured and explained, not assumed improved; (b) ~200k
ERROR-level lines/day is a log-noise defect in its own right (drowns real errors) —
surfaced to operator; any fix (rate-limit, severity, or root-cause) is a separate ruled
task, not slipped into R2.

**R4.2/R4.3 STATUS: BUILT + DEPLOYED 2026-08-08 07:47:39Z (commit marine `1d012f6` + meta
`245e47b`); FINAL ACCEPT ROWS PENDING first full on-disk cycle.** One canonical
`SWAN_WORK_ROOT` (new `services/swan_paths.py`, env-overridable) replaced EIGHT hardcoded
sites — the fact-pin's seven plus `swan_runner.py:3110` (a live default inside
`run_3level()`, found at scope-ack, pre-authorized by this section's own "IF R4.1 finds
root references there" clause; leaving it would have split the roots). Four tests patch
the constant instead of a literal; two additional literal-referencing test files verified
unaffected (attribute-based patching / historical docstring). Unit + deploy-script heredoc
gained scoped `ReadWritePaths=/var/lib/weewx-clearskies/swan`; `/var/run` line retained for
the API loop socket. Deploy evidence: bootstrap `install -d` ran; migration copied
forecast cache/timeline/incoming/profile_store/hotstarts (one-time, idempotent, copy-not-
move); service restored the cache FROM THE NEW ROOT (journal 07:47:43) and served the
06:52Z run with zero gap; health 200; targeted pytest on librewxr **23 passed, 0 failed**.
Old tmpfs tree left in place pending first verified on-disk cycle (then lead-deleted).
Remaining accept rows (next full cycle): cycle writes land on /var/lib; memory peak < 2 GB;
wall-clock within +15% (projected +0.14%); hotstart replacement on new root; then tmpfs
tree deletion and the free-memory delta measurement.

**R4.1 — Fact-pin (read-only, dispatch-blocking).** (a) Enumerate EVERY reference to
`/var/run/weewx-clearskies` and `/run/weewx-clearskies` across the marine repo, the systemd
unit (`ReadWritePaths=/var/run/weewx-clearskies` confirmed present), deploy scripts, and
OPERATIONS-MANUAL — known code anchors `providers/nearshore/swan.py:237, :1735, :4099`, plus
`forecast_cache.json`, `incoming.json`, `wind_timeline.json`, `profile_store/`, hotstart and
`level*` dirs (all confirmed live under the tmpfs root). (b) Pin the hotstart lifecycle: who
writes the per-hour stamps (6 stamps × 4 levels = 1.2 GB measured), who consumes them, what
cleans them — today's retention is unbounded within a day. (c) Measure disk write throughput
at `/var/lib` (a full cycle writes roughly 2–4 GB) and report projected cycle-time delta
against the D-R3 +15% ceiling.
**R4.2 — Root relocation.** Single module-level root (or `[swan] work_root` config key,
default `/var/lib/weewx-clearskies/swan`) replacing the three hardcoded `Path` literals; unit
gains `ReadWritePaths=/var/lib/weewx-clearskies` (or converts to `StateDirectory=`); directory
ownership established once at deploy per OPERATIONS-MANUAL §11 — **no chown in service code.**
**R4.3 — Migration without a gap.** Deploy step copies `forecast_cache.json` and
`profile_store/*.db` from the tmpfs root to the new root before restart; old tmpfs tree
removed after the first successful post-move cycle. The forecast on the site never blanks
(D-1a lesson: moving the cache aside cost a forecast gap — copying, not moving, avoids it).
**R4.4 — Hotstart retention.** At cycle end, delete each level's hotstart stamps older than
the newest cycle's set (design constant, reviewed at Gate R4 — not admin config). Measured
today: 24 files / 1.2 GB where ~4 are live.
**Files (exhaustive):** `providers/nearshore/swan.py` (path constants only),
`services/swan_runner.py` IF R4.1 finds root references there (name them in scope-ack),
config plumbing for the new key, the systemd unit file (lead applies on librewxr per deploy
discipline), `scripts/deploy-marine.sh` (migration step), `tests/` (retention unit test with
`tmp_path` — no literal `/var/lib` paths in tests, per the 2026-07-25 Windows/Linux lesson).
**MUST NOT TOUCH:** SWAN input grammar, physics blocks, cycle cadence, the convergence gate,
publish/cache decision logic, `reestablish_spot` semantics (its teardown list gains the new
root's spot artifacts — that is a LIST update, not a semantics change).
**Accept (live, all pasted raw):** (1) `/run/weewx-clearskies` absent or < 10 MB;
(2) `free -h` shared/tmpfs figure drops by ≥ 3 GB vs the 2026-08-08 baseline (3.5 GB shared);
(3) systemd `memory peak` for a full cycle < 2 GB (was 5.1 GB); (4) cycle wall-clock within
+15% of the tmpfs baseline (04:51→05:26Z = 35 min baseline); (5) `lastRunTime` continuity
across the migration deploy (no gap); (6) hotstart file count at cycle end = one cycle's set.

### ⛔ QC GATE R4 — `clearskies-auditor` (adversarial), then lead gate
Adversarial brief: "Prove something still writes to `/run/weewx-clearskies` after the move
(grep the live process's open files mid-cycle, `ls` the tmpfs after two cycles). Prove the
migration loses the served forecast (hit `/surf` during the deploy window). Prove hotstart
retention deletes a stamp the NEXT cycle still needs (force a warm start after cleanup).
Prove the service writes to a root-owned dir and silently falls back." Standard rows as R1,
plus the D-R3 wall-clock ceiling row and a post-deploy journal sweep (pre/post ERROR/WARNING
class counts — the HRRR-404 noise class is pre-existing, do not count it as new).

---

## PHASE R2 — A wave that stops breaking, re-forms, and breaks again *(the double break)*

**✅ R2 CODE FOUND ALREADY LIVE — status marker corrected 2026-08-09 PM (session 6).** The
priority-reset round's dev agent found, and the lead independently verified, that R2's
cessation change is already implemented and deployed: commits `fdf7afc` ("R2 — cessation on
breaking fraction alone; coherent zone output") + `b3f8092` ("R2 audit F1 — aggregate zones
scoped to the second break"); the AND-term is gone at both sites and
`test_ddd_breaking_w5_saturation.py` pins Q_b-only. This section was never marked DONE — a
plan-status staleness, corrected here. **Consequence, recorded honestly: the 2026-08-09
screenshot's wall-to-wall impact rendering is the model's output WITH the cessation fix**
(on tonight's shelf/tide the model chains breaks at 100.6 → 47.6 → 2.7 m with a ~1 m reform
band); the R3 fixed window + all-break labels make it legible, but whether chained impact
with near-zero reform is physically acceptable on this profile is an open model question
for the operator if the rendered result still reads wrong after R3 deploys.

**Owner:** `clearskies-api-dev` (Sonnet, marine repo); tests `clearskies-test-author`.
**QC:** `clearskies-auditor` at Gate R2 (blind — never sees the dev's tests/commits/report).
**Authorization:** D-R1 ruling (physics criterion change, trigger 1) — plan approval is the
paper trail. Constants γ = 0.73, Γ = 0.40, K = 0.15, Q_B_VISIBLE = 0.05, Q_B_CESSATION = 0.02,
β_D = 0.10, 15 cm reform floor: **ALL UNCHANGED** (decision-register item 2 of the remodel
plan stands; nothing here re-tunes a dial — R2 removes one dead AND-term and repairs zone
bookkeeping).

**R2.1 — Cessation per D-R1.** In `_ddd_breaking_march()` (`surf_1d_analytical.py:1242`; the
AND-term site is the `H <= _DDD_STABLE_GAMMA * d` conjunct documented at `:75` and applied
near `:1367` — agent re-pins exact lines at HEAD per prime-directive rule 7): cessation
becomes `Q_b < Q_B_CESSATION` alone.
**Scope clarification (lead ruling 2026-08-08, at R2 dev scope-ack):** the SAME conjunct
exists in a second, mirrored site — `apply_ddd_saturation()` (:1910 at `1d012f6`), the
combined-profile counterpart whose returned `roller_energy_profile` is the exact `er` array
zone classification consumes (`surf_1d_pipeline.py:750` — production-verified). **Both
sites lose the conjunct.** Grounds: D-R1 rules the CRITERION, not one function; fixing only
the per-partition march would pass the KAT while production kept drawing the never-ceasing
impact zone through the combined path. `test_ddd_breaking_w5_saturation.py` (which pins the
AND-term timing in apply_ddd_saturation) is updated same-commit with a programmatically
derived expectation, per the stale-test rule.
**Second lead ruling (2026-08-08, at R2 dev dry-run):** the aggregate `_classify_zones`'
E_r local-max/floor window is clamped at the next break (mirroring
`_classify_zones_per_break`'s approved Round-X clamp; the aggregate variant's unbounded
window contradicted its own "WITHIN the zone" docstring and was unreachable pre-R2 since
no wave ever ceased). Methodology: the 5% criterion and all constants untouched.
**Worked-consequence CORRECTION + K1(d) threshold change (flagged to operator, not
silent):** the plan's "~10 m roller tail" estimate was wrong on the real transect-24
profile. Measured march with ALL constants at locked values: cessation at 58.94 m
(Qb 0.0195 < 0.02), re-onset at 41.78 m (Qb 0.073) — a 17 m lull, too short for E_r to
clear the 5% floor before zone 2 re-feeds it. Honest outer-impact width: **51.49 m**
(was 94.39 m at HEAD). R2-K1(d)'s "≤ 40 m" accept bound was the estimate, not physics —
enforcing it would require changing a locked constant. REWRITTEN to pin the structural
contract instead: width < 60 m AND < 90 m (HEAD fails both), end seaward of the second
break (HEAD's −1.12 m fails), end = genuine floor-crossing or next-zone fallthrough.
Fail-pre-change preserved on every prong; HEAD values recorded in the test docstring. The existing re-break machinery (rise through
Q_B_VISIBLE after a prior cessation, forbidden in depth < 0.15 m) is UNTOUCHED — with
cessation reachable, it is what produces the shorebreak.
**Worked consequence (from live 2026-08-08 05:00Z numbers, transect 24, tide −0.315):** outer
break onsets at ~94 m (depth 1.19 m, hs 0.69 m — unchanged); across the terrace the broken
wave decays toward 0.40·d, Q_b falls to ~2–4×10⁻³ < 0.02 → **cessation mid-terrace**; roller
then starves (D_br = 0) and E_r decays with its ~9 m e-fold length → impact zone ends a short
distance past cessation instead of at the sand; the ceased wave (hs ≈ 0.3–0.4 m) marches the
inner slope, depth drops through ~0.5 m inside ~30 m, Hrms/Hmax rises, Q_b re-crosses 0.05 →
**second break = shorebreak** in knee-deep water near the waterline, well seaward of the
15 cm floor. Both operator-visible defects (300 ft impact zone, missing shorebreak) fall out
of this one change.
**R2.2 — Zone-coherence guards.** `_classify_zones()` (`:2227`) and
`_classify_zones_per_break()` (`:2351`): emit `reform_trough` ONLY when the impact-zone end
lies strictly seaward of the innermost break (`distances[impact_end_idx] >
inner_bp.distance_m`); otherwise `None`. Today's served output (reform trough 3.7→88.7 m
INSIDE the impact zone 93.7→3.7 m, foam zone zero-width) is the unguarded case. New fire-only
invariant in `services/invariants.py`: served zones never overlap; trough, when present, lies
between impact end and inner break.
**R2.3 — Tests** (`clearskies-test-author`; every KAT's fail-pre-change transcript recorded):
- **R2-K1 (the terrace KAT — must FAIL at HEAD):** fixture = REAL transect-24 profile from
  `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` (261 points), tide
  −0.315 m, partitions 0.353 m @ 18.4 s + 0.343 m @ 13.1 s (the live 05:00Z inputs). Assert:
  outer break within ±10 m of 94 m; a cessation occurs at depth > 0.3 m; a re-break exists
  shoreward of 30 m; impact-zone width ≤ 40 m (vs 90 m at HEAD).
- **R2-K2:** X-K1 (independent Battjes–Janssen Q_b reference) passes unchanged.
- **R2-K3:** X-K2 (T55 bar fixture, Hs 1.1 m → bar break + distinct shorebreak) passes
  unchanged — this KAT already demanded the double break; R2 makes it reachable on terrace
  profiles too.
- **R2-K4 (no-chatter):** monotone gentle slope — at most one onset/cessation pair per bar;
  hysteresis holds.
- **R2-K5 (zone coherence):** the R2.2 guard on the live 05:00Z shape (impact reaching the
  waterline pre-fix) yields `reform_trough = None` pre-R2.1-style inputs, coherent zones
  post; invariant registered and logged.
- Round-W/X guard-test inventory: any existing test pinning the AND-term cessation is listed
  and updated IN THE SAME COMMIT (stale-test block applies; none may be silently deleted).
**Files (exhaustive):** `weewx_clearskies_marine/services/surf_1d_analytical.py` (cessation
conjunct + zone guards ONLY — this names it out of the frozen core for exactly these edits),
`weewx_clearskies_marine/services/invariants.py`, tests as above.
**MUST NOT TOUCH:** the Q_b solve (`_breaking_fraction`), onset semantics, all constants
(list above), the 15 cm floor, the one-sided DDD step, the roller march equations,
`surf_1d_pipeline.py`, anything in `endpoints/`.
**Accept (live):** post-deploy cycle at a low-tide hour serves ≥ 2 break points on the
representative transect with a finite impact zone (≤ 40 m) and a coherent trough; raw
profile JSON pasted.

**LIVE ACCEPT — first post-R2 cycle (08:47:37→09:17:53Z, 30 m 16 s, deployed b3f8092), raw
payloads in session record:** CESSATION+RE-BREAK LIVE — the profile (09:00Z, tide −0.835,
transect 23) serves an outer plunging break at 116 m and a cascade of re-breaks shoreward;
one endless break is gone. Headline stable: face 0.92–0.94 m at matched hours (pre-R2
0.92–0.96 — inside the ≤10% row); min/max healthy (0.80–0.94). INV-11 rate: 19,923 →
11,768 per precompute window (−41%, still huge — F2 item stands). INV-13 fired 240× (the
new guard working, on the finding below). **NEW FINDING (operator ruling requested,
D-R6):** the zone classifier consumes the INTERLEAVED multi-partition break list — the two
swells break ~2 m apart at the outer bar (duplicate 116/114 m pair), so `break_points[1]`
is the OTHER SWELL's outer break and the aggregate impact zone collapses to a 1 m sliver;
12 break markers serve (6 per swell, pairs at the same spots); the inner shelf at extreme
low tide staircases through ~5 tiny re-breaks (0.13–0.29 m faces in 0.2–0.4 m water —
physically arguable at −0.8 tide; webcam row judges). RECOMMENDED (a): zones + served
break list computed from the DOMINANT partition only (consistent with the operator-ruled
WC-D3 dominant-break chart filter); alt (b): cluster/merge cross-partition breaks within
a grid step; alt (c): leave as-is. No change without the ruling; the webcam gate row and
R3's chart work both want this settled first.

**D-R6 RULED — operator, 2026-08-08 chat (explicit order):** "fix the profile so it only
models the dominant swell, make sure that is what displays on the dashboard." Option (a):
backend serves dominant-partition-only breaks and zones; dashboard display verified
end-to-end at live accept. (Earlier same day the coordinator had wrongly treated the
operator's *question* as this ruling and dispatched prematurely; the operator stopped it —
agent killed at scope-ack, zero code. This entry is the actual ruling.)

**Operator context for this round (recorded 2026-08-08):** the operator has been testing
the model against the ground throughout and reports the break points have not matched
reality. This round is DISPLAY correctness only (one swell's coherent picture instead of
two interleaved ones) — it is not claimed as a fix for break-location accuracy. The
break-location-vs-reality question stays open after this ships.

### PHASE R5 — D-R6 remediation: dominant-partition breaks + zones (RULED, dispatched 2026-08-08)

**R5 ACCEPT — RECORDED 2026-08-09 00:20Z (deployed a399eb6 at 23:35:16Z; accept cycle =
the 18z full run 23:36→00:13:59Z; coordinator of the L1-BOUNDARY-REBUILD session ran the
accept as an unblocking step for that plan's Phase C).**
1. ✅ partitionIndex uniformity: served breakPoints distinct partitionIndex = `{0}`
   (curl /profile → python; single wind-swell partition day, 3.5 s / 0.74 m).
2. ✅ No duplicate outer pair: 2 breaks served — 42.8 m spilling + −4.2 m plunging
   shorebreak, same partition. (Original 116/114 m case unreproducible on a
   single-partition day; the structural cause — interleaved cross-partition list — is
   gone by selection.)
3. ✅ Marker count 2 ≤ 6 (was 12 on the defect hour).
4. ✅ w/ note: aggregate foamZone ends exactly at the dominant swell's OWN next break
   (42.8 → −4.2); no zone overlap (per-break zone 2's impact band −4.2→−10.2 starts where
   aggregate foam ends). Aggregate impactZone is zero-width at the outer break — spilling
   breaker physics (no plunge point), NOT the cross-partition sliver defect.
5. ✅ INVARIANT_13 firings since deploy: **0** (`journalctl --since 23:35 | grep -c
   INVARIANT_13` = 0; was 240×/cycle).
6. ⚠ STRUCTURAL ONLY: pre-deploy served payload was NOT captured before deploy
   (coordinator baseline miss, recorded). Numeric matched-hour headline diff therefore
   impossible. Structural evidence: `git show a399eb6 --stat` = endpoints/surf.py,
   endpoints/beach_profile.py, tests only — zero height-producing code touched; current
   headline 0.84–1.09 m face, in family with R2's 0.92–0.94 m record.
**Disposition: R5 round CLOSED as accepted (5/6 numeric + 1 structural, deviation
recorded).** R2's separate webcam row remains open in its own gate block.

**Owner:** clearskies-api-dev (Sonnet). **Auditor:** clearskies-auditor (blind), then lead gate.
**Dominance criterion (lead call, no re-derivation):** per-transect — the partition with the
largest `face_height_m` among that transect's `per_partition` entries that have
`break_points`. This is the EXISTING operator-ruled definition already in
`endpoints/surf.py::_representative_transect_primary_break_point` (:597-602, operator ruling
2026-08-02 Q3 "that's the wave surfers care about"). NOT the spot-level deep-water
`dominant_pbi` (`beach_profile.py:495-500`, key `height_m`) — that one stays untouched
(SurfBeat blending + wave shapes). Per-transect selection self-heals the fallback case:
if the spot-dominant swell doesn't break on this transect but a secondary does, the
secondary is served (a chart with breaks visible on cam must never draw none).

**Design, to file and line:**
1. `endpoints/surf.py` — extract the :597-602 dominant-selection loop into a module-level
   helper `_dominant_partition_break_result(transect) -> PartitionBreakResult | None`;
   `_representative_transect_primary_break_point` calls it (behavior unchanged);
   `_break_points_for_representative_transect` (:545-554) replaces its
   all-partitions loop with the helper — emit ALL break points of the ONE dominant
   partition (outer break + its own re-breaks; R2's staircase is one swell's re-breaks and
   stays). Docstring (:515-521 "EVERY swell partition") updated to match.
2. `endpoints/beach_profile.py` — break_points producer (:560-646): select the per-transect
   dominant `pbr` by the SAME criterion, run the existing body (primary emission :606-615,
   non-primary emission :629-645, partitionInfo/canonical lookup :565-598 incl. the
   unmatched-partition warning) for that single pbr only. `_bp_objs` (:719-728), aggregate
   `_classify_zones` (:735-740), `_classify_zones_per_break` (:747-750) and INVARIANT_13
   then consume dominant-only automatically — no changes inside them.
3. Tests: rewrite the pins in `tests/test_v3_f4_breakpoints_1d_pipeline.py` (multi-partition
   collection is superseded) and any pinned all-partitions expectations in
   `tests/test_beach_profile_partition_index_spaces.py` / `test_beach_profile_unification.py`;
   NEW `tests/test_r5_dominant_partition_breaks.py` KATs: (K1) two partitions both breaking →
   served list is exactly the larger-face partition's breaks, single partitionInfo;
   (K2) dominant-by-face has no breaks on this transect, secondary does → secondary served;
   (K3) zones computed from dominant-only list — no cross-partition degenerate pair, no
   INVARIANT_13 firing on the K1 fixture.

**MUST NOT TOUCH:** dashboard (chart filter at `BeachProfileChart.tsx:585-594` stays as
harmless defense — R3's scope, not this round's); `surf_1d_pipeline.py`;
`surf_1d_analytical.py`; `swelltrack_cache.py`; `invariants.py`; the spot-level
`dominant_pbi` block (`beach_profile.py:495-528`); wave shapes/jacking; the wire SHAPE of
breakPoints entries (fields unchanged — only which entries are served changes).

**Contract note (authorization):** served-list semantics change = trigger 4; authorized by
the operator's D-R6 (a) ruling above + standing "plan spells it out" grant. Doc-sync row:
API-MANUAL breakPoints description ("every partition" → "dominant partition") lands in this
round's DOCUMENTATION table entry.

**Accept (live, expected numbers):** post-deploy cycle, low-tide `/profile` hour —
(1) every served breakPoints entry carries the SAME partitionInfo.partitionIndex;
(2) the duplicate 116/114 m outer pair is gone (one outer break);
(3) marker count ~half (12 → ≤6 on the comparable hour);
(4) aggregate impact zone is tens of meters (sliver ≥1 m → bounded band ending at the
    dominant swell's OWN next break), no zone overlap;
(5) INVARIANT_13 firing rate on degenerate cross-partition pairs → 0 in the post-deploy
    journal window (was 240×/cycle);
(6) headline face/min/max unchanged vs pre-deploy matched hour (this round must not move
    heights — it only changes which breaks/zones are DISPLAYED).

### ⛔ QC GATE R2 — `clearskies-auditor` (adversarial, blind), then lead gate
**Row 3 (blind adversarial) RUN 2026-08-08 — 1 BLOCKER, 1 MAJOR, both lead-synthesized:**
The auditor independently verified the Q_b solve (own Brent solver, 1e-8 agreement),
DISPROVED false-cessation under production-faithful bathymetric noise (PCHIP/native-spacing
up to 10 cm), verified the 15 cm floor under adversarial oscillation, verified no
steep-slope regression, and — highest value — verified the SERVED combined path
(`apply_ddd_saturation`) ceases/reforms on a terrace shape (the gap the KATs never covered).
**F1 [BLOCKER, ACCEPTED → remediation dispatched]:** aggregate `_classify_zones` trough/foam
ends still assume ≤2 breaks (`break_points[-1]` / waterline) — on the 3-break profiles R2
now produces, aggregate bands overlap the middle break's per-break zones (repro:
trough [54.90→3.75] atop break-2 impact [54.79→3.75]). Lead ruling (third application of
the next-break-scoping principle): aggregate trough+foam end at `break_points[1]` when
n≥2; waterline criterion survives only for n==1; INVARIANT_13 comparison updated; one
lead-directed 3-break coherence test added same-commit; ships as a second commit atop
`fdf7afc`. **F2 [MAJOR, ACCEPTED as evidentiary gap]:** INVARIANT_11's comparison_starved
exclusion makes the closure check structurally blind exactly at cessation boundaries — the
"energy still closes" claim is unverifiable by the round's own designated verifier there.
Joined with the pre-existing ~200k/day firing noise (see Gate R4 event) into ONE operator
item: redesign/rate-limit/root-cause INV-11 as its own ruled task; the R2 gate's
closure row relies on the auditor's independent spot-solve + the pre/post firing-rate
comparison, stated as such, not on INV-11 silence.
Adversarial brief: "Prove a broken wave still cannot cease on a flat shelf (construct worse
terraces: 200 m at uniform 0.9 m). Prove cessation now fires where breaking should continue
(steep bar face — false cessation mid-break). Prove the shorebreak is an artifact of the
15 cm floor rather than a real Q_b re-crossing. Prove zones can still overlap. Prove
energy closure (X-K3 invariant) drifts with the roller now starving mid-profile."
**Reality gate (pre-stated, the operator's standard — the webcam outranks every formula):**
first daylight low-tide hour after deploy — webcam beside chart: outer whitewater line AND a
distinct shorebreak visible on cam ⇔ chart draws both breaks with a bounded impact band, same
hour, screenshot beside payload. FAIL either direction = round stays open. Matched-hour face
height still within the Surfline envelope (the heights were right before R2 — they must not
move; any breaking-face delta > 10% vs the pre-R2 cycle at matched hour is a gate failure).
**Escalation path if reality still disagrees after R2 (pre-stated so it cannot be improvised):**
the ordered suspects are (1) bathymetry — judged against D-R4's independent-survey delta
(REQUIRED input to this gate); (2) shoaling amplification — the 0.35 m offshore → 0.69 m
at-shelf growth chain, checked against cam at matched hours; (3) the Q_B_VISIBLE = 0.05
cutoff — a display-sensitivity dial, recalibrated only by operator ruling with side-by-side
screenshots. Each escalation returns to the operator with evidence before any further code
change; if the evidence ends up indicting the statistical breaking model itself, its removal
and replacement is an operator decision with a designed successor — never a mid-round rip-out.

---

## PHASE R3 — Fixed beach-profile scale *(operator-ruled, third request)*

**Owner:** `clearskies-dashboard-dev` (Sonnet) + `clearskies-api-dev` (one metadata field).
**QC:** `clearskies-auditor` at Gate R3. **Pre-approved architectural scope (trigger 4/7):**
one additive per-spot config key + one additive field in `/profile` metadata (D-R2 ruling).

**R3.1 — Assign and serve the window.** Marine spot config gains
`profile_display_window_m` (one of the D-R2 ladder presets) + `profile_display_landward_m`
(default 30). Assignment happens at spot establishment: smallest ladder preset that covers
BOTH the modeled profile extent and the deepest plausible break location — computed once,
written to spot config, changed only by re-establishment or explicit operator edit (mirrors
the Z-D1 stickiness principle: the display frame never moves hour-to-hour).
`/surf/{id}/profile` serves both values in `metadata` (additive; response shape otherwise
untouched). API-MANUAL §17 documents them.
**R3.2 — Fixed chart domain.** `BeachProfileChart.tsx`: DELETE the data-driven tier selection
(`selectTier`, `:144-161`, and the tier tables `:315-317`); the x-domain is exactly
`[+window, −landward]` from metadata (converted via `METER_TO_UNIT`, `:314`), every render,
regardless of where breaks, transect ends, or zones fall this hour. Content beyond the domain
clips; content short of it does NOT stretch. Tick generation keeps its current spacing rules
over the fixed domain. Fallback when metadata absent (older API): the Huntington preset,
hardcoded next to a comment naming this plan — never the old tier logic.
**R3.3 — Tests** (vitest, `clearskies-test-author`): two fixtures — break at 20 m and break
at 300 m — assert IDENTICAL axis domain (this test MUST FAIL against the tier logic at
HEAD); landward extent renders to −30 m with the beach fill; a zone extending past the
domain clips without distorting the bands.
**Files (exhaustive):** dashboard `src/components/marine/tabs/BeachProfileChart.tsx`,
`src/api/types.ts` (metadata type), its test file; marine `endpoints/beach_profile.py`
(metadata block only) + config plumbing for the two keys; API-MANUAL §17 + DASHBOARD-MANUAL
rows.
**MUST NOT TOUCH:** ~~the dominant-break annotation filter (`:585-594` — WC-D3 behavior,
unchanged)~~ **REVERSED 2026-08-09 PM (operator, in chat: "the fact that you cannot see two
breaks means you are blind"): EVERY served break point gets its height/type label — the
dominant-only annotation filter is DELETED in the same round (collision handling kept)**;
zone band rendering; wave-surface sampling; the heat map.
**Accept (live):** two screenshots, one high-tide hour and one low-tide hour, both axes
reading identically (492 ft … −98 ft under D-R2 defaults); no crop of the modeled profile.

### ⛔ QC GATE R3 — `clearskies-auditor`, then lead gate
Adversarial brief: "Prove the axis can still move — feed breaks at 5 m and 320 m, metadata
absent, metadata partial, Hawaiian units, meters locale. Prove the clip distorts a zone band
or the waterline marker at either extreme."

---

## DOCUMENTATION — exact deltas (each ships in its task's code commit; none deferred)

| Doc | Phase | Delta |
|---|---|---|
| `docs/manuals/API-MANUAL.md` §17 | R1, R3 | min/max fields live (cache-codec note: fields round-trip the swelltrack cache as of R1); `/profile` metadata display-extent fields. |
| `docs/manuals/PROVIDER-MANUAL.md` | R2, R4 | Cessation = Q_b-only (AND-term removed, with the asymptote rationale); work-root location + hotstart retention policy. |
| `docs/ARCHITECTURE.md` | R2, R4 | Breaking state-machine semantics row; persisted-file locations `/run` → `/var/lib`. |
| `docs/manuals/OPERATIONS-MANUAL.md` | R4 | New persisted paths, unit `ReadWritePaths`/`StateDirectory`, migration procedure, retention; corrects the M-0d row that called the profile store "on disk" while it lived on tmpfs. |
| `docs/manuals/DASHBOARD-MANUAL.md` | R3 | Fixed-scale rule (data-driven tiers removed; operator ruling 2026-08-08). |
| `docs/decisions/ADR-102` (amendment) | R2 | Cessation criterion change, D-R1 ruling text, live evidence (hs = 0.40·d to 1 cm). |
| `docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md` | R1, R2, R4 | Status pointers: WC-D3 residual → this plan; M-0d storage-location correction pointer. |

## Standing process (applies to every task above)

Dispatch gate per `rules/coordinator.md` §1 (allowlist, design-to-line from THIS document,
prohibition list, live check with expected numbers) — all four written in the brief before any
agent starts. Mandatory verbatim blocks (git, architectural, stale-test) in every brief.
Sonnet for all delegated work; the lead independently re-runs every claim (acceptance gate §2).
One functional change per deploy; `deploy-marine.sh` only; running commit + process start-time
recorded; post-deploy journal sweep with pre/post ERROR/WARNING class counts. Reality-gate
rows pasted raw beside the external reference, tolerances as written here, never restated
after seeing numbers. Any trigger-list hit not pre-approved in this plan → STOP and surface.

## Decision log

- **2026-08-08 — plan created** from the same-day audit (six handoff issues + operator memory
  finding). Operator rulings in chat, recorded above: double break required where outer
  breaking is real; fixed chart scale (third request); RAM-disk storage must stop. DECIDE
  items D-R1..D-R4 opened. Status DRAFT pending operator approval.
- **2026-08-08 — PLAN APPROVED, all D-items ruled** (operator, in chat, verbatim: "1. yes.
  2. sorry i meant 150. 3. yes. 4. yes, follow all rules, especially related to agent
  delegation and adversarial qc. make sure you update the plan with progress and completion.").
  Status → ACTIVE. R1 dispatch begins same session (test-author first for the
  fail-pre-change transcript, then api-dev, fix + tests in one commit; adversarial auditor
  before the lead gate).
- **2026-08-08 — authorization semantics ruling** (operator, in chat, verbatim: "the plan
  itself serves as permission for architectural changes if they are spelled out in the
  plan"). An architectural change SPELLED OUT in this approved plan (D-R1 cessation term
  removal; R3.1 config key + metadata field; R4 path/config/unit changes) needs no
  re-approval at dispatch. Anything NOT spelled out here still stops and surfaces —
  the trigger list continues to bind for new territory.
- **2026-08-08 — standing push/deploy authorization** (operator, in chat, verbatim: "you
  have permission to push/deploy, as coordinator, as necessary for testing"). Scope: this
  plan's phases, coordinator-executed, deploy scripts only, one functional change per
  deploy, every deploy still carries its gate evidence and reality row. R1.2 CLOSED
  same session: tests/test_swelltrack_cache_roundtrip.py authored (79 lines, 2 tests);
  fail-pre-change transcript on record (test (a) FAILS at deployed 65a7c73 with
  `assert None == 1.3`; test (b) legacy-tolerance PASSES pre-change as expected).
- **2026-08-08 (later, same session) — operator challenged the physics constants and the RAM
  disk's origin.** Answers recorded: (a) Q_b thresholds (5%/2%) are the statistical-breaking
  visibility constants the operator approved in the remodel plan's decision register item 2
  (real seas are a height distribution; Q_b is the fraction of passing waves breaking at a
  point); (b) Γ = 0.40 is the Dally–Dean–Dalrymple (1985) stable-wave-height coefficient,
  lab-calibrated (Horikawa & Kuo data) — it is the published reformation criterion, not
  filler, and it remains in the dissipation equation regardless of the D-R1 ruling; the
  defect is the unreachable `≤` test against an asymptote, not the constant; (c) RAM-disk
  provenance pinned to `b3348b6` (see Phase R4 provenance block) — a 2026-07-17 debugging
  convenience, never an approved design. Scale semantics re-ruled: fixed preset windows
  assigned per location at setup (D-R2 rewritten); 140-vs-150 m sub-question opened.
