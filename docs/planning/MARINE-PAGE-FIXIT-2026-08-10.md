# Marine Activities Page — Fixit Log (2026-08-10)

**Status: CLOSED AS EVIDENCE RECORD 2026-08-10 — research complete, operator rulings
recorded per item, and the whole log is now turned into the execution plan at
[MARINE-PAGE-FIXIT-PLAN-2026-08-10.md](MARINE-PAGE-FIXIT-PLAN-2026-08-10.md) (granular
tasks, QC gates, agent assignments, docs-first). This file stays as the evidence and ruling
record the plan cites; no further items land here. Rewritten in plain English 2026-08-10 at
the operator's request.**

**How the research was done:** two read-only agents read the server code and the dashboard
code; the lead pulled live data from the dev site's API, read the model service's logs on
the compute machine, and checked what's actually deployed. Raw copies of the live data are
saved in the session scratchpad. Nothing was modified anywhere.

A note on names used throughout, defined once here:

- **WaveWatch III (WW3)** — the government's global ocean wave model. It's where our
  offshore wave information comes from.
- **SWAN** — the wave model we run ourselves. It takes WaveWatch III's waves at its outer
  edge and computes how they change as they cross the shelf and approach the beach.
- **Swell train** — one family of waves from one storm (the model's word for this is a
  "partition"). A day's ocean usually carries several trains at once.
- **The offshore reading point** — a fixed spot at 15 m depth where we sample the swell,
  deliberately comparable to a buoy reading. (Internal name: the deep-water reference, "DWR.")
- **Transect** — one measurement line running from offshore to the sand. We model 162 of
  them spaced along the beach. The surf-by-location detail comes from these.
- **Breaking fraction** — at any point along a transect, the percentage of waves that are
  actively breaking there. This number drives where we say "the break" is.
- **Whitewater energy** — the energy the foam/roller carries after a wave breaks. It decays
  as the broken wave moves shoreward, and we use it to size the impact zone.

---

## Item 0 (added during research) — the service had crashed, and the page never said so

**What we found before anything else:** at the time of the screenshots, the model service
had not published anything for almost 13 hours, and the forecast it was serving had a
34-hour hole in it. Every card that said "current conditions" was actually showing data
about 5 hours old — with nothing on the page indicating that.

**Root cause (operator report, same day):** at startup the service looked for a temporary
directory it never actually used. When the server rebooted for maintenance overnight, that
put the service into an endless crash loop. **This has been repaired.** The lead re-checked
the live site afterward: the service is publishing again and the forecast once again starts
at the current hour.

**Two things remain open from this:**

1. **A smaller hole is still appearing, from a different cause.** The recovered forecast is
   missing a 21-hour stretch in its middle. The logs show why this likely happens: when our
   run started, some of the weather-model wind files it wanted had not been posted to the
   government download server yet (they appear gradually over an hour or two after each
   cycle). It looks like the run simply publishes a forecast without the hours it couldn't
   get wind for — silently. That needs to be confirmed and fixed in the fix round; our own
   rules say a model runs on all its inputs or refuses loudly.
2. **Your call:** should the cards show the age of the data — and/or refuse to label a stale
   timestep as "current"? During the crash loop, the page looked perfectly healthy while
   showing 12-hour-old surf. That silence is what let this go unnoticed.

---

## Item 1 — The swell list doesn't match Surfline or the buoys

**What you reported:** we're supposed to be feeding every swell train from WaveWatch III
into SWAN, but the dashboard showed only 1 groundswell and 2 windswells — while Surfline
and the buoys showed more.

### The evidence, captured ~11 AM PDT 2026-08-10

Surfline's spot card (their "LOTUS" forecast):

| Field | Value |
|---|---|
| Surf height (observed, Smart Cam) | 2–3 ft+, "Thigh to stomach" |
| Swell 1 | 1.9 ft @ 13 s from S 184° |
| Swell 2 | 0.2 ft @ 22 s from SSW 193° |
| Swell 3 | 0.3 ft @ 10 s from W 270° |

