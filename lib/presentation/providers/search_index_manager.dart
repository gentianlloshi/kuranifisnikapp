import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/verse.dart';
import '../../domain/usecases/get_surah_verses_usecase.dart';
import '../../domain/usecases/get_surahs_usecase.dart';
import 'inverted_index_builder.dart' as idx;
import 'search_index_isolate.dart' as iso;
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';
import 'package:kurani_fisnik_app/core/search/stemmer.dart';
import 'package:kurani_fisnik_app/core/search/token_utils.dart' as tq;
import 'search_snapshot_store.dart';

/// Encapsulates building and querying the inverted search index.
/// Responsible only for in-memory structures; persistence & advanced ranking can layer on top later.
class SearchIndexManager {
  final GetSurahsUseCase getSurahsUseCase;
  final GetSurahVersesUseCase getSurahVersesUseCase;

  Map<String, List<String>>? _invertedIndex; // token -> verseKeys
  final Map<String, Verse> _verseCache = {}; // verseKey -> Verse
  bool _building = false;
  Completer<void>? _buildCompleter;
  // Incremental state
  int _nextSurahToIndex = 1; // 1..114
  bool _incrementalMode = false; // true if using incremental background build
  int _buildSessionId = 0; // monotonically increasing build session
  // Progress stream
  final StreamController<SearchIndexProgress> _progressController = StreamController<SearchIndexProgress>.broadcast();
  Stream<SearchIndexProgress> get progressStream => _progressController.stream;

  // Adaptive throttling (user activity)
  DateTime? _lastUserScrollEvent;
  static const Duration _scrollQuietDuration = Duration(milliseconds: 300); // need this long of quiet to resume
  static const Duration _maxPausePerBatch = Duration(seconds: 2); // don't stall forever

  bool get isBuilt => _invertedIndex != null;
  bool get isBuilding => _building;

  // Persistence constants
  static const int _snapshotVersion = 2; // bumped for incremental structure
  static const String _snapshotFile = 'search_index_v$_snapshotVersion.json';
  // Computed corpus hash (lazy). Used to invalidate old snapshots when assets change.
  String? _cachedCorpusHash;
  final SnapshotStore _snapshotStore;

  // Scoring weights (tunable)
  static const int _baseHitWeight = 10;
  static const int _wTranslation = 25;
  static const int _wArabic = 15;
  static const int _wTransliteration = 10;

  SearchIndexManager({
    required this.getSurahsUseCase,
    required this.getSurahVersesUseCase,
    SnapshotStore? snapshotStore,
  }) : _snapshotStore = snapshotStore ?? DefaultSnapshotStore(fileName: _snapshotFile);

  /// Ensures the index is fully built (blocking until completion) unless already built.
  Future<void> ensureBuilt({void Function(double progress)? onProgress}) async {
    if (_invertedIndex != null) return;
    // Try fast-path load from snapshot
    if (await _tryLoadSnapshot()) {
  _emitProgress(1.0);
  if (onProgress != null) onProgress(1.0); // backward compatibility
      return;
    }
    if (_building) {
      return _buildCompleter?.future;
    }
    _building = true;
    _buildCompleter = Completer<void>();
    try {
      // Load required asset JSONs on main isolate (fast; file I/O) and offload heavy parse/build
      final arabicStr = await rootBundle.loadString('assets/data/arabic_quran.json');
      // Prefer default translation for index; can be made dynamic later
      final translationStr = await rootBundle.loadString('assets/data/sq_ahmeti.json');
      String translitStr = '';
      try { translitStr = await rootBundle.loadString('assets/data/transliterations.json'); } catch (_) {}

      _emitProgress(0.05); if (onProgress != null) onProgress(0.05);
      final result = await compute(iso.buildFullIndexFromAssets, {
        'arabic': arabicStr,
        'translation': translationStr,
        'transliterations': translitStr,
      });
      final index = (result['index'] as Map).map((k, v) => MapEntry(k as String, (v as List).cast<String>()));
      final verses = (result['verses'] as Map).cast<String, dynamic>();
      // Populate caches
      _invertedIndex = index;
      verses.forEach((k, v) {
        final obj = v as Map<String, dynamic>;
        _verseCache[k] = Verse(
          surahId: obj['surahNumber'] as int,
          verseNumber: obj['number'] as int,
          arabicText: obj['ar'] as String? ?? '',
          translation: obj['t'] as String?,
          transliteration: obj['tr'] as String?,
          verseKey: obj['verseKey'] as String? ?? k,
          juz: obj['juz'] as int?,
        );
      });
      _emitProgress(1.0); if (onProgress != null) onProgress(1.0);
      // Persist snapshot (fire & forget)
      unawaited(_saveSnapshot());
    } catch (_) {
      _invertedIndex = null;
      rethrow;
    } finally {
      _building = false;
      _buildCompleter?.complete();
    }
  }

