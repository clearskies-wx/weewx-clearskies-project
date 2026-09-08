# Fishing and Boating remediation — global species matrix

**Status:** Phase 2 working evidence. This is not implementation authority and
does not validate any existing score coefficient or profile.

## Verified catalogue inventory

The current `species_by_region` catalogue contains these 90 unique selectable
labels. Every one must receive a source-species record before Phase 2 closes:

amberjack; arctic char; atlantic salmon; barracuda; bat ray; black drum; black
sea bass; bluefish; bonefish; bream; brown trout; cabezon; california
barracuda; california halibut; california sheephead; catfish; channel catfish;
cobia; cod; coho salmon; corbina; crappie; dolly varden; dungeness crab;
flounder; giant trevally; grouper; haddock; halibut; hogfish; jack crevalle;
kelp bass; king mackerel; king salmon; lake trout; landlocked salmon;
largemouth bass; leopard shark; lingcod; mahi-mahi; muskie; opaleye; pacific
bonito; pacific halibut; pacific mackerel; papio; permit; petrale sole; pike;
pollock; pompano; rainbow trout; redfish; rockfish; sablefish; salmon; sand
bass; sculpin; scup; sheepshead; shovelnose guitarfish; silver salmon;
skipjack tuna; smallmouth bass; snapper; snook; speckled trout; spotted
seatrout; steelhead; striped bass; sturgeon; summer flounder; surfperch;
tarpon; tautog; thresher shark; trevally; triggerfish; trout; tuna; wahoo;
walleye; weakfish; white croaker; white seabass; winter flounder; yellow
perch; yellowfin tuna; yellowtail; yellowtail snapper.

## Required record fields

Each source-species record must identify: scientific name; familiar aliases;
candidate group label; applicable region and fishing category; habitat/depth;
temperature treatment; tide/current, pressure, and time treatment; legal and
seasonal rule; source URL and access date; and whether a claimed value is a
direct source, derived mapping, product judgment, or missing evidence.

## Global source-species matrix index

This is the replacement catalogue index. It covers every currently selectable
label and names what setup must resolve before a scoreable choice exists. It
does **not** import `species_profiles`, their temperature bands, or any old
multiplier. `direct` means the label can start from the named source species;
`resolve` means setup must select a location-eligible member first. The full
record for either state still needs a location, habitat depth, law, and
field-level evidence classification before it becomes a completed effective
profile.

