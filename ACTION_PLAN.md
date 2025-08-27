# Plan Veprimi i Unifikuar: Stabilizimi dhe Optimizimi i "Kurani Fisnik"

Data: 2025-08-27
Status: Miratuar (Release 1.1.0 është tag-uar)

Misioni: Stabilizim i plotë, eliminim i crash-eve/ngrirjeve dhe optimizim i performancës e memories, me verifikim përmes testeve dhe profilizimit.

## Faza 1 — Stabilizimi Kritik (Prioriteti më i lartë)

1. Crash në tab-in e Kërkimit
   - Shkaku: përdorim i `context.watch/select` jashtë `build` (p.sh., në callbacks). Skanim aktual: asnjë përdorim i drejtpërdrejtë `context.select/watch`; `Selector` përdoret në build, `context.read` në callbacks (OK).
   - Veprimi: Mbani këtë rregull — në callbacks përdorni vetëm `context.read<T>()`.
   - Verifikim: Navigoni në tab-in e kërkimit dhe bëni input; nuk duhet red screen.

2. Përkthimi që zhduket pas ndryshimeve të shfaqjes
   - Veprimi: Siguro `notifyListeners()` pas çdo ndryshimi në AppStateProvider; përdor imutabilitet (lista/objekt i ri) kur ndryshon opsionet e shfaqjes.
   - Verifikim: Togglo “Shfaq fjalë për fjalë” dhe “Opsionet e shfaqjes” — përkthimet mbeten të dukshme.

## Faza 2 — Refaktorimi Themelor i Performancës

1. Lazy-loading i plotë i të dhënave
   - Gjendja: Metas-only startup aktiv; verse-t ngarkohen on-demand për sure.
   - Veprime të vazhduara: Prefetch në navigim, enrichment async, parsing në isolate.
   - Verifikim: DevTools Memory në cold start → 0 instanca Verse.

2. Lazy Tab Views
   - Veprim: Përdorni IndexedStack + flamurë “constructed[]” ose AutomaticKeepAlive vetëm për tab-in aktiv në ndërtimin e parë.
   - Verifikim: Profilizim start-up — nuk ka ndërtim të panevojshëm të tab-eve.

## Faza 3 — UX

1. Auto-scroll gjatë audios
   - Veprim: Lidh auto-scroll me stream të pozicionit të audios ose indeksin e fjalës së theksuar; kontroll periodik të dukshmërisë.

2. Enkodimi i fonteve për “ë/ç”
   - Veprim: Siguro font me mbulim Latin Extended (p.sh. Lora/Noto Sans); përditëso ThemeData në titujt e Ndihmës.

## Faza 4 — Higjiena e Kodit dhe Verifikimi Final

1. Kontroll i rindërtimeve (Rebuild storms)
   - Veprim: Përdor `Selector` në vend të `Consumer` ku ka kuptim; vendos `const` ku mundet; shmang state changes në build.

2. Profilizim përfundimtar
   - Veprim: Nxirr build në `--profile` në pajisje fizike; kap snapshot-e (startup, kërkim, scroll të gjatë).

## Matje dhe Sukses
- Startup: pa bllokime; 0 Verse në memorie para hapjes së sures.
- Kërkim: pa stuhira rindërtimi; input 16ms frame budget.
- Scrolling: i qëndrueshëm me item keys dhe (ku e mundur) itemExtent/prototypeItem.
- Tests: të gjitha kalojnë; Analyzer: vetëm info-level lints.

## Shënime
- `CHANGELOG.md` dhe tag `v1.1.0` publikuar.
- Lint cleanup i vogël mund të bëhet në një PR vijues.