Surfline's buoy cards (10:56–11:00 AM):

| Buoy | Overall | Individual swell trains |
|---|---|---|
| San Pedro South (213) | 2.3 ft @ 14 s, S 180° | 1.7 ft 14 s S 175° · 0.6 ft 13 s SSE 150° · 0.4 ft 9 s SSW 195° |
| Long Beach Channel (215) | 2.6 ft @ 15 s, SSW 206° | 2.7 ft 15 s S 175° · 0.9 ft 15 s N 355° · 0.3 ft 5 s WSW 250° |
| San Pedro (092) | 2 ft @ 14 s, S 169° | 1.2 ft 14 s SSE 160° · 0.5 ft 10 s SSE 150° · 0.9 ft 5 s W 270° |
| Capistrano Beach Nearshore | 2.3 ft @ 14 s, SSW 207° | 2 ft 14 s SSW 205° · 0.3 ft 22 s SW 215° · 0.2 ft 22 s NE 50° |
| Green Beach Offshore | 2 ft @ 14 s, S 189° | 1.9 ft 14 s S (cut off) · 0.8 ft 6 s W 275° · 0.3 ft 8 s SW (cut off) |

Our own card at the same time: ONE groundswell (1.6 ft, 14.5 s, SSW) and two wind swells
(1.4 ft @ 3.9 s W; 0.6 ft @ 3.3 s SSW). No 10-second west swell, no 22-second swell,
no second south swell.

### What's actually going on — COMPLETE HOP-BY-HOP TRACE (done live, 2026-08-10 ~1:20 PM PDT, operator-ordered)

We use the WaveWatch III **grid** product with per-grid-cell swell-train information — the
old station-based path was deleted Aug 9 and is not involved anywhere. The full chain was
traced with real data from the 19:24Z run (the first good run after the crash-loop repair),
all at matched times:

**Hop 1 — what the grids return: everything we need, and we request all of it.** The run's
fetch asks NOAA for all three swell-train slots plus wind sea plus total height, per grid
cell (confirmed in the run's own request logs). A direct decode of the same file at the grid
cell nearest our southern edge (valid 18:00Z) returned **all three swell slots populated**:
0.49 m @ 13.7 s from 186°, 0.23 m @ 8.5 s from 190°, 0.20 m @ 11.0 s from 192° (wind sea
absent at that cell — calm local wind; the three heights square-sum to the file's own 0.61 m
total, so the fields are self-consistent). The grid product's ceiling is 3 swell trains +
wind sea per cell — that's NOAA's file structure.

**Hop 2 — building our model's offshore edge: THIS IS WHERE TRAINS MERGE.** We decomposed
the actual edge-input file our run built for a mid-boundary point at 18:00Z
(`B_S_0047.txt`). The three distinct south-family trains from Hop 1 arrive there as **ONE
broad energy hump** centered at 13.2 s, spanning ~8–20 s, with no dip anywhere — no
downstream step can ever re-separate them. Why, in plain terms: our edge spectrum is stored
on 35 fixed frequency slots; in this period band the slots are about as wide as the
narrowed peaks themselves, and the big train carries ~6× the energy of each small one — so
the small trains disappear into the big one's shoulder. (The Aug 9 "losing swells" fix
solved this for two COMPARABLE trains; the small-train-on-a-big-train's-shoulder case is
what remains, and the 35-slot grid is the binding limit.) The small trains' energy is not
lost — even their direction survives as a lean (the hump's peak direction drifts
190°→180° across its low-period side) — but their identity as separate trains is gone.

**Hop 3 — SWAN and everything after it: FAITHFUL, proven row by row.** SWAN's own
swell-splitting output at the offshore reading point was compared against the served data
for every one of the 47 forecast hours: **identical — every train, height, period, and
direction.** At 18:00Z SWAN resolved and we served: 1.6 ft @ 14.0 s S 198° + 0.7 ft @
7.2 s W 264° + 0.2 ft @ 14.5 s S 176° — and a 21.8 s train appears at some hours. Nothing
is dropped in fetch, serving, or display.

