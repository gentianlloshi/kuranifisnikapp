class MemorizationSession {
  final int surah; // active group surah id
  final Set<String> selectedVerseKeys; // keys surah:verse
  final int repeatTarget; // desired repeat cycles

  const MemorizationSession({
    required this.surah,
    this.selectedVerseKeys = const {},
    this.repeatTarget = 1,
  });

  MemorizationSession copyWith({
    int? surah,
    Set<String>? selectedVerseKeys,
    int? repeatTarget,
  }) => MemorizationSession(
        surah: surah ?? this.surah,
        selectedVerseKeys: selectedVerseKeys ?? this.selectedVerseKeys,
        repeatTarget: repeatTarget ?? this.repeatTarget,
      );
}
