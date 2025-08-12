// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_by_word.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordByWordVerseAdapter extends TypeAdapter<WordByWordVerse> {
  @override
  final int typeId = 2;

  @override
  WordByWordVerse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordByWordVerse(
      verseNumber: fields[0] as int,
      words: (fields[1] as List).cast<WordData>(),
    );
  }

  @override
  void write(BinaryWriter writer, WordByWordVerse obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.verseNumber)
      ..writeByte(1)
      ..write(obj.words);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordByWordVerseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WordDataAdapter extends TypeAdapter<WordData> {
  @override
  final int typeId = 3;

  @override
  WordData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordData(
      arabic: fields[0] as String,
      translation: fields[1] as String,
      transliteration: fields[2] as String,
      charStart: fields[3] as int,
      charEnd: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WordData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.arabic)
      ..writeByte(1)
      ..write(obj.translation)
      ..writeByte(2)
      ..write(obj.transliteration)
      ..writeByte(3)
      ..write(obj.charStart)
      ..writeByte(4)
      ..write(obj.charEnd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimestampDataAdapter extends TypeAdapter<TimestampData> {
  @override
  final int typeId = 4;

  @override
  TimestampData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimestampData(
      verseNumber: fields[0] as int,
      wordTimestamps: (fields[1] as List).cast<WordTimestamp>(),
    );
  }

  @override
  void write(BinaryWriter writer, TimestampData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.verseNumber)
      ..writeByte(1)
      ..write(obj.wordTimestamps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimestampDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WordTimestampAdapter extends TypeAdapter<WordTimestamp> {
  @override
  final int typeId = 5;

  @override
  WordTimestamp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordTimestamp(
      start: fields[0] as int,
      end: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WordTimestamp obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.start)
      ..writeByte(1)
      ..write(obj.end);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordTimestampAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
