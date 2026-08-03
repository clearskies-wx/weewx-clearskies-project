# Wind Provider Decoupling + Assembly — Design for Operator Review

**Status: ✅ FULLY APPROVED 2026-08-03 (operator chat: "yes fully approved"), including the
revised single-assembled-timeline store (§2) confirmed by explicit read-back.** Build rounds
sequence per §5 migration order after the follow-up queue clears; each step separately
deployed + reality-gated. Nothing dispatched yet.
Implements the operator ruling of 2026-08-03 (AUDIT-OPUS-WINDOW-2026-08-03.md, decision item 9):

> "You need to decouple the HRRR gathering from the runs… This is an external API provider just
> like any other and needs treated as such. It should have its own independent timings, not be
> tied into the surf system, especially if that information may be used by other portions of the
> marine service. Second, if we have to assemble our information, then we need a mechanism to do
> that. Third… We need to cut back our hourly runs to 12 hours." + read-back confirmation:
> per-hour freshest-available assembly; 12 h fast cycle ("half a day"); full runs trigger on
> extended-cycle-assembled-complete.

Evidence base: [V3-F1-WIND-HOLE-INVESTIGATION-2026-08-03.md](V3-F1-WIND-HOLE-INVESTIGATION-2026-08-03.md)
(mechanism, doc conflicts, §3b time-shift, finding 13 fast-cycle unreachability) + live journal
completeness survey 2026-08-03 (every extended-cycle first fetch partial: 7-31 of 49).

---

## 1. The component: Wind Gatherer

**One new background component inside the existing marine service process** — an independent
asyncio task with its own scheduler, started at service startup, never invoked by (and never
invoking) the run path.

**Considered and not recommended:** a separate systemd service. It maximizes "treated like an
external provider" but adds a deployment unit, port-less IPC or file-locking complexity, and a
second failure domain — for a gatherer whose consumers all live in the marine process anyway.
The in-process task satisfies the ruling's substance (own timings, zero coupling to runs, shared
by all marine consumers). If a second service ever needs wind (e.g. the API host), the store
format (below) is file-based and shippable. **Operator may override to separate-service.**

**Responsibilities (all of these move OUT of the run path):**
- Detect new HRRR cycles (hourly 18 h; extended 00/06/12/18Z 48 h) and GFS cycles (far window).
- Fetch incrementally: only forecast-hours not yet held for a cycle ("top-up"), respecting the
  existing NOMADS pacing (0.55 s) and rate limiter.
- Track per-cycle completeness (which f-hours held vs expected).
- Maintain the assembled store (below) and emit events: `hourly_cycle_assembled`,
  `extended_cycle_assembled`.

**Schedule (gatherer-owned, tunable constants):**
- During an upload window (cycle start +50 min → +2 h, or until complete): top-up poll every
  5 min.
- Otherwise: idle check every 15 min (catches late posts and startup gaps).
- On startup: reconcile the store against expected cycles (cold-start backfill of the newest
  complete extended cycle + newest hourly).

## 2. The store: ONE assembled wind timeline, updated in place
*(REVISED 2026-08-03 per operator review Q2 — "we need to be keeping one fully assembled set,
why are we keeping individual fragments?" The original per-cycle-fragment design + retention
depths are DROPPED.)*

File-backed under the marine service's run directory (survives restarts):
- **`wind_timeline.json(.gz)`** — THE single assembled set: one record per forecast hour over
  the working window (now → +72 h), each carrying the grid data + per-hour provenance metadata
  (source cycle, issue time, fetched-at). When a fresher cycle's file for an hour arrives, that
  hour is REPLACED in place. Hours behind the wall clock age out at the front. No per-cycle
  fragment files are kept — an hour's previous value has served its purpose the moment a
  fresher one lands.
- **`incoming.json`** — completeness tracker for the cycle currently being assembled ONLY:
  expected hours, held hours, assembled-complete flag. Cleared when assembly completes (its
  hours are already merged into the timeline as they arrived).
- **Read API (in-process):** `get_wind_series(t0, t1)` → the timeline's hours in range, with
  the per-hour provenance and a series-level coverage summary; refuses (named reason) if the
  range has a gap or non-uniform cadence — by construction it shouldn't. `get_status()` →
  freshness/completeness summary (consumed by /health now; a future full status page per
  operator Q4 pin).
