// Dart script to prebuild the search index asset from project assets.
// Run with: dart run tool/build_search_index.dart
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final root = Directory.current.path;
  final assetsDir = Directory('assets/data');
  if (!assetsDir.existsSync()) {
    stderr.writeln('assets/data not found. Run from repo root.');
    exit(1);
  }
  final arabic = await File('${assetsDir.path}/arabic_quran.json').readAsString();
  final t = await File('${assetsDir.path}/sq_ahmeti.json').readAsString();
  final tr = await File('${assetsDir.path}/transliterations.json').readAsString();

  Map<String,dynamic> parse(String s) => json.decode(s) as Map<String,dynamic>;
  final arabicObj = parse(arabic);
  final tObj = parse(t);
  Map<String,dynamic> trObj; try { trObj = parse(tr); } catch(_) { trObj = {}; }

  final versesMap = <String, Map<String, dynamic>>{};
  final List aList = (arabicObj['quran'] as List?) ?? const [];
  for (final item in aList) {
    if (item is Map<String,dynamic>) {
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
  final List tList = (tObj['quran'] as List?) ?? const [];
  for (final item in tList) {
    if (item is Map<String,dynamic>) {
      final s = (item['chapter'] as num?)?.toInt();
      final v = (item['verse'] as num?)?.toInt();
      if (s == null || v == null) continue;
      final key = '$s:$v';
      final existing = versesMap[key] ?? {
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
  trObj.forEach((sk, obj) {
    final s = int.tryParse(sk); if (s == null) return;
    if (obj is Map<String,dynamic>) {
      obj.forEach((vk, val) {
        final v = int.tryParse(vk); if (v == null) return;
        final key = '$s:$v';
        final existing = versesMap[key] ?? {
          'surahNumber': s,
          'number': v,
          'verseKey': key,
          'ar': '',
          't': '',
          'tr': '',
        };
        existing['tr'] = (val ?? '').toString();
        versesMap[key] = existing;
      });
    }
  });

  // Build inverted index (simple local implementation mirrors lib one)
  Map<String, List<String>> index = {};
  Iterable<String> tokenize(String text) {
    final lower = text.toLowerCase();
    return lower.split(RegExp(r'[^a-zçëšžáéíóúâêîôûäöü0-9]+')).where((e) => e.isNotEmpty);
  }
  String normalizeLatin(String input) {
    var s = input.toLowerCase().replaceAll('ç','c').replaceAll('ë','e');
    return s;
  }
  for (final e in versesMap.entries) {
    final key = e.key; final m = e.value;
    final set = <String>{}
      ..addAll(tokenize(m['t'] ?? ''))
      ..addAll(tokenize(m['tr'] ?? ''))
      ..addAll(tokenize(m['ar'] ?? ''));
    final seen = <String>{};
    for (final tok in set) {
      if (!seen.add(tok)) continue;
      final list = index.putIfAbsent(tok, () => <String>[]);
      list.add(key);
      final norm = normalizeLatin(tok);
      if (norm != tok) {
        final l2 = index.putIfAbsent(norm, () => <String>[]);
        l2.add(key);
      }
    }
  }

  final out = {
    'index': index,
    'verses': versesMap,
    'version': 1,
  };
  final outFile = File('${assetsDir.path}/search_index.json');
  await outFile.writeAsString(json.encode(out));
  stdout.writeln('Wrote ${outFile.path} (${await outFile.length()} bytes)');
}
