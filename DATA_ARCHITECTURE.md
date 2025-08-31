# DATA_ARCHITECTURE: Post‑Mortem + Udhëzues Parandalues

Ky dokument përmbledh analizën e shkaqeve rrënjësore (post‑mortem) dhe përshkruan arkitekturën e rekomanduar të të dhënave për të parandaluar regresione në të ardhmen në aplikacionin Flutter “Kurani Fisnik”.


## Pjesa 1 — Analiza Post‑Mortem (Root Cause Analysis)

### 1.1 Problemi i unifikuar: konflikt “Eager” vs “Lazy” loading
- Qëllimi: kërkimi funksional që në hapjen e aplikacionit kërkon të dhëna të plota (eager), ndërsa nisja e shpejtë kërkon ngarkim minimal (lazy).
- Anti‑modeli: thirrja e metodave “të rënda” në start (p.sh. `getAllSurahs()` ose ngarkimi/hidratimi i plotë i indeksit/`verseCache`) bllokon thread‑in kryesor, çon në ngrirje 5–9 sekonda dhe “Skipped frames”.
- Ndërlidhja: kur e shmangim ngrirjen me “lazy”, kërkimi mund të mos ketë të dhëna të mjaftueshme në memorie; kur e bëjmë kërkimin të menjëhershëm me “eager”, kthehet ngrirja. Zgjidhja është një strategji hibride e kontrolluar: meta‑t në start, indeks në sfond/kur kërkohet, dhe hidratim “on‑demand”.

### 1.2 Pse përkthimi mungon në pamjen e leximit?
- Hipoteza e verifikuar: rrjedha e leximit përdor një shteg “lazy” që ngarkon vetëm `SurahMeta` dhe vargjet bazë, por harron hapin e dytë të pasurimit (enrichment) me përkthimin/transliterimin e zgjedhur.
- Pse shfaqet në rezultatet e kërkimit? Kërkimi, kur ngarkohet në mënyrë “eager”, ka një `verseCache` me të dhëna të plota ose ka “raw verse” në memorie dhe i hidraton vetëm për rezultatet. Pra, rezultati i kërkimit shfaq përkthimin, por pamja e leximit (që ndjek një rrugë tjetër) nuk bën enrichment para `notifyListeners()`.
- Zgjidhja: në `QuranProvider.loadSurah(surahId)`, pasi merren vargjet bazë (`repository.getVersesForSurah(surahId)`), kryhet enrichment me përkthimin/transliterimin aktiv dhe vetëm pastaj thirret `notifyListeners()`. Kjo duhet të jetë e detyrueshme, jo opsionale.

### 1.3 Mësimet e nxjerra
- Mbani një strategji të vetme: “Lazy by default” + ngarkime të kontrolluara në sfond, jo rrugë të dyfishta (një “lazy”, një “eager”) brenda të njëjtit Provider.
- Mos bllokoni thread‑in kryesor me I/O ose JSON masiv; përdorni `compute`/izolate për parsing dhe ndërtim indeksi.
- Kërkimi ka nevoja globale (indeks), Leximi ka nevoja lokale (surah e hapur). Izoloni përgjegjësitë dhe mos ndërthurni rrjedhat.
- Stabilizoni instancat e provider‑ëve (mos rindërtoni shpesh) që cache/indekset të mos humbasin.


## Pjesa 2 — Arkitektura e të Dhënave (Udhëzues Parandalues)

### 2.1 Filozofia kryesore: “Lazy by default”
- Asnjëherë mos ngarko të gjithë Kuranin, përkthimet apo `verseCache` në start.
- Ruhen vetëm meta‑t në memorie në start; ngarkesat e tjera kryhen on‑demand ose në sfond.

### 2.2 Startup Flow (nisja e aplikacionit)
1. UI minimale shfaqet sa më shpejt (splash/landing e lehtë).
2. `QuranProvider` thërret vetëm `getSurahList()` për të marrë `SurahMeta` (id, emër, ajete, etj.).
3. `SurahListWidget` ndërtohet nga këto meta; asnjë varg i plotë nuk hidratohet.
4. Punët e rënda (p.sh. ngarkimi i `search_index.json`, verifikimi i snapshot‑it) fillojnë në sfond pas frame‑it të parë ose në hapjen e tabit të Kërkimit. JSON parsing/ndërtimi i indeksit të bëhet me `compute`/izolate.

### 2.3 Reader View Flow (hapja e një sureje)
1. Përdoruesi zgjedh një sure → `QuranProvider.loadSurah(surahId)`.
2. `QuranRepository.getVersesForSurah(surahId)` kthen vargjet bazë (pa i pasuruar globalisht cache‑t).
3. Hapi kritik: kryhet enrichment i vargjeve me përkthimin/transliterimin aktualisht të zgjedhur (p.sh. sq_*, transliterimet). Ky hap mund të përdorë një cache të vogël per‑surah dhe/ose parsing në izolat nëse skedari është i madh.
4. Vetëm pas përfundimit të enrichment thirret `notifyListeners()` që UI të ketë të dhëna të plota. Prefetch i lehtë për 1 sure para/pas mund të lejohet, por gjithmonë në sfond.

