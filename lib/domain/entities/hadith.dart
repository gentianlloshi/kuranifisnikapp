class Hadith {
  final String id;
  final String type;
  final String author;
  final String text;
  final String source;

  const Hadith({
    required this.id,
    required this.type,
    required this.author,
    required this.text,
    required this.source,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hadith &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

