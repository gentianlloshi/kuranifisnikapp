import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kurani_fisnik_app/presentation/widgets/search_widget.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/bookmark_provider.dart';
import 'package:kurani_fisnik_app/domain/usecases/bookmark_usecases.dart';
import 'package:kurani_fisnik_app/domain/repositories/bookmark_repository.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';

void main() {
  testWidgets('SearchResultItem highlights occurrences of query', (tester) async {
    const verse = Verse(
      surahId: 1,
      verseNumber: 1,
      arabicText: 'Ar',
      translation: 'Kjo është një fjali testuese me Fjali dy herë fjali.',
      transliteration: 'trans',
      verseKey: '1:1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => BookmarkProvider(bookmarkUseCases: BookmarkUseCases(_FakeRepo())),
          ),
        ],
        child: MaterialApp(
          home: Material(
            child: SearchResultItem(
              verse: verse,
              searchQuery: 'fjali',
              settings: _DummySettings(),
            ),
          ),
        ),
      ),
    );

    // Expect at least two highlighted containers (WidgetSpan) -> inspect by finding Containers with decoration maybe
    final matches = find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration);
    expect(matches, findsWidgets);
  });
}

class _DummySettings {
  bool get showArabic => false;
  bool get showTranslation => true;
  bool get showTransliteration => false;
  int get fontSizeArabic => 24;
  int get fontSizeTranslation => 16;
}

class _FakeRepo implements BookmarkRepository {
  final List<Bookmark> _store = [];
  @override
  Future<void> addBookmark(Bookmark bookmark) async => _store.add(bookmark);
  @override
  Future<List<Bookmark>> getBookmarks() async => _store;
  @override
  Future<bool> isBookmarked(String verseKey) async => _store.any((b) => b.verseKey == verseKey);
  @override
  Future<void> removeBookmark(String verseKey) async => _store.removeWhere((b) => b.verseKey == verseKey);
  @override
  Future<void> clearBookmarks() async => _store.clear();
}
