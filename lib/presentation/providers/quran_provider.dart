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

class QuranProvider extends ChangeNotifier {
  final GetSurahsUseCase? _getSurahsUseCase;
  final GetSurahsArabicOnlyUseCase? _getSurahsArabicOnlyUseCase;
  final SearchVersesUseCase? _searchVersesUseCase;
  final GetSurahVersesUseCase? _getSurahVersesUseCase;

  final SearchIndexManager? _indexManager; // null in simple ctor
  StreamSubscription<SearchIndexProgress>? _indexProgressSub;

  QuranProvider({
    required GetSurahsUseCase getSurahsUseCase,
    required GetSurahsArabicOnlyUseCase getSurahsArabicOnlyUseCase,
    required SearchVersesUseCase searchVersesUseCase,
    required GetSurahVersesUseCase getSurahVersesUseCase,
  })  : _getSurahsUseCase = getSurahsUseCase,
        _getSurahsArabicOnlyUseCase = getSurahsArabicOnlyUseCase,
        _searchVersesUseCase = searchVersesUseCase,
        _getSurahVersesUseCase = getSurahVersesUseCase,
        _indexManager = SearchIndexManager(
          getSurahsUseCase: getSurahsUseCase,
          getSurahVersesUseCase: getSurahVersesUseCase,
        ) {
    _init();
    // Subscribe to live progress stream
    _indexProgressSub = _indexManager?.progressStream.listen((evt) {
      _isBuildingIndex = !evt.complete;
      _indexProgress = evt.progress;
      notifyListeners();
    });
  }

  // Simplified constructor for basic functionality without use cases
  QuranProvider.simple()
      : _getSurahsUseCase = null,
        _getSurahsArabicOnlyUseCase = null,
        _searchVersesUseCase = null,
        _getSurahVersesUseCase = null,
        _indexManager = null;
  
  Future<void> _init() async {
    if (_surahsMeta.isEmpty && _getSurahsArabicOnlyUseCase != null) {
      Future.delayed(const Duration(milliseconds: 10), () async {
        await loadSurahMetasArabicOnly();
      });
    }
  }

  // Metadata-only list (no verse bodies) to reduce startup memory.
  List<SurahMeta> _surahsMeta = [];
  List<Verse> _allCurrentSurahVerses = []; // full list for current surah
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
  // Search indexing (delegated)
  bool _isBuildingIndex = false; // mirrors manager state for UI convenience
  double _indexProgress = 0;
  bool get isBuildingIndex => _isBuildingIndex;
  double get indexProgress => _indexProgress;
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 350);
  bool _userTriggeredIndexOnce = false; // suppress duplicate logs

  List<SurahMeta> get surahs => _surahsMeta;
  List<Verse> get currentVerses => _pagedVerses;
  List<Verse> get fullCurrentSurahVerses => _allCurrentSurahVerses;
  List<Verse> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get currentSurahId => _currentSurahId;
  Surah? get currentSurah => _currentSurah;
  bool get hasMoreVerses => _hasMoreVerses;

  Future<void> loadSurahs() async {
    _setLoading(true);
    try {
      final res = await _getSurahsUseCase!.call();
      if (res is Success<List<Surah>>) {
        final sw = Stopwatch()..start();
        final all = res.value.map((s) => SurahMeta.fromSurah(s)).toList();
        // Incremental publication in small batches for earlier first paint.
        _surahsMeta = [];
        final batchSize = 25;
        for (int i = 0; i < all.length; i += batchSize) {
          final end = (i + batchSize) > all.length ? all.length : (i + batchSize);
          _surahsMeta.addAll(all.sublist(i, end));
          notifyListeners();
          // Yield control between batches (except last) to allow frames.
          if (end < all.length) {
            await Future.delayed(Duration(milliseconds: 1));
          }
        }
        Logger.d('Loaded surah metadata count=${_surahsMeta.length} in ${sw.elapsedMilliseconds}ms', tag: 'StartupPhase');
        _error = null;
      } else {
        _error = res.error?.message ?? 'Unknown error';
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
      final surahs = await _getSurahsArabicOnlyUseCase!.call();
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
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    if (_indexManager != null) {
      // Kick incremental build if not started yet (returns immediately) – user-driven start.
      final wasIdle = !_indexManager!.isBuilding && indexProgress <= 0.0;
      _indexManager!.ensureIncrementalBuild();
      if (wasIdle && !_userTriggeredIndexOnce) {
        _userTriggeredIndexOnce = true;
        Logger.i('Index build triggered by user search input', tag: 'SearchIndex');
      }
      // Perform search over currently indexed subset (results will improve as index grows)
      _searchResults = _indexManager!.search(
        query,
        juzFilter: _activeJuzFilter,
        includeTranslation: _filterTranslation,
        includeArabic: _filterArabic,
        includeTransliteration: _filterTransliteration,
      );
      _error = null;
      notifyListeners();
      return;
    }
    if (_searchVersesUseCase != null) {
      _setLoading(true);
      try {
        _searchResults = await _searchVersesUseCase!.call(query);
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
      _allCurrentSurahVerses = await _getSurahVersesUseCase!.call(surahId);
  Logger.d('Loaded verses surah=$surahId count=${_allCurrentSurahVerses.length}', tag: 'LazySurah');
      _currentSurahId = surahId;
      // Preserve existing meta fields in _currentSurah (already set in navigateToSurah) and just attach verses after pagination.
      if (_currentSurah == null || _currentSurah!.number != surahId) {
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
      _error = null;
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

  // Called by search/bookmark navigation to set a verse to scroll to after load
  void openSurahAtVerse(int surahNumber, int verseNumber) async {
    _pendingScrollVerseNumber = verseNumber;
    await navigateToSurah(surahNumber);
  }

  int? consumePendingScrollTarget() {
    final v = _pendingScrollVerseNumber;
    _pendingScrollVerseNumber = null;
    return v;
  }

  void _appendMoreVerses() {
    final remaining = _allCurrentSurahVerses.length - _loadedVerseCount;
    if (remaining <= 0) {
      _hasMoreVerses = false;
      return;
    }
    final take = remaining >= _pageSize ? _pageSize : remaining;
    _pagedVerses.addAll(_allCurrentSurahVerses.sublist(_loadedVerseCount, _loadedVerseCount + take));
    _loadedVerseCount += take;
    _hasMoreVerses = _loadedVerseCount < _allCurrentSurahVerses.length;
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
    _indexProgressSub?.cancel();
    _indexManager?.dispose();
    super.dispose();
  }

  // UI can call this when user actively scrolls verses; forwards to index manager for adaptive throttling
  void notifyUserScrollActivity() {
    _indexManager?.notifyUserScrollEvent();
  }

  // Public explicit trigger for incremental index build (phase scheduler & early user actions)
  void ensureIndexBuild() {
  _indexManager?.ensureIncrementalBuild();
  }

  // Ensure verses for a surah are loaded; if different surah from current, switches context.
  Future<void> ensureSurahLoaded(int surahNumber) async {
    if (_currentSurahId == surahNumber && _allCurrentSurahVerses.isNotEmpty) return;
    final sw = Stopwatch()..start();
    await navigateToSurah(surahNumber); // this calls loadSurahVerses internally
    Logger.d('ensureSurahLoaded surah=$surahNumber took=${sw.elapsedMilliseconds}ms', tag: 'LazySurah');
  }

}

