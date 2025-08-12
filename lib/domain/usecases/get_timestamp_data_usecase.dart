import 'package:kurani_fisnik_app/domain/entities/word_by_word.dart';
import 'package:kurani_fisnik_app/domain/repositories/word_by_word_repository.dart';

class GetTimestampDataUseCase {
  final WordByWordRepository repository;

  GetTimestampDataUseCase({required this.repository});

  Future<List<TimestampData>> call(int surahNumber) {
    return repository.getTimestampData(surahNumber);
  }
}


