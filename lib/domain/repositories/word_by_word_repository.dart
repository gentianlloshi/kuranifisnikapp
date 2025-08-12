import 'package:kurani_fisnik_app/domain/entities/word_by_word.dart';

abstract class WordByWordRepository {
  Future<List<WordByWordVerse>> getWordByWordData(int surahNumber);
  Future<List<TimestampData>> getTimestampData(int surahNumber);
}