**So the direct answer to "where is it getting dropped":** it is not dropped in fetch,
serving, or display. The merging happens where we build the model's offshore edge — and the
operator's follow-up challenge (below) exposed the primary mechanism, which is a genuine
defect, not a resolution limit.

### UPDATE (same day, operator challenge): the buoys show DIFFERENT DIRECTIONS — and the root cause is ours

The operator rejected the "same-direction merging" story: the buoys show trains at 150°,
175°, 195°, 270° — nowhere near each other. Correct. Scope note first: the earlier
"faithful, proven row by row" claim covered ONLY the copy from SWAN's output table to the
page — it was never a claim that the model output matches reality, and the operator is
right that it doesn't. Two further live checks settled where the direction diversity dies:

1. **A survey of every wet cell in our fetch corridor** (not just one cell) shows WaveWatch
   III DOES deliver directionally distinct families, cell after cell: the main south swell
   13.7–13.9 s at 187–197°, an SSE train 8.4–8.7 s at 171–172°, a WEST swell 9.8–11.5 s at
   273–286°, a 20.4 s forerunner at ~212–216°, and 3.6–3.8 s chop at ~245–270°. Directions
   span 114°. The single cell sampled earlier (all-south) was unrepresentative.
2. **The west-side edge file we actually fed SWAN** (`B_W_0050.txt`, 18:00Z) contains NO
   distinct west swell at all — its only west-sector energy is 3–5 s chop at 250–255°. The
   10–11 s @ ~277° train that exists in the WW3 cells around that point never made it into
   the file.

**Root cause, confirmed in code** (`boundary_reconstruction.py:442-446` with `:383-407`):
when we compute a boundary point's trains, we average each WW3 "swell slot" (1, 2, 3) across
the four surrounding grid cells **by slot number** — height with height, period with period,
direction with direction. But NOAA does not promise that slot 2 is the same physical wave
system from one cell to the next, and the corridor survey proves it is not: adjacent cells
carry (slot 2 = 9.8 s west swell 277°) next to (slot 2 = 3.6 s chop 259°) next to
(slot 2 = 8.7 s SSE 172°). Averaging across misaligned slots:

- **fabricates trains that exist nowhere** — a 10 s west swell averaged with 4 s chop gives
  a ~6–7 s "west" train; our served 7.2 s @ 264° is exactly that signature;
- **annihilates real trains** — the west swell and the SSE train each get smeared into
  whatever shared their slot number in neighboring cells, so no distinct 277° or 172° train
  survives to the edge file (measured: B_W_0050 has none);
- **homogenizes directions** — circular averaging of a 197° south with a 280° west pulls
  everything toward the energetic south family.

The earlier finding (35 frequency slots + the assigned ±15° directional spread merging
close trains) is real but SECONDARY — it explains small same-family losses, not the
disappearance of a 90°-separated west swell. The slot-mixing defect explains that, and it
is our implementation's assumption, not a WW3 limitation and not SWAN misbehaving: SWAN
never received the trains.

Why existing tests missed it: the reconstruction's tests (bin-sum identity, direction
convention, multimodality) all use fixtures where every cell's slots hold the same trains —
the misalignment case was never exercised.

**Reconciliation with the screenshots:** the awful card you photographed (1 groundswell +
two 3–4 s chop trains, no west component) was the **stale crashed run** (Item 0). The
repaired run's served list — two south groundswells + a 7 s west train + an intermittent
22 s train — matches the Surfline/buoy picture reasonably well. Two visible differences
remain: our west train reads 7.2 s where Surfline's reads 10 s (different models can
legitimately disagree here; our own input had 8.5 s and 11 s components that merged), and
our second groundswell is smaller than the buoys suggest (its energy partly folded into the
main train at Hop 2).

