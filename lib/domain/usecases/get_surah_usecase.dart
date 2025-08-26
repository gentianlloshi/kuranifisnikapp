import '../entities/surah.dart';
import '../repositories/quran_repository.dart';

/// Lightweight: fetch a single Surah meta by id/number without loading the full corpus.
class GetSurahUseCase {
  final QuranRepository repository;

  GetSurahUseCase(this.repository);

  Future<Surah> call(int surahId) async {
    // Repository.getSurah returns a meta-only Surah in the lazy model.
    return repository.getSurah(surahId);
  }
}
