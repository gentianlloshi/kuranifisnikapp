import 'package:flutter/material.dart';
import '../../domain/entities/note.dart';
import '../../data/datasources/local/note_hive_datasource.dart';

class NoteProvider extends ChangeNotifier {
  final NoteHiveDataSource _ds = NoteHiveDataSource();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  String _searchQuery = '';
  String? _selectedTag;
  bool _isLoading = false;
  String? _error;
  List<String> _tags = [];

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Note> get filteredNotes => _filteredNotes.isEmpty && (_searchQuery.isEmpty && _selectedTag == null) ? _notes : _filteredNotes;
  String get searchQuery => _searchQuery;
  String? get selectedTag => _selectedTag;
  List<String> get tags => _tags;

  Future<void> loadNotes() async {
    _setLoading(true);
    try {
      _notes = await _ds.getAllNotes();
  _filteredNotes = _notes;
  _rebuildTags();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createNewNote({
    required String verseKey,
    required String content,
    List<String>? tags,
  }) async {
    try {
      final note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        verseKey: verseKey,
        content: content,
        tags: tags ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  _notes.add(note);
  _filteredNotes = _applyFilters();
  _rebuildTags();
      _error = null;
      notifyListeners();
  await _ds.saveNote(note);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note.copyWith(updatedAt: DateTime.now());
        _error = null;
  _filteredNotes = _applyFilters();
  _rebuildTags();
        notifyListeners();
  await _ds.saveNote(_notes[index]);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      _notes.removeWhere((note) => note.id == noteId);
      _error = null;
  _filteredNotes = _applyFilters();
  _rebuildTags();
      notifyListeners();
      // Persist deletion
      for (final note in _notes.where((n) => n.id == noteId)) {
        await _ds.deleteNote(note.id);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<Note> getNotesByVerseKey(String verseKey) {
    return _notes.where((note) => note.verseKey == verseKey).toList();
  }

  // Legacy sync helpers referenced by widgets
  int getNotesCountForVerse(String verseKey) => getNotesByVerseKey(verseKey).length;
  List<Note> getNotesForVerseSync(String verseKey) => getNotesByVerseKey(verseKey);

  // Backwards compatible addNote signature used in widgets
  Future<void> addNote(String verseKey, String content, {List<String>? tags}) async {
    await createNewNote(verseKey: verseKey, content: content, tags: tags);
  }

  void searchNotes(String query) {
    _searchQuery = query;
    _filteredNotes = _applyFilters();
    notifyListeners();
  }

  void filterByTag(String? tag) {
    _selectedTag = tag;
    _filteredNotes = _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedTag = null;
    _filteredNotes = _notes;
    notifyListeners();
  }

  List<Note> _applyFilters() {
    Iterable<Note> result = _notes;
    if (_searchQuery.isNotEmpty) {
      result = result.where((n) => n.content.toLowerCase().contains(_searchQuery.toLowerCase()));
    }
    if (_selectedTag != null) {
      result = result.where((n) => n.tags.contains(_selectedTag));
    }
    return result.toList();
  }

  void _rebuildTags() {
    final set = <String>{};
    for (final n in _notes) {
      set.addAll(n.tags);
    }
    _tags = set.toList()..sort();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