Label wrinkle, unchanged: the server has THREE classes — "groundswell" (≥12.5 s),
"swell" (10–12.5 s), "wind swell" (<10 s) — so our 7.2 s west train displays as
"Wind Swell" while Surfline presents their 10 s west component as a swell.

### Recommendation

1. **Fix the slot-mixing defect — this is now the headline fix of the whole log.**
   Operator follow-up question (2026-08-10): why average at all — why not plug each WW3
   cell's swells straight into the adjacent L1 boundary cells? Answer, recorded: averaging
   was never a requirement. WW3 cells are ~16 km apart and the L1 boundary needs a spectrum
   every 1 km, so ~10–16 boundary points fall between two WW3 cell centers; the accepted
   design interpolated purely so the boundary would vary smoothly instead of in 16-km
   blocks. A smoothness preference — and the opening the bug walked through.

   **Ruled direction (operator, 2026-08-10 chat): let SWAN do the interpolating.** SWAN's
   boundary command accepts spectra at listed positions along a side and interpolates
   between them itself — bin by bin, which is a true MIXTURE (an in-between point carries
   both neighbors' trains at partial strength; no averaged periods or directions, ever).
   "We should not be interpolating and then having SWAN interpolate our interpolation."

   **Primary design for the fix round:** emit ONE spectrum file per wet WW3 cell along each
   offshore side, built purely from that cell's own trains (no spatial sampling code at
   all), positioned at the cell's true along-side location, and let SWAN interpolate
   between them. Notes for the implementer:
   - This supersedes the ruled 1-km boundary-point spacing (ADR-104 P4 / ruling D4,
     "spacing = L1 dx"). That rule existed to stop SWAN interpolating between DISTANT
     spectra — a station-era fear (stations sat 100+ km apart). Adjacent WW3 cells are
     16 km apart; SWAN's mixture between neighbors is exactly the behavior we want. The
     ADR/manual doc-sync lands with the fix.
   - Land-masked WW3 cells supply nothing; SWAN interpolates across the gap between the
     flanking wet cells. The fix round must verify SWAN's behavior seaward of the FIRST and
     LAST supplied position on each side (extend the end cells' spectra to the side's
     corners explicitly if needed) and keep the ascending-position and file-count rules of
     the existing emission machinery (file count drops ~194 → ~15, retiring the 99-file
     command-cap concern in the parking lot).
   - Fallback refinement (only if SWAN's between-cell mixture proves unacceptable in
     accept): our own spectrum-mixture at 1-km points — same no-mixing guarantee, more
     code. The cross-cell train-matching idea is DROPPED.
   Acceptance: a test built from the REAL misaligned corridor values recorded above; the
   west-side edge input must contain a distinct ~10 s west lobe; the served list must show
   a real ~10 s west train (not a fabricated 7 s one) and the SSE train, compared against
   the buoy tables at matched time.
2. **Re-measure the secondary losses after that lands.** The 35-frequency-slot ceiling and
   the assigned ±15° directional spread still merge genuinely close same-family trains
   (the 13.7 s / 11.0 s same-direction pair). Whether that residual justifies a costlier
   resolution increase is a decision to make AFTER the slot fix, with fresh comparisons —
   much of what looked like a resolution problem may have been slot-mixing.
3. **Freshness guard (Item 0)** — the stale-data half of the original symptom; repaired,
   follow-ups tracked there.
4. **Label taxonomy:** confirm the three display categories (Groundswell ≥12.5 s / Swell
   10–12.5 s / Wind Swell <10 s) — once a true ~10 s west swell is served it will display
   as "Swell," a label the card has likely never shown.

---

## Item 2 — The three headline numbers should be ranges, but show single values

**What you reported:** Swell Height should be a range across all surfable swells (5 seconds
or longer); Breaking Face Height should be the lowest-to-highest across the best-surf
stretch of beach; Period should also be a range across surfable swells. All three showed a
single number.

