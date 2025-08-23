### **Dokumenti i Rasteve të Përdorimit (Use Cases) për Aplikacionin "Kurani Fisnik" në Flutter**

**Versioni:** 1.1
**Data:** 23 Gusht 2025

#### **1. Aktorët**

*   **Përdoruesi (User):** Aktori kryesor i sistemit. Ky është çdo person që shkarkon dhe përdor aplikacionin, qoftë për lexim, studim apo dëgjim.
*   **Sistemi (System):** Përfaqëson vetë aplikacionin "Kurani Fisnik".

#### **2. Diagrami i Përgjithshëm i Rasteve të Përdorimit (Konceptual)**



*(Ky është një diagram konceptual për të ilustruar ndërveprimet kryesore. Tabela më poshtë ofron detajet e plota.)*

---

### **3. Rastet e Përdorimit të Detajuara**

#### **Moduli 1: Lundrimi dhe Zbulimi i Përmbajtjes**

| **UC-01: Shfletimi i Listës së Sureve** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi hap aplikacionin dhe shikon listën e plotë të 114 sureve për të zgjedhur njërën për lexim. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Aplikacioni është i instaluar dhe i hapur. Të dhënat bazë të sureve janë ngarkuar. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Sistemi shfaq ekranin kryesor me listën e sureve. <br> 2. Për çdo sure, Sistemi shfaq: numrin, emrin, përkthimin e emrit, numrin e ajeteve dhe llojin (Mekase/Medinase). <br> 3. Për suret e lexuara pjesërisht, Sistemi shfaq një shirit vizual progresi dhe përqindjen. <br> 4. Përdoruesi bën `scroll` poshtë për të parë të gjitha suret. <br> 5. Përdoruesi prek një sure specifike për ta hapur. |
| **Rrjedha Alternative (Alternative Flows):** | **3a. Shfaqet butoni "Vazhdo ku e ke lënë":** Nëse ka një shenjues të fundit të ruajtur, Sistemi shfaq një buton të dukshëm në krye të listës për të shkuar direkt te ai ajet. <br> **5a. Shfaqet modali i vazhdimit të leximit:** Nëse Përdoruesi prek një sure që është lexuar pjesërisht (mbi 10 ajete), Sistemi shfaq një dritare që pyet "Fillo nga e para" apo "Vazhdo ku e ke lënë?". <br> **5b. Rivendosja e progresit:** Përdoruesi prek butonin e rivendosjes te një sure e përfunduar për ta shënuar si të palexuar. |

| **UC-02: Kërkimi i Përmbajtjes** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi përdor fushën e kërkimit për të gjetur sure, ajete specifike, ose fjalë kyçe në tekstin shqip dhe arabisht. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Ekrani kryesor është i hapur. Indeksi i kërkimit është ndërtuar në prapaskenë. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Përdoruesi prek fushën e kërkimit. <br> 2. Përdoruesi shkruan një term kërkimi (emër sureje, referencë ajeti si "2:255", ose fjalë si "mëshira"). <br> 3. Ndërsa përdoruesi shkruan, Sistemi shfaq rezultatet në kohë reale dhe numrin total të gjetjeve. <br> 4. Rezultatet shfaqin ajetin e gjetur, referencën e tij dhe theksojnë nën‑vargjet e përputhura (highlight i pjesshëm, tolerant ndaj diakritikave). <br> 5. Përdoruesi prek një rezultat për të lundruar direkt te ai ajet në pamjen e leximit. |
| **Rrjedha Alternative (Alternative Flows):** | **2a. Filtrimi i kërkimit:** Përdoruesi hap filtrat dhe zgjedh të kërkojë vetëm në arabisht/shqip, ose e kufizon kërkimin brenda një xhuzi specifik. Sistemi përditëson rezultatet sipas filtrave. <br> **4a. Shfaqja e kontekstit:** Përdoruesi prek butonin "Shfaq Kontekstin" te një rezultat për të parë ajetin para dhe pas. |

#### **Moduli 2: Leximi dhe Ndërveprimi me Tekstin**

