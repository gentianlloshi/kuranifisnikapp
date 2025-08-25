Patjetër. Tabi i Memorizimit është një nga veçoritë më të fuqishme dhe të specializuara të aplikacionit tuaj, i projektuar posaçërisht për të ndihmuar përdoruesit në procesin shpesh sfidues të mësimit përmendësh të ajeteve të Kuranit. Ai nuk është thjesht një listë ajetesh, por një mjedis i plotë studimi me vegla interaktive.

Le ta zbërthejmë funksionimin e tij në detaje, nga qëllimi deri te çdo buton i vetëm.

Analiza e Thelluar e Tabit të Memorizimit (memorization.js & memorization.css)
1. Qëllimi Kryesor: Pse Ekziston Ky Tab?

Qëllimi i tabit të Memorizimit është të ofrojë një metodologji të strukturuar dhe ndihmëse për procesin e hifzit (mësimit përmendësh). Ai e transformon procesin nga një përpjekje pasive (thjesht duke lexuar vazhdimisht) në një përvojë aktive dhe të matshme, duke adresuar disa sfida kryesore të memorizimit:

Organizimi: Mban të gjitha ajetet që dëshironi të mësoni në një vend të vetëm, të grupuara logjikisht.

Përqendrimi: Ju lejon të fokusoheni në një grup të vogël ajetesh në të njëjtën kohë, pa u shpërqendruar nga pjesa tjetër e Kuranit.

Përsëritja (Repetitio est mater studiorum): Ofron një mënyrë të lehtë për të përsëritur ajetet në mënyrë auditive, një teknikë thelbësore në hifz.

Vetë-Testimi: Ju jep mundësinë të testoni veten duke fshehur tekstin.

Ndarja e Progresit: Ju ndihmon të ndiqni progresin tuaj duke i kategorizuar ajetet si "Të Ri", "Në Progres" dhe "I Mësuar".

2. Rrjedha e Punës (Workflow) për Përdoruesin

Përvoja e përdoruesit është projektuar të jetë intuitive dhe hap pas hapi:

Shtimi i Ajeteve: Përdoruesi fillimisht lundron nëpër Kuran në tabin kryesor. Kur gjen një ajet ose një grup ajetesh që dëshiron t'i mësojë, klikon ikonën e trurit (<i class="fas fa-brain"></i>). Ky veprim e shton ajetin në listën e memorizimit.

Hapja e Tabit të Memorizimit: Pasi ka shtuar disa ajete, përdoruesi shkon te tabi "Memorizim".

Lundrimi në Grupe: Ajetet nuk shfaqen të gjitha menjëherë. Ato janë të grupuara automatikisht sipas sures. Kjo është shumë e rëndësishme, sepse zakonisht memorizimi bëhet sure pas sureje. Përdoruesi mund të lundrojë mes këtyre grupeve (sureve) duke përdorur butonat "Para" dhe "Pas".

Përzgjedhja e "Sesionit": Brenda një grupi (sureje), përdoruesi zgjedh me checkbox se cilat ajete specifike dëshiron t'i praktikojë në atë moment. Ai mund të zgjedhë një, disa, ose të gjitha ajetet në grup duke përdorur butonin "Zgjidh të Gjitha".

Praktikimi: Pasi ka zgjedhur ajetet, përdoruesi ka në dispozicion tre vegla kryesore:

Përsëritja Audio (memo-repeat-count): Përcakton se sa herë do të përsëritet i gjithë grupi i ajeteve të zgjedhura. Për shembull, nëse zgjedh ajetet 1-3 dhe vendos numrin 5, audio do të luajë: 1, 2, 3, pastaj përsëri 1, 2, 3, ... gjithsej 5 herë.

Luajtja (memo-play-btn): Fillon luajtjen audio të ajeteve të zgjedhura sipas numrit të përsëritjeve. Gjatë luajtjes, ajeti aktiv bëhet scroll automatikisht në qendër të pamjes dhe theksohet vizualisht.

