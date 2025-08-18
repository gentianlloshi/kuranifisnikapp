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

  bool get isBuilt => _invertedIndex != null;
  bool get isBuilding => _building;

  // Persistence constants
  static const int _snapshotVersion = 1; // bump if tokenization / weighting changes
  static const String _snapshotFile = 'search_index_v$_snapshotVersion.json';

  SearchIndexManager({
    required this.getSurahsUseCase,
    required this.getSurahVersesUseCase,
  });

  /// Ensures the index is built. Multiple concurrent callers will await the same future.
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
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveSnapshot() async {
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
