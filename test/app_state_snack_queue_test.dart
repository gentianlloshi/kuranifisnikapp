import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/app_state_provider.dart';
import 'package:kurani_fisnik_app/domain/usecases/settings_usecases.dart';
import 'package:kurani_fisnik_app/domain/repositories/storage_repository.dart';
import 'package:kurani_fisnik_app/domain/entities/app_settings.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/entities/note.dart';

class _NoopGetSettings extends GetSettingsUseCase {
  _NoopGetSettings() : super(_FakeStorage());
}

class _NoopSaveSettings extends SaveSettingsUseCase {
  _NoopSaveSettings() : super(_FakeStorage());
}

class _FakeStorage implements StorageRepository {
  AppSettings _settings = const AppSettings();
  @override
  Future<void> addBookmark(Bookmark bookmark) async {}
  @override
  Future<void> addVerseToMemorization(String verseKey) async {}
  @override
  Future<void> deleteNote(String noteId) async {}
  @override
  Future<List<Bookmark>> getBookmarks() async => [];
  @override
  Future<AppSettings?> getSettings() async => _settings;
  @override
  Future<List<String>> getMemorizationList() async => [];
  @override
  Future<List<Note>> getNotes() async => [];
  @override
  Future<Note?> getNoteForVerse(String verseKey) async => null;
  @override
  Future<void> removeBookmark(String verseKey) async {}
  @override
  Future<bool> isBookmarked(String verseKey) async => false;
  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {}
  @override
  Future<void> saveNote(Note note) async {}
  @override
  Future<void> saveSettings(AppSettings settings) async { _settings = settings; }
  @override
  Future<void> saveLastReadPosition(int surahNumber, int verseNumber) async {}
  @override
  Future<Map<String, int>> getLastReadPosition() async => {'surah': 1, 'verse': 1};
  @override
  Future<void> removeVerseFromMemorization(String verseKey) async {}
  @override
  Future<bool> isVerseMemorized(String verseKey) async => false;
  @override
  Future<Map<String, int>> getLastReadTimestamps() async => {};
}

void main() {
  test('enqueueSnack adds to queue and drain advances only on completion', () async {
    final app = AppStateProvider(
      getSettingsUseCase: _NoopGetSettings(),
      saveSettingsUseCase: _NoopSaveSettings(),
      simple: true,
    );

    expect(app.hasSnack, isFalse);
    app.enqueueSnack('A', duration: const Duration(milliseconds: 10));
    app.enqueueSnack('B', duration: const Duration(milliseconds: 10));

    // After enqueue, queue should have items but none marked displaying until host marks it
    expect(app.hasSnack, isTrue);
    expect(app.currentSnack!.text, 'A');
    expect(app.isSnackDisplaying, isFalse);

    // Simulate host showing the first snack
    app.markSnackDisplayed();
    expect(app.isSnackDisplaying, isTrue);

    // Complete first snack
    app.onSnackCompleted();
    expect(app.isSnackDisplaying, isFalse);
    expect(app.hasSnack, isTrue); // second remains
    expect(app.currentSnack!.text, 'B');

    // Show and complete second
    app.markSnackDisplayed();
    app.onSnackCompleted();
    expect(app.hasSnack, isFalse);
    expect(app.currentSnack, isNull);
    expect(app.isSnackDisplaying, isFalse);
  });
}
