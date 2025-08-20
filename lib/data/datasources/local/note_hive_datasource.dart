import 'package:hive/hive.dart';
import '../../../domain/entities/note.dart';
import 'hive_boxes.dart';

class NoteHiveDataSource {
  Future<Box> _openBox() async => Hive.isBoxOpen(HiveBoxes.notes)
      ? Hive.box(HiveBoxes.notes)
      : await Hive.openBox(HiveBoxes.notes);

  Future<List<Note>> getAllNotes() async {
    final box = await _openBox();
    return box.values
        .whereType<Map>()
        .map((m) => Note.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> saveNote(Note note) async {
    final box = await _openBox();
    await box.put(note.id, note.toJson());
  }

  Future<void> deleteNote(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }
}
