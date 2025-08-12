import '../entities/verse.dart';
import '../repositories/quran_repository.dart';

class GetSurahVersesUseCase {
  final QuranRepository repository;

  GetSurahVersesUseCase(this.repository);

  Future<List<Verse>> call(int surahId) async {
    try {
      return await repository.getVersesBySurah(surahId);
    } catch (e) {
      throw Exception('Failed to get verses for surah $surahId: $e');
    }
  }
}
