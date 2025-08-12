import '../../domain/entities/hadith.dart';

class HadithModel {
  final String id;
  final String type;
  final String author;
  final String text;
  final String source;

  const HadithModel({
    required this.id,
    required this.type,
    required this.author,
    required this.text,
    required this.source,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      id: json['id'] as String,
      type: json['tipi'] as String,
      author: json['autor'] as String,
      text: json['thenia'] as String,
      source: json['burimi'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipi': type,
      'autor': author,
      'thenia': text,
      'burimi': source,
    };
  }

  Hadith toEntity() {
    return Hadith(
      id: id,
      type: type,
      author: author,
      text: text,
      source: source,
    );
  }
}

