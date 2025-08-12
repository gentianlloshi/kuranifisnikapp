import '../entities/app_settings.dart';
import '../entities/bookmark.dart';
import '../entities/note.dart';

abstract class StorageRepository {
  Future<AppSettings?> getSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<List<Bookmark>> getBookmarks();
  Future<void> saveBookmarks(List<Bookmark> bookmarks);
  Future<void> addBookmark(Bookmark bookmark);
  Future<void> removeBookmark(String verseKey);
  Future<bool> isBookmarked(String verseKey);
  
  // Note methods
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String noteId);
  Future<List<Note>> getNotes();
  Future<Note?> getNoteForVerse(String verseKey);
  
  // Last read position methods
  Future<void> saveLastReadPosition(int surahNumber, int verseNumber);
  Future<Map<String, int>> getLastReadPosition();
  
  // Memorization methods
  Future<void> addVerseToMemorization(String verseKey);
  Future<void> removeVerseFromMemorization(String verseKey);
  Future<List<String>> getMemorizationList();
  Future<bool> isVerseMemorized(String verseKey);
}
