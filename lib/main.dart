import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Providers
import 'package:kurani_fisnik_app/presentation/providers/app_state_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/quran_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/audio_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/bookmark_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/note_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/memorization_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/notification_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/texhvid_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/thematic_index_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/word_by_word_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/surah_selection_provider.dart';
// Verse action registry + selection service
import 'package:kurani_fisnik_app/presentation/widgets/verse_action_registry.dart';
import 'package:kurani_fisnik_app/presentation/providers/selection_service.dart';
import 'package:kurani_fisnik_app/presentation/providers/reading_progress_provider.dart';

// Pages and Widgets
import 'package:kurani_fisnik_app/presentation/pages/home_page.dart';
import 'package:kurani_fisnik_app/presentation/pages/enhanced_home_page.dart';

// Data Sources
import 'package:kurani_fisnik_app/data/datasources/local/quran_local_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/content_local_data_source.dart';

// Repositories
import 'package:kurani_fisnik_app/data/repositories/quran_repository_impl.dart';
import 'package:kurani_fisnik_app/data/repositories/storage_repository_impl.dart';
import 'package:kurani_fisnik_app/data/repositories/bookmark_repository_impl.dart';
import 'package:kurani_fisnik_app/data/repositories/texhvid_repository_impl.dart';
import 'package:kurani_fisnik_app/data/repositories/thematic_index_repository_impl.dart';
import 'package:kurani_fisnik_app/data/datasources/local/word_by_word_local_data_source.dart';
import 'package:kurani_fisnik_app/data/repositories/word_by_word_repository_impl.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_word_by_word_data_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_timestamp_data_usecase.dart';

// Use Cases
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_arabic_only_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/search_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surah_verses_usecase.dart' as get_verses;
import 'package:kurani_fisnik_app/domain/usecases/settings_usecases.dart';
import 'package:kurani_fisnik_app/domain/usecases/bookmark_usecases.dart';
// Specific single-use use cases already exist inside grouped files; use ones from texhvid_usecases & thematic_index_usecases
import 'package:kurani_fisnik_app/domain/usecases/texhvid_usecases.dart' show TexhvidUseCases; 
import 'package:kurani_fisnik_app/domain/usecases/thematic_index_usecases.dart' show GetThematicIndexUseCase; 

// Services
import 'package:kurani_fisnik_app/core/services/notification_service.dart';
import 'package:kurani_fisnik_app/core/services/audio_service.dart';
import 'presentation/theme/design_tokens.dart';
import 'presentation/theme/theme.dart';
import 'presentation/startup/startup_scheduler.dart';
import 'presentation/startup/performance_monitor.dart';
import 'core/utils/logger.dart';
// Dev performance overlay removed for cleaner UI.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupSw = Stopwatch()..start();
  Logger.configure();
  Logger.i('Startup: begin', tag: 'Startup');

  // Initialize Hive
  await Hive.initFlutter();

  Future<Box> openTimed(String name) async {
    final sw = Stopwatch()..start();
    final box = await Hive.openBox(name);
    Logger.d('Hive box $name opened in ${sw.elapsedMilliseconds}ms', tag: 'HiveInit');
    return box;
  }
  // Critical boxes only (keep cold start minimal).
  final quranBox = await openTimed("quranBox");
  final translationBox = await openTimed("translationBox");
  Logger.i('Startup: critical boxes opened elapsed=${startupSw.elapsedMilliseconds}ms', tag: 'Startup');

  // Non-critical boxes: open lazily (first use) or scheduled later.
  // We pass null to providers; they will open on demand.
  // Large static assets are cached in-memory; no Hive boxes for them
  const Box? thematicIndexBox = null;
  const Box? transliterationBox = null;
  const Box? wordByWordBox = null;
  const Box? timestampBox = null;

  // Defer heavy service initialization until after first frame to avoid jank.
  final notificationService = NotificationService();
  final audioService = AudioService();

  runApp(KuraniFisnikApp(
    notificationService: notificationService,
    audioService: audioService,
    quranBox: quranBox,
    translationBox: translationBox,
    thematicIndexBox: thematicIndexBox,
    transliterationBox: transliterationBox,
    wordByWordBox: wordByWordBox,
    timestampBox: timestampBox,
  ));
  // Schedule service init post-frame (slight delay) to yield UI.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final sw = Stopwatch()..start();
    await notificationService.initialize();
    await audioService.initialize();
    Logger.i('Deferred services initialized in ${sw.elapsedMilliseconds}ms', tag: 'Startup');
  });
  // First frame callback instrumentation
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Logger.i('Startup: first frame in ${startupSw.elapsedMilliseconds}ms', tag: 'Startup');
    // Defer a microtask to allow any phase 2 meta timing to be recorded by providers then output summary marker.
    Future.microtask(() {
      Logger.i('PerfSummary: firstFrameMs=${startupSw.elapsedMilliseconds}', tag: 'PerfSummary');
    });
  });
}