### What's actually going on

The screenshot of your card matched the live data exactly, and the explanation is different
for each of the three numbers:

1. **Swell Height — working as designed, honestly.** The card does display a range when
   there is one. At the hour it was showing, only ONE swell qualified as surfable (the
   14.5 s groundswell; both wind swells were under 4 seconds). Lowest = highest = one
   number. At an earlier hour of the same forecast, two swells qualified and the served
   range was a real 0.25–1.73 ft. Nothing is broken here.
2. **Breaking Face Height — the card is wired to the wrong number. This is the real
   defect.** There are TWO "face height range" measurements on the server:
   - the one the card currently reads: the spread across *swell trains* (each train's
     average breaking face height, lowest to highest). When one swell dominates the break —
     most days — this collapses to a single number, permanently.
   - the one that matches YOUR definition: the spread across the *best-surf strips of
     beach* (the strips whose surf stands clearly above the beach average — statistically,
     more than 0.75 standard deviations above it). That measurement is already computed and
     served (`modelSurfHeightMin`/`Max`), and at the very hour of your screenshot it held a
     real range: 3.4–3.6 ft. The card just isn't reading it.
3. **Period — a range was never built.** The server sends one combined period (weighted by
   each swell's energy), by the Aug 8 design decision. No minimum/maximum period fields
   exist anywhere. Your range expectation is a new requirement, not a bug.

One more thing found while reading this code: the "is it surfable?" rule has a quiet
fallback — **if no swell qualifies, it includes everything, chop and all**, rather than
showing nothing. On a junk day, the "surfable range" could quietly be built out of
3-second wind chop.

### Recommendation

**RULED (operator, 2026-08-10 chat) — Item 2 is now fully specified for the fix round:**

1. **Breaking Face Height range = `modelSurfHeightMin`/`modelSurfHeightMax`** (the
   best-surf-strip pair). RULED yes. Pure display rebind — the fields are already served.
   The old per-swell pair (`faceHeightMinFt`/`faceHeightMaxFt`) loses its only display
   consumer; retire it from the card, and remove it from the served response in the same
   change unless something else is found consuming it.
2. **Period must NEVER be a combined/averaged number — "that is not how the physics
   works" (operator, verbatim).** The energy-weighted `combinedPeriodS` is REJECTED:
   periods of separate wave trains do not combine. Build a true RANGE instead: new served
   fields `periodMinS`/`periodMaxS` = lowest/highest peak period across the surfable
   swells, and the card's Period shows that range (single number only when min = max, the
   same collapse rule as the other ranges). `combinedPeriodS` is retired — added only
   yesterday, and this card was its sole consumer.
3. **Eligibility fallback when NO swell qualifies: keep as-is** (operator: fine). The
   existing fall-back-to-all-components behavior stands.
4. **Swell Height stands as designed** — the honest collapse to one number when only one
   swell is surfable.
5. Fix-round hygiene, no ruling needed: the 5-second surfable threshold is written in two
   separate places; make it one shared definition so they can't drift apart.

---

## Item 3 — Surf score card: redundant text at the bottom

**What you reported:** remove "The score is a weighted…" from the bottom of the card; it's
already in the info-icon help (you checked).

### What we found

Confirmed exactly. It's one translation entry ("The score is a weighted geometric mean of
the five factors…") rendered in two places: the card footer (`SurfingTab.tsx:2105-2109`)
and the info-icon popup (same file, :384-386).

### Recommendation

Delete the footer block. Keep the popup and the translation entry untouched. One-line
change, ready for the fix round, no decisions needed.

---

## Item 4 — Beach profile: the second break isn't marked, and the impact zone is wrong

**What you reported:** the two wave bumps on the chart sit roughly where the real breaks
are, but only the outer one is marked as breaking — the inner beach break really does break
and gets nothing. You asked whether the breaking threshold needs changing. Also the impact
zone needs redefining: it should be where waves actually crash down onto the water, it
should come from the primary surf line only (not a spread across all 162 lines), and the
swash — the water running up the sand — must not be part of it.

