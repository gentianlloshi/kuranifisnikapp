import '../../domain/entities/verse.dart';
import '../../domain/entities/note.dart';

// Config for scoring weights (tunable)
class UnifiedRankingConfig {
  final int noteBaseBoost;
  final int scoreTranslation;
  final int scoreTransliteration;
  final int scoreArabic;
  final int scoreNoteContent;
  final int scoreTagMatch;
  final int scoreRecencyFresh; // < 7 days
  final int scoreRecencyRecent; // < 30 days

  const UnifiedRankingConfig({
    this.noteBaseBoost = 40,
    this.scoreTranslation = 30,
    this.scoreTransliteration = 15,
    this.scoreArabic = 12,
    this.scoreNoteContent = 20,
    this.scoreTagMatch = 6,
    this.scoreRecencyFresh = 6,
    this.scoreRecencyRecent = 3,
  });

  static const UnifiedRankingConfig defaults = UnifiedRankingConfig();
}

class UnifiedItem {
  final Verse? verse;
  final Note? note;
  final int score;
  const UnifiedItem({this.verse, this.note, required this.score});
}

List<UnifiedItem> computeUnifiedTop({
  required List<Verse> verses,
  required List<Note> notes,
  required String query,
  int limit = 5,
  UnifiedRankingConfig config = UnifiedRankingConfig.defaults,
}) {
  String _fold(String s) => s
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ë', 'e');

  final q = query.trim();
  if (q.isEmpty) return const [];
  Set<String> _tokens(String s) => _fold(s)
      .split(RegExp(r"[^\p{L}\p{N}]+", unicode: true))
      .where((e) => e.isNotEmpty)
      .toSet();
  final qTokens = _tokens(q);
  int _scoreVerse(Verse v) {
    int s = 0;
    final t = _fold(v.textTranslation ?? '');
    final tr = _fold(v.textTransliteration ?? '');
    final ar = _fold(v.textArabic);
    for (final tok in qTokens) {
      if (t.contains(tok)) s += config.scoreTranslation;
      if (tr.contains(tok)) s += config.scoreTransliteration;
      if (ar.contains(tok)) s += config.scoreArabic;
    }
    return s;
  }
  int _scoreNote(Note n) {
    int s = config.noteBaseBoost; // base boost for personal notes
    final content = _fold(n.content);
    for (final tok in qTokens) {
      if (content.contains(tok)) s += config.scoreNoteContent;
      if (n.tags.any((t) => _fold(t).contains(tok))) s += config.scoreTagMatch;
    }
    final ageDays = DateTime.now().difference(n.updatedAt).inDays;
    if (ageDays < 7) {
      s += config.scoreRecencyFresh;
    } else if (ageDays < 30) {
      s += config.scoreRecencyRecent;
    }
    return s;
  }
  final items = <UnifiedItem>[];
  for (final v in verses) {
    final s = _scoreVerse(v);
    if (s > 0) items.add(UnifiedItem(verse: v, score: s));
  }
  for (final n in notes) {
    final s = _scoreNote(n);
    if (s > 0) items.add(UnifiedItem(note: n, score: s));
  }
  items.sort((a, b) => b.score.compareTo(a.score));
  if (items.length > limit) return items.sublist(0, limit);
  return items;
}
