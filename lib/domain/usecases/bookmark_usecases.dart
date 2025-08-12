import '../entities/bookmark.dart';
import '../repositories/bookmark_repository.dart';

class BookmarkUseCases {
  final BookmarkRepository repository;

  BookmarkUseCases(this.repository);

  Future<List<Bookmark>> getBookmarks() async {
    try {
      return await repository.getBookmarks();
    } catch (e) {
      throw Exception('Failed to get bookmarks: $e');
    }
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    try {
      await repository.addBookmark(bookmark);
    } catch (e) {
      throw Exception('Failed to add bookmark: $e');
    }
  }

  Future<void> removeBookmark(String verseKey) async {
    try {
      await repository.removeBookmark(verseKey);
    } catch (e) {
      throw Exception('Failed to remove bookmark: $e');
    }
  }

  Future<bool> isBookmarked(String verseKey) async {
    try {
      return await repository.isBookmarked(verseKey);
    } catch (e) {
      throw Exception('Failed to check bookmark status: $e');
    }
  }
}

class GetBookmarksUseCase {
  final BookmarkRepository repository;

  GetBookmarksUseCase(this.repository);

  Future<List<Bookmark>> call() async {
    try {
      return await repository.getBookmarks();
    } catch (e) {
      throw Exception('Failed to get bookmarks: $e');
    }
  }
}

class AddBookmarkUseCase {
  final BookmarkRepository repository;

  AddBookmarkUseCase(this.repository);

  Future<void> call(Bookmark bookmark) async {
    try {
      await repository.addBookmark(bookmark);
    } catch (e) {
      throw Exception('Failed to add bookmark: $e');
    }
  }
}

class RemoveBookmarkUseCase {
  final BookmarkRepository repository;

  RemoveBookmarkUseCase(this.repository);

  Future<void> call(String verseKey) async {
    try {
      await repository.removeBookmark(verseKey);
    } catch (e) {
      throw Exception('Failed to remove bookmark: $e');
    }
  }
}
