List<String> tokenizeLatin(String text) {
  final lower = text.toLowerCase();
  final parts = lower.split(RegExp(r'[^a-zçëšžáéíóúâêîôûäöü0-9]+'));
  return parts.where((p) => p.isNotEmpty).toList();
}

String normalizeLatin(String input) {
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

List<String> expandQueryTokens(String query, String Function(String) stem) {
  final raw = tokenizeLatin(query);
  final result = <String>[];
  for (final r in raw) {
    if (r.length <= 2) { result.add(r); continue; }
    result.add(r);
    final norm = r.replaceAll('ç','c').replaceAll('ë','e');
    if (norm != r) result.add(norm);
    final st = stem(normalizeLatin(r));
    if (st.length >= 3) result.add(st);
  }
  return result.toSet().toList();
}
