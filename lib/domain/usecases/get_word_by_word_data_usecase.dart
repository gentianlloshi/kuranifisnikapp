import 'package:kurani_fisnik_app/domain/entities/word_by_word.dart';
import 'package:kurani_fisnik_app/domain/repositories/word_by_word_repository.dart';

class GetWordByWordDataUseCase {
  final WordByWordRepository repository;

  GetWordByWordDataUseCase({required this.repository});

  Future<List<WordByWordVerse>> call(int surahNumber) {
    return repository.getWordByWordData(surahNumber);
  }
}


