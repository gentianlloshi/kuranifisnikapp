// ignore_for_file: unnecessary_import
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/core/services/data_import_service.dart';
import 'package:kurani_fisnik_app/core/services/data_export_service.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';
import 'package:kurani_fisnik_app/data/repositories/storage_repository_impl.dart';
import 'package:kurani_fisnik_app/domain/repositories/storage_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'dart:io';

// Minimal harness to validate ImportProgress emissions and cancel behavior.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final tempDir = Directory.systemTemp.createTempSync('hive_test');
  Hive.init(tempDir.path);
  late StorageRepository repo;
  late DataImportService importService;

  setUp(() {
    repo = StorageRepositoryImpl(StorageDataSourceImpl());
    importService = DataImportService(storageRepository: repo);
  });

  test('emits progress phases and completes', () async {
    // Build a tiny bundle with a bookmark and note so we see per-item progress
    final bundle = ImportBundle(root: {
      'version': DataExportService.exportVersion,
      'settings': {'theme': 'light'},
      'bookmarks': [
        {
          'verseKey': '1:1',
          'title': 'Test',
          'createdAt': DateTime.now().toIso8601String(),
        }
      ],
      'notes': [
        {
          'id': 'n1',
          'verseKey': '1:1',
          'content': 'hello',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }
      ],
      'memorization': {'verses': []},
      'readingProgress': {
        'positions': {'1': 1},
        'timestamps': {'1': DateTime.now().millisecondsSinceEpoch}
      }
    });

    final phases = <String>[];
    final sub = importService.progressStream.listen((p) { phases.add(p.phase); });
    addTearDown(() => sub.cancel());

    final res = await importService.applyImport(
      bundle: bundle,
      options: const DataImportOptions(
        overwriteSettings: true,
        importBookmarks: true,
        importNotes: true,
        importMemorization: true,
        importReadingProgress: true,
      ),
    );

  // Allow queued stream events (like the final 'done') to deliver to our listener
  await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(res.canceled, isFalse);
    // Must have emitted init and done at least
    expect(phases.first, anyOf('init'));
    expect(phases.contains('done'), isTrue);
  });

  test('cancel stops import and emits canceled', () async {
    // Make a larger bundle to allow cancel interception
    final manyNotes = List.generate(100, (i) => {
      'id': 'n$i',
      'verseKey': '1:1',
      'content': 'c$i',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    final bundle = ImportBundle(root: {
      'version': DataExportService.exportVersion,
      'notes': manyNotes,
    });

    final phases = <String>[];
    final sub = importService.progressStream.listen((p) {
      phases.add(p.phase);
      if (p.phase == 'notes' && p.current > 10) {
        importService.cancelImport();
      }
    });
    addTearDown(() => sub.cancel());

    final res = await importService.applyImport(
      bundle: bundle,
      options: const DataImportOptions(
        overwriteSettings: false,
        importBookmarks: false,
        importNotes: true,
        importMemorization: false,
        importReadingProgress: false,
      ),
    );

  // Allow queued stream events (like the final 'canceled') to deliver to our listener
  await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(res.canceled, isTrue);
    expect(phases.contains('canceled'), isTrue);
  });
}
