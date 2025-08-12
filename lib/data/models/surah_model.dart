import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/surah.dart';
import '../../domain/entities/verse.dart';

part 'surah_model.g.dart';

@JsonSerializable()
class SurahModel {
  final int number;
  @JsonKey(name: 'name')
  final String nameArabic;
  final String transliteration;
  final String translation;
  @JsonKey(name: 'verses')
  final int versesCount;
  final String revelation;
  @JsonKey(name: 'ayahs')
  final List<VerseModel>? verses;

  const SurahModel({
    required this.number,
    required this.nameArabic,
    required this.transliteration,
    required this.translation,
    required this.versesCount,
    required this.revelation,
    this.verses,
  });

  factory SurahModel.fromJson(Map<String, dynamic> json) =>
      _$SurahModelFromJson(json);

  Map<String, dynamic> toJson() => _$SurahModelToJson(this);

  Surah toEntity() {
    return Surah(
      id: number,  // Add the missing id parameter
      number: number,
      nameArabic: nameArabic,
      nameTransliteration: transliteration,
      nameTranslation: translation,
      versesCount: versesCount,
      revelation: revelation,
      verses: verses?.map((v) => v.toEntity(number)).toList() ?? [],
    );
  }

  // Add fromEntity constructor
  factory SurahModel.fromEntity(Surah entity) {
    return SurahModel(
      number: entity.number,
      nameArabic: entity.nameArabic,
      transliteration: entity.nameTransliteration,
      translation: entity.nameTranslation,
      versesCount: entity.versesCount,
      revelation: entity.revelation,
      verses: entity.verses.map((v) => VerseModel.fromEntity(v)).toList(),
    );
  }
}

@JsonSerializable()
class VerseModel {
  final int number;
  @JsonKey(name: 'text')
  final String textArabic;
  final String? translation;
  final String? transliteration;

  const VerseModel({
    required this.number,
    required this.textArabic,
    this.translation,
    this.transliteration,
  });

  factory VerseModel.fromJson(Map<String, dynamic> json) =>
      _$VerseModelFromJson(json);

  Map<String, dynamic> toJson() => _$VerseModelToJson(this);

  Verse toEntity(int surahNumber) {
    return Verse(
      surahId: surahNumber,
      verseNumber: number,
      arabicText: textArabic,
      translation: translation,
      transliteration: transliteration,
      verseKey: '$surahNumber:$number',
    );
  }

  // Add fromEntity constructor
  factory VerseModel.fromEntity(Verse entity) {
    return VerseModel(
      number: entity.verseNumber,
      textArabic: entity.arabicText,
      translation: entity.translation,
      transliteration: entity.transliteration,
    );
  }
}
