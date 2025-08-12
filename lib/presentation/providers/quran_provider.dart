import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/surah.dart';
import '../../domain/entities/verse.dart';
import '../../domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/core/utils/result.dart';
import '../../domain/usecases/search_verses_usecase.dart';
import '../../domain/usecases/get_surah_verses_usecase.dart';
import 'search_index_manager.dart';

class QuranProvider extends ChangeNotifier {
  final GetSurahsUseCase? _getSurahsUseCase;
  final SearchVersesUseCase? _searchVersesUseCase;
  final GetSurahVersesUseCase? _getSurahVersesUseCase;

  final SearchIndexManager? _indexManager; // null in simple ctor

  QuranProvider({
    required GetSurahsUseCase getSurahsUseCase,
    required SearchVersesUseCase searchVersesUseCase,
    required GetSurahVersesUseCase getSurahVersesUseCase,
  })  : _getSurahsUseCase = getSurahsUseCase,
        _searchVersesUseCase = searchVersesUseCase,
        _getSurahVersesUseCase = getSurahVersesUseCase,
        _indexManager = SearchIndexManager(
          getSurahsUseCase: getSurahsUseCase,
          getSurahVersesUseCase: getSurahVersesUseCase,
        ) {
    _init();
  }

  // Simplified constructor for basic functionality without use cases
  QuranProvider.simple()
      : _getSurahsUseCase = null,
        _searchVersesUseCase = null,
        _getSurahVersesUseCase = null,
        _indexManager = null;
  
  Future<void> _init() async {
    if (_surahs.isEmpty && _getSurahsUseCase != null) {
      await loadSurahs();
    }
  }

  List<Surah> _surahs = [];
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

  List<Surah> get surahs => _surahs;
  List<Verse> get currentVerses => _pagedVerses;
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
        _surahs = res.value;
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

  Future<void> searchVerses(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    if (_indexManager != null) {
      try {
        await _indexManager!.ensureBuilt(onProgress: (p) {
          _isBuildingIndex = true;
          _indexProgress = p;
          notifyListeners();
        });
        _isBuildingIndex = false;
        _searchResults = _indexManager!.search(query);
        _error = null;
        notifyListeners();
      } catch (e) {
        // fallback to original use case if provided
        if (_searchVersesUseCase != null) {
          _setLoading(true);
          try {
            _searchResults = await _searchVersesUseCase!.call(query);
            _error = null;
          } catch (e2) {
            _error = e2.toString();
            _searchResults = [];
          } finally {
            _setLoading(false);
          }
        }
      }
    } else if (_searchVersesUseCase != null) {
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
      _currentSurahId = surahId;
      _currentSurah = _surahs.firstWhere(
        (s) => s.id == surahId || s.number == surahId,
        orElse: () => Surah(
          id: surahId,
          number: surahId,
          nameArabic: '',
          nameTranslation: '',
          nameTransliteration: '',
          revelation: '',
          versesCount: _allCurrentSurahVerses.length,
          verses: _allCurrentSurahVerses,
        ),
      );
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
    if (_surahs.isEmpty) {
      await loadSurahs();
    }
    final surah = _surahs.firstWhere(
      (s) => s.number == surahNumber || s.id == surahNumber,
      orElse: () => Surah(
        id: surahNumber,
        number: surahNumber,
        nameArabic: '—',
        nameTranslation: '—',
        nameTransliteration: '—',
        revelation: '',
        versesCount: 0,
        verses: const [],
      ),
    );
    _currentSurah = surah;
    notifyListeners();
    await loadSurahVerses(surah.number);
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
    super.dispose();
  }

}

