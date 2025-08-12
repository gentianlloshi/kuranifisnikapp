import 'package:kurani_fisnik_app/domain/entities/word_by_word.dart';
import 'package:kurani_fisnik_app/domain/repositories/word_by_word_repository.dart';
import 'package:kurani_fisnik_app/data/datasources/local/word_by_word_local_data_source.dart';

class WordByWordRepositoryImpl implements WordByWordRepository {
  final WordByWordLocalDataSource localDataSource;

  WordByWordRepositoryImpl({required this.localDataSource});

  @override
  Future<List<WordByWordVerse>> getWordByWordData(int surahNumber) {
    return localDataSource.getWordByWordData(surahNumber);
  }

  @override
  Future<List<TimestampData>> getTimestampData(int surahNumber) {
    return localDataSource.getTimestampData(surahNumber);
  }
}