### What's actually going on

The two symptoms turned out to be **one defect**, and it's confirmed both in the code and
in the live data:

- **How break markers work:** walking shoreward along the line, the model marks "breaking
  has started" when the breaking fraction rises past 5%, and only closes the zone — and
  only THEN writes the break marker — when the breaking fraction falls back below 2%. One
  marker per zone, placed where the wave was losing the most energy.
- **The defect:** on your beach, the breaking fraction never drops below 2% between the
  outer break and the sand. So the outer break and the beach break get glued together into
  ONE long zone → one marker (the outer one), and the beach break gets nothing — no matter
  what the thresholds are.
- **The same glue breaks the impact zone.** The impact zone is supposed to stop either
  where the whitewater energy has decayed away or at the next break. With no second break
  ever marked, there's nothing to stop it — the live data shows a single "impact zone"
  running 262 m → 19.5 m from the waterline, ending in knee-deep water, with the foam band
  continuing past the waterline **onto the sand**. That's the too-wide pink bar you see.
- **Your all-lines hypothesis is ruled out:** the chart already uses ONE line (the primary
  surf line, #44 of 162). Nothing is being blended across lines. The width problem is
  purely the zone definition.
- **A caution before touching thresholds:** at the hour we sampled, the depth profile the
  model was given is a smooth, featureless slope — **no inner sandbar at all** — and the
  modeled wave height decays smoothly after the outer break with no second peak. On that
  profile, NO threshold setting could produce a second break. So the question isn't just
  "tune the numbers" — it's also "does our depth data actually contain the real inner
  bar / low-tide step that makes the beach break happen?" Our profiles come from a
  government seafloor survey dataset and get mathematically smoothed; sandbars also move
  season to season.
- Smaller things found along the way: the chart's own documentation and the code disagree
  about how much whitewater decay ends the impact zone (50% in one place, 5% in the other);
  one of our internal self-checks on whitewater energy accounting fires dozens of times per
  model run (known, noisy, same subsystem); and the weird "-10492" number on the chart's
  left edge is just two axis labels ("-10" elevation and "492" distance) overlapping at
  small card sizes.

### Recommendation

**RULED (operator, 2026-08-10 chat) — the measure-first plan above is SUPERSEDED; Item 4 is
specified as follows:**

1. **Bathymetry investigation: DROPPED.** Operator explicitly does not care about the
   depth-profile question. No depth-data work in this item.
2. **The breaking threshold becomes operator-ADJUSTABLE.** The onset threshold that decides
   where a break registers (today a fixed 5% breaking-fraction constant) becomes a
   configuration setting, default = today's value. The operator tunes it against reality
   (cam) rather than us deriving it.
3. **The impact zone is REDEFINED as a fixed-width crash band.** Operator, in substance:
   the break zone is where the wave CRASHES, not where it produces whitewater; the crash
   happens in one place; make the zone a fixed distance and stop measuring whether the wave
   keeps breaking. A surfer needs to know where to paddle out behind — not how long the
   broken wave rolls. So: per registered break point, the published impact zone = the break
   location plus a FIXED distance shoreward. The whitewater-decay termination, the
   5%-vs-50% question, and all "is it still breaking" logic leave the zone definition
   entirely. Open parameter for dispatch: the fixed distance value — proposal: ship a
   sensible default and make it adjustable alongside the threshold knob, so both get tuned
   the same way. The earlier safety ruling stands: the band never crosses the waterline
   (swash never included).
4. **Dependency the knob needs, included in the ruled change:** today a break marker is
   only written when breaking CEASES — which is exactly why the beach break gets no marker
   even though waves crash there, and why lowering the threshold alone could not fix it.
   Marker detection therefore decouples from the stopped-breaking machinery: each distinct
   crash point (a local peak of energy loss above the threshold) gets its own marker, and
   each marker gets its fixed crash band. This is what makes the second break appear and
   makes the threshold knob do what the operator expects.
5. The internal wave-transformation physics (including its whitewater-energy bookkeeping)
   is NOT touched — only the published break markers and the published zone definition
   change. The noisy internal self-check (invariant 11) stays a tracked separate item.
6. **Quick display fixes, unchanged:** the overlapping axis labels ("-10492"); and one look
   at the flat ankle-depth profile segment landward of the waterline.

---

## Item 5 — Surf height map: too-big cells, blocky photo, smoothing, attribution, size

**What you reported:** registration is closer, but (1) the colored strips got bigger — not
wanted; (2) smooth the display across strips like a radar image so single-line quirks
don't show; (3) the aerial photo loads absurdly low-resolution; (4) remove the "USGS
National Agricultural…" text — nothing below the legends; (5) make the card a standard 4-
wide by 2-tall box with a scroll bar, plus a chevron to expand/compact it, so it stops
pushing the surf forecast off the bottom of the page.

### What's actually going on

- **This card's sign-off was already struck last night** for exactly your first and third
  complaints (plus an unresolved doubt about photo-to-data alignment). The session record
  from last night says the next session must FIRST finish the alignment check — project one
  known landmark (the pier base) through both the data drawing and the photo drawing and
  compare the numbers — before any further fixes. That's still the pending starting point.
- **Why the strips got bigger:** last night's fix made the whole drawing use one true
  ground scale (so a meter is a meter in every direction — that rule is now written into
  the design manual and stays). Side effect: strip height went from a fixed screen size to
  true 10-meter ground pitch, about 3× taller on screen. Strip size now depends entirely on
  how much ground the picture frames — frame more ground, strips shrink, and the
  one-true-scale rule is preserved.
- **Why the photo is blocky:** the code assembles the background from map-photo squares and
  caps itself at 4 squares per side. With the current framing that cap forces it down to a
  zoomed-out square size, then stretches it up. The underlying imagery (government aerial
  photography, ~0.6–1 m per pixel) is plenty sharp — we're just not asking for it.
- **The fix for both is the same framing change** the strike record already proposed: widen
  the frame toward the pier tip (more ground → smaller strips → and per-pixel demand drops)
  and raise the 4-square cap so the photo can load at proper sharpness.
- **Attribution text:** today's imagery (CONUS) is public-domain government photography —
  no legal requirement to credit it on the card face. BUT the same code path shows a
  different provider (ESRI) outside the continental US, and that one's terms DO require
  attribution. So: safe to clear the card face, as long as the credit can still appear
  somewhere (the info icon). Note: there's a second line of text below the legends too (a
  note about display smoothing) — "nothing below the legends" taken literally removes it as
  well; confirm that's what you want.
