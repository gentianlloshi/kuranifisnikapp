import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/note.dart';

part 'note_model.g.dart';

@JsonSerializable()
class NoteModel {
  final String id;
  final String verseKey;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  const NoteModel({
    required this.id,
    required this.verseKey,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  Map<String, dynamic> toJson() => _$NoteModelToJson(this);

  Note toEntity() {
    return Note(
      id: id,
      verseKey: verseKey,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: tags,
    );
  }

  factory NoteModel.fromEntity(Note note) {
    return NoteModel(
      id: note.id,
      verseKey: note.verseKey,
      content: note.content,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      tags: note.tags,
    );
  }
}

