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
    final verseNum = (json['verse'] as num?)?.toInt() ?? int.tryParse('${json['verse']}') ?? 0;
    final rawWords = (json['words'] as List?) ?? const [];
    final words = rawWords.map((e) {
      if (e is Map) {
        return WordData.fromJson(Map<String, dynamic>.from(e as Map));
      }
      return WordData.fromJson(e as Map<String, dynamic>);
    }).toList();
    return WordByWordVerse(
      verseNumber: verseNum,
      words: words,
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
    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }
    return WordData(
      arabic: (json['arabic'] ?? json['text'] ?? '').toString(),
      translation: (json['translation'] ?? '').toString(),
      transliteration: (json['transliteration'] ?? '').toString(),
      charStart: _toInt(json['char_start'] ?? json['start'] ?? 0),
      charEnd: _toInt(json['char_end'] ?? json['end'] ?? 0),
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
    final verseNum = (json['verse'] as num?)?.toInt() ?? int.tryParse('${json['verse']}') ?? 0;
    final raw = (json['words'] as List?) ?? const [];
    final ts = raw.map((e) {
      if (e is Map) {
        return WordTimestamp.fromJson(Map<String, dynamic>.from(e as Map));
      }
      return WordTimestamp.fromJson(e as Map<String, dynamic>);
    }).toList();
    return TimestampData(
      verseNumber: verseNum,
      wordTimestamps: ts,
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
    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }
    return WordTimestamp(
      start: _toInt(json['start']),
      end: _toInt(json['end']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
    };
  }
}