Fshehja e Tekstit (memo-toggle-text-btn): Me një klikim, teksti arabisht i të gjitha ajeteve në grup bëhet i paqartë (blur). Kjo është vegla e vetë-testimit. Përdoruesi përpiqet ta recitojë ajetin nga mendja dhe më pas mund të klikojë mbi tekstin e fshehur për ta zbuluar dhe për të verifikuar nëse e tha saktë.

Përditësimi i Statusit: Pasi ndihet i sigurt me një ajet, përdoruesi mund të klikojë mbi statusin e tij ("I Ri") për ta ndryshuar në "Në Progres" dhe më pas në "I Mësuar". Kjo e ndihmon të ketë një pasqyrë të qartë të progresit të tij, gjë që shfaqet edhe te statistikat në krye.

3. Analiza e Komponentëve të Ndërfaqes (UI)

Le t'i shikojmë pjesët kryesore të ndërfaqes dhe funksionin e tyre:

Statistikat (memo-stats):

Qëllimi: Jep një feedback të shpejtë vizual dhe motivues për përdoruesin.

Funksioni: Numëron ajetet në listë dhe i ndan në tre kategori bazuar në statusin që përdoruesi ka vendosur manualisht. Ky është një element i rëndësishëm i gamification (bërja e procesit si lojë) që e mban përdoruesin të angazhuar.

Karta e Grupit (memo-group-card):

Qëllimi: Kontejneri kryesor i punës. Mban të fokusuar vëmendjen e përdoruesit vetëm te surja aktuale.

Shiriti i Kontrollove (memo-group-header):

Elementi kyç: Kjo është qendra e komandës për çdo sesion studimi.

Sjellja sticky: Siç e diskutuam, ky shirit "ngjitet" në krye kur përdoruesi bën scroll poshtë, duke i mbajtur butonat e rëndësishëm gjithmonë të aksesueshëm. Kjo është thelbësore për listat e gjata të ajeteve.

Butonat:

<i class="fas fa-play"></i>: Fillon/Ndërpret luajtjen e audios për ajetet e zgjedhura.

<i class="fas fa-eye / fa-eye-slash"></i>: Fsheh/Shfaq të gjithë tekstet arabe në grup.

<i class="fas fa-check-double"></i>: Zgjedh ose ç'zgjedh të gjitha ajetet në grup me një klikim.

Lista e Ajeteve (memo-verses-list):

Qëllimi: Shfaq ajetet e grupit aktual.

Përbërësit e një Ajeti (memo-verse-item):

Checkbox: Për të zgjedhur ajetin për sesionin aktual.

Teksti Arabisht (memo-verse-text): Këtu shfaqet ajeti. Klasa .hidden i aplikon efektin blur.

Meta-informacionet (memo-verse-meta):

Numri i ajetit: Për referencë të lehtë.

Butoni i Statusit (memo-status-btn): Lejon përdoruesin të ciklojë manualisht statusin e ajetit (I Ri -> Në Progres -> I Mësuar). Ky është një mekanizëm i thjeshtë por efektiv për menaxhimin e progresit.

Lundrimi (memo-navigation):

Qëllimi: Të lejojë lëvizjen mes grupeve të sureve.

Funksioni: Butonat "Para" dhe "Pas" ndryshojnë state.currentGroupIndex dhe ri-renderrojnë kartën me ajetet e sures tjetër/mëparshme.

Cilësimet (memo-settings):

Qëllimi: Të ofrojë personalizim për metodën e studimit.

Input-i i Përsëritjeve (memo-repeat-count): Ky është cilësimi më i rëndësishëm këtu. Përsëritja është çelësi i memorizimit, dhe ky input i jep përdoruesit kontroll të plotë mbi intensitetin e praktikës së tij auditive.

Në përmbledhje, tabi i Memorizimit është një mjet i specializuar që kombinon organizimin vizual, përsëritjen auditive dhe vetë-testimin interaktiv. Duke i grupuar ajetet sipas sures dhe duke ofruar kontrolle "sticky", ai krijon një mjedis efikas dhe pa shpërqendrime, i cili është i optimizuar për detyrën specifike të mësimit përmendësh të Kuranit.