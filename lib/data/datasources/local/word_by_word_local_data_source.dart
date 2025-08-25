import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../domain/entities/word_by_word.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';

abstract class WordByWordLocalDataSource {
  Future<List<WordByWordVerse>> getWordByWordData(int surahNumber);
  Future<List<TimestampData>> getTimestampData(int surahNumber);
}

class WordByWordLocalDataSourceImpl implements WordByWordLocalDataSource {
  Box<dynamic>? _wordByWordBox;
  Box<dynamic>? _timestampBox;

  // Increment this when changing parsing / storage format so cached Hive data is invalidated.
  static const int _cacheVersion = 2;

  WordByWordLocalDataSourceImpl({
    Box<dynamic>? wordByWordBox,
    Box<dynamic>? timestampBox,
  })  : _wordByWordBox = wordByWordBox,
        _timestampBox = timestampBox;

  @override
  Future<List<WordByWordVerse>> getWordByWordData(int surahNumber) async {
  final String boxKey = 'word_by_word_surah_${surahNumber}_v$_cacheVersion';
    if (_wordByWordBox == null || !_wordByWordBox!.isOpen) {
      _wordByWordBox = await Hive.openBox('wordByWordBox');
    }
    if (_wordByWordBox!.containsKey(boxKey)) {
      final List<dynamic> cachedData = _wordByWordBox!.get(boxKey);
  // ignore: avoid_print
  // ignore: use_build_context_synchronously
  Logger.d('cache hit words surah=$surahNumber count=${cachedData.length}', tag: 'WBW');
      return cachedData.map((item) {
        if (item is Map) {
          // Coerce to Map<String,dynamic> for model parser
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          return WordByWordVerse.fromJson(map);
        }
        return WordByWordVerse.fromJson(item as Map<String, dynamic>);
      }).toList();
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/word/$surahNumber.json');
      final verses = await compute(_parseWordByWordJson, jsonString);
  // _wordByWordBox is guaranteed non-null after lazy open above
  await _wordByWordBox!.put(boxKey, verses.map((v) => v.toJson()).toList());
  // ignore: avoid_print
  Logger.d('loaded asset words surah=$surahNumber count=${verses.length}', tag: 'WBW');
      return verses;
    } catch (e) {
      throw Exception('Failed to load word by word data for surah $surahNumber: $e');
    }
  }

  @override
  Future<List<TimestampData>> getTimestampData(int surahNumber) async {
  final String boxKey = 'timestamp_surah_${surahNumber}_v$_cacheVersion';
    if (_timestampBox == null || !_timestampBox!.isOpen) {
      _timestampBox = await Hive.openBox('timestampBox');
    }
    if (_timestampBox!.containsKey(boxKey)) {
      final List<dynamic> cachedData = _timestampBox!.get(boxKey);
  // ignore: avoid_print
  Logger.d('cache hit ts surah=$surahNumber count=${cachedData.length}', tag: 'WBW');
      return cachedData.map((item) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          return TimestampData.fromJson(map);
        }
        return TimestampData.fromJson(item as Map<String, dynamic>);
      }).toList();
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/time/time$surahNumber.json');
      final timestamps = await compute(_parseTimestampJson, jsonString);
  // _timestampBox is guaranteed non-null after lazy open above
  await _timestampBox!.put(boxKey, timestamps.map((t) => t.toJson()).toList());
  // ignore: avoid_print
  Logger.d('loaded asset ts surah=$surahNumber count=${timestamps.length}', tag: 'WBW');
      return timestamps;
    } catch (e) {
      throw Exception('Failed to load timestamp data for surah $surahNumber: $e');
    }
  }
}

// Top-level isolate parsing helpers
List<WordByWordVerse> _parseWordByWordJson(String jsonString) {
  final Map<String, dynamic> jsonData = json.decode(jsonString);
  final List<WordByWordVerse> verses = [];
  jsonData.forEach((key, value) {
    final verseNum = int.parse(key);
  final mapVal = value as Map<String, dynamic>;
  final List<dynamic> arr = mapVal['words'] as List<dynamic>? ?? mapVal.values.firstWhere((v)=>v is List, orElse: ()=>[]) as List<dynamic>;
    final words = <WordData>[];
    int cursor = 0;
    for (final w in arr) {
      final text = w.toString();
      final start = cursor;
      cursor += text.length + 1;
      words.add(WordData(arabic: text, translation: '', transliteration: '', charStart: start, charEnd: start + text.length));
    }
    verses.add(WordByWordVerse(verseNumber: verseNum, words: words));
  });
  return verses;
}

List<TimestampData> _parseTimestampJson(String jsonString) {
  final dynamic decoded = json.decode(jsonString);
  // Support both legacy map {"1": [...]} and new list format [{"ayah":1,"segments":[[idx,next,start,end],...]}]
  if (decoded is Map<String, dynamic>) {
    final List<TimestampData> out = [];
    decoded.forEach((key, value) {
      out.add(TimestampData.fromJson({
        'verse': int.parse(key),
        'words': value,
      }));
    });
    return out;
  }
  if (decoded is List) {
    final List<TimestampData> out = [];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final ayah = item['ayah'] as int? ?? item['verse'] as int? ?? item['id'] as int?;
        final segments = item['segments'] as List<dynamic>?;
        if (ayah != null && segments != null) {
          // Expand phrase segments into per-word timestamps.
          // Assumed segment format: [wordStartIndex, nextWordIndex, startMs, endMs]
          // We linearly interpolate times for each word in the span.
          final Map<int, Map<String, int>> perWord = {};
          int maxNextWord = 0;
          for (final seg in segments) {
            if (seg is List && seg.length >= 4) {
              final ws = seg[0];
              final wn = seg[1];
              final start = seg[2];
              final end = seg[3];
              if (ws is int && wn is int && start is int && end is int && end >= start) {
                maxNextWord = wn > maxNextWord ? wn : maxNextWord;
                final span = wn - ws;
                final duration = end - start;
                if (span <= 1) {
                  perWord[ws] = {'start': start, 'end': end};
                } else {
                  for (int k = 0; k < span; k++) {
                    final wIdx = ws + k;
                    final wStart = start + (duration * k / span).round();
                    final wEnd = start + (duration * (k + 1) / span).round();
                    perWord[wIdx] = {'start': wStart, 'end': wEnd};
                  }
                }
              }
            }
          }
          // Produce ordered list from 0 .. maxNextWord-1 if contiguous, else only collected keys sorted.
            final orderedKeys = perWord.keys.toList()..sort();
            final words = <Map<String, int>>[];
            for (final k in orderedKeys) {
              final entry = perWord[k]!;
              words.add({'start': entry['start']!, 'end': entry['end']!});
            }
          // ignore: avoid_print
          if (words.isNotEmpty) {
            final expected = maxNextWord;
            if (words.length != expected) {
              Logger.w('expand warn verse=$ayah words=${words.length} expected=$expected', tag: 'WBW');
            } else {
              Logger.d('expanded verse=$ayah words=${words.length}', tag: 'WBW');
            }
          }
          out.add(TimestampData.fromJson({'verse': ayah, 'words': words}));
        }
      }
    }
    return out;
  }
  throw FormatException('Unsupported timestamp JSON format');
}


