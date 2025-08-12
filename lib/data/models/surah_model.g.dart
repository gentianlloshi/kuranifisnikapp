// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surah_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SurahModel _$SurahModelFromJson(Map<String, dynamic> json) => SurahModel(
      number: (json['number'] as num).toInt(),
      nameArabic: json['name'] as String,
      transliteration: json['transliteration'] as String,
      translation: json['translation'] as String,
      versesCount: (json['verses'] as num).toInt(),
      revelation: json['revelation'] as String,
      verses: (json['ayahs'] as List<dynamic>?)
          ?.map((e) => VerseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SurahModelToJson(SurahModel instance) =>
    <String, dynamic>{
      'number': instance.number,
      'name': instance.nameArabic,
      'transliteration': instance.transliteration,
      'translation': instance.translation,
      'verses': instance.versesCount,
      'revelation': instance.revelation,
      'ayahs': instance.verses,
    };

VerseModel _$VerseModelFromJson(Map<String, dynamic> json) => VerseModel(
      number: (json['number'] as num).toInt(),
      textArabic: json['text'] as String,
      translation: json['translation'] as String?,
      transliteration: json['transliteration'] as String?,
    );

Map<String, dynamic> _$VerseModelToJson(VerseModel instance) =>
    <String, dynamic>{
      'number': instance.number,
      'text': instance.textArabic,
      'translation': instance.translation,
      'transliteration': instance.transliteration,
    };
