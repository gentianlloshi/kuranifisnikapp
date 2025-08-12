import 'dart:async';
import 'package:flutter/foundation.dart';
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

  SearchIndexManager({
    required this.getSurahsUseCase,
    required this.getSurahVersesUseCase,
  });

  /// Ensures the index is built. Multiple concurrent callers will await the same future.
  Future<void> ensureBuilt({void Function(double progress)? onProgress}) async {
    if (_invertedIndex != null) return;
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
    } catch (_) {
      _invertedIndex = null;
      rethrow;
    } finally {
      _building = false;
      _buildCompleter?.complete();
    }
  }

  List<Verse> search(String query) {
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
      int score = base * 10;
      final translation = (verse.textTranslation ?? '').toLowerCase();
      for (final ft in fullTokens) {
        if (translation.contains(ft)) score += 25;
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

class _ScoredVerse {
  final Verse verse;
  final int score;
  _ScoredVerse(this.verse, this.score);
}