### 2.4 Search Flow (strategji hibride)
- Indeksi kryesor (statik):
  - Ngarkohet nga `assets/data/search_index.json` ose nga snapshot i lokalt në mënyrë asinkrone. Kjo ndodh në sfond pas nisjes ose në hapjen e parë të tabit të Kërkimit. Kurrë mos e blloko nisjen.
  - Parsing/validimi në izolat; mos hidrato vargje objekt‑orientuar në masë—ruaj “raw verse” (harta) dhe hidrato vetëm për rezultatet e shfaqura.
- `verseCache` (dinamik):
  - Mos e mbush kurrë në tërësi në start. Hidrato vetëm kur:
    - përdoruesi hap një sure (flow i leximit), ose
    - kërkimi kthen rezultate që duhen shfaqur.
- Ekzekutimi i kërkimit:
  - Gating mbi indeksin e ngarkuar; përdor “raw verse” për normalizim/ranking; hidrato objekte vetëm për rreshtat që shfaqen.
  - Përditësimet e progresit dhe rimbërthimi i UI duhet të jenë të deboncuara/throttled për të shmangur “rebuild storms”.

### 2.5 Rregullat e Arta (Anti‑modelet për t’u shmangur)
- MOS thirr `getAllSurahs()` (ose ekuivalente) në startup ose në constructor të Provider‑it.
- MOS bëj I/O sinkron, JSON parsing masiv, ose ndërtim indeksi në thread‑in kryesor. Përdor `compute` ose izolate.
- ÇDO Provider të jetë “lazy”: asnjë punë e rëndë në konstruktor; përdorni metoda `ensure*()` që nisin punë në sfond kur kërkohet.
- MOS hidrato masivisht `Verse` në memorie. Ruaj “raw verse” dhe hidrato “on‑demand”.

### 2.6 Stabiliteti i Provider‑ëve dhe versionimi i të dhënave
- Mos rikrijo provider‑ët pa nevojë; përdor `ProxyProvider` me `update` që ruan instancën ekzistuese kur është e mundur.
- Snapshot‑et dhe `search_index.json` të kenë `version` dhe `dataVersion`. Kur ndryshon korpusi (p.sh. skedarë në `assets/data/`), rrit `dataVersion` për të invaliduar cache‑t.

### 2.7 Observabiliteti dhe verifikimi
- Telemetri e lehtë: kohë nisjeje, kohë ngarkimi indeksi (sfond), numri i vargjeve të hidratuara në UI.
- Lint/Analyzer: pa punë të rënda në konstruktorë të provider‑ëve; mos përdor `initState` për I/O pa `postFrame`/deferim.
- Teste gardiane (smoke + unit):
  - Startup: “0 Verse të hidratuara” pas kornizës së parë; vetëm meta‑t në memorie.
  - Reader: hap një sure → përkthimi shfaqet; enrichment kryhet përpara `notifyListeners()`.
  - Search: nëse indeksi nuk është gati, nis ngarkimin në sfond; kërkimet pasuese japin rezultate; nuk ka crash kur ndërrohen përkthimet.

### 2.8 “Playbook” i shpejtë për regresionet
- Nëse shfaqen ngrirje në start: kontrollo për thirrje “të rënda” në startup (I/O, JSON parsing, hidratim masiv) dhe zhvendosi në izolat/sfond.
- Nëse mungon përkthimi në lexim: verifiko që `loadSurah()` bën enrichment para `notifyListeners()` dhe që përkthimi i zgjedhur po merret nga repo.
- Nëse kërkimi kthen “No results”: sigurohu që indeksi/snapshot është ngarkuar (ose niset ngarkimi) dhe se provider‑i nuk është rikrijuar duke humbur cache‑t.


## Shtojcë — Kontrata minimale e moduleve
- `QuranRepository`
  - Input: id e surës
  - Output: meta ose vargje bazë; funksione për enrichment (përkthim/transliterim) që mund të punojnë në izolat.
- `QuranProvider`
  - Startup: `getSurahList()` (meta vetëm)
  - Reader: `loadSurah(surahId)` → enrichment → `notifyListeners()`
  - Search: `ensureSearchIndexReady()` që nis ngarkimin në sfond; `search(query)` që përdor indeksin dhe hidratonin “on‑demand”.
- `SearchIndexManager`
  - Ngarkon indeks/snapshot në sfond; ruan “raw verse”; hidraton vetëm për rezultatet; shmang “rebuild storms”.

---

Ky dokument është bazë referimi. Ruajeni të azhurnuar pas çdo ndryshimi në rrjedhat e të dhënave, politikën e caching‑ut ose formatin e asset‑eve.

## Historia e Regresioneve dhe Parandalimi

- Gusht 2025 — Regresion në Kërkim: Kërkimi dështoi sepse `assets/data/search_index.json` ishte bosh. Ky problem shfaqej me `invSize=0` në log dhe asnjë rezultat.
  - Zgjidhja teknike: rikrijim i asetit me `tool/build_search_index.dart` dhe ngarkim i detyruar në `SearchWidget.initState` përmes `ensureSearchIndexReady()` që përdor prebuilt/snapshot.
  - Gardianët e rinj:
    - CI workflow gjeneron dhe validon indeksin (`tool/validate_assets.dart`) përpara analizës/testeve; dështimi i validimit ndalon PR‑in.
    - Test i thjeshtë `test/asset_guard_test.dart` verifikon që `search_index.json` ekziston dhe ka një `index` jo‑bosh.
  - Qëllimi: të parandalohen përsëritje të të njëjtit regresion dhe të garantohet që kërkimi të ketë gjithmonë të dhëna të vlefshme.