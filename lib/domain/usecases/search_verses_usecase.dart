import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';

class SearchVersesUseCase {
  final QuranRepository _repository;

  SearchVersesUseCase(this._repository);

  Future<List<Verse>> call(String query, {String? translationKey}) async {
    if (query.trim().isEmpty) {
      return [];
    }
    
    return await _repository.searchVerses(query, translationKey: translationKey);
  }
}
