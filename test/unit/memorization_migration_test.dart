import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kurani_fisnik_app/data/datasources/local/hive_boxes.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:kurani_fisnik_app/presentation/providers/memorization_provider.dart';
import 'package:kurani_fisnik_app/domain/entities/memorization_verse.dart';

void main() {
  group('MemorizationProvider legacy migration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mem_mig_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('migrates legacy map "verses" to structured list', () async {
  final box = await Hive.openBox(HiveBoxes.memorization);
      box.put('verses', { '1:1': true, '1:2': true, '2:255': true });
      final provider = MemorizationProvider();
      await provider.load();
      // After load migration should have occurred
      expect(provider.isVerseMemorized('1:1'), isTrue);
      expect(provider.isVerseMemorized('1:2'), isTrue);
      expect(provider.isVerseMemorized('2:255'), isTrue);
      // Should have created session for first surah encountered (1)
      expect(provider.activeSurah, 1);
      // Legacy keys removed
      expect(box.get('verses_v1'), isNotNull);
      expect(box.get('verses'), isNull);
    });

    test('migrates legacy list "list" to structured list', () async {
  final box = await Hive.openBox(HiveBoxes.memorization);
      box.put('list', ['3:5','3:6']);
      final provider = MemorizationProvider();
      await provider.load();
      expect(provider.isVerseMemorized('3:5'), isTrue);
      expect(provider.isVerseMemorized('3:6'), isTrue);
      expect(box.get('list'), isNull);
    });

    test('skips migration when verses_v1 already exists', () async {
  final box = await Hive.openBox(HiveBoxes.memorization);
      // Pre-populate new format
      box.put('verses_v1', [ {'s': 4, 'v': 10, 'st': MemorizationStatus.mastered.index } ]);
      // Also add legacy that should be ignored
      box.put('verses', { '4:11': true });
      final provider = MemorizationProvider();
      await provider.load();
      // Only the pre-populated verse should exist (4:10), not 4:11
      expect(provider.isVerseMemorized('4:10'), isTrue);
      expect(provider.isVerseMemorized('4:11'), isFalse);
      // Legacy still present but untouched (optional cleanup skipped)
      // Because code deletes legacy keys after migration only if migration runs; here it shouldn't run
      expect(box.get('verses'), isNotNull);
    });
  });
}
