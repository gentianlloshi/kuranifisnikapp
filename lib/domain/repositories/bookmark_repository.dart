import '../entities/bookmark.dart';

abstract class BookmarkRepository {
  Future<List<Bookmark>> getBookmarks();
  Future<void> addBookmark(Bookmark bookmark);
  Future<void> removeBookmark(String verseKey);
  Future<bool> isBookmarked(String verseKey);
  Future<void> clearBookmarks();
}
