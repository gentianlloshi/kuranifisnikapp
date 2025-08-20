import 'surah.dart';

class SurahMeta {
  final int number;
  final String nameArabic;
  final String nameTransliteration;
  final String nameTranslation;
  final int versesCount;
  final String revelation;
  const SurahMeta({
    required this.number,
    required this.nameArabic,
    required this.nameTransliteration,
    required this.nameTranslation,
    required this.versesCount,
    required this.revelation,
  });

  factory SurahMeta.fromSurah(Surah s) => SurahMeta(
        number: s.number,
        nameArabic: s.nameArabic,
        nameTransliteration: s.nameTransliteration,
        nameTranslation: s.nameTranslation,
        versesCount: s.versesCount,
        revelation: s.revelation,
      );
}
