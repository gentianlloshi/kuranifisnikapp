/// Light Albanian-oriented stemmer: trims a small set of frequent noun/adjective suffixes.
/// Intentionally conservative to avoid over-stemming. Ensures minimum stem length of 3.
String lightStem(String token) {
  var s = token;
  if (s.length <= 3) return s;
  // Order matters: try longer suffixes first.
  const suffixes = <String>[
    'ave', 'eve', 'ive', 'ove',
    'ëve', 'ët', 'ën',
    'uar', 'ues', 'uesi',
    'shme', 'shëm', 'shm',
    'isht',
    'it', 'in', 've', 'ra', 'ri', 're', 't', 'i', 'e', 'a', 'u',
  ];
  for (final suf in suffixes) {
    if (s.endsWith(suf) && s.length - suf.length >= 3) {
      s = s.substring(0, s.length - suf.length);
      break;
    }
  }
  return s;
}
