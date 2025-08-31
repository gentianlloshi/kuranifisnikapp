import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/search_index_manager.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surah_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/domain/entities/surah_meta.dart';

class _FakeRepo implements QuranRepository {
  @override
  Future<List<Surah>> getAllSurahs() async => [Surah(id:1, number:1, nameArabic:'', nameTranslation:'', nameTransliteration:'', revelation:'', versesCount:7, verses:const [])];
  @override
  Future<Surah> getSurah(int surahNumber) async => (await getAllSurahs()).first;
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => [
    Verse(surahId: surahNumber, verseNumber: 1, arabicText: 'الرَّحْمَٰنِ الرَّحِيمِ', translation: 'Mëshiruesi, Mëshirëbërësi', transliteration: 'ar-rahman ar-rahim', verseKey: '$surahNumber:1'),
  ];
  @override
  Future<Verse> getVerse(int surahNumber, int verseNumber) async => (await getSurahVerses(surahNumber)).firstWhere((v)=>v.verseNumber==verseNumber);
  @override
  Future<List<Verse>> getVersesBySurah(int surahId) async => getSurahVerses(surahId);
  @override
  Future<Map<String, dynamic>> getTranslation(String translationKey) async => {};
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};
  @override
  Future<List<SurahMeta>> getSurahList() async => (await getAllSurahs()).map(SurahMeta.fromSurah).toList();
  @override
  Future<List<Verse>> getVersesForSurah(int surahId) async => getSurahVerses(surahId);
  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) async => [];
  @override
  Future<void> ensureSurahTranslation(int surahNumber, {String translationKey = 'sq_ahmeti'}) async {}
  @override
  Future<void> ensureSurahTransliteration(int surahNumber) async {}
  @override
  bool isSurahFullyEnriched(int surahNumber) => true;
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
  test('search finds results for meshire variants via normalized+stem gating', () async {
    final repo = _FakeRepo();
    final mgr = SearchIndexManager(
      getSurahsUseCase: GetSurahsUseCase(repo),
      getSurahVersesUseCase: GetSurahVersesUseCase(repo),
    );
    // Inject minimal index and verse cache
    mgr.debugSetIndex({
      // tokens likely to exist after index build (normalized):
      'meshire': ['1:1'], 'meshireberes': ['1:1'], 'ar': ['1:1'], 'rahman': ['1:1'], 'rahim': ['1:1']
    }, {
      '1:1': Verse(
        surahId: 1,
        verseNumber: 1,
        arabicText: 'الرَّحْمَٰنِ الرَّحِيمِ',
        translation: 'Mëshiruesi, Mëshirëbërësi',
        transliteration: 'ar-rahman ar-rahim',
        verseKey: '1:1',
      )
    });

    final res1 = mgr.search('meshire');
    final res2 = mgr.search('mëshirë');
    final res3 = mgr.search('meshireberes');

    expect(res1.map((v)=>v.verseKey), contains('1:1'));
    expect(res2.map((v)=>v.verseKey), contains('1:1'));
    expect(res3.map((v)=>v.verseKey), contains('1:1'));
  });
}