class KuraniFisnikApp extends StatelessWidget {
  final NotificationService notificationService;
  final AudioService audioService;
  final Box quranBox;
  final Box translationBox;
  final Box? thematicIndexBox;
  final Box? transliterationBox;
  final Box? wordByWordBox;
  final Box? timestampBox;

  const KuraniFisnikApp({
    super.key,
    required this.notificationService,
    required this.audioService,
    required this.quranBox,
    required this.translationBox,
  required this.thematicIndexBox,
  required this.transliterationBox,
  required this.wordByWordBox,
  required this.timestampBox,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<AudioService>.value(value: audioService),
        Provider<NotificationService>.value(value: notificationService),

        // Data Sources
        Provider<QuranLocalDataSource>(
          create: (_) => QuranLocalDataSourceImpl(
            quranBox: quranBox,
            translationBox: translationBox,
          ),
        ),
        Provider<StorageDataSource>(
          create: (_) => StorageDataSourceImpl(),
        ),
        Provider<ContentLocalDataSource>(
          create: (_) => ContentLocalDataSourceImpl(),
        ),
        Provider<WordByWordLocalDataSource>(
          create: (_) => WordByWordLocalDataSourceImpl(
            wordByWordBox: wordByWordBox,
            timestampBox: timestampBox,
          ),
        ),

        // Repositories
        ProxyProvider2<QuranLocalDataSource, StorageDataSource, QuranRepositoryImpl>(
          update: (_, localDataSource, storageDataSource, __) {
            final repo = QuranRepositoryImpl(localDataSource, storageDataSource);
            // Registration moved to first use site to reduce startup work.
            return repo;
          },
        ),
        ProxyProvider<StorageDataSource, StorageRepositoryImpl>(
          update: (_, storageDataSource, __) => StorageRepositoryImpl(storageDataSource),
        ),
        ProxyProvider<StorageDataSource, BookmarkRepositoryImpl>(
          update: (_, storageDataSource, __) => BookmarkRepositoryImpl(storageDataSource),
        ),
        // Texhvid & Thematic index repositories don't need StorageDataSource directly
        Provider<TexhvidRepositoryImpl>(
          create: (_) => TexhvidRepositoryImpl(),
        ),
        Provider<ThematicIndexRepositoryImpl>(
          create: (_) => ThematicIndexRepositoryImpl(),
        ),
        ProxyProvider<WordByWordLocalDataSource, WordByWordRepositoryImpl>(
          update: (_, ds, __) => WordByWordRepositoryImpl(localDataSource: ds),
        ),

        // Use Cases
        ProxyProvider<QuranRepositoryImpl, GetSurahsUseCase>(
          update: (context, repo, previous) => GetSurahsUseCase(repo),
        ),
        ProxyProvider<QuranRepositoryImpl, GetSurahsArabicOnlyUseCase>(
          update: (context, repo, previous) => GetSurahsArabicOnlyUseCase(repo),
        ),
        ProxyProvider<QuranRepositoryImpl, SearchVersesUseCase>(
          update: (context, repo, previous) => SearchVersesUseCase(repo),
        ),
        ProxyProvider<QuranRepositoryImpl, get_verses.GetSurahVersesUseCase>(
          update: (context, repo, previous) => get_verses.GetSurahVersesUseCase(repo),
        ),
        ProxyProvider<StorageRepositoryImpl, GetSettingsUseCase>(
          update: (_, repository, __) => GetSettingsUseCase(repository),
        ),
        ProxyProvider<StorageRepositoryImpl, SaveSettingsUseCase>(
          update: (_, repository, __) => SaveSettingsUseCase(repository),
        ),
  // Bookmark / thematic use cases grouped
        ProxyProvider<TexhvidRepositoryImpl, TexhvidUseCases>(
          update: (_, repository, __) => TexhvidUseCases(repository),
        ),
        ProxyProvider<ThematicIndexRepositoryImpl, GetThematicIndexUseCase>(
          update: (_, repository, __) => GetThematicIndexUseCase(repository),
        ),
        ProxyProvider<WordByWordRepositoryImpl, GetWordByWordDataUseCase>(
          update: (_, repo, __) => GetWordByWordDataUseCase(repository: repo),
        ),
        ProxyProvider<WordByWordRepositoryImpl, GetTimestampDataUseCase>(
          update: (_, repo, __) => GetTimestampDataUseCase(repository: repo),
        ),

        // Providers
  // App state provider depends on settings use cases
        ChangeNotifierProxyProvider2<GetSettingsUseCase, SaveSettingsUseCase, AppStateProvider>(
          create: (ctx) => AppStateProvider(getSettingsUseCase: Provider.of<GetSettingsUseCase>(ctx, listen: false), saveSettingsUseCase: Provider.of<SaveSettingsUseCase>(ctx, listen: false)),
          update: (_, getSettingsUseCase, saveSettingsUseCase, previous) => previous ?? AppStateProvider(getSettingsUseCase: getSettingsUseCase, saveSettingsUseCase: saveSettingsUseCase),
        ),
        ChangeNotifierProxyProvider6<GetSurahsUseCase, GetSurahsArabicOnlyUseCase, SearchVersesUseCase, get_verses.GetSurahVersesUseCase, QuranRepositoryImpl, AppStateProvider, QuranProvider>(
          create: (ctx) => QuranProvider(
            getSurahsUseCase: Provider.of<GetSurahsUseCase>(ctx, listen:false),
            getSurahsArabicOnlyUseCase: Provider.of<GetSurahsArabicOnlyUseCase>(ctx, listen:false),
            searchVersesUseCase: Provider.of<SearchVersesUseCase>(ctx, listen:false),
            getSurahVersesUseCase: Provider.of<get_verses.GetSurahVersesUseCase>(ctx, listen:false),
            quranRepository: Provider.of<QuranRepositoryImpl>(ctx, listen:false),
            appStateProvider: Provider.of<AppStateProvider>(ctx, listen:false),
          ),
          update: (ctx, getSurahsUseCase, getSurahsArabicOnlyUseCase, searchVersesUseCase, getSurahVersesUseCase, repo, appState, previous) => previous ?? QuranProvider(
            getSurahsUseCase: getSurahsUseCase,
            getSurahsArabicOnlyUseCase: getSurahsArabicOnlyUseCase,
            searchVersesUseCase: searchVersesUseCase,
            getSurahVersesUseCase: getSurahVersesUseCase,
            quranRepository: repo,
            appStateProvider: appState,
          ),
        ),

        // Additional Providers
        ChangeNotifierProvider<AudioProvider>(
          create: (ctx) => AudioProvider(),
          lazy: true,
        ),
        ProxyProvider<BookmarkRepositoryImpl, BookmarkUseCases>(
          update: (ctx, repo, previous) => BookmarkUseCases(repo),
        ),
        ChangeNotifierProxyProvider<BookmarkUseCases, BookmarkProvider>(
          create: (ctx) => BookmarkProvider(bookmarkUseCases: Provider.of<BookmarkUseCases>(ctx, listen: false)),
          update: (ctx, useCases, previous) => BookmarkProvider(bookmarkUseCases: useCases),
        ),
        ChangeNotifierProvider<NoteProvider>(
          create: (ctx) => NoteProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider<MemorizationProvider>(
          create: (ctx) => MemorizationProvider(),
          lazy: true,
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (ctx) => NotificationProvider(service: notificationService),
          lazy: true,
        ),
        ChangeNotifierProxyProvider<TexhvidUseCases, TexhvidProvider>(
          create: (ctx) => TexhvidProvider(texhvidUseCases: Provider.of<TexhvidUseCases>(ctx, listen:false)),
          update: (ctx, texhvidUseCases, previous) => TexhvidProvider(texhvidUseCases: texhvidUseCases),
        ),
        ChangeNotifierProxyProvider<GetThematicIndexUseCase, ThematicIndexProvider>(
          create: (ctx) => ThematicIndexProvider(getThematicIndexUseCase: Provider.of<GetThematicIndexUseCase>(ctx, listen:false)),
          update: (ctx, getThematicIndexUseCase, previous) => ThematicIndexProvider(getThematicIndexUseCase: getThematicIndexUseCase),
        ),
        ChangeNotifierProxyProvider2<GetWordByWordDataUseCase, GetTimestampDataUseCase, WordByWordProvider>(
          create: (ctx) => WordByWordProvider(
            getWordByWordDataUseCase: Provider.of<GetWordByWordDataUseCase>(ctx, listen: false),
            getTimestampDataUseCase: Provider.of<GetTimestampDataUseCase>(ctx, listen: false),
          ),
          update: (ctx, wUse, tUse, prev) => WordByWordProvider(
            getWordByWordDataUseCase: wUse,
            getTimestampDataUseCase: tUse,
          ),
        ),
        ChangeNotifierProvider<SurahSelectionProvider>(
          create: (ctx) => SurahSelectionProvider(),
          lazy: true,
        ),
        ChangeNotifierProxyProvider<StorageRepositoryImpl, ReadingProgressProvider>(
          create: (ctx) => ReadingProgressProvider(storage: Provider.of<StorageRepositoryImpl>(ctx, listen:false)),
          update: (ctx, storageRepo, previous) => ReadingProgressProvider(storage: storageRepo),
        ),
        ChangeNotifierProvider<VerseActionRegistry>(
          create: (ctx) => VerseActionRegistry()
            ..registerAll([
              VerseAction(
                id: 'play',
                label: 'Luaj këtë ajet',
                icon: Icons.play_arrow,
                handler: (ctx, verse) async {
                  ctx.read<AudioProvider>().playVerse(verse);
                },
              ),
              VerseAction(
                id: 'play_from_here',
                label: 'Luaj nga ky ajet',
                icon: Icons.playlist_play,
                handler: (ctx, verse) async {
                  final q = ctx.read<QuranProvider>();
                  final verses = q.currentVerses;
                  final startIndex = verses.indexWhere((v) => v.number == verse.number);
                  if (startIndex != -1) {
                    final wbwProv = ctx.read<WordByWordProvider>();
                    ctx.read<AudioProvider>().playSurah(verses, startIndex: startIndex, wbwProvider: wbwProv);
                  }
                },
              ),
              VerseAction(
                id: 'memorization_toggle',
                label: 'Ndrysho Status Memorizimi',
                icon: Icons.psychology,
                handler: (ctx, verse) async {
                  final mem = ctx.read<MemorizationProvider>();
                  mem.toggleVerseMemorization('${verse.surahNumber}:${verse.number}');
                },
              ),
            ]),
        ),
        // Global selection service (multi-domain selection future)
        ChangeNotifierProvider<SelectionService>(
          create: (ctx) => SelectionService(),
          lazy: true,
        ),
      ],
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          // Update logger suppression dynamically (cheap)
          Logger.configure(
            suppressTags: appState.verboseWbwLogging ? {} : {'WBW'},
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Breakpoints: <360 0.95, 360-599 1.0, 600-839 1.1, >=840 1.2
              double scaleFactor;
              if (width < 360) {
                scaleFactor = 0.95;
              } else if (width < 600) {
                scaleFactor = 1.0;
              } else if (width < 840) {
                scaleFactor = 1.1;
              } else {
                scaleFactor = 1.2;
              }
              final theme = _resolveTheme(appState.currentTheme, scaleFactor: scaleFactor);
              // Register post-frame startup scheduler once.
        WidgetsBinding.instance.addPostFrameCallback((_) {
                // Use a dedicated element context to start scheduler (once).
                if (context.findAncestorWidgetOfExactType<_StartupSchedulerMarker>() == null) {
                  // Insert marker by rebuilding below (simpler: just start scheduler directly)
                  final scheduler = StartupScheduler(context);
                  scheduler.start();
          PerformanceMonitor.ensureStarted();
                }
              });
              return _StartupSchedulerMarker(
                child: MaterialApp(
                  title: 'Kurani Fisnik',
                  debugShowCheckedModeBanner: false,
                  theme: theme,
                  // No dev perf overlay; return the child as-is.
                  builder: (context, child) => child ?? const SizedBox.shrink(),
                  home: const EnhancedHomePage(),
                  routes: {
                    '/home': (context) => const EnhancedHomePage(),
                    '/quran': (context) => const HomePage(),
                    '/search': (context) => const HomePage(),
                    '/bookmarks': (context) => const HomePage(),
                    '/notes': (context) => const HomePage(),
                    '/memorization': (context) => const HomePage(),
                    '/texhvid': (context) => const HomePage(),
                    '/thematic': (context) => const HomePage(),
                    '/settings': (context) => const HomePage(),
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  ThemeData _resolveTheme(String themeName, {double scaleFactor = 1.0}) {
    switch (themeName) {
      case 'dark':
        return buildAppTheme(buildMinimalDarkScheme(), scaleFactor: scaleFactor);
      case 'sepia':
        return buildAppTheme(buildSepiaScheme(Brightness.light), scaleFactor: scaleFactor);
      case 'midnight':
        return buildAppTheme(buildDeepBlueScheme(Brightness.dark), scaleFactor: scaleFactor);
      default:
        return buildAppTheme(buildDeepBlueScheme(Brightness.light), scaleFactor: scaleFactor);
    }
  }
}

// Marker widget to ensure we only start scheduler once; carries child tree.
class _StartupSchedulerMarker extends InheritedWidget {
  const _StartupSchedulerMarker({required super.child});
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
