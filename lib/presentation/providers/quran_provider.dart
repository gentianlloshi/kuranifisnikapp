import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/surah.dart';
import '../../domain/entities/surah_meta.dart';
import '../../domain/entities/verse.dart';
import '../../domain/usecases/get_surahs_usecase.dart';
import '../../domain/usecases/get_surahs_arabic_only_usecase.dart';
import 'package:kurani_fisnik_app/core/utils/result.dart';
import '../../domain/usecases/search_verses_usecase.dart';
import '../../domain/usecases/get_surah_verses_usecase.dart';
import 'search_index_manager.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../core/metrics/perf_metrics.dart';

class QuranProvider extends ChangeNotifier {
  final GetSurahsUseCase? _getSurahsUseCase;
  final GetSurahsArabicOnlyUseCase? _getSurahsArabicOnlyUseCase;
  final SearchVersesUseCase? _searchVersesUseCase;
  final GetSurahVersesUseCase? _getSurahVersesUseCase;
  final QuranRepository? _quranRepository; // for on-demand enrichment

  final SearchIndexManager? _indexManager; // null in simple ctor
  StreamSubscription<SearchIndexProgress>? _indexProgressSub;
  // Debounce for progress-driven search result refreshes
  Timer? _resultsRefreshDebounce;
  double _lastNotifiedProgress = -1;
  DateTime? _lastProgressNotifyAt;

  QuranProvider({
    required GetSurahsUseCase getSurahsUseCase,
    required GetSurahsArabicOnlyUseCase getSurahsArabicOnlyUseCase,
    required SearchVersesUseCase searchVersesUseCase,
    required GetSurahVersesUseCase getSurahVersesUseCase,
    QuranRepository? quranRepository,
  })  : _getSurahsUseCase = getSurahsUseCase,
        _getSurahsArabicOnlyUseCase = getSurahsArabicOnlyUseCase,
        _searchVersesUseCase = searchVersesUseCase,
        _getSurahVersesUseCase = getSurahVersesUseCase,
        _quranRepository = quranRepository,
        _indexManager = SearchIndexManager(
          getSurahsUseCase: getSurahsUseCase,
          getSurahVersesUseCase: getSurahVersesUseCase,
        ) {
    _init();
    // Subscribe to live progress stream with throttling to avoid rebuild storms
    _indexProgressSub = _indexManager?.progressStream.listen((evt) {
      _isBuildingIndex = !evt.complete;
      _indexProgress = evt.progress;
      // Update perf metrics coverage (index fraction). Enrichment coverage handled in repo merges.
      PerfMetrics.instance.setIndexCoverage(evt.progress);
      // If user has an active query, refresh results as the index grows, but debounce updates
      if (_lastQuery.isNotEmpty) {
        _scheduleResultsRefresh();
      }
      // Throttle UI notifications for progress bar to at most ~every 300ms or on >=2% progress delta or on completion
      final now = DateTime.now();
      final shouldNotify = evt.complete ||
          _lastNotifiedProgress < 0 ||
          (evt.progress - _lastNotifiedProgress) >= 0.02 ||
          (now.difference(_lastProgressNotifyAt ?? DateTime.fromMillisecondsSinceEpoch(0)).inMilliseconds >= 300);
      if (shouldNotify) {
        _lastNotifiedProgress = evt.progress;
        _lastProgressNotifyAt = now;
        notifyListeners();
      }
    });
  }

  // Simplified constructor for basic functionality without use cases
  QuranProvider.simple()
      : _getSurahsUseCase = null,
        _getSurahsArabicOnlyUseCase = null,
        _searchVersesUseCase = null,
        _getSurahVersesUseCase = null,
        _quranRepository = null,
        _indexManager = null;
  
  Future<void> _init() async {
    if (_surahsMeta.isEmpty && _getSurahsArabicOnlyUseCase != null) {
      Future.delayed(const Duration(milliseconds: 10), () async {
        await loadSurahMetasArabicOnly();
      });
    }
  // Do NOT build the search index at init to avoid instantiating Verse objects at startup.
  // StartupScheduler (Phase 3) or user actions (search) will trigger incremental build later.
  }

