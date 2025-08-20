import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/verse.dart';
import '../../domain/usecases/get_surah_verses_usecase.dart';
import '../../domain/usecases/get_surahs_usecase.dart';
import 'inverted_index_builder.dart' as idx;

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

  bool get isBuilt => _invertedIndex != null;
  bool get isBuilding => _building;

  // Persistence constants
  static const int _snapshotVersion = 2; // bumped for incremental structure
  static const String _snapshotFile = 'search_index_v$_snapshotVersion.json';

  SearchIndexManager({
    required this.getSurahsUseCase,
    required this.getSurahVersesUseCase,
  });

  /// Ensures the index is fully built (blocking until completion) unless already built.
  Future<void> ensureBuilt({void Function(double progress)? onProgress}) async {
    if (_invertedIndex != null) return;
    // Try fast-path load from snapshot
    if (await _tryLoadSnapshot()) {
      if (onProgress != null) onProgress(1.0);
      return;
    }
    if (_building) {
      return _buildCompleter?.future;
    }
    _building = true;
    _buildCompleter = Completer<void>();
    try {
      final List<Map<String, dynamic>> raw = [];
      for (int s = 1; s <= 114; s++) {
        try {
          final verses = await getSurahVersesUseCase.call(s);
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
          if (onProgress != null) {
            onProgress(s / 114.0 * 0.5);
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        } catch (_) {
          // Skip surah silently
        }
      }
      if (onProgress != null) onProgress(0.55);
      _invertedIndex = await compute(idx.buildInvertedIndex, raw);
      if (onProgress != null) onProgress(1.0);
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
    if (_invertedIndex != null && !_incrementalMode) return; // already fully built
    if (_building) return;
    _incrementalMode = true;
    _building = true;
    _buildCompleter = Completer<void>();
    _invertedIndex ??= <String, List<String>>{}; // start empty index
    () async {
      try {
        // Attempt load (may be partial)
        if (_nextSurahToIndex == 1 && await _tryLoadSnapshot()) {
          // If snapshot marks complete we can stop.
          if (_nextSurahToIndex > 114) {
            _building = false;
            _incrementalMode = false;
            _buildCompleter?.complete();
            if (onProgress != null) onProgress(1.0);
            return;
          }
        }
        for (int s = _nextSurahToIndex; s <= 114; s++) {
          _nextSurahToIndex = s; // record current for snapshot resume
          try {
            final verses = await getSurahVersesUseCase.call(s);
            for (final v in verses) {
              final key = '${v.surahNumber}:${v.number}';
              _verseCache[key] = v;
              _indexVerse(v);
            }
          } catch (_) {/* skip */}
          if (onProgress != null) onProgress(s / 114.0);
          if (s % 5 == 0 || s == 114) {
            unawaited(_saveSnapshot(partial: s != 114));
          }
          // Yield to UI
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        _incrementalMode = false;
        if (onProgress != null) onProgress(1.0);
      } finally {
        _building = false;
        _buildCompleter?.complete();
      }
    }();
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
    for (final t in tokens) {
      final list = _invertedIndex![t];
      if (list == null) continue;
      for (final key in list) {
        candidateScores.update(key, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    if (candidateScores.isEmpty) return [];
    final fullTokens = _tokenize(query).map((e) => e.toLowerCase()).toSet();
    final scored = <_ScoredVerse>[];
    candidateScores.forEach((key, base) {
      final verse = _verseCache[key];
      if (verse == null) return;
      if (juzFilter != null && verse.juz != juzFilter) return;
      int score = base * 10;
      if (includeTranslation) {
        final translation = (verse.textTranslation ?? '').toLowerCase();
        for (final ft in fullTokens) {
          if (translation.contains(ft)) score += 25;
        }
      }
      if (includeArabic) {
        final ar = (verse.textArabic ?? '').toLowerCase();
        for (final ft in fullTokens) {
          if (ar.contains(ft)) score += 15; // lower weight
        }
      }
      if (includeTransliteration) {
        final tr = (verse.textTransliteration ?? '').toLowerCase();
        for (final ft in fullTokens) {
          if (tr.contains(ft)) score += 10; // lowest weight
        }
      }
      scored.add(_ScoredVerse(verse, score));
    });
    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final s = a.verse.surahNumber.compareTo(b.verse.surahNumber);
      if (s != 0) return s;
      return a.verse.number.compareTo(b.verse.number);
    });
    return scored.map((e) => e.verse).toList();
  }

  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    final parts = lower.split(RegExp(r'[^a-zçëšžáéíóúâêîôûäöü0-9]+'));
    return parts.where((p) => p.isNotEmpty).toList();
  }

  List<String> _expandQueryTokens(String query) {
    final raw = _tokenize(query);
    final result = <String>[];
    for (final r in raw) {
      if (r.length <= 2) {
        result.add(r);
        continue;
      }
      result.add(r);
      final norm = r.replaceAll('ç', 'c').replaceAll('ë', 'e');
      if (norm != r) result.add(norm);
    }
    return result.toSet().toList();
  }

  // Tokenize & insert a single verse into the existing in-memory inverted index (incremental mode)
  void _indexVerse(Verse v) {
    if (_invertedIndex == null) return;
    final key = '${v.surahNumber}:${v.number}';
    final tokens = <String>{}
      ..addAll(_tokenize((v.textTranslation ?? '')))
      ..addAll(_tokenize((v.textTransliteration ?? '')))
      ..addAll(_tokenize(_normalizeArabic((v.textArabic))));
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
}

extension on SearchIndexManager {
  Future<File> _snapshotPath() async {
    final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/${SearchIndexManager._snapshotFile}');
  }

  Future<bool> _tryLoadSnapshot() async {
    try {
      final file = await _snapshotPath();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      final jsonMap = json.decode(content) as Map<String, dynamic>;
      final version = jsonMap['version'] as int?;
      if (version != SearchIndexManager._snapshotVersion) return false; // mismatch version
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
      final file = await _snapshotPath();
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
      final payload = json.encode({
        'version': SearchIndexManager._snapshotVersion,
        'index': _invertedIndex,
        'verses': versesMap,
        'createdAt': DateTime.now().toIso8601String(),
        'nextSurah': partial ? _nextSurahToIndex : 115, // 115 => complete ( > 114 )
      });
      await file.writeAsString(payload, flush: true);
    } catch (_) {
      // ignore persistence failure silently
    }
  }
}

class _ScoredVerse {
  final Verse verse;
  final int score;
  _ScoredVerse(this.verse, this.score);
}