  /// Starts an incremental background build if not yet complete. Returns immediately.
  /// Search calls can begin early; they will return partial results based on indexed surahs.
  void ensureIncrementalBuild({void Function(double progress)? onProgress}) {
    // Already fully built & not in incremental mode
    if (_invertedIndex != null && !_incrementalMode) return;
    // If full index is built via isolate above, don't run per-surah main-thread batches
    if (_invertedIndex != null && _nextSurahToIndex > 114) {
      _emitProgress(1.0);
      if (onProgress != null) onProgress(1.0);
      return;
    }
    // If a build already in progress, just return (callers can await existing completer if exposed later)
    if (_building) return;
    _incrementalMode = true;
    _building = true;
    _buildSessionId++;
    final int session = _buildSessionId;
    _buildCompleter = Completer<void>();
    _invertedIndex ??= <String, List<String>>{}; // start empty index
    () async {
      try {
        // Attempt fast snapshot load once at session start.
        if (_nextSurahToIndex == 1 && await _tryLoadSnapshot()) {
          if (session != _buildSessionId) return; // stale session guard
          if (_nextSurahToIndex > 114) {
            // Snapshot already complete; mark done (let finally handle completion flags)
            _incrementalMode = false;
            _emitProgress(1.0);
            if (onProgress != null) onProgress(1.0);
            return;
          }
        }
        for (int s = _nextSurahToIndex; s <= 114; s++) {
          if (session != _buildSessionId) return; // aborted by newer session
          _nextSurahToIndex = s; // record current for snapshot resume
          final batchSw = Stopwatch()..start();
          try {
            // TODO: Move incremental per-surah collection into isolate as well if needed.
            final verses = await getSurahVersesUseCase.call(s);
            // Keep verse cache for result hydration
            final raw = <Map<String, dynamic>>[];
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
            if (raw.isNotEmpty) {
              // Build partial inverted index off the main isolate and merge
              final partial = await compute(idx.buildInvertedIndex, raw);
              _mergePartialIndex(partial);
            }
          } catch (_) {/* skip surah errors silently */}
          final p = s / 114.0;
          _emitProgress(p);
          PerfMetrics.instance.setIndexCoverage(p);
          if (onProgress != null) onProgress(p);
          final elapsed = batchSw.elapsedMilliseconds;
          if (elapsed > 30) {
            // Avoid importing logger here to keep manager lean; using debugPrint.
            // ignore: avoid_print
            print('[IndexBatch] surah=$s ms=$elapsed progress=${(p*100).toStringAsFixed(1)}');
          }
          if (s % 5 == 0 || s == 114) {
            unawaited(_saveSnapshot(partial: s != 114));
          }
          await _applyAdaptiveThrottle(); // cooperative yield
        }
        if (session == _buildSessionId) {
          _incrementalMode = false;
          _emitProgress(1.0);
          PerfMetrics.instance.setIndexCoverage(1.0);
          if (onProgress != null) onProgress(1.0);
        }
      } catch (_) {
        // On error keep state allowing retry later; do not mark complete progress
      } finally {
        if (session == _buildSessionId) {
          _building = false;
          if (!(_buildCompleter?.isCompleted ?? true)) {
            _buildCompleter!.complete();
          }
        }
      }
    }();
  }

