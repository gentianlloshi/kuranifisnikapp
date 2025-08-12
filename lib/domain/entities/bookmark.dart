class Bookmark {
  final String verseKey;
  final DateTime createdAt;
  final String? note;

  const Bookmark({
    required this.verseKey,
    required this.createdAt,
    this.note,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      verseKey: json['verseKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verseKey': verseKey,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  Bookmark copyWith({
    String? verseKey,
    DateTime? createdAt,
    String? note,
  }) {
    return Bookmark(
      verseKey: verseKey ?? this.verseKey,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark &&
          runtimeType == other.runtimeType &&
          verseKey == other.verseKey;

  @override
  int get hashCode => verseKey.hashCode;
}