| Display label | Current region/category slots | Source species or member rule | Functional role / setup treatment |
|---|---|---|---|
| amberjack | Atlantic Southeast / bottom fish | resolve: *Seriola* member | reef/demersal; jurisdictional member selection |
| arctic char | Alaska / salmonids | *Salvelinus alpinus* | coldwater lake/river; waterbody required |
| atlantic salmon | Atlantic Northeast / salmonids | *Salmo salar*, sea-run or landlocked life history | river/anadromous; life history and law required |
| barracuda | Caribbean / inshore | *Sphyraena barracuda* | reef/nearshore |
| bat ray | Pacific Southwest / inshore | *Myliobatis californica* | shallow flats/estuarine |
| black drum | Atlantic Southeast; Gulf / inshore | *Pogonias cromis* | estuarine/demersal |
| black sea bass | Atlantic Northeast / inshore | *Centropristis striata* | reef/demersal |
| bluefish | Atlantic Northeast; Gulf; Hawaii / inshore | *Pomatomus saltatrix* where range confirms; Hawaii resolve | nearshore pelagic; Hawaii member unresolved |
| bonefish | Hawaii; Caribbean; Pacific Territories / inshore | resolve: *Albula* member by region | shallow flats/estuarine |
| bream | Atlantic Southeast; Gulf / freshwater | resolve: local sunfish member | warmwater lake/river |
| brown trout | Great Lakes / salmonids | *Salmo trutta* | coldwater lake/river |
| cabezon | Pacific Southwest; Central; Northwest / bottom fish | *Scorpaenichthys marmoratus* | reef/demersal |
| california barracuda | Pacific Southwest / inshore | *Sphyraena argentea* | nearshore pelagic |
| california halibut | Pacific Southwest / inshore | *Paralichthys californicus* | shallow flats/estuarine |
| california sheephead | Pacific Southwest / inshore; bottom fish | California sheephead, taxonomy recorded per source | reef/kelp |
| catfish | Atlantic Northeast; Southeast; Gulf; Pacific; Great Lakes / freshwater | resolve: local catfish member | warmwater lake/river |
| channel catfish | Great Lakes / freshwater | *Ictalurus punctatus* | warmwater lake/river |
| cobia | Atlantic Southeast; Gulf / inshore | *Rachycentron canadum* | nearshore pelagic/reef |
| cod | Atlantic Northeast / bottom fish | *Gadus morhua* | bottom/demersal |
| coho salmon | Great Lakes / salmonids | *Oncorhynchus kisutch* | river/anadromous or stocked-lake life history |
| corbina | Pacific Southwest; Central / inshore | California corbina, *Menticirrhus undulatus* | surf-zone |
| crappie | Atlantic Southeast; Gulf / freshwater | resolve: black or white crappie | warmwater lake/river |
| dolly varden | Alaska / salmonids | *Salvelinus malma* | coldwater lake/river |
| dungeness crab | Pacific Northwest / bottom fish | *Metacarcinus magister* | benthic invertebrate; separate legal rule |
| flounder | Atlantic; Gulf; Pacific Northwest / inshore | resolve: local flatfish member | bottom/demersal |
| giant trevally | Hawaii; Pacific Territories / inshore | *Caranx ignobilis* where range confirms | nearshore pelagic/reef |
| grouper | Atlantic Southeast; Gulf; Pacific Southwest; Hawaii; Caribbean; Pacific Territories / bottom fish | resolve: jurisdictional grouper member | reef/demersal |
| haddock | Atlantic Northeast / bottom fish | *Melanogrammus aeglefinus* | bottom/demersal |
| halibut | Pacific regions; Alaska / inshore or bottom fish | resolve: California or Pacific halibut | bottom/demersal |
| hogfish | Caribbean / bottom fish | *Lachnolaimus maximus* | reef/kelp |
| jack crevalle | Atlantic Southeast; Gulf / inshore | *Caranx hippos* | nearshore pelagic |
| kelp bass | Pacific Southwest / inshore | *Paralabrax clathratus* | reef/kelp |
| king mackerel | Atlantic Southeast; Gulf / bottom fish | *Scomberomorus cavalla* | nearshore pelagic |
| king salmon | Alaska; Great Lakes / salmonids | Chinook, *Oncorhynchus tshawytscha* | river/anadromous or stocked-lake life history |
| lake trout | Great Lakes / salmonids | *Salvelinus namaycush* | coldwater deep lake |
| landlocked salmon | Atlantic Northeast / salmonids | landlocked *Salmo salar* | coldwater lake/river |
| largemouth bass | Atlantic; Gulf; Pacific; Great Lakes / freshwater | *Micropterus nigricans* | warmwater lake/river |
| leopard shark | Pacific Southwest / inshore | *Triakis semifasciata* | shallow flats/estuarine |
| lingcod | Pacific regions; Alaska / bottom fish | *Ophiodon elongatus* | bottom/demersal |
| mahi-mahi | Hawaii; Caribbean; Pacific Territories / inshore and legacy bottom-fish slots | *Coryphaena hippurus* | deep pelagic; legacy category conflict must not change role silently |
| muskie | Great Lakes / freshwater | *Esox masquinongy* | lake/river ambush predator |
| opaleye | Pacific Southwest / inshore | *Girella nigricans* | reef/kelp |
| pacific bonito | Pacific Southwest / inshore | *Sarda chiliensis* | nearshore pelagic |
| pacific halibut | Pacific Central; Northwest; Alaska / inshore or bottom fish | *Hippoglossus stenolepis* | bottom/demersal |
| pacific mackerel | Pacific Southwest / inshore | *Scomber japonicus* | nearshore pelagic |
| papio | Hawaii / inshore | resolve: Hawaiian *Caranx* or *Carangoides* member | nearshore pelagic/reef |
| permit | Caribbean / inshore | *Trachinotus falcatus* | shallow flats/estuarine |
| petrale sole | Pacific Northwest / bottom fish | *Eopsetta jordani* | bottom/demersal |
| pike | Atlantic Northeast; Pacific Northwest; Great Lakes / freshwater | resolve: local pike member | lake/river ambush predator |
| pollock | Atlantic Northeast / bottom fish | Atlantic pollock, *Pollachius virens* | bottom/demersal |
| pompano | Atlantic Southeast; Gulf / inshore | Florida pompano, *Trachinotus carolinus* | shallow flats/estuarine |
| rainbow trout | Great Lakes / salmonids | resident *Oncorhynchus mykiss* | coldwater lake/river |
| redfish | Atlantic Southeast; Gulf / inshore | red drum, *Sciaenops ocellatus* | shallow flats/estuarine |
| rockfish | Pacific regions; Alaska / bottom fish | resolve: local *Sebastes* member | reef/demersal |
| sablefish | Alaska / bottom fish | *Anoplopoma fimbria* | deep pelagic/bottom-demersal |
| salmon | Pacific regions; Alaska; Great Lakes / salmonids | resolve: species, run, and life history | river/anadromous or stocked-lake |
| sand bass | Pacific Southwest / inshore | resolve: barred or spotted sand bass | reef/kelp |
| sculpin | Pacific Southwest / bottom fish | Southern California alias: California scorpionfish | reef/demersal |
| scup | Atlantic Northeast / inshore | *Stenotomus chrysops* | bottom/demersal |
| sheepshead | Atlantic; Gulf; Pacific Central / inshore or bottom fish | Atlantic sheepshead where range confirms; Pacific resolve | reef/demersal |
| shovelnose guitarfish | Pacific Southwest / inshore | California shovelnose guitarfish; taxonomy per source | shallow flats/estuarine |
| silver salmon | Alaska / salmonids | coho, *Oncorhynchus kisutch* | river/anadromous |
| skipjack tuna | Hawaii; Pacific Territories / inshore | *Katsuwonus pelamis* | deep pelagic |
| smallmouth bass | Atlantic Northeast; Pacific Northwest; Great Lakes / freshwater | *Micropterus dolomieu* | warmwater lake/river |
| snapper | Atlantic Southeast; Gulf; Hawaii; Caribbean; Pacific Territories / bottom fish | resolve: jurisdictional snapper member | reef/demersal |
| snook | Atlantic Southeast; Gulf; Caribbean / inshore | common snook, *Centropomus undecimalis*, only where range confirms | shallow flats/estuarine |
| speckled trout | Atlantic Southeast; Gulf / inshore | spotted seatrout, *Cynoscion nebulosus* | shallow flats/estuarine |
| spotted seatrout | Atlantic Southeast; Gulf / inshore | *Cynoscion nebulosus*; alias of speckled trout | shallow flats/estuarine |
| steelhead | Atlantic Northeast; Pacific; Alaska; Great Lakes / salmonids | migratory *Oncorhynchus mykiss* | river/anadromous |
| striped bass | Atlantic Northeast; Pacific Central; Northwest / inshore | *Morone saxatilis* where local range/stock confirms | estuarine/nearshore |
| sturgeon | Pacific Northwest / inshore | resolve: local sturgeon member | river/estuarine; legal status first |
| summer flounder | Atlantic Northeast / inshore | *Paralichthys dentatus* | bottom/demersal |
| surfperch | Pacific Southwest; Central; Northwest / inshore | resolve: local Embiotocidae member | surf-zone |
| tarpon | Atlantic Southeast; Gulf; Caribbean / inshore | *Megalops atlanticus* | shallow flats/estuarine |
| tautog | Atlantic Northeast / bottom fish | *Tautoga onitis* | reef/demersal |
| thresher shark | Pacific Southwest / inshore | resolve: local *Alopias* member | nearshore pelagic |
| trevally | Hawaii; Pacific Territories / inshore | resolve: local *Caranx* or *Carangoides* member | nearshore pelagic/reef |
| triggerfish | Gulf / bottom fish | resolve: gray or other local triggerfish member | reef/demersal |
| trout | Atlantic; Pacific; Alaska; Great Lakes / freshwater or salmonids | resolve: local trout member and life history | coldwater lake/river |
| tuna | Hawaii; Caribbean; Pacific Territories / legacy bottom-fish slots | resolve: named tuna member | deep pelagic; legacy category conflict |
| wahoo | Hawaii; Caribbean; Pacific Territories / legacy bottom-fish slots | *Acanthocybium solandri* | deep pelagic; legacy category conflict |
| walleye | Atlantic Northeast; Pacific Northwest; Great Lakes / freshwater | *Sander vitreus* | warmwater lake/river |
| weakfish | Atlantic Northeast / inshore | *Cynoscion regalis* | estuarine/nearshore |
| white croaker | Pacific Southwest / inshore | *Genyonemus lineatus* | surf-zone/nearshore |
| white seabass | Pacific Southwest; Central / inshore | *Atractoscion nobilis* | nearshore pelagic |
| winter flounder | Atlantic Northeast / inshore | *Pseudopleuronectes americanus* | bottom/demersal |
| yellow perch | Great Lakes / freshwater | *Perca flavescens* | coldwater/warmwater lake role by waterbody |
| yellowfin tuna | Hawaii; Pacific Territories / inshore | *Thunnus albacares* | deep pelagic |
| yellowtail | Pacific Southwest; Central / inshore | California yellowtail; taxonomy per current source | nearshore pelagic |
| yellowtail snapper | Caribbean / bottom fish | *Ocyurus chrysurus* | reef/demersal |

Phase 4 deletes the old name-keyed `species_profiles` structure and its neutral
default. The source-member matrix and effective-profile resolver replace it;
none of the removed values is copied into the replacement.

## Aliases and practical-group names

For every exact source-species row not named below, the displayed label is also
its candidate practical-group name and it has no additional alias. The following
rows need explicit handling before setup decides whether a group can collapse:

