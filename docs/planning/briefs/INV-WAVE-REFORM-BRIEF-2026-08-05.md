# INV-WAVE-REFORM BRIEF — why our broken waves never back off, and what fixing it takes

**Identity:** read-only investigation, operator-ordered 2026-08-05 in chat ("Yes that is
what needs to happen") after the Round Z audit established the mechanism. Lead:
coordinator. You: investigator (read-only; findings only; NO code changes anywhere).

## The established facts (do not re-derive; verify citations if you doubt them)

- Real HB surf: waves break on the outer bar, STOP breaking across the deeper trough
  (the wave "backs off"/reforms), then break again inshore. The double break is the norm
  at this beach (operator ground truth).
- Our 1D model: once breaking starts, published Hs stays pinned at exactly gamma*d
  (0.73*depth) from the outer break to the waterline on ~2/3 of the pier's 162 transects
  (Round Z audit, computed with the deployed code on the real CUDEM profiles). The
  modeled wave never drops BELOW the breaking ceiling, so it never stops breaking, so no
  second break onset exists for detection on those transects — at ANY detector setting.
- The trough relief at this spot is real but modest (bar-to-trough depth difference
  ~0.03-0.3 m).

## Your questions

1. **Where exactly does our code hold Hs at the ceiling?** Trace the post-breaking
   treatment in `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/
   surf_1d_analytical.py` (`run_1d_analytical` — the saturation clamp, any
   breaking-dissipation term, any roller-energy model) and name file:line for each
   mechanism that prevents Hs from decaying below gamma*d in deepening water. Also
   establish whether SurfBeat blending (`_blended_hs_m` in endpoints/beach_profile.py /
   the pipeline) masks or preserves any decay the 1D kernel produces.
2. **What is the standard published treatment?** The classic breaking-decay models
   (Dally-Dean-Dalrymple 1985 and successors) let a broken wave decay toward a LOWER
   stable height (stable-wave coefficient Gamma ~0.35-0.4 * depth) and CEASE breaking
   when it reaches it — which is exactly the "backing off" that creates reform + second
   break. Also read what SWAN itself does for depth-induced breaking dissipation —
   LOCAL manual ONLY: docs/reference/swan-user-manual.txt (do NOT web-search SWAN
   behavior; general surf-zone literature via WebSearch is allowed for the
   Dally-family constants if needed).
3. **Quantify the payoff.** Implement NOTHING in the repo — but you may write a
   THROWAWAY local script (scratchpad only, never committed) that mimics a
   stable-height reform rule on top of the real transect profiles
   (the spot cache is on librewxr at /etc/weewx-clearskies/spot_profiles/
   huntington-city-beach-pier.json; a local copy exists at the session scratchpad as
   hb-spot-profile.json) to estimate: with a Dally-type "breaking ceases at
   Gamma*d" rule, how many of the 162 transects show a genuine double break at
   2 m / 14-16 s SW? Report the number for Gamma = 0.35 and 0.40.
4. **Options + costs.** For each viable fix (e.g., add stable-height breaking-cessation
   to the 1D kernel; alternatives you find in the code's own structure), state: which
   functions change, whether the change is formula-level (it is — say so plainly),
   what new constants appear, what guards/KATs it needs, and the risk to currently-good
   outputs (face heights, zones, foam-to-waterline all key off the same Hs profile —
   what moves?).

## Rules

- Read-only everywhere. No commits, no deploys, no edits inside any repo. Throwaway
  analysis scripts live in your scratchpad only.
- Plain English in your report: no invented vocabulary; every technical term defined at
  first use. The operator reads this directly.
- Every claim cites file:line, manual section, or your script + its output.
- Report via SendMessage to "main": (1) the mechanism trace, (2) the standard treatment
  summary, (3) the quantified payoff table, (4) options with costs and risks, (5) your
  recommendation. The operator decides; you and the lead do not.
