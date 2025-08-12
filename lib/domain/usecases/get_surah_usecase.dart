import '../entities/surah.dart';
import '../repositories/quran_repository.dart';

class GetSurahUseCase {
  final QuranRepository repository;

  GetSurahUseCase(this.repository);

  Future<Surah?> call(int surahId) async {
    try {
      final surahs = await repository.getAllSurahs();
      return surahs.firstWhere(
        (surah) => surah.id == surahId,
        orElse: () => throw Exception('Surah not found'),
      );
    } catch (e) {
      throw Exception('Failed to get surah: $e');
    }
  }
}