| Display label | Alias or member rule | Candidate practical-group name |
|---|---|---|
| california barracuda | Pacific barracuda | California barracuda |
| california sheephead | distinct from Atlantic sheepshead | California sheephead |
| corbina | California corbina | California corbina |
| halibut | California halibut and Pacific halibut are separate members | Halibut only after complete-profile comparison |
| king salmon | Chinook salmon | King salmon |
| silver salmon | Coho salmon | Silver salmon |
| coho salmon | Silver salmon in Alaska; life history still matters | Coho salmon |
| landlocked salmon | landlocked Atlantic salmon, distinct from sea-run life history | Landlocked salmon |
| rainbow trout | resident *Oncorhynchus mykiss*, distinct operationally from steelhead | Rainbow trout |
| steelhead | migratory *Oncorhynchus mykiss*, distinct operationally from rainbow trout | Steelhead |
| speckled trout | spotted seatrout, *Cynoscion nebulosus* | Spotted seatrout only if eligible members and profiles match |
| spotted seatrout | speckled trout, *Cynoscion nebulosus* | Spotted seatrout only if eligible members and profiles match |
| redfish | red drum, *Sciaenops ocellatus* | Redfish |
| sculpin | Southern California recreational use means California scorpionfish | Sculpin |
| amberjack | member must be selected from the location's managed *Seriola* set | Amberjack only after complete-profile comparison |
| bonefish | Caribbean and Hawaiian/Pacific members differ | Bonefish only after complete-profile comparison |
| bream | local sunfish member required | Bream only after complete-profile comparison |
| catfish | local catfish member required | Catfish only after complete-profile comparison |
| crappie | black and white crappie require member selection | Crappie only after complete-profile comparison |
| flounder | local flatfish member required | Flounder only after complete-profile comparison |
| grouper | jurisdictional member required | Grouper only after complete-profile comparison |
| papio | Hawaiian/Pacific *Caranx* or *Carangoides* member required | Papio only after complete-profile comparison |
| pike | local pike member required | Pike only after complete-profile comparison |
| pollock | Atlantic pollock in the Northeast; no cross-region substitution | Pollock |
| rockfish | local *Sebastes* member required | Rockfish only after complete-profile comparison |
| salmon | source species, run, and life history required | Salmon only after complete-profile comparison |
| sand bass | barred and spotted sand bass require member selection | Sand bass only after complete-profile comparison |
| sheepshead | Atlantic and California meanings must not mix; Pacific Central remains unresolved | Sheepshead only after complete-profile comparison |
| snapper | jurisdictional member required | Snapper only after complete-profile comparison |
| sturgeon | local sturgeon member and legal status required | Sturgeon only after complete-profile comparison |
| surfperch | local Embiotocidae member required | Surfperch only after complete-profile comparison |
| thresher shark | local *Alopias* member required | Thresher shark only after complete-profile comparison |
| trevally | local *Caranx* or *Carangoides* member required | Trevally only after complete-profile comparison |
| triggerfish | local triggerfish member required | Triggerfish only after complete-profile comparison |
| trout | source species and life history required | Trout only after complete-profile comparison |
| tuna | named tuna member required | Tuna only after complete-profile comparison |
| yellowtail | current California taxonomic identity must be retained from the selected source | Yellowtail |

This table does not suppress a label. It tells setup when it must return one
fully disclosed source member or several separate practical choices rather than
pretending that a broad familiar name describes one fish.

## Regional functional-fallback matrix

Every row in the source-species matrix resolves through one of these roles only
after setup has identified the applicable region, member species, habitat depth,
and jurisdiction. “Source evidence” means the source-species row provides that
factual input. “Plan judgment” means the remediation plan already fixed the
rule. “Missing evidence” means research found no defensible score value; it is
never a value copied from the deleted code. This table is the profile matrix
used by the future resolver, not an optional narrative.

| Functional role | Habitat/depth | Temperature suitability | Tide/current suitability | Pressure treatment | Time treatment | Seasonal/legal treatment |
|---|---|---|---|---|---|---|
| bottom/demersal | Source evidence: exact member's benthic depth | Missing evidence: needs member-specific depth-appropriate treatment | Missing evidence: no universal tide state | Plan judgment base; member sensitivity missing evidence | Plan judgment 1.00 when no documented adjustment | Source-evidence runtime legal lookup; plan judgment 1.00 when open and no documented refinement |
| reef/kelp | Source evidence: exact member's reef/kelp depth | Missing evidence | Missing evidence | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence runtime legal lookup; plan judgment 1.00 absent evidence |
| surf-zone | Source evidence: exact member's surf-zone depth | Missing evidence | Missing evidence: observations stay member/site-specific | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence runtime legal lookup; plan judgment 1.00 absent evidence |
| shallow flats/estuarine | Source evidence: exact member's flats, bay, or estuary depth | Missing evidence | Missing evidence | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence runtime legal lookup; plan judgment 1.00 absent evidence |
| nearshore pelagic | Source evidence: exact member's pelagic depth band | Missing evidence | Missing evidence | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence runtime legal lookup; plan judgment 1.00 absent evidence |
| deep pelagic | Source evidence: exact member's pelagic depth band | Missing evidence | Missing evidence | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence runtime legal lookup; plan judgment 1.00 absent evidence |
| coldwater deep lake | Source evidence: member and waterbody depth stratum | Missing evidence: real freshwater target-depth series required | Missing evidence: lake current applicability must be recorded | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence waterbody/jurisdiction lookup; plan judgment 1.00 absent evidence |
| warmwater lake/river | Source evidence: member and waterbody or reach | Missing evidence: real freshwater target-depth/reach series required | Missing evidence: river/current rule must be member and reach specific | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence waterbody/jurisdiction lookup; plan judgment 1.00 absent evidence |
| river/anadromous salmonid | Source evidence: run, life history, and reach | Missing evidence: real reach/depth series required | Missing evidence: flow rule must be member and reach specific | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence run/jurisdiction lookup; plan judgment 1.00 absent evidence |
| lake/river ambush predator | Source evidence: member and waterbody/reach | Missing evidence: real freshwater target-depth/reach series required | Missing evidence: current rule must be member and reach specific | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence waterbody/jurisdiction lookup; plan judgment 1.00 absent evidence |
| benthic invertebrate | Source evidence: exact member and benthic depth | Missing evidence | Missing evidence | Plan judgment base; sensitivity missing evidence | Plan judgment 1.00 absent evidence | Source-evidence fishery/jurisdiction lookup; plan judgment 1.00 absent evidence |

The missing-evidence core fields are deliberate gaps in the new matrix. They
are not neutral values, defaults, or a way to reintroduce `species_profiles`.
They are a mandatory research backlog. Phase 2 does not close until research
replaces every such field with documented matrix information. They do not
authorize a runtime fallback, a null score, or any other visitor-facing
behavior.

## Source register for matrix rows

The following register attaches the primary or established fisheries sources
used for the identity, range, habitat/depth, and legal fields in the matrix.
All were accessed 2026-09-06. A source establishes only the field stated here;
it does not establish a score multiplier unless the matrix explicitly records
it as source evidence or a plan judgment.

