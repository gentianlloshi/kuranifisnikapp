import '../../domain/entities/prayer.dart';

class PrayerModel {
  final String id;
  final String title;
  final String textAlbanian;
  final String source;

  const PrayerModel({
    required this.id,
    required this.title,
    required this.textAlbanian,
    required this.source,
  });

  factory PrayerModel.fromJson(Map<String, dynamic> json) {
    return PrayerModel(
      id: json['id'] as String,
      title: json['titulli'] as String,
      textAlbanian: json['shqip'] as String,
      source: json['burimi'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulli': title,
      'shqip': textAlbanian,
      'burimi': source,
    };
  }

  Prayer toEntity() {
    return Prayer(
      id: id,
      title: title,
      textAlbanian: textAlbanian,
      source: source,
    );
  }
}

