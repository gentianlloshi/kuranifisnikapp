import '../../domain/entities/bookmark.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../datasources/local/storage_data_source.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  final StorageDataSource _storageDataSource;

  BookmarkRepositoryImpl(this._storageDataSource);

  @override
  Future<List<Bookmark>> getBookmarks() async {
    return await _storageDataSource.getBookmarks();
  }

  @override
  Future<void> addBookmark(Bookmark bookmark) async {
    final bookmarks = await getBookmarks();
    bookmarks.add(bookmark);
    await _storageDataSource.saveBookmarks(bookmarks);
  }

  @override
  Future<void> removeBookmark(String verseKey) async {
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((bookmark) => bookmark.verseKey == verseKey);
    await _storageDataSource.saveBookmarks(bookmarks);
  }

  @override
  Future<bool> isBookmarked(String verseKey) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((bookmark) => bookmark.verseKey == verseKey);
  }

  @override
  Future<void> clearBookmarks() async {
    await _storageDataSource.saveBookmarks([]);
  }
}