- **Sizing:** the dashboard's card grid already has exactly the notion you asked for —
  "4x2" is a full-width, double-height card — and a ready-made fullscreen
  expand/close control already exists and is used by another card. One nuance: the existing
  control opens the card as a fullscreen overlay (a pop-over), not an in-place grow within
  the page. Confirm which you want; the overlay is nearly free, in-place growing is new
  work that shoves the layout around.
- Found along the way: the design manual's list of marine cards is missing this card
  entirely — will be fixed with the doc-sync when this lands.

### Recommendation

1. **Alignment check first** (finish the strike record's pending check; turn it into an
   automated test so alignment can never silently drift again).
2. **One framing change** — wider frame + higher square cap — with acceptance criteria:
   strips at or below their pre-change on-screen size, photo sharpness around 1.5 m per
   pixel or better, landmark alignment test passing.
3. **Smoothing: display-only.** Blend the colors smoothly between adjacent strips (like a
   radar mosaic); leave every underlying number untouched, and never paint color where
   there's no data.
4. **Attribution: move it into the info icon, don't delete it outright** — needed for the
   non-CONUS imagery case. Confirm whether the smoothing note below the legends goes too.
5. **Size: full-width double-height with internal scrolling, plus the existing
   expand control.** **RULED (operator, 2026-08-10): the fullscreen overlay is fine** —
   reuse the existing overlay component (chevron in the card header opens the card
   fullscreen; Escape/close compacts it back). No in-place grid expansion.
