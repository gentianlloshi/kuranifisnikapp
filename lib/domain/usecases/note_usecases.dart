import 'package:uuid/uuid.dart';
import '../entities/note.dart';
import '../repositories/note_repository.dart';

class GetNotesUseCase {
  final NoteRepository _noteRepository;

  GetNotesUseCase(this._noteRepository);

  Future<List<Note>> call() async {
    return await _noteRepository.getAllNotes();
  }
}

class GetNotesByVerseKeyUseCase {
  final NoteRepository _noteRepository;

  GetNotesByVerseKeyUseCase(this._noteRepository);

  Future<List<Note>> call(String verseKey) async {
    return await _noteRepository.getNotesByVerseKey(verseKey);
  }
}

class GetNoteByIdUseCase {
  final NoteRepository _noteRepository;

  GetNoteByIdUseCase(this._noteRepository);

  Future<Note?> call(String id) async {
    return await _noteRepository.getNoteById(id);
  }
}

class AddNoteUseCase {
  final NoteRepository _noteRepository;

  AddNoteUseCase(this._noteRepository);

  Future<void> call(String verseKey, String content, {List<String> tags = const []}) async {
    const uuid = Uuid();
    final newNote = Note(
      id: uuid.v4(),
      verseKey: verseKey,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: tags,
    );
    await _noteRepository.addNote(newNote);
  }
}

class UpdateNoteUseCase {
  final NoteRepository _noteRepository;

  UpdateNoteUseCase(this._noteRepository);

  Future<void> call(Note note) async {
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await _noteRepository.updateNote(updatedNote);
  }
}

class DeleteNoteUseCase {
  final NoteRepository _noteRepository;

  DeleteNoteUseCase(this._noteRepository);

  Future<void> call(String id) async {
    await _noteRepository.deleteNote(id);
  }
}

class SearchNotesUseCase {
  final NoteRepository _noteRepository;

  SearchNotesUseCase(this._noteRepository);

  Future<List<Note>> call(String query) async {
    return await _noteRepository.searchNotes(query);
  }
}

class GetNotesByTagUseCase {
  final NoteRepository _noteRepository;

  GetNotesByTagUseCase(this._noteRepository);

  Future<List<Note>> call(String tag) async {
    return await _noteRepository.getNotesByTag(tag);
  }
}

class GetAllTagsUseCase {
  final NoteRepository _noteRepository;

  GetAllTagsUseCase(this._noteRepository);

  Future<List<String>> call() async {
    return await _noteRepository.getAllTags();
  }
}

