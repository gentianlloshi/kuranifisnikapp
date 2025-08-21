import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kuranifisnikapp/core/services/data_import_service.dart';
import 'package:kuranifisnikapp/domain/repositories/storage_repository.dart';
import 'package:kuranifisnikapp/domain/entities/app_settings.dart';
import 'package:kuranifisnikapp/domain/entities/bookmark.dart';
import 'package:kuranifisnikapp/domain/entities/note.dart';

class _FakeStorageRepository implements StorageRepository {
  AppSettings? _settings;
  final Map<String, Bookmark> _bookmarks = {};
  final Map<String, Note> _notes = {};
  final Map<String, int> _lastReadPositions = {}; // surah->verse
  final Map<String, int> _lastReadTimestamps = {}; // surah->ts
  final Set<String> _memorization = {};

  @override
  Future<AppSettings?> getSettings() async => _settings;
  @override
  Future<void> saveSettings(AppSettings settings) async { _settings = settings; }
  @override
  Future<List<Bookmark>> getBookmarks() async => _bookmarks.values.toList();
  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async { _bookmarks..clear()..addEntries(bookmarks.map((b)=>MapEntry(b.verseKey,b))); }
  @override
  Future<void> addBookmark(Bookmark bookmark) async { _bookmarks[bookmark.verseKey]=bookmark; }
  @override
  Future<void> removeBookmark(String verseKey) async { _bookmarks.remove(verseKey); }
  @override
  Future<bool> isBookmarked(String verseKey) async => _bookmarks.containsKey(verseKey);
  // Notes
  @override
  Future<void> saveNote(Note note) async { _notes[note.id]=note; }
  @override
  Future<void> deleteNote(String noteId) async { _notes.remove(noteId); }
  @override
  Future<List<Note>> getNotes() async => _notes.values.toList();
  @override
  Future<Note?> getNoteForVerse(String verseKey) async => _notes.values.firstWhere((n)=>n.verseKey==verseKey, orElse: ()=> null as Note); // not used in tests
  // Reading progress
  @override
  Future<void> saveLastReadPosition(int surahNumber, int verseNumber) async { _lastReadPositions['$surahNumber'] = verseNumber; _lastReadTimestamps['$surahNumber'] = DateTime.now().millisecondsSinceEpoch ~/ 1000; }
  @override
  Future<Map<String, int>> getLastReadPosition() async => Map.of(_lastReadPositions);
  @override
  Future<Map<String, int>> getLastReadTimestamps() async => Map.of(_lastReadTimestamps);
  // Memorization
  @override
  Future<void> addVerseToMemorization(String verseKey) async { _memorization.add(verseKey); }
  @override
  Future<void> removeVerseFromMemorization(String verseKey) async { _memorization.remove(verseKey); }
  @override
  Future<List<String>> getMemorizationList() async => _memorization.toList();
  @override
  Future<bool> isVerseMemorized(String verseKey) async => _memorization.contains(verseKey);
}

