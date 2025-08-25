import 'dart:convert';
import 'inverted_index_builder.dart' as idx;

/// Payload keys expected by [buildFullIndexFromAssets]
/// - 'arabic': JSON string of assets/data/arabic_quran.json
/// - 'translation': JSON string of assets/data/<translation>.json (e.g., sq_ahmeti.json)
/// - 'transliterations': JSON string of assets/data/transliterations.json
///
/// Returns a Map<String, dynamic> with keys:
/// - 'index': Map<String, List<String>> inverted index
/// - 'verses': Map<String, Map<String, dynamic>> minimal verse data {key -> {surahNumber, number, verseKey, ar, t, tr}}
Map<String, dynamic> buildFullIndexFromAssets(Map<String, String> payload) {
  final arabicJson = payload['arabic'] ?? '{}';
  final translationJson = payload['translation'] ?? '{}';
  final translitJson = payload['transliterations'] ?? '{}';

  // Parse inputs
  final arabic = json.decode(arabicJson) as Map<String, dynamic>;
  final tData = json.decode(translationJson) as Map<String, dynamic>;
  Map<String, dynamic> trData;
  try {
    trData = json.decode(translitJson) as Map<String, dynamic>;
  } catch (_) {
    trData = <String, dynamic>{};
  }

  // Normalize into a key->fields map
  // Arabic format: { "quran": [ {"chapter":1, "verse":1, "text":"..."}, ... ] }
  final versesMap = <String, Map<String, dynamic>>{};
  final List<dynamic> aList = (arabic['quran'] as List?) ?? const [];
  for (final item in aList) {
    if (item is Map<String, dynamic>) {
      final s = (item['chapter'] as num?)?.toInt();
      final v = (item['verse'] as num?)?.toInt();
      if (s == null || v == null) continue;
      final key = '$s:$v';
      versesMap[key] = {
        'surahNumber': s,
        'number': v,
        'verseKey': key,
        'ar': item['text'] as String? ?? '',
        't': '',
        'tr': '',
      };
    }
  }

  // Translation format typically mirrors arabic: { "quran": [ {"chapter":1, "verse":1, "text":"..."}, ... ] }
  final List<dynamic> tList = (tData['quran'] as List?) ?? const [];
  for (final item in tList) {
    if (item is Map<String, dynamic>) {
      final s = (item['chapter'] as num?)?.toInt();
      final v = (item['verse'] as num?)?.toInt();
      if (s == null || v == null) continue;
      final key = '$s:$v';
      final existing = versesMap[key] ?? <String, dynamic>{
        'surahNumber': s,
        'number': v,
        'verseKey': key,
        'ar': '',
        't': '',
        'tr': '',
      };
      existing['t'] = (item['text'] ?? '').toString();
      versesMap[key] = existing;
    }
  }

  // Transliterations format seen in repo: { "<surah>": { "<verse>": "text" } }
  try {
    for (final entry in trData.entries) {
      final s = int.tryParse(entry.key);
      if (s == null) continue;
      final obj = entry.value;
      if (obj is Map<String, dynamic>) {
        for (final e in obj.entries) {
          final v = int.tryParse(e.key);
          if (v == null) continue;
          final key = '$s:$v';
          final existing = versesMap[key] ?? <String, dynamic>{
            'surahNumber': s,
            'number': v,
            'verseKey': key,
            'ar': '',
            't': '',
            'tr': '',
          };
          existing['tr'] = (e.value ?? '').toString();
          versesMap[key] = existing;
        }
      }
    }
  } catch (_) {
    // Ignore transliteration merge errors
  }

  // Build raw rows for index builder
  final raw = <Map<String, dynamic>>[];
  versesMap.forEach((key, v) {
    raw.add({'key': key, 't': v['t'] ?? '', 'tr': v['tr'] ?? '', 'ar': v['ar'] ?? ''});
  });

  final index = idx.buildInvertedIndex(raw);
  return {
    'index': index,
    'verses': versesMap,
  };
}
