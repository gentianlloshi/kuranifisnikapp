import 'package:kurani_fisnik_app/data/repositories/quran_repository_impl.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';

/// Lightweight use case: fetch Arabic + meta only (no translation / transliteration merge)
class GetSurahsArabicOnlyUseCase {
  final QuranRepositoryImpl repository;
  GetSurahsArabicOnlyUseCase(this.repository);
  Future<List<Surah>> call() async {
    return repository.getArabicOnly();
  }
}