void main() {
  group('DataImportService dryRunDiff', () {
    late _FakeStorageRepository repo;
    late DataImportService service;

    setUp(() async {
      repo = _FakeStorageRepository();
      service = DataImportService(storageRepository: repo);
      // Ensure Hive initialized for memorization tests
      final dir = await Directory.systemTemp.createTemp('hive_test');
      Hive.init(dir.path);
    });

    test('Empty bundle yields no changes', () async {
      final bundle = ImportBundle(root: {});
      final diff = await service.dryRunDiff(bundle);
      expect(diff.bookmarkAdds, isEmpty);
      expect(diff.noteAdds, isEmpty);
      expect(diff.memorizationAdds, isEmpty);
      expect(diff.readingProgressImprovements, isEmpty);
    });

    test('Bookmark add detected', () async {
      final json = '{"bookmarks":[{"verseKey":"1:1","createdAt":"2024-01-01T00:00:00.000Z"}] }';
      final bundle = await service.parse(json);
      final diff = await service.dryRunDiff(bundle);
      expect(diff.bookmarkAdds.length, 1);
    });

    test('Bookmark update detected when newer createdAt', () async {
      // Seed existing bookmark older
      final older = Bookmark(verseKey: '2:5', createdAt: DateTime.parse('2024-01-01T00:00:00Z'));
      await repo.saveBookmarks([older]);
      final json = '{"bookmarks":[{"verseKey":"2:5","createdAt":"2024-02-01T00:00:00.000Z"}] }';
      final diff = await service.dryRunDiff(await service.parse(json));
      expect(diff.bookmarkUpdates.length, 1);
    });

    test('Note add vs update vs conflict', () async {
      final base = DateTime.parse('2024-01-01T00:00:00Z');
      final existing = Note(id: 'n1', verseKey: '1:1', content: 'old', createdAt: base, updatedAt: base);
      await repo.saveNote(existing);
      // Imported updated inside conflict window (within 5s) -> conflict
      final conflictJson = '{"notes":[{"id":"n1","verseKey":"1:1","content":"new","createdAt":"${base.toIso8601String()}","updatedAt":"${base.add(const Duration(seconds:3)).toIso8601String()}"}] }';
      final diffConflict = await service.dryRunDiff(await service.parse(conflictJson));
      expect(diffConflict.noteConflicts.length, 1);
      // Imported updated after window (10s) -> update
      final updateJson = '{"notes":[{"id":"n1","verseKey":"1:1","content":"new2","createdAt":"${base.toIso8601String()}","updatedAt":"${base.add(const Duration(seconds:10)).toIso8601String()}"}] }';
      final diffUpdate = await service.dryRunDiff(await service.parse(updateJson));
      expect(diffUpdate.noteUpdates.length, 1);
    });

    test('Older note import ignored', () async {
      final base = DateTime.parse('2024-03-01T00:00:20Z');
      final existing = Note(id: 'n2', verseKey: '1:2', content: 'live', createdAt: base, updatedAt: base);
      await repo.saveNote(existing);
      final olderJson = '{"notes":[{"id":"n2","verseKey":"1:2","content":"stale","createdAt":"2024-03-01T00:00:00Z","updatedAt":"2024-03-01T00:00:10Z"}] }';
      final diff = await service.dryRunDiff(await service.parse(olderJson));
      expect(diff.noteAdds, isEmpty);
      expect(diff.noteUpdates, isEmpty);
      expect(diff.noteConflicts, isEmpty);
    });

    test('Reading progress improvement detected for higher verse', () async {
      await repo.saveLastReadPosition(1, 3); // sets ts implicitly
      final json = '{"readingProgress":{"positions":{"1":5},"timestamps":{"1":999999}}}';
      final diff = await service.dryRunDiff(await service.parse(json));
      expect(diff.readingProgressImprovements.containsKey('1'), isTrue);
    });

    test('No reading progress improvement when lower verse & older ts', () async {
      await repo.saveLastReadPosition(2, 10);
      final json = '{"readingProgress":{"positions":{"2":5},"timestamps":{"2":1}}}';
      final diff = await service.dryRunDiff(await service.parse(json));
      expect(diff.readingProgressImprovements.containsKey('2'), isFalse);
    });
    test('Memorization upgrade (status increase) detected', () async {
      // Seed existing memorization box manually to simulate lower status
      final box = await Hive.openBox('memorization_box');
      await box.put('verses_v1', [ {'s':1,'v':5,'st':0} ]); // newVerse
      final json = '{"memorization":{"verses":[{"surah":1,"verse":5,"status":"inProgress"}]}}';
      final diff = await service.dryRunDiff(await service.parse(json));
      expect(diff.memorizationStatusUpgrades.length, 1);
    });
  });

  group('DataImportService applyImport settings merge', () {
    late _FakeStorageRepository repo;
    late DataImportService service;
    setUp(() {
      repo = _FakeStorageRepository();
      service = DataImportService(storageRepository: repo);
    });

    test('Partial settings merge preserves local audio & font fields', () async {
      // Local settings with distinct values
      final local = const AppSettings(preferredReciter: 'rec-local', audioVolume: 0.42, playbackSpeed: 1.25, fontSizeArabic: 30, fontSizeTranslation: 18, fontSize: 19);
      await repo.saveSettings(local);
      // Incoming missing those keys (only theme provided)
      final json = '{"settings":{"theme":"dark"}}';
      final bundle = await service.parse(json);
      final diff = await service.dryRunDiff(bundle);
      expect(diff.settingsChange, SettingsChange.partial);
      final res = await service.applyImport(bundle: bundle, options: const DataImportOptions(overwriteSettings: true), precomputedDiff: diff);
      expect(res.settingsOverwritten, true);
      final merged = await repo.getSettings();
      expect(merged!.preferredReciter, 'rec-local');
      expect(merged.audioVolume, 0.42);
      expect(merged.playbackSpeed, 1.25);
      expect(merged.fontSizeArabic, 30);
      expect(merged.fontSizeTranslation, 18);
      expect(merged.fontSize, 19);
      expect(merged.theme, 'dark');
    });
  });
}
