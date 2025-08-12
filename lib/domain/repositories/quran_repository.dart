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
}
