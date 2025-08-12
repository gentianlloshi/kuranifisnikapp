import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/core/utils/result.dart';
import 'package:kurani_fisnik_app/core/error/failures.dart';

class GetSurahsUseCase {
  final QuranRepository _repository;
  GetSurahsUseCase(this._repository);
  Future<Result<List<Surah>>> call() async {
    try {
      final data = await _repository.getAllSurahs();
      return Success(data);
    } catch (e, st) {
      return FailureResult( mapError(e, st) );
    }
  }
}

class GetSurahUseCase {
  final QuranRepository _repository;

  GetSurahUseCase(this._repository);

  Future<Surah> call(int surahNumber) async {
    return await _repository.getSurah(surahNumber);
  }
}
