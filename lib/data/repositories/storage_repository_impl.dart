import '../../domain/entities/app_settings.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/storage_repository.dart';
import '../datasources/local/storage_data_source.dart';

class StorageRepositoryImpl implements StorageRepository {
  final StorageDataSource _storageDataSource;

  StorageRepositoryImpl(this._storageDataSource);

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _storageDataSource.saveSettings(settings);
  }

  @override
  Future<AppSettings> getSettings() async {
    return await _storageDataSource.getSettings();
  }

  @override
  Future<void> addBookmark(Bookmark bookmark) async {
    final bookmarks = await getBookmarks();
    final existingIndex = bookmarks.indexWhere((b) => b.verseKey == bookmark.verseKey);
    
    if (existingIndex != -1) {
      bookmarks[existingIndex] = bookmark;
    } else {
      bookmarks.add(bookmark);
    }

    await _storageDataSource.saveBookmarks(bookmarks);
  }

  @override
  Future<void> removeBookmark(String verseKey) async {
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((bookmark) => bookmark.verseKey == verseKey);
    
    await _storageDataSource.saveBookmarks(bookmarks);
  }

  @override
  Future<List<Bookmark>> getBookmarks() async {
    final bookmarks = await _storageDataSource.getBookmarks();
    return bookmarks;
  }

  @override
  Future<bool> isBookmarked(String verseKey) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((bookmark) => bookmark.verseKey == verseKey);
  }

  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {
    await _storageDataSource.saveBookmarks(bookmarks);
  }

  @override
  Future<void> saveNote(Note note) async {
    final notes = await getNotes();
    final existingIndex = notes.indexWhere((n) => n.id == note.id);
    
    if (existingIndex != -1) {
      notes[existingIndex] = note;
    } else {
      notes.add(note);
    }

    await _storageDataSource.saveNotes(notes);
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final notes = await getNotes();
    notes.removeWhere((note) => note.id == noteId);
    
    await _storageDataSource.saveNotes(notes);
  }

  @override
  Future<List<Note>> getNotes() async {
    final notes = await _storageDataSource.getNotes();
    return notes;
  }

  @override
  Future<Note?> getNoteForVerse(String verseKey) async {
    final notes = await getNotes();
    try {
      return notes.firstWhere((note) => note.verseKey == verseKey);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveLastReadPosition(int surahNumber, int verseNumber) async {
    // TODO: Implement last read position functionality
    // For now, this is a placeholder
  }

  @override
  Future<Map<String, int>> getLastReadPosition() async {
    // TODO: Implement last read position functionality
    // For now, return empty map
    return {};
  }

  @override
  Future<void> addVerseToMemorization(String verseKey) async {
    final memorizationList = await getMemorizationList();
    if (!memorizationList.contains(verseKey)) {
      memorizationList.add(verseKey);
      await _storageDataSource.saveMemorizationList(memorizationList);
    }
  }

  @override
  Future<void> removeVerseFromMemorization(String verseKey) async {
    final memorizationList = await getMemorizationList();
    memorizationList.remove(verseKey);
    await _storageDataSource.saveMemorizationList(memorizationList);
  }

  @override
  Future<List<String>> getMemorizationList() async {
    return await _storageDataSource.getMemorizationList();
  }

  @override
  Future<bool> isVerseMemorized(String verseKey) async {
    final memorizationList = await getMemorizationList();
    return memorizationList.contains(verseKey);
  }
}
