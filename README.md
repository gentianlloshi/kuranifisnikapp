# Kurani Fisnik - Flutter App

[![Flutter CI](https://github.com/gentianlloshi/kuranifisnikapp/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/gentianlloshi/kuranifisnikapp/actions/workflows/flutter-ci.yml)

Aplikacion Flutter për leximin dhe studimin e Kuranit Fisnik në gjuhën shqipe.

## Përshkrimi

Ky aplikacion ofron një platformë të plotë për leximin, studimin dhe kërkimin në Kuranin Fisnik, i fokusuar te përdoruesit shqipfolës. Aplikacioni përmban përkthime të shumta në shqip, krahas tekstit origjinal arab dhe transliterimit latin.

## Çfarë ka të re (24 Gusht 2025)

 - Indeksi Tematik: Ikona sipas kategorisë, parapamje e lehtë për vargje (snippet i ajetit të parë ose “S–E”), bottom sheet me bosh/placeholder miqësor. Kërkimi tani thekson rezultatet dhe zgjeron kategoritë automatikisht. “Shko te ajeti/rangu” skrollon në krye te ajeti i parë dhe thekson vargun ~6s.
 - Kërkimi (UI): Ngjyrosje me kontrast më të lartë për pjesët e përputhura në listime.
 - Memorizimi: Tab i ri me kokë “sticky”, statistika globale/aktive, navigim mes grupeve (sure), maskim teksti me “Prek për të parë”, përzgjedhje e ajeve, status ciklik (I Ri → Në Progres → I Mësuar), dhe kontroll i përsëritjeve të seancës.
 - Stabilitet: Pastrim i kodit të indeksit tematik dhe teste të reja për utilitetet e parapamjes/ikonave.
 - Performanca në start: StartupScheduler tani hap kutitë jo-kritike të Hive me vonesa të shkallëzuara pas kornizës së parë (thematicIndexBox, transliterationBox, wordByWordBox, timestampBox) për të shmangur burst I/O dhe jank.

## Karakteristikat Kryesore

### ✅ Të Implementuara Plotësisht

#### Shtresa e të Dhënave (Data Layer)
- ✅ Modele Dart për entitetet (Surah, Verse, Translation, etj.)
- ✅ LocalDataSource për ngarkimin e JSON me mbështetje për caching (Hive)
- ✅ Ruajtja lokale (shared_preferences dhe Hive)

#### Shtresa e Domenit (Domain Layer)
- ✅ Entitetet e domenit
- ✅ Rastet e përdorimit (Use Cases)
- ✅ Ndërfaqet e depove (Repository interfaces)

#### Shtresa e Prezantimit (Presentation Layer)
- ✅ Ekranet kryesore
- ✅ Widget-et e ripërdorshme
- ✅ Menaxhimi i gjendjes (Provider)
- ✅ Navigimi

#### Funksionalitetet Kryesore
- ✅ **Leximi i Kuranit** - Pamje e plotë e Kuranit me përkthime dhe mbështetje për lazy loading të ajeteve.
- ✅ **Kërkimi në tekst** - Indeks i invertuar (prefix + normalizim diakritik) në isolate + highlight i qartë
- ✅ **Sistemi i favoriteve** - Ruajtja e ajeteve të preferuara
- ✅ **Shënimet personale** - Mbajtja e shënimeve për ajete
- ✅ **Cilësimet e aplikacionit** - Personalizimi i përvojës
- ✅ **Temat vizuale** - Dritë/Errët/Sepia/Mesnatë

#### Funksionalitete të Avancuara
- ✅ **Texhvid dhe kuizet** - Mësimi i rregullave të leximit me kuize interaktive
- ✅ **Indeksi tematik** - Gjetur ajete sipas temave dhe koncepteve
- ✅ **Luajtja e audios** - Playlist i plotë për sure, prefetch i skedarëve, retry & cache lokale
- ✅ **Highlight Word-by-Word (Audio Sync)** - Sinkronizim i fjalëve me audio me shtrirje të segmenteve frazë → fjalë + pointer incremental (performant)
- 🟡 **Memorizimi i ajeteve** - Bazë funksionale; mungojnë mjete të avancuara (maskim teksti, SRS)
- 🟡 **Gjenerimi i imazheve** - Implementim ekziston por kërkon rifaktorizim UI + temë të re eksporti


### 🚀 Optimizime dhe Përmirësime

- ✅ **Lazy Loading Ajete**: `ListView.builder` + ngarkim incremental për sure të gjata.
- ✅ **Caching i të Dhënave**: Surah / përkthime / transliterime / index tematik në Hive (offline ready).
- ✅ **Parsimi në Isolate**: JSON voluminoz zhvendosur off-main për të reduktuar frame skips në start.
- ✅ **Indeksi i Kërkimit**: Ndërtim në isolate + debounce 350ms → kërkime të rrjedhshme gjatë shkrimit.
 - ✅ **Indeks i Parandërtuar (opsional)**: Mund të krijoni `assets/data/search_index.json` me `dart run tool/build_search_index.dart` për start edhe më të shpejtë; aplikacioni e ngarkon automatikisht nëse ekziston.
- ✅ **Highlight i Rafinuar**: Sfondo i verdhë me kontrast të lartë (dark-mode toned) për rezultatet e kërkimit.
- ✅ **Auto-Scroll Audio**: Ajeti aktiv mbahet në viewport (alignment 0.1 + throttling + suppression pas scroll manual).
- ✅ **Audio Stability**: Eliminim i ndërprerjeve me `ConcatenatingAudioSource` + prefetch/depozitim lokalisht.
- ✅ **Word Index Engine**: Pointer incremental + throttling (≈55ms) → zero skanime të plota për çdo frame.

### 🧪 Testimi

Janë krijuar teste unitare për disa nga rastet e përdorimit dhe implementimet e depove (`GetSurahsUseCase`, `SearchVersesUseCase`, `QuranRepositoryImpl`). Këto teste sigurojnë që logjika e biznesit dhe shtresa e të dhënave funksionojnë siç pritet. Për shkak të kufizimeve të mjedisit, testet nuk u ekzekutuan plotësisht, por struktura dhe kodimi i tyre janë në vend për testime të mëtejshme.

## Struktura e Projektit

```
lib/
├── core/                          # Funksionalitete të përgjithshme (shërbime, utilitete, menaxhim gabimesh)
│   ├── error/                     # Menaxhimi i gabimeve
│   ├── services/                  # Shërbime si audio, njoftime
│   └── utils/                     # Utilitete dhe konstante
├── data/
│   ├── datasources/               # Burimet e të dhënave (lokale dhe të jashtme)
│   │   ├── local/                 # Të dhënat lokale (JSON, Hive)
│   │   └── remote/                # API-të e jashtme (nëse ka)
│   ├── models/                    # Modelet e të dhënave (DTOs)
│   └── repositories/              # Implementimet e depove
├── domain/
│   ├── entities/                  # Entitetet e domenit
│   ├── repositories/              # Ndërfaqet e depove
│   └── usecases/                  # Rastet e përdorimit (logjika e biznesit)
├── presentation/
│   ├── pages/                     # Ekranet kryesore
│   ├── widgets/                   # Widget-e të ripërdorshme
│   ├── providers/                 # Menaxhimi i gjendjes (Provider)
│   └── router/                    # Navigimi (nëse përdoret go_router)
└── assets/
    ├── data/                      # Skedarët JSON
    ├── fonts/                     # Fontet arabe dhe shqipe
    └── images/                    # Imazhet
```

## Të Dhënat

Aplikacioni përmban:

- **Teksti arab i Kuranit** - Teksti origjinal i plotë
- **Përkthime shqipe**:
  - Përkthimi i Sherif Ahmetit
  - Përkthimi i Hasan Mehdiut
  - Përkthimi i Feti Mehes
- **Transliterimet latine** - Për ndihmë në lexim
- **Indeksi tematik** - Ajete të grupuara sipas temave
- **Rregullat e Texhvidit** - Me shembuj dhe kuize
- **Lutjet dhe hadithet** - Përmbajtje shtesë

## Instalimi dhe Përdorimi

### Parakushtet

- Flutter SDK (versioni 3.0 ose më i ri)
- Dart SDK
- Android Studio / VS Code
- Emulator ose pajisje fizike

### Hapat e Instalimit

1. **Klononi projektin**
   ```bash
   git clone [repository-url]
   cd kurani_fisnik_flutter
   ```

2. **Instaloni varësitë**
   ```bash
   flutter pub get
   ```

3. **Gjeneroni skedarët Hive (vetëm pas ndryshimeve në entitete)**
4. **(Opsionale) Ndërtoni indeksin e kërkimit si asset**
   ```powershell
   dart run tool/build_search_index.dart
   ```
   Skedari `assets/data/search_index.json` do të ngarkohet automatikisht në start duke eliminuar ndërtimin në pajisje.
   ```bash
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

4. **Konfiguroni asetet**
   - Sigurohuni që të gjithë skedarët JSON janë në `assets/data/`
   - Fontet janë në `assets/fonts/`

5. **Ekzekutoni aplikacionin**
   ```bash
   flutter run
   ```

### Ndërtimi për Prodhim

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Arkitektura

Aplikacioni ndjek parimet e **Clean Architecture**:

- **Presentation Layer**: UI dhe menaxhimi i gjendjes
- **Domain Layer**: Logjika e biznesit dhe entitetet
- **Data Layer**: Burimet e të dhënave dhe ruajtja

### Menaxhimi i Gjendjes

Përdoret **Provider** për menaxhimin e gjendjes:

- `AppStateProvider` - Gjendja globale e aplikacionit
- `QuranProvider` - Të dhënat e Kuranit
- `BookmarkProvider` - Favoritet
- `NoteProvider` - Shënimet
- `TexhvidProvider` - Rregullat e Texhvidit
- `ThematicIndexProvider` - Indeksi tematik
- `AudioProvider` - Menaxhimi i luajtjes dhe shkarkimit të audios

## Kontributi

Për të kontribuar në projekt:

1. Fork projektin
2. Krijoni një branch të ri (`git checkout -b feature/AmazingFeature`)
3. Commit ndryshimet (`git commit -m \'Add some AmazingFeature\'`) 
4. Push në branch (`git push origin feature/AmazingFeature`)
5. Hapni një Pull Request

### Contributing – Checks & Workflows

- CI: Çdo PR/push ekzekuton:
   - `flutter analyze --no-fatal-infos --no-fatal-warnings`
   - `flutter test --coverage`
   - Statusi i CI tregohet nga badge më sipër. Coverage ngarkohet si artifact (lcov.info).
- Seed Issues: Workflow “Seed Issues” krijon labels/milestone/issues nga `.github/issues_seed.json`.
   - Mund të ekzekutohet me `dry_run=true` për verifikim.
   - `fail_on_noop=false` (default) nuk dështojnë kur s’ka asgjë të re për t’u krijuar.

Rregulla PR:
- Ruani startup-in “lazy-by-default” (pa Verse të hidratuara në cold start).
- Shmangni punë të rënda në thread-in kryesor; preferoni `compute`/isolate.
- Për kërkim: mos nisni `ensureBuilt()` në start; përdorni incremental build kur hapet Search.
- Shtoni teste për rrjedhat e reja dhe azhurnoni `issues_seed.json` kur krijoni epics.

## Licenca

Ky projekt është i licensuar nën [MIT License](LICENSE).

## Kontakti

Për pyetje ose sugjerime, kontaktoni:
- Email: [your-email@example.com]
- GitHub: [your-github-username]

## Falënderime

- Përkthyesit e Kuranit në gjuhën shqipe
- Komuniteti Flutter
- Kontribuesit e projektit

---

**Shënim**: Ky aplikacion është krijuar për qëllime edukative dhe fetare. Përmbajtja e Kuranit është marrë nga burime të besueshme, por rekomandohet verifikimi me burime zyrtare për studime të thella.

---
### 🔄 Roadmap i Afërt
- Persistim i indeksit të kërkimit (snapshot incremental është në vend; zgjerim për invalidim/verzionim)
- Field-weighted ranking i përmirësuar (aktualisht ka pesha bazike; nevojitet kalibrim dhe BM25-lite)
- Mini-player i përhershëm në fund gjatë navigimit
- Opsion për çaktivizim auto-scroll / reduktim animacionesh
- Normalizim morfologjik: rritje e mbulimit të prapashtesave dhe testim i regression-eve


