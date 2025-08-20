import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/bookmark_provider.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/usecases/bookmark_usecases.dart';
import 'package:kurani_fisnik_app/domain/repositories/bookmark_repository.dart';

class _FakeBookmarkRepo implements BookmarkRepository {
  final List<Bookmark> _store = [];
  @override
  Future<void> addBookmark(Bookmark bookmark) async => _store.add(bookmark);
  @override
  Future<List<Bookmark>> getBookmarks() async => List.unmodifiable(_store);
  @override
  Future<bool> isBookmarked(String verseKey) async => _store.any((b) => b.verseKey == verseKey);
  @override
  Future<void> removeBookmark(String verseKey) async => _store.removeWhere((b) => b.verseKey == verseKey);
  @override
  Future<void> clearBookmarks() async => _store.clear();
}

void main() {
  group('BookmarkProvider.toggleBookmark', () {
    late BookmarkProvider provider;
  late _FakeBookmarkRepo fake;

    setUp(() {
  fake = _FakeBookmarkRepo();
  provider = BookmarkProvider(bookmarkUseCases: BookmarkUseCases(fake));
    });

    test('adds bookmark when not existing, removes when existing', () async {
      const key = '1:1';
      expect(await provider.isBookmarked(key), isFalse);
      await provider.toggleBookmark(key);
      expect(await provider.isBookmarked(key), isTrue);
      await provider.toggleBookmark(key);
      expect(await provider.isBookmarked(key), isFalse);
    });
  });
}
