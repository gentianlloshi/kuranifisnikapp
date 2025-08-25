import 'package:flutter/material.dart';
import '../../domain/entities/note.dart';
import '../../data/datasources/local/note_hive_datasource.dart';
import 'package:kurani_fisnik_app/core/search/token_utils.dart' as tq;
import 'package:kurani_fisnik_app/core/search/stemmer.dart';

class NoteProvider extends ChangeNotifier {
  final NoteHiveDataSource _ds = NoteHiveDataSource();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  String _searchQuery = '';
  String? _selectedTag;
  bool _isLoading = false;
  String? _error;
  List<String> _tags = [];
  // In-memory inverted index for fast note searches (token -> set of noteIds)
  final Map<String, Set<String>> _noteIndex = {};
  // Note id -> Note
  final Map<String, Note> _noteById = {};
  // verseKey -> list of noteIds (stable order by updatedAt desc)
  final Map<String, List<String>> _verseToNoteIds = {};

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
  _rebuildIndex();
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
  _indexNote(note);
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
  _rebuildIndex(); // safe & simple; note count is small
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
  _removeFromIndex(noteId);
      notifyListeners();
  // Persist deletion
  await _ds.deleteNote(noteId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<Note> getNotesByVerseKey(String verseKey) {
    return _notes.where((note) => note.verseKey == verseKey).toList();
  }

  // Legacy sync helpers referenced by widgets
  int getNotesCountForVerse(String verseKey) {
    final list = _verseToNoteIds[verseKey];
    if (list != null) return list.length;
    return getNotesByVerseKey(verseKey).length;
  }
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

  // ---------------- In-memory notes index ----------------
  void _rebuildIndex() {
    _noteIndex.clear();
    _noteById.clear();
    _verseToNoteIds.clear();
    for (final n in _notes) {
      _noteById[n.id] = n;
      final list = _verseToNoteIds.putIfAbsent(n.verseKey, () => <String>[]);
      list.add(n.id);
      _indexNote(n);
    }
    // Order verse mapping by recency
    _verseToNoteIds.forEach((vk, ids) {
      ids.sort((a, b) => _noteById[b]!.updatedAt.compareTo(_noteById[a]!.updatedAt));
    });
  }

  void _indexNote(Note n) {
    _noteById[n.id] = n;
    final tokens = <String>{};
    // Content tokens
    for (final t in tq.tokenizeLatin(n.content)) {
      if (t.isEmpty) continue;
      final norm = tq.normalizeLatin(t);
      if (norm.length >= 2) tokens.add(norm);
      final st = lightStem(norm);
      if (st.length >= 3) tokens.add(st);
    }
    // Tag tokens
    for (final tag in n.tags) {
      for (final t in tq.tokenizeLatin(tag)) {
        final norm = tq.normalizeLatin(t);
        if (norm.length >= 2) tokens.add(norm);
      }
    }
    for (final tok in tokens) {
      final set = _noteIndex.putIfAbsent(tok, () => <String>{});
      set.add(n.id);
    }
    // verse mapping
    final list = _verseToNoteIds.putIfAbsent(n.verseKey, () => <String>[]);
    if (!list.contains(n.id)) list.add(n.id);
  }

  void _removeFromIndex(String noteId) {
    _noteById.remove(noteId);
    // Remove from postings
    for (final entry in _noteIndex.entries) {
      entry.value.remove(noteId);
    }
    // Clean empty tokens
    _noteIndex.removeWhere((_, ids) => ids.isEmpty);
    // Remove from verse mapping
    for (final ids in _verseToNoteIds.values) {
      ids.remove(noteId);
    }
    _verseToNoteIds.removeWhere((_, ids) => ids.isEmpty);
  }

  /// Quick notes search using the in-memory index; returns ranked notes.
  List<Note> quickSearchNotes(String query, {String? verseKeyFilter, String? tagFilter, int limit = 20}) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final tokens = tq.expandQueryTokens(q, lightStem)
        .map((e) => tq.normalizeLatin(e))
        .where((e) => e.isNotEmpty)
        .toSet();
    if (tokens.isEmpty) return const [];
    final score = <String, int>{}; // noteId -> score
    for (final t in tokens) {
      final ids = _noteIndex[t];
      if (ids == null) continue;
      for (final id in ids) {
        score.update(id, (v) => v + 10, ifAbsent: () => 10);
      }
    }
    if (score.isEmpty) return const [];
    // Rank by score + recency
    final candidates = score.keys
        .map((id) => _noteById[id])
        .whereType<Note>()
        .where((n) => verseKeyFilter == null || n.verseKey == verseKeyFilter)
        .where((n) => tagFilter == null || n.tags.contains(tagFilter))
        .toList();
    candidates.sort((a, b) {
      final c = (score[b.id]! - score[a.id]!);
      if (c != 0) return c;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    if (candidates.length > limit) return candidates.sublist(0, limit);
    return candidates;
  }
}
