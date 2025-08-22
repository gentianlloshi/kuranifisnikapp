// Isolate helper to build inverted index for verses
import 'package:kurani_fisnik_app/core/search/stemmer.dart';
// Input: List<Map<String,dynamic>> where each map has keys: 'key' (verseKey),
// 't' (translation), 'tr' (transliteration), 'ar' (arabic)
// Output: Map<String, List<String>> inverted index token -> list of verseKeys

const int _kMinPrefixLen = 3;

Map<String, List<String>> _createIndex(List<Map<String, dynamic>> raw) {
  final Map<String, List<String>> index = {};
  for (final row in raw) {
    final verseKey = row['key'] as String?;
    final text = (row['t'] ?? '') as String;
    final translit = (row['tr'] ?? '') as String;
    final arabic = (row['ar'] ?? '') as String;
    if (verseKey == null || verseKey.isEmpty) continue;
    final tokens = <String>{}
      ..addAll(_tokenize(text))
      ..addAll(_tokenize(translit))
      ..addAll(_tokenize(_normalizeArabic(arabic)));
    final seen = <String>{};
    for (final tok in tokens) {
      if (tok.isEmpty) continue;
      final norm = _normalizeLatin(tok);
  final stem = lightStem(norm);
      // Base token
      void addToken(String t){
        if (seen.add(t)) {
          final list = index.putIfAbsent(t, () => <String>[]);
          list.add(verseKey);
        }
      }
      addToken(tok);
      if (norm != tok) addToken(norm);
      if (stem != norm && stem.length >= 3) addToken(stem);
      // Prefix indexing (for incremental / partial search) from length _kMinPrefixLen..min(10,len-1)
      final baseForPrefix = stem.length >= 3 ? stem : norm;
      if (baseForPrefix.length >= _kMinPrefixLen) {
        final maxPref = baseForPrefix.length - 1 < 10 ? baseForPrefix.length - 1 : 10; // cap at 10 chars
        for (int l = _kMinPrefixLen; l <= maxPref; l++) {
          addToken(baseForPrefix.substring(0, l));
        }
      }
    }
  }
  return index;
}

List<String> _tokenize(String text) {
  final lower = text.toLowerCase();
  final parts = lower.split(RegExp(r'[^a-zçëšžáéíóúâêîôûäöü0-9]+'));
  return parts.where((p) => p.isNotEmpty).toList();
}

// Basic Arabic normalization: remove diacritics and common elongations
String _normalizeArabic(String input) {
  var s = input;
  // Remove tashkeel
  s = s.replaceAll(RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
  // Normalize alef forms
  s = s.replaceAll(RegExp('[\u0622\u0623\u0625\u0671]'), 'ا');
  // Normalize ya / dotless ya
  s = s.replaceAll('\u0649', 'ي');
  // Remove tatweel
  s = s.replaceAll('\u0640', '');
  return s;
}

String _normalizeLatin(String input) {
  String s = input.toLowerCase();
  // Replace Albanian specific letters
  s = s.replaceAll('ç', 'c').replaceAll('ë', 'e');
  // Remove common accent marks (precomposed -> basic) quick map
  const mapping = {
    'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a','ā':'a','ă':'a','ą':'a',
    'é':'e','è':'e','ë':'e','ê':'e','ě':'e','ē':'e','ę':'e','ė':'e',
    'í':'i','ì':'i','ï':'i','î':'i','ī':'i','į':'i','ı':'i',
    'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o','ø':'o','ō':'o','ő':'o',
    'ú':'u','ù':'u','ü':'u','û':'u','ū':'u','ů':'u','ű':'u','ť':'t','š':'s','ž':'z','ñ':'n','ç':'c'
  };
  final sb = StringBuffer();
  for (final ch in s.split('')) {

// stemmer now provided by core/search/stemmer.dart
    sb.write(mapping[ch] ?? ch);
  }
  return sb.toString();
}

// Top-level function for compute()
Map<String, List<String>> buildInvertedIndex(List<Map<String, dynamic>> raw) => _createIndex(raw);
