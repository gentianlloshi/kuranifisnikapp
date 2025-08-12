class Prayer {
  final String id;
  final String title;
  final String textAlbanian;
  final String source;

  const Prayer({
    required this.id,
    required this.title,
    required this.textAlbanian,
    required this.source,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Prayer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