  void _mergePartialIndex(Map<String, List<String>> partial) {
    final dst = _invertedIndex!;
    partial.forEach((token, keys) {
      final list = dst.putIfAbsent(token, () => <String>[]);
      // Append while avoiding duplicates at the very end of the list (rare)
      if (list.isEmpty) {
        list.addAll(keys);
      } else {
        for (final k in keys) {
          if (list.isEmpty || list.last != k) {
            // Weak de-duplication; safe since each verse appears once per partial
            list.add(k);
          }
        }
      }
    });
  }

  List<Verse> search(
    String query, {
    int? juzFilter, // if set, restrict to verses in this Juz
    bool includeTranslation = true,
    bool includeArabic = true,
    bool includeTransliteration = true,
  }) {
  if (_invertedIndex == null) return [];
    final tokens = _expandQueryTokens(query);
    if (tokens.isEmpty) return [];
  final candidateScores = <String, int>{};
    // Exact/prefix hits
    for (final t in tokens) {
      final list = _invertedIndex![t];
      if (list == null) continue;
      for (final key in list) {
        candidateScores.update(key, (v) => v + _baseHitWeight, ifAbsent: () => _baseHitWeight);
      }
    }
    // Fuzzy fallback (Levenshtein distance 1 for short tokens, <=2 for longer)
    // Apply diacritic-insensitive normalization to query tokens for general correctness
    final rawTokens = tq
        .tokenizeLatin(query)
        .map((e) => _normalizeLatin(e))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (rawTokens.isNotEmpty) {
      final indexTokens = _invertedIndex!.keys;
      for (final qTok in rawTokens) {
        final maxDist = qTok.length <= 4 ? 1 : 2;
        for (final idxTok in indexTokens) {
          final idxN = _normalizeLatin(idxTok);
          if (idxN.isEmpty) continue;
          if ((idxN.length - qTok.length).abs() > maxDist) continue;
          // Quick first-letter filter to reduce noise and cost
          if (idxN[0] != qTok[0]) continue;
          final d = _levenshtein(idxN, qTok, maxDist);
          if (d >= 0 && d <= maxDist) {
            final keys = _invertedIndex![idxTok];
            if (keys == null) continue;
            final weight = (_baseHitWeight / (d + 2)).round(); // lower weight for fuzzier
            for (final k in keys) {
              candidateScores.update(k, (v) => v + weight, ifAbsent: () => weight);
            }
          }
        }
      }
    }
    if (candidateScores.isEmpty) return [];
  // Use normalized tokens for consistent matching/highlighting
  final fullTokens = tq.tokenizeLatin(query)
      .map((e) => e.toLowerCase())
      .map(_normalizeLatin)
      .toSet();
  final scored = <_ScoredVerse>[];
    candidateScores.forEach((key, base) {
      final verse = _verseCache[key];
      if (verse == null) return;
      if (juzFilter != null && verse.juz != juzFilter) return;
      int score = base * _baseHitWeight;
      // Build normalized field strings for substring checks
      final tRaw = verse.textTranslation ?? '';
      final trRaw = verse.textTransliteration ?? '';
      final arRaw = verse.textArabic;
      final tNorm = _normalizeLatin(tRaw.toLowerCase());
      final trNorm = _normalizeLatin(trRaw.toLowerCase());
      final arNorm = _normalizeArabic(arRaw).toLowerCase();
      bool hasSubstringHit = false;
      if (includeTranslation) {
        for (final ft in fullTokens) { if (tNorm.contains(ft)) { score += _wTranslation; hasSubstringHit = true; } }
      }
      if (includeArabic) {
        for (final ft in fullTokens) { if (arNorm.contains(ft)) { score += _wArabic; hasSubstringHit = true; } }
      }
      if (includeTransliteration) {
        for (final ft in fullTokens) { if (trNorm.contains(ft)) { score += _wTransliteration; hasSubstringHit = true; } }
      }
      // Prune pure-fuzzy outliers: require at least one substring hit in any included field
      if (!hasSubstringHit) return;
      scored.add(_ScoredVerse(verse, score));
    });
    // Default ranking by score, stable tie-breakers
    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final s = a.verse.surahNumber.compareTo(b.verse.surahNumber);
      if (s != 0) return s;
      return a.verse.number.compareTo(b.verse.number);
    });
    return scored.map((e) => e.verse).toList();
  }

  List<String> _expandQueryTokens(String query) {
  return tq.expandQueryTokens(query, lightStem);
  }

  // Tokenize & insert a single verse into the existing in-memory inverted index (incremental mode)
  void _indexVerse(Verse v) {
    if (_invertedIndex == null) return;
    final key = '${v.surahNumber}:${v.number}';
    final tokens = <String>{}
  ..addAll(tq.tokenizeLatin((v.textTranslation ?? '')))
  ..addAll(tq.tokenizeLatin((v.textTransliteration ?? '')))
  ..addAll(tq.tokenizeLatin(_normalizeArabic((v.textArabic))));
    final seenVerseTokens = <String>{};
    for (final tok in tokens) {
      if (tok.isEmpty) continue;
      final norm = _normalizeLatin(tok);
      void addToken(String t) {
        if (seenVerseTokens.add(t)) {
          final list = _invertedIndex!.putIfAbsent(t, () => <String>[]);
          list.add(key);
        }
      }
      addToken(tok);
      if (norm != tok) addToken(norm);
      if (norm.length >= 3) {
        final maxPref = norm.length - 1 < 10 ? norm.length - 1 : 10;
        for (int l = 2; l <= maxPref; l++) {
          addToken(norm.substring(0, l));
        }
      }
    }
  }

  String _normalizeArabic(String input) {
    var s = input;
    s = s.replaceAll(RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
    s = s.replaceAll(RegExp('[\u0622\u0623\u0625\u0671]'), 'ا');
    s = s.replaceAll('\u0649', 'ي');
    s = s.replaceAll('\u0640', '');
    return s;
  }

  String _normalizeLatin(String input) {
    String s = input.toLowerCase();
    s = s.replaceAll('ç', 'c').replaceAll('ë', 'e');
    const mapping = {
      'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a','ā':'a','ă':'a','ą':'a',
      'é':'e','è':'e','ë':'e','ê':'e','ě':'e','ē':'e','ę':'e','ė':'e',
      'í':'i','ì':'i','ï':'i','î':'i','ī':'i','į':'i','ı':'i',
      'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o','ø':'o','ō':'o','ő':'o',
      'ú':'u','ù':'u','ü':'u','û':'u','ū':'u','ů':'u','ű':'u','ť':'t','š':'s','ž':'z','ñ':'n','ç':'c'
    };
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      sb.write(mapping[ch] ?? ch);
    }
    return sb.toString();
  }

  // stemmer provided by core/search/stemmer.dart

  /// Public API for UI to notify that user scrolled (used for adaptive throttling)
  void notifyUserScrollEvent() {
    _lastUserScrollEvent = DateTime.now();
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }

  void _emitProgress(double progress) {
    try {
      final indexedSurahs = _invertedIndex == null
          ? 0
          : (_incrementalMode
              ? (_nextSurahToIndex - 1).clamp(0, 114)
              : 114);
      _progressController.add(SearchIndexProgress(
        progress: progress.clamp(0, 1),
        incremental: _incrementalMode,
        complete: progress >= 0.999,
        indexedSurahs: indexedSurahs,
        totalSurahs: 114,
      ));
    } catch (_) {}
  }

  Future<void> _applyAdaptiveThrottle() async {
    // If no scroll events recently just minimal yield
    if (_lastUserScrollEvent == null) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      return;
    }
    final start = DateTime.now();
    while (_lastUserScrollEvent != null &&
        DateTime.now().difference(_lastUserScrollEvent!) < _scrollQuietDuration) {
      if (DateTime.now().difference(start) > _maxPausePerBatch) break; // hard cap
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // After pause, always yield a tiny delay to keep UI responsive
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

// Bounded Levenshtein (returns -1 if exceeds maxDist early)
int _levenshtein(String a, String b, int maxDist) {
  final m = a.length, n = b.length;
  if ((m - n).abs() > maxDist) return -1;
  if (m == 0) return n <= maxDist ? n : -1;
  if (n == 0) return m <= maxDist ? m : -1;
  List<int> prev = List<int>.generate(n + 1, (j) => j);
  List<int> curr = List<int>.filled(n + 1, 0);
  for (int i = 1; i <= m; i++) {
    curr[0] = i;
    int rowMin = curr[0];
    final ca = a.codeUnitAt(i - 1);
    for (int j = 1; j <= n; j++) {
      final cb = b.codeUnitAt(j - 1);
      final cost = ca == cb ? 0 : 1;
      final ins = curr[j - 1] + 1;
      final del = prev[j] + 1;
      final sub = prev[j - 1] + cost;
      final v = (ins < del ? ins : del);
      curr[j] = v < sub ? v : sub;
      if (curr[j] < rowMin) rowMin = curr[j];
    }
    if (rowMin > maxDist) return -1; // early prune
    final tmp = prev; prev = curr; curr = tmp;
  }
  final d = prev[n];
  return d <= maxDist ? d : -1;
}

extension on SearchIndexManager {
  Future<File> _snapshotPath() async {
    final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/${SearchIndexManager._snapshotFile}');
  }

  Future<bool> _tryLoadSnapshot() async {
    try {
  final jsonMap = await _snapshotStore.load();
  if (jsonMap == null) return false;
      final version = jsonMap['version'] as int?;
      if (version != SearchIndexManager._snapshotVersion) return false; // mismatch version
  final dataVersion = jsonMap['dataVersion'] as String?;
  final currentHash = await _computeCorpusHash();
  if (dataVersion != currentHash) return false; // corpus changed
      final inv = (jsonMap['index'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).cast<String>()));
      final versesJson = (jsonMap['verses'] as Map<String, dynamic>);
      versesJson.forEach((k, v) {
        final obj = v as Map<String, dynamic>;
        _verseCache[k] = Verse(
          surahId: obj['surahNumber'] as int,
          verseNumber: obj['number'] as int,
          arabicText: obj['ar'] as String? ?? '',
          translation: obj['t'] as String?,
          transliteration: obj['tr'] as String?,
          verseKey: obj['verseKey'] as String? ?? k,
          juz: obj['juz'] as int?,
        );
      });
      _invertedIndex = inv;
      final next = jsonMap['nextSurah'] as int?; // if present & <=114 indicates partial
      if (next != null && next >= 1 && next <= 114) {
        _nextSurahToIndex = next;
        if (_nextSurahToIndex > 114) {
          // complete snapshot
          _incrementalMode = false;
        }
      } else {
        _nextSurahToIndex = 115; // mark complete
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveSnapshot({bool partial = false}) async {
    if (_invertedIndex == null) return;
    try {
      final versesMap = <String, dynamic>{};
      _verseCache.forEach((k, v) {
        versesMap[k] = {
          'surahNumber': v.surahNumber,
          'number': v.number,
          'verseKey': v.verseKey,
          'ar': v.textArabic,
          't': v.textTranslation,
          'tr': v.textTransliteration,
          'juz': v.juz,
        };
      });
  final payload = {
        'version': SearchIndexManager._snapshotVersion,
        'dataVersion': await _computeCorpusHash(),
        'index': _invertedIndex,
        'verses': versesMap,
        'createdAt': DateTime.now().toIso8601String(),
        'nextSurah': partial ? _nextSurahToIndex : 115, // 115 => complete ( > 114 )
  };
  await _snapshotStore.save(payload);
    } catch (_) {
      // ignore persistence failure silently
    }
  }

  // Compute a lightweight corpus hash using asset bytes to invalidate snapshots when data changes.
  Future<String> _computeCorpusHash() async {
    if (_cachedCorpusHash != null) return _cachedCorpusHash!;
    try {
      final hash = await _snapshotStore.computeCurrentDataVersion();
      _cachedCorpusHash = hash;
      return hash;
    } catch (_) {
      return 'v2:fallback';
    }
  }
}

class _ScoredVerse {
  final Verse verse;
  final int score;
  _ScoredVerse(this.verse, this.score);
}

/// Progress event for search index building
class SearchIndexProgress {
  final double progress; // 0..1
  final bool incremental; // true if still in incremental mode
  final bool complete; // true when fully built
  final int indexedSurahs; // counted surahs so far (114 when complete)
  final int totalSurahs;
  const SearchIndexProgress({
    required this.progress,
    required this.incremental,
    required this.complete,
    required this.indexedSurahs,
    required this.totalSurahs,
  });
}
