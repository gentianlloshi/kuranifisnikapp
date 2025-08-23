/// Light Albanian-oriented stemmer: trims a small set of frequent noun/adjective suffixes.
/// Intentionally conservative to avoid over-stemming. Ensures minimum stem length of 3.
String lightStem(String token) {
  var s = token;
  if (s.length <= 3) return s;
  // Order matters: try longer suffixes first.
  const suffixes = <String>[
    // 4+ length
    'shme',
    // 3 length
    'shëm', 'shem', 'ave', 'eve', 'ive', 'ove', 'uar', 'ues',
    // 2 length
    'ëve', 'ët', 'ën', 'it', 'in', 've', 'ra', 'ri', 're',
    // 1 length (very conservative)
    't', 'i', 'e', 'a', 'u',
  ];
  for (final suf in suffixes) {
    if (s.endsWith(suf) && s.length - suf.length >= 3) {
      // Preserve 'sh' when cutting '-shëm'/'-shme'
  if (suf == 'shëm' || suf == 'shem') {
        s = s.substring(0, s.length - suf.length) + 'sh';
      } else if (suf == 'shme') {
        s = s.substring(0, s.length - suf.length) + 'sh';
      } else {
        s = s.substring(0, s.length - suf.length);
      }
      break;
    }
  }
  // Final cleanup: drop trailing diacritic 'ë' if present and stem would remain >=3
  if (s.endsWith('ë') && s.length > 3) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
