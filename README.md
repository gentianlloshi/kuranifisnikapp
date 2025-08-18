# Kurani Fisnik - Flutter App

Aplikacion Flutter për leximin dhe studimin e Kuranit Fisnik në gjuhën shqipe.

## Përshkrimi

Ky aplikacion ofron një platformë të plotë për leximin, studimin dhe kërkimin në Kuranin Fisnik, i fokusuar te përdoruesit shqipfolës. Aplikacioni përmban përkthime të shumta në shqip, krahas tekstit origjinal arab dhe transliterimit latin.

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
- Persistim i indeksit të kërkimit (shmang rebuild çdo hapje)
- Field-weighted ranking (Arabic > Translation > Transliteration)
- Mini-player i përhershëm në fund gjatë navigimit
- Opsion për çaktivizim auto-scroll / reduktim animacionesh
- Light stemming për forma fjalësh (-it, -in, -ve)


