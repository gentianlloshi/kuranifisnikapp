import '../entities/note.dart';

abstract class NoteRepository {
  Future<List<Note>> getAllNotes();
  Future<List<Note>> getNotesByVerseKey(String verseKey);
  Future<Note?> getNoteById(String id);
  Future<void> addNote(Note note);
  Future<void> updateNote(Note note);
  Future<void> deleteNote(String id);
  Future<List<Note>> searchNotes(String query);
  Future<List<Note>> getNotesByTag(String tag);
  Future<List<String>> getAllTags();
}

