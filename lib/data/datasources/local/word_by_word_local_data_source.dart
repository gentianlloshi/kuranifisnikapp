import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../../domain/entities/word_by_word.dart';

abstract class WordByWordLocalDataSource {
  Future<List<WordByWordVerse>> getWordByWordData(int surahNumber);
  Future<List<TimestampData>> getTimestampData(int surahNumber);
}

class WordByWordLocalDataSourceImpl implements WordByWordLocalDataSource {
  final Box<dynamic> _wordByWordBox;
  final Box<dynamic> _timestampBox;

  WordByWordLocalDataSourceImpl({
    required Box<dynamic> wordByWordBox,
    required Box<dynamic> timestampBox,
  })  : _wordByWordBox = wordByWordBox,
        _timestampBox = timestampBox;

  @override
  Future<List<WordByWordVerse>> getWordByWordData(int surahNumber) async {
    final String boxKey = 'word_by_word_surah_$surahNumber';
    if (_wordByWordBox.containsKey(boxKey)) {
      final List<dynamic> cachedData = _wordByWordBox.get(boxKey);
      return cachedData.map((json) => WordByWordVerse.fromJson(json)).toList();
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/word/$surahNumber.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      final List<WordByWordVerse> verses = [];
      // Assuming the JSON structure is a map where keys are verse numbers
      // and values are lists of words for that verse.
      jsonData.forEach((key, value) {
        verses.add(WordByWordVerse.fromJson({
          'verse': int.parse(key),
          'words': value,
        }));
      });

      await _wordByWordBox.put(boxKey, verses.map((v) => v.toJson()).toList());
      return verses;
    } catch (e) {
      throw Exception('Failed to load word by word data for surah $surahNumber: $e');
    }
  }

  @override
  Future<List<TimestampData>> getTimestampData(int surahNumber) async {
    final String boxKey = 'timestamp_surah_$surahNumber';
    if (_timestampBox.containsKey(boxKey)) {
      final List<dynamic> cachedData = _timestampBox.get(boxKey);
      return cachedData.map((json) => TimestampData.fromJson(json)).toList();
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/time/time$surahNumber.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final List<TimestampData> timestamps = [];
      // Assuming the JSON structure is a map where keys are verse numbers
      // and values are lists of word timestamps for that verse.
      jsonData.forEach((key, value) {
        timestamps.add(TimestampData.fromJson({
          'verse': int.parse(key),
          'words': value,
        }));
      });

      await _timestampBox.put(boxKey, timestamps.map((t) => t.toJson()).toList());
      return timestamps;
    } catch (e) {
      throw Exception('Failed to load timestamp data for surah $surahNumber: $e');
    }
  }
}


