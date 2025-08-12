import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';

class GetSurahsUseCase {
  final QuranRepository _repository;

  GetSurahsUseCase(this._repository);

  Future<List<Surah>> call() async {
    return await _repository.getAllSurahs();
  }
}

class GetSurahUseCase {
  final QuranRepository _repository;

  GetSurahUseCase(this._repository);

  Future<Surah> call(int surahNumber) async {
    return await _repository.getSurah(surahNumber);
  }
}
