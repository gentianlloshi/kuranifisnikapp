import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'inverted_index_builder.dart' as idx;
import '../../domain/entities/surah.dart';
import '../../domain/entities/verse.dart';
import '../../domain/usecases/get_surahs_usecase.dart';
import '../../domain/usecases/search_verses_usecase.dart';
import '../../domain/usecases/get_surah_verses_usecase.dart';

class QuranProvider extends ChangeNotifier {
  final GetSurahsUseCase? _getSurahsUseCase;
  final SearchVersesUseCase? _searchVersesUseCase;
  final GetSurahVersesUseCase? _getSurahVersesUseCase;

  QuranProvider({
    required GetSurahsUseCase getSurahsUseCase,
    required SearchVersesUseCase searchVersesUseCase,
    required GetSurahVersesUseCase getSurahVersesUseCase,
  })  : _getSurahsUseCase = getSurahsUseCase,
        _searchVersesUseCase = searchVersesUseCase,
        _getSurahVersesUseCase = getSurahVersesUseCase {
    // Auto-load surahs on creation to populate UI
    _init();
  }

  // Simplified constructor for basic functionality without use cases
  QuranProvider.simple()
      : _getSurahsUseCase = null,
        _searchVersesUseCase = null,
        _getSurahVersesUseCase = null;
  
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
  // Search indexing
  bool _isBuildingIndex = false;
  bool get isBuildingIndex => _isBuildingIndex;
  Map<String, List<String>>? _invertedIndex; // token -> list of verseKeys
  final Map<String, Verse> _verseCache = {}; // verseKey -> Verse

  Future<void> _ensureSearchIndex() async {
    if (_invertedIndex != null || _isBuildingIndex) return;
    _isBuildingIndex = true;
    notifyListeners();
    try {
  // Collect raw verse records including translation, transliteration, arabic
      final List<Map<String, dynamic>> raw = [];
      // Load surahs list if needed
      if (_surahs.isEmpty && _getSurahsUseCase != null) {
        await loadSurahs();
      }
      // Iterate all surah numbers 1..114
      if (_getSurahVersesUseCase != null) {
        for (int s = 1; s <= 114; s++) {
          try {
            final verses = await _getSurahVersesUseCase!.call(s);
            for (final v in verses) {
              final key = '${v.surahNumber}:${v.number}';
              _verseCache[key] = v;
              raw.add({
                'key': key,
                't': (v.textTranslation ?? '').toString(),
                'tr': (v.textTransliteration ?? '').toString(),
                'ar': (v.textArabic ?? '').toString(),
              });
            }
          } catch (_) {
            // continue other surahs
          }
        }
      }
      // Build inverted index in isolate
  _invertedIndex = await compute(idx.buildInvertedIndex, raw);
    } catch (_) {
      _invertedIndex = null; // fallback will trigger
    } finally {
      _isBuildingIndex = false;
      notifyListeners();
    }
  }

  // Token-based search using inverted index
  List<Verse> _searchIndexQuery(String query) {
    if (_invertedIndex == null) return [];
  final tokens = _expandQueryTokens(query);
    if (tokens.isEmpty) return [];
    // Collect union first for scoring
    final candidateKeys = <String, int>{}; // key -> score
    for (final t in tokens) {
      final list = _invertedIndex![t];
      if (list == null) continue;
      for (final k in list) {
        candidateKeys.update(k, (s) => s + 1, ifAbsent: () => 1);
      }
    }
    if (candidateKeys.isEmpty) return [];

    // Scoring: exact full-token matches weighted higher than prefix-only matches
    final Set<String> fullTokens = _tokenize(query).map((e)=>e.toLowerCase()).toSet();
    List<_ScoredVerse> scored = [];
    candidateKeys.forEach((key, hitCount) {
      final verse = _verseCache[key];
      if (verse == null) return;
      int score = hitCount * 10; // base weight per token hit
      // Add bonuses for full-token presence (not just prefix). We treat any full token not found as penalty.
      for (final ft in fullTokens) {
        final verseText = (verse.textTranslation ?? '').toLowerCase();
        if (verseText.contains(ft)) {
          score += 25;
        }
      }
      scored.add(_ScoredVerse(verse, score));
    });
    scored.sort((a,b){
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final s = a.verse.surahNumber.compareTo(b.verse.surahNumber);
      if (s != 0) return s;
      return a.verse.number.compareTo(b.verse.number);
    });
    return scored.map((e)=>e.verse).toList();
  }

  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    final parts = lower.split(RegExp(r'[^a-zçëšžáéíóúâêîôûäöü0-9]+'));
    return parts.where((p) => p.isNotEmpty).toList();
  }

  List<String> _expandQueryTokens(String query){
    final raw = _tokenize(query);
    final result = <String>[];
    for (final r in raw){
      if (r.length <= 2){
        // allow direct small token to leverage prefix index
        result.add(r);
        continue;
      }
      result.add(r);
      // also add normalized form (strip diacritics for ç, ë etc.)
      final norm = r.replaceAll('ç','c').replaceAll('ë','e');
      if (norm != r) result.add(norm);
    }
    return result.toSet().toList();
  }

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
      _surahs = await _getSurahsUseCase!.call();
      _error = null;
    } catch (e) {
      _error = e.toString();
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
    // Ensure index built
    await _ensureSearchIndex();
    if (_invertedIndex != null) {
      // Fast path using index
      _searchResults = _searchIndexQuery(query);
      _error = null;
      notifyListeners();
    } else {
      // Fallback to original use case
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

}

class _ScoredVerse {
  final Verse verse;
  final int score;
  _ScoredVerse(this.verse, this.score);
}