| **UC-03: Leximi i një Sureje** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi lexon një sure, duke lundruar midis ajeteve dhe duke përdorur mjetet e ndërfaqes. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Përdoruesi ka zgjedhur një sure nga lista ose ka lundruar nga një rezultat kërkimi. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Sistemi shfaq pamjen e leximit me ajetet e sures së zgjedhur. <br> 2. Për çdo ajet, Sistemi shfaq (sipas cilësimeve): numrin, tekstin arabisht, transliterimin, përkthimin dhe një grup butonash veprimi. <br> 3. Përdoruesi bën `scroll` poshtë për të lexuar ajetet. <br> 4. Ndërsa përdoruesi bën `scroll`, Sistemi përditëson shiritin e progresit në krye. <br> 5. Kur përdoruesi i afrohet fundit të sures, Sistemi automatikisht ngarkon dhe shton suren pasardhëse (infinite scroll). |
| **Rrjedha Alternative (Alternative Flows):** | **3a. Lundrim i shpejtë:** Përdoruesi përdor menunë rënëse "Shko te Ajeti" për të kërcyer direkt te një ajet specifik brenda sures. <br> **3b. Lexim pa shpërqendrime:** Përdoruesi prek butonin "Fullscreen" për të fshehur të gjithë elementet e tjerë të ndërfaqes. |

| **UC-04: Dëgjimi i Recitimit Audio** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi dëgjon recitimin audio për një ajet të vetëm ose për të gjithë suren. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Përdoruesi është në pamjen e leximit. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Përdoruesi prek butonin "Play" poshtë një ajeti. <br> 2. Sistemi shkarkon dhe luan audion për atë ajet. Ikona ndryshon në "Pause". <br> 3. Nëse është aktivizuar "Luajtja Fjalë-për-Fjalë", Sistemi thekson çdo fjalë arabisht në kohë reale. |
| **Rrjedha Alternative (Alternative Flows):** | **1a. Luajtja e të gjithë sures:** Përdoruesi prek butonin "Luaj Gjithë Suren" në shiritin e sipërm. <br> **2a. Shfaqet modali i zgjedhjes:** Nëse përdoruesi nuk është në fillim, Sistemi e pyet nëse dëshiron të fillojë nga ajeti aktual apo nga fillimi. <br> **3a. Luajtje e vazhdueshme:** Sistemi luan ajetet njëri pas tjetrit derisa përdoruesi ta ndalojë ose surja të mbarojë. <br> **4a. Menaxhimi me mini-player:** Një mini-player shfaqet në fund të ekranit për të kontrolluar luajtjen pa qenë nevoja të bëjë `scroll` lart. |

| **UC-05: Ndërveprimi me një Ajet të Vetëm** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi përdor grupin e butonave poshtë një ajeti për të kryer veprime specifike. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Përdoruesi është në pamjen e leximit. |
| **Rrjedha Kryesore (Basic Flow):** | Përdoruesi prek një nga butonat e veprimit (p.sh., "Kopjo", "Ndaj", "Shto te të Preferuarat", "Shënim", "Memorizo", "Gjenero Imazh"). Sistemi kryen veprimin përkatës për atë ajet. |

| **UC-06: Përzgjedhja e Shumë Ajeteve** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi zgjedh disa ajete njëkohësisht për të kryer veprime masive. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Përdoruesi është në pamjen e leximit. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Përdoruesi prek butonin "Modaliteti i Përzgjedhjes". <br> 2. Ndërfaqja ndryshon dhe Sistemi shfaq një shirit veprimesh në fund. <br> 3. Përdoruesi prek ajetet që dëshiron të zgjedhë. <br> 4. Përdoruesi prek një nga butonat në shiritin e veprimeve (p.sh., "Kopjo të gjitha", "Shto të gjitha te të Preferuarat"). <br> 5. Sistemi kryen veprimin për të gjitha ajetet e zgjedhura dhe del nga modaliteti i përzgjedhjes. |

#### **Moduli 3: Studimi i Thelluar dhe Personalizimi**

| **UC-07: Përdorimi i Indeksit Tematik** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi eksploron ajetet e Kuranit të grupuara sipas temave. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Përdoruesi ka hapur tabin "Indeksi Tematik". |
| **Rrjedha Kryesore (Basic Flow):** | 1. Sistemi shfaq një listë të kategorive kryesore. <br> 2. Përdoruesi prek një kategori për ta zgjeruar dhe për të parë nën-temat. <br> 3. Përdoruesi prek një nën-temë për ta zgjeruar dhe për të parë listën e ajeteve përkatëse. <br> 4. Përdoruesi prek një ajet ose rang (p.sh., 2:255–257) për të lundruar te ai në pamjen e leximit; Sistemi siguron `scroll` të besueshëm dhe e thekson segmentin për rreth 6 sekonda. |

