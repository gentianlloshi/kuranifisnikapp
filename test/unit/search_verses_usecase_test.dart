import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/domain/usecases/search_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';

class FakeQuranRepository implements QuranRepository {
  final List<Verse> verses;
  int searchCalls = 0;
  FakeQuranRepository(this.verses);

  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) async {
    searchCalls++;
    final q = query.toLowerCase();
    return verses.where((v) => v.textArabic.toLowerCase().contains(q) || (v.textTranslation?.toLowerCase().contains(q) ?? false)).toList();
  }

  // Unused methods
  @override
  Future<List<Surah>> getAllSurahs() => throw UnimplementedError();
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
  // New enrichment API members – not used here
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
  // Duplicate signature for searchVerses with Surah return removed
}

void main() {
  late SearchVersesUseCase searchVersesUseCase;
  late FakeQuranRepository fakeRepository;

  setUp(() {
    // Will initialize per test
  });

  group('SearchVersesUseCase', () {
    final tVerses = [
      Verse(surahId: 1, verseNumber: 1, arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', verseKey: '1:1', translation: 'Në emër të Allahut, Mëshiruesit, Mëshirëbërësit.'),
      Verse(surahId: 1, verseNumber: 2, arabicText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ', verseKey: '1:2', translation: 'Falënderimi i takon Allahut, Zotit të botëve.'),
    ];

    test('should search verses from the repository', () async {
      fakeRepository = FakeQuranRepository(tVerses);
      searchVersesUseCase = SearchVersesUseCase(fakeRepository);
      final result = await searchVersesUseCase.call('Allah');
      expect(result, equals(tVerses));
      expect(fakeRepository.searchCalls, 1);
    });

    test('should return empty list when query is empty', () async {
      fakeRepository = FakeQuranRepository(tVerses);
      searchVersesUseCase = SearchVersesUseCase(fakeRepository);
      final result = await searchVersesUseCase.call('');
      expect(result, equals([]));
      expect(fakeRepository.searchCalls, 0);
    });

    test('should search verses with translation key (ignored in fake)', () async {
      fakeRepository = FakeQuranRepository(tVerses);
      searchVersesUseCase = SearchVersesUseCase(fakeRepository);
      final result = await searchVersesUseCase.call('Allah', translationKey: 'sq_ahmeti');
      expect(result, equals(tVerses));
      expect(fakeRepository.searchCalls, 1);
    });
  });
}

