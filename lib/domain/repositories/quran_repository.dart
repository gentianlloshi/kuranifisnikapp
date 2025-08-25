import '../entities/surah.dart';
import '../entities/verse.dart';

abstract class QuranRepository {
  Future<List<Surah>> getAllSurahs();
  Future<Surah> getSurah(int surahNumber);
  Future<List<Verse>> getSurahVerses(int surahNumber);
  Future<List<Verse>> getVersesBySurah(int surahId); // Shtimi i metodës që mungon
  Future<Verse> getVerse(int surahNumber, int verseNumber);
  Future<Map<String, dynamic>> getTranslation(String translationKey);
  Future<Map<String, dynamic>> getThematicIndex();
  Future<Map<String, dynamic>> getTransliterations();
  Future<List<Verse>> searchVerses(String query, {String? translationKey});
  // On-demand enrichment
  Future<void> ensureSurahTranslation(int surahNumber, {String translationKey = 'sq_ahmeti'});
  Future<void> ensureSurahTransliteration(int surahNumber);
  bool isSurahFullyEnriched(int surahNumber);
  Map<String,double> translationCoverageByKey();
  // Reactive streams (PERF-2) for UI to subscribe to coverage changes
  Stream<double> get enrichmentCoverageStream; // emits 0..1 when enrichment coverage changes
  // Optional: translation coverage per key aggregate (emit map for simplicity)
  Stream<Map<String,double>> get translationCoverageStream; // emits updated coverage map per translation key
}
