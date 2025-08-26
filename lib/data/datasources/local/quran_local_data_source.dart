import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding; // for ensureInitialized()
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';

abstract class QuranLocalDataSource {
  Future<List<Surah>> getQuranData();
  Future<List<Surah>> getSurahMetas(); // metas only, no verses
  Future<Map<String, dynamic>> getTranslationData(String translationKey);
  Future<Map<String, dynamic>> getThematicIndex();
  Future<Map<String, dynamic>> getTransliterations();
  Future<List<Verse>> getSurahVerses(int surahNumber);
}

class QuranLocalDataSourceImpl implements QuranLocalDataSource {
  final Box<dynamic> _quranBox; // critical – opened at startup
  Box<dynamic> _translationBox; // opened early (active translation cache)
  // Large static assets: prefer in-memory cache over Hive to avoid slow box open/writes
  Map<String, dynamic>? _thematicIndexCache;
  Map<String, dynamic>? _transliterationsCache;

  QuranLocalDataSourceImpl({
    required Box<dynamic> quranBox,
    required Box<dynamic> translationBox,
  })  : _quranBox = quranBox,
        _translationBox = translationBox;

  @override
  Future<List<Surah>> getQuranData() async {
    if (_quranBox.containsKey('all_surahs')) {
      final List<dynamic> cachedData = _quranBox.get('all_surahs');
      return cachedData.map((json) => Surah.fromJson(json)).toList();
    }
    try {
      // Ensure binding is initialized before touching RootIsolateToken
      // (defensive: some startup paths may call into this very early)
      WidgetsFlutterBinding.ensureInitialized();
      // Load asset strings on the main isolate (binding-safe),
      // then offload heavy JSON parsing/structuring to an isolate.
      final String arabicStr = await rootBundle.loadString('assets/data/arabic_quran.json');
      String? suretStr; try { suretStr = await rootBundle.loadString('assets/data/suret.json'); } catch (_) { suretStr = null; }
      final List<dynamic> surahJsonList = await compute(_parseQuranDataFromStrings, {
        'arabic': arabicStr,
        'suret': suretStr,
      });
      final List<Surah> surahs = surahJsonList.map((m) => Surah.fromJson(m as Map<String,dynamic>)).toList()
        ..sort((a,b)=>a.number.compareTo(b.number));
      await _quranBox.put('all_surahs', surahs.map((s) => s.toJson()).toList());
      return surahs;
    } catch (e) { throw Exception('Failed to load Quran data: $e'); }
  }

  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async {
    // On-demand load only verses for the requested surah
    WidgetsFlutterBinding.ensureInitialized();
    final String arabicStr = await rootBundle.loadString('assets/data/arabic_quran.json');
    final Map<String,dynamic> arabicJson = json.decode(arabicStr) as Map<String,dynamic>;
    final List<dynamic> verses = (arabicJson['quran'] as List?) ?? const [];
    final out = <Verse>[];
    for (final item in verses) {
      if (item is! Map<String,dynamic>) continue;
      final s = (item['chapter'] as num?)?.toInt();
      if (s != surahNumber) continue;
      final v = (item['verse'] as num?)?.toInt() ?? 0;
      out.add(Verse(
        surahId: surahNumber,
        verseNumber: v,
        arabicText: (item['text'] ?? '').toString(),
        translation: null,
        transliteration: null,
        verseKey: '$surahNumber:$v',
      ));
    }
    return out;
  }

  @override
  Future<List<Surah>> getSurahMetas() async {
    // Build metas from suret.json only (fast; no verse bodies)
    WidgetsFlutterBinding.ensureInitialized();
    final String suretStr = await rootBundle.loadString('assets/data/suret.json');
    final List<dynamic> metaList = json.decode(suretStr) as List<dynamic>;
    final out = <Surah>[];
    for (final m in metaList) {
      if (m is! Map<String,dynamic>) continue;
      final n = m['numri'];
      if (n is! int) continue;
      final nameArabic = (m['emri_arab'] ?? 'سورة $n').toString();
      final nameTranslation = (m['emri_shqip'] ?? 'Sure $n').toString();
      final meaning = (m['kuptimi'] ?? nameTranslation).toString();
      final revelation = (m['vendi'] ?? (n < 90 ? 'Medinë' : 'Mekë')).toString();
      final versesCount = (m['numri_ajeteve'] is int) ? m['numri_ajeteve'] as int : 0;
      out.add(Surah(
        id: n,
        number: n,
        nameArabic: nameArabic,
        nameTransliteration: meaning,
        nameTranslation: nameTranslation,
        versesCount: versesCount,
        revelation: revelation,
        verses: const [], // metas only
      ));
    }
    out.sort((a,b)=> a.number.compareTo(b.number));
    return out;
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
    // Use in-memory cache only. Avoid Hive for these large static assets to reduce startup I/O.
    if (_thematicIndexCache != null) return _thematicIndexCache!;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/temat.json');
      // Offload heavy decode to isolate (mirrors translation/transliteration parsing).
      final sw = Stopwatch()..start();
      final Map<String, dynamic> jsonData = await compute(_decodeJsonMap, jsonString);
      if (sw.elapsedMilliseconds > 40) {
        debugPrint('Decoded thematic index in ${sw.elapsedMilliseconds}ms (isolate)');
      }
      _thematicIndexCache = jsonData;
      return _thematicIndexCache!;
    } catch (e) {
      throw Exception('Failed to load thematic index: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getTransliterations() async {
    // In-memory cache only; avoid Hive to prevent very slow box opens for huge payloads.
    if (_transliterationsCache != null) return _transliterationsCache!;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/transliterations.json');
      final sw = Stopwatch()..start();
      final Map<String, dynamic> jsonData = await compute(_decodeJsonMap, jsonString);
      if (sw.elapsedMilliseconds > 50) {
        debugPrint('Decoded transliterations in ${sw.elapsedMilliseconds}ms (isolate)');
      }
      _transliterationsCache = jsonData;
      return _transliterationsCache!;
    } catch (e) {
      throw Exception('Failed to load transliterations: $e');
    }
  }
}

// Isolate helper for heavy parsing from strings (safe; no rootBundle in isolate)
Future<List<dynamic>> _parseQuranDataFromStrings(Map<String, String?> payload) async {
  final arabicStr = payload['arabic'] ?? '{}';
  final suretStr = payload['suret'];
  return _buildSurahListFromJsonStrings(arabicStr, suretStr);
}

Map<String, dynamic> _decodeJsonMap(String jsonStr) {
  return json.decode(jsonStr) as Map<String, dynamic>;
}

// Shared builder used by both isolate and main-isolate paths
List<Map<String, dynamic>> _buildSurahListFromJsonStrings(String arabicStr, String? suretStr) {
  final Map<String,dynamic> arabicJson = json.decode(arabicStr) as Map<String,dynamic>;
  final List<dynamic> verses = arabicJson['quran'] ?? [];
  final Map<int,List<Map<String,dynamic>>> surahsMap = {};
  for (final verse in verses) {
    final int chapter = verse['chapter'];
    (surahsMap[chapter] ??= []).add({'number': verse['verse'], 'text': verse['text']});
  }
  Map<int, Map<String,dynamic>> metaMap = {};
  if (suretStr != null) {
    try {
      final List<dynamic> metaList = json.decode(suretStr) as List<dynamic>;
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
