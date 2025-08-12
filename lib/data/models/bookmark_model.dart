import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/bookmark.dart';

part 'bookmark_model.g.dart';

@JsonSerializable()
class BookmarkModel {
  final String verseKey;
  final DateTime createdAt;
  final String? note;

  const BookmarkModel({
    required this.verseKey,
    required this.createdAt,
    this.note,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) =>
      _$BookmarkModelFromJson(json);

  Map<String, dynamic> toJson() => _$BookmarkModelToJson(this);

  Bookmark toEntity() {
    return Bookmark(
      verseKey: verseKey,
      createdAt: createdAt,
      note: note,
    );
  }

  factory BookmarkModel.fromEntity(Bookmark bookmark) {
    return BookmarkModel(
      verseKey: bookmark.verseKey,
      createdAt: bookmark.createdAt,
      note: bookmark.note,
    );
  }
}