| Matrix rows covered | Source evidence |
|---|---|
| bat ray; California halibut; corbina; leopard shark; California barracuda (Pacific barracuda); Pacific mackerel (Pacific chub mackerel); white croaker; white seabass; shovelnose guitarfish; surfperch; barred sand bass; kelp bass; thresher shark | [California Department of Fish and Wildlife Surf Zone Fishes](https://wildlife.ca.gov/Conservation/Marine/Surf) — Southern California identity and surf-zone occurrence; its tide observations are taxon-specific, not a generic multiplier. Thresher shark remains a member-resolution record pending a location-appropriate *Alopias* source. |
| California sheephead; cabezon; lingcod; rockfish; sculpin; Pacific bonito; opaleye; yellowtail; Dungeness crab; petrale sole | [California marine species list](https://wildlife.ca.gov/Conservation/Marine/MLMA/Master-Plan/Species), [California ocean regulations](https://wildlife.ca.gov/Fishing/Ocean), and [Oregon bottomfish rules](https://myodfw.com/sport-bottomfish-seasons) — named West-Coast member and legal-context evidence. |
| Pacific halibut; generic halibut | [NOAA Fisheries Pacific halibut](https://www.fisheries.noaa.gov/species/pacific-halibut) and [CDFW Pacific halibut](https://wildlife.ca.gov/Conservation/Marine/Pacific-Halibut) — Pacific species identity and location-dependent law; generic `halibut` remains a setup resolution record. |
| arctic char; Dolly Varden; king salmon; silver salmon; sablefish; Alaska salmon/trout/steelhead rows | [Alaska Department of Fish and Game fish inventory](https://www.adfg.alaska.gov/index.cfm?adfg=animals.listfish&sort=scientific) and [Alaska sport-fishing regulations](https://www.adfg.alaska.gov/index.cfm?adfg=fishregulations.sport) — source identity and location/date-specific legal requirement. |
| Atlantic cod; haddock; pollock; black sea bass; scup; summer flounder; winter flounder; weakfish; tautog; Atlantic striped bass | [NOAA Fisheries Northeast multispecies groundfish](https://www.fisheries.noaa.gov/species/northeast-multispecies-groundfish), [Atlantic pollock](https://www.fisheries.noaa.gov/species/atlantic-pollock), and [Atlantic States Marine Fisheries Commission species index](https://asmfc.org/species/) — Northeast identity, habitat, and management context. |
| redfish; speckled trout/spotted seatrout; snook; Atlantic sheepshead; cobia; Florida pompano; tarpon; jack crevalle; black drum; king mackerel; bluefish; amberjack; triggerfish; Florida freshwater rows | [Florida Fish and Wildlife Conservation Commission recreational regulations](https://myfwc.com/fishing/saltwater/recreational/), [red drum rules](https://myfwc.com/fishing/saltwater/recreational/red-drum/), [snook rules](https://myfwc.com/fishing/saltwater/recreational/snook/), and [freshwater regulations](https://myfwc.com/fishing/freshwater/regulations/) — regional identity and jurisdictional legal context. |
| grouper; snapper; tuna; wahoo; mahi-mahi; bonefish; permit; barracuda; yellowtail snapper; hogfish; Caribbean snook/tarpon | [NOAA U.S. Caribbean regulations](https://www.fisheries.noaa.gov/southeast/rules-and-regulations/current-fishing-regulations-us-caribbean) and the [Caribbean Fishery Management Council Puerto Rico plan](https://caribbeanfmc.com/FMP_Island_Based_2019/EA_FMP_Puerto_Rico_Final.pdf) — member and jurisdiction requirements. |
| Hawaiian/Pacific Territory bonefish; giant trevally; trevally; papio; yellowfin tuna; skipjack tuna; Hawaii bluefish | [Hawaii DAR regulated-species scientific names](https://dlnr.hawaii.gov/dar/fishing/fishing-regulations/scientific-names-of-regulated-species/) and [NOAA Pacific Islands recreational and non-commercial fishing](https://www.fisheries.noaa.gov/pacific-islands/resources-fishing/recreational-and-non-commercial-fishing-pacific-islands) — local common-name/member and territory-specific management context. |
| lake trout; muskie; yellow perch; channel catfish; brown trout; rainbow trout; coho salmon; Great Lakes salmonids | [Michigan DNR fish species index](https://www.michigan.gov/dnr/education/michigan-species/fish-species) and [New York Great Lakes and tributaries rules](https://dec.ny.gov/things-to-do/freshwater-fishing/regulations/great-lakes-tributaries) — freshwater habitat depth and waterbody-specific legal context. |
| largemouth bass; smallmouth bass; walleye; pike; catfish; bream; crappie; trout; landlocked salmon; Atlantic salmon | [Michigan DNR fish species index](https://www.michigan.gov/dnr/education/michigan-species/fish-species), [Massachusetts freshwater fishing rules](https://www.mass.gov/info-details/freshwater-fishing-regulations), and [Maine Atlantic-salmon information](https://www.maine.gov/dmr/fisheries/sea-run-fisheries/sea-run-species/atlantic-salmon) — named-member, waterbody, life-history, and legal-context requirements. |

For multi-taxon rows, the source register proves why setup must resolve a member;
it does not silently choose one. The exact selected member, location, depth, and
jurisdiction are recorded in the effective profile at setup time.

## Quantitative research findings — not score values

The research pass found these direct observations. They belong in the matrix as
source facts, not as copied score thresholds. Each is limited to the named
species, place, water depth, life stage, or study method. None by itself proves
the Fishing formula's active/good/marginal temperature treatment, a tide/current
factor, a pressure sensitivity, a time multiplier, or a legal closure outside
the named jurisdiction.

| Source species | Direct quantitative observation | What it may establish | What it does not establish |
|---|---|---|---|
| Atlantic cod | NOAA Essential Fish Habitat material places adults and spawning adults below 10°C and at 10–150 m. | A cold bottom-dwelling habitat context. | A live selected-location score band. |
| Black sea bass | NOAA's 2025 stock snapshot identifies an 8°C winter bottom-temperature threshold for the northern subunit. | A subunit-specific ecological threshold. | A complete score profile or threshold outside that subunit. |
| Lake trout | New York lists 42–52°F preference and 48°F optimum for Lake Ontario; Michigan lists 40–55°F and 10–30 ft in cold seasons versus 100–200+ ft in summer. | Why the selected waterbody and target depth matter. | A general lake-trout score range without the real waterbody/depth series. |
| Brown trout | New York lists 54–63°F preference and 58°F optimum for Lake Ontario. A Sierra Nevada telemetry study observed 12–19.3°C occupancy in one deep pool. | Local biological observations. | A transferable score range or night multiplier. |
| Rainbow trout / steelhead | New York lists 55–65°F preference and 60°F optimum for Lake Ontario. EPA material summarizes 12–19°C preferred/optimal range. | Candidate evidence that must retain resident-versus-migratory and waterbody context. | A common resident-and-steelhead profile or a universal flow score. |
| Coho and Chinook salmon | New York lists 52–58°F preference and 53°F optimum for Lake Ontario. California/USGS material gives life-stage and reach-specific temperature/flow observations. | Run- and reach-specific evidence. | A global salmon score or an interchangeable lake/river profile. |
| Atlantic salmon | New York lists 55–65°F preference and 60°F optimum for Lake Ontario; other sources identify cooler river/spawning conditions. | The need to keep sea-run and landlocked life histories separate. | A universal Atlantic-salmon threshold or legal state. |
| Walleye | A Black Bay study used 18–22°C as optimal thermal habitat while sampling vertical profiles. | A named-waterbody thermal observation. | A universal target-depth score range. |
| Yellow perch | Ontario observations report seasonal thermal distributions; Iowa identifies 30–40 ft thermocline/bottom use in stratified lakes. | Waterbody- and season-specific depth context. | A general score band or time multiplier. |
| Channel catfish | A Nebraska river model identifies 25–31°C summer growth habitat and specific velocity/depth conditions; New Jersey material describes night feeding. | A named river/member ecological observation. | A category-wide catfish score or multiplier. |
| Largemouth and smallmouth bass | Louisiana and U.S. Forest Service material reports regional/lake temperature and depth observations. | Member- and waterbody-specific habitat context. | A nationwide score band. |
| California halibut, Pacific mackerel, Pacific bonito, corbina, kelp bass, lingcod, Pacific halibut, and sablefish | Fisheries sources provide species depth ranges and, for Pacific halibut, seasonal shallow/deep movement. | Member-specific target-depth selection. | A scoreable water-temperature range, tide/current state, pressure curve, or time multiplier. |

The research result is therefore precise: it improves source-member selection,
habitat-depth handling, and legal lookup requirements. It does not authorize a
new numerical score value. A functional profile may use these facts only in the
role they support; it must leave unsupported score fields as **missing evidence**.

Setup may collapse entries only after every score-affecting and legal field in
their effective profiles matches. Generic labels such as `rockfish`, `grouper`,
`snapper`, `trout`, `catfish`, `flounder`, `surfperch`, `salmon`, and `tuna`
remain separate/unavailable for collapse until that comparison is complete.

## Initial evidence anchors

The regional taxon/alias review in `MARINE-SURF-FISHING-RESEARCH-BRIEF.md`
§11.10 is the starting cross-reference. Its CDFW, NOAA Fisheries, Hawaii DAR,
Florida FWC, Caribbean Fishery Management Council, USGS, and Michigan DNR
links establish candidate identity, range, habitat, and management context.
They do not establish universal pressure, tide, time-of-day, or seasonal score
multipliers. Those remain explicit product judgments or missing evidence until
an individual record cites support.

## Existing-code deletion finding

The current code exposes 90 labels but contains only 73 name-keyed
`species_profiles` records. The following 17 selectable labels currently reach
the scorer's neutral default: `amberjack`,
`arctic char`, `atlantic salmon`, `bonefish`, `bream`, `crappie`, `halibut`,
`lake trout`, `landlocked salmon`, `muskie`, `pike`, `pollock`, `sablefish`,
`smallmouth bass`, `sturgeon`, `trevally`, and `triggerfish`.

Phase 4 deletes that default with the old table. Every existing selectable label
remains in scope and receives its matrix-derived direct, collapsed-group,
or geographic-functional-category effective profile. This finding does not authorize
removing, hiding, or otherwise changing the selectable list.

## Direct-profile gap review

The following labels have an exact taxon or defensible alias/life-history
meaning, but still need a researched effective profile: `arctic char`
(*Salvelinus alpinus*), `atlantic salmon` (*Salmo salar*), `lake trout`
(*S. namaycush*), `landlocked salmon` (landlocked *S. salar* life history),
`muskie` (*Esox masquinongy*), `sablefish` (*Anoplopoma fimbria*), and
`smallmouth bass` (*Micropterus dolomieu*).

`pike` and `pollock` must first resolve by region: northern pike (*E. lucius*)
is not every pike; Atlantic pollock (*Pollachius virens*) is not Alaska/walleye
pollock (*Gadus chalcogrammus*). `halibut` likewise must resolve to named
California or Pacific species before a profile is selected.

`amberjack`, `bonefish`, `bream`, `crappie`, `sturgeon`, `trevally`, and
`triggerfish` are multi-taxon labels. They remain selectable, but setup must
identify their location-appropriate source members before a complete profile is
derived. A generic label must never silently become a worldwide species.

The source review supports identity, habitat/depth, range, and legal context.
It does not support universal temperature hard stops, tide/current preference,
pressure sensitivity, time-of-day adjustment, seasonal adjustment, or numerical
multiplier for any of these labels. Those fields must be documented regional
functional product mappings or later species/location-specific evidence.

## Verified identity findings — first pass

- California Department of Fish and Wildlife's Surf Zone Fishes material
  identifies multiple surfperch species and reports different tide associations
  within that family. `surfperch` therefore remains a non-collapsible label;
  it is not a source species or a tide/current profile.
- California's marine species inventory identifies California corbina
  (*Menticirrhus undulatus*), Pacific barracuda (*Sphyraena argentea*), kelp
  bass (*Paralabrax clathratus*), barred sand bass (*P. nebulifer*), Pacific
  bonito (*Sarda chiliensis*), white croaker (*Genyonemus lineatus*), and
  California scorpionfish (*Scorpaena guttata*). The last is the local
  sport-fishing meaning of `sculpin`; that alias must not be generalized to
  unrelated sculpins.
- NOAA Fisheries identifies kelp forest habitat as important for kelp bass and
  multiple rockfish species. `kelp bass` is an exact habitat candidate, while
  `rockfish` remains a multi-species group requiring a regional member list.
- Alaska Department of Fish and Game identifies Chinook/king salmon as
  *Oncorhynchus tshawytscha*, coho/silver salmon as *O. kisutch*, steelhead /
  rainbow trout as *O. mykiss*, Arctic char as *Salvelinus alpinus*, and Dolly
  Varden as *S. malma*. King/Chinook and coho/silver are aliases, not separate
  taxa; their legal and life-history profile still remains location-specific.

- Hawaiʻi DAR identifies `ulua`/`pāpio` as multiple *Caranx* and
  *Carangoides* taxa. The catalogue's `papio` and `trevally` labels therefore
  cannot collapse to a single source species. Hawaiian bonefish / `‘ō‘io`
  identifies *Albula glossodonta* and can be an exact candidate.
- Caribbean Fishery Management Council documentation separates snapper and
  grouper complexes into multiple species and management units. Generic
  `snapper` and `grouper` require a jurisdiction-specific member list and may
  not receive one shared legal or habitat profile.
- Florida Fish and Wildlife Conservation Commission records distinct seasonal
  and possession rules for spotted seatrout by management region. `speckled
  trout` / `spotted seatrout` is one taxon candidate, but its legal-availability
  profile must be evaluated at the configured location rather than by a
  region-wide month multiplier.
- Michigan DNR identifies lake trout as *Salvelinus namaycush* and describes a
  cold, often deep-water habitat. Freshwater species require a genuine local
  freshwater depth/temperature source; an ocean profile or surface fallback is
  not evidence for that factor.

- NOAA Fisheries identifies summer flounder as *Paralichthys dentatus* and
  documents its inshore/offshore seasonal migration. `summer flounder` is an
  exact Atlantic candidate; generic `flounder` is not a substitute for it or
  for winter, southern, Gulf, California, or Pacific halibut profiles.
- Florida FWC identifies redfish as red drum (*Sciaenops ocellatus*) and
  `speckled trout` as spotted seatrout (*Cynoscion nebulosus*). Both have
  management-region-specific rules, including closures or catch-and-release
  treatment in some regions. A source species can therefore be identifiable
  while its legal score input still cannot be precomputed globally.
- NOAA and Caribbean records identify `grouper` as a multi-species family/group
  and distinguish individual snapper/grouper management units. These display
  labels remain unavailable for collapse without a location-specific source
 member list and completed effective profile.

## Complete-profile comparison contract

Setup compares the complete **effective** profile for every eligible source
species that shares a candidate familiar group label. The compared fields are:

1. source taxon and the applicable location/jurisdiction;
2. legal-availability rule and seasonal closure conditions;
3. fishing category and regional membership;
4. habitat role, target depth, and required water-source type;
5. active, marginal, good, and optimal temperature treatment;
6. tide/current states and their effective factor;
7. pressure-response treatment and effective factor;
8. time-of-day treatment;
9. seasonal treatment; and
10. every fallback level and provenance classification that supplied those
   values.

Two eligible source species collapse to one displayed practical choice only
when every field above is identical after the documented fallback order has
resolved it. A difference in one field—especially taxon, habitat depth, legal
status, temperature treatment, or fallback source—keeps the source species as
separate selectable choices. Existing fish are never removed by this rule; it
only controls whether a familiar label represents one fully matching group or
several separately explained choices.

## Effective-profile fallback order

Every existing selectable fish resolves its effective profile in this order:

1. direct source-species profile for the selected region and jurisdiction;
2. matching collapsed-group profile, only after the complete-profile comparison
   above passes;
3. geographic functional-category profile.

The geographic functional category is scoped to the selected region and fishing
category: for example, all regional rockfish, all regional bottom fish, or all
regional river salmonids. There is no general regional fishing fallback.

## Geographic group and category research packets

These packets are the permitted final fallback records. Each is tied to a
geographic area and fishing category; none is a universal fish profile. The
source-member rows above still control where a category applies.

| Geographic group or category | Source members and direct evidence | Required live/context inputs |
|---|---|---|
| Pacific Southwest surf/flats | California corbina, California halibut, shovelnose guitarfish, bat ray, and named surfperch members occupy the sandy surf, bay, estuary, or soft-bottom environments documented by [CDFW life-history material](https://wildlife.ca.gov/Conservation/Marine/Life-History-Fish). | Location-specific target depth, water-column temperature, tide/current state, and current CDFW rule. |
| Pacific Southwest reef/kelp and bottom fish | Kelp bass, California sheephead, cabezon, California scorpionfish, lingcod, and location-eligible rockfish have distinct reef/kelp or groundfish depths and legal classes in [CDFW rules](https://wildlife.ca.gov/Fishing/Ocean/Regulations/Sport-Fishing/General-Ocean-Fishing-Regs). | Exact member set, reef/depth stratum, and current area/date rule. |
| Pacific Central/Northwest bottom fish | Lingcod, cabezon, petrale sole, Pacific halibut, and the location-eligible rockfish member set are documented separately by [Oregon](https://myodfw.com/fishing) and Washington regulations. | State marine area, member, depth stratum, and current legal rule. |
| Alaska bottom fish | Pacific halibut, lingcod, sablefish, and the locally legal rockfish member set are distinct Alaska records under [ADF&G](https://www.adfg.alaska.gov/index.cfm?adfg=fishregulations.sport). | Management area, selected member, depth, date, and retention status. |
| Atlantic Northeast groundfish | Cod, haddock, Atlantic pollock, tautog, black sea bass, scup, and named flatfish records have different depth, stock, and legal context in [NOAA Northeast groundfish material](https://www.fisheries.noaa.gov/species/northeast-multispecies-groundfish). | Member, stock/area, bottom depth, and state/federal rule. |
| Atlantic Southeast and Gulf inshore | Red drum, spotted seatrout, snook where locally eligible, cobia, pompano, tarpon, black drum, sheepshead, and crevalle jack are distinct local inshore records in [FWC sources](https://myfwc.com/fishing/saltwater/recreational/). | State/federal waters, member, habitat depth, date, and local legal rule. |
| Atlantic Southeast and Gulf bottom fish | Greater amberjack, gray triggerfish, king mackerel, and jurisdictional snapper/grouper members have distinct depth and closure requirements in [NOAA Gulf rules](https://www.fisheries.noaa.gov/southeast/rules-regulations/fishing-regulations-and-seasonal-closures-gulf-america). | Exact member, reef/depth stratum, federal/state waters, and date. |
| Caribbean reef and bottom fish | The applicable island's named grouper and snapper members, yellowtail snapper, hogfish, and local reef records are governed separately by Puerto Rico, St. Croix, and St. Thomas/St. John materials. | Island, member, habitat/depth, and current territorial/federal rule. |
| Hawaiʻi and Pacific Territories pelagic | Named yellowfin, skipjack, mahi-mahi, wahoo, and locally eligible trevally members are pelagic/reef records, not generic bottom fish. [NOAA Pacific Islands](https://www.fisheries.noaa.gov/pacific-islands/resources-fishing/recreational-and-non-commercial-fishing-pacific-islands) documents distinct territorial management. | Territory or island, exact member, depth stratum, date, and legal rule. |
| Hawaiʻi deep-bottom fish | Hawaiʻi Deep 7 distinguishes six snapper members and one grouper; it cannot be a generic snapper/grouper profile. | Exact Deep 7 or local reef member, bottom depth, area, and current rule. |
| Great Lakes coldwater deep lake | Lake trout, brown trout, rainbow trout, coho, and Chinook sources identify water-column temperature and seasonal depth differences in named lakes. | Actual lake, depth-stratified temperature, life history, and lake/date law. |
| Great Lakes and regional warmwater lake/river | Largemouth bass, smallmouth bass, walleye, perch, channel catfish, pike, and muskie use materially different cover, depth, current, and season patterns. | Named waterbody/reach, exact member, target depth or flow reach, and jurisdiction. |
| River/anadromous salmonid | Chinook, coho, steelhead, Atlantic salmon, landlocked salmon, Arctic char, Dolly Varden, and locally eligible trout records differ by run, life stage, reach, temperature, and flow. | Named run, life history, reach, depth/flow, temperature, date, and law. |

The direct species row may collapse only to the matching geographic group when
every effective profile field agrees. Otherwise it collapses only to the named
geographic category above, whose record is itself researched for that area and
category. It never falls through to a generic regional fishing profile.

## Pressure, tide/current, and time research limits

The exhaustive factor review found no category-wide pressure, tide/current, or
time-of-day score rule that can be asserted for the source members in the
matrix. This is positive research evidence against filling the categories with
fishing folklore or the deleted code's values.

- A peer-reviewed review of fish angling vulnerability found no consensus that
  atmospheric pressure changes alter catchability; its available northern-pike
  test found no relationship. [Lennox et al., 2017](https://doi.org/10.1111/faf.12219)
  This does not justify assigning a zero pressure sensitivity to every fish.
- Rockfish and black-sea-bass pressure-chamber studies test rapid hydrostatic
  changes during capture, not weather-pressure trends. They are excluded from
  the Fishing pressure field.
- The Southern California corbina study found higher beach-seine abundance at
  lower incoming tides. It is a location-specific abundance observation for
  *Menticirrhus undulatus*, not an angling score factor for all surf fish.
  [CDFW Status of the Fisheries Report](https://nrm.dfg.ca.gov/FileHandler.ashx?DocumentID=65489)
- Puget Sound telemetry for lingcod, copper rockfish, and quillback rockfish
  found individual differences rather than one general tidal or daily pattern.
  [Tolimieri et al., 2009](https://www.int-res.com/articles/meps_oa/m380p229.pdf)
- The strongest Great Lakes result is a low-light association for walleye catch
  in one lake. It does not classify a time-of-day factor for every warmwater
  fish or every lake. [Shaw, Renik & Sass, 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8483380/)

Therefore, each such direct observation remains attached to its exact source
member, location, method, and limit. It may not populate a geographic group or
category score field unless research establishes the same supported treatment
for every member to which that group/category profile applies.

## Sport-fishing and sport-industry source register

These sources complement the biological and legal register. They measure
recreational catch, effort, charter outcomes, tournament results, or angler
survey outcomes. Each remains limited to its named fish, place, method, and
season; a result from one fishery is not a generic profile.

| Source member / geographic context | Sport-fishing or industry finding | Source |
|---|---|---|
| California corbina, Southern California surf | Beach-seine catch per unit of effort was higher at lower incoming tides; summer abundance was higher and winter lower. | [CDFW Surf Fish Population Study](https://wildlife.ca.gov/Conservation/Marine/Surf) |
| Barred and walleye surfperch, Southern California | Named members—not generic surfperch—had highest catch per unit of effort at slightly higher outgoing tides. | [CDFW Surf Fish Population Study](https://wildlife.ca.gov/Conservation/Marine/Surf) |
| Kelp bass and barred sand bass, Southern California | California sport-vessel and recreational survey records contain member-specific catches by 0–40 m blocks during the fishery’s June–August study period. | [CDFW saltwater bass fishery study](https://nrm.dfg.ca.gov/FileHandler.ashx?DocumentID=90973) |
| California halibut, San Francisco Bay | Angler-intercept and effort data provide fish-per-angler records; recruitment and targeting explained large catch years. | [CDFW Status of the Fisheries Report](https://nrm.dfg.ca.gov/FileHandler.ashx?DocumentID=65489) |
| Dungeness crab, Columbia River estuary | State creel interviews measure recreational catch and effort around tide-change periods; effort timing alone is not catch-success evidence. | [Oregon recreational-crab report](https://dfw.state.or.us/mrp/publications/docs/2004-05%20%20Col.R.%20crab%20final.pdf) |
| Giant trevally, Hawaiʻi | Local pole-and-line capture and acoustic tracking document member-specific depth, daily movement, and seasonal migration. | [University of Hawaiʻi ulua project](https://www.himb.hawaii.edu/ReefPredator/Ulua.html) |
| Guam shallow-bottom fishing | A transparent non-commercial creel study measured method-specific catch outcomes; its results apply to Guam members and methods, not all Pacific territories. | [Sablan, Taylor & Houk (2025)](https://doi.org/10.1016/j.fishres.2024.107180) |
| Tautog, southern Massachusetts | Rod-and-reel study measured catch per angler across depth, temperature, tide, month, and angler experience; local catch rose after water approached 10°C and was highest in October, with a weak/variable tide association. | [McNamee et al. (2018)](https://academic.oup.com/mcf/article/10/6/550/7827017) |
| Red drum, Atlantic/Gulf | Recreational survey and guide-logbook records establish regional catch-per-angler-hour, habitat/season patterns, and local sport-fishing outcomes. | [NOAA red-drum FMP](https://repository.library.noaa.gov/view/noaa/67269/noaa_67269_DS1.pdf); [Florida Bay sport-fishery analysis](https://www.aoml.noaa.gov/flbay/fish95.html) |
| Common snook, Florida Bay | Sport-fishery catch rate is documented in fish per angler-hour; local spawning-aggregation work supplies separate place/season context. | [Florida Bay sport-fishery analysis](https://repository.library.noaa.gov/view/noaa/35215/noaa_35215_DS1.pdf) |
| King mackerel, west-central Florida | Tournament angler interviews measured fish-per-line-hour alongside environmental and bait/reef variables. | [Wall, Muller-Karger & Roffer (2009)](https://pure.lib.usf.edu/en/publications/linkages-between-environmental-conditions-and-recreational-king-m-4/) |
| Summer flounder, New Jersey/southern New York | Fully observed party-boat trips found vessel/location dominated catch variation and little time-of-day effect in that fishery. | [Bochenek & Powell (2010)](https://academic.oup.com/mcf/article/2/1/412/7826900) |
| Red snapper, Gulf for-hire | Electronic captain logbooks and dockside creels give named-member recreational effort, catch, release, and depth-of-effort data. | [iSnapper Gulf trial](https://academic.oup.com/najfm/article-abstract/45/1/150/8105535) |
| Walleye, Lake Erie; smallmouth bass, Lake Erie | State sport guidance specifies named waterbody, season, depth, and light-context fishing outcomes. | [NYSDEC walleye guidance](https://dec.ny.gov/things-to-do/freshwater-fishing/places-to-fish/great-lakes-niagara-river-st-lawrence-river/lake-erie-walleye-fishing); [NYSDEC smallmouth guidance](https://dec.ny.gov/things-to-do/freshwater-fishing/places-to-fish/great-lakes-niagara-river-st-lawrence-river/lake-erie-smallmouth-bass-fishing) |
| Lake Ontario trout and salmon | Sport guidance ties named fish and water-column temperatures to targeting conditions; creel and charter reports provide observed harvest/effort. | [NYSDEC Lake Ontario guide](https://dec.ny.gov/things-to-do/freshwater-fishing/places-to-fish/great-lakes-niagara-river-st-lawrence-river/trolling-lake-ontario-trout-salmon); [Michigan creel report](https://www.michigandnr.com/publications/pdfs/DNRFishLibrary/FisheriesReports/FR049.pdf) |

All sport-fishing and sport-industry findings are evidence inputs for the
matrix. A value becomes a geographic group/category treatment only after the
same completed result has been established for every member to which the
treatment would apply.

The fallback record must name the level used for each field. It does not erase
the selected fish, its source identity, or an unavailable live input.

Functional profiles are product-role mappings, not claims that all members
share biological behavior: `bottom/demersal`, `reef/kelp`, `surf-zone`,
`shallow flats/estuarine`, `nearshore pelagic`, `deep pelagic`, `coldwater deep
lake`, `warmwater lake/river`, `river/anadromous salmonid`, and `lake/river
ambush predator`. Each mapping still requires regional habitat/depth and legal
evidence before it supplies a score factor.

## Existing Pacific-code deletion finding

The Pacific Southwest, Central, and Northwest catalogue exposes 38 unique
labels. Thirty-four old scoring records and the neutral-default path for
`halibut`, `pike`, `smallmouth bass`, and `sturgeon` are all deleted in Phase 4.
None identifies a source taxon, jurisdiction, habitat/depth, legal rule, source
URL/access date, or field-level provenance.

Accordingly, none of the existing Pacific pressure sensitivities, temperature
bands, tide/time multipliers, or seasonal multipliers transfers to the matrix.

Source review supports only the following role boundaries: Southern California
`sculpin` may mean California scorpionfish; `surfperch`, `rockfish`, `grouper`,
`flounder`, `sand bass`, `salmon`, `trout`, `pike`, and `sturgeon` are ambiguous
labels requiring regional member/taxon resolution. California and Pacific
halibut remain distinct. Dungeness crab remains selectable but has a separate
benthic-invertebrate role and legal rule. Freshwater choices require a configured
waterbody and genuine freshwater target-depth temperature source.

CDFW habitat and regulation material, NOAA Pacific halibut/lingcod material,
and Oregon marine regulations support those identity, habitat, and legal
boundaries. They do not supply numerical scoring factors.

- NOAA identifies Pacific halibut as *Hippoglossus stenolepis*, lingcod as
  *Ophiodon elongatus*, and sablefish as *Anoplopoma fimbria*. `halibut` must
  not collapse California and Pacific halibut; sablefish's adult deep-water
  habitat means its temperature/depth factor cannot borrow a shallow inshore
  profile.
- California sources identify `sculpin` in the Southern California fishing
  context as California scorpionfish (*Scorpaena guttata*), while other
  sculpins are distinct species. The selection must retain that regional alias
  meaning without treating every generic sculpin as the same profile.
- Alaska records confirm Arctic char (*Salvelinus alpinus*), Dolly Varden
  (*S. malma*), lake trout (*S. namaycush*), northern pike (*Esox lucius*),
  and rainbow/steelhead (*Oncorhynchus mykiss*) as distinct source species.
  The unprofiled Alaska/freshwater labels therefore require individual or
  functional profiles rather than the existing neutral default.

## Evidence classification and catalogue-wide audit — 2026-09-06

The local catalogue inventory was independently reproduced from
`data/species.yaml`: it has 90 unique selectable labels, 73 old profile records
scheduled for deletion, and 17 labels with no profile. The 17 are: amberjack; arctic char;
atlantic salmon; bonefish; bream; crappie; halibut; lake trout; landlocked
salmon; muskie; pike; pollock; sablefish; smallmouth bass; sturgeon; trevally;
and triggerfish. This is an evidence finding, not permission to remove or hide
any selection.

Every field in the eventual global matrix must use one of these plain-English
classifications:

| Classification | Meaning and permitted use |
|---|---|
| Source evidence | It names the exact taxon, source URL, access date, applicable place, and the specific field the source supports. |
| Derived mapping | It records the source-backed fact, the reproducible mapping, and why that mapping applies; it is never presented as a source value. |
| Plan judgment | It names the responsible approved plan rule and rationale; it is never presented as biological or legal research. |
| Missing evidence | It may not produce a scientific or legal claim. |
| Not applicable | The record explains why no replacement factor is silently supplied. |

The deleted 73 records have numerical pressure sensitivity, temperature bands,
tide/time preferences and multipliers, but none carries an exact taxon,
jurisdiction, habitat depth, legal rule, source URL/access date, or field-level
provenance. None of those values enters the matrix. The old seasonal entries are
deleted for the same reason: a spawning/migration observation is not a legal
closure or numerical seasonal multiplier.

### Global source coverage findings

The evidence pass covered the catalogue's Pacific, Alaska, Atlantic Northeast,
Atlantic Southeast, Gulf, Caribbean, Hawaii, Pacific Territories, Great Lakes,
and freshwater/salmonid slots. It establishes these source-backed boundaries:

- California's [Surf Zone Fishes](https://wildlife.ca.gov/Conservation/Marine/Surf)
  lists several distinct surfperch and documents different tide associations for
  California corbina, barred surfperch, and walleye surfperch. A global
  `surfperch` profile or an inherited tide multiplier is therefore unsupported.
- NOAA's [greater amberjack](https://www.fisheries.noaa.gov/species/greater-amberjack)
  record establishes *Seriola dumerili* as one candidate and distinguishes
  regional management. It does not authorize a worldwide `amberjack` member,
  pressure sensitivity, or score multiplier.
- Florida's [flounder rules](https://myfwc.com/fishing/saltwater/recreational/flounder/),
  NOAA Northeast groundfish material, and Pacific regulations distinguish the
  members behind `flounder`, `grouper`, `snapper`, `rockfish`, `halibut`, and
  other group labels. Setup must resolve a local eligible member before those
  labels can collapse.
- Hawai\u02bbi's [regulated-species name list](https://dlnr.hawaii.gov/dar/fishing/fishing-regulations/scientific-names-of-regulated-species/)
  shows that local `ulua`/`p\u0101pio` terms cover several taxa. Hawaiian/Pacific
  Territory `trevally` and `papio` are therefore member-resolution records, not
  universal source species.
- Government freshwater material, including Michigan's
  [lake-trout profile](https://www.michigan.gov/dnr/education/michigan-species/fish-species/lake-trout),
  records depth- and waterbody-dependent habitat. Freshwater and salmonid
  selections require an actual configured waterbody (or river reach),
  location-specific law, and a timestamped freshwater target-depth temperature.
  Ocean or surface substitutions are not evidence for these rows.

Across all regions, the source pass supports identity, aliases, geographic
availability, habitat/depth roles, and the requirement for a live
location-and-date legal check. It does **not** support the old numerical active,
good, marginal, or optimal temperature thresholds; tide/current factors;
pressure sensitivities; time-of-day multipliers; or regional-month legal
closures. These values remain missing evidence unless an approved, field-level
derived mapping or plan judgment record is added.

### Required member-resolution records

The following existing labels are not a single scoreable worldwide taxon and
must stay in the catalogue until setup has selected a location-eligible member,
waterbody/coastal area, and jurisdiction: amberjack, bonefish, bream, crappie,
flounder, grouper, halibut, pike, pollock, rockfish, salmon, snapper, sturgeon,
surfperch, trevally, triggerfish, trout, catfish, tuna, papio, and sheepshead.
This is a preservation rule: it prohibits an unsupported collapse, not the
label's availability.

### Fixed formula and functional-fallback boundary

The approved formula's exponents, pressure-change bands, tide/current levels,
and bounded time/season/solunar adjustments are plan judgments from remediation
plan §3.6.1. They are not biological source facts. A functional fallback may use
source evidence about habitat/depth only to choose a functional role; it must
record every temperature, tide/current, pressure, time, seasonal, and legal
field separately as source evidence, a derived mapping, a plan judgment, missing
evidence, or not applicable.

No functional profile may reuse a removed coefficient. A required live core
input—target-depth temperature, tide/current, or pressure—remains null
under the operator's 2026-09-06 decision, with warning-level location, period,
missing-input, and provenance logging. The visitor receives no technical
fallback explanation.

## Phase 2 status

This document now records the catalogue inventory, source-quality audit,
identity/habitat/legal boundaries, and known unresolved member records. It does
not yet contain complete field-level effective profiles for every eligible
source member or regional functional fallback. Phase 2 and Gate 2 remain open.
