import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';

abstract class QuranLocalDataSource {
  Future<List<Surah>> getQuranData();
  Future<Map<String, dynamic>> getTranslationData(String translationKey);
  Future<Map<String, dynamic>> getThematicIndex();
  Future<Map<String, dynamic>> getTransliterations();
  Future<List<Verse>> getSurahVerses(int surahNumber);
}

class QuranLocalDataSourceImpl implements QuranLocalDataSource {
  final Box<dynamic> _quranBox; // critical – opened at startup
  Box<dynamic> _translationBox; // opened early (active translation cache)
  Box<dynamic>? _thematicIndexBox; // deferred
  Box<dynamic>? _transliterationBox; // deferred

  QuranLocalDataSourceImpl({
    required Box<dynamic> quranBox,
    required Box<dynamic> translationBox,
    Box<dynamic>? thematicIndexBox,
    Box<dynamic>? transliterationBox,
  })  : _quranBox = quranBox,
        _translationBox = translationBox,
        _thematicIndexBox = thematicIndexBox,
        _transliterationBox = transliterationBox;

  @override
  Future<List<Surah>> getQuranData() async {
    if (_quranBox.containsKey('all_surahs')) {
      final List<dynamic> cachedData = _quranBox.get('all_surahs');
      return cachedData.map((json) => Surah.fromJson(json)).toList();
    }

    try {
      final String arabicJsonString = await rootBundle.loadString('assets/data/arabic_quran.json');
      String? suretJsonString; try { suretJsonString = await rootBundle.loadString('assets/data/suret.json'); } catch(_){ }
      final List<dynamic> surahJsonList = await compute(_parseQuranDataIsolate, {
        'arabic': arabicJsonString,
        'suret': suretJsonString,
      });
      final List<Surah> surahs = surahJsonList.map((m) => Surah.fromJson(m as Map<String,dynamic>)).toList()
        ..sort((a,b)=>a.number.compareTo(b.number));
      await _quranBox.put('all_surahs', surahs.map((s) => s.toJson()).toList());
      return surahs;
    } catch (e) { throw Exception('Failed to load Quran data: $e'); }
  }

  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async {
    final surahs = await getQuranData();
    final surah = surahs.firstWhere((s) => s.number == surahNumber);
    return surah.verses;
  }

  // Legacy fallback removed; metadata now sourced from suret.json directly.

  @override
  Future<Map<String, dynamic>> getTranslationData(String translationKey) async {
    // Translation box always available (opened early) but keep defensive lazy-open in case of future deferral.
    if (!_translationBox.isOpen) {
      _translationBox = await Hive.openBox('translationBox');
    }
    if (_translationBox.containsKey(translationKey)) {
      return _translationBox.get(translationKey) as Map<String, dynamic>;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/$translationKey.json');
      final sw = Stopwatch()..start();
      final Map<String, dynamic> jsonData = await compute(_decodeJsonMap, jsonString);
      if (sw.elapsedMilliseconds > 50) {
        debugPrint('Decoded translation $translationKey in ${sw.elapsedMilliseconds}ms (isolate)');
      }
      await _translationBox.put(translationKey, jsonData);
      return jsonData;
    } catch (e) {
      throw Exception('Failed to load translation data for $translationKey: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getThematicIndex() async {
    final box = _thematicIndexBox ??= await Hive.openBox('thematicIndexBox');
    if (!box.containsKey('thematic_index')) {
      // First time access triggers an actual asset decode (instrument lazy open)
      PerfMetrics.instance.incLazyBoxOpen();
    }
    if (box.containsKey('thematic_index')) {
      return box.get('thematic_index') as Map<String, dynamic>;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/temat.json');
      // Offload heavy decode to isolate (mirrors translation/transliteration parsing).
      final sw = Stopwatch()..start();
      final Map<String, dynamic> jsonData = await compute(_decodeJsonMap, jsonString);
      if (sw.elapsedMilliseconds > 40) {
        debugPrint('Decoded thematic index in ${sw.elapsedMilliseconds}ms (isolate)');
      }
      await box.put('thematic_index', jsonData);
      return jsonData;
    } catch (e) {
      throw Exception('Failed to load thematic index: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getTransliterations() async {
    final box = _transliterationBox ??= await Hive.openBox('transliterationBox');
    if (!box.containsKey('transliterations')) {
  PerfMetrics.instance.incTransliterationCacheHit();
      PerfMetrics.instance.incLazyBoxOpen();
    }
    if (box.containsKey('transliterations')) {
      return box.get('transliterations') as Map<String, dynamic>;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/transliterations.json');
      final sw = Stopwatch()..start();
      final Map<String, dynamic> jsonData = await compute(_decodeJsonMap, jsonString);
      if (sw.elapsedMilliseconds > 50) {
        debugPrint('Decoded transliterations in ${sw.elapsedMilliseconds}ms (isolate)');
      }
  await box.put('transliterations', jsonData);
      return jsonData;
    } catch (e) {
      throw Exception('Failed to load transliterations: $e');
    }
  }
}

// Isolate helper for heavy parsing
List<dynamic> _parseQuranDataIsolate(Map<String, String?> payload) {
  final arabicStr = payload['arabic']!;
  final suretStr = payload['suret'];
  final Map<String,dynamic> arabicJson = json.decode(arabicStr);
  final List<dynamic> verses = arabicJson['quran'] ?? [];
  final Map<int,List<Map<String,dynamic>>> surahsMap = {};
  for (final verse in verses) {
    final int chapter = verse['chapter'];
    (surahsMap[chapter] ??= []).add({'number': verse['verse'], 'text': verse['text']});
  }
  Map<int, Map<String,dynamic>> metaMap = {};
  if (suretStr != null) {
    try {
      final List<dynamic> metaList = json.decode(suretStr);
      for (final m in metaList) {
        if (m is Map<String,dynamic> && m['numri'] is int) {
          metaMap[m['numri'] as int] = m;
        }
      }
    } catch(_){ }
  }
  final out = <Map<String,dynamic>>[];
  final numbers = surahsMap.keys.toList()..sort();
  for (final n in numbers) {
    final versesData = surahsMap[n]!;
    final meta = metaMap[n];
    final nameArabic = meta != null && meta['emri_arab'] is String ? meta['emri_arab'] as String : 'سورة $n';
    final nameTranslation = meta != null && meta['emri_shqip'] is String ? meta['emri_shqip'] as String : 'Sure $n';
    final meaning = meta != null && meta['kuptimi'] is String ? meta['kuptimi'] as String : nameTranslation;
    final revelation = meta != null && meta['vendi'] is String ? meta['vendi'] as String : (n < 90 ? 'Medinë' : 'Mekë');
    final versesCount = meta != null && meta['numri_ajeteve'] is int ? meta['numri_ajeteve'] as int : versesData.length;
    out.add({
      'id': n,
      'number': n,
      'nameArabic': nameArabic,
      'nameTransliteration': meaning,
      'nameTranslation': nameTranslation,
      'versesCount': versesCount,
      'revelation': revelation,
      'verses': [ for (final v in versesData) {
        'surahId': n,
        'verseNumber': v['number'],
        'arabicText': v['text'],
        'verseKey': '$n:${v['number']}',
      } ],
    });
  }
  return out;
}

Map<String, dynamic> _decodeJsonMap(String jsonStr) {
  return json.decode(jsonStr) as Map<String, dynamic>;
}
