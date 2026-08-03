# Research Report: Is 40 m a defensible SWAN nest resolution for point/headland/bay surf breaks?

> Produced by a bounded web-research agent dispatched 2026-08-03 (decision item 7 follow-up,
> operator request: "there has to be some guidelines as to what grid resolutions should be used
> to model these types of features"). Saved verbatim by the coordinator.

**Bottom line up front:** 40 m sits *inside* the published range for nearshore spectral-wave transformation modeling (30–300 m per USACE guidance) and is finer than operational surf-forecast practice (NOAA NWPS bottoms out at 500 m). But dedicated surf-break studies that try to resolve the break itself use 100 m SWAN only to deliver boundary conditions, then drop to 2–25 m (often phase-resolving) for the break. A citable published cells-per-feature rule exists — Deltares says **5–10 grid points across a relevant bathymetric feature** — which is *stricter* than the project's unsourced 4–5-cell rule. At 40 m that means reliably resolving features ≳200–400 m: the gross headland/point scale of most classic breaks, but not the 50–150 m "wedge/focus" components that actually control surf quality.

## §1 — Published resolution practice

| Source | Model | Resolution | Feature / context | Citation |
|---|---|---|---|---|
| USACE ERDC/CHL CHETN-I-64, J.M. Smith, Sept 2001, "Modeling Nearshore Wave Transformation with STWAVE" | STWAVE (phase-averaged, SWAN-class) | **"Transformation-scale grid resolution is of the order of 100 to 1,000 ft (30–300 m)"** for bathymetry causing refraction/shoaling/breaking; separately, phase-resolving models need 8–10 cells per *wavelength* | General nearshore transformation guidance — closest thing to official US agency doctrine | [DTIC PDF](https://apps.dtic.mil/sti/tr/pdf/ADA588527.pdf) (403 for direct fetch; numbers via search index + [tpub mirror](https://coastalengineering.tpub.com/chetn-i-64/chetn-i-640001.htm)) — **published** |
| NOAA Nearshore Wave Prediction System (NWPS), operational | SWAN (+ WW3 boundary) | **1.8 km down to 500 m** nearshore | Operational US coastal forecast grids for all WFOs — no attempt to resolve individual surf breaks | [polar.ncep.noaa.gov/nwps](https://polar.ncep.noaa.gov/nwps/) — **published, fetched directly** |
| Weppe, S. et al. 2019, Australasian Coasts & Ports, "Modelling Surf Break Wave Mechanics with SWASH — Mangamaunu Point Break (Kaikōura, NZ)" | SWAN (downscaling hindcast) + SWASH (phase-resolving) | SWAN 39-yr hindcast at **100 m** to characterize offshore conditions; the break itself at **2 m** SWASH (1400×900 cells ⇒ 2.8×1.8 km domain) | A real point break, modeled for consenting/impact purposes | [PDF](https://ref.coastalrestorationtrust.org.nz/site/assets/files/10177/53-1649_weppe_finalpaper.pdf) — **published, text extracted** |
| eCoast / Environment Southland, "Surf Breaks of Regional Significance: Southland" | SWAN | SWAN used for swell-corridor / transformation zone offshore of breaks (grid numbers in PDF; direct fetch blocked, 403) | Regional surf break significance assessments | [es.govt.nz report](https://www.es.govt.nz/repository/libraries/id:26gi9ayo517q9stt81sd/hierarchy/environment/coast/documents/Surf%20Breaks%20of%20Regional%20Significance-%20Southland%20-%20Report.pdf) — **published, resolution unverified** |
| Deltares, Delft3D Modelling Guidelines, "App1 – grid & bathymetry" | Delft3D-FLOW/WAVE (SWAN engine) | Rule of thumb: **"5–10 grid points should cover bathymetric and geographical features"** (features relevant to the problem only) | Generic grid-design guidance from SWAN's co-developing institute | [Deltares public wiki](https://publicwiki.deltares.nl/pages/viewpage.action?pageId=6946846) (page now login-walled; wording confirmed via search index twice) — **published** |
| USACE ERDC/CHL CHETN-IV-76 (2010), CMS-Wave grid nesting | CMS-Wave | **100 m** high-resolution nests (~50 km² each) | Complex nearshore bathymetry/shoreline, Rhode Island south shore | [DTIC PDF](https://apps.dtic.mil/sti/pdfs/ADA524888.pdf) — **published** |
| NZ "Surf Break Research" programme (MetOcean Solutions / eCoast); Scarfe et al. 2009 Aramoana modeling | SWAN + finer models | Detailed studies at 7 NZ breaks; pattern: SWAN for transformation, finer/phase-resolving for the break | Point, bar, and beach breaks | [surfbreakresearch.org](https://surfbreakresearch.org/); [Scarfe review, JCR 2009](https://bioone.org/journals/journal-of-coastal-research/volume-2009/issue-253/07-0958.1/Research-Based-Surfing-Literature-for-Coastal-Management-and-the-Science/10.2112/07-0958.1.full) — **published** |

Not found despite targeted searches: a SWAN-at-Mundaka resolution paper, and any surf paper that *validates* a specific phase-averaged resolution against surf quality.

## §2 — Size census of point/headland/bay breaks

**All feature scales below are map-scale estimates from well-known geography unless marked otherwise.** "Controlling feature" at two scales: (A) the gross point/headland/bay, (B) the take-off/section-controlling element (cobble delta lobe, reef bowl, bar).

| Break | Type | (A) Gross feature | (B) Controlling element | Basis |
|---|---|---|---|---|
| Mangamaunu, NZ | point | ~1 km cobble point | few hundred m delta | **Published domain**: 2.8×1.8 km SWASH box (Weppe 2019); rest map-scale |
| Rincon, CA | point (creek delta) | ~500–600 m cove | ~200–400 m cobble fan | map-scale |
| Trestles (Lowers), CA | point-ish cobble delta | ~500 m delta complex | ~150–250 m fan apex | map-scale |
| Malibu (First Point), CA | point/bay | ~800 m Malibu Point | ~200–300 m ride line | map-scale |
| Steamer Lane, CA | headland | ~200–250 m Lighthouse Pt | ~100–150 m ledge/bowl | map-scale |
| Honolua Bay, HI | bay/point | ~500–600 m bay | ~300 m reef along NE wall | map-scale |
| Mundaka, ES | rivermouth left | ~1 km estuary mouth | ~200–400 m sandbar | map-scale; ride ~400 m widely reported |
| Raglan Manu Bay, NZ | point | ~2 km three-point complex | ~300–400 m boulder delta per point | map-scale |
| Jeffreys Bay (Supertubes), ZA | point | ~2 km point | ~300–500 m Supertubes section | map-scale |
| Bells Beach, AU | reef/point in bay | ~700 m bay | ~150–250 m Bells bowl | map-scale |
| Punta de Lobos, CL | point | ~400–500 m headland | ~200–300 m ride | map-scale |
| Chicama, PE | point (multi-section) | ~4 km total | ~400–600 m per named section | map-scale |
| Noosa (First Pt–Granite Bay), AU | headland point series | ~1.5 km headland complex | ~150–300 m per point | map-scale |
| Lennox Head, AU | point | ~600 m | ~250–400 m boulder bank | map-scale |
| Whangamata Bar, NZ | bay/bar | ~500 m harbour mouth | ~200–300 m ebb delta bar | map-scale |

**Fractions (n=15):**
- By gross feature (A): **~90–95%** are ≥160–200 m ⇒ nominally resolvable at 40 m with 4–5 cells (only Steamer Lane marginal).
- By controlling element (B): **~55–65%** comfortably ≥200 m; bowls/ledges/bar apexes at ~100–250 m are marginal-to-unresolved at 40 m. Mead & Black's surf-break taxonomy ([JCR SI 29, 2001](https://www.researchgate.net/publication/284338012_Field_studies_leading_to_the_bathymetric_classification_of_world-class_surfing_breaks)) shows quality is set by mesoscale components typically smaller still (tens to ~150 m — component dimensions unretrieved, unverified).
- To cover **90% at the controlling-element scale**: ~30–35 m (4–5-cell rule) or ~15–30 m (Deltares 5–10-point rule). Defensible round number: **20–25 m**.

## §3 — Synthesis

**(a) Is 40 m inside practitioner range?** Yes — comfortably. USACE transformation guidance is 30–300 m; 40 m is at the fine end, 12–45× finer than NOAA's operational nearshore grids, and matches the ~100 m SWAN grids surf-science practitioners use for wave-climate downscaling at real point breaks. No published source calls 40 m inadequate for phase-averaged refraction at headland scale.

**(b) For resolving the break itself:** every surf-break-specific study treats SWAN-class resolution (40–100 m) as the *delivery* layer and resolves the break with a much finer model (2 m SWASH at Mangamaunu). For surf-quality detail (peel angle, sections): ≤20–25 m phase-averaged or 2–10 m phase-resolving. Compute: 40→20 m ≈ 4–8× cost; 2 m phase-resolving is a different model class. For a *forecast* system predicting whether/how refraction lights up a point — vs reproducing its surf mechanics — 40 m is defensible and ahead of operational practice.

**(c) The N-cells rule — now sourced.** Deltares Delft3D Modelling Guidelines: **"5–10 grid points should cover bathymetric and geographical features"** relevant to the problem. Same form as, slightly stricter than, the project's unsourced 4–5-cell rule — the project rule is a mildly permissive reading of a real published guideline. Under the published form, 40 m resolves features ≳200–400 m.

**Recommended ruling shape:** 40 m is defensible as-is for the stated purpose (2-D refraction at natural point/headland/bay features), resolving the gross feature at ~90% of classic breaks; it under-resolves take-off-zone-scale elements at roughly a third to half of them; ~20–25 m would be needed to claim controlling-element resolution for ~90% of the sample.

## §4 — Searches run and dead ends

11 searches; fetches: NWPS (success), Scarfe review PDF (taxonomy only, no resolutions), Weppe Mangamaunu PDF (key numbers), CHETN-I-64 (403; index + mirror), Environment Southland (403; SWAN confirmed, grids unverified), Deltares wiki (login wall; wording via index ×2). Dead ends: no SWAN-resolution paper at Mundaka/Bells/J-Bay/Malibu; Mead & Black component dimensions paywalled; no published validation of a phase-averaged resolution threshold against surf-break fidelity.
