import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/search_index_manager.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surah_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';

class _FakeRepo implements QuranRepository {
  @override
  Future<List<Surah>> getSurahs() async => [Surah(id:1, number:1, nameArabic:'', nameTranslation:'', nameTransliteration:'', revelation:'', versesCount:7, verses:const [])];
  @override
  Future<List<Surah>> getAllSurahs() async => getSurahs();
  @override
  Future<Surah> getSurah(int surahNumber) async => (await getSurahs()).first;
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => List.generate(3, (i)=> Verse(surahId: surahNumber, verseNumber: i+1, arabicText: 'A', translation: 'T$i', transliteration: 'TR$i', verseKey: '$surahNumber:${i+1}'));
  @override
  Future<Verse> getVerse(int surahNumber, int verseNumber) async => (await getSurahVerses(surahNumber)).firstWhere((v)=> v.verseNumber==verseNumber);
  @override
  Future<Map<String, dynamic>> getTranslation(String translationKey) async => {};
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};
  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) async => [];
}

void main() {
  test('progress stream emits events and reaches completion', () async {
    final repo = _FakeRepo();
    final mgr = SearchIndexManager(
      getSurahsUseCase: GetSurahsUseCase(repo),
      getSurahVersesUseCase: GetSurahVersesUseCase(repo),
    );
    final events = <SearchIndexProgress>[];
    final sub = mgr.progressStream.listen(events.add);
    mgr.ensureIncrementalBuild();
    // Wait a short duration to collect some events
    await Future.delayed(const Duration(milliseconds: 200));
    // We expect at least one event
    expect(events.isNotEmpty, isTrue);
    // Force full build (ensureBuilt) then wait for completion
    await mgr.ensureBuilt();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(events.last.complete, isTrue);
    await sub.cancel();
    mgr.dispose();
  });
}
