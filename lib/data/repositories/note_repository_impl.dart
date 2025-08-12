import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../datasources/local/storage_data_source.dart';

class NoteRepositoryImpl implements NoteRepository {
  final StorageDataSource _storageDataSource;
  List<Note>? _cachedNotes;

  NoteRepositoryImpl(this._storageDataSource);

  @override
  Future<List<Note>> getAllNotes() async {
    if (_cachedNotes != null) {
      return _cachedNotes!;
    }

    _cachedNotes = await _storageDataSource.getNotes();
    return _cachedNotes!;
  }

  @override
  Future<List<Note>> getNotesByVerseKey(String verseKey) async {
    final notes = await getAllNotes();
    return notes.where((note) => note.verseKey == verseKey).toList();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final notes = await getAllNotes();
    try {
      return notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addNote(Note note) async {
    final notes = await getAllNotes();
    notes.add(note);
    _cachedNotes = notes;
    await _storageDataSource.saveNotes(notes);
  }

  @override
  Future<void> updateNote(Note note) async {
    final notes = await getAllNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    
    if (index != -1) {
      notes[index] = note;
      _cachedNotes = notes;
      await _storageDataSource.saveNotes(notes);
    } else {
      throw Exception('Note with id ${note.id} not found');
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    final notes = await getAllNotes();
    notes.removeWhere((note) => note.id == id);
    _cachedNotes = notes;
    await _storageDataSource.saveNotes(notes);
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final notes = await getAllNotes();
    final queryLower = query.toLowerCase();
    
    return notes.where((note) {
      return note.content.toLowerCase().contains(queryLower) ||
             note.tags.any((tag) => tag.toLowerCase().contains(queryLower));
    }).toList();
  }

  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    final notes = await getAllNotes();
    return notes.where((note) => note.tags.contains(tag)).toList();
  }

  @override
  Future<List<String>> getAllTags() async {
    final notes = await getAllNotes();
    final Set<String> tags = {};
    
    for (final note in notes) {
      tags.addAll(note.tags);
    }
    
    return tags.toList()..sort();
  }

  void clearCache() {
    _cachedNotes = null;
  }
}

