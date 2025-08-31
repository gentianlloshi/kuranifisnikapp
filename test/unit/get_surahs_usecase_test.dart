import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/core/utils/result.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/entities/surah_meta.dart';

class FakeQuranRepository implements QuranRepository {
  final List<Surah> surahs;
  int getAllSurahsCallCount = 0;
  FakeQuranRepository(this.surahs);

  @override
  Future<List<Surah>> getAllSurahs() async {
    getAllSurahsCallCount++;
    return surahs;
  }

  // Unused methods for this test
  @override
  Future<Surah> getSurah(int surahNumber) => throw UnimplementedError();
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) => throw UnimplementedError();
  @override
  Future<List<Verse>> getVersesBySurah(int surahId) => throw UnimplementedError();
  @override
  Future<Verse> getVerse(int surahNumber, int verseNumber) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getTranslation(String translationKey) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getThematicIndex() => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getTransliterations() => throw UnimplementedError();
  @override
  Future<List<SurahMeta>> getSurahList() => throw UnimplementedError();
  @override
  Future<List<Verse>> getVersesForSurah(int surahId) => throw UnimplementedError();
  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) => throw UnimplementedError();
  // New enrichment API members – not used in this test
  @override
  Future<void> ensureSurahTranslation(int surahNumber, {String translationKey = 'sq_ahmeti'}) async {}
  @override
  Future<void> ensureSurahTransliteration(int surahNumber) async {}
  @override
  bool isSurahFullyEnriched(int surahNumber) => false;
  @override
  Map<String, double> translationCoverageByKey() => const {};
  @override
  Stream<double> get enrichmentCoverageStream => const Stream<double>.empty();
  @override
  Stream<Map<String, double>> get translationCoverageStream => const Stream<Map<String, double>>.empty();
  @override
  void setPreferredTranslationKey(String translationKey) {}
}

void main() {
  late GetSurahsUseCase getSurahsUseCase;
  late FakeQuranRepository fakeRepository;

  group('GetSurahsUseCase', () {
    final tSurahs = [
      Surah(number: 1, nameArabic: 'الفاتحة', nameTransliteration: 'Al-Fatiha', nameTranslation: 'Hapja', versesCount: 7, revelation: 'Mekke'),
      Surah(number: 2, nameArabic: 'البقرة', nameTransliteration: 'Al-Baqarah', nameTranslation: 'Lopë', versesCount: 286, revelation: 'Medinë'),
    ];

    test('should get list of surahs from the repository', () async {
      fakeRepository = FakeQuranRepository(tSurahs);
      getSurahsUseCase = GetSurahsUseCase(fakeRepository);
      // Act
  final result = await getSurahsUseCase.call();
  // Assert
  expect(result, isA<Success<List<Surah>>>());
  expect((result as Success<List<Surah>>).value, tSurahs);
      expect(fakeRepository.getAllSurahsCallCount, 1);
    });
  });
}