| **UC-08: Mësimi i Texhvidit** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi mëson dhe praktikon rregullat e leximit të saktë të Kuranit. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Përdoruesi ka hapur tabin "Texhvid". |
| **Rrjedha Kryesore (Basic Flow):** | 1. Sistemi shfaq kategoritë e rregullave të Texhvidit. <br> 2. Përdoruesi prek një kategori për të parë rregullat që përmban. <br> 3. Përdoruesi prek një rregull për të parë shpjegimin e detajuar dhe shembujt. |
| **Rrjedha Alternative (Alternative Flows):** | **3a. Testimi i njohurive:** Përdoruesi prek butonin "Fillo Kuizin" (qoftë atë të përgjithshmin ose atë specifik për një rregull) për të hyrë në modalitetin e kuizit, ku përgjigjet pyetjeve dhe merr feedback të menjëhershëm. |

| **UC-09: Menaxhimi i Veglave Personale (Favoritet, Shënimet, Memorizimi)** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi menaxhon përmbajtjen që ka ruajtur personalisht. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Përdoruesi ka shtuar më parë ajete në njërën nga këto lista. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Përdoruesi hap njërin prej tabeve ("Të Preferuarat", "Shënimet", "Memorizim", "Shenjuesit"). <br> 2. Sistemi shfaq listën përkatëse të ajeteve të ruajtura. <br> 3. Përdoruesi ndërvepron me listën: i shikon, i fshin, ose lundron te ajeti origjinal. |
| **Rrjedha Specifike (Specific Flows):** | **Për Shënimet:** Përdoruesi mund të kërkojë dhe të filtrojë shënimet e tij sipas tekstit ose etiketave. <br> **Për Memorizimin:** Përdoruesi zgjedh ajetet që dëshiron të praktikojë, përcakton numrin e përsëritjeve dhe përdor veglat e fshehjes së tekstit dhe luajtjes së audios. |

#### **Moduli 4: Cilësimet dhe Administrimi**

| **UC-10: Personalizimi i Aplikacionit** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi modifikon pamjen dhe sjelljen e aplikacionit sipas preferencave të tij. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Aplikacioni është i hapur. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Përdoruesi hap panelin e Cilësimeve. <br> 2. Përdoruesi ndryshon një nga opsionet e disponueshme (p.sh., temën vizuale, madhësinë e fontit, shfaqjen e transliterimit, recituesin e audios). <br> 3. Sistemi aplikon ndryshimin menjëherë në të gjithë ndërfaqen dhe e ruan atë për sesionet e ardhshme. |

| **UC-11: Menaxhimi i të Dhënave** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi eksporton ose importon të dhënat e tij personale. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Paneli i cilësimeve është i hapur. |
| **Rrjedha Kryesore (Eksporti):** | 1. Përdoruesi prek butonin "Eksporto". <br> 2. Sistemi gjeneron një skedar JSON që përmban të gjitha të dhënat e përdoruesit (favoritet, shënimet, progresin, cilësimet) dhe ia ofron për shkarkim. |
| **Rrjedha Kryesore (Importi):** | 1. Përdoruesi prek butonin "Importo" dhe zgjedh një skedar JSON të vlefshëm nga pajisja e tij. <br> 2. Sistemi shfaq një mesazh konfirmimi. <br> 3. Pasi konfirmohet, Sistemi mbishkruan të dhënat aktuale me ato nga skedari dhe e rifreskon aplikacionin. |

| **UC-12: Njoftimet Ditore dhe Testi i Njoftimit** | |
| :--- | :--- |
| **Përshkrimi:** | Përdoruesi sheh “Lutja e Ditës” dhe “Hadithi i Ditës” në ekranin e njoftimeve, i rifreskon, dhe teston një njoftim lokal. |
| **Aktori:** | Përdoruesi |
| **Parakushtet:** | Aplikacioni ka ngarkuar asetet përkatëse (`lutjet.json`, `thenie-hadithe.json`) dhe ka lejet për njoftime. |
| **Rrjedha Kryesore (Basic Flow):** | 1. Sistemi shfaq kartat me përmbajtje të formatuar: titull/autor, tekst dhe burim. <br> 2. Përdoruesi prek ikonën e rifreskimit për të marrë një element të ri (rastësor, pa përsëritje të menjëhershme). <br> 3. Përdoruesi prek “Test Njoftimi” dhe merr një njoftim lokal provë. |
| **Rrjedha Alternative:** | Në mungesë lejesh, Sistemi kërkon leje për njoftime. |

---

Ky dokument i rasteve të përdorimit mbulon të gjithë funksionalitetin e versionit web dhe mund të shërbejë si një udhërrëfyes i qartë për zhvillimin e aplikacionit në Flutter. Çdo rast përdorimi mund të shndërrohet në një ose më shumë "user stories" në një metodologji Agile.