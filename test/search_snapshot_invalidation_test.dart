import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/search_index_manager.dart';
import 'helpers/test_snapshot_store.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surah_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Search snapshot invalidation', () {
    test('snapshot uses matching dataVersion and ignores mismatched', () async {
      final temp = await Directory.systemTemp.createTemp('kf_snapshot_test');
      final store = TestSnapshotStore(dir: temp, currentDataVersion: 'v2:new');
      // Prepare a snapshot with matching dataVersion but an empty index
      await store.save({
        'version': 2,
        'dataVersion': 'v2:new',
        'index': {},
        'verses': {},
        'createdAt': DateTime.now().toIso8601String(),
        'nextSurah': 115,
      });

      // Minimal dummy repository & usecases (not invoked when snapshot valid)
      final repo = _DummyRepo();
      final dummyGetSurahs = GetSurahsUseCase(repo);
      final dummyGetVerses = GetSurahVersesUseCase(repo);
      final mgrFromSnapshot = SearchIndexManager(
        getSurahsUseCase: dummyGetSurahs,
        getSurahVersesUseCase: dummyGetVerses,
  snapshotStore: store,
  enablePrebuiltAsset: false,
      );
      await mgrFromSnapshot.ensureBuilt();
      expect(mgrFromSnapshot.isBuilt, isTrue);
      // Empty index should yield no results
      expect(mgrFromSnapshot.search('allahu'), isEmpty);

      // Now change dataVersion to mismatch and use a fresh manager so it ignores the snapshot and builds from assets
      store.currentDataVersion = 'v2:changed';
      final mgrBuilt = SearchIndexManager(
        getSurahsUseCase: dummyGetSurahs,
        getSurahVersesUseCase: dummyGetVerses,
  snapshotStore: store,
  enablePrebuiltAsset: false,
      );
      await mgrBuilt.ensureBuilt();
      expect(mgrBuilt.isBuilt, isTrue);
      // Real index should return some results for a common token
      expect(mgrBuilt.search('allahu'), isNotEmpty);
    });
  });
}

class _DummyRepo implements QuranRepository {
  @override
  Stream<double> get enrichmentCoverageStream => const Stream.empty();
  @override
  Stream<Map<String, double>> get translationCoverageStream => const Stream.empty();
  @override
  Future<List<Surah>> getAllSurahs() async => [];
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};
  @override
  Future<Map<String, dynamic>> getTranslation(String translationKey) async => {};
  @override
  Future<Surah> getSurah(int surahNumber) async => throw UnimplementedError();
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => throw UnimplementedError();
  @override
  Future<List<Verse>> getVersesBySurah(int surahId) async => throw UnimplementedError();
  @override
  Future<Verse> getVerse(int surahNumber, int verseNumber) async => throw UnimplementedError();
  @override
  Future<void> ensureSurahTransliteration(int surahNumber) async {}
  @override
  Future<void> ensureSurahTranslation(int surahNumber, {String translationKey = 'sq_ahmeti'}) async {}
  @override
  bool isSurahFullyEnriched(int surahNumber) => true;
  @override
  Map<String, double> translationCoverageByKey() => {'sq_ahmeti': 2/114};
  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) async => [];
}