  // Metadata-only list (no verse bodies) to reduce startup memory.
  List<SurahMeta> _surahsMeta = [];
  List<Verse> _allCurrentSurahVerses = []; // full list for current surah
  final Map<int, List<Verse>> _prefetchCache = {}; // surahNumber -> verses (prefetched)
  List<Verse> _pagedVerses = []; // verses exposed with pagination
  List<Verse> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  int? _currentSurahId;
  Surah? _currentSurah;
  bool _hasMoreVerses = false;
  int _loadedVerseCount = 0;
  static const int _pageSize = 20;
  // Pending scroll target (verse number) after loading a surah, used for smooth scroll from search / bookmarks
  int? _pendingScrollVerseNumber;
  // Pending highlight range on arrival (inclusive), used to softly highlight verses after navigation
  int? _pendingHighlightStartVerseNumber;
  int? _pendingHighlightEndVerseNumber;
  // Search indexing (delegated)
  bool _isBuildingIndex = false; // mirrors manager state for UI convenience
  double _indexProgress = 0;
  bool get isBuildingIndex => _isBuildingIndex;
  double get indexProgress => _indexProgress;
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 350);
  bool _userTriggeredIndexOnce = false; // suppress duplicate logs
  String _lastQuery = '';

  List<SurahMeta> get surahs => _surahsMeta;
  List<Verse> get currentVerses => _pagedVerses;
  List<Verse> get fullCurrentSurahVerses => _allCurrentSurahVerses;
  List<Verse> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get currentSurahId => _currentSurahId;
  Surah? get currentSurah => _currentSurah;
  bool get hasMoreVerses => _hasMoreVerses;
  // Expose underlying repository for debug / metrics panels (read-only usage)
  QuranRepository? get repository => _quranRepository;

  Future<void> loadSurahs() async {
    _setLoading(true);
    try {
      // Prefer Arabic-only meta list to keep memory footprint small
      final uc = _getSurahsArabicOnlyUseCase ?? _getSurahsUseCase;
      if (uc == null) return;
      final List<Surah> surahModels;
      if (uc is GetSurahsArabicOnlyUseCase) {
        surahModels = await uc.call();
      } else if (uc is GetSurahsUseCase) {
        final res = await uc.call();
        if (res is Success<List<Surah>>) {
          surahModels = res.value;
        } else {
          _error = res.error?.message ?? 'Unknown error';
          _setLoading(false);
          return;
        }
      } else {
        surahModels = const <Surah>[];
      }
      if (surahModels.isNotEmpty) {
        final sw = Stopwatch()..start();
        final all = surahModels.map((s) => SurahMeta.fromSurah(s.copyWith(verses: const []))).toList();
        // Incremental publication in small batches for earlier first paint.
        _surahsMeta = [];
        final batchSize = 25;
        for (int i = 0; i < all.length; i += batchSize) {
          final end = (i + batchSize) > all.length ? all.length : (i + batchSize);
          _surahsMeta.addAll(all.sublist(i, end));
          notifyListeners();
          // Yield control between batches (except last) to allow frames.
          if (end < all.length) {
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }
        Logger.d('Loaded surah metadata count=${_surahsMeta.length} in ${sw.elapsedMilliseconds}ms', tag: 'StartupPhase');
        _error = null;
      } else {
        _error = 'No surahs loaded';
      }
    } catch (e) {
      _error = e.toString(); // fallback if unexpected exception
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadSurahMetasArabicOnly() async {
    _setLoading(true);
    try {
  final uc = _getSurahsArabicOnlyUseCase; if (uc == null) return; final surahs = await uc.call();
      final sw = Stopwatch()..start();
      final all = surahs.map((s) => SurahMeta.fromSurah(s)).toList();
      _surahsMeta = [];
      const batchSize = 25;
      for (int i = 0; i < all.length; i += batchSize) {
        final end = (i + batchSize) > all.length ? all.length : (i + batchSize);
        _surahsMeta.addAll(all.sublist(i, end));
        notifyListeners();
        if (end < all.length) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }
      Logger.d('Loaded Arabic-only metas count=${_surahsMeta.length} in ${sw.elapsedMilliseconds}ms', tag: 'StartupPhase');
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  int? _activeJuzFilter;
  bool _filterTranslation = true;
  bool _filterArabic = true;
  bool _filterTransliteration = true;

  void setJuzFilter(int? juz) {
    _activeJuzFilter = juz;
    notifyListeners();
  }

  void setFieldFilters({bool? translation, bool? arabic, bool? transliteration}) {
    if (translation != null) _filterTranslation = translation;
    if (arabic != null) _filterArabic = arabic;
    if (transliteration != null) _filterTransliteration = transliteration;
    notifyListeners();
  }

  int? get activeJuzFilter => _activeJuzFilter;
  bool get filterTranslation => _filterTranslation;
  bool get filterArabic => _filterArabic;
  bool get filterTransliteration => _filterTransliteration;

  Future<void> searchVerses(String query) async {
    _lastQuery = query.trim();
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    if (_indexManager != null) {
      // Kick incremental build if not started yet (returns immediately) – user-driven start.
  final mgr = _indexManager; // promote for null-safe access
  final wasIdle = !(mgr.isBuilding) && indexProgress <= 0.0;
  mgr.ensureIncrementalBuild();
      if (wasIdle && !_userTriggeredIndexOnce) {
        _userTriggeredIndexOnce = true;
        Logger.i('Index build triggered by user search input', tag: 'SearchIndex');
      }
      // Perform search over currently indexed subset (results will improve as index grows)
  _searchResults = (mgr.search(
        query,
        juzFilter: _activeJuzFilter,
        includeTranslation: _filterTranslation,
        includeArabic: _filterArabic,
        includeTransliteration: _filterTransliteration,
  ));
      assert(() {
        // ignore: avoid_print
        print('[SearchDBG] Provider.searchVerses results=${_searchResults.length} query="$query"');
        return true;
      }());
      _error = null;
      notifyListeners();
      return;
    }
  final uc = _searchVersesUseCase;
  if (uc != null) {
      _setLoading(true);
      try {
        _searchResults = await uc.call(query);
        _error = null;
      } catch (e) {
        _error = e.toString();
        _searchResults = [];
      } finally {
        _setLoading(false);
      }
    }
  }

  void searchVersesDebounced(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      searchVerses(query);
    });
  }

  Future<void> loadSurahVerses(int surahId) async {
    _setLoading(true);
    try {
      if (_prefetchCache.containsKey(surahId)) {
        final cached = _prefetchCache.remove(surahId);
        if (cached != null) {
          _allCurrentSurahVerses = cached;
        } else {
          _allCurrentSurahVerses = [];
        }
      } else {
        final uc = _getSurahVersesUseCase;
        if (uc == null) {
          _allCurrentSurahVerses = [];
        } else {
          // Only fetch verses for the requested surah (Arabic-only); enrichment is done on-demand
          _allCurrentSurahVerses = await uc.call(surahId);
        }
      }
  Logger.d('Loaded verses surah=$surahId count=${_allCurrentSurahVerses.length}', tag: 'LazySurah');
  // Attempt on-demand enrichment (translation + transliteration) asynchronously without blocking UI.
      // We resolve repository via context-less global if needed; better would be dependency injection; skipping for brevity.
      // ignore: unawaited_futures
  final repo = _quranRepository;
  if (repo != null) {
        // Fire-and-forget enrichment: translation then transliteration.
        Future(() async {
          try {
            // Respect current field filters: only enrich what’s needed.
            final needT = _filterTranslation && !repo.isSurahFullyEnriched(surahId);
            if (needT) {
              await repo.ensureSurahTranslation(surahId);
              Logger.d('Surah $surahId translation enriched', tag: 'LazySurah');
            }
            final needTr = _filterTransliteration && !repo.isSurahFullyEnriched(surahId);
            if (needTr) {
              await repo.ensureSurahTransliteration(surahId);
              Logger.d('Surah $surahId transliteration enriched', tag: 'LazySurah');
            }
            // After enrichment, re-fetch the current surah verses once to merge enriched fields,
            // then re-apply pagination without jank.
            if (needT || needTr) {
              try {
                final enriched = await (_getSurahVersesUseCase?.call(surahId) ?? Future.value(<Verse>[]));
                // Replace only if we are still on the same surah
                if (_currentSurahId == surahId && enriched.isNotEmpty) {
                  _allCurrentSurahVerses = enriched;
                  // Recreate paged window preserving the already loaded count
                  final prevLoaded = _loadedVerseCount;
                  _pagedVerses = [];
                  _loadedVerseCount = 0;
                  _hasMoreVerses = false;
                  while (_loadedVerseCount < prevLoaded && _loadedVerseCount < _allCurrentSurahVerses.length) {
                    _appendMoreVerses();
                  }
                  // If nothing loaded yet, publish first page
                  if (prevLoaded == 0 && _pagedVerses.isEmpty) {
                    _appendMoreVerses();
                  }
                }
              } catch (_) {}
              notifyListeners();
            }
          } catch (e) {
            Logger.w('Enrichment failed surah=$surahId err=$e', tag: 'LazySurah');
          }
        });
      }
  _currentSurahId = surahId;
  // Preserve existing meta fields in _currentSurah (already set in navigateToSurah) and just attach verses after pagination.
  final currentNumber = _currentSurah?.number;
  if (_currentSurah == null || currentNumber != surahId) {
        _currentSurah = Surah(
          id: surahId,
          number: surahId,
          nameArabic: '',
          nameTranslation: '',
          nameTransliteration: '',
          revelation: '',
          versesCount: _allCurrentSurahVerses.length,
          verses: const [],
        );
  }
      _loadedVerseCount = 0;
      _pagedVerses = [];
      _appendMoreVerses();
      // If a pending scroll/highlight target exists beyond the first page, load enough pages to include it
      if (_pendingScrollVerseNumber != null) {
        final targetIdx = _allCurrentSurahVerses.indexWhere((v) => v.verseNumber == _pendingScrollVerseNumber);
        if (targetIdx != -1 && targetIdx >= _loadedVerseCount) {
          final needed = ((targetIdx + 1) - _loadedVerseCount);
          if (needed > 0) {
            int morePages = (needed / _pageSize).ceil();
            while (morePages > 0 && _hasMoreVerses) {
              _appendMoreVerses();
              morePages--;
            }
          }
        }
      }
      // Also ensure pending highlight range end is included to fully highlight the range
      if (_pendingHighlightEndVerseNumber != null) {
        final endIdx = _allCurrentSurahVerses.indexWhere((v) => v.verseNumber == _pendingHighlightEndVerseNumber);
        if (endIdx != -1 && endIdx >= _loadedVerseCount) {
          final needed = ((endIdx + 1) - _loadedVerseCount);
          if (needed > 0) {
            int morePages = (needed / _pageSize).ceil();
            while (morePages > 0 && _hasMoreVerses) {
              _appendMoreVerses();
              morePages--;
            }
          }
        }
      }
      _error = null;
  // Opportunistic prefetch of next surah early (after first page) for chaining smoothness
  _maybePrefetchNextSurah(surahId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  Future<void> navigateToSurah(int surahNumber) async {
    if (_surahsMeta.isEmpty) {
      if (_getSurahsArabicOnlyUseCase != null) {
        await loadSurahMetasArabicOnly();
      } else if (_getSurahsUseCase != null) {
        await loadSurahs();
      }
    }
    final meta = _surahsMeta.firstWhere(
      (s) => s.number == surahNumber,
      orElse: () => SurahMeta(
        number: surahNumber,
        nameArabic: '—',
        nameTransliteration: '—',
        nameTranslation: '—',
        versesCount: 0,
        revelation: '',
      ),
    );
    _currentSurah = Surah(
      id: surahNumber,
      number: meta.number,
      nameArabic: meta.nameArabic,
      nameTransliteration: meta.nameTransliteration,
      nameTranslation: meta.nameTranslation,
      versesCount: meta.versesCount,
      revelation: meta.revelation,
      verses: const [],
    );
    notifyListeners();
    await loadSurahVerses(meta.number);
    // After verses loaded, trigger listeners to allow scroll
    if (_pendingScrollVerseNumber != null) {
      // keep value; UI will consume and then clear via consumePendingScrollTarget
      notifyListeners();
    }
  }

  Future<void> loadSurah(int surahNumber) async => navigateToSurah(surahNumber);

  // Called by navigation to open a surah at a specific verse and mark it for highlight.
  void openSurahAtVerse(int surahNumber, int verseNumber) async {
    _pendingScrollVerseNumber = verseNumber;
    _pendingHighlightStartVerseNumber = verseNumber;
    _pendingHighlightEndVerseNumber = verseNumber;
    await navigateToSurah(surahNumber);
  }

  // Called by navigation to open a surah at a verse range and mark range for highlight.
  void openSurahAtRange(int surahNumber, int startVerse, int endVerse) async {
    final s = startVerse <= endVerse ? startVerse : endVerse;
    final e = endVerse >= startVerse ? endVerse : startVerse;
    _pendingScrollVerseNumber = s;
    _pendingHighlightStartVerseNumber = s;
    _pendingHighlightEndVerseNumber = e;
    await navigateToSurah(surahNumber);
  }

  int? consumePendingScrollTarget() {
    final v = _pendingScrollVerseNumber;
    _pendingScrollVerseNumber = null;
    return v;
  }

  // Peek without consuming (used by UI to wait until verses are available)
  int? get pendingScrollTarget => _pendingScrollVerseNumber;

  /// Returns [start, end] for a pending arrival highlight range and clears it; or null if none.
  List<int>? consumePendingHighlightRange() {
    final s = _pendingHighlightStartVerseNumber;
    final e = _pendingHighlightEndVerseNumber;
    _pendingHighlightStartVerseNumber = null;
    _pendingHighlightEndVerseNumber = null;
    if (s == null || e == null) return null;
    return [s, e];
  }

  void _appendMoreVerses() {
    final remaining = _allCurrentSurahVerses.length - _loadedVerseCount;
    if (remaining <= 0) {
      _hasMoreVerses = false;
      // At end of current surah pages; if chaining desired prefetch next if not already
      if (_currentSurahId != null) _maybePrefetchNextSurah(_currentSurahId!);
      return;
    }
    final take = remaining >= _pageSize ? _pageSize : remaining;
    _pagedVerses.addAll(_allCurrentSurahVerses.sublist(_loadedVerseCount, _loadedVerseCount + take));
    _loadedVerseCount += take;
    _hasMoreVerses = _loadedVerseCount < _allCurrentSurahVerses.length;
    // Trigger prefetch when within one page from end
    if (_hasMoreVerses == false && _currentSurahId != null) {
      _maybePrefetchNextSurah(_currentSurahId!);
    } else if (_hasMoreVerses && (_allCurrentSurahVerses.length - _loadedVerseCount) <= _pageSize && _currentSurahId != null) {
      _maybePrefetchNextSurah(_currentSurahId!);
    }
  }

  void _loadMoreVerses() {
    if (_isLoading || !_hasMoreVerses) return;
    _appendMoreVerses();
    notifyListeners();
  }

  void loadMoreVerses() => _loadMoreVerses();

  // Lejon daljen nga një sure dhe kthimin te lista e sureve
  void exitCurrentSurah() {
    _currentSurah = null;
    _currentSurahId = null;
    _allCurrentSurahVerses = [];
    _pagedVerses = [];
    _hasMoreVerses = false;
    _loadedVerseCount = 0;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
  _resultsRefreshDebounce?.cancel();
    _indexProgressSub?.cancel();
    _indexManager?.dispose();
    super.dispose();
  }

  // UI can call this when user actively scrolls verses; forwards to index manager for adaptive throttling
  void notifyUserScrollActivity() {
    _indexManager?.notifyUserScrollEvent();
  }

  // Public explicit trigger for incremental index build (phase scheduler & early user actions)
  void startIndexBuild() {
    _indexManager?.ensureIncrementalBuild();
  }

  // Debounced refresh of search results while index builds, to reduce rebuild churn
  void _scheduleResultsRefresh() {
    _resultsRefreshDebounce?.cancel();
    _resultsRefreshDebounce = Timer(const Duration(milliseconds: 200), () {
      final mgr = _indexManager;
      if (mgr != null && _lastQuery.isNotEmpty) {
        _searchResults = mgr.search(
          _lastQuery,
          juzFilter: _activeJuzFilter,
          includeTranslation: _filterTranslation,
          includeArabic: _filterArabic,
          includeTransliteration: _filterTransliteration,
        );
        notifyListeners();
      }
    });
  }

  // Ensure verses for a surah are loaded; if different surah from current, switches context.
  Future<void> ensureSurahLoaded(int surahNumber) async {
    if (_currentSurahId == surahNumber && _allCurrentSurahVerses.isNotEmpty) return;
    final sw = Stopwatch()..start();
    await navigateToSurah(surahNumber); // this calls loadSurahVerses internally
    Logger.d('ensureSurahLoaded surah=$surahNumber took=${sw.elapsedMilliseconds}ms', tag: 'LazySurah');
  }

  // Prefetch next surah's verses (store in cache) if not last surah.
  void _maybePrefetchNextSurah(int current) {
    if (current >= 114) return; // last surah
    final next = current + 1;
    if (_prefetchCache.containsKey(next)) return; // already prefetched
    // Fire and forget prefetch
    // ignore: unawaited_futures
    Future(() async {
      try {
  final uc = _getSurahVersesUseCase; if (uc == null) return; final verses = await uc.call(next);
        _prefetchCache[next] = verses;
        Logger.d('Prefetched surah=$next verses=${verses.length}', tag: 'Prefetch');
      } catch (e) {
        // ignore errors silently
      }
    });
  }

  bool hasPrefetched(int surahNumber) => _prefetchCache.containsKey(surahNumber);

  // Resolve a verse instance for given surah & verse number. If not loaded yet, returns null (caller can load then retry).
  Verse? findVerse(int surahNumber, int verseNumber) {
    if (_currentSurahId == surahNumber) {
      try { return _allCurrentSurahVerses.firstWhere((v) => v.verseNumber == verseNumber); } catch (_) {}
      try { return _pagedVerses.firstWhere((v) => v.verseNumber == verseNumber); } catch (_) {}
    }
    return null;
  }

  /// Resolve a verse for a reference string like "2:255" using current caches.
  /// Returns null if not available without triggering heavy loads.
  Verse? resolveVerseByRef(String verseRef) {
    final parts = verseRef.trim().split(':');
    if (parts.length != 2) return null;
    final s = int.tryParse(parts[0]);
    final v = int.tryParse(parts[1]);
    if (s == null || v == null) return null;
    // Check current/prefetched caches first
    final local = findVerse(s, v);
    if (local != null) return local;
    // Try prefetch cache (full surah list if present)
    final pref = _prefetchCache[s];
    if (pref != null) {
      try { return pref.firstWhere((e) => e.verseNumber == v); } catch (_) {}
    }
    // Fallback to index manager verse cache (if built/snapshot loaded)
    return _indexManager?.getVerseByKey('$s:$v');
  }

}

