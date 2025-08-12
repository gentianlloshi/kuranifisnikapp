import 'package:hive/hive.dart';

part 'word_by_word.g.dart';

@HiveType(typeId: 2)
class WordByWordVerse {
  @HiveField(0)
  final int verseNumber;
  @HiveField(1)
  final List<WordData> words;

  WordByWordVerse({
    required this.verseNumber,
    required this.words,
  });

  factory WordByWordVerse.fromJson(Map<String, dynamic> json) {
    return WordByWordVerse(
      verseNumber: json['verse'] as int,
      words: (json['words'] as List<dynamic>)
          .map((e) => WordData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verse': verseNumber,
      'words': words.map((e) => e.toJson()).toList(),
    };
  }
}

@HiveType(typeId: 3)
class WordData {
  @HiveField(0)
  final String arabic;
  @HiveField(1)
  final String translation;
  @HiveField(2)
  final String transliteration;
  @HiveField(3)
  final int charStart;
  @HiveField(4)
  final int charEnd;

  WordData({
    required this.arabic,
    required this.translation,
    required this.transliteration,
    required this.charStart,
    required this.charEnd,
  });

  factory WordData.fromJson(Map<String, dynamic> json) {
    return WordData(
      arabic: json['arabic'] as String,
      translation: json['translation'] as String,
      transliteration: json['transliteration'] as String,
      charStart: json['char_start'] as int,
      charEnd: json['char_end'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'arabic': arabic,
      'translation': translation,
      'transliteration': transliteration,
      'char_start': charStart,
      'char_end': charEnd,
    };
  }
}

@HiveType(typeId: 4)
class TimestampData {
  @HiveField(0)
  final int verseNumber;
  @HiveField(1)
  final List<WordTimestamp> wordTimestamps;

  TimestampData({
    required this.verseNumber,
    required this.wordTimestamps,
  });

  factory TimestampData.fromJson(Map<String, dynamic> json) {
    return TimestampData(
      verseNumber: json['verse'] as int,
      wordTimestamps: (json['words'] as List<dynamic>)
          .map((e) => WordTimestamp.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verse': verseNumber,
      'words': wordTimestamps.map((e) => e.toJson()).toList(),
    };
  }
}

@HiveType(typeId: 5)
class WordTimestamp {
  @HiveField(0)
  final int start;
  @HiveField(1)
  final int end;

  WordTimestamp({
    required this.start,
    required this.end,
  });

  factory WordTimestamp.fromJson(Map<String, dynamic> json) {
    return WordTimestamp(
      start: json['start'] as int,
      end: json['end'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
    };
  }
}


