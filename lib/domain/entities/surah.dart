import 'package:hive/hive.dart';
import 'verse.dart';

@HiveType(typeId: 0)
class Surah {
  @HiveField(0)
  final int? id;
  @HiveField(1)
  final int number;
  @HiveField(2)
  final String nameArabic;
  @HiveField(3)
  final String nameTransliteration;
  @HiveField(4)
  final String nameTranslation;
  @HiveField(5)
  final int versesCount;
  @HiveField(6)
  final String revelation;
  @HiveField(7)
  final List<Verse> verses;

  const Surah({
    this.id,
    required this.number,
    required this.nameArabic,
    required this.nameTransliteration,
    required this.nameTranslation,
    required this.versesCount,
    required this.revelation,
    this.verses = const [],
  });

  Surah copyWith({
    int? id,
    int? number,
    String? nameArabic,
    String? nameTransliteration,
    String? nameTranslation,
    int? versesCount,
    String? revelation,
    List<Verse>? verses,
  }) {
    return Surah(
      id: id ?? this.id,
      number: number ?? this.number,
      nameArabic: nameArabic ?? this.nameArabic,
      nameTransliteration: nameTransliteration ?? this.nameTransliteration,
      nameTranslation: nameTranslation ?? this.nameTranslation,
      versesCount: versesCount ?? this.versesCount,
      revelation: revelation ?? this.revelation,
      verses: verses ?? this.verses,
    );
  }

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] ?? json['number'] ?? 0,
      number: json['number'] as int,
  nameArabic: json['nameArabic'] as String,
  nameTransliteration: json['nameTransliteration'] as String, // meaning or transliteration
  nameTranslation: json['nameTranslation'] as String, // Albanian name
      versesCount: json['versesCount'] as int,
      revelation: json['revelation'] as String,
      verses: (json['verses'] as List<dynamic>?)
          ?.map((e) => Verse.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'nameArabic': nameArabic,
      'nameTransliteration': nameTransliteration,
      'nameTranslation': nameTranslation,
      'versesCount': versesCount,
      'revelation': revelation,
      'verses': verses.map((v) => v.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Surah && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Surah(id: $id, number: $number, nameArabic: $nameArabic)';
  }
}