6. Update the two manuals (design + dashboard) in the same round.

---

## Item 6 — Main map sometimes missing layers

**What you reported:** the main map sometimes doesn't load all its layers. Your screenshot:
an entirely gray map — but with street names and the numbered location pin drawn on top of
the gray.

### What's actually going on

The map is drawn as three separate layers: the base map image, a street-names overlay, and
the markers. Your screenshot shows the base layer missing while the other two loaded —
and the code review found two concrete ways that happens:

1. **A failed map image is silently invisible.** There is no error handling at all on the
   map image layers — no retry, no "map failed to load" message. If the image server has a
   hiccup, you get exactly what you photographed: silent gray.
2. **A theme change can knock out just the base layer.** The base layer is torn down and
   rebuilt whenever the page's light/dark theme resolves or changes — but the street-names
   layer isn't. In the sunrise/sunset auto-theme mode, the page first guesses the theme,
   then corrects itself moments later when the sun times load. That correction rebuilds the
   base layer alone at a vulnerable moment, while the labels layer keeps its already-loaded
   images. That produces precisely "labels and pins, no map."

Also noted: switching between the overview map and the detail view rebuilds the entire map
from scratch each time, multiplying the vulnerable moments.

### Recommendation

All straightforward display work, no decisions needed:

1. Add proper error handling to every map layer: a few retries, then a visible "map imagery
   failed to load — retrying" state. Never silent gray.
2. Make theme changes rebuild the layers together (or wait until the theme has settled
   before creating the map) so one layer can't be rebuilt without the others.
3. Before closing, reproduce it once in a browser with network logging to confirm which of
   the two mechanisms is the common one in practice.

---

## Appendix — where things live (for the fix round)

| Topic | Place |
|---|---|
| Swell list served to the card | marine repo `endpoints/surf.py:1507-1518`; labels assigned in `services/swan_spectral.py:50-61` |
| WaveWatch III field ceiling (3 swells + wind sea) | `services/ww3_partition_fields.py:183-196` |
| Headline ranges (current + best-surf-strip pair) | `endpoints/surf.py:498-582`; `services/surf_1d_pipeline.py:2352-2396` |
| Swell-conditions card render | dashboard `SurfingTab.tsx:1897-1901, 2115-2292` |
| Score-card footer to delete | `SurfingTab.tsx:2105-2109` |
| Break start/stop rules (5% / 2%) and marker placement | `services/surf_1d_analytical.py:1473-1618` |
| Impact/foam zone construction | `services/surf_1d_analytical.py:2267-2420` |
| Beach profile serving (one line, #44) | marine repo `endpoints/beach_profile.py:364-384, 694-833` |
| Heat map scale, photo squares, attribution | dashboard `HeatMapCard.tsx:630-652, 491-569, 1771-1783` |
| Card grid sizes + existing fullscreen control | `src/components/ui/card.tsx:31-58`; `src/components/ui/chart-fullscreen.tsx` |
| Main map layers | dashboard `src/components/marine/LocationMap.tsx` |
| Strike record for the heat map card | meta repo commit `30f2699`, recorded in the L1 plan |
| Live-data snapshots used above | session scratchpad `surf-bundle.json`, `surf-profile.json`, `surf-bundle-2.json` |
| Swell-train trace artifacts (Item 1) | scratchpad `TABLE_DWR_1.txt` (SWAN's per-hour train table, 19:24Z run) + `B_S_0047.txt` (the decomposed edge-input spectrum); WW3 grid probe values recorded in the Item 1 text; edge-building code `services/boundary_reconstruction.py` (35 frequency slots; adaptive peak-narrowing at :524-601) |
