import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
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
  final Box<dynamic> _quranBox;
  final Box<dynamic> _translationBox;
  final Box<dynamic> _thematicIndexBox;
  final Box<dynamic> _transliterationBox;

  QuranLocalDataSourceImpl({
    required Box<dynamic> quranBox,
    required Box<dynamic> translationBox,
    required Box<dynamic> thematicIndexBox,
    required Box<dynamic> transliterationBox,
  })
      : _quranBox = quranBox,
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
    if (_translationBox.containsKey(translationKey)) {
      return _translationBox.get(translationKey);
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
    if (_thematicIndexBox.containsKey('thematic_index')) {
      return _thematicIndexBox.get('thematic_index');
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/temat.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      await _thematicIndexBox.put('thematic_index', jsonData);
      return jsonData;
    } catch (e) {
      throw Exception('Failed to load thematic index: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getTransliterations() async {
    if (_transliterationBox.containsKey('transliterations')) {
      return _transliterationBox.get('transliterations');
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/transliterations.json');
      final sw = Stopwatch()..start();
      final Map<String, dynamic> jsonData = await compute(_decodeJsonMap, jsonString);
      if (sw.elapsedMilliseconds > 50) {
        debugPrint('Decoded transliterations in ${sw.elapsedMilliseconds}ms (isolate)');
      }
      await _transliterationBox.put('transliterations', jsonData);
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
