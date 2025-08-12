import 'package:flutter/material.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/usecases/bookmark_usecases.dart';

class BookmarkProvider extends ChangeNotifier {
  final BookmarkUseCases _bookmarkUseCases;

  BookmarkProvider({
    required BookmarkUseCases bookmarkUseCases,
  }) : _bookmarkUseCases = bookmarkUseCases;

  List<Bookmark> _bookmarks = [];
  bool _isLoading = false;
  String? _error;

  List<Bookmark> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBookmarks() async {
    _setLoading(true);
    try {
      _bookmarks = await _bookmarkUseCases.getBookmarks();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    try {
      await _bookmarkUseCases.addBookmark(bookmark);
      _bookmarks.add(bookmark);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeBookmark(String verseKey) async {
    try {
      await _bookmarkUseCases.removeBookmark(verseKey);
      _bookmarks.removeWhere((bookmark) => bookmark.verseKey == verseKey);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> isBookmarked(String verseKey) async {
    try {
      return await _bookmarkUseCases.isBookmarked(verseKey);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleBookmark(String verseKey) async {
    final already = await isBookmarked(verseKey);
    if (already) {
      await removeBookmark(verseKey);
    } else {
      await addBookmark(Bookmark(verseKey: verseKey, createdAt: DateTime.now()));
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