- **Disk bound:** one timeline (~tens of MB) + one tracker. No retention policy needed —
  the structure is self-bounding.

**Invariant (new, replaces inv-candidates from the hole class):** a series returned by
`get_wind_series` is gap-free and uniform-cadence by construction, or the call REFUSES with a
named reason. The `wind_dt_hr = 1` positional-cadence assertion in the SWAN input writer gains a
hard validation: non-uniform/gapped series → refuse the run (this is investigation option (f),
folded in — a gapped field can never again be silently time-shifted).

## 3. Consumers (all read-only against the store)

| Consumer | Today | Under this design |
|---|---|---|
| Full 48 h SWAN run | fetches inline at trigger time; ran on 7-31/49 hours every cycle | triggered BY `extended_cycle_assembled` (~4×/day, ~90 min after cycle start); reads a complete assembled 48 h series |
| Hourly fast cycle | 24 h scope; trigger unreachable in production (finding 13) | REAL hourly trigger on `hourly_cycle_assembled`; **12 forecast hours** (operator: "half a day"); reads assembled freshest |
| Surf-card display wind | request-time 19-file download + publish-time warming thread (H5) | reads the store; H5 warming thread and request-time fetch path DELETED (decision item 1 dissolved) |
| GFS far window (48-72 h) | separate fetch, same partial-success defect class | gatherer-owned on the same manifest pattern (fixes the GFS twin defect) |

## 4. What gets deleted (no dead code)

- `hrrr.py` request-time fetch orchestration from consumer paths (fetch machinery itself is
  reused by the gatherer); the f00-only "posted" detection; the cycle-fallback loop (assembly
  replaces it).
- H5 publish-time warming thread (`_warm_hrrr_cache_for_locations`) + its KAT file (superseded
  behavior — tests updated in the same commit per stale-test rule).
- The run-path's HRRR-cycle-keyed dedup interactions where they gated on fetch-time cycle
  detection (run triggers become event-driven; the forced-run bypass semantics from the livelock
  fix are preserved against the new trigger).

## 5. Migration order (each step deployable + reality-gated)

1. **Gatherer + store land dormant** (no consumer switched; store observable via /health +
   admin). Verify: manifest shows real completeness curves over ≥2 extended cycles.
2. **Display wind switches** to the store (lowest risk, user-visible latency win). Verify: /surf
   response times; no inline NOMADS fetches in journal from request path.
3. **Full run switches** to `extended_cycle_assembled` trigger + store reads. Verify: first
   triggered run consumes 49/49; reality gate vs NDBC.
4. **Fast cycle (12 h) switches on** — first time this path runs in production. Verify: hourly
   cadence in journal; C3's fill-runtime measurement finally lands here.
5. **Deletions** (§4) + doc batch (PROVIDER/API/DASHBOARD manual updates incl. the V3-F1 doc
   conflicts).

## 6. Trigger classification (for the record)

Trigger 2 (new component + responsibilities move), 5 (fetch lifecycle moves), 6 (new schedules;
run triggers change), 7 (new persisted store files). **All authorized by the 2026-08-03 operator
ruling.** Constants that remain operator-tunable at review: top-up poll interval (5 min), idle
interval (15 min), retention depths, 12 h fast-cycle scope (ruled).

## 7. Open questions — OPERATOR REVIEW 2026-08-03 (chat)

1. In-process gatherer task — **✅ RULED: yes.**
2. Store retention — **✅ RULED: NO fragment retention; ONE fully assembled set updated in
   place** ("we need to be keeping one fully assembled set, why are we keeping individual
   fragments?"). §2 rewritten accordingly — read-back of the revised store shape confirmed by
   operator before build.
3. Fast-cycle trigger — **✅ RULED: after complete assembly** ("yes after complete assembly")
   — both run types trigger on their cycle's assembled-complete event, never on partial reads.
4. Admin wind-status readout — **📌 PINNED by operator**: "maybe that would be a part of a full
   status page or something… but not individually." `get_status()` ships for /health's internal
   use; NO standalone admin widget; revisit if/when a full status page is designed (joins the
   operator-visibility tracked item).
