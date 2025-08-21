class MemorizationVerse {
  final int surah; // numeric id
  final int verse; // numeric verse within surah
  MemorizationStatus status;

  MemorizationVerse({
    required this.surah,
    required this.verse,
    required this.status,
  });

  String get key => '$surah:$verse';
}
enum MemorizationStatus { newVerse, inProgress, mastered }
