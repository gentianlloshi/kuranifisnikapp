import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/quran_provider.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surah_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/search_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/core/utils/result.dart';

class _FakeQuranRepo implements QuranRepository {
  final List<Surah> _surahs = [
    Surah(
      id: 1,
      number: 1,
      nameArabic: 'Al-Fatiha',
      nameTranslation: 'Hapja',
      nameTransliteration: 'Al-Fatiha',
      revelation: 'Meccan',
      versesCount: 7,
      verses: const [],
    ),
  ];

  @override
  Future<List<Surah>> getSurahs() async => _surahs;
  @override
  Future<List<Surah>> getAllSurahs() async => _surahs;
  @override
  Future<Surah> getSurah(int surahNumber) async => _surahs.firstWhere((s) => s.number == surahNumber);
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => getVersesBySurah(surahNumber);
  @override
  Future<Verse> getVerse(int surahNumber, int verseNumber) async => (await getVersesBySurah(surahNumber)).firstWhere((v) => v.verseNumber == verseNumber);
  @override
  Future<Map<String, dynamic>> getTranslation(String translationKey) async => {};
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};

  @override
  Future<List<Verse>> getVersesBySurah(int surahId) async => List.generate(7, (i) => Verse(
        surahId: surahId,
        verseNumber: i + 1,
        arabicText: 'Ajeti ${i + 1}',
        translation: 'Përkthimi ${i + 1}',
        transliteration: 'Trans ${i + 1}',
        verseKey: '$surahId:${i + 1}',
      ));

  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) async => [];
}

void main() {
  group('QuranProvider.openSurahAtVerse', () {
    late QuranProvider provider;

    setUp(() {
      final repo = _FakeQuranRepo();
      provider = QuranProvider(
        getSurahsUseCase: GetSurahsUseCase(repo),
        searchVersesUseCase: SearchVersesUseCase(repo),
        getSurahVersesUseCase: GetSurahVersesUseCase(repo),
      );
    });

    test('sets pending verse and consumes after load', () async {
  provider.openSurahAtVerse(1, 5);
      // After openSurahAtVerse the surah is loaded and pending scroll stored.
      final pending = provider.consumePendingScrollTarget();
      expect(pending, 5);
      // Consuming again should return null.
      expect(provider.consumePendingScrollTarget(), isNull);
    });
  });
}
