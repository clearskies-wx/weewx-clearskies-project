# International Forecast Text Patterns — Verified Reference

**Researched:** 2026-07-05 via WebSearch + WebFetch against national meteorological service websites  
**Purpose:** Reference for building i18n-compliant forecast text generation. Documents how each national met service structures forecast period text — period labels, probability language, temperature phrasing, wind, transitions, and sentence structure.  
**Used by:** Forecast text engine locale files, custom composers, template system

---

## Research Methodology

All examples are fetched from live national meteorological service websites on 2026-07-05. Source URLs are cited per section. No examples are from training data. Where a website could not be fetched (JavaScript-rendered content), API data or documented examples are used instead with the limitation noted.

---

## 1. Dutch — KNMI (Koninklijk Nederlands Meteorologisch Instituut)

**Sources:** [knmi.nl/verwachtingen](https://www.knmi.nl/nederland-nu/weer/verwachtingen), [knmi.nl/de-weersverwachting](https://www.knmi.nl/kennis-en-datacentrum/achtergrond/de-weersverwachting)

### Fetched forecast text (July 5, 2026)

> "Zwaar bewolkt en af en toe regen. Vanmiddag is het zwaar bewolkt en af en toe valt er regen. De middagtemperatuur loopt uiteen van 19 graden C in het noordelijk kustgebied tot 24 graden C in Limburg. De westelijke wind is zwak tot matig."

> "Komende nacht is het vrijwel overal droog. De minimumtemperaturen liggen rond 15 graden C. Landinwaarts is er weinig wind. Aan de kust staat een matige wind uit het zuidwesten."

> "Morgenochtend is het half tot zwaar bewolkt. In het noordoosten kan er plaatselijk lichte regen vallen."

### Period labels

| Dutch | English equivalent |
|---|---|
| Vanmiddag | This afternoon |
| Vanavond | This evening |
| Komende nacht | Coming night |
| Morgenochtend | Tomorrow morning |
| Morgenmiddag | Tomorrow afternoon |
| Vanaf donderdag | From Thursday (extended) |

### Precipitation probability

Narrative qualifiers in text: "af en toe regen" (now and then rain), "kan er plaatselijk lichte regen vallen" (light rain can fall locally), "vrijwel overal droog" (practically everywhere dry). Tabular product uses percentage (%) for "Neerslagkans" (precipitation chance).

### Temperature

Degrees Celsius with geographic qualification: "De middagtemperatuur loopt uiteen van 19 graden C in het noordelijk kustgebied tot 24 graden C in Limburg." Minima: "De minimumtemperaturen liggen rond 15 graden C."

### Wind

Direction + qualitative Beaufort scale: "De westelijke wind is zwak tot matig" (westerly wind is weak to moderate). Direction letters: N, NO, O, ZO, Z, ZW, W, NW.

### Sentence structure

[Time period] + [sky condition] + [precipitation]. [Temperature with regional variation]. [Wind direction + intensity]. Order: (1) sky/clouds, (2) precipitation, (3) temperature, (4) wind.

---

## 2. Russian — Roshydromet (Гидрометцентр России)

**Sources:** [meteoinfo.ru/moscow](https://meteoinfo.ru/forecasts/russia/moscow-area/moscow), [meteoinfo.ru/terminology](https://meteoinfo.ru/forcabout/3891-nast-kpp), [Telegram @hmcru](https://t.me/s/hmcru), [meteoservice.ru](https://www.meteoservice.ru/weather/text/rossiya)

### Fetched forecast text (July 5, 2026)

**Day forecast:**
> "Облачно с прояснениями. Кратковременный дождь. Местами гроза."
> Temperature: 20..22°C
> Wind: "З 5-10 м/c, при грозе порывы до 15 м/c"

**Night forecast:**
> "Облачно с прояснениями. Местами кратковременный дождь."
> Temperature: 14..16°C
> Wind: "Ю-З 4-9 м/c"

### Period labels

| Russian | English equivalent |
|---|---|
| День | Day |
| Ночь | Night |
| Днем | During the day |
| Ночью | At night |
| В ближайшие сутки | In the coming 24 hours |
| В первой половине дня | In the first half of the day |
| Понедельник 6 июля | Monday July 6 |

### Precipitation probability

NOT expressed as percentages. Uses spatial qualifiers per official standard RD 52.27.724-2009:
- "Местами" (in places) — confirmed at ≤ 50% of stations
- "В отдельных районах" (in individual areas)
- "Кратковременный дождь" (brief rain) — implies limited duration

### Temperature

Ranges in Celsius: "20..22°C" (point forecast) or "около +20°C" (approximately). Day/night always separate: "Днем около +20°C, ночью — около +17°C." Per standards: 2°C increments for points, 5°C increments for regions.

### Wind

Direction abbreviation + speed range in m/s + gust clause: "З 5-10 м/c, при грозе порывы до 15 м/c" (W 5-10 m/s, gusts to 15 m/s during thunderstorms).

Direction abbreviations: З (west), Ю-З (southwest), Ю (south), С-В (northeast).

Official qualitative scale: "слабый" (weak, 0-5 m/s), "умеренный" (moderate, 6-11 m/s), "сильный" (strong, 12-17 m/s), "ураганный" (hurricane, 33+ m/s).

### Cloud cover terminology (official)

| Russian | English | Oktas |
|---|---|---|
| Ясно | Clear | 0-3 |
| Малооблачно | Few clouds | — |
| Облачно с прояснениями | Cloudy with clear spells | dominant term |
| Переменная облачность | Variable cloudiness | — |
| Облачно, пасмурно | Cloudy, overcast | 8-10 |

### Sentence structure

[Cloud description]. [Precipitation type]. [Spatial qualifier + phenomenon]. Then separately: Temperature as range. Wind as direction + speed + gusts. Order: (1) cloudiness, (2) precipitation, (3) additional phenomena, (4) temperature, (5) wind.

**Style:** Telegraphic — short declarative sentences, no conjunctions between sky and precipitation.

---

## 3. Portuguese — IPMA (Portugal) and INMET (Brazil)

### 3A. European Portuguese — IPMA

**Sources:** [ipma.pt/prev.descritiva](https://www.ipma.pt/pt/otempo/prev.descritiva/), [IPMA API weather types](https://api.ipma.pt/open-data/weather-type-classe.json), [IPMA API Lisbon](https://api.ipma.pt/open-data/forecast/meteorology/cities/daily/1110600.json)

#### Weather type classification (31 types, fetched from API)

| ID | Portuguese | English |
|---|---|---|
| 1 | Céu limpo | Clear sky |
| 2 | Céu pouco nublado | Partly cloudy |
| 3 | Céu parcialmente nublado | Sunny intervals |
| 4 | Céu muito nublado ou encoberto | Cloudy |
| 5 | Céu nublado por nuvens altas | Cloudy (high cloud) |
| 6 | Aguaceiros/chuva | Showers/rain |
| 7 | Aguaceiros/chuva fracos | Light showers/rain |
| 8 | Aguaceiros/chuva fortes | Heavy showers/rain |
| 9 | Chuva/aguaceiros | Rain/showers |
| 10 | Chuva fraca ou chuvisco | Light rain/drizzle |
| 11 | Chuva/aguaceiros forte | Heavy rain/showers |
| 12 | Períodos de chuva | Intermittent rain |
| 15 | Chuvisco | Drizzle |
| 16 | Neblina | Mist |
| 17 | Nevoeiro ou nuvens baixas | Fog or low clouds |
| 18 | Neve | Snow |
| 19 | Trovoada | Thunderstorms |
| 20 | Aguaceiros e possibilidade de trovoada | Showers and possible thunderstorms |
| 21 | Granizo | Hail |
| 22 | Geada | Frost |
| 23 | Chuva e possibilidade de trovoada | Rain and possible thunderstorms |

#### Fetched narrative text

> "Céu geralmente muito nublado, tornando-se gradualmente pouco nublado ou limpo a partir da manhã"

> "Períodos de chuva fraca ou chuvisco até início da tarde, temporariamente moderada até início da manhã"

#### Wind classification

| Portuguese | Speed |
|---|---|
| fraco | ≤ 15 km/h |
| moderado | 15-35 km/h |
| forte | 35-55 km/h |
| muito forte | > 55 km/h |

#### Period labels

"Hoje" (today), "Amanhã" (tomorrow). Temporal phrases within text: "a partir da manhã" (from morning), "até início da tarde" (until early afternoon).

#### Sentence structure

[Sky condition with temporal evolution]. [Precipitation + intensity + temporal extent]. [Wind direction + intensity + geographic qualifier]. [Temperature]. Uses "Céu" (sky) prefix before cloud descriptions. Transition: "tornando-se gradualmente" (gradually becoming).

### 3B. Brazilian Portuguese — INMET

**Sources:** [portal.inmet.gov.br](https://portal.inmet.gov.br/), [Agência Brasil / INMET capitals](https://memoria.ebc.com.br/agenciabrasil/noticia/2002-12-02/inmet-informa-previsao-do-tempo-para-capitais), [Revista Cultivar](https://revistacultivar.com.br/noticias/inmet-previsao-do-tempo-ate-segunda-feira-6-7)

#### Fetched forecast text

> "Rio de Janeiro: claro a parcialmente nublado passando a nublado com possibilidade de pancadas de chuvas e trovoadas isoladas à noite. Temperatura estável. Máxima de 38 graus."

> "Curitiba: nublado a encoberto com chuva. Temperatura: ligeiro declínio. Máxima de 26 graus."

#### Key differences from European Portuguese

- INMET omits "Céu" prefix — uses bare cloud terms
- Uses "passando a" (changing to) for transitions
- Uses "com possibilidade de" (with possibility of) for uncertainty
- Temperature trend words: "estável" (stable), "ligeiro declínio" (slight decline), "em elevação" (rising)
- Very telegraphic for city forecasts; more narrative for regional overviews

#### Period labels

"Madrugada" (dawn), "Manhã" (morning), "Tarde" (afternoon), "Noite" (night). Extended: date-based.

#### Sentence structure

[City]: [sky condition transition]. [Precipitation possibility]. [Temperature trend]. [Maximum temperature]. Very concise, formulaic.

---

## 4. Italian — ilMeteo / Servizio Meteorologico

**Sources:** [ilMeteo.it](https://www.ilmeteo.it/portale/meteo-oggi), [meteo.it](https://www.meteo.it/meteo/italia), [meteoam.it](https://www.meteoam.it/it/home), [CFR Toscana](https://www.cfr.toscana.it/index.php?IDS=2&IDSS=69)

### Fetched forecast text (July 5, 2026)

**National overview:**
> "Anticiclone prevalente sull'Italia. La giornata sarà contrassegnata da un'atmosfera stabile, infatti il sole non incontrerà grossi problemi a splendere in un cielo che sarà sereno o al massimo poco nuvoloso su tutte le regioni. I venti soffieranno debolmente dai quadranti settentrionali."

**Northern Italy:**
> "Il cielo si potrà vedere sereno o al massimo poco nuvoloso e soltanto sui rilievi del Triveneto, specie sul Friuli, si potranno verificare delle precipitazioni pomeridiane. Venti deboli, mare calmo e caldo fino a 35 gradi."

**Regional bulletin (Toscana):**
> "Cielo: sereno o poco nuvoloso; nel pomeriggio formazione di locali addensamenti sulle zone interne."

### Period labels

"Oggi" (today), "Domani" (tomorrow), "Sabato" (Saturday). Day parts: "Al mattino" (in the morning), "Nel pomeriggio" (in the afternoon), "nella prima parte del mattino" (in the first part of the morning).

### Precipitation probability

Always narrative, never percentages: "qualche debole e locale pioggia" (some weak and local rain), "si potranno verificare delle precipitazioni pomeridiane" (afternoon precipitation may occur).

### Wind

"I venti soffieranno debolmente dai quadranti settentrionali" (winds will blow weakly from northern quadrants). Uses "quadranti" (quadrants). Intensity: "debole" (weak), "moderato" (moderate), "forte" (strong). Sea state paired: "mare calmo" (calm), "poco mossi" (slightly choppy).

### Sentence structure

Italian forecasts are the **most literary/narrative** of all services studied. Order: (1) synoptic cause, (2) overall characterization, (3) sky conditions, (4) precipitation as exceptions, (5) wind, (6) sea state, (7) temperature. Causal connectors: "pertanto" (therefore), "di conseguenza" (consequently), "infatti" (in fact).

---

## 5. Filipino — PAGASA

**Sources:** [pagasa.dost.gov.ph/weather](https://www.pagasa.dost.gov.ph/weather), [PAGASA NCR](https://www.pagasa.dost.gov.ph/regional-forecast/ncrprsd), [PAGASA Northern Luzon](https://www.pagasa.dost.gov.ph/regional-forecast/nlprsd), [PAGASA Weekly](https://www.pagasa.dost.gov.ph/weather/weather-outlook-weekly)

### Fetched forecast text (July 5, 2026)

> "Partly cloudy to cloudy skies with isolated rainshowers or thunderstorms"
> Temperature: 25-35°C
> Wind: "Light to moderate" from east

### Key finding

**PAGASA issues ALL forecasts exclusively in English.** No Filipino/Tagalog language forecasts found on any official pages or PDF products. This is consistent with our existing i18n-composition-patterns.md which documents: "PAGASA uses English for all meteorological text."

### Period labels

"Tonight", "Tomorrow", named days. Standard English period labels.

### Precipitation probability

Spatial qualifiers only: "isolated rainshowers or thunderstorms", "scattered", "with at times heavy rains". No percentages.

### Sentence structure

Formulaic: "[Sky condition] with [precipitation type]". Very standardized, not narrative. Synopsis → Regional conditions → Wind/Coastal table → Temperature.

---

## 6. Chinese Traditional — CWA (Central Weather Administration, Taiwan)

**Sources:** [cwa.gov.tw/County](https://www.cwa.gov.tw/V8/C/W/County/County.html?CID=63), [cwa.gov.tw/week](https://www.cwa.gov.tw/V8/C/W/week.html), [CWA Open Data API](https://opendata.cwa.gov.tw/dist/opendata-swagger.html), [API example (HackMD)](https://hackmd.io/@hexschool/HJk5Xx8Cxg)

### Fetched API data (F-C0032-001 dataset)

```
city: 高雄市
weather: 多雲時晴 (cloudy, sometimes clear)
rain: 10%
minTemp: 25°C, maxTemp: 32°C
comfort: 悶熱 (muggy)
windSpeed: 偏南風 3-4 級 (southerly wind force 3-4)
```

### Weather description terms (fixed codified phrases)

| Chinese | English |
|---|---|
| 晴 | Clear/sunny |
| 多雲 | Cloudy |
| 陰 | Overcast |
| 晴時多雲 | Clear, sometimes cloudy |
| 多雲時晴 | Cloudy, sometimes clear |
| 多雲短暫雨 | Cloudy with brief rain |
| 多雲短暫陣雨或雷雨 | Cloudy with brief showers or thunderstorms |

### Period structure

12-hour blocks: 06:00-18:00 (白天 daytime) and 18:00-06:00 (晚上 nighttime).

### Precipitation probability

Percentage: "10%", "20%", "0%". Direct numerical, similar to NWS.

### Wind

Direction + Beaufort scale: "偏南風 3-4 級" (southerly wind force 3-4). Uses "偏" (towards/biased) prefix.

### Comfort index (unique to CWA)

"舒適度" (comfort index): "悶熱" (muggy), "舒適" (comfortable), "寒冷" (cold).

### Sentence structure

**NOT narrative** — structured data fields: (1) 天氣 weather phrase, (2) 降雨機率 PoP %, (3) 溫度 temp range, (4) 舒適度 comfort, (5) 風速 wind. Similar to our existing zh-CN/zh-TW current conditions composer pattern.

---

## Cross-Service Comparison

| Feature | KNMI (nl) | Roshydromet (ru) | IPMA (pt-PT) | INMET (pt-BR) | Italian | PAGASA (fil) | CWA (zh-TW) |
|---|---|---|---|---|---|---|---|
| **Format** | Narrative | Telegraphic | Narrative | Telegraphic | Literary narrative | Formulaic | Data fields |
| **Precip prob** | % in table, text in narrative | Spatial qualifiers | % in API, text in narrative | Text qualifiers | Text qualifiers | Text qualifiers | Percentage |
| **Temperature** | Range + geography | Range °C, day/night | Min/Max °C | Max + trend word | Max with "fino a" | Range low-high | Min/Max per period |
| **Wind** | Direction + Beaufort qual. | Abbrev + m/s + gusts | Quadrant + km/h class | Minimal | Quadrant + qualitative | Intensity + direction | Direction + Beaufort |
| **Period labels** | Dutch time-of-day words | День/Ночь + dates | Hoje/Amanhã | Shifts (dawn/afternoon/night) | Time-of-day + regional | English periods | 12-hour blocks |
| **Narrative style** | Moderate | Low | Moderate-High | Low-Moderate | Very High | Very Low | None |

---

---

## 7. Japanese — JMA (Japan Meteorological Agency)

**Sources:** [JMA Tokyo XML via drk7.jp](https://www.drk7.jp/weather/xml/13.xml), [JMA Forecast Terminology](https://www.jma.go.jp/jma/kishou/know/yougo_hp/mokuji.html), [JMA Weather Terms](https://www.jma.go.jp/jma/kishou/know/yougo_hp/tenki.html), [JMA Wind Terms](https://www.jma.go.jp/jma/kishou/know/yougo_hp/kaze.html), [JMA Temperature Terms](https://www.jma.go.jp/jma/kishou/know/yougo_hp/kion.html), [JMA Product Catalog](https://www.data.jma.go.jp/suishin/cgi-bin/catalogue/make_product_page.cgi?id=TenkiYoh)

### Fetched forecast text (Tokyo, July 5, 2026)

```
くもり　時々　雨           (Cloudy, occasionally rain)
くもり　夜のはじめ頃　晴れ  (Cloudy, clearing toward early evening)
雨　後　くもり             (Rain, later cloudy)
晴れ時々くもり             (Fair with occasional clouds)
くもり一時雨              (Cloudy, temporarily rain)
くもり　所により　雨       (Cloudy with rain in some areas)
```

Wind: `南の風　２３区西部　では　南の風　やや強く` (South wind; in western 23 wards, somewhat strong south wind)

Precipitation probability: `20%, 60%, 50%, 60%` for 4 six-hour blocks (00-06, 06-12, 12-18, 18-24)

### Period labels

| Japanese | Reading | English |
|---|---|---|
| 今日 | kyō | Today |
| 明日 | ashita | Tomorrow |
| 明後日 | asatte | Day after tomorrow |
| 未明 | mimei | Pre-dawn |
| 明け方 | akegata | Daybreak |
| 朝 | asa | Morning |
| 昼前 | hirumae | Late morning |
| 昼過ぎ | hirusugi | Afternoon |
| 夕方 | yūgata | Evening |
| 夜のはじめ頃 | yoru no hajimegoro | Early night |
| 夜遅く | yoru osoku | Late night |

### Weather transition operators — CONFIRMED same as current conditions

| Operator | Reading | Meaning | Duration rule |
|---|---|---|---|
| 時々 | tokidoki | occasionally | Intermittent, < 50% of forecast period |
| 一時 | ichiji | temporarily | Continuous, < 25% of period |
| のち / 後 | nochi | later/then | State change within period |
| 所により | tokoroni yori | in some areas | Spatial qualifier |

### Precipitation probability

Percentage in 10% increments per 6-hour block. Defined as probability of ≥ 1mm precipitation. Higher probability does NOT imply heavier rainfall (JMA explicitly states this).

### Temperature

Single integer values in Celsius: `最高気温` (maximum) and `最低気温` (minimum). No ranges or decade grouping. Weekly forecasts compare to normals: `平年並` (near normal).

### Wind

Direction: `南の風` (south wind), `南よりの風` (southerly wind — variable within quadrant). Speed terms: 静穏 (calm, <0.3 m/s), やや強い (somewhat strong, 10-15 m/s), 強い (strong, 15-20 m/s), 非常に強い (very strong, 20-30 m/s), 猛烈な (violent, ~30+ m/s).

### Sentence structure

**NOT prose narrative.** Semi-structured telegraphic format: `[Weather] [space] [Transition operator] [space] [Next condition]`. Wind and wave are separate fields. Components separated by full-width spaces. Fundamentally different from NWS flowing prose.

---

## 8. German — DWD (Deutscher Wetterdienst)

**Sources:** [DWD National Forecast](https://www.dwd.de/DE/wetter/vorhersage_aktuell/vhs_brd_node.html), [DWD Hessen](https://www.dwd.de/DE/wetter/vorhersage_aktuell/hessen/vhs_hes_node.html), [DWD 10-Day](https://www.dwd.de/DE/wetter/vorhersage_aktuell/10-tage/10tage_node.html)

### Fetched forecast text (Hessen, July 5, 2026)

**Synoptic overview:**
> "Zwischen einem Tief über der Norwegischen See und einem Hoch mit Zentrum südlich von Irland gelangt mit einer nordwestlichen Strömung warme Meeresluft in den Vorhersagebereich."

**Sunday:**
> "Am Sonntag wechselnd bewölkt und im Tagesverlauf Schauer, nachmittags und abends auch einzelne kurze Gewitter gering wahrscheinlich. Temperaturanstieg auf 22 bis 28 Grad mit den höheren Werten im Süden, in Hochlagen um 20 Grad."

**Night to Monday:**
> "In der Nacht zum Montag wechselnd bewölkt und im Nordosten einzelne letzte, rasch abschwächende Schauer möglich. Tiefsttemperatur zwischen 17 und 13 Grad."

**Monday:**
> "Am Montag im Norden wechselnd bis stark bewölkt und etwas Regen möglich. Nach Süden mehr Sonne und niederschlagsfrei. Höchsttemperatur zwischen 24 und 27 Grad im Norden und 27 bis 31 Grad im Süden."

### Period labels

| German | English |
|---|---|
| Am Sonntag | On Sunday |
| Nacht zum Montag | Night leading to Monday |
| Am Montag | On Monday |
| tagsüber | during the day |
| nachmittags | afternoon |
| abends | evening |

### Precipitation probability

Qualitative, never percentages: `gering wahrscheinlich` (low probability), `möglich` (possible), `wahrscheinlich` (probable), `vereinzelt` (isolated), `gebietsweise` (area-wide).

### Temperature

Ranges in Celsius with regional differentiation: "Höchsttemperatur zwischen 24 und 27 Grad im Norden und 27 bis 31 Grad im Süden." Also: "Temperaturanstieg auf 22 bis 28 Grad" (temperature rise to 22-28 degrees).

### Wind

Direction + Beaufort: "Windböen um 55 km/h (Bft 7) aus West bis Nordwest." Qualifiers: `mäßig` (moderate), `frisch` (fresh), `stark` (strong), `böig` (gusty), `stürmisch` (stormy).

### Sentence structure

**Most NWS-like of all non-English services.** Flowing German prose paragraphs, one per day. Opens with synoptic overview, then day-by-day narrative. Order within paragraphs: sky → precipitation → temperature → wind. Uses standard German connectors: `und` (and), `mit` (with), `dann` (then), `zunächst` (initially), `anschließend` (subsequently).

---

## 9. Spanish — AEMET (Agencia Estatal de Meteorología)

**Sources:** [aemet.es/prediccion/espana](https://www.aemet.es/es/eltiempo/prediccion/espana), [AEMET Help](https://www.aemet.es/en/eltiempo/prediccion/espana/ayuda), [AEMET Probability Terms (Tagoror Meteo)](https://tagorormeteo.es/descifrando-los-terminos-de-probabilidad-y-espacio-que-utiliza-aemet-en-sus-predicciones/), [AEMET Precipitation Language (Blog)](https://aemetblog.es/2016/08/23/el-lenguaje-de-los-meteorologos-las-precipitaciones/)

### Fetched forecast text (National, July 5, 2026)

> "Continuá la situación de estabilidad y la ola de calor, con ello, los cielos despejados o poco nubosos, aunque con algunas nubes altas."

> "Crecerán nubes de evolución en el centro peninsular, dejando algún chubasco aislado en zonas de montaña."

> "Se superarán los 36-39 grados en la mayor parte de la Península."

> "Vientos de componente este en general en los litorales, que serán fuertes en el Estrecho con algunas rachas muy fuertes."

### AEMET standardized probability vocabulary

| Term | Probability range |
|---|---|
| baja probabilidad / posible | 10-40% |
| probable | 40-70% |
| (no qualifier) | > 70% |
| no se descarta | very low probability |

**Spatial distribution:**
- `aisladas o dispersas` = affects < 30% of territory
- (unqualified) = 30-60%
- `generalizadas` = > 60%

**Temporal duration:**
- `ocasionales` = < 30% of period
- `intermitentes` = ~50% with brief interruptions
- `persistentes o continuas` = > 60%

**Rain intensity:**
- `débiles` = up to 2 mm/h
- (unqualified) = 2-15 mm/h
- `fuertes` = 15-30 mm/h
- `muy fuertes` = 30-60 mm/h
- `torrenciales` = > 60 mm/h

### Period labels

`para hoy` (for today), `para mañana` (for tomorrow). Sub-periods: `por la tarde` (afternoon), `al final del día` (end of day), `a mediodía` (midday).

### Sentence structure

Organized **thematically**, not by time period: Cielos (sky) → Precipitaciones (precipitation) → Temperaturas (temperatures) → Vientos (winds). National forecast is a flowing paragraph; regional forecasts are shorter with same element order. Connectors: `aunque` (although), `con` (with), `salvo` (except).

---

## 10. French — Météo-France

**Sources:** [meteofrance.com/paris/75000](https://meteofrance.com/previsions-meteo-france/paris/75000), [Météo-France Île-de-France](https://meteofrance.com/previsions-meteo-france/ile-de-france/3)

### Fetched forecast text (Paris, July 5, 2026)

**Pour ce matin:**
> "Temps largement ensoleillé. La température se situe aux alentours de 18 degrés vers 8 heures. Vent de Nord-Ouest assez faible."

**Pour cet après-midi:**
> "Le soleil brille généreusement. La température se situe aux alentours de 27 degrés vers 14 heures. Vent faible à modéré de Nord-Ouest."

**Pour ce soir:**
> "Passages nuageux de haute altitude. Les températures avoisinent 29 degrés vers 20 heures. Vent faible de Nord-Nord-Ouest."

**Pour la nuit prochaine:**
> "Voile de nuages élevés. La température se situe aux alentours de 22 degrés vers 2 heures. Vent faible de direction variable."

### Period labels — **closest to NWS of any non-English service**

| French | English equivalent |
|---|---|
| Pour ce matin | For this morning |
| Pour cet après-midi | For this afternoon |
| Pour ce soir | For this evening |
| Pour la nuit prochaine | For the coming night |
| Pour lundi matin | For Monday morning |
| Pour lundi après-midi | For Monday afternoon |

### Temperature

Single representative value at a specific time (unique among all services): "La température se situe aux alentours de 27 degrés vers 14 heures" (around 27 degrees around 2 PM). NOT expressed as ranges or highs/lows.

### Wind

`Vent de Nord-Ouest assez faible` (NW wind, fairly light). Qualifiers: `faible` (light), `assez faible` (fairly light), `faible à modéré` (light to moderate), `modéré` (moderate). Numeric for strong: "50 à 60 km/h".

### Sentence structure

**Most NWS-like format.** Period-labeled paragraphs, each following: sky conditions → temperature → wind. Simple declarative sentences, minimal subordination. Each element gets its own sentence.

---

## 11. Chinese Simplified — CMA (China Meteorological Administration)

**Sources:** [weather.cma.cn Beijing](https://weather.cma.cn/web/weather/54511.html), [weather.cma.cn Shanghai](https://weather.cma.cn/web/weather/58367.html), [CMA Weather Bulletin](https://weather.cma.cn/web/channel-3780.html)

### Fetched forecast data (Beijing, July 5, 2026)

| Day | Daytime (白天) | Nighttime (夜间) |
|---|---|---|
| 星期日 07/05 | 雷阵雨，西风微风，32°C | 阴，东风微风，21°C |
| 星期一 07/06 | 雷阵雨，南风微风，32°C | 雷阵雨，东风微风，24°C |
| 星期二 07/07 | 雷阵雨，南风微风，30°C | 雷阵雨，东北风微风，22°C |

### City forecast format

**NOT narrative.** Structured tabular: `[Condition]，[Wind direction][Wind level]，[Temperature]°C`

Example: `雷阵雨，西风微风，32°C` (thundershowers, west wind light, 32°C)

### Period labels

白天 (daytime), 夜间 (nighttime). Days: 星期日 (Sunday), 星期一 (Monday), etc. Narrative bulletins: 今天白天 (today daytime), 今天夜间 (tonight), 明天 (tomorrow), 未来三天 (next three days).

### Precipitation terms

| Chinese | English |
|---|---|
| 小雨 | Light rain |
| 中雨 | Moderate rain |
| 大雨 | Heavy rain |
| 暴雨 | Torrential rain |
| 大暴雨 | Severe torrential rain |
| 特大暴雨 | Extreme torrential rain |
| 雷阵雨 | Thundershowers |
| 阵雨 | Showers |

No explicit probability in city forecasts. Bulletin narrative uses "部分地区有" (some areas will have).

### Wind

Direction: 西风 (west), 东南风 (southeast), 无持续风向 (no consistent direction). Speed: 微风 (light/gentle), 3~4级 (force 3-4), 4~5级 (force 4-5). Gusts in bulletins: "8~10级阵风" (force 8-10 gusts).

### Sentence structure

City forecasts are structured data fields, not prose. The weather bulletin (天气公报) is narrative prose but focused on severe weather warnings, not routine period forecasts. Same pattern as our existing zh-CN current conditions composer — structured, space-separated.

---

## Updated Cross-Service Comparison

| Feature | NWS (en) | JMA (ja) | DWD (de) | AEMET (es) | Météo-France (fr) | CMA (zh-CN) | CWA (zh-TW) | KNMI (nl) | Roshydromet (ru) | IPMA (pt-PT) | INMET (pt-BR) | Italian | PAGASA (fil) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Format** | Prose/period | Telegraphic | Prose/day | Prose/theme | Prose/period | Tabular | Tabular | Narrative | Telegraphic | Narrative | Telegraphic | Literary | Formulaic |
| **Precip prob** | % inline | % per 6h block | Qualitative | Standardized vocab | Not in text | Not in city | % | % in table | Spatial quals | % in API | Text quals | Text quals | Text quals |
| **Temperature** | "Highs near 78" | Single °C | Range °C | Range °C | Single °C at time | Single °C | Min/Max °C | Range + geography | Range °C | Min/Max °C | Max + trend | Max + "fino a" | Range low-high |
| **Wind** | "S wind 10-15 mph" | Direction + descriptor | Direction + Bft | Qualitative | Direction + qualifier | Direction + 级 | Direction + 級 | Direction + Bft qual | Abbrev + m/s | Quadrant + class | Minimal | Quadrant + qual | Intensity + dir |
| **Most NWS-like** | — | No | Yes | Partial | **Yes** | No | No | Moderate | No | Moderate | No | No | No |

---

## Implications for Our Engine

### Composition class assignments (forecast text)

| Locale | Current conditions class | Forecast text class (proposed) | Rationale |
|---|---|---|---|
| en | TEMPLATE | TEMPLATE — NWS-style period paragraphs | Direct GFE adaptation |
| de | TEMPLATE | TEMPLATE — DWD-style day paragraphs | Most NWS-like non-English service; same connectors, flowing prose |
| es | TEMPLATE | TEMPLATE — AEMET thematic order | Sky→precip→temp→wind; standardized probability vocab maps well to template |
| fr | TEMPLATE | TEMPLATE — Météo-France period paragraphs | **Most NWS-like format** — period-labeled paragraphs, same element order |
| it | TEMPLATE | TEMPLATE or CUSTOM — literary style may need custom | Italian is highly narrative with synoptic cause-first order; may be too literary for templates |
| nl | TEMPLATE | TEMPLATE — KNMI narrative style | Same connector pattern as current conditions, add period labels |
| pt-PT | TEMPLATE | TEMPLATE — IPMA narrative with transitions | "tornando-se gradualmente" pattern, "Céu" prefix |
| pt-BR | TEMPLATE | TEMPLATE — INMET telegraphic | Simpler than IPMA; "passando a" transitions |
| ru | TEMPLATE (case-inflected) | TEMPLATE — telegraphic Roshydromet style | Case inflection for spatial qualifiers, separate sentences per element |
| fil | TEMPLATE (English) | TEMPLATE (English) | PAGASA uses English exclusively — same as en |
| ja | CUSTOM | CUSTOM — JMA semi-structured telegraphic | Same 時々/一時/のち operators confirmed for forecasts; NOT prose |
| zh-CN | CUSTOM | CUSTOM — CMA structured tabular | NOT prose — structured fields like current conditions composer |
| zh-TW | CUSTOM | CUSTOM — CWA structured data fields | Same pattern as zh-CN with traditional characters and Beaufort 級 |

### Key locale-specific features needed for forecast text

**TEMPLATE locales:**

1. **English (en):** GFE period labels (Today/Tonight/Saturday/Saturday Night), PoP language (chance of/likely/slight chance), temperature decade phrasing (upper 80s, mid 40s), wind with connector transitions
2. **German (de):** Period labels (Am Sonntag, Nacht zum Montag), qualitative probability (gering wahrscheinlich, möglich), temperature ranges with regional differentiation, Beaufort wind with km/h
3. **Spanish (es):** Period labels (para hoy, para mañana), AEMET probability vocabulary (baja probabilidad/probable/no se descarta), spatial qualifiers (aisladas/generalizadas), temporal duration (ocasionales/intermitentes/persistentes), rain intensity scale (débiles through torrenciales)
4. **French (fr):** Period labels (Pour ce matin, Pour cet après-midi, Pour la nuit prochaine), temperature at specific hour ("aux alentours de 27 degrés vers 14 heures"), wind qualifiers (faible, assez faible, modéré)
5. **Dutch (nl):** Period labels (Vanmiddag, Vanavond, Morgenochtend), Beaufort qualitative wind terms (zwak/matig/krachtig), spatial qualifiers (plaatselijk, vrijwel overal)
6. **Russian (ru):** Case-inflected spatial qualifiers (Местами + nominative), period labels (День/Ночь + dates), direction abbreviations (З, Ю-З, С-В), wind in m/s with gust clause, cloud cover vocabulary (Облачно с прояснениями)
7. **Portuguese (pt-PT):** "Céu" prefix before sky terms, 31-type IPMA weather classification, "tornando-se gradualmente" transitions, quadrant wind system
8. **Portuguese (pt-BR):** "passando a" transitions, "com possibilidade de" probability, temperature trend words (estável/declínio/elevação), omit "Céu" prefix
9. **Italian (it):** Synoptic-cause-first order if literary mode, "quadranti" wind directions, literary connectors (pertanto, di conseguenza, infatti), sea state pairing
10. **Filipino (fil):** English — same as en locale (PAGASA confirmed English-only)

**CUSTOM locales:**

11. **Japanese (ja):** Same temporal operators (時々/一時/のち) confirmed for forecasts. Add 8 sub-period labels (未明 through 夜遅く), precipitation probability as % per 6h block, wind descriptor terms (やや強い through 猛烈な), single-value temperature in °C
12. **Chinese Simplified (zh-CN):** Structured tabular format (condition + wind direction + wind level + temperature). Period labels (白天/夜间 + 星期X). CMA precipitation intensity scale (小雨 through 特大暴雨). Wind: 微风/3~4级 notation
13. **Chinese Traditional (zh-TW):** Same structure as zh-CN with traditional characters. Fixed compound weather phrases (晴時多雲, 多雲短暫雨). Beaufort 級. 舒適度 comfort index (unique to CWA)
